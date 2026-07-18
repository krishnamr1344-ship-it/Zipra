import re
from typing import Optional
from pydantic import BaseModel, field_validator

ADDR_LINE_LENGTH = 255
CITY_LENGTH = 100
STATE_LENGTH = 100
PINCODE_LENGTH = 10
LABEL_LENGTH = 50


class AddressCreate(BaseModel):
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
