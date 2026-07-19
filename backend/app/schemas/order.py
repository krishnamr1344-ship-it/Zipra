from typing import Optional
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, Field, field_validator

VALID_PAYMENT_METHODS = {"cod", "COD"}
VALID_ORDER_STATUSES = {"Pending", "Confirmed", "Shipped", "Delivered", "Cancelled"}


class OrderItemInput(BaseModel):
    product_id: str
    quantity: int = Field(ge=1)


class OrderCreateRequest(BaseModel):
    address_id: str
    payment_method: str
    delivery_fee: Optional[Decimal] = None

    @field_validator("payment_method")
    @classmethod
    def valid_method(cls, v):
        v = v.strip().lower()
        if v not in VALID_PAYMENT_METHODS:
            raise ValueError(f"Payment method must be one of: {', '.join(sorted(VALID_PAYMENT_METHODS))}")
        return "COD"


class OrderDirectCreateRequest(BaseModel):
    items: list[OrderItemInput] = Field(min_length=1)
    payment_method: str
    address_id: Optional[str] = None
    delivery_fee: Optional[Decimal] = None

    @field_validator("payment_method")
    @classmethod
    def valid_method(cls, v):
        v = v.strip().lower()
        if v not in VALID_PAYMENT_METHODS:
            raise ValueError(f"Payment method must be one of: {', '.join(sorted(VALID_PAYMENT_METHODS))}")
        return "COD"


class OrderItemResponse(BaseModel):
    id: str
    product_id: str
    product_name: str
    product_price: float
    quantity: int
    subtotal: float

    class Config:
        from_attributes = True


class DeliveryAddress(BaseModel):
    address_line1: str
    address_line2: Optional[str] = None
    city: str
    state: str
    pincode: str
    address_type: Optional[str] = None
    house_number: Optional[str] = None
    floor_number: Optional[str] = None
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    maps_link: Optional[str] = None


class OrderResponse(BaseModel):
    id: str
    status: str
    total_amount: float
    payment_method: str
    delivery_fee: Optional[float] = None
    items: list[OrderItemResponse] = []
    delivery_address: Optional[DeliveryAddress] = None
    created_at: datetime

    class Config:
        from_attributes = True


class StatusUpdateRequest(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def valid_status(cls, v):
        if v not in VALID_ORDER_STATUSES:
            raise ValueError(f"Status must be one of: {', '.join(sorted(VALID_ORDER_STATUSES))}")
        return v
