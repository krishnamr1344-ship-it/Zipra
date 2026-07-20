from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import ComboPack, ComboPackItem, Product, Offer, Shop
from app.schemas import (
    ComboPackCreate, ComboPackUpdate, OfferCreate, OfferUpdate, OfferResponse, MessageResponse,
)
from app.utils.helpers import require_admin

router = APIRouter(prefix="/api/admin")


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
    require_admin(request)
    packs = db.query(ComboPack).filter(ComboPack.is_deleted == False).order_by(ComboPack.name).all()
    return [_pack_to_admin_response(p) for p in packs]


@router.post("/combo-packs", status_code=status.HTTP_201_CREATED)
def create_combo_pack(body: ComboPackCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
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
        if prod.approval_status != "approved":
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Product '{prod.name}' is not approved (status: {prod.approval_status})")
        if prod.shop_id:
            shop = db.query(Shop).filter(Shop.id == prod.shop_id, Shop.is_deleted == False, Shop.is_active == True).first()
            if not shop:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Product '{prod.name}' belongs to an inactive or deleted shop")
        if prod.stock <= 0:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Product '{prod.name}' is out of stock")
        db.add(ComboPackItem(pack_id=pack.id, product_id=item.product_id, quantity=item.quantity))
    db.commit()
    db.refresh(pack)
    return _pack_to_admin_response(pack)


@router.put("/combo-packs/{pack_id}")
def update_combo_pack(pack_id: str, body: ComboPackUpdate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
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
            if prod.approval_status != "approved":
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Product '{prod.name}' is not approved (status: {prod.approval_status})")
            if prod.shop_id:
                shop = db.query(Shop).filter(Shop.id == prod.shop_id, Shop.is_deleted == False, Shop.is_active == True).first()
                if not shop:
                    raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Product '{prod.name}' belongs to an inactive or deleted shop")
            if prod.stock <= 0:
                raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Product '{prod.name}' is out of stock")
            db.add(ComboPackItem(pack_id=pack.id, product_id=item.product_id, quantity=item.quantity))
    db.commit()
    db.refresh(pack)
    return _pack_to_admin_response(pack)


@router.delete("/combo-packs/{pack_id}")
def delete_combo_pack(pack_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    pack = db.query(ComboPack).filter(ComboPack.id == pack_id, ComboPack.is_deleted == False).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")
    pack.is_deleted = True
    db.commit()
    return {"message": "Combo pack deleted"}


@router.put("/combo-packs/{pack_id}/toggle")
def toggle_combo_pack(pack_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    pack = db.query(ComboPack).filter(ComboPack.id == pack_id, ComboPack.is_deleted == False).first()
    if not pack:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Pack not found")
    pack.is_enabled = not pack.is_enabled
    db.commit()
    return {"is_enabled": pack.is_enabled, "message": f"Pack {'enabled' if pack.is_enabled else 'disabled'}"}


@router.get("/offers", response_model=list[OfferResponse])
def list_offers_admin(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
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
    require_admin(request)
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
    require_admin(request)
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
    require_admin(request)
    offer = db.query(Offer).filter(Offer.id == offer_id, Offer.is_deleted == False).first()
    if not offer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Offer not found")
    offer.is_deleted = True
    db.commit()
    return MessageResponse(message="Offer deleted")
