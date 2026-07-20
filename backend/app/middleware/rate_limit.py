import time
from collections import defaultdict
from typing import Optional

from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from sqlalchemy.orm import Session

from app.core.config import (
    RATE_LIMIT_MAX_ATTEMPTS,
    RATE_LIMIT_WINDOW_SECONDS,
    RATE_LIMIT_BLOCK_MINUTES,
)
from app.core.constants import PUBLIC_PATHS, PUBLIC_PREFIXES, AUTH_RATE_LIMIT_PATHS, FAILURE_CODES
from app.core.security import decode_jwt
from app.db.session import SessionLocal
from app.models import TokenBlacklist, User

_rate_store: dict[str, list[float]] = defaultdict(list)
_blocked_ips: dict[str, float] = {}


class RateLimitMiddleware(BaseHTTPMiddleware):

    def _is_blocked(self, ip: str, now: float) -> Optional[JSONResponse]:
        if ip in _blocked_ips:
            if now < _blocked_ips[ip]:
                remaining = int(_blocked_ips[ip] - now)
                return JSONResponse(
                    status_code=429,
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

        is_auth = (path in AUTH_RATE_LIMIT_PATHS and request.method == "POST")

        if is_auth:
            block = self._is_blocked(ip, now)
            if block:
                return block

        if path not in PUBLIC_PATHS and not any(path.startswith(p) for p in PUBLIC_PREFIXES):
            auth_header = request.headers.get("Authorization")
            if not auth_header or not auth_header.startswith("Bearer "):
                return JSONResponse(
                    status_code=401,
                    content={"detail": "Missing or invalid Authorization header"},
                )

            token = auth_header.split(" ", 1)[1]

            try:
                payload = decode_jwt(token)
            except Exception as e:
                return JSONResponse(status_code=401, content={"detail": str(e.detail) if hasattr(e, 'detail') else "Invalid token"})

            jti = payload.get("jti")

            db: Session = SessionLocal()
            try:
                blacklisted = db.query(TokenBlacklist).filter(
                    TokenBlacklist.token_jti == jti,
                    TokenBlacklist.is_deleted == False,
                ).first()
                if blacklisted:
                    return JSONResponse(
                        status_code=401,
                        content={"detail": "Token has been revoked"},
                    )

                user = db.query(User).filter(User.id == payload.get("sub")).first()
                if not user or user.is_deleted:
                    return JSONResponse(
                        status_code=401,
                        content={"detail": "User no longer exists"},
                    )
                if user.role != payload.get("role", "user"):
                    return JSONResponse(
                        status_code=401,
                        content={"detail": "Token role mismatch — please re-login"},
                    )
            finally:
                db.close()

            request.state.user_id = payload.get("sub")
            request.state.user_role = payload.get("role", "user")

        response = await call_next(request)

        if is_auth and response.status_code in FAILURE_CODES:
            self._record_failure(ip, now)

        return response
