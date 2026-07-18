from typing import Optional
from datetime import datetime
from pydantic import BaseModel, field_validator

VALID_PAYMENT_METHODS = {"cod", "COD"}


class PaymentProcessRequest(BaseModel):
    order_id: str
    method: str

    @field_validator("method")
    @classmethod
    def valid_method(cls, v):
        v = v.strip().lower()
        if v not in VALID_PAYMENT_METHODS:
            raise ValueError(f"Payment method must be one of: {', '.join(sorted(VALID_PAYMENT_METHODS))}")
        return "COD"


class PaymentResponse(BaseModel):
    id: str
    order_id: str
    amount: float
    method: str
    status: str
    transaction_id: Optional[str] = None
    expires_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True
