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
