"""
schemas.py
Purpose: Pydantic models for request/response validation.
Security: Every input is validated BEFORE touching the database.
          Prevents injection, malformed data, and type confusion.
          Max lengths prevent buffer exhaustion / DoS via large payloads.
          Payments NEVER accept or expose sensitive data (card numbers, CVV, etc.).
"""
import re
from decimal import Decimal
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, Field, field_validator, computed_field

NAME_REGEX = r"^.{2,50}$"

NAME_REGEX_MSG = "Invalid name format (2-50 characters)"

MAX_NAME_LENGTH = 100
MAX_EMAIL_LENGTH = 255
MAX_PHONE_LENGTH = 20
MAX_PASSWORD_LENGTH = 128
MAX_TOKEN_LENGTH = 2048
PRODUCT_NAME_LENGTH = 200
DESC_LENGTH = 2000
ADDR_LINE_LENGTH = 255
CITY_LENGTH = 100
STATE_LENGTH = 100
PINCODE_LENGTH = 10
LABEL_LENGTH = 50
UNIT_LENGTH = 20
TRANSACTION_ID_LENGTH = 100
IMAGE_URL_LENGTH = 1000

VALID_PAYMENT_METHODS = {"cod", "COD"}
VALID_ORDER_STATUSES = {"Pending", "Confirmed", "Shipped", "Delivered", "Cancelled"}
VALID_PAYMENT_STATUSES = {"pending", "success", "failed"}


