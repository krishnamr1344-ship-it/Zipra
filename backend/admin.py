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

import os
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, status
from sqlalchemy.orm import Session

from database import get_db
from models import User, Category, Product, ProductImage, Address, Order, Payment, CartItem, DeliveryZone, DeliveryFee, ComboPack, ComboPackItem, Offer
from schemas import (
    CategoryCreate, CategoryResponse,
    ProductCreate, ProductResponse,
    StatusUpdateRequest, MessageResponse,
    DeliveryZoneCreate,
    DeliveryFeeCreate, DeliveryFeeUpdate, DeliveryFeeResponse,
    ComboPackCreate, ComboPackUpdate, ComboPackResponse, ComboPackItemResponse, ComboPackItemInput,
    OfferCreate, OfferUpdate, OfferResponse,
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
            price=float(p.price), original_price=float(p.original_price) if p.original_price else None, unit=p.unit,
            images=[img.image_url for img in p.images if not img.is_deleted],
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
        price=body.price, original_price=body.original_price, unit=body.unit.strip().lower(),
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
        price=float(product.price), original_price=float(product.original_price) if product.original_price else None, unit=product.unit,
        images=[img.image_url for img in product.images if not img.is_deleted],
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
    product.original_price = body.original_price
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
        price=float(product.price), original_price=float(product.original_price) if product.original_price else None, unit=product.unit,
        images=[img.image_url for img in product.images if not img.is_deleted],
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


@router.post("/products/{product_id}/upload-image", status_code=status.HTTP_201_CREATED)
async def upload_product_image(product_id: str, request: Request, file: UploadFile = File(...), db: Session = Depends(get_db)):
    _require_admin(request)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")

    ext = file.filename.split(".")[-1] if file.filename else "jpg"
    filename = f"{uuid.uuid4()}.{ext}"
    os.makedirs("uploads", exist_ok=True)
    content = await file.read()
    with open(f"uploads/{filename}", "wb") as f:
        f.write(content)

    max_sort = db.query(db.func.max(ProductImage.sort_order)).filter(ProductImage.product_id == product_id, ProductImage.is_deleted == False).scalar() or 0
    img = ProductImage(product_id=product.id, image_url=f"/uploads/{filename}", sort_order=max_sort + 1)
    db.add(img)
    db.commit()
    db.refresh(img)
    return {"id": str(img.id), "image_url": img.image_url, "sort_order": img.sort_order}


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
def list_combo_packs_admin(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    packs = db.query(ComboPack).filter(ComboPack.is_deleted == False).order_by(ComboPack.name).all()
    return [_pack_to_admin_response(p) for p in packs]


@router.post("/combo-packs", status_code=status.HTTP_201_CREATED)
def create_combo_pack(body: ComboPackCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
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
        prod = db.query(Product).filter(Product.id == item.product_id, Product.is_deleted == False).first()
        if not prod:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Product {item.product_id} not found")
        db.add(ComboPackItem(pack_id=pack.id, product_id=item.product_id, quantity=item.quantity))
    db.commit()
    db.refresh(pack)
    return _pack_to_admin_response(pack)


@router.put("/combo-packs/{pack_id}")
def update_combo_pack(pack_id: str, body: ComboPackUpdate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
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
            prod = db.query(Product).filter(Product.id == item.product_id, Product.is_deleted == False).first()
            if not prod:
                raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Product {item.product_id} not found")
            db.add(ComboPackItem(pack_id=pack.id, product_id=item.product_id, quantity=item.quantity))
    db.commit()
    db.refresh(pack)
    return _pack_to_admin_response(pack)


@router.delete("/combo-packs/{pack_id}")
def delete_combo_pack(pack_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    pack = db.query(ComboPack).filter(ComboPack.id == pack_id, ComboPack.is_deleted == False).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")
    pack.is_deleted = True
    db.commit()
    return {"message": "Combo pack deleted"}


@router.put("/combo-packs/{pack_id}/toggle")
def toggle_combo_pack(pack_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    pack = db.query(ComboPack).filter(ComboPack.id == pack_id, ComboPack.is_deleted == False).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")
    pack.is_enabled = not pack.is_enabled
    db.commit()
    return {"is_enabled": pack.is_enabled, "message": f"Pack {'enabled' if pack.is_enabled else 'disabled'}"}


# ─── OFFERS (Admin) ──────────────────────────────────────────────


@router.get("/offers", response_model=list[OfferResponse])
def list_offers_admin(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    offers = db.query(Offer).filter(Offer.is_deleted == False).order_by(Offer.created_at.desc()).all()
    return [
        OfferResponse(
            id=str(o.id), name=o.name, description=o.description,
            discount_percent=o.discount_percent, image_url=o.image_url,
            is_active=o.is_active, created_at=o.created_at,
        ) for o in offers
    ]


@router.post("/offers", response_model=OfferResponse, status_code=status.HTTP_201_CREATED)
def create_offer(body: OfferCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    offer = Offer(
        name=body.name.strip(),
        description=body.description.strip() if body.description else None,
        discount_percent=body.discount_percent,
        image_url=body.image_url.strip() if body.image_url else None,
    )
    db.add(offer)
    db.commit()
    db.refresh(offer)
    return OfferResponse(
        id=str(offer.id), name=offer.name, description=offer.description,
        discount_percent=offer.discount_percent, image_url=offer.image_url,
        is_active=offer.is_active, created_at=offer.created_at,
    )


@router.put("/offers/{offer_id}", response_model=OfferResponse)
def update_offer(offer_id: str, body: OfferUpdate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    offer = db.query(Offer).filter(Offer.id == offer_id, Offer.is_deleted == False).first()
    if not offer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found")
    if body.name is not None:
        offer.name = body.name.strip()
    if body.description is not None:
        offer.description = body.description.strip() if body.description else None
    if body.discount_percent is not None:
        offer.discount_percent = body.discount_percent
    if body.image_url is not None:
        offer.image_url = body.image_url.strip() if body.image_url else None
    if body.is_active is not None:
        offer.is_active = body.is_active
    db.commit()
    db.refresh(offer)
    return OfferResponse(
        id=str(offer.id), name=offer.name, description=offer.description,
        discount_percent=offer.discount_percent, image_url=offer.image_url,
        is_active=offer.is_active, created_at=offer.created_at,
    )


@router.delete("/offers/{offer_id}", response_model=MessageResponse)
def delete_offer(offer_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    offer = db.query(Offer).filter(Offer.id == offer_id, Offer.is_deleted == False).first()
    if not offer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found")
    offer.is_deleted = True
    db.commit()
    return MessageResponse(message="Offer deleted")


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


@router.delete("/delivery-zones/{zone_id}", response_model=MessageResponse)
def delete_delivery_zone(zone_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    zone = db.query(DeliveryZone).filter(DeliveryZone.id == zone_id, DeliveryZone.is_deleted == False).first()
    if not zone:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery zone not found")
    zone.is_deleted = True
    db.commit()
    return MessageResponse(message="Delivery zone deleted")


@router.put("/delivery-zones/{zone_id}", response_model=MessageResponse)
def update_delivery_zone(zone_id: str, body: DeliveryZoneCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    zone = db.query(DeliveryZone).filter(DeliveryZone.id == zone_id, DeliveryZone.is_deleted == False).first()
    if not zone:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery zone not found")
    zone.zone_name = body.zone_name
    zone.geojson_data = body.geojson_data
    db.commit()
    return MessageResponse(message="Delivery zone updated")


# ─── DELIVERY FEE (Admin) ─────────────────────────────────────────


@router.get("/delivery-fees", response_model=list[DeliveryFeeResponse])
def list_delivery_fees(request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    fees = db.query(DeliveryFee).filter(DeliveryFee.is_deleted == False).order_by(DeliveryFee.min_order_amount).all()
    return [
        DeliveryFeeResponse(
            id=str(f.id),
            min_order_amount=float(f.min_order_amount),
            max_order_amount=float(f.max_order_amount) if f.max_order_amount else None,
            fee=float(f.fee),
            is_active=f.is_active,
            created_at=f.created_at,
        )
        for f in fees
    ]


@router.post("/delivery-fees", response_model=DeliveryFeeResponse, status_code=status.HTTP_201_CREATED)
def create_delivery_fee(body: DeliveryFeeCreate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    fee = DeliveryFee(
        min_order_amount=body.min_order_amount,
        max_order_amount=body.max_order_amount,
        fee=body.fee,
    )
    db.add(fee)
    db.commit()
    db.refresh(fee)
    return DeliveryFeeResponse(
        id=str(fee.id),
        min_order_amount=float(fee.min_order_amount),
        max_order_amount=float(fee.max_order_amount) if fee.max_order_amount else None,
        fee=float(fee.fee),
        is_active=fee.is_active,
        created_at=fee.created_at,
    )


@router.put("/delivery-fees/{fee_id}", response_model=DeliveryFeeResponse)
def update_delivery_fee(fee_id: str, body: DeliveryFeeUpdate, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    fee = db.query(DeliveryFee).filter(DeliveryFee.id == fee_id, DeliveryFee.is_deleted == False).first()
    if not fee:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery fee not found")
    if body.min_order_amount is not None:
        fee.min_order_amount = body.min_order_amount
    if body.max_order_amount is not None:
        fee.max_order_amount = body.max_order_amount
    if body.fee is not None:
        fee.fee = body.fee
    if body.is_active is not None:
        fee.is_active = body.is_active
    db.commit()
    db.refresh(fee)
    return DeliveryFeeResponse(
        id=str(fee.id),
        min_order_amount=float(fee.min_order_amount),
        max_order_amount=float(fee.max_order_amount) if fee.max_order_amount else None,
        fee=float(fee.fee),
        is_active=fee.is_active,
        created_at=fee.created_at,
    )


@router.delete("/delivery-fees/{fee_id}", response_model=MessageResponse)
def delete_delivery_fee(fee_id: str, request: Request, db: Session = Depends(get_db)):
    _require_admin(request)
    fee = db.query(DeliveryFee).filter(DeliveryFee.id == fee_id, DeliveryFee.is_deleted == False).first()
    if not fee:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery fee not found")
    fee.is_deleted = True
    db.commit()
    return MessageResponse(message="Delivery fee deleted")
