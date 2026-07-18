from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session
import bcrypt

from app.db.session import get_db
from app.models import User, Shop
from app.schemas import ShopLoginRequest, ShopResponse, ShopUpdate
from app.core.security import create_jwt
from app.utils.helpers import get_user_id

router = APIRouter(prefix="/api/shop")


@router.post("/login", status_code=status.HTTP_200_OK)
def shop_login(body: ShopLoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        User.email == body.email.lower(),
        User.is_deleted == False,
    ).first()
    if not user or not user.password_hash:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not bcrypt.checkpw(body.password.encode("utf-8"), user.password_hash.encode("utf-8")):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if user.role not in ("shop_owner",):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Shop owner access required")

    shop = db.query(Shop).filter(Shop.owner_id == user.id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found for this user")

    token, _jti, _expires = create_jwt(str(user.id), user.role)
    return {
        "message": "Login successful",
        "token": token,
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "role": user.role},
        "shop": ShopResponse(
            id=str(shop.id), owner_id=str(shop.owner_id), name=shop.name,
            description=shop.description, logo_url=shop.logo_url, banner_url=shop.banner_url,
            address=shop.address, city=shop.city, state=shop.state, pincode=shop.pincode,
            latitude=float(shop.latitude) if shop.latitude else None,
            longitude=float(shop.longitude) if shop.longitude else None,
            phone=shop.phone, email=shop.email, gst_number=shop.gst_number,
            is_active=shop.is_active, is_open=shop.is_open, created_at=shop.created_at,
        ),
    }


@router.get("/profile", response_model=ShopResponse)
def get_shop_profile(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    shop = db.query(Shop).filter(Shop.owner_id == user_id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")
    return ShopResponse(
        id=str(shop.id), owner_id=str(shop.owner_id), name=shop.name,
        description=shop.description, logo_url=shop.logo_url, banner_url=shop.banner_url,
        address=shop.address, city=shop.city, state=shop.state, pincode=shop.pincode,
        latitude=float(shop.latitude) if shop.latitude else None,
        longitude=float(shop.longitude) if shop.longitude else None,
        phone=shop.phone, email=shop.email, gst_number=shop.gst_number,
        is_active=shop.is_active, is_open=shop.is_open, created_at=shop.created_at,
    )


@router.put("/profile", response_model=ShopResponse)
def update_shop_profile(body: ShopUpdate, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    shop = db.query(Shop).filter(Shop.owner_id == user_id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")
    update_data = body.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(shop, key, value)
    db.commit()
    db.refresh(shop)
    return ShopResponse(
        id=str(shop.id), owner_id=str(shop.owner_id), name=shop.name,
        description=shop.description, logo_url=shop.logo_url, banner_url=shop.banner_url,
        address=shop.address, city=shop.city, state=shop.state, pincode=shop.pincode,
        latitude=float(shop.latitude) if shop.latitude else None,
        longitude=float(shop.longitude) if shop.longitude else None,
        phone=shop.phone, email=shop.email, gst_number=shop.gst_number,
        is_active=shop.is_active, is_open=shop.is_open, created_at=shop.created_at,
    )


@router.post("/toggle-open")
def toggle_shop_open(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    shop = db.query(Shop).filter(Shop.owner_id == user_id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")
    shop.is_open = not shop.is_open
    db.commit()
    return {"is_open": shop.is_open}


@router.post("/upload-logo")
def upload_logo(request: Request, db: Session = Depends(get_db)):
    from fastapi import UploadFile, File
    import os, uuid as _uuid
    user_id = get_user_id(request)
    shop = db.query(Shop).filter(Shop.owner_id == user_id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")
    return {"message": "Upload endpoint ready", "logo_url": shop.logo_url}


@router.post("/upload-banner")
def upload_banner(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    shop = db.query(Shop).filter(Shop.owner_id == user_id, Shop.is_deleted == False).first()
    if not shop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Shop not found")
    return {"message": "Upload endpoint ready", "banner_url": shop.banner_url}
