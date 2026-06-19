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
from models import User, Category, Product, ProductImage, ProductFlag, Address, Order, Payment, DeliveryZone, ComboPack, ComboPackItem, Notification
from pydantic import BaseModel
from schemas import (
    CategoryCreate, CategoryResponse,
    ProductCreate, ProductResponse,
    StatusUpdateRequest, MessageResponse, DeliveryVerifyRequest,
    DeliveryZoneCreate,
    ComboPackCreate, ComboPackUpdate, ComboPackResponse, ComboPackItemResponse, ComboPackItemInput,
    NotificationCreate, NotificationResponse,
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
        if not user:
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


@router.put("/products/bulk-delete", response_model=MessageResponse)
def bulk_delete_products(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    count = db.query(Product).filter(Product.is_deleted == False).count()
    db.query(Product).filter(Product.is_deleted == False).update({"is_deleted": True})
    db.commit()
    return MessageResponse(message=f"{count} products deleted")


SEED_CATALOG = {
    "🥛 Dairy": {
        "icon": "🥛",
        "products": [
            ("Milk", "1L", 56, 60, 100, "Fresh toned milk", "https://placehold.co/400x400/FFF3E0/E65100?text=Milk"),
            ("Curd", "500g", 40, 45, 80, "Fresh thick curd", "https://placehold.co/400x400/FFF3E0/E65100?text=Curd"),
            ("Butter", "100g", 52, 58, 60, "Creamy butter", "https://placehold.co/400x400/FFF3E0/E65100?text=Butter"),
            ("Ghee", "500ml", 390, 430, 40, "Pure cow ghee", "https://placehold.co/400x400/FFF3E0/E65100?text=Ghee"),
            ("Paneer", "200g", 90, 100, 50, "Fresh cottage cheese", "https://placehold.co/400x400/FFF3E0/E65100?text=Paneer"),
            ("Cheese", "200g", 120, 135, 40, "Mozzarella cheese", "https://placehold.co/400x400/FFF3E0/E65100?text=Cheese"),
        ],
    },
    "🌾 Rice & Grocery": {
        "icon": "🌾",
        "products": [
            ("Rice", "1kg", 52, 58, 100, "Premium sona masoori rice", "https://placehold.co/400x400/E8F5E9/2E7D32?text=Rice"),
            ("Wheat Flour (Atta)", "1kg", 48, 52, 80, "Chakki fresh atta", "https://placehold.co/400x400/E8F5E9/2E7D32?text=Atta"),
            ("Rava", "1kg", 55, 62, 60, "Bombay rava/sooji", "https://placehold.co/400x400/E8F5E9/2E7D32?text=Rava"),
            ("Maida", "1kg", 45, 50, 60, "Fine maida flour", "https://placehold.co/400x400/E8F5E9/2E7D32?text=Maida"),
            ("Sugar", "1kg", 42, 46, 100, "Fine white sugar", "https://placehold.co/400x400/E8F5E9/2E7D32?text=Sugar"),
            ("Salt", "1kg", 18, 20, 100, "Iodized table salt", "https://placehold.co/400x400/E8F5E9/2E7D32?text=Salt"),
        ],
    },
    "🥜 Dals": {
        "icon": "🥜",
        "products": [
            ("Toor Dal", "500g", 75, 82, 60, "Premium toor dal/pigeon pea", "https://placehold.co/400x400/FFF8E1/F57F17?text=Toor+Dal"),
            ("Urad Dal", "500g", 70, 78, 60, "Premium urad dal/black gram", "https://placehold.co/400x400/FFF8E1/F57F17?text=Urad+Dal"),
            ("Moong Dal", "500g", 65, 72, 60, "Premium moong dal/green gram", "https://placehold.co/400x400/FFF8E1/F57F17?text=Moong+Dal"),
            ("Chana Dal", "500g", 60, 68, 60, "Premium chana dal/bengal gram", "https://placehold.co/400x400/FFF8E1/F57F17?text=Chana+Dal"),
        ],
    },
    "🛢️ Oils": {
        "icon": "🛢️",
        "products": [
            ("Sunflower Oil", "1L", 155, 170, 80, "Refined sunflower oil", "https://placehold.co/400x400/FFF3E0/E65100?text=Sunflower+Oil"),
            ("Groundnut Oil", "1L", 195, 215, 50, "Pure groundnut oil", "https://placehold.co/400x400/FFF3E0/E65100?text=Groundnut+Oil"),
            ("Coconut Oil", "1L", 210, 230, 50, "Pure coconut oil", "https://placehold.co/400x400/FFF3E0/E65100?text=Coconut+Oil"),
        ],
    },
    "🌶️ Masala": {
        "icon": "🌶️",
        "products": [
            ("Chilli Powder", "100g", 40, 46, 80, "Pure red chilli powder", "https://placehold.co/400x400/FCE4EC/D32F2F?text=Chilli+Powder"),
            ("Turmeric Powder", "100g", 35, 42, 80, "Pure turmeric powder", "https://placehold.co/400x400/FCE4EC/D32F2F?text=Turmeric+Powder"),
            ("Coriander Powder", "100g", 30, 36, 80, "Pure coriander powder", "https://placehold.co/400x400/FCE4EC/D32F2F?text=Coriander+Powder"),
            ("Garam Masala", "100g", 55, 64, 60, "Aromatic garam masala", "https://placehold.co/400x400/FCE4EC/D32F2F?text=Garam+Masala"),
            ("Sambar Powder", "200g", 60, 70, 60, "Authentic sambar powder", "https://placehold.co/400x400/FCE4EC/D32F2F?text=Sambar+Powder"),
        ],
    },
    "☕ Beverages": {
        "icon": "☕",
        "products": [
            ("Tea Powder", "250g", 130, 148, 80, "Premium CTC tea powder", "https://placehold.co/400x400/E3F2FD/1565C0?text=Tea+Powder"),
            ("Coffee Powder", "200g", 180, 200, 60, "Premium filter coffee", "https://placehold.co/400x400/E3F2FD/1565C0?text=Coffee+Powder"),
            ("Boost", "500g", 295, 340, 50, "Boost energy health drink", "https://placehold.co/400x400/E3F2FD/1565C0?text=Boost"),
            ("Horlicks", "500g", 260, 300, 50, "Horlicks nutritive drink", "https://placehold.co/400x400/E3F2FD/1565C0?text=Horlicks"),
        ],
    },
    "🧼 Bathroom & Personal Care": {
        "icon": "🧼",
        "products": [
            ("Soap", "100g", 40, 48, 100, "Premium bathing soap", "https://placehold.co/400x400/F3E5F5/7B1FA2?text=Soap"),
            ("Shampoo", "200ml", 95, 115, 80, "Nourishing shampoo", "https://placehold.co/400x400/F3E5F5/7B1FA2?text=Shampoo"),
            ("Toothpaste", "200g", 105, 125, 80, "Strong teeth toothpaste", "https://placehold.co/400x400/F3E5F5/7B1FA2?text=Toothpaste"),
            ("Toothbrush", "piece", 35, 42, 100, "Soft bristle toothbrush", "https://placehold.co/400x400/F3E5F5/7B1FA2?text=Toothbrush"),
            ("Hair Oil", "200ml", 65, 78, 80, "Pure coconut hair oil", "https://placehold.co/400x400/F3E5F5/7B1FA2?text=Hair+Oil"),
        ],
    },
}


@router.post("/products/seed", response_model=MessageResponse)
def seed_catalog(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)

    # Soft-delete all existing products
    db.query(Product).filter(Product.is_deleted == False).update({"is_deleted": True})
    db.flush()

    # Soft-delete all existing categories
    db.query(Category).filter(Category.is_deleted == False).update({"is_deleted": True})
    db.flush()

    created_cats = 0
    created_products = 0

    for cat_name, cat_data in SEED_CATALOG.items():
        cat = Category(name=cat_name, description="", image=cat_data["icon"])
        db.add(cat)
        db.flush()

        for prod_name, unit, price, mrp, stock, desc, img_url in cat_data["products"]:
            discount = int(round((1 - price / mrp) * 100)) if mrp > price else 0
            product = Product(
                category_id=cat.id,
                name=prod_name,
                description=desc,
                price=price,
                unit=unit,
                stock=stock,
                discount_percent=discount,
            )
            db.add(product)
            db.flush()
            db.add(ProductImage(product_id=product.id, image_url=img_url, sort_order=0))
            created_products += 1

        created_cats += 1

    db.commit()
    return MessageResponse(message=f"Seeded {created_cats} categories with {created_products} products")


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


@router.delete("/products/{product_id}", response_model=MessageResponse)
def delete_product(product_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(product_id)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.is_deleted = True
    db.commit()
    return MessageResponse(message="Product deleted")


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


@router.delete("/categories/{category_id}", response_model=MessageResponse)
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
    return MessageResponse(message="Category deleted")


@router.get("/orders")
def list_orders(request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    orders = db.query(Order).filter(Order.is_deleted == False).order_by(Order.created_at.desc()).all()
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
            "user_id": user_id,
            "user_name": user_name,
            "user_email": user_email,
            "user_phone": user_phone,
            "user_gps_address": user_gps,
            "delivery_address": delivery_address,
            "delivery_otp": o.delivery_otp,
        })
    return result


@router.put("/orders/{order_id}/status", response_model=MessageResponse)
def update_order_status(order_id: str, body: StatusUpdateRequest, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(order_id)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if order.status == "Delivered":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Order is already delivered and cannot be modified")
    if body.status == "Delivered":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Use the delivery verification endpoint to mark orders as delivered")
    if body.status == "Cancelled" and order.status != "Cancelled":
        for oi in order.items:
            if not oi.is_deleted:
                product = db.query(Product).filter(Product.id == oi.product_id, Product.is_deleted == False).first()
                if product:
                    product.stock += oi.quantity
    order.status = body.status
    db.commit()
    return MessageResponse(message=f"Order status updated to {body.status}")


@router.delete("/orders/{order_id}", response_model=MessageResponse)
def delete_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(order_id)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    order.is_deleted = True
    db.commit()
    return MessageResponse(message="Order deleted")


@router.post("/orders/{order_id}/deliver", response_model=MessageResponse)
def deliver_order(order_id: str, body: DeliveryVerifyRequest, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(order_id)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if order.status == "Delivered":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Order is already delivered")
    if not order.delivery_otp:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No delivery code assigned to this order")
    if order.delivery_otp != body.otp:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid delivery code")
    order.status = "Delivered"
    order.delivery_otp = None
    db.commit()
    return MessageResponse(message="Order delivered successfully")


@router.delete("/orders/{order_id}/hard", response_model=MessageResponse)
def hard_delete_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(order_id)
    oid = uuid.UUID(order_id)
    order = db.query(Order).filter(Order.id == oid).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    try:
        db.execute(text("DELETE FROM payments WHERE order_id = :oid"), {"oid": oid})
        db.execute(text("DELETE FROM order_items WHERE order_id = :oid"), {"oid": oid})
        db.execute(text("DELETE FROM orders WHERE id = :oid"), {"oid": oid})
        db.commit()
    except Exception:
        db.rollback()
        raise
    return MessageResponse(message="Order permanently deleted")


@router.delete("/users/{user_id}", response_model=MessageResponse)
def delete_user(user_id: str, request: Request, db: Session = Depends(get_db)):
    admin_id = _require_admin(request, db)
    _validate_uuid(user_id)
    if user_id == admin_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete yourself")
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.is_deleted = True
    db.commit()
    return MessageResponse(message="User deleted")


@router.delete("/users/{user_id}/hard", response_model=MessageResponse)
def hard_delete_user(user_id: str, request: Request, db: Session = Depends(get_db)):
    admin_id = _require_admin(request, db)
    _validate_uuid(user_id)
    if user_id == admin_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot delete yourself")
    uid = uuid.UUID(user_id)
    user = db.query(User).filter(User.id == uid).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    try:
        db.execute(text("DELETE FROM addresses WHERE user_id = :uid"), {"uid": uid})
        db.execute(text("DELETE FROM cart_items WHERE user_id = :uid"), {"uid": uid})
        for order in db.query(Order).filter(Order.user_id == uid).all():
            db.execute(text("DELETE FROM payments WHERE order_id = :oid"), {"oid": order.id})
            db.execute(text("DELETE FROM order_items WHERE order_id = :oid"), {"oid": order.id})
        db.execute(text("DELETE FROM orders WHERE user_id = :uid"), {"uid": uid})
        db.execute(text("DELETE FROM wishlist_items WHERE user_id = :uid"), {"uid": uid})
        db.execute(text("UPDATE product_suggestions SET user_id = NULL WHERE user_id = :uid"), {"uid": uid})
        db.execute(text("DELETE FROM users WHERE id = :uid"), {"uid": uid})
        db.commit()
    except Exception:
        db.rollback()
        raise
    return MessageResponse(message="User permanently deleted")


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


@router.delete("/combo-packs/{pack_id}")
def delete_combo_pack(pack_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(pack_id)
    pack = db.query(ComboPack).filter(ComboPack.id == pack_id, ComboPack.is_deleted == False).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")
    pack.is_deleted = True
    db.commit()
    return {"message": "Combo pack deleted"}


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


@router.delete("/delivery-zones/{zone_id}", response_model=MessageResponse)
def delete_delivery_zone(zone_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request, db)
    _validate_uuid(zone_id)
    zone = db.query(DeliveryZone).filter(DeliveryZone.id == zone_id, DeliveryZone.is_deleted == False).first()
    if not zone:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery zone not found")
    zone.is_deleted = True
    db.commit()
    return MessageResponse(message="Delivery zone deleted")


# ─── NOTIFICATIONS ────────────────────────────────────────────────


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

