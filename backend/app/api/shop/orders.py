from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import ShopOrder, Order, OrderItem, Product, User, Address, Earning
from app.schemas import ShopOrderResponse, ShopOrderStatusUpdate, OrderItemResponse, MessageResponse
from app.utils.helpers import require_shop_owner, get_shop_for_owner

router = APIRouter(prefix="/api/shop/orders", tags=["shop-orders"])


def _shop_order_to_response(so: ShopOrder, db: Session) -> ShopOrderResponse:
    order = so.order
    user = db.query(User).filter(User.id == order.user_id).first() if order else None
    address = db.query(Address).filter(Address.id == order.address_id).first() if order and order.address_id else None
    items = []
    if order:
        order_items = db.query(OrderItem).filter(
            OrderItem.order_id == order.id,
            OrderItem.is_deleted == False,
        ).all()
        items = [
            OrderItemResponse(
                id=str(oi.id), product_id=str(oi.product_id),
                product_name=oi.product_name, product_price=float(oi.product_price),
                quantity=oi.quantity, subtotal=float(oi.subtotal),
            ) for oi in order_items
        ]
    addr_str = None
    if address:
        parts = [address.address_line1, address.city, address.state, address.pincode]
        addr_str = ", ".join(p for p in parts if p)
    return ShopOrderResponse(
        id=str(so.id), order_id=str(so.order_id), shop_id=str(so.shop_id),
        status=so.status,
        customer_name=user.name if user else None,
        customer_phone=user.phone if user else None,
        delivery_address=addr_str,
        items=items,
        total_amount=float(order.total_amount) if order else 0,
        payment_method=order.payment_method if order else "COD",
        accepted_at=so.accepted_at,
        packing_at=so.packing_at,
        ready_at=so.ready_at,
        delivered_at=so.delivered_at,
        cancelled_at=so.cancelled_at,
        cancellation_reason=so.cancellation_reason,
        created_at=so.created_at,
    )


@router.get("", response_model=list[ShopOrderResponse])
def list_shop_orders(
    request: Request,
    status_filter: str = None,
    db: Session = Depends(get_db),
):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    query = db.query(ShopOrder).filter(ShopOrder.shop_id == shop.id, ShopOrder.is_deleted == False)
    if status_filter:
        query = query.filter(ShopOrder.status == status_filter)
    shop_orders = query.order_by(ShopOrder.created_at.desc()).all()
    return [_shop_order_to_response(so, db) for so in shop_orders]


@router.get("/{order_id}", response_model=ShopOrderResponse)
def get_shop_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    so = db.query(ShopOrder).filter(
        ShopOrder.id == order_id,
        ShopOrder.shop_id == shop.id,
        ShopOrder.is_deleted == False,
    ).first()
    if not so:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    return _shop_order_to_response(so, db)


@router.put("/{order_id}/accept", response_model=ShopOrderResponse)
def accept_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    so = db.query(ShopOrder).filter(
        ShopOrder.id == order_id,
        ShopOrder.shop_id == shop.id,
        ShopOrder.is_deleted == False,
    ).first()
    if not so:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if so.status != "new":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot accept order in {so.status} status")
    so.status = "accepted"
    so.accepted_at = datetime.now(timezone.utc)
    so.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(so)
    return _shop_order_to_response(so, db)


@router.put("/{order_id}/packing", response_model=ShopOrderResponse)
def start_packing(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    so = db.query(ShopOrder).filter(
        ShopOrder.id == order_id,
        ShopOrder.shop_id == shop.id,
        ShopOrder.is_deleted == False,
    ).first()
    if not so:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if so.status != "accepted":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot start packing from {so.status} status")
    so.status = "packing"
    so.packing_at = datetime.now(timezone.utc)
    so.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(so)
    return _shop_order_to_response(so, db)


@router.put("/{order_id}/ready", response_model=ShopOrderResponse)
def mark_ready(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    so = db.query(ShopOrder).filter(
        ShopOrder.id == order_id,
        ShopOrder.shop_id == shop.id,
        ShopOrder.is_deleted == False,
    ).first()
    if not so:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if so.status != "packing":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot mark ready from {so.status} status")
    so.status = "ready_for_pickup"
    so.ready_at = datetime.now(timezone.utc)
    so.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(so)
    return _shop_order_to_response(so, db)


@router.put("/{order_id}/deliver", response_model=ShopOrderResponse)
def mark_delivered(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    so = db.query(ShopOrder).filter(
        ShopOrder.id == order_id,
        ShopOrder.shop_id == shop.id,
        ShopOrder.is_deleted == False,
    ).first()
    if not so:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if so.status not in ("ready_for_pickup", "out_for_delivery"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot deliver from {so.status} status")
    so.status = "delivered"
    so.delivered_at = datetime.now(timezone.utc)
    so.updated_at = datetime.now(timezone.utc)

    order_items = db.query(OrderItem).filter(
        OrderItem.order_id == so.order_id,
        OrderItem.is_deleted == False,
    ).all()
    shop_product_ids = [str(p.id) for p in db.query(Product).filter(
        Product.shop_id == shop.id,
        Product.is_deleted == False,
    ).all()]
    shop_total = sum(
        float(oi.subtotal) for oi in order_items
        if str(oi.product_id) in shop_product_ids
    )
    commission_rate = Decimal("0.10")
    commission = (Decimal(str(shop_total)) * commission_rate).quantize(Decimal("0.01"))
    net_amount = Decimal(str(shop_total)) - commission

    earning = Earning(
        shop_id=shop.id,
        order_id=so.order_id,
        amount=shop_total,
        commission=commission,
        net_amount=net_amount,
        status="pending",
    )
    db.add(earning)

    parent_order = db.query(Order).filter(Order.id == so.order_id).first()
    if parent_order:
        parent_order.status = "delivered"
        parent_order.updated_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(so)
    return _shop_order_to_response(so, db)


@router.put("/{order_id}/cancel", response_model=ShopOrderResponse)
def cancel_order(order_id: str, body: ShopOrderStatusUpdate, request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    so = db.query(ShopOrder).filter(
        ShopOrder.id == order_id,
        ShopOrder.shop_id == shop.id,
        ShopOrder.is_deleted == False,
    ).first()
    if not so:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    if so.status in ("delivered", "cancelled"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Cannot cancel order in {so.status} status")
    so.status = "cancelled"
    so.cancelled_at = datetime.now(timezone.utc)
    so.cancellation_reason = body.cancellation_reason
    so.updated_at = datetime.now(timezone.utc)

    order_items = db.query(OrderItem).filter(
        OrderItem.order_id == so.order_id,
        OrderItem.is_deleted == False,
    ).all()
    shop_product_ids = {str(p.id) for p in db.query(Product).filter(
        Product.shop_id == shop.id,
        Product.is_deleted == False,
    ).all()}
    for oi in order_items:
        if str(oi.product_id) in shop_product_ids:
            product = db.query(Product).filter(Product.id == oi.product_id).first()
            if product:
                product.stock += oi.quantity

    db.commit()
    db.refresh(so)
    return _shop_order_to_response(so, db)
