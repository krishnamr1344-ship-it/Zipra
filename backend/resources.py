"""
resources.py
Purpose: CRUD endpoints for categories, products, addresses, cart, orders, payments.
Security:
  - All endpoints require JWT auth (enforced by middleware).
  - Ownership validation: users access ONLY their own data.
  - Input validated by Pydantic before DB access.
  - Payments store NO sensitive data (card numbers, CVV, etc.).
  - SQLAlchemy ORM only — no raw SQL.
  - Soft-delete used everywhere (is_deleted flag).
"""
import json
import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
import httpx

from typing import Optional

from database import get_db
from models import (
    User, Category, Product, ProductImage, Address, CartItem,
    Order, OrderItem, Payment, DeliveryZone, DeliveryFee, ComboPack, ComboPackItem, Offer,
)
from schemas import (
    CategoryCreate, CategoryResponse,
    ProductCreate, ProductResponse,
    AddressCreate, AddressUpdate, AddressResponse, GpsAddressCreate,
    CartAddRequest, CartUpdateRequest, CartItemResponse,
    OrderCreateRequest, OrderDirectCreateRequest, OrderResponse, OrderItemResponse, DeliveryAddress,
    PaymentProcessRequest, PaymentResponse, MessageResponse,
    ZoneCheckRequest, ZoneCheckResponse,
    ComboPackItemInput, ComboPackItemResponse, ComboPackResponse, PackAddRequest,
    OfferResponse,
)

router = APIRouter(prefix="/api")


# ─── HELPERS ──────────────────────────────────────────────────────

def _get_user_id(request: Request) -> str:
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    return user_id


def _get_user(user_id: str, db: Session) -> User:
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


def _get_address_or_404(addr_id: str, user_id: str, db: Session) -> Address:
    addr = db.query(Address).filter(
        Address.id == addr_id,
        Address.user_id == user_id,
        Address.is_deleted == False,
    ).first()
    if not addr:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Address not found")
    return addr


def _get_cart_item_or_404(item_id: str, user_id: str, db: Session) -> CartItem:
    item = db.query(CartItem).filter(
        CartItem.id == item_id,
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).first()
    if not item:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cart item not found")
    return item


def _get_product_or_404(prod_id: str, db: Session) -> Product:
    prod = db.query(Product).filter(
        Product.id == prod_id,
        Product.is_deleted == False,
    ).first()
    if not prod:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return prod


