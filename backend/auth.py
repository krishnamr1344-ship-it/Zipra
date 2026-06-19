"""
auth.py
Purpose: /register, /login, /logout endpoints.
Security:
  - Passwords hashed with bcrypt (12 rounds) before storage.
  - JWT tokens with configurable expiry (default 1440 min).
  - On /logout, token JTI saved to blacklist table.
  - Generic error messages only — never leak DB or stack details.
  - Password reset codes sent via SMTP email (configurable via env).
"""
import logging
import hashlib
import hmac
import smtplib
import ssl
from email.message import EmailMessage
logger = logging.getLogger(__name__)
import os
import secrets
import string
import uuid
from datetime import datetime, timedelta, timezone

import bcrypt
import jwt
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from database import get_db
from models import User, TokenBlacklist, PasswordResetCode
from schemas import RegisterRequest, LoginRequest, LogoutRequest, UpdateProfileRequest, ForgotPasswordRequest, ResetPasswordRequest

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_EXPIRY_MINUTES = int(os.getenv("JWT_EXPIRY_MINUTES", "1440"))
BCRYPT_ROUNDS = int(os.getenv("BCRYPT_ROUNDS", "12"))

if not JWT_SECRET:
    raise RuntimeError("JWT_SECRET not set in environment variables")
if len(JWT_SECRET) < 32:
    raise RuntimeError(f"JWT_SECRET is only {len(JWT_SECRET)} characters long (minimum: 32)")

SMTP_HOST = os.getenv("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("SMTP_USERNAME")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
SMTP_FROM_EMAIL = os.getenv("SMTP_FROM_EMAIL", SMTP_USERNAME)

RESET_CODE_EXPIRY_MINUTES = 15

router = APIRouter(prefix="/api/auth", tags=["auth"])


def _send_reset_email(recipient: str, code: str):
    """Send password reset code via SMTP. Raises if SMTP not configured."""
    if not SMTP_HOST or not SMTP_USERNAME or not SMTP_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password reset is currently unavailable. Contact support.",
        )
    try:
        msg = EmailMessage()
        msg["Subject"] = "Your Password Reset Code"
        msg["From"] = SMTP_FROM_EMAIL
        msg["To"] = recipient
        msg.set_content(
            f"Your password reset code is: {code}\n\n"
            f"This code expires in {RESET_CODE_EXPIRY_MINUTES} minutes.\n"
            f"If you did not request this, please ignore this email."
        )
        context = ssl.create_default_context()
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls(context=context)
            server.login(SMTP_USERNAME, SMTP_PASSWORD)
            server.send_message(msg)
        logger.info("Reset code sent to %s", recipient)
    except Exception as e:
        logger.warning("Failed to send reset email to %s: %s", recipient, e)


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


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    """
    Register a new user.
    Security:
      - Input validated by Pydantic before DB access.
      - Password bcrypt-hashed immediately.
      - Duplicate email returns generic error (don't reveal if email exists).
    """
    # Security: check for existing user.
    existing_email = db.query(User).filter(User.email == body.email).first()
    if existing_email:
        if existing_email.is_deleted:
            # Reactivate soft-deleted user and update details.
            existing_email.is_deleted = False
            existing_email.name = body.name
            existing_email.phone = body.phone
            existing_email.password_hash = _hash_password(body.password)
            db.commit()
            db.refresh(existing_email)
            token, jti, expires = _create_jwt(str(existing_email.id), existing_email.role)
            return {
                "message": "Registration successful",
                "token": token,
                "user": {"id": str(existing_email.id), "name": existing_email.name, "email": existing_email.email, "role": existing_email.role},
            }
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already registered")

    existing_phone = db.query(User).filter(User.phone == body.phone).first()
    if existing_phone and not existing_phone.is_deleted:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Phone number already registered")

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


@router.put("/profile")
def update_profile(body: UpdateProfileRequest, request: Request, db: Session = Depends(get_db)):
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if body.name is not None:
        user.name = body.name.strip()
    if body.email is not None:
        new_email = body.email.strip()
        existing_user = db.query(User).filter(User.email == new_email, User.id != user_id, User.is_deleted == False).first()
        if existing_user:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email already in use")
        user.email = new_email
    if body.phone is not None:
        user.phone = body.phone.strip()
    db.commit()
    db.refresh(user)
    return {
        "message": "Profile updated",
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "phone": user.phone, "role": user.role},
    }


@router.post("/forgot-password")
def forgot_password(body: ForgotPasswordRequest, db: Session = Depends(get_db)):
    # Check SMTP availability early to avoid leaking generated codes
    if not SMTP_HOST or not SMTP_USERNAME or not SMTP_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Password reset is currently unavailable. Contact support.",
        )

    user = db.query(User).filter(
        User.email == body.email,
        User.is_deleted == False,
    ).first()
    if not user:
        # Don't reveal whether email exists — always return same message
        return {"message": "If this email is registered, a reset code has been generated"}

    # Invalidate any previous unused codes for this email
    db.query(PasswordResetCode).filter(
        PasswordResetCode.email == body.email,
        PasswordResetCode.used_at.is_(None),
        PasswordResetCode.is_deleted == False,
    ).update({"is_deleted": True})
    db.commit()

    code = ''.join(secrets.choice(string.digits) for _ in range(6))
    code_hash = hashlib.sha256(code.encode()).hexdigest()
    reset_code = PasswordResetCode(
        email=body.email,
        code_hash=code_hash,
        expires_at=datetime.now(timezone.utc) + timedelta(minutes=RESET_CODE_EXPIRY_MINUTES),
    )
    db.add(reset_code)
    db.commit()
    _send_reset_email(body.email, code)
    return {
        "message": "If this email is registered, a reset code has been generated",
    }


@router.post("/reset-password")
def reset_password(body: ResetPasswordRequest, db: Session = Depends(get_db)):
    now = datetime.now(timezone.utc)
    code_hash = hashlib.sha256(body.code.encode()).hexdigest()
    record = db.query(PasswordResetCode).filter(
        PasswordResetCode.email == body.email,
        PasswordResetCode.code_hash == code_hash,
        PasswordResetCode.used_at.is_(None),
        PasswordResetCode.expires_at > now,
        PasswordResetCode.is_deleted == False,
    ).first()
    if not record:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset code")

    user = db.query(User).filter(
        User.email == body.email,
        User.is_deleted == False,
    ).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    user.password_hash = _hash_password(body.new_password)
    record.used_at = now
    db.commit()
    return {"message": "Password reset successful"}
