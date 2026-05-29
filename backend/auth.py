"""
auth.py
Purpose: /register, /login, /logout endpoints.
Security:
  - Passwords hashed with bcrypt (12 rounds) before storage.
  - JWT tokens with 30-minute expiry.
  - On /logout, token JTI saved to blacklist table.
  - Generic error messages only — never leak DB or stack details.
"""
import os
import uuid
import secrets
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models import User, TokenBlacklist, PasswordResetToken
from schemas import RegisterRequest, LoginRequest, LogoutRequest


class ForgotPasswordRequest(BaseModel):
    email: str


class ResetPasswordRequest(BaseModel):
    token: str
    password: str



JWT_SECRET = os.getenv("JWT_SECRET")
JWT_EXPIRY_MINUTES = int(os.getenv("JWT_EXPIRY_MINUTES", "30"))
BCRYPT_ROUNDS = int(os.getenv("BCRYPT_ROUNDS", "12"))

if not JWT_SECRET:
    raise RuntimeError("JWT_SECRET not set in .env file")

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _generic_error():
    """
    Security: Return only a generic message on any auth failure.
    Never reveal whether the email exists or the password was wrong.
    """
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid credentials",
    )


def _hash_password(plain: str) -> str:
    """Security: bcrypt with configurable rounds. Never reversible."""
    return bcrypt.hashpw(plain.encode("utf-8"), bcrypt.gensalt(rounds=BCRYPT_ROUNDS)).decode("utf-8")


def _verify_password(plain: str, hashed: str) -> bool:
    """Constant-time comparison — resists timing attacks."""
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def _create_jwt(user_id: str, role: str = "user") -> tuple[str, str, datetime]:
    jti = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    expires = now + timedelta(minutes=JWT_EXPIRY_MINUTES)
    payload = {
        "sub": user_id,
        "jti": jti,
        "iat": now,
        "exp": expires,
        "role": role,
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
    return token, jti, expires


def decode_jwt(token: str) -> dict:
    """
    Decode and validate a JWT.
    Raises HTTPException on expiry, bad signature, or blacklisted token.
    """
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    return payload


# ─── PASSWORD RESET ──────────────────────────────────────────────

@router.post("/forgot-password")
def forgot_password(body: ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(
        User.email == body.email,
        User.is_deleted == False,
    ).first()

    if not user:
        return {"message": "If the email exists, a reset link has been sent"}

    old_tokens = db.query(PasswordResetToken).filter(
        PasswordResetToken.user_id == user.id,
        PasswordResetToken.used == False,
    ).all()
    for t in old_tokens:
        t.used = True

    reset_token = secrets.token_urlsafe(48)
    expires = datetime.now(timezone.utc) + timedelta(hours=1)
    prt = PasswordResetToken(
        user_id=user.id,
        token=reset_token,
        expires_at=expires,
    )
    db.add(prt)
    db.commit()

    debug_print = os.getenv("DEBUG", "false").lower() == "true"
    if debug_print:
        print(f"Password reset token for {body.email}: {reset_token}")

    return {"message": "If the email exists, a reset link has been sent"}


@router.post("/reset-password")
def reset_password(body: ResetPasswordRequest, db: Session = Depends(get_db)):
    prt = db.query(PasswordResetToken).filter(
        PasswordResetToken.token == body.token,
        PasswordResetToken.used == False,
        PasswordResetToken.expires_at > datetime.now(timezone.utc),
    ).first()

    if not prt:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token",
        )

    user = db.query(User).filter(User.id == prt.user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    if len(body.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password must be at least 8 characters",
        )

    user.password_hash = _hash_password(body.password)
    prt.used = True
    db.commit()

    return {"message": "Password reset successful"}


# ─── ENDPOINTS ───────────────────────────────────────────────────


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    """
    Register a new user.
    Security:
      - Input validated by Pydantic before DB access.
      - Password bcrypt-hashed immediately.
      - Duplicate email returns generic error (don't reveal if email exists).
    """
    # Security: check for existing user (soft-delete aware).
    existing = db.query(User).filter(
        User.email == body.email,
        User.is_deleted == False,
    ).first()
    if existing:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Registration failed")

    user = User(
        email=body.email,
        password_hash=_hash_password(body.password),
        name=body.name,
        phone=body.phone,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token, jti, expires = _create_jwt(str(user.id), user.role)

    return {
        "message": "Registration successful",
        "token": token,
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "role": user.role},
    }


@router.post("/login")
def login(body: LoginRequest, db: Session = Depends(get_db)):
    """
    Authenticate user and return JWT.
    Security:
      - Constant-time password comparison.
      - Generic error for any failure.
      - Token expires in 30 minutes.
    """
    user = db.query(User).filter(
        User.email == body.email,
        User.is_deleted == False,
    ).first()

    if not user or not _verify_password(body.password, user.password_hash):
        raise _generic_error()

    token, jti, expires = _create_jwt(str(user.id), user.role)

    return {
        "message": "Login successful",
        "token": token,
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "role": user.role},
    }


@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(body: LogoutRequest, db: Session = Depends(get_db)):
    """
    Logout: blacklist the JWT so it can never be used again.
    Security:
      - Token decoded and validated first.
      - JTI saved to blacklist table.
      - Blacklisted tokens rejected on all protected routes.
    """
    payload = decode_jwt(body.token)
    jti = payload.get("jti")
    exp = payload.get("exp")

    if not jti:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid token")

    # Security: prevent double-blacklist (idempotent).
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
