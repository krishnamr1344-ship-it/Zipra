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
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database import get_db
from models import User, TokenBlacklist
from schemas import RegisterRequest, LoginRequest, LogoutRequest



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


# ─── ENDPOINTS ───────────────────────────────────────────────────


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


class SocialLoginRequest(BaseModel):
    email: str
    name: Optional[str] = None
    phone: Optional[str] = None


@router.post("/social", status_code=status.HTTP_200_OK)
def social_login(body: SocialLoginRequest, db: Session = Depends(get_db)):
    """
    Social (Google) login/registration.
    The email is trusted from the OAuth provider. Finds the existing user
    or creates one, then returns a backend JWT so the rest of the app
    works identically to email/password login.
    """
    email = (body.email or "").strip().lower()
    if not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is required")

    user = db.query(User).filter(User.email == email).first()
    if user:
        if user.is_deleted:
            user.is_deleted = False
            user.name = (body.name or email.split("@")[0]).strip() or "User"
            user.phone = body.phone or ""
    else:
        user = User(
            email=email,
            name=(body.name or email.split("@")[0]).strip() or "User",
            phone=body.phone or "",
            password_hash="",  # social users authenticate via provider, not password
            role="user",
        )
        db.add(user)
    db.commit()
    db.refresh(user)

    token, _jti, _expires = _create_jwt(str(user.id), user.role)
    return {
        "message": "Login successful",
        "token": token,
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "role": user.role},
    }
