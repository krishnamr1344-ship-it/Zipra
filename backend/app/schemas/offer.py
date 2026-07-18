from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field, field_validator


class OfferCreate(BaseModel):
    name: str
    description: Optional[str] = None
    discount_percent: int = Field(ge=1, le=100)
    image_url: Optional[str] = None

    @field_validator("name")
    @classmethod
    def valid_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Offer name is required")
        if len(v) > 200:
            raise ValueError("Name must not exceed 200 characters")
        return v


class OfferUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    discount_percent: Optional[int] = None
    image_url: Optional[str] = None
    is_active: Optional[bool] = None


class OfferResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    discount_percent: int
    image_url: Optional[str] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
