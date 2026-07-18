import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, String, Boolean, DateTime, Numeric, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.db.base import Base


def _utcnow():
    return datetime.now(timezone.utc)


class DeliveryPartner(Base):
    __tablename__ = "delivery_partners"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    name = Column(String(255), nullable=False)
    phone = Column(String(20), nullable=False)
    vehicle_type = Column(String(50), nullable=True)
    vehicle_number = Column(String(20), nullable=True)
    is_available = Column(Boolean, default=True, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    is_deleted = Column(Boolean, default=False, nullable=False)
    current_latitude = Column(Numeric(10, 7), nullable=True)
    current_longitude = Column(Numeric(10, 7), nullable=True)
    created_at = Column(DateTime(timezone=True), default=_utcnow, nullable=False)

    user = relationship("User", backref="delivery_profiles")


class DeliveryAssignment(Base):
    __tablename__ = "delivery_assignments"
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    shop_order_id = Column(UUID(as_uuid=True), ForeignKey("shop_orders.id"), nullable=False, index=True)
    delivery_partner_id = Column(UUID(as_uuid=True), ForeignKey("delivery_partners.id"), nullable=True)
    status = Column(String(20), default="pending", nullable=False)
    assigned_at = Column(DateTime(timezone=True), nullable=True)
    picked_up_at = Column(DateTime(timezone=True), nullable=True)
    delivered_at = Column(DateTime(timezone=True), nullable=True)
    is_deleted = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime(timezone=True), default=_utcnow, nullable=False)

    shop_order = relationship("ShopOrder", backref="assignments")
    delivery_partner = relationship("DeliveryPartner", backref="assignments")
