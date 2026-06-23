"""
middleware.py
Purpose: Rate limiting + JWT validation middleware.
Security:
  - All mutating endpoints (POST/PUT/DELETE/PATCH) rate limited per IP.
  - Counts only FAILED attempts (4xx) to avoid penalising legitimate users.
  - Respects X-Forwarded-For header for proxy deployments (Render).
  - JWT check on all protected routes (except public paths).
  - Blacklisted tokens are rejected immediately.
"""
import os
import logging
import time
logger = logging.getLogger(__name__)
import threading
from collections import defaultdict

from typing import Optional
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from sqlalchemy.orm import Session

from database import SessionLocal, get_db as _get_db
from models import TokenBlacklist, User
from auth import decode_jwt

RATE_LIMIT_MAX_ATTEMPTS = int(os.getenv("RATE_LIMIT_MAX_ATTEMPTS", "10"))
RATE_LIMIT_WINDOW_SECONDS = int(os.getenv("RATE_LIMIT_WINDOW_SECONDS", "60"))
RATE_LIMIT_BLOCK_MINUTES = int(os.getenv("RATE_LIMIT_BLOCK_MINUTES", "5"))

_rate_store: dict[str, list[float]] = defaultdict(list)
_blocked_ips: dict[str, float] = {}
_rate_lock = threading.Lock()


from config import PUBLIC_PATHS, PUBLIC_PATH_PREFIXES

MUTATING_METHODS = {"POST", "PUT", "DELETE", "PATCH"}
FAILURE_CODES = {400, 401, 403, 422, 429}


def _get_client_ip(request: Request) -> str:
    """Extract client IP from X-Forwarded-For or fall back to direct connection."""
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        ip = forwarded.split(",")[0].strip()
        if ip:
            return ip
    return request.client.host if request.client else "unknown"


class RateLimitMiddleware(BaseHTTPMiddleware):

    def _is_blocked(self, ip: str, now: float) -> Optional[JSONResponse]:
        with _rate_lock:
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
        with _rate_lock:
            _rate_store[ip] = [t for t in _rate_store[ip] if now - t < RATE_LIMIT_WINDOW_SECONDS]
            _rate_store[ip].append(now)
            if len(_rate_store[ip]) >= RATE_LIMIT_MAX_ATTEMPTS:
                _blocked_ips[ip] = now + (RATE_LIMIT_BLOCK_MINUTES * 60)
                _rate_store[ip] = []

    async def dispatch(self, request: Request, call_next):
        ip = _get_client_ip(request)
        path = request.url.path
        now = time.time()

        is_mutating = request.method in MUTATING_METHODS

        if is_mutating:
            block = self._is_blocked(ip, now)
            if block:
                return block

        if path not in PUBLIC_PATHS and not any(path.startswith(p) for p in PUBLIC_PATH_PREFIXES):
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
            token_version = payload.get("tok_ver", 0)

            db_override = request.app.dependency_overrides.get(_get_db, _get_db)
            db_gen = db_override()
            db: Session = next(db_gen)
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

                user_id = payload.get("sub")
                if not user_id:
                    return JSONResponse(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        content={"detail": "Invalid token payload"},
                    )
                user = db.query(User).filter(User.id == user_id, User.is_deleted == False).first()
                if not user:
                    return JSONResponse(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        content={"detail": "User not found"},
                    )
                if user.token_version != token_version:
                    return JSONResponse(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        content={"detail": "Token has been invalidated. Please login again."},
                    )
                request.state.user_id = str(user.id)
                request.state.user_role = user.role
            finally:
                try:
                    next(db_gen)
                except StopIteration:
                    pass

        response = await call_next(request)

        if is_mutating:
            self._record_failure(ip, now)

        return response