def _get_order_or_404(order_id: str, user_id: str, db: Session) -> Order:
    order = db.query(Order).filter(
        Order.id == order_id,
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    return order


def _cart_item_to_response(item: CartItem) -> CartItemResponse:
    return CartItemResponse(
        id=str(item.id),
        product_id=str(item.product_id),
        product_name=item.product.name,
        product_price=float(item.product.price),
        product_unit=item.product.unit,
        product_image=item.product.images[0].image_url if item.product.images else None,
        quantity=item.quantity,
        subtotal=round(float(item.product.price) * item.quantity, 2),
    )


def _order_to_response(order: Order) -> OrderResponse:
    items = []
    for oi in order.items:
        if not oi.is_deleted:
            items.append(OrderItemResponse(
                id=str(oi.id),
                product_id=str(oi.product_id),
                product_name=oi.product_name,
                product_price=float(oi.product_price),
                quantity=oi.quantity,
                subtotal=float(oi.subtotal),
            ))
    delivery_address = None
    if order.address_id and order.address:
        addr = order.address
        delivery_address = DeliveryAddress(
            address_line1=addr.address_line1,
            city=addr.city,
            state=addr.state,
            pincode=addr.pincode,
            latitude=float(addr.latitude) if addr.latitude else None,
            longitude=float(addr.longitude) if addr.longitude else None,
        )
    return OrderResponse(
        id=str(order.id),
        status=order.status,
        total_amount=float(order.total_amount),
        payment_method=order.payment_method,
        items=items,
        delivery_address=delivery_address,
        created_at=order.created_at,
    )


# ─── CATEGORIES ───────────────────────────────────────────────────

@router.get("/categories", response_model=list[CategoryResponse])
def list_categories(db: Session = Depends(get_db)):
    cats = db.query(Category).filter(Category.is_deleted == False).order_by(Category.name).all()
    return [
        CategoryResponse(id=str(c.id), name=c.name, description=c.description, image=c.image)
        for c in cats
    ]


@router.get("/categories/{category_id}", response_model=CategoryResponse)
def get_category(category_id: str, db: Session = Depends(get_db)):
    cat = db.query(Category).filter(Category.id == category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    return CategoryResponse(id=str(cat.id), name=cat.name, description=cat.description, image=cat.image)


# ─── PRODUCTS ─────────────────────────────────────────────────────

@router.get("/products", response_model=list[ProductResponse])
def list_products(category_id: Optional[str] = None, db: Session = Depends(get_db)):
    query = db.query(Product).filter(Product.is_deleted == False)
    if category_id:
        query = query.filter(Product.category_id == category_id)
    products = query.order_by(Product.name).all()
    result = []
    for p in products:
        result.append(ProductResponse(
            id=str(p.id),
            category_id=str(p.category_id),
            category_name=p.category.name if p.category else None,
            name=p.name,
            description=p.description,
            price=float(p.price),
            unit=p.unit,
            images=[img.image_url for img in p.images if not img.is_deleted],
            stock=p.stock,
        ))
    return result


@router.get("/products/{product_id}", response_model=ProductResponse)
def get_product(product_id: str, db: Session = Depends(get_db)):
    p = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not p:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    return ProductResponse(
        id=str(p.id),
        category_id=str(p.category_id),
        category_name=p.category.name if p.category else None,
        name=p.name,
        description=p.description,
        price=float(p.price),
        unit=p.unit,
        images=[img.image_url for img in p.images if not img.is_deleted],
        stock=p.stock,
    )


# ─── ADDRESSES ────────────────────────────────────────────────────
# Ownership: all queries filter by user_id from JWT.

@router.get("/addresses", response_model=list[AddressResponse])
def list_addresses(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    addrs = db.query(Address).filter(
        Address.user_id == user_id,
        Address.is_deleted == False,
    ).order_by(Address.is_default.desc(), Address.created_at.desc()).all()
    return [
        AddressResponse(
            id=str(a.id), label=a.label, address_line1=a.address_line1,
            address_line2=a.address_line2, city=a.city, state=a.state,
            pincode=a.pincode, landmark=a.landmark,
            address_type=a.address_type, house_number=a.house_number,
            floor_number=a.floor_number,
            latitude=float(a.latitude) if a.latitude else None,
            longitude=float(a.longitude) if a.longitude else None,
            is_default=a.is_default,
            maps_link=f"https://www.google.com/maps?q={a.latitude},{a.longitude}" if a.latitude and a.longitude else None,
        ) for a in addrs
    ]


@router.post("/addresses", response_model=AddressResponse, status_code=status.HTTP_201_CREATED)
def create_address(body: AddressCreate, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    if body.is_default:
        db.query(Address).filter(Address.user_id == user_id, Address.is_deleted == False).update(
            {"is_default": False}
        )

    addr = Address(
        user_id=user_id, label=body.label.strip(),
        address_line1=body.address_line1.strip(),
        address_line2=body.address_line2.strip() if body.address_line2 else None,
        city=body.city.strip(), state=body.state.strip(),
        pincode=body.pincode.strip(),
        address_type=body.address_type,
        house_number=body.house_number.strip() if body.house_number else None,
        floor_number=body.floor_number.strip() if body.floor_number else None,
        landmark=body.landmark.strip() if body.landmark else None,
        latitude=body.latitude, longitude=body.longitude,
        is_default=body.is_default,
    )
    db.add(addr)
    db.commit()
    db.refresh(addr)
    maps = f"https://www.google.com/maps?q={body.latitude},{body.longitude}" if body.latitude and body.longitude else None
    return AddressResponse(
        id=str(addr.id), label=addr.label,
        address_line1=addr.address_line1, address_line2=addr.address_line2,
        city=addr.city, state=addr.state, pincode=addr.pincode,
        address_type=addr.address_type, house_number=addr.house_number,
        floor_number=addr.floor_number, landmark=addr.landmark,
        latitude=float(addr.latitude) if addr.latitude else None,
        longitude=float(addr.longitude) if addr.longitude else None,
        is_default=addr.is_default,
        maps_link=maps,
    )


@router.put("/addresses/{address_id}", response_model=AddressResponse)
def update_address(address_id: str, body: AddressUpdate, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    addr = _get_address_or_404(address_id, user_id, db)

    if body.is_default is True:
        db.query(Address).filter(Address.user_id == user_id, Address.is_deleted == False).update(
            {"is_default": False}
        )

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if value is not None and isinstance(value, str):
            setattr(addr, field, value.strip())
        else:
            setattr(addr, field, value)

    db.commit()
    db.refresh(addr)
    maps = f"https://www.google.com/maps?q={addr.latitude},{addr.longitude}" if addr.latitude and addr.longitude else None
    return AddressResponse(
        id=str(addr.id), label=addr.label,
        address_line1=addr.address_line1, address_line2=addr.address_line2,
        city=addr.city, state=addr.state, pincode=addr.pincode,
        address_type=addr.address_type, house_number=addr.house_number,
        floor_number=addr.floor_number, landmark=addr.landmark,
        latitude=float(addr.latitude) if addr.latitude else None,
        longitude=float(addr.longitude) if addr.longitude else None,
        is_default=addr.is_default,
        maps_link=maps,
    )


@router.delete("/addresses/{address_id}", response_model=MessageResponse)
def delete_address(address_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    addr = _get_address_or_404(address_id, user_id, db)
    addr.is_deleted = True
    db.commit()
    return MessageResponse(message="Address deleted")


@router.post("/addresses/auto", response_model=AddressResponse, status_code=status.HTTP_201_CREATED)
def create_address_from_gps(body: GpsAddressCreate, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    label = "GPS Location"
    address_line1 = f"{body.latitude:.6f}, {body.longitude:.6f}"
    city = "Unknown"
    state = "Unknown"
    pincode = "000000"

    try:
        with httpx.Client(timeout=10) as client:
            resp = client.get(
                "https://nominatim.openstreetmap.org/reverse",
                params={"lat": body.latitude, "lon": body.longitude, "format": "json"},
                headers={"User-Agent": "DeliveryApp/1.0"},
            )
        if resp.status_code == 200:
            data = resp.json()
            if "address" in data:
                addr_data = data["address"]
                area = addr_data.get("suburb") or addr_data.get("city_district") or ""
                road = addr_data.get("road") or ""
                house = addr_data.get("house_number") or ""
                parts = []
                if road:
                    parts.append(road)
                if house:
                    parts.append(house)
                city = addr_data.get("city") or addr_data.get("town") or addr_data.get("village") or addr_data.get("county") or "Unknown"
                address_line1 = ", ".join(parts) if parts else data.get("display_name", address_line1)
                address_line2 = f"{area}, {city}" if area and city else area or None
                state = addr_data.get("state") or "Unknown"
                pincode = addr_data.get("postcode") or "000000"
    except Exception:
        pass

    # If user already has a GPS address, update it (check by lat/lng being set)
    existing_gps = db.query(Address).filter(
        Address.user_id == user_id,
        Address.latitude != None,
        Address.longitude != None,
        Address.is_deleted == False,
    ).first()

    if existing_gps:
        existing_gps.address_line1 = address_line1
        existing_gps.address_line2 = address_line2
        existing_gps.city = city
        existing_gps.state = state
        existing_gps.pincode = pincode
        existing_gps.landmark = body.landmark
        existing_gps.address_type = body.address_type
        existing_gps.house_number = body.house_number
        existing_gps.floor_number = body.floor_number
        existing_gps.latitude = body.latitude
        existing_gps.longitude = body.longitude
        db.commit()
        db.refresh(existing_gps)
        maps = f"https://www.google.com/maps?q={body.latitude},{body.longitude}" if body.latitude and body.longitude else None
        return AddressResponse(
            id=str(existing_gps.id), label=existing_gps.label,
            address_line1=existing_gps.address_line1, address_line2=existing_gps.address_line2,
            city=existing_gps.city, state=existing_gps.state,
            pincode=existing_gps.pincode, landmark=existing_gps.landmark,
            address_type=existing_gps.address_type,
            house_number=existing_gps.house_number,
            floor_number=existing_gps.floor_number,
            latitude=float(existing_gps.latitude) if existing_gps.latitude else None,
            longitude=float(existing_gps.longitude) if existing_gps.longitude else None,
            is_default=existing_gps.is_default,
            maps_link=maps,
        )

    # Set as default if no other address exists
    has_address = db.query(Address).filter(
        Address.user_id == user_id, Address.is_deleted == False
    ).first()
    is_default = has_address is None

    addr = Address(
        user_id=user_id, label=label,
        address_line1=address_line1, address_line2=address_line2,
        city=city, state=state,
        pincode=pincode, landmark=body.landmark,
        address_type=body.address_type,
        house_number=body.house_number,
        floor_number=body.floor_number,
        latitude=body.latitude, longitude=body.longitude,
        is_default=is_default,
    )
    db.add(addr)
    db.commit()
    db.refresh(addr)
    maps = f"https://www.google.com/maps?q={body.latitude},{body.longitude}" if body.latitude and body.longitude else None
    return AddressResponse(
        id=str(addr.id), label=addr.label,
        address_line1=addr.address_line1, address_line2=addr.address_line2,
        city=addr.city, state=addr.state, pincode=addr.pincode,
        address_type=addr.address_type, house_number=addr.house_number,
        floor_number=addr.floor_number, landmark=addr.landmark,
        latitude=float(addr.latitude) if addr.latitude else None,
        longitude=float(addr.longitude) if addr.longitude else None,
        is_default=addr.is_default,
        maps_link=maps,
    )


# ─── PLACES SEARCH ──────────────────────────────────────────────────

@router.get("/places/search")
def search_places(q: str, db: Session = Depends(get_db)):
    try:
        import httpx
        with httpx.Client(timeout=10) as client:
            resp = client.get(
                "https://nominatim.openstreetmap.org/search",
                params={"q": q, "format": "json", "limit": 10, "addressdetails": 1},
                headers={"User-Agent": "DeliveryApp/1.0"},
            )
        if resp.status_code != 200:
            return []
        data = resp.json()
        results = []
        for item in data:
            addr_data = item.get("address", {})
            results.append({
                "display_name": item.get("display_name", ""),
                "latitude": float(item.get("lat", 0)),
                "longitude": float(item.get("lon", 0)),
                "address_line1": ", ".join(filter(None, [addr_data.get("road", ""), addr_data.get("house_number", "")])),
                "address_line2": addr_data.get("suburb") or addr_data.get("city_district") or "",
                "city": addr_data.get("city") or addr_data.get("town") or addr_data.get("village") or addr_data.get("county") or "",
                "state": addr_data.get("state") or "",
                "pincode": addr_data.get("postcode") or "",
            })
        return results
    except Exception:
        return []


# ─── CART ─────────────────────────────────────────────────────────
# Ownership: all queries filter by user_id from JWT.

@router.get("/cart", response_model=list[CartItemResponse])
def list_cart(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()
    return [_cart_item_to_response(i) for i in items]


@router.post("/cart", response_model=CartItemResponse, status_code=status.HTTP_201_CREATED)
def add_to_cart(body: CartAddRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)
    product = _get_product_or_404(body.product_id, db)

    if product.stock < body.quantity:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Insufficient stock")

    existing = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.product_id == body.product_id,
        CartItem.is_deleted == False,
    ).first()

    if existing:
        existing.quantity = body.quantity
        db.commit()
        db.refresh(existing)
        return _cart_item_to_response(existing)

    # Check if there's a soft-deleted entry and restore it.
    soft_deleted = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.product_id == body.product_id,
        CartItem.is_deleted == True,
    ).first()
    if soft_deleted:
        soft_deleted.is_deleted = False
        soft_deleted.quantity = body.quantity
        db.commit()
        db.refresh(soft_deleted)
        return _cart_item_to_response(soft_deleted)

    item = CartItem(user_id=user_id, product_id=body.product_id, quantity=body.quantity)
    db.add(item)
    db.commit()
    db.refresh(item)
    return _cart_item_to_response(item)


@router.put("/cart/{item_id}", response_model=CartItemResponse)
def update_cart_item(item_id: str, body: CartUpdateRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    item = _get_cart_item_or_404(item_id, user_id, db)

    if body.quantity == 0:
        item.is_deleted = True
        db.commit()
        raise HTTPException(status_code=status.HTTP_200_OK, detail="Item removed from cart")

    item.quantity = body.quantity
    db.commit()
    db.refresh(item)
    return _cart_item_to_response(item)


@router.delete("/cart/{item_id}", response_model=MessageResponse)
def remove_cart_item(item_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    item = _get_cart_item_or_404(item_id, user_id, db)
    item.is_deleted = True
    db.commit()
    return MessageResponse(message="Item removed from cart")


@router.delete("/cart", response_model=MessageResponse)
def clear_cart(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()
    for item in items:
        item.is_deleted = True
    db.commit()
    return MessageResponse(message="Cart cleared")


# ─── ORDERS ───────────────────────────────────────────────────────
# Ownership: all queries filter by user_id from JWT.

@router.get("/orders", response_model=list[OrderResponse])
def list_orders(request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    orders = db.query(Order).filter(
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).order_by(Order.created_at.desc()).all()
    return [_order_to_response(o) for o in orders]


@router.get("/orders/{order_id}", response_model=OrderResponse)
def get_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    order = _get_order_or_404(order_id, user_id, db)
    return _order_to_response(order)


@router.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(body: OrderCreateRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    addr = _get_address_or_404(body.address_id, user_id, db)

    cart_items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()

    if not cart_items:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cart is empty")

    total = Decimal("0.00")
    order_items_data = []

    for ci in cart_items:
        product = _get_product_or_404(str(ci.product_id), db)
        if product.stock < ci.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {product.name}",
            )
        subtotal = product.price * ci.quantity
        total += subtotal
        order_items_data.append({
            "product_id": product.id,
            "product_name": product.name,
            "product_price": product.price,
            "quantity": ci.quantity,
            "subtotal": subtotal,
        })

    order = Order(
        user_id=user_id,
        address_id=addr.id,
        total_amount=total + (body.delivery_fee or Decimal("0.00")),
        payment_method=body.payment_method,
    )
    db.add(order)
    db.flush()

    for oi_data in order_items_data:
        oi = OrderItem(order_id=order.id, **oi_data)
        db.add(oi)
        product = _get_product_or_404(str(oi_data["product_id"]), db)
        product.stock -= oi_data["quantity"]

    for ci in cart_items:
        ci.is_deleted = True

    db.commit()
    db.refresh(order)
    return _order_to_response(order)


@router.post("/orders/direct", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order_direct(body: OrderDirectCreateRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    total = Decimal("0.00")
    order_items_data = []

    for item in body.items:
        product = _get_product_or_404(item.product_id, db)
        if product.stock < item.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {product.name}",
            )
        subtotal = product.price * item.quantity
        total += subtotal
        order_items_data.append({
            "product_id": product.id,
            "product_name": product.name,
            "product_price": product.price,
            "quantity": item.quantity,
            "subtotal": subtotal,
        })

    address_id = body.address_id
    if address_id:
        addr = db.query(Address).filter(
            Address.id == address_id,
            Address.user_id == user_id,
            Address.is_deleted == False,
        ).first()
        if not addr:
            address_id = None
        else:
            # Server-side delivery zone validation
            if addr.latitude is not None and addr.longitude is not None:
                zones = db.query(DeliveryZone).filter(
                    DeliveryZone.is_deleted == False,
                    DeliveryZone.is_active == True,
                ).all()
                if zones:
                    from shapely.geometry import shape as shapely_shape
                    from shapely.geometry import Point
                    point = Point(float(addr.longitude), float(addr.latitude))
                    in_zone = False
                    for z in zones:
                        try:
                            geom = json.loads(z.geojson_data)
                            polygon = shapely_shape(geom)
                            if polygon.contains(point):
                                in_zone = True
                                break
                        except Exception:
                            continue
                    if not in_zone:
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail="Delivery not available in your area",
                        )

    order = Order(
        user_id=user_id,
        address_id=address_id,
        total_amount=total + (body.delivery_fee or Decimal("0.00")),
        payment_method=body.payment_method,
    )
    db.add(order)
    db.flush()

    for oi_data in order_items_data:
        oi = OrderItem(order_id=order.id, **oi_data)
        db.add(oi)
        product = _get_product_or_404(str(oi_data["product_id"]), db)
        product.stock -= oi_data["quantity"]

    payment = Payment(
        order_id=order.id,
        user_id=user_id,
        method=body.payment_method,
        status="success",
        amount=total,
    )
    payment.transaction_id = str(uuid.uuid4()).replace("-", "")[:16].upper()
    db.add(payment)

    db.commit()
    db.refresh(order)
    return _order_to_response(order)


# ─── PAYMENTS ─────────────────────────────────────────────────────
# Security: NEVER accept or store card numbers, CVV, bank details.
# Only COD (Cash on Delivery) is supported.

PAYMENT_TIMEOUT_SECONDS = 60


def _payment_to_response(payment: Payment) -> PaymentResponse:
    expires_at = payment.created_at + timedelta(seconds=PAYMENT_TIMEOUT_SECONDS)
    return PaymentResponse(
        id=str(payment.id),
        order_id=str(payment.order_id),
        amount=float(payment.amount),
        method=payment.method,
        status=payment.status,
        transaction_id=payment.transaction_id,
        expires_at=expires_at,
        created_at=payment.created_at,
    )


def _check_payment_expiry(payment: Payment, db: Session):
    if payment.status != "pending":
        return
    elapsed = (datetime.now(timezone.utc) - payment.created_at).total_seconds()
    if elapsed >= PAYMENT_TIMEOUT_SECONDS:
        payment.status = "failed"
        payment.transaction_id = None
        db.commit()
        db.refresh(payment)


@router.post("/payments/process", response_model=PaymentResponse)
def process_payment(body: PaymentProcessRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    order = db.query(Order).filter(
        Order.id == body.order_id,
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    if order.status != "Pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Payment already processed")

    existing_payment = db.query(Payment).filter(
        Payment.order_id == order.id,
        Payment.is_deleted == False,
    ).first()
    if existing_payment:
        return _payment_to_response(existing_payment)

    payment = Payment(
        order_id=order.id,
        user_id=user_id,
        amount=order.total_amount,
        method=body.method,
        status="completed",
        transaction_id="COD" + datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S") + str(uuid.uuid4()).split("-")[0],
    )
    order.status = "Confirmed"
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return _payment_to_response(payment)


@router.get("/payments/{order_id}", response_model=PaymentResponse)
def get_payment(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    payment = db.query(Payment).filter(
        Payment.order_id == order_id,
        Payment.user_id == user_id,
        Payment.is_deleted == False,
    ).first()
    if not payment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    return _payment_to_response(payment)


@router.get("/offers", response_model=list[OfferResponse])
def list_active_offers(db: Session = Depends(get_db)):
    offers = db.query(Offer).filter(
        Offer.is_deleted == False, Offer.is_active == True,
    ).order_by(Offer.created_at.desc()).all()
    return [
        OfferResponse(
            id=str(o.id), name=o.name, description=o.description,
            discount_percent=o.discount_percent, image_url=o.image_url,
            is_active=o.is_active, created_at=o.created_at,
        ) for o in offers
    ]


@router.post("/check-zone", response_model=ZoneCheckResponse)
def check_delivery_zone(body: ZoneCheckRequest, db: Session = Depends(get_db)):
    try:
        zones = db.query(DeliveryZone).filter(
            DeliveryZone.is_deleted == False,
            DeliveryZone.is_active == True,
        ).all()
        if not zones:
            return ZoneCheckResponse(serviceable=True, message="No zones configured — allowing all areas")

        from shapely.geometry import shape as shapely_shape
        from shapely.geometry import Point

        point = Point(body.lng, body.lat)
        for z in zones:
            geom = json.loads(z.geojson_data)
            polygon = shapely_shape(geom)
            if polygon.contains(point):
                return ZoneCheckResponse(serviceable=True)
        return ZoneCheckResponse(serviceable=False, message="Sorry, delivery not available in your area")
    except Exception:
        # Fail open: if zones can't be verified (table missing, no zones, etc.),
        # allow delivery everywhere rather than blocking the whole app.
        return ZoneCheckResponse(serviceable=True, message="No delivery zones configured — allowing all areas")


class DeliveryFeeRequest(BaseModel):
    subtotal: Decimal


@router.post("/delivery-fee")
def get_delivery_fee(body: DeliveryFeeRequest, db: Session = Depends(get_db)):
    fee = db.query(DeliveryFee).filter(
        DeliveryFee.is_deleted == False,
        DeliveryFee.is_active == True,
        DeliveryFee.min_order_amount <= body.subtotal,
    ).order_by(DeliveryFee.min_order_amount.desc()).first()
    if not fee:
        return {"fee": 0, "message": "Free delivery"}
    if fee.max_order_amount is not None and body.subtotal > fee.max_order_amount:
        return {"fee": 0, "message": "Free delivery"}
    return {"fee": float(fee.fee), "message": "Delivery fee applied"}


# ─── COMBO PACKS ──────────────────────────────────────────────────


def _pack_to_response(pack: ComboPack) -> dict:
    items = []
    for pi in pack.items:
        if not pi.is_deleted:
            prod = pi.product
            items.append({
                "id": str(pi.id),
                "product_id": str(pi.product_id),
                "product_name": prod.name if prod else "",
                "product_price": float(prod.price) if prod else 0,
                "product_unit": prod.unit if prod else "",
                "product_image": prod.images[0].image_url if prod and prod.images else None,
                "quantity": pi.quantity,
            })
    return {
        "id": str(pack.id),
        "name": pack.name,
        "description": pack.description,
        "image_url": pack.image_url,
        "total_price": float(pack.total_price),
        "discount_label": pack.discount_label,
        "savings_text": pack.savings_text,
        "is_enabled": pack.is_enabled,
        "items": items,
        "created_at": pack.created_at,
    }


@router.get("/combo-packs")
def list_combo_packs(db: Session = Depends(get_db)):
    packs = db.query(ComboPack).filter(
        ComboPack.is_deleted == False,
        ComboPack.is_enabled == True,
    ).order_by(ComboPack.name).all()

    result = []
    for pack in packs:
        # Check if all items have sufficient stock
        all_in_stock = True
        for pi in pack.items:
            if not pi.is_deleted and pi.product:
                if pi.product.stock < pi.quantity:
                    all_in_stock = False
                    break
        if not all_in_stock:
            continue
        result.append(_pack_to_response(pack))
    return result


@router.post("/combo-packs/add-to-cart", status_code=status.HTTP_200_OK)
def add_pack_to_cart(body: PackAddRequest, request: Request, db: Session = Depends(get_db)):
    user_id = _get_user_id(request)
    _get_user(user_id, db)

    pack = db.query(ComboPack).filter(
        ComboPack.id == body.pack_id,
        ComboPack.is_deleted == False,
        ComboPack.is_enabled == True,
    ).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")

    added = []
    for pi in pack.items:
        if pi.is_deleted:
            continue
        prod = _get_product_or_404(str(pi.product_id), db)
        if prod.stock < pi.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {prod.name}",
            )
        existing = db.query(CartItem).filter(
            CartItem.user_id == user_id,
            CartItem.product_id == pi.product_id,
            CartItem.is_deleted == False,
        ).first()
        if existing:
            existing.quantity += pi.quantity
            db.flush()
        else:
            soft = db.query(CartItem).filter(
                CartItem.user_id == user_id,
                CartItem.product_id == pi.product_id,
                CartItem.is_deleted == True,
            ).first()
            if soft:
                soft.is_deleted = False
                soft.quantity = pi.quantity
                db.flush()
            else:
                item = CartItem(user_id=user_id, product_id=pi.product_id, quantity=pi.quantity)
                db.add(item)
                db.flush()
        added.append({
            "product_id": str(pi.product_id),
            "product_name": prod.name,
            "quantity": pi.quantity,
        })
    db.commit()
    return {"message": "Pack added to cart", "items": added}
