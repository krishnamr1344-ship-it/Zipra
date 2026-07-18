import re
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, field_validator

MAX_NAME_LENGTH = 100
MAX_EMAIL_LENGTH = 255
MAX_PHONE_LENGTH = 20
MAX_PASSWORD_LENGTH = 128
PRODUCT_NAME_LENGTH = 200

VALID_SHOP_ORDER_STATUSES = {"new", "accepted", "packing", "ready_for_pickup", "out_for_delivery", "delivered", "cancelled"}


class ShopCreate(BaseModel):
    name: str
    description: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    gst_number: Optional[str] = None

    @field_validator("name")
    @classmethod
    def valid_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Shop name is required")
        if len(v) > 200:
            raise ValueError("Name must not exceed 200 characters")
        return v


class ShopUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    logo_url: Optional[str] = None
    banner_url: Optional[str] = None
    gst_number: Optional[str] = None
    bank_account_number: Optional[str] = None
    bank_ifsc: Optional[str] = None
    bank_name: Optional[str] = None
    is_active: Optional[bool] = None
    is_open: Optional[bool] = None


class ShopResponse(BaseModel):
    id: str
    owner_id: str
    name: str
    description: Optional[str] = None
    logo_url: Optional[str] = None
    banner_url: Optional[str] = None
    address: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    gst_number: Optional[str] = None
    is_active: bool
    is_open: bool
    created_at: datetime

    class Config:
        from_attributes = True


class ShopOwnerCreate(BaseModel):
    name: str
    email: str
    phone: str
    password: str
    shop_name: str

    @field_validator("email")
    @classmethod
    def valid_email(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Email is required")
        if len(v) > MAX_EMAIL_LENGTH:
            raise ValueError(f"Email must not exceed {MAX_EMAIL_LENGTH} characters")
        if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", v):
            raise ValueError("Invalid email format")
        return v.lower()

    @field_validator("password")
    @classmethod
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if len(v) > MAX_PASSWORD_LENGTH:
            raise ValueError(f"Password must not exceed {MAX_PASSWORD_LENGTH} characters")
        return v

    @field_validator("name")
    @classmethod
    def name_nonempty(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Name is required")
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"Name must not exceed {MAX_NAME_LENGTH} characters")
        return v

    @field_validator("phone")
    @classmethod
    def valid_phone(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Phone number is required")
        if len(v) > MAX_PHONE_LENGTH:
            raise ValueError(f"Phone must not exceed {MAX_PHONE_LENGTH} characters")
        return v

    @field_validator("shop_name")
    @classmethod
    def shop_name_nonempty(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Shop name is required")
        if len(v) > 200:
            raise ValueError("Shop name must not exceed 200 characters")
        return v


class ShopLoginRequest(BaseModel):
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def valid_email(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Email is required")
        return v.lower()

    @field_validator("password")
    @classmethod
    def nonempty(cls, v):
        if not v:
            raise ValueError("Password is required")
        return v


class ShopProductCreate(BaseModel):
    category_id: str
    name: str
    description: Optional[str] = None
    price: float
    original_price: Optional[float] = None
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
        return v

    @field_validator("stock")
    @classmethod
    def valid_stock(cls, v):
        if v < 0:
            raise ValueError("Stock cannot be negative")
        return v


class ShopProductResponse(BaseModel):
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
    approval_status: str
    created_at: datetime

    class Config:
        from_attributes = True


class ShopProductStockUpdate(BaseModel):
    stock: int

    @field_validator("stock")
    @classmethod
    def valid_stock(cls, v):
        if v < 0:
            raise ValueError("Stock cannot be negative")
        return v


class ShopOrderResponse(BaseModel):
    id: str
    order_id: str
    shop_id: str
    status: str
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    delivery_address: Optional[str] = None
    items: list = []
    total_amount: float
    payment_method: str
    accepted_at: Optional[datetime] = None
    packing_at: Optional[datetime] = None
    ready_at: Optional[datetime] = None
    delivered_at: Optional[datetime] = None
    cancelled_at: Optional[datetime] = None
    cancellation_reason: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class ShopOrderStatusUpdate(BaseModel):
    cancellation_reason: Optional[str] = None


class EarningResponse(BaseModel):
    id: str
    shop_id: str
    order_id: str
    amount: float
    commission: float
    net_amount: float
    status: str
    settled_at: Optional[datetime] = None
    created_at: datetime

    class Config:
        from_attributes = True


class EarningSummary(BaseModel):
    today: float
    this_week: float
    this_month: float
    total_pending: float
    total_settled: float


class DeliveryPartnerCreate(BaseModel):
    name: str
    phone: str
    vehicle_type: Optional[str] = None
    vehicle_number: Optional[str] = None

    @field_validator("name")
    @classmethod
    def name_nonempty(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Name is required")
        return v

    @field_validator("phone")
    @classmethod
    def valid_phone(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Phone number is required")
        return v


class DeliveryPartnerUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    vehicle_type: Optional[str] = None
    vehicle_number: Optional[str] = None
    is_available: Optional[bool] = None
    is_active: Optional[bool] = None


class DeliveryPartnerResponse(BaseModel):
    id: str
    name: str
    phone: str
    vehicle_type: Optional[str] = None
    vehicle_number: Optional[str] = None
    is_available: bool
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