class RegisterRequest(BaseModel):
    """Validation schema for /register."""
    name: str
    email: str
    phone: str
    password: str

    # Security: Enforce minimum password strength.
    @field_validator("password")
    @classmethod
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if len(v) > MAX_PASSWORD_LENGTH:
            raise ValueError(f"Password must not exceed {MAX_PASSWORD_LENGTH} characters")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain an uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain a lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain a digit")
        return v

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

    @field_validator("name")
    @classmethod
    def name_nonempty(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Name is required")
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"Name must not exceed {MAX_NAME_LENGTH} characters")
        if not re.match(NAME_REGEX, v):
            raise ValueError(NAME_REGEX_MSG)
        return v

    @field_validator("phone")
    @classmethod
    def valid_phone(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Phone number is required")
        if len(v) > MAX_PHONE_LENGTH:
            raise ValueError(f"Phone must not exceed {MAX_PHONE_LENGTH} characters")
        if not re.match(r"^\+?[1-9]\d{9,14}$", v):
            raise ValueError("Invalid phone number format (10-15 digits, optional + prefix)")
        return v


class LoginRequest(BaseModel):
    """Validation schema for /login."""
    email: str
    password: str

    @field_validator("email")
    @classmethod
    def valid_email(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Email is required")
        if len(v) > MAX_EMAIL_LENGTH:
            raise ValueError(f"Email must not exceed {MAX_EMAIL_LENGTH} characters")
        return v.lower()

    @field_validator("password")
    @classmethod
    def nonempty(cls, v):
        if not v:
            raise ValueError("Password is required")
        if len(v) > MAX_PASSWORD_LENGTH:
            raise ValueError(f"Password must not exceed {MAX_PASSWORD_LENGTH} characters")
        return v


class LogoutRequest(BaseModel):
    """Validation schema for /logout."""
    token: str

    @field_validator("token")
    @classmethod
    def nonempty(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Token is required")
        if len(v) > MAX_TOKEN_LENGTH:
            raise ValueError(f"Token must not exceed {MAX_TOKEN_LENGTH} characters")
        return v


# ─── CATEGORY ─────────────────────────────────────────────────────

class CategoryCreate(BaseModel):
    name: str
    description: Optional[str] = None
    image: Optional[str] = None

    @field_validator("name")
    @classmethod
    def valid_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Category name is required")
        if len(v) > MAX_NAME_LENGTH:
            raise ValueError(f"Name must not exceed {MAX_NAME_LENGTH} characters")
        if not re.match(NAME_REGEX, v):
            raise ValueError(NAME_REGEX_MSG)
        return v

    @field_validator("description")
    @classmethod
    def valid_desc(cls, v):
        if v and len(v) > DESC_LENGTH:
            raise ValueError(f"Description must not exceed {DESC_LENGTH} characters")
        return v


class CategoryResponse(BaseModel):
    id: str
    name: str
    description: Optional[str] = None
    image: Optional[str] = None

    class Config:
        from_attributes = True


# ─── PRODUCT ──────────────────────────────────────────────────────

class ProductCreate(BaseModel):
    category_id: str
    name: str
    description: Optional[str] = None
    price: Decimal
    unit: str
    images: list[str] = []
    stock: int = 0
    discount_percent: int = 0

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
    unit: str
    images: list[str] = []
    stock: int
    discount_percent: int = 0
    is_enabled: bool = True

    @computed_field
    @property
    def final_price(self) -> float:
        return round(self.price * (100 - self.discount_percent) / 100, 2)

    class Config:
        from_attributes = True


# ─── ADDRESS ──────────────────────────────────────────────────────

class AddressCreate(BaseModel):
    label: str
    address_line1: str
    address_line2: Optional[str] = None
    city: str
    state: str = "Unknown"
    pincode: str
    address_type: str = "Home"
    house_number: Optional[str] = None
    floor_number: Optional[str] = None
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_default: bool = False

    @field_validator("address_type")
    @classmethod
    def valid_type(cls, v):
        if v not in ("Home", "Work", "Other"):
            raise ValueError("address_type must be Home, Work, or Other")
        return v

    @field_validator("label")
    @classmethod
    def valid_label(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Label is required (e.g. Home, Work)")
        if len(v) > LABEL_LENGTH:
            raise ValueError(f"Label must not exceed {LABEL_LENGTH} characters")
        return v

    @field_validator("address_line1")
    @classmethod
    def valid_line1(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Address line 1 is required")
        if len(v) > ADDR_LINE_LENGTH:
            raise ValueError(f"Address must not exceed {ADDR_LINE_LENGTH} characters")
        return v

    @field_validator("address_line2")
    @classmethod
    def valid_line2(cls, v):
        if v and len(v) > ADDR_LINE_LENGTH:
            raise ValueError(f"Address must not exceed {ADDR_LINE_LENGTH} characters")
        return v.strip() if v else v

    @field_validator("city")
    @classmethod
    def valid_city(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("City is required")
        if len(v) > CITY_LENGTH:
            raise ValueError(f"City must not exceed {CITY_LENGTH} characters")
        return v

    @field_validator("state")
    @classmethod
    def valid_state(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("State is required")
        if len(v) > STATE_LENGTH:
            raise ValueError(f"State must not exceed {STATE_LENGTH} characters")
        return v

    @field_validator("pincode")
    @classmethod
    def valid_pincode(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Pincode is required")
        if len(v) > PINCODE_LENGTH:
            raise ValueError(f"Pincode must not exceed {PINCODE_LENGTH} characters")
        if not re.match(r"^\d{5,10}$", v):
            raise ValueError("Pincode must be 5-10 digits")
        return v


class AddressUpdate(BaseModel):
    label: Optional[str] = None
    address_line1: Optional[str] = None
    address_line2: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    address_type: Optional[str] = None
    house_number: Optional[str] = None
    floor_number: Optional[str] = None
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_default: Optional[bool] = None

    @field_validator("label")
    @classmethod
    def valid_label(cls, v):
        if v:
            v = v.strip()
            if len(v) > LABEL_LENGTH:
                raise ValueError(f"Label must not exceed {LABEL_LENGTH} characters")
        return v

    @field_validator("address_line1")
    @classmethod
    def valid_line1(cls, v):
        if v:
            v = v.strip()
            if len(v) > ADDR_LINE_LENGTH:
                raise ValueError(f"Address must not exceed {ADDR_LINE_LENGTH} characters")
        return v

    @field_validator("city")
    @classmethod
    def valid_city(cls, v):
        if v:
            v = v.strip()
            if len(v) > CITY_LENGTH:
                raise ValueError(f"City must not exceed {CITY_LENGTH} characters")
        return v

    @field_validator("state")
    @classmethod
    def valid_state(cls, v):
        if v:
            v = v.strip()
            if len(v) > STATE_LENGTH:
                raise ValueError(f"State must not exceed {STATE_LENGTH} characters")
        return v

    @field_validator("pincode")
    @classmethod
    def valid_pincode(cls, v):
        if v:
            v = v.strip()
            if len(v) > PINCODE_LENGTH:
                raise ValueError(f"Pincode must not exceed {PINCODE_LENGTH} characters")
            if not re.match(r"^\d{5,10}$", v):
                raise ValueError("Pincode must be 5-10 digits")
        return v


class AddressResponse(BaseModel):
    id: str
    label: str
    address_line1: str
    address_line2: Optional[str] = None
    city: str
    state: str
    pincode: str
    address_type: str = "Home"
    house_number: Optional[str] = None
    floor_number: Optional[str] = None
    landmark: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_default: bool
    maps_link: Optional[str] = None

    class Config:
        from_attributes = True


class GpsAddressCreate(BaseModel):
    latitude: float
    longitude: float
    address_type: str = "Home"
    house_number: Optional[str] = None
    floor_number: Optional[str] = None
    landmark: Optional[str] = None

    @field_validator("address_type")
    @classmethod
    def valid_type(cls, v):
        if v not in ("Home", "Work", "Other"):
            raise ValueError("address_type must be Home, Work, or Other")
        return v


# ─── CART ─────────────────────────────────────────────────────────

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


# ─── ORDER ────────────────────────────────────────────────────────

class OrderItemInput(BaseModel):
    product_id: str
    quantity: int = Field(ge=1)

class OrderCreateRequest(BaseModel):
    address_id: str
    payment_method: str

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
    items: list[OrderItemResponse] = []
    delivery_address: Optional[DeliveryAddress] = None
    delivery_otp: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


# ─── PAYMENT ──────────────────────────────────────────────────────
# Security: NEVER accept or expose card numbers, CVV, bank details.

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


# ─── WISHLIST ────────────────────────────────────────────────────

class WishlistAddRequest(BaseModel):
    product_id: str


class WishlistItemResponse(BaseModel):
    id: str
    product_id: str
    product_name: str
    product_price: float
    product_unit: str
    product_image: Optional[str] = None
    product_discount_percent: int = 0
    product_final_price: float = 0
    created_at: datetime

    class Config:
        from_attributes = True


class WishlistRemoveResponse(BaseModel):
    message: str


# ─── COMBO PACKS ──────────────────────────────────────────────────

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


# ─── DELIVERY ZONE ────────────────────────────────────────────────

class DeliveryZoneCreate(BaseModel):
    zone_name: str = Field(..., max_length=100)
    geojson_data: str = Field(..., min_length=1)

    @field_validator("geojson_data")
    @classmethod
    def valid_geojson(cls, v):
        try:
            import json
            data = json.loads(v)
        except json.JSONDecodeError:
            raise ValueError("Invalid GeoJSON: not valid JSON")
        if not isinstance(data, dict) or "type" not in data:
            raise ValueError("Invalid GeoJSON: must be a JSON object with 'type' property")
        if data["type"] not in ("Polygon", "MultiPolygon"):
            raise ValueError("GeoJSON type must be Polygon or MultiPolygon")
        return v


class ZoneCheckRequest(BaseModel):
    lat: float
    lng: float


class ZoneCheckResponse(BaseModel):
    serviceable: bool
    message: Optional[str] = None


# ─── PRODUCT SUGGESTIONS ───────────────────────────────────────────

SUGGEST_PRODUCT_NAME_LENGTH = 300
SUGGEST_REASON_LENGTH = 2000


class ProductSuggestionCreate(BaseModel):
    product_name: str = Field(..., min_length=1, max_length=SUGGEST_PRODUCT_NAME_LENGTH)
    reason: Optional[str] = None

    @field_validator("reason")
    @classmethod
    def valid_reason(cls, v):
        if v and len(v) > SUGGEST_REASON_LENGTH:
            raise ValueError(f"Reason must not exceed {SUGGEST_REASON_LENGTH} characters")
        return v


# ─── GENERIC ──────────────────────────────────────────────────────

class MessageResponse(BaseModel):
    message: str


class UpdateProfileRequest(BaseModel):
    name: Optional[str] = None
    email: Optional[str] = None
    phone: Optional[str] = None

    @field_validator("name")
    @classmethod
    def valid_name(cls, v):
        if v:
            v = v.strip()
            if not v:
                raise ValueError("Name cannot be empty")
            if len(v) > MAX_NAME_LENGTH:
                raise ValueError(f"Name must not exceed {MAX_NAME_LENGTH} characters")
        return v

    @field_validator("email")
    @classmethod
    def valid_email(cls, v):
        if v:
            v = v.strip()
            if not v:
                raise ValueError("Email cannot be empty")
            if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", v):
                raise ValueError("Invalid email format")
        return v.lower() if v else v


class ForgotPasswordRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def valid_email(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Email is required")
        return v.lower()


class ResetPasswordRequest(BaseModel):
    email: str
    code: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if len(v) > MAX_PASSWORD_LENGTH:
            raise ValueError(f"Password must not exceed {MAX_PASSWORD_LENGTH} characters")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Password must contain an uppercase letter")
        if not re.search(r"[a-z]", v):
            raise ValueError("Password must contain a lowercase letter")
        if not re.search(r"\d", v):
            raise ValueError("Password must contain a digit")
        return v


class SuggestProductRequest(BaseModel):
    product_name: str
    reason: Optional[str] = None

    @field_validator("product_name")
    @classmethod
    def valid_name(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Product name is required")
        if len(v) > 200:
            raise ValueError("Product name must not exceed 200 characters")
        return v


class StatusUpdateRequest(BaseModel):
    status: str

    @field_validator("status")
    @classmethod
    def valid_status(cls, v):
        if v not in VALID_ORDER_STATUSES:
            raise ValueError(f"Status must be one of: {', '.join(sorted(VALID_ORDER_STATUSES))}")
        return v


class DeliveryVerifyRequest(BaseModel):
    otp: str

    @field_validator("otp")
    @classmethod
    def valid_otp(cls, v):
        if not re.match(r"^\d{6}$", v):
            raise ValueError("OTP must be exactly 6 digits")
        return v


class AppVersionResponse(BaseModel):
    latest_version: str
    apk_download_url: str
    release_notes: Optional[str] = None


class NotificationCreate(BaseModel):
    title: str
    message: Optional[str] = None
    type: str = "offer"
    image_url: Optional[str] = None
    link: Optional[str] = None

    @field_validator("title")
    @classmethod
    def valid_title(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Title is required")
        if len(v) > 200:
            raise ValueError("Title must not exceed 200 characters")
        return v

    @field_validator("message")
    @classmethod
    def valid_msg(cls, v):
        if v and len(v) > 2000:
            raise ValueError("Message must not exceed 2000 characters")
        return v

    @field_validator("type")
    @classmethod
    def valid_type(cls, v):
        v = v.strip().lower()
        allowed = {"offer", "promo", "update", "info"}
        if v not in allowed:
            raise ValueError(f"Type must be one of: {', '.join(sorted(allowed))}")
        return v


class NotificationResponse(BaseModel):
    id: str
    title: str
    message: Optional[str] = None
    type: str
    image_url: Optional[str] = None
    link: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True
