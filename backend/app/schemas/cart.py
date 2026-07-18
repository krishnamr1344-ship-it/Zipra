from typing import Optional
from pydantic import BaseModel, field_validator


class CartAddRequest(BaseModel):
    product_id: str
    quantity: int = 1

    @field_validator("quantity")
    @classmethod
    def valid_qty(cls, v):
        if v < 1:
            raise ValueError("Quantity must be at least 1")
        if v > 100:
            raise ValueError("Quantity must not exceed 100")
        return v


class CartUpdateRequest(BaseModel):
    quantity: int

    @field_validator("quantity")
    @classmethod
    def valid_qty(cls, v):
        if v < 0:
            raise ValueError("Quantity cannot be negative")
        if v > 100:
            raise ValueError("Quantity must not exceed 100")
        return v


class CartItemResponse(BaseModel):
    id: str
    product_id: str
    product_name: str
    product_price: float
    product_unit: str
    product_image: Optional[str] = None
    quantity: int
    subtotal: float

    class Config:
        from_attributes = True
