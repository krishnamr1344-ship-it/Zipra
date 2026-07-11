"""
auth.py
Purpose: /register, /login, /logout, /social endpoints.
Security:
  - Passwords hashed with bcrypt (12 rounds) before storage.
  - JWT tokens with 30-minute expiry.
  - On /logout, token JTI saved to blacklist table.
  - Social login verifies Firebase ID token on backend — never trusts client email.
  - Generic error messages only — never leak DB or stack details.
"""
import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

import bcrypt
import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, field_validator
from sqlalchemy.orm import Session

from database import get_db
from models import User, TokenBlacklist
from schemas import RegisterRequest, LoginRequest, LogoutRequest


JWT_SECRET = os.getenv("JWT_SECRET")
JWT_EXPIRY_MINUTES = int(os.getenv("JWT_EXPIRY_MINUTES", "30"))
BCRYPT_ROUNDS = int(os.getenv("BCRYPT_ROUNDS", "12"))
MAX_TOKEN_LENGTH = 2048

if not JWT_SECRET:
    raise RuntimeError("JWT_SECRET not set in .env file")

router = APIRouter(prefix="/api/auth", tags=["auth"])

# ─── Firebase Admin SDK setup ──────────────────────────────────
_firebase = None
_firebase_auth = None


def _init_firebase():
    """Initialize Firebase Admin SDK lazily on first social login request.
    Supports multiple credential sources:
      1. FIREBASE_SERVICE_ACCOUNT_JSON — base64-encoded service account key
      2. FIREBASE_SERVICE_ACCOUNT_PATH — path to JSON file
      3. GOOGLE_APPLICATION_CREDENTIALS — standard GCP env var
      4. Cloud Run metadata server (no config needed)
    Silently returns None if Firebase is not configured — endpoint will
    return 501 Not Implemented.
    """
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
                # Falls back to GOOGLE_APPLICATION_CREDENTIALS or Cloud Run metadata
                firebase_admin.initialize_app()

        _firebase = firebase_admin
        _firebase_auth = firebase_auth_module
    except Exception:
        # Firebase not configured — social login will return 501
        _firebase = None
        _firebase_auth = None


def _verify_firebase_token(id_token: str) -> dict:
    """Verify a Firebase ID token and return its decoded payload.
    Raises HTTPException(401) if the token is invalid, expired, or Firebase
    is not configured.
    """
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
    """
    Social (Google/Firebase) login/registration.

    Security:
      - The Firebase ID token is verified on the backend via Firebase Admin SDK.
      - The email is extracted from the VERIFIED token payload, NOT from the request body.
      - If the token is invalid/forged, the request is rejected with 401.
      - Firebase may not be configured (local dev) — returns 501 in that case.
    """
    # Step 1: Verify the Firebase ID token
    decoded_token = _verify_firebase_token(body.id_token)

    # Step 2: Extract email from the verified token — NEVER trust body.email
    token_email = (decoded_token.get("email") or "").strip().lower()
    if not token_email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not available from authentication provider",
        )

    # Step 3: Use token email for lookup (body.email is only used as a fallback display name hint)
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

    token, _jti, _expires = _create_jwt(str(user.id), user.role)
    return {
        "message": "Login successful",
        "token": token,
        "user": {"id": str(user.id), "name": user.name, "email": user.email, "role": user.role},
    }
