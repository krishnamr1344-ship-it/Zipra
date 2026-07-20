from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import DeliveryZone, DeliveryFee
from app.schemas import (
    DeliveryZoneCreate, MessageResponse,
    DeliveryFeeCreate, DeliveryFeeUpdate, DeliveryFeeResponse,
)
from app.utils.helpers import require_admin

router = APIRouter(prefix="/api/admin")


@router.get("/stats")
def dashboard_stats(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    from app.models import Product, Category, Order, User
    products = db.query(Product).filter(Product.is_deleted == False).count()
    categories = db.query(Category).filter(Category.is_deleted == False).count()
    orders = db.query(Order).filter(Order.is_deleted == False).count()
    users = db.query(User).filter(User.is_deleted == False).count()
    from sqlalchemy import func
    total = db.query(func.coalesce(func.sum(Order.total_amount), 0)).filter(Order.is_deleted == False, Order.status == "Delivered").scalar()
    return {
        "products": products,
        "categories": categories,
        "orders": orders,
        "users": users,
        "revenue": round(total, 2),
    }


@router.post("/delivery-zone", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def create_delivery_zone(body: DeliveryZoneCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    zone = DeliveryZone(
        zone_name=body.zone_name,
        geojson_data=body.geojson_data,
    )
    db.add(zone)
    db.commit()
    return MessageResponse(message=f"Delivery zone '{body.zone_name}' created")


@router.get("/delivery-zones")
def list_delivery_zones(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
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
    require_admin(request)
    zone = db.query(DeliveryZone).filter(DeliveryZone.id == zone_id, DeliveryZone.is_deleted == False).first()
    if not zone:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery zone not found")
    zone.is_deleted = True
    db.commit()
    return MessageResponse(message="Delivery zone deleted")


@router.put("/delivery-zones/{zone_id}", response_model=MessageResponse)
def update_delivery_zone(zone_id: str, body: DeliveryZoneCreate, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    zone = db.query(DeliveryZone).filter(DeliveryZone.id == zone_id, DeliveryZone.is_deleted == False).first()
    if not zone:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery zone not found")
    zone.zone_name = body.zone_name
    zone.geojson_data = body.geojson_data
    db.commit()
    return MessageResponse(message="Delivery zone updated")


@router.get("/delivery-fees", response_model=list[DeliveryFeeResponse])
def list_delivery_fees(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
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
    require_admin(request)
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
    require_admin(request)
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
    require_admin(request)
    fee = db.query(DeliveryFee).filter(DeliveryFee.id == fee_id, DeliveryFee.is_deleted == False).first()
    if not fee:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Delivery fee not found")
    fee.is_deleted = True
    db.commit()
    return MessageResponse(message="Delivery fee deleted")
