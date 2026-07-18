import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
from fastapi import APIRouter, Depends, HTTPException, Request, status
from pydantic import BaseModel, field_validator
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models import User, TokenBlacklist
from app.schemas import RegisterRequest, LoginRequest, LogoutRequest
from app.core.security import hash_password, verify_password, create_jwt, decode_jwt
from app.core.config import JWT_SECRET, JWT_EXPIRY_MINUTES, BCRYPT_ROUNDS


MAX_TOKEN_LENGTH = 2048

router = APIRouter(prefix="/api/auth", tags=["auth"])

_firebase = None
_firebase_auth = None


def _init_firebase():
    global _firebase, _firebase_auth
    if _firebase is not None:
        return
    try:
        import firebase_admin
        from firebase_admin import auth as firebase_auth_module
        from firebase_admin import credentials

        try:
            firebase_admin.get_app()
        except ValueError:
            service_account_json_b64 = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON")
            if service_account_json_b64:
                import json
                import base64
                decoded = json.loads(base64.b64decode(service_account_json_b64).decode("utf-8"))
                cred = credentials.Certificate(decoded)
                firebase_admin.initialize_app(cred)
            elif os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"):
                cred = credentials.Certificate(os.getenv("FIREBASE_SERVICE_ACCOUNT_PATH"))
                firebase_admin.initialize_app(cred)
            else:
                firebase_admin.initialize_app()

        _firebase = firebase_admin
        _firebase_auth = firebase_auth_module
    except Exception:
        _firebase = None
        _firebase_auth = None


def _verify_firebase_token(id_token: str) -> dict:
    _init_firebase()
    if _firebase_auth is None:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Firebase authentication is not configured on the server",
        )
    try:
        return _firebase_auth.verify_id_token(id_token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired Firebase ID token",
        )


def _generic_error():
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid credentials",
    )


@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(body: LogoutRequest, db: Session = Depends(get_db)):
    payload = decode_jwt(body.token)
    jti = payload.get("jti")
    exp = payload.get("exp")

    if not jti:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid token")

    already = db.query(TokenBlacklist).filter(
        TokenBlacklist.token_jti == jti,
        TokenBlacklist.is_deleted == False,
    ).first()
    if already:
        return {"message": "Already logged out"}

    bl = TokenBlacklist(
        token_jti=jti,
        expires_at=datetime.fromtimestamp(exp, tz=timezone.utc) if exp else datetime.now(timezone.utc) + timedelta(minutes=30),
    )
    db.add(bl)
    db.commit()

    return {"message": "Logged out successfully"}


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


@router.post("/social", status_code=status.HTTP_200_OK)
def social_login(body: SocialLoginRequest, db: Session = Depends(get_db)):
    decoded_token = _verify_firebase_token(body.id_token)

    token_email = (decoded_token.get("email") or "").strip().lower()
    if not token_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not available from authentication provider",
        )

    user = db.query(User).filter(User.email == token_email).first()
    if user:
        if user.is_deleted:
            user.is_deleted = False
            user.name = (body.name or token_email.split("@")[0]).strip() or "User"
            user.phone = body.phone or ""
    else:
        user = User(
            email=token_email,
            name=(body.name or token_email.split("@")[0]).strip() or "User",
            phone=body.phone or "",
            password_hash="",
            role="user",
        )
        db.add(user)
    db.commit()
    db.refresh(user)

    token, _jti, _expires = create_jwt(str(user.id), user.role)
    return {
        "message": "Login successful",
        "token": token,
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "role": user.role},
    }


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


@router.post("/login-email", status_code=status.HTTP_200_OK)
def email_login(body: EmailLoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        User.email == body.email.lower(),
        User.is_deleted == False,
    ).first()
    if not user or not user.password_hash:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not bcrypt.checkpw(body.password.encode("utf-8"), user.password_hash.encode("utf-8")):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if user.role not in ("shop_owner", "admin"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Use Google Sign-In for customer accounts")

    token, _jti, _expires = create_jwt(str(user.id), user.role)
    return {
        "message": "Login successful",
        "token": token,
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "role": user.role},
    }


class ForgotPasswordRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def valid_email(cls, v):
        v = v.strip()
        if not v:
            raise ValueError("Email is required")
        return v.lower()


@router.post("/forgot-password", status_code=status.HTTP_200_OK)
def forgot_password(body: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        User.email == body.email.lower(),
        User.is_deleted == False,
    ).first()
    if not user:
        return {"message": "If the email exists, a reset link has been sent"}
    reset_token = str(uuid.uuid4())
    user.password_reset_token = reset_token
    user.password_reset_token_expires = datetime.now(timezone.utc) + timedelta(hours=1)
    db.commit()
    return {"message": "If the email exists, a reset link has been sent", "reset_token": reset_token}


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


@router.post("/reset-password", status_code=status.HTTP_200_OK)
def reset_password(body: ResetPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        User.password_reset_token == body.token,
        User.is_deleted == False,
    ).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset token")
    if user.password_reset_token_expires and user.password_reset_token_expires < datetime.now(timezone.utc):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Reset token has expired")
    user.password_hash = hash_password(body.new_password)
    user.password_reset_token = None
    user.password_reset_token_expires = None
    db.commit()
    return {"message": "Password reset successful"}


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_strength(cls, v):
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


@router.post("/change-password", status_code=status.HTTP_200_OK)
def change_password(body: ChangePasswordRequest, request: Request, db: Session = Depends(get_db)):
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user or not user.password_hash:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid current password")
    if not bcrypt.checkpw(body.current_password.encode("utf-8"), user.password_hash.encode("utf-8")):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid current password")
    user.password_hash = hash_password(body.new_password)
    db.commit()
    return {"message": "Password changed successfully"}
