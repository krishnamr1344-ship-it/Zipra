import re
from typing import Optional
from decimal import Decimal
from pydantic import BaseModel, field_validator

PRODUCT_NAME_LENGTH = 200
DESC_LENGTH = 2000
UNIT_LENGTH = 20
NAME_REGEX = r"^[a-zA-Z\s.\-]{2,50}$"
NAME_REGEX_MSG = "Invalid name format (only letters, spaces, dots, hyphens; 2-50 chars)"


class ProductCreate(BaseModel):
    category_id: str
    shop_id: Optional[str] = None
    name: str
    description: Optional[str] = None
    price: Decimal
    original_price: Optional[Decimal] = None
    unit: str
    images: list[str] = []
    stock: int = 0

    @field_validator("name")
    @classmethod
    def valid_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Product name is required")
        if len(v) > PRODUCT_NAME_LENGTH:
            raise ValueError(f"Name must not exceed {PRODUCT_NAME_LENGTH} characters")
        if not re.match(NAME_REGEX, v):
            raise ValueError(NAME_REGEX_MSG)
        return v

    @field_validator("price")
    @classmethod
    def valid_price(cls, v):
        if v <= 0:
            raise ValueError("Price must be greater than 0")
        return v

    @field_validator("unit")
    @classmethod
    def valid_unit(cls, v):
        v = v.strip().lower()
        if not v:
            raise ValueError("Unit is required")
        if len(v) > UNIT_LENGTH:
            raise ValueError(f"Unit must not exceed {UNIT_LENGTH} characters")
        return v

    @field_validator("stock")
    @classmethod
    def valid_stock(cls, v):
        if v < 0:
            raise ValueError("Stock cannot be negative")
        return v

    @field_validator("description")
    @classmethod
    def valid_desc(cls, v):
        if v and len(v) > DESC_LENGTH:
            raise ValueError(f"Description must not exceed {DESC_LENGTH} characters")
        return v


class ProductResponse(BaseModel):
    id: str
    category_id: str
    category_name: Optional[str] = None
    name: str
    description: Optional[str] = None
    price: float
    original_price: Optional[float] = None
    unit: str
    images: list[str] = []
    stock: int

    class Config:
        from_attributes = True
