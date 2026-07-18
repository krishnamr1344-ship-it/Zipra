import os
import uuid
from datetime import datetime, timezone

import bcrypt
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import Shop, User, Product, ShopOrder, DeliveryPartner, Earning
from app.schemas import (
    ShopCreate, ShopUpdate, ShopResponse, ShopOwnerCreate,
    DeliveryPartnerCreate, DeliveryPartnerUpdate, DeliveryPartnerResponse,
    MessageResponse, ShopProductResponse,
)
from app.utils.helpers import require_admin

router = APIRouter(prefix="/api/admin", tags=["admin-shops"])


@router.get("/shops", response_model=list[ShopResponse])
def list_shops(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    shops = db.query(Shop).filter(Shop.is_deleted == False).order_by(Shop.created_at.desc()).all()
    return [
        ShopResponse(
            id=str(s.id), owner_id=str(s.owner_id),
            name=s.name, description=s.description,
            logo_url=s.logo_url, banner_url=s.banner_url,
            address=s.address, city=s.city, state=s.state, pincode=s.pincode,
            latitude=float(s.latitude) if s.latitude else None,
            longitude=float(s.longitude) if s.longitude else None,
            phone=s.phone, email=s.email,
            gst_number=s.gst_number,
            is_active=s.is_active, is_open=s.is_open,
            created_at=s.created_at,
        ) for s in shops
    ]


@router.post("/shops", response_model=ShopResponse, status_code=status.HTTP_201_CREATED)
def create_shop_owner(body: ShopOwnerCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    existing = db.query(User).filter(User.email == body.email.lower()).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")
    hashed = bcrypt.hashpw(body.password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")
    user = User(
        email=body.email.lower(),
        password_hash=hashed,
        name=body.name.strip(),
        phone=body.phone.strip(),
        role="shop_owner",
    )
    db.add(user)
    db.flush()
    shop = Shop(
        owner_id=user.id,
        name=body.shop_name.strip(),
        email=body.email.lower(),
        phone=body.phone.strip(),
    )
    db.add(shop)
    db.commit()
    db.refresh(shop)
    return ShopResponse(
        id=str(shop.id), owner_id=str(shop.owner_id),
        name=shop.name, description=shop.description,
        logo_url=shop.logo_url, banner_url=shop.banner_url,
        address=shop.address, city=shop.city, state=shop.state, pincode=shop.pincode,
        latitude=float(shop.latitude) if shop.latitude else None,
        longitude=float(shop.longitude) if shop.longitude else None,
        phone=shop.phone, email=shop.email,
        gst_number=shop.gst_number,
        is_active=shop.is_active, is_open=shop.is_open,
        created_at=shop.created_at,
    )


@router.put("/shops/{shop_id}", response_model=ShopResponse)
def update_shop(shop_id: str, body: ShopUpdate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    shop = db.query(Shop).filter(Shop.id == shop_id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")
    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        if value is not None:
            setattr(shop, key, value)
    shop.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(shop)
    return ShopResponse(
        id=str(shop.id), owner_id=str(shop.owner_id),
        name=shop.name, description=shop.description,
        logo_url=shop.logo_url, banner_url=shop.banner_url,
        address=shop.address, city=shop.city, state=shop.state, pincode=shop.pincode,
        latitude=float(shop.latitude) if shop.latitude else None,
        longitude=float(shop.longitude) if shop.longitude else None,
        phone=shop.phone, email=shop.email,
        gst_number=shop.gst_number,
        is_active=shop.is_active, is_open=shop.is_open,
        created_at=shop.created_at,
    )


@router.put("/shops/{shop_id}/toggle", response_model=MessageResponse)
def toggle_shop(shop_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    shop = db.query(Shop).filter(Shop.id == shop_id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")
    shop.is_active = not shop.is_active
    shop.updated_at = datetime.now(timezone.utc)
    db.commit()
    return MessageResponse(message=f"Shop {'activated' if shop.is_active else 'deactivated'}")


@router.get("/products/pending", response_model=list[ShopProductResponse])
def list_pending_products(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    products = db.query(Product).filter(
        Product.approval_status == "pending",
        Product.is_deleted == False,
    ).order_by(Product.created_at.desc()).all()
    return [
        ShopProductResponse(
            id=str(p.id), category_id=str(p.category_id),
            category_name=p.category.name if p.category else None,
            name=p.name, description=p.description,
            price=float(p.price),
            original_price=float(p.original_price) if p.original_price else None,
            unit=p.unit,
            images=[img.image_url for img in p.images if not img.is_deleted],
            stock=p.stock,
            approval_status=p.approval_status or "pending",
            created_at=p.created_at,
        ) for p in products
    ]


@router.put("/products/{product_id}/approve", response_model=MessageResponse)
def approve_product(product_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.approval_status = "approved"
    product.updated_at = datetime.now(timezone.utc)
    db.commit()
    return MessageResponse(message="Product approved")


@router.put("/products/{product_id}/reject", response_model=MessageResponse)
def reject_product(product_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    product = db.query(Product).filter(Product.id == product_id, Product.is_deleted == False).first()
    if not product:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Product not found")
    product.approval_status = "rejected"
    product.updated_at = datetime.now(timezone.utc)
    db.commit()
    return MessageResponse(message="Product rejected")


@router.get("/delivery-partners", response_model=list[DeliveryPartnerResponse])
def list_delivery_partners(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    partners = db.query(DeliveryPartner).filter(DeliveryPartner.is_deleted == False).order_by(DeliveryPartner.created_at.desc()).all()
    return [
        DeliveryPartnerResponse(
            id=str(p.id), name=p.name, phone=p.phone,
            vehicle_type=p.vehicle_type, vehicle_number=p.vehicle_number,
            is_available=p.is_available, is_active=p.is_active,
            created_at=p.created_at,
        ) for p in partners
    ]


@router.post("/delivery-partners", response_model=DeliveryPartnerResponse, status_code=status.HTTP_201_CREATED)
def create_delivery_partner(body: DeliveryPartnerCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    partner = DeliveryPartner(
        name=body.name.strip(),
        phone=body.phone.strip(),
        vehicle_type=body.vehicle_type,
        vehicle_number=body.vehicle_number,
    )
    db.add(partner)
    db.commit()
    db.refresh(partner)
    return DeliveryPartnerResponse(
        id=str(partner.id), name=partner.name, phone=partner.phone,
        vehicle_type=partner.vehicle_type, vehicle_number=partner.vehicle_number,
        is_available=partner.is_available, is_active=partner.is_active,
        created_at=partner.created_at,
    )


@router.put("/delivery-partners/{partner_id}", response_model=DeliveryPartnerResponse)
def update_delivery_partner(partner_id: str, body: DeliveryPartnerUpdate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    partner = db.query(DeliveryPartner).filter(DeliveryPartner.id == partner_id, DeliveryPartner.is_deleted == False).first()
    if not partner:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery partner not found")
    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        if value is not None:
            setattr(partner, key, value)
    db.commit()
    db.refresh(partner)
    return DeliveryPartnerResponse(
        id=str(partner.id), name=partner.name, phone=partner.phone,
        vehicle_type=partner.vehicle_type, vehicle_number=partner.vehicle_number,
        is_available=partner.is_available, is_active=partner.is_active,
        created_at=partner.created_at,
    )


@router.delete("/delivery-partners/{partner_id}", response_model=MessageResponse)
def delete_delivery_partner(partner_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    partner = db.query(DeliveryPartner).filter(DeliveryPartner.id == partner_id, DeliveryPartner.is_deleted == False).first()
    if not partner:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery partner not found")
    partner.is_deleted = True
    db.commit()
    return MessageResponse(message="Delivery partner deleted")
