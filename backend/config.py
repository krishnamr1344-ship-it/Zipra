"""
Shared configuration — single source of truth for public paths.
"""
import os as _os

PUBLIC_PATHS: set[str] = {
    "/", "/docs", "/openapi.json", "/redoc",
    "/api/auth/register", "/api/auth/login", "/api/auth/logout",
    "/api/auth/forgot-password", "/api/auth/reset-password",
    "/api/app-version", "/api/categories", "/api/products",
    "/api/combo-packs", "/api/check-zone", "/api/places/search",
    "/api/places/reverse", "/api/suggest-product",
    "/api/payments/webhook",
}

PUBLIC_PATH_PREFIXES: set[str] = set()

# ─── Razorpay ─────────────────────────────────────────────────────
RAZORPAY_ENABLED: bool = _os.getenv("RAZORPAY_ENABLED", "").lower() in ("1", "true", "yes")
RAZORPAY_KEY_ID: str = _os.getenv("RAZORPAY_KEY_ID", "")
RAZORPAY_KEY_SECRET: str = _os.getenv("RAZORPAY_KEY_SECRET", "")
RAZORPAY_WEBHOOK_SECRET: str = _os.getenv("RAZORPAY_WEBHOOK_SECRET", "")


# ─── Supabase ─────────────────────────────────────────────────────
SUPABASE_URL: str = _os.getenv("SUPABASE_URL", "")
SUPABASE_SERVICE_KEY: str = _os.getenv("SUPABASE_SERVICE_KEY", "") or _os.getenv("SUPABASE_SERVICE_ROLE_KEY", "")
SUPABASE_UPLOAD_KEY: str = _os.getenv("SUPABASE_UPLOAD_KEY", "") or SUPABASE_SERVICE_KEY
SUPABASE_STORAGE_BUCKET: str = _os.getenv("SUPABASE_STORAGE_BUCKET", "product-images")
