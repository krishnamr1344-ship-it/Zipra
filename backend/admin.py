"""
admin.py
Purpose: Admin-only CRUD endpoints for managing products, categories,
         orders, users, and viewing dashboard stats.
Security:
  - Every endpoint checks that the user has role="admin".
  - Input validated by Pydantic before DB access.
  - Soft-delete used everywhere.
  - No sensitive user data exposed (no password hashes).
"""
import logging
import uuid
logger = logging.getLogger(__name__)

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy import text
from sqlalchemy.orm import Session

from database import get_db
from models import User, Category, Product, ProductImage, ProductFlag, Address, Order, Payment, DeliveryZone, ComboPack, ComboPackItem, Banner, Notification, AppSetting
from resources import _validate_order_transition
from pydantic import BaseModel
from schemas import (
    CategoryCreate, CategoryResponse,
    ProductCreate, ProductResponse,
    StatusUpdateRequest, MessageResponse, DeliveryVerifyRequest,
    DeliveryZoneCreate,
    ComboPackCreate, ComboPackUpdate, ComboPackResponse, ComboPackItemResponse, ComboPackItemInput,
    NotificationCreate, NotificationResponse,
    BannerCreate, BannerUpdate, BannerResponse,
)

class SeedCatalogItem(BaseModel):
    name: str
    unit: str
    price: float
    mrp: float
    stock: int
    description: str
    image: str

class SeedCategory(BaseModel):
    name: str
    icon: str
    products: list[SeedCatalogItem]

class SeedCatalogRequest(BaseModel):
    categories: list[SeedCategory]

router = APIRouter(prefix="/api/admin")


def _require_admin(request: Request, db: Session = None) -> str:
    role = getattr(request.state, "user_role", None)
    user_id = getattr(request.state, "user_id", None)
    if role != "admin" or not user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    if db is not None:
        user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
        if not user or user.role != "admin":
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user_id


def _validate_uuid(uuid_str: str) -> str:
    try:
        uuid.UUID(uuid_str)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid ID format")
    return uuid_str


# ─── STATS ────────────────────────────────────────────────────────

