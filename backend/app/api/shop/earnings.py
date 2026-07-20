from datetime import datetime, timezone, timedelta

from fastapi import APIRouter, Depends, Request
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.db.session import get_db
from app.models import Earning
from app.schemas import EarningResponse, EarningSummary
from app.utils.helpers import require_shop_owner, get_shop_for_owner

router = APIRouter(prefix="/api/shop/earnings", tags=["shop-earnings"])


@router.get("", response_model=list[EarningResponse])
def list_earnings(
    request: Request,
    status_filter: str = None,
    db: Session = Depends(get_db),
):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    query = db.query(Earning).filter(Earning.shop_id == shop.id, Earning.is_deleted == False)
    if status_filter:
        query = query.filter(Earning.status == status_filter)
    earnings = query.order_by(Earning.created_at.desc()).all()
    return [
        EarningResponse(
            id=str(e.id), shop_id=str(e.shop_id), order_id=str(e.order_id),
            amount=float(e.amount), commission=float(e.commission),
            net_amount=float(e.net_amount), status=e.status,
            settled_at=e.settled_at, created_at=e.created_at,
        ) for e in earnings
    ]


@router.get("/summary", response_model=EarningSummary)
def earnings_summary(request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    now = datetime.now(timezone.utc)
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    week_start = today_start - timedelta(days=today_start.weekday())
    month_start = today_start.replace(day=1)

    def _sum(start, end, status=None):
        q = db.query(func.coalesce(func.sum(Earning.net_amount), 0)).filter(
            Earning.shop_id == shop.id,
            Earning.is_deleted == False,
            Earning.created_at >= start,
            Earning.created_at < end,
        )
        if status:
            q = q.filter(Earning.status == status)
        return float(q.scalar())

    return EarningSummary(
        today=_sum(today_start, today_start + timedelta(days=1)),
        this_week=_sum(week_start, week_start + timedelta(days=7)),
        this_month=_sum(month_start, (month_start.replace(day=28) + timedelta(days=4)).replace(day=1)),
        total_pending=_sum(datetime.min.replace(tzinfo=timezone.utc), now, status="pending"),
        total_settled=_sum(datetime.min.replace(tzinfo=timezone.utc), now, status="settled"),
    )


@router.get("/settled", response_model=list[EarningResponse])
def settled_earnings(request: Request, db: Session = Depends(get_db)):
    user_id = require_shop_owner(request)
    shop = get_shop_for_owner(user_id, db)
    earnings = db.query(Earning).filter(
        Earning.shop_id == shop.id,
        Earning.status == "settled",
        Earning.is_deleted == False,
    ).order_by(Earning.settled_at.desc()).all()
    return [
        EarningResponse(
            id=str(e.id), shop_id=str(e.shop_id), order_id=str(e.order_id),
            amount=float(e.amount), commission=float(e.commission),
            net_amount=float(e.net_amount), status=e.status,
            settled_at=e.settled_at, created_at=e.created_at,
        ) for e in earnings
    ]
