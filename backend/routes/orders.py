import json
import uuid
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from database import get_db
from models import CartItem, Order, OrderItem, Payment, Address, DeliveryZone
from schemas import (
    OrderCreateRequest, OrderDirectCreateRequest, OrderResponse, OrderItemResponse, DeliveryAddress, MessageResponse,
)
from routes.helpers import get_user_id, get_user, get_address_or_404, get_product_or_404, get_order_or_404

router = APIRouter(prefix="/api")


def _order_to_response(order: Order) -> OrderResponse:
    items = []
    for oi in order.items:
        if not oi.is_deleted:
            items.append(OrderItemResponse(
                id=str(oi.id),
                product_id=str(oi.product_id),
                product_name=oi.product_name,
                product_price=float(oi.product_price),
                quantity=oi.quantity,
                subtotal=float(oi.subtotal),
            ))
    delivery_address = None
    if order.address_id and order.address:
        addr = order.address
        delivery_address = DeliveryAddress(
            address_line1=addr.address_line1,
            city=addr.city,
            state=addr.state,
            pincode=addr.pincode,
            latitude=float(addr.latitude) if addr.latitude else None,
            longitude=float(addr.longitude) if addr.longitude else None,
        )
    return OrderResponse(
        id=str(order.id),
        status=order.status,
        total_amount=float(order.total_amount),
        payment_method=order.payment_method,
        items=items,
        delivery_address=delivery_address,
        created_at=order.created_at,
    )


@router.get("/orders", response_model=list[OrderResponse])
def list_orders(request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    orders = db.query(Order).filter(
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).order_by(Order.created_at.desc()).all()
    return [_order_to_response(o) for o in orders]


@router.get("/orders/{order_id}", response_model=OrderResponse)
def get_order(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    order = get_order_or_404(order_id, user_id, db)
    return _order_to_response(order)


@router.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(body: OrderCreateRequest, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    get_user(user_id, db)

    addr = get_address_or_404(body.address_id, user_id, db)

    cart_items = db.query(CartItem).filter(
        CartItem.user_id == user_id,
        CartItem.is_deleted == False,
    ).all()

    if not cart_items:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cart is empty")

    total = Decimal("0.00")
    order_items_data = []

    for ci in cart_items:
        product = get_product_or_404(str(ci.product_id), db)
        if product.stock < ci.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {product.name}",
            )
        subtotal = product.price * ci.quantity
        total += subtotal
        order_items_data.append({
            "product_id": product.id,
            "product_name": product.name,
            "product_price": product.price,
            "quantity": ci.quantity,
            "subtotal": subtotal,
        })

    order = Order(
        user_id=user_id,
        address_id=addr.id,
        total_amount=total + (body.delivery_fee or Decimal("0.00")),
        payment_method=body.payment_method,
    )
    db.add(order)
    db.flush()

    for oi_data in order_items_data:
        oi = OrderItem(order_id=order.id, **oi_data)
        db.add(oi)
        product = get_product_or_404(str(oi_data["product_id"]), db)
        product.stock -= oi_data["quantity"]

    for ci in cart_items:
        ci.is_deleted = True

    db.commit()
    db.refresh(order)
    return _order_to_response(order)


@router.post("/orders/direct", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order_direct(body: OrderDirectCreateRequest, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    get_user(user_id, db)

    total = Decimal("0.00")
    order_items_data = []

    for item in body.items:
        product = get_product_or_404(item.product_id, db)
        if product.stock < item.quantity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Insufficient stock for {product.name}",
            )
        subtotal = product.price * item.quantity
        total += subtotal
        order_items_data.append({
            "product_id": product.id,
            "product_name": product.name,
            "product_price": product.price,
            "quantity": item.quantity,
            "subtotal": subtotal,
        })

    address_id = body.address_id
    if address_id:
        addr = db.query(Address).filter(
            Address.id == address_id,
            Address.user_id == user_id,
            Address.is_deleted == False,
        ).first()
        if not addr:
            address_id = None
        else:
            if addr.latitude is not None and addr.longitude is not None:
                zones = db.query(DeliveryZone).filter(
                    DeliveryZone.is_deleted == False,
                    DeliveryZone.is_active == True,
                ).all()
                if zones:
                    from shapely.geometry import shape as shapely_shape
                    from shapely.geometry import Point
                    point = Point(float(addr.longitude), float(addr.latitude))
                    in_zone = False
                    for z in zones:
                        try:
                            geom = json.loads(z.geojson_data)
                            polygon = shapely_shape(geom)
                            if polygon.contains(point):
                                in_zone = True
                                break
                        except Exception:
                            continue
                    if not in_zone:
                        raise HTTPException(
                            status_code=status.HTTP_403_FORBIDDEN,
                            detail="Delivery not available in your area",
                        )

    order = Order(
        user_id=user_id,
        address_id=address_id,
        total_amount=total + (body.delivery_fee or Decimal("0.00")),
        payment_method=body.payment_method,
    )
    db.add(order)
    db.flush()

    for oi_data in order_items_data:
        oi = OrderItem(order_id=order.id, **oi_data)
        db.add(oi)
        product = get_product_or_404(str(oi_data["product_id"]), db)
        product.stock -= oi_data["quantity"]

    payment_rec = Payment(
        order_id=order.id,
        user_id=user_id,
        method=body.payment_method,
        status="success",
        amount=total,
    )
    payment_rec.transaction_id = str(uuid.uuid4()).replace("-", "")[:16].upper()
    db.add(payment_rec)

    db.commit()
    db.refresh(order)
    return _order_to_response(order)