@router.get("/stats")
def dashboard_stats(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    products = db.query(Product).filter(Product.is_deleted == False).count()
    categories = db.query(Category).filter(Category.is_deleted == False).count()
    orders = db.query(Order).filter(Order.is_deleted == False).count()
    users = db.query(User).filter(User.is_deleted == False).count()
    delivered = db.query(Order).filter(Order.is_deleted == False, Order.status == "Delivered").with_entities(Order.total_amount).all()
    total = sum(round(float(r[0]), 2) for r in delivered) if delivered else 0.0
    return {
        "products": products,
        "categories": categories,
        "orders": orders,
        "users": users,
        "revenue": round(total, 2),
    }


@router.get("/products", response_model=list[ProductResponse])
def list_products(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    products = db.query(Product).filter(Product.is_deleted == False).order_by(Product.name).all()
    return [
        ProductResponse(
            id=str(p.id), category_id=str(p.category_id),
            category_name=p.category.name if p.category else None,
            name=p.name, description=p.description,
            price=round(float(p.price), 2), unit=p.unit,
            images=[img.image_url for img in p.images if not img.is_deleted],
            stock=p.stock, discount_percent=p.discount_percent,
            is_enabled=p.flag.is_enabled if p.flag else True,
        ) for p in products
    ]


@router.post("/products", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(body: ProductCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    cat = db.query(Category).filter(Category.id == body.category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    product = Product(
        category_id=body.category_id, name=body.name.strip(),
        description=body.description.strip() if body.description else None,
        price=body.price, unit=body.unit.strip().lower(),
        stock=body.stock, discount_percent=body.discount_percent,
    )
    db.add(product)
    db.flush()
    for i, url in enumerate(body.images):
        db.add(ProductImage(product_id=product.id, image_url=url.strip(), sort_order=i))
    db.commit()
    db.refresh(product)
    return ProductResponse(
        id=str(product.id), category_id=str(product.category_id),
        category_name=cat.name,
        name=product.name, description=product.description,
        price=round(float(product.price), 2), unit=product.unit,
        images=[img.image_url for img in product.images if not img.is_deleted],
        stock=product.stock, discount_percent=product.discount_percent,
        is_enabled=product.flag.is_enabled if product.flag else True,
    )


# ─── CATEGORIES ────────────────────────────────────────────────────

@router.get("/categories", response_model=list[CategoryResponse])


# ─── PRODUCTS (update / delete) ────────────────────────────────────

@router.put("/products/{product_id}", response_model=ProductResponse)
def update_product(product_id: str, body: ProductCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(product_id)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    cat = db.query(Category).filter(Category.id == body.category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    product.category_id = body.category_id
    product.name = body.name.strip()
    product.description = body.description.strip() if body.description else None
    product.price = body.price
    product.unit = body.unit.strip().lower()
    product.stock = body.stock
    product.discount_percent = body.discount_percent
    # Replace images
    for old_img in product.images:
        old_img.is_deleted = True
    for i, url in enumerate(body.images):
        db.add(ProductImage(product_id=product.id, image_url=url.strip(), sort_order=i))
    db.commit()
    db.refresh(product)
    return ProductResponse(
        id=str(product.id), category_id=str(product.category_id),
        category_name=cat.name,
        name=product.name, description=product.description,
        price=round(float(product.price), 2), unit=product.unit,
        images=[img.image_url for img in product.images if not img.is_deleted],
        stock=product.stock, discount_percent=product.discount_percent,
        is_enabled=product.flag.is_enabled if product.flag else True,
    )


@router.put("/products/{product_id}/toggle")
def toggle_product(product_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(product_id)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    flag = product.flag
    if not flag:
        flag = ProductFlag(product_id=product.id)
        db.add(flag)
    flag.is_enabled = not flag.is_enabled
    db.commit()
    return {"is_enabled": flag.is_enabled, "message": f"Product {'enabled' if flag.is_enabled else 'disabled'}"}


@router.delete("/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(product_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(product_id)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.is_deleted = True
    db.commit()


@router.get("/categories", response_model=list[CategoryResponse])
def list_categories(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    cats = db.query(Category).filter(Category.is_deleted == False).order_by(Category.name).all()
    return [CategoryResponse(id=str(c.id), name=c.name, description=c.description, image=c.image) for c in cats]


@router.post("/categories", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(body: CategoryCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    existing = db.query(Category).filter(Category.name == body.name.strip(), Category.is_deleted == False).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Category already exists")
    cat = Category(
        name=body.name.strip(),
        description=body.description.strip() if body.description else None,
        image=body.image.strip() if body.image else None,
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return CategoryResponse(id=str(cat.id), name=cat.name, description=cat.description, image=cat.image)


@router.put("/categories/{category_id}", response_model=CategoryResponse)
def update_category(category_id: str, body: CategoryCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(category_id)
    cat = db.query(Category).filter(Category.id == category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    dup = db.query(Category).filter(Category.name == body.name.strip(), Category.id != category_id, Category.is_deleted == False).first()
    if dup:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Category name already taken")
    cat.name = body.name.strip()
    cat.description = body.description.strip() if body.description else None
    cat.image = body.image.strip() if body.image else None
    db.commit()
    db.refresh(cat)
    return CategoryResponse(id=str(cat.id), name=cat.name, description=cat.description, image=cat.image)


@router.delete("/categories/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(category_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(category_id)
    cat = db.query(Category).filter(Category.id == category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    has_products = db.query(Product).filter(Product.category_id == category_id, Product.is_deleted == False).first()
    if has_products:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete category with existing products")
    cat.is_deleted = True
    db.commit()


@router.get("/orders")
def list_orders(request: Request, db: Session = Depends(get_db), status: str = None):
    _require_admin(request, db)
    query = db.query(Order).filter(Order.is_deleted == False)
    if status:
        valid = {"Pending", "Confirmed", "Shipped", "Out For Delivery", "Delivered", "Cancelled", "Failed"}
        if status not in valid:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Invalid status. Must be one of: {', '.join(sorted(valid))}")
        query = query.filter(Order.status == status)
    else:
        query = query.filter(Order.status != "Failed")
    orders = query.order_by(Order.created_at.desc()).all()
    result = []
    for o in orders:
        items = []
        for oi in o.items:
            if not oi.is_deleted:
                items.append({
                    "id": str(oi.id), "product_id": str(oi.product_id),
                    "product_name": oi.product_name,                     "product_price": round(float(oi.product_price), 2),
                    "quantity": oi.quantity, "subtotal": round(float(oi.subtotal), 2),
                })
        delivery_address = None
        if o.address_id and o.address:
            maps = f"https://www.google.com/maps?q={o.address.latitude},{o.address.longitude}" if o.address.latitude and o.address.longitude else None
            delivery_address = {
                "address_line1": o.address.address_line1,
                "address_line2": o.address.address_line2,
                "city": o.address.city,
                "state": o.address.state,
                "pincode": o.address.pincode,
                "address_type": o.address.address_type,
                "house_number": o.address.house_number,
                "floor_number": o.address.floor_number,
                "landmark": o.address.landmark,
                "latitude": float(o.address.latitude) if o.address.latitude else None,
                "longitude": float(o.address.longitude) if o.address.longitude else None,
                "maps_link": maps,
            }
        user_name = o.user.name if o.user else None
        user_email = o.user.email if o.user else None
        user_phone = o.user.phone if o.user else None
        user_id = str(o.user_id) if o.user_id else None
        user_gps = None
        if o.user_id:
            gps_addr = db.query(Address).filter(
                Address.user_id == o.user_id,
                Address.label == "GPS Location",
                Address.is_deleted == False,
            ).first()
            if gps_addr:
                gmaps = f"https://www.google.com/maps?q={gps_addr.latitude},{gps_addr.longitude}" if gps_addr.latitude and gps_addr.longitude else None
                user_gps = {
                    "address_line1": gps_addr.address_line1,
                    "address_line2": gps_addr.address_line2,
                    "city": gps_addr.city,
                    "state": gps_addr.state,
                    "pincode": gps_addr.pincode,
                    "address_type": gps_addr.address_type,
                    "house_number": gps_addr.house_number,
                    "floor_number": gps_addr.floor_number,
                    "landmark": gps_addr.landmark,
                    "latitude": float(gps_addr.latitude) if gps_addr.latitude else None,
                    "longitude": float(gps_addr.longitude) if gps_addr.longitude else None,
                    "maps_link": gmaps,
                }
        result.append({
            "id": str(o.id), "status": o.status,
            "total_amount": round(float(o.total_amount), 2), "payment_method": o.payment_method,
            "items": items, "created_at": o.created_at,
            "delivery_otp": o.delivery_otp,
            "user_id": user_id,
            "user_name": user_name,
            "user_email": user_email,
            "user_phone": user_phone,
            "user_gps_address": user_gps,
            "delivery_address": delivery_address,
        })
    return result


@router.put("/orders/{order_id}/status", response_model=MessageResponse)
def update_order_status(order_id: str, body: StatusUpdateRequest, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(order_id)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if order.status == "Failed":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot modify a failed payment order")
    if order.status == "Delivered":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Order is already delivered and cannot be modified")
    if body.status == "Delivered":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Use the delivery verification endpoint to mark orders as delivered")
    _validate_order_transition(order.status, body.status)
    if body.status == "Cancelled" and order.status != "Cancelled":
        for oi in order.items:
            if not oi.is_deleted:
                product = db.query(Product).filter(Product.id == oi.product_id, Product.is_deleted == False).first()
                if product:
                    product.stock += oi.quantity
    order.status = body.status
    db.commit()
    return MessageResponse(message=f"Order status updated to {body.status}")


@router.delete("/orders/{order_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(order_id)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    order.is_deleted = True
    db.commit()


@router.post("/orders/{order_id}/deliver", response_model=MessageResponse)
def deliver_order(order_id: str, body: DeliveryVerifyRequest, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(order_id)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if order.status == "Delivered":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Order is already delivered")
    if order.status != "Out For Delivery":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Order must be 'Out For Delivery' before delivery can be confirmed")
    if not order.delivery_otp:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No delivery code assigned to this order")
    if order.delivery_otp != body.otp:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid delivery code")
    order.status = "Delivered"
    order.delivery_otp = None
    db.commit()
    return MessageResponse(message="Order delivered successfully")


@router.get("/users")
def list_users(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    users = db.query(User).filter(User.is_deleted == False).order_by(User.created_at.desc()).all()
    result = []
    for u in users:
        gps_addr = db.query(Address).filter(
            Address.user_id == u.id,
            Address.label == "GPS Location",
            Address.is_deleted == False,
        ).first()
        addr_info = None
        if gps_addr:
            gmaps = f"https://www.google.com/maps?q={gps_addr.latitude},{gps_addr.longitude}" if gps_addr.latitude and gps_addr.longitude else None
            addr_info = {
                "address_line1": gps_addr.address_line1,
                "address_line2": gps_addr.address_line2,
                "city": gps_addr.city,
                "state": gps_addr.state,
                "pincode": gps_addr.pincode,
                "address_type": gps_addr.address_type,
                "house_number": gps_addr.house_number,
                "floor_number": gps_addr.floor_number,
                "landmark": gps_addr.landmark,
                "latitude": float(gps_addr.latitude) if gps_addr.latitude else None,
                "longitude": float(gps_addr.longitude) if gps_addr.longitude else None,
                "maps_link": gmaps,
            }
        result.append({
            "id": str(u.id),
            "name": u.name,
            "email": u.email,
            "phone": u.phone,
            "role": u.role,
            "created_at": u.created_at,
            "gps_address": addr_info,
        })
    return result


@router.post("/delivery-zone", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def create_delivery_zone(body: DeliveryZoneCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    zone = DeliveryZone(
        zone_name=body.zone_name,
        geojson_data=body.geojson_data,
    )
    db.add(zone)
    db.commit()
    return MessageResponse(message=f"Delivery zone '{body.zone_name}' created")


# ─── COMBO PACKS (Admin) ─────────────────────────────────────────


def _pack_to_admin_response(pack: ComboPack) -> dict:
    items = []
    for pi in pack.items:
        if not pi.is_deleted:
            prod = pi.product
            items.append({
                "id": str(pi.id),
                "product_id": str(pi.product_id),
                "product_name": prod.name if prod else "",
                "product_price": round(float(prod.price), 2) if prod else 0,
                "product_unit": prod.unit if prod else "",
                "product_image": next((img.image_url for img in prod.images if not img.is_deleted), None) if prod else None,
                "quantity": pi.quantity,
            })
    return {
        "id": str(pack.id),
        "name": pack.name,
        "description": pack.description,
        "image_url": pack.image_url,
        "total_price": round(float(pack.total_price), 2),
        "discount_label": pack.discount_label,
        "savings_text": pack.savings_text,
        "is_enabled": pack.is_enabled,
        "items": items,
        "created_at": pack.created_at,
    }


@router.get("/combo-packs")
def list_combo_packs_admin(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    packs = db.query(ComboPack).filter(ComboPack.is_deleted == False).order_by(ComboPack.name).all()
    return [_pack_to_admin_response(p) for p in packs]


@router.post("/combo-packs", status_code=status.HTTP_201_CREATED)
def create_combo_pack(body: ComboPackCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    pack = ComboPack(
        name=body.name.strip(),
        description=body.description.strip() if body.description else None,
        image_url=body.image_url.strip() if body.image_url else None,
        total_price=body.total_price,
        discount_label=body.discount_label.strip() if body.discount_label else None,
        savings_text=body.savings_text.strip() if body.savings_text else None,
    )
    db.add(pack)
    db.flush()
    for item in body.items:
        product = db.query(Product).filter(Product.id == item.product_id, Product.is_deleted == False).first()
        if not product:
            db.rollback()
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Product {item.product_id} not found")
        db.add(ComboPackItem(pack_id=pack.id, product_id=product.id, quantity=item.quantity))
    db.commit()
    db.refresh(pack)
    return _pack_to_admin_response(pack)


@router.put("/combo-packs/{pack_id}")
def update_combo_pack(pack_id: str, body: ComboPackUpdate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(pack_id)
    pack = db.query(ComboPack).filter(ComboPack.id == pack_id, ComboPack.is_deleted == False).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")
    if body.name is not None:
        pack.name = body.name.strip()
    if body.description is not None:
        pack.description = body.description.strip() if body.description else None
    if body.image_url is not None:
        pack.image_url = body.image_url.strip() if body.image_url else None
    if body.total_price is not None:
        pack.total_price = body.total_price
    if body.discount_label is not None:
        pack.discount_label = body.discount_label.strip() if body.discount_label else None
    if body.savings_text is not None:
        pack.savings_text = body.savings_text.strip() if body.savings_text else None
    if body.is_enabled is not None:
        pack.is_enabled = body.is_enabled
    if body.items is not None:
        for old in pack.items:
            old.is_deleted = True
        for item in body.items:
            product = db.query(Product).filter(Product.id == item.product_id, Product.is_deleted == False).first()
            if not product:
                db.rollback()
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Product {item.product_id} not found")
            db.add(ComboPackItem(pack_id=pack.id, product_id=product.id, quantity=item.quantity))
    db.commit()
    db.refresh(pack)
    return _pack_to_admin_response(pack)


@router.delete("/combo-packs/{pack_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_combo_pack(pack_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(pack_id)
    pack = db.query(ComboPack).filter(ComboPack.id == pack_id, ComboPack.is_deleted == False).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")
    pack.is_deleted = True
    db.commit()


@router.put("/combo-packs/{pack_id}/toggle")
def toggle_combo_pack(pack_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(pack_id)
    pack = db.query(ComboPack).filter(ComboPack.id == pack_id, ComboPack.is_deleted == False).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")
    pack.is_enabled = not pack.is_enabled
    db.commit()
    return {"is_enabled": pack.is_enabled, "message": f"Pack {'enabled' if pack.is_enabled else 'disabled'}"}


@router.get("/delivery-zones")
def list_delivery_zones(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    zones = db.query(DeliveryZone).filter(DeliveryZone.is_deleted == False, DeliveryZone.is_active == True).all()
    return [
        {
            "id": str(z.id),
            "zone_name": z.zone_name,
            "geojson_data": z.geojson_data,
            "created_at": z.created_at,
        }
        for z in zones
    ]


@router.put("/delivery-zones/{zone_id}", response_model=MessageResponse)
def update_delivery_zone(zone_id: str, body: DeliveryZoneCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(zone_id)
    zone = db.query(DeliveryZone).filter(DeliveryZone.id == zone_id, DeliveryZone.is_deleted == False).first()
    if not zone:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery zone not found")
    zone.zone_name = body.zone_name
    zone.geojson_data = body.geojson_data
    db.commit()
    return MessageResponse(message=f"Delivery zone '{body.zone_name}' updated")


@router.delete("/delivery-zones/{zone_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_delivery_zone(zone_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(zone_id)
    zone = db.query(DeliveryZone).filter(DeliveryZone.id == zone_id, DeliveryZone.is_deleted == False).first()
    if not zone:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery zone not found")
    zone.is_deleted = True
    db.commit()


# ─── NOTIFICATIONS ────────────────────────────────────────────────


@router.get("/notifications", response_model=list[NotificationResponse])
def list_admin_notifications(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    notifications = db.query(Notification).filter(
        Notification.is_deleted == False,
    ).order_by(Notification.created_at.desc()).limit(100).all()
    return [
        NotificationResponse(
            id=str(n.id),
            title=n.title,
            message=n.message,
            type=n.type,
            image_url=n.image_url,
            link=n.link,
            created_at=n.created_at,
        ) for n in notifications
    ]


@router.post("/notifications", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED)
def create_notification(body: NotificationCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    notif = Notification(
        title=body.title.strip(),
        message=body.message.strip() if body.message else None,
        type=body.type,
        image_url=body.image_url.strip() if body.image_url else None,
        link=body.link.strip() if body.link else None,
    )
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return NotificationResponse(
        id=str(notif.id),
        title=notif.title,
        message=notif.message,
        type=notif.type,
        image_url=notif.image_url,
        link=notif.link,
        created_at=notif.created_at,
    )


@router.delete("/notifications/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_notification(notification_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    notif = db.query(Notification).filter(Notification.id == notification_id, Notification.is_deleted == False).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_deleted = True
    db.commit()


# ─── BANNERS ──────────────────────────────────────────────────────


@router.get("/banners", response_model=list[BannerResponse])
def list_banners(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    banners = db.query(Banner).filter(
        Banner.is_deleted == False,
    ).order_by(Banner.sort_order, Banner.created_at.desc()).all()
    return [
        BannerResponse(
            id=str(b.id),
            title=b.title,
            subtitle=b.subtitle,
            image_url=b.image_url,
            link=b.link,
            color=b.color,
            is_active=b.is_active,
            sort_order=b.sort_order,
            created_at=b.created_at,
        ) for b in banners
    ]


@router.post("/banners", response_model=BannerResponse, status_code=status.HTTP_201_CREATED)
def create_banner(body: BannerCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    banner = Banner(
        title=body.title.strip(),
        subtitle=body.subtitle.strip() if body.subtitle else None,
        image_url=body.image_url.strip() if body.image_url else None,
        link=body.link.strip() if body.link else None,
        color=body.color,
        is_active=body.is_active,
        sort_order=body.sort_order,
    )
    db.add(banner)
    db.commit()
    db.refresh(banner)
    return BannerResponse(
        id=str(banner.id),
        title=banner.title,
        subtitle=banner.subtitle,
        image_url=banner.image_url,
        link=banner.link,
        color=banner.color,
        is_active=banner.is_active,
        sort_order=banner.sort_order,
        created_at=banner.created_at,
    )


@router.put("/banners/{banner_id}", response_model=BannerResponse)
def update_banner(banner_id: str, body: BannerUpdate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    banner = db.query(Banner).filter(Banner.id == banner_id, Banner.is_deleted == False).first()
    if not banner:
        raise HTTPException(status_code=404, detail="Banner not found")
    if body.title is not None:
        banner.title = body.title.strip()
    if body.subtitle is not None:
        banner.subtitle = body.subtitle.strip() if body.subtitle else None
    if body.image_url is not None:
        banner.image_url = body.image_url.strip() if body.image_url else None
    if body.link is not None:
        banner.link = body.link.strip() if body.link else None
    if body.color is not None:
        banner.color = body.color
    if body.is_active is not None:
        banner.is_active = body.is_active
    if body.sort_order is not None:
        banner.sort_order = body.sort_order
    db.commit()
    db.refresh(banner)
    return BannerResponse(
        id=str(banner.id),
        title=banner.title,
        subtitle=banner.subtitle,
        image_url=banner.image_url,
        link=banner.link,
        color=banner.color,
        is_active=banner.is_active,
        sort_order=banner.sort_order,
        created_at=banner.created_at,
    )


@router.delete("/banners/{banner_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_banner(banner_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    banner = db.query(Banner).filter(Banner.id == banner_id, Banner.is_deleted == False).first()
    if not banner:
        raise HTTPException(status_code=404, detail="Banner not found")
    banner.is_deleted = True
    db.commit()


class SettingsResponse(BaseModel):
    delivery_fee: int = 40
    free_delivery_threshold: int = 499


class SettingsUpdate(BaseModel):
    delivery_fee: int
    free_delivery_threshold: int


def _get_setting(db: Session, key: str, default: str) -> str:
    row = db.query(AppSetting).filter(AppSetting.key == key).first()
    return row.value if row else default


def _set_setting(db: Session, key: str, value: str):
    row = db.query(AppSetting).filter(AppSetting.key == key).first()
    if row:
        row.value = value
    else:
        db.add(AppSetting(key=key, value=value))
    db.commit()


@router.get("/settings", response_model=SettingsResponse)
def get_settings(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    fee_raw = _get_setting(db, "delivery_fee", "40")
    threshold_raw = _get_setting(db, "free_delivery_threshold", "499")
    return SettingsResponse(
        delivery_fee=int(fee_raw),
        free_delivery_threshold=int(threshold_raw),
    )


@router.put("/settings", response_model=SettingsResponse)
def update_settings(body: SettingsUpdate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _set_setting(db, "delivery_fee", str(body.delivery_fee))
    _set_setting(db, "free_delivery_threshold", str(body.free_delivery_threshold))
    return SettingsResponse(
        delivery_fee=body.delivery_fee,
        free_delivery_threshold=body.free_delivery_threshold,
    )
