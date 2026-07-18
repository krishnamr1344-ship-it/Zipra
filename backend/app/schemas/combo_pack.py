from typing import Optional
from datetime import datetime
from decimal import Decimal
from pydantic import BaseModel, Field, field_validator

PACK_NAME_LENGTH = 200
PACK_DESC_LENGTH = 2000


class ComboPackItemInput(BaseModel):
    product_id: str
    quantity: int = Field(ge=1, le=100)


class PackAddRequest(BaseModel):
    pack_id: str


class ComboPackItemResponse(BaseModel):
    id: str
    product_id: str
    product_name: str
    product_price: float
    product_unit: str
    product_image: Optional[str] = None
    quantity: int

    class Config:
        from_attributes = True


class ComboPackCreate(BaseModel):
    name: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    total_price: Decimal
    discount_label: Optional[str] = None
    savings_text: Optional[str] = None
    items: list[ComboPackItemInput] = Field(min_length=1)

    @field_validator("name")
    @classmethod
    def valid_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Pack name is required")
        if len(v) > PACK_NAME_LENGTH:
            raise ValueError(f"Name must not exceed {PACK_NAME_LENGTH} characters")
        return v

    @field_validator("total_price")
    @classmethod
    def valid_price(cls, v):
        if v <= 0:
            raise ValueError("Total price must be greater than 0")
        return v

    @field_validator("description")
    @classmethod
    def valid_desc(cls, v):
        if v and len(v) > PACK_DESC_LENGTH:
            raise ValueError(f"Description must not exceed {PACK_DESC_LENGTH} characters")
        return v


class ComboPackUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    image_url: Optional[str] = None
    total_price: Optional[Decimal] = None
    discount_label: Optional[str] = None
    savings_text: Optional[str] = None
    is_enabled: Optional[bool] = None
    items: Optional[list[ComboPackItemInput]] = None

    @field_validator("name")
    @classmethod
    def valid_name(cls, v):
        if v:
            v = v.strip()
            if len(v) > PACK_NAME_LENGTH:
                raise ValueError(f"Name must not exceed {PACK_NAME_LENGTH} characters")
        return v

    @field_validator("total_price")
    @classmethod
    def valid_price(cls, v):
        if v is not None and v <= 0:
            raise ValueError("Total price must be greater than 0")
        return v


class ComboPackResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    image_url: Optional[str] = None
    total_price: float
    discount_label: Optional[str] = None
    savings_text: Optional[str] = None
    is_enabled: bool
    items: list[ComboPackItemResponse] = []
    created_at: datetime

    class Config:
        from_attributes = True
