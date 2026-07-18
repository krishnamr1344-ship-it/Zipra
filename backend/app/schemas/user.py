import re
from typing import Optional
from pydantic import BaseModel, field_validator

NAME_REGEX = r"^[a-zA-Z\s.\-]{2,50}$"
NAME_REGEX_MSG = "Invalid name format (only letters, spaces, dots, hyphens; 2-50 chars)"
MAX_NAME_LENGTH = 100
MAX_EMAIL_LENGTH = 255
MAX_PHONE_LENGTH = 20
MAX_PASSWORD_LENGTH = 128
MAX_TOKEN_LENGTH = 2048


class RegisterRequest(BaseModel):
    name: str
    email: str
    phone: str
    password: str

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


class EmailLoginRequest(BaseModel):
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


class SocialLoginRequest(BaseModel):
    email: str
    name: Optional[str] = None
    phone: Optional[str] = None
    id_token: str

    @field_validator("id_token")
    @classmethod
    def nonempty_token(cls, v):
        if not v or not v.strip():
            raise ValueError("Firebase ID token is required")
        if len(v) > MAX_TOKEN_LENGTH:
            raise ValueError(f"Token must not exceed {MAX_TOKEN_LENGTH} characters")
        return v.strip()


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
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if len(v) > MAX_TOKEN_LENGTH:
            raise ValueError(f"Password must not exceed {MAX_TOKEN_LENGTH} characters")
        return v


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v
