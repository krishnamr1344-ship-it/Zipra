import uuid
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import Order, Payment
from app.schemas import PaymentProcessRequest, PaymentResponse
from app.utils.helpers import get_user_id, get_user

router = APIRouter(prefix="/api")

PAYMENT_TIMEOUT_SECONDS = 60


def _payment_to_response(payment: Payment) -> PaymentResponse:
    expires_at = payment.created_at + timedelta(seconds=PAYMENT_TIMEOUT_SECONDS)
    return PaymentResponse(
        id=str(payment.id),
        order_id=str(payment.order_id),
        amount=float(payment.amount),
        method=payment.method,
        status=payment.status,
        transaction_id=payment.transaction_id,
        expires_at=expires_at,
        created_at=payment.created_at,
    )


def _check_payment_expiry(payment: Payment, db: Session):
    if payment.status != "pending":
        return
    elapsed = (datetime.now(timezone.utc) - payment.created_at).total_seconds()
    if elapsed >= PAYMENT_TIMEOUT_SECONDS:
        payment.status = "failed"
        payment.transaction_id = None
        db.commit()
        db.refresh(payment)


@router.post("/payments/process", response_model=PaymentResponse)
def process_payment(body: PaymentProcessRequest, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    get_user(user_id, db)

    order = db.query(Order).filter(
        Order.id == body.order_id,
        Order.user_id == user_id,
        Order.is_deleted == False,
    ).first()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")

    if order.status != "Pending":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Payment already processed")

    existing_payment = db.query(Payment).filter(
        Payment.order_id == order.id,
        Payment.is_deleted == False,
    ).first()
    if existing_payment:
        return _payment_to_response(existing_payment)

    payment = Payment(
        order_id=order.id,
        user_id=user_id,
        amount=order.total_amount,
        method=body.method,
        status="success",
        transaction_id="COD" + datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S") + str(uuid.uuid4()).split("-")[0],
    )
    order.status = "Confirmed"
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return _payment_to_response(payment)


@router.get("/payments/{order_id}", response_model=PaymentResponse)
def get_payment(order_id: str, request: Request, db: Session = Depends(get_db)):
    user_id = get_user_id(request)
    payment = db.query(Payment).filter(
        Payment.order_id == order_id,
        Payment.user_id == user_id,
        Payment.is_deleted == False,
    ).first()
    if not payment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Payment not found")
    return _payment_to_response(payment)
