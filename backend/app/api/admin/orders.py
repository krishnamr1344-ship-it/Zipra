from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import Order, Address, ShopOrder, Product, OrderItem, Earning
from app.schemas import StatusUpdateRequest, MessageResponse
from app.utils.helpers import require_admin

router = APIRouter(prefix="/api/admin")


@router.get("/orders")
def list_orders(request: Request, db: Session = Depends(get_db)):
    require_admin(request)
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
            "delivery_fee": float(o.delivery_fee) if o.delivery_fee else 0,
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
    require_admin(request)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    VALID_TRANSITIONS = {
        "Pending": ["Confirmed", "Cancelled"],
        "Confirmed": ["Shipped", "Cancelled"],
        "Shipped": ["Delivered", "Cancelled"],
        "Delivered": [],
        "Cancelled": [],
    }
    target = body.status.capitalize() if body.status and body.status.lower() not in ("cancelled",) else body.status
    if target.lower() == "cancelled":
        target = "Cancelled"
    if order.status not in VALID_TRANSITIONS:
        raise HTTPException(400, detail=f"Cannot transition from '{order.status}' — unknown current status")
    if target not in VALID_TRANSITIONS.get(order.status, []):
        raise HTTPException(400, detail=f"Cannot transition from '{order.status}' to '{target}'")

    if target == "Delivered":
        shop_orders = db.query(ShopOrder).filter(
            ShopOrder.order_id == order_id, ShopOrder.is_deleted == False,
        ).all()
        if shop_orders and not all(so.status == "delivered" for so in shop_orders):
            pending_shops = [so.shop_id for so in shop_orders if so.status != "delivered"]
            raise HTTPException(400, detail=f"Cannot mark Delivered — {len(pending_shops)} shop(s) haven't delivered yet")
    if target == "Shipped":
        shop_orders = db.query(ShopOrder).filter(
            ShopOrder.order_id == order_id, ShopOrder.is_deleted == False,
        ).all()
        if shop_orders and any(so.status == "new" for so in shop_orders):
            raise HTTPException(400, detail="Cannot mark Shipped — some shops haven't accepted the order yet")

    order.status = target
    order.updated_at = datetime.now(timezone.utc)
    if target == "Cancelled":
        shop_orders = db.query(ShopOrder).filter(
            ShopOrder.order_id == order_id,
            ShopOrder.is_deleted == False,
        ).all()
        already_cancelled_shop_ids = set()
        for so in shop_orders:
            if so.status == "cancelled":
                already_cancelled_shop_ids.add(str(so.shop_id))
        for so in shop_orders:
            if so.status not in ("delivered", "cancelled"):
                so.status = "cancelled"
                so.cancelled_at = datetime.now(timezone.utc)
                so.cancellation_reason = "Cancelled by admin"
                so.updated_at = datetime.now(timezone.utc)
        for oi in order.items:
            if not oi.is_deleted:
                product = db.query(Product).filter(Product.id == oi.product_id).first()
                if product and product.shop_id and str(product.shop_id) not in already_cancelled_shop_ids:
                    product.stock += oi.quantity
        earnings = db.query(Earning).filter(Earning.order_id == order_id).all()
        for e in earnings:
            e.status = "cancelled"
    db.commit()
    return MessageResponse(message=f"Order status updated to {target}")


@router.delete("/orders/{order_id}", response_model=MessageResponse)
def delete_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    require_admin(request)
    order = db.query(Order).filter(Order.id == order_id, Order.is_deleted == False).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    shop_orders = db.query(ShopOrder).filter(
        ShopOrder.order_id == order_id,
        ShopOrder.is_deleted == False,
    ).all()
    already_cancelled_shop_ids = set()
    for so in shop_orders:
        if so.status == "cancelled":
            already_cancelled_shop_ids.add(str(so.shop_id))
        so.is_deleted = True
    for oi in order.items:
        if not oi.is_deleted:
            product = db.query(Product).filter(Product.id == oi.product_id).first()
            if product and product.shop_id and str(product.shop_id) not in already_cancelled_shop_ids:
                product.stock += oi.quantity
    earnings = db.query(Earning).filter(Earning.order_id == order_id).all()
    for e in earnings:
        e.status = "cancelled"
    order.is_deleted = True
    db.commit()
    return MessageResponse(message="Order deleted")
