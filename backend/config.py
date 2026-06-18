"""
Shared configuration — single source of truth for public paths.
"""
PUBLIC_PATHS: set[str] = {
    "/", "/docs", "/openapi.json", "/redoc",
    "/api/auth/register", "/api/auth/login", "/api/auth/logout",
    "/api/auth/forgot-password", "/api/auth/reset-password",
    "/api/app-version", "/api/categories", "/api/products",
    "/api/combo-packs", "/api/check-zone", "/api/places/search",
    "/api/places/reverse", "/api/suggest-product",
    "/api/upload",
}

PUBLIC_PATH_PREFIXES: set[str] = set()


# ─── Supabase ─────────────────────────────────────────────────────
import os as _os

SUPABASE_URL: str = _os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY: str = _os.getenv("SUPABASE_SERVICE_KEY", "") or _os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_STORAGE_BUCKET: str = _os.getenv("SUPABASE_STORAGE_BUCKET", "product-images")
