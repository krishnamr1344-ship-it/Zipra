PUBLIC_PATHS = {
    "/",
    "/api/auth/social",
    "/api/auth/login-email",
    "/api/auth/forgot-password",
    "/api/auth/reset-password",
    "/api/shop/login",
    "/api/check-zone",
    "/api/categories",
    "/api/products",
    "/api/places/search",
    "/api/combo-packs",
    "/api/delivery-fee",
    "/api/offers",
    "/docs",
    "/openapi.json",
    "/redoc",
}

PUBLIC_PREFIXES = {"/api/products/", "/api/categories/"}

AUTH_RATE_LIMIT_PATHS = {"/api/auth/social", "/api/auth/login-email", "/api/shop/login"}

VALID_PAYMENT_METHODS = {"cod", "COD"}
VALID_ORDER_STATUSES = {"Pending", "Confirmed", "Shipped", "Delivered", "Cancelled"}
VALID_PAYMENT_STATUSES = {"pending", "success", "failed"}
FAILURE_CODES = {401, 400, 422}
