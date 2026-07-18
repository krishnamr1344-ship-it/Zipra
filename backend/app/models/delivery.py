import uuid
from datetime import datetime, timezone
from decimal import Decimal

from sqlalchemy import Column, String, Boolean, DateTime, Numeric
from sqlalchemy.dialects.postgresql import UUID

from app.db.base import Base


def _utcnow():
    return datetime.now(timezone.utc)


class DeliveryFee(Base):
    __tablename__ = "delivery_fees"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    min_order_amount = Column(Numeric(10, 2), default=Decimal("0.00"), nullable=False)
    max_order_amount = Column(Numeric(10, 2), nullable=True)
    fee = Column(Numeric(10, 2), nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    is_deleted = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)


class DeliveryZone(Base):
    __tablename__ = "delivery_zones"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    zone_name = Column(String(100), nullable=False)
    geojson_data = Column(String, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    is_deleted = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)
