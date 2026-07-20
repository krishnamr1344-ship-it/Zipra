from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import ComboPack, ComboPackItem, CartItem, Product, Offer, Shop
from app.schemas import (
    ComboPackResponse, ComboPackItemResponse, PackAddRequest, OfferResponse, MessageResponse,
)
from app.utils.helpers import get_user_id, get_user, get_product_or_404

router = APIRouter(prefix="/api")


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
        all_valid = True
        for pi in pack.items:
            if not pi.is_deleted and pi.product:
                prod = pi.product
                if prod.stock < pi.quantity:
                    all_valid = False
                    break
                if prod.approval_status != "approved":
                    all_valid = False
                    break
                if prod.shop_id:
                    shop = db.query(Shop).filter(
                        Shop.id == prod.shop_id, Shop.is_deleted == False, Shop.is_active == True,
                    ).first()
                    if not shop:
                        all_valid = False
                        break
        if not all_valid:
            continue
        result.append(_pack_to_response(pack))
    return result


@router.post("/combo-packs/add-to-cart", status_code=status.HTTP_200_OK)
def add_pack_to_cart(body: PackAddRequest, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    get_user(user_id, db)

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
        prod = get_product_or_404(str(pi.product_id), db)
        if prod.stock < pi.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {prod.name}",
            )
        if prod.approval_status != "approved":
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Product '{prod.name}' is no longer available",
            )
        if prod.shop_id:
            shop = db.query(Shop).filter(
                Shop.id == prod.shop_id, Shop.is_deleted == False, Shop.is_active == True,
            ).first()
            if not shop:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Shop for '{prod.name}' is currently unavailable",
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
