import json
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel
from shapely.errors import GEOSException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import DeliveryZone, DeliveryFee
from app.schemas import ZoneCheckRequest, ZoneCheckResponse, MessageResponse

router = APIRouter(prefix="/api")


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
    except (GEOSException, ValueError, json.JSONDecodeError, ImportError):
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
