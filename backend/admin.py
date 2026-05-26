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
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from database import get_db
from models import User, Category, Product, ProductImage, Address, Order, Payment, DeliveryZone
from schemas import (
    CategoryCreate, CategoryResponse,
    ProductCreate, ProductResponse,
    StatusUpdateRequest, MessageResponse,
    DeliveryZoneCreate,
)

router = APIRouter(prefix="/api/admin")


def _require_admin(request: Request) -> str:
    role = getattr(request.state, "user_role", None)
    user_id = getattr(request.state, "user_id", None)
    if role != "admin" or not user_id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user_id


# ─── STATS ────────────────────────────────────────────────────────

@router.get("/stats")
def dashboard_stats(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    products = db.query(Product).filter(Product.is_deleted == False).count()
    categories = db.query(Category).filter(Category.is_deleted == False).count()
    orders = db.query(Order).filter(Order.is_deleted == False).count()
    users = db.query(User).filter(User.is_deleted == False).count()
    delivered = db.query(Order).filter(Order.is_deleted == False, Order.status == "Delivered").with_entities(Order.total_amount).all()
    total = sum(float(r[0]) for r in delivered) if delivered else 0.0
    return {
        "products": products,
        "categories": categories,
        "orders": orders,
        "users": users,
        "revenue": round(total, 2),
    }


@router.get("/products", response_model=list[ProductResponse])
def list_products(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    products = db.query(Product).filter(Product.is_deleted == False).order_by(Product.name).all()
    return [
        ProductResponse(
            id=str(p.id), category_id=str(p.category_id),
            category_name=p.category.name if p.category else None,
            name=p.name, description=p.description,
            price=float(p.price), unit=p.unit,
            images=[img.image_url for img in p.images],
            stock=p.stock,
        ) for p in products
    ]


@router.post("/products", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(body: ProductCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    cat = db.query(Category).filter(Category.id == body.category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    product = Product(
        category_id=body.category_id, name=body.name.strip(),
        description=body.description.strip() if body.description else None,
        price=body.price, unit=body.unit.strip().lower(),
        stock=body.stock,
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
        price=float(product.price), unit=product.unit,
        images=[img.image_url for img in product.images],
        stock=product.stock,
    )


@router.put("/products/{product_id}", response_model=ProductResponse)
def update_product(product_id: str, body: ProductCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
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
        price=float(product.price), unit=product.unit,
        images=[img.image_url for img in product.images],
        stock=product.stock,
    )


@router.delete("/products/{product_id}", response_model=MessageResponse)
def delete_product(product_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.is_deleted = True
    db.commit()
    return MessageResponse(message="Product deleted")


@router.get("/categories", response_model=list[CategoryResponse])
def list_categories(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    cats = db.query(Category).filter(Category.is_deleted == False).order_by(Category.name).all()
    return [CategoryResponse(id=str(c.id), name=c.name, description=c.description, image=c.image) for c in cats]


@router.post("/categories", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(body: CategoryCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
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
    _require_admin(request)
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


@router.delete("/categories/{category_id}", response_model=MessageResponse)
def delete_category(category_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    cat = db.query(Category).filter(Category.id == category_id, Category.is_deleted == False).first()
    if not cat:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Category not found")
    has_products = db.query(Product).filter(Product.category_id == category_id, Product.is_deleted == False).first()
    if has_products:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete category with existing products")
    cat.is_deleted = True
    db.commit()
    return MessageResponse(message="Category deleted")


@router.get("/orders")
def list_orders(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    orders = db.query(Order).filter(Order.is_deleted == False).order_by(Order.created_at.desc()).all()
    result = []
    for o in orders:
        items = []
        for oi in o.items:
            if not oi.is_deleted:
                items.append({
                    "id": str(oi.id), "product_id": str(oi.product_id),
                    "product_name": oi.product_name, "product_price": float(oi.product_price),
                    "quantity": oi.quantity, "subtotal": float(oi.subtotal),
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
            "total_amount": float(o.total_amount), "payment_method": o.payment_method,
            "items": items, "created_at": o.created_at,
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
    _require_admin(request)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    order.status = body.status
    db.commit()
    return MessageResponse(message=f"Order status updated to {body.status}")


@router.delete("/orders/{order_id}", response_model=MessageResponse)
def delete_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    order.is_deleted = True
    db.commit()
    return MessageResponse(message="Order deleted")


@router.delete("/users/{user_id}", response_model=MessageResponse)
def delete_user(user_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.is_deleted = True
    db.commit()
    return MessageResponse(message="User deleted")


@router.get("/users")
def list_users(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
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
    _require_admin(request)
    zone = DeliveryZone(
        zone_name=body.zone_name,
        geojson_data=body.geojson_data,
    )
    db.add(zone)
    db.commit()
    return MessageResponse(message=f"Delivery zone '{body.zone_name}' created")


@router.get("/delivery-zones")
def list_delivery_zones(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
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
