"""
middleware.py
Purpose: Rate limiting + JWT validation middleware.
Security:
  - /login & /register rate limited: counts only FAILED attempts per IP.
  - JWT check on all protected routes (except /register, /login).
  - Blacklisted tokens are rejected immediately.
"""
import os
import time
from collections import defaultdict

from typing import Optional
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from sqlalchemy.orm import Session

from database import SessionLocal
from models import TokenBlacklist
from auth import decode_jwt

RATE_LIMIT_MAX_ATTEMPTS = int(os.getenv("RATE_LIMIT_MAX_ATTEMPTS", "10"))
RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
RATE_LIMIT_BLOCK_MINUTES = int(os.getenv("RATE_LIMIT_BLOCK_MINUTES", "5"))

_rate_store: dict[str, list[float]] = defaultdict(list)
_blocked_ips: dict[str, float] = {}


PUBLIC_PATHS = {"/", "/api/auth/register", "/api/auth/login", "/api/check-zone", "/api/categories", "/api/products", "/api/places/search", "/api/places/reverse", "/api/combo-packs", "/api/suggest-product", "/docs", "/openapi.json", "/redoc"}

FAILURE_CODES = {401, 400, 422}


class RateLimitMiddleware(BaseHTTPMiddleware):

    def _is_blocked(self, ip: str, now: float) -> Optional[JSONResponse]:
        if ip in _blocked_ips:
            if now < _blocked_ips[ip]:
                remaining = int(_blocked_ips[ip] - now)
                return JSONResponse(
                    status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                    content={"detail": f"Too many attempts. Try again in {remaining} seconds."},
                    headers={"Retry-After": str(remaining)},
                )
            else:
                del _blocked_ips[ip]
        return None

    def _record_failure(self, ip: str, now: float):
        _rate_store[ip] = [t for t in _rate_store[ip] if now - t < RATE_LIMIT_WINDOW_SECONDS]
        _rate_store[ip].append(now)
        if len(_rate_store[ip]) >= RATE_LIMIT_MAX_ATTEMPTS:
            _blocked_ips[ip] = now + (RATE_LIMIT_BLOCK_MINUTES * 60)
            _rate_store[ip] = []

    async def dispatch(self, request: Request, call_next):
        ip = request.client.host if request.client else "unknown"
        path = request.url.path
        now = time.time()

        is_auth = (
            (path == "/api/auth/login" or path == "/api/auth/register")
            and request.method == "POST"
        )

        if is_auth:
            block = self._is_blocked(ip, now)
            if block:
                return block

        if path not in PUBLIC_PATHS:
            auth_header = request.headers.get("Authorization")
            if not auth_header or not auth_header.startswith("Bearer "):
                return JSONResponse(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    content={"detail": "Missing or invalid Authorization header"},
                )

            token = auth_header.split(" ", 1)[1]

            try:
                payload = decode_jwt(token)
            except HTTPException as e:
                return JSONResponse(status_code=e.status_code, content={"detail": e.detail})

            jti = payload.get("jti")

            db: Session = SessionLocal()
            try:
                blacklisted = db.query(TokenBlacklist).filter(
                    TokenBlacklist.token_jti == jti,
                    TokenBlacklist.is_deleted == False,
                ).first()
                if blacklisted:
                    return JSONResponse(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        content={"detail": "Token has been revoked"},
                    )
            finally:
                db.close()

            request.state.user_id = payload.get("sub")
            request.state.user_role = payload.get("role", "user")

        response = await call_next(request)

        if is_auth and response.status_code in FAILURE_CODES:
            self._record_failure(ip, now)

        return response
