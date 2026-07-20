from typing import Optional
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, Field, field_validator


class DeliveryZoneCreate(BaseModel):
    zone_name: str = Field(..., max_length=100)
    geojson_data: str = Field(..., min_length=1)


class ZoneCheckRequest(BaseModel):
    lat: float
    lng: float


class ZoneCheckResponse(BaseModel):
    serviceable: bool
    message: Optional[str] = None


class DeliveryFeeCreate(BaseModel):
    min_order_amount: Decimal = Decimal("0.00")
    max_order_amount: Optional[Decimal] = None
    fee: Decimal = Field(..., gt=Decimal("0.00"))


class DeliveryFeeUpdate(BaseModel):
    min_order_amount: Optional[Decimal] = None
    max_order_amount: Optional[Decimal] = None
    fee: Optional[Decimal] = None
    is_active: Optional[bool] = None

    @field_validator("fee")
    @classmethod
    def validate_fee(cls, v):
        if v is not None and v <= 0:
            raise ValueError("Fee must be positive")
        return v


class DeliveryFeeResponse(BaseModel):
    id: str
    min_order_amount: float
    max_order_amount: Optional[float] = None
    fee: float
    is_active: bool
    created_at: datetime
