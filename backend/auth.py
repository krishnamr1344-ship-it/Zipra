"""
auth.py
Purpose: Google Sign-In auth only — /google-login, /logout, /me, /profile.
Security:
  - Firebase ID token verified using Google public keys.
  - JWT tokens with configurable expiry (default 1440 min).
  - On /logout, token JTI saved to blacklist table.
"""
import logging
import time
from typing import Optional
logger = logging.getLogger(__name__)
import os
import uuid
from datetime import datetime, timedelta, timezone

import jwt
import httpx
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from database import get_db
from models import User, TokenBlacklist
from schemas import GoogleLoginRequest, UpdateProfileRequest, UpdatePhoneRequest

JWT_SECRET = os.getenv("JWT_SECRET")
JWT_EXPIRY_MINUTES = int(os.getenv("JWT_EXPIRY_MINUTES", "1440"))

if not JWT_SECRET:
    raise RuntimeError("JWT_SECRET not set in environment variables")
if len(JWT_SECRET) < 32:
    raise RuntimeError(f"JWT_SECRET is only {len(JWT_SECRET)} characters long (minimum: 32)")

FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID")
if not FIREBASE_PROJECT_ID:
    raise RuntimeError("FIREBASE_PROJECT_ID not set in environment variables")

FIREBASE_CERTS_URL = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
FIREBASE_ISSUER = f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}"

_cached_keys: dict[str, str] = {}
_cached_keys_expiry: float = 0


def _get_firebase_keys() -> dict[str, str]:
    global _cached_keys, _cached_keys_expiry
    now = time.time()
    if _cached_keys and now < _cached_keys_expiry:
        return _cached_keys
    try:
        resp = httpx.get(FIREBASE_CERTS_URL, timeout=10)
        resp.raise_for_status()
        _cached_keys = resp.json()
        _cached_keys_expiry = now + 3600
    except Exception as e:
        logger.warning("Failed to fetch Firebase public keys: %s", e)
        if not _cached_keys:
            raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Unable to verify authentication")
    return _cached_keys


def verify_firebase_token(token: str) -> dict:
    keys = _get_firebase_keys()
    try:
        header = jwt.get_unverified_header(token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token format")
    kid = header.get("kid")
    if not kid or kid not in keys:
        keys = _get_firebase_keys()
        if not kid or kid not in keys:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    public_key = keys[kid]
    try:
        decoded = jwt.decode(
            token,
            public_key,
            algorithms=["RS256"],
            audience=FIREBASE_PROJECT_ID,
            issuer=FIREBASE_ISSUER,
        )
        return decoded
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")


def _create_jwt(user_id: str, role: str = "user", token_version: int = 0) -> tuple[str, str, datetime]:
    jti = str(uuid.uuid4())
    now = datetime.now(timezone.utc)
    expires = now + timedelta(minutes=JWT_EXPIRY_MINUTES)
    payload = {
        "sub": user_id,
        "jti": jti,
        "iat": now,
        "exp": expires,
        "role": role,
        "tok_ver": token_version,
    }
    token = jwt.encode(payload, JWT_SECRET, algorithm="HS256")
    return token, jti, expires


def decode_jwt(token: str) -> dict:
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    return payload


ADMIN_EMAIL = os.getenv("ADMIN_EMAIL", "").lower().strip()

router = APIRouter(prefix="/api/auth", tags=["auth"])


@router.post("/google-login")
def google_login(body: GoogleLoginRequest, db: Session = Depends(get_db)):
    decoded = verify_firebase_token(body.id_token)
    firebase_uid = decoded.get("uid")
    email = decoded.get("email", "")
    name = decoded.get("name", email.split("@")[0])
    if not firebase_uid or not email:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid token payload")

    user = db.query(User).filter(
        User.firebase_uid == firebase_uid,
        User.is_deleted == False,
    ).first()

    if not user:
        user = db.query(User).filter(
            User.email == email,
            User.is_deleted == False,
        ).first()
        if user:
            user.firebase_uid = firebase_uid
        else:
            role = "admin" if email.lower() == ADMIN_EMAIL else "user"
            user = User(
                firebase_uid=firebase_uid,
                email=email,
                name=name,
                role=role,
            )
            db.add(user)
        db.commit()
        db.refresh(user)

    token, jti, expires = _create_jwt(str(user.id), user.role, user.token_version)

    return {
        "message": "Login successful",
        "token": token,
        "user": {
            "id": str(user.id),
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "role": user.role,
        },
    }


@router.post("/logout", status_code=status.HTTP_200_OK)
def logout(request: Request, db: Session = Depends(get_db)):
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authorization header")
    token = auth_header.split(" ", 1)[1]
    payload = decode_jwt(token)
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


@router.get("/me")
def get_profile(request: Request, db: Session = Depends(get_db)):
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return {
        "user": {
            "id": str(user.id),
            "name": user.name,
            "email": user.email,
            "phone": user.phone,
            "role": user.role,
        },
    }


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
    if body.phone is not None:
        user.phone = body.phone.strip()

    db.commit()
    db.refresh(user)
    return {
        "message": "Profile updated",
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "phone": user.phone, "role": user.role},
    }


@router.put("/profile/phone")
def update_phone(body: UpdatePhoneRequest, request: Request, db: Session = Depends(get_db)):
    user_id = getattr(request.state, "user_id", None)
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.phone = body.phone.strip()
    db.commit()
    db.refresh(user)
    return {
        "message": "Phone number saved",
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "phone": user.phone, "role": user.role},
    }
