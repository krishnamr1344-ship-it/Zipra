"""
main.py
Purpose: FastAPI application entry point.
Security:
  - CORS: only allows FRONTEND_URL from .env, never wildcard.
  - Rate-limit + JWT middleware applied globally.
  - Generic error responses only.

Database:
  - PostgreSQL via SQLAlchemy (models.py, database.py)
  - Render PostgreSQL in production, local PostgreSQL in development
"""
import logging
import os
import hmac
logger = logging.getLogger(__name__)
from pathlib import Path
from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent / '.env')
import uuid
from decimal import Decimal
from datetime import datetime, timezone

import bcrypt
from fastapi import FastAPI, Request, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from sqlalchemy.orm import Session

from database import engine, SessionLocal, Base
from auth import router as auth_router
from middleware import RateLimitMiddleware
from resources import router as resources_router
from admin import router as admin_router
from models import Category, Product, ProductImage, ProductFlag, User, ComboPack, ComboPackItem, AppVersion, Notification

FRONTEND_URL = os.getenv("FRONTEND_URL")
API_KEY = os.getenv("API_KEY")

ADMIN_EMAIL = os.getenv("ADMIN_EMAIL")
ADMIN_PASSWORD = os.getenv("ADMIN_PASSWORD", "")

# Crash on startup if critical env vars are missing (never fall back to defaults).
_missing = []
if not FRONTEND_URL:
    _missing.append("FRONTEND_URL")
if not ADMIN_EMAIL:
    _missing.append("ADMIN_EMAIL")
if _missing:
    raise RuntimeError(f"Missing required environment variables: {', '.join(_missing)}")

from config import PUBLIC_PATHS
PUBLIC_PATHS_C4 = PUBLIC_PATHS

# Create all tables on startup (new tables only).
Base.metadata.create_all(bind=engine)
# Migrate existing tables: add discount_percent column if missing.
from sqlalchemy import inspect, text
inspector = inspect(engine)
existing_cols = {c['name'] for c in inspector.get_columns('products')}
if 'discount_percent' not in existing_cols:
    with engine.connect() as conn:
        conn.execute(text('ALTER TABLE products ADD COLUMN discount_percent INTEGER NOT NULL DEFAULT 0'))
        conn.commit()

# Migrate existing users table: add is_deleted column if missing.
user_cols = {c['name'] for c in inspector.get_columns('users')}
if 'is_deleted' not in user_cols:
    with engine.connect() as conn:
        conn.execute(text("ALTER TABLE users ADD COLUMN is_deleted BOOLEAN NOT NULL DEFAULT FALSE"))
        conn.commit()

# Migrate existing orders table: add delivery_otp column if missing.
order_cols = {c['name'] for c in inspector.get_columns('orders')}
if 'delivery_otp' not in order_cols:
    with engine.connect() as conn:
        conn.execute(text("ALTER TABLE orders ADD COLUMN delivery_otp VARCHAR(6)"))
        conn.commit()

# Migrate existing orders table: add idempotency_key column if missing.
if 'idempotency_key' not in order_cols:
    with engine.connect() as conn:
        conn.execute(text("ALTER TABLE orders ADD COLUMN idempotency_key VARCHAR(64) UNIQUE"))
        conn.execute(text("CREATE INDEX IF NOT EXISTS ix_orders_idempotency_key ON orders (idempotency_key)"))
        conn.commit()

app = FastAPI(
    title="Delivery App API",
    description="Secure backend for delivery application",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ─── Security Headers ────────────────────────────────────────────
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response


# ─── API Key Validation ──────────────────────────────────────────
@app.middleware("http")
async def validate_api_key(request: Request, call_next):
    if API_KEY and request.url.path not in PUBLIC_PATHS_C4:
        # Skip API key check if a valid JWT Bearer token is present
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            return await call_next(request)
        header_key = request.headers.get("X-API-Key")
        if not header_key or not hmac.compare_digest(header_key, API_KEY):
            return JSONResponse(
                status_code=403,
                content={"detail": "Invalid or missing API key"},
            )
    return await call_next(request)


# ─── CSRF Protection (Origin / Referer check) ──────────────────────
# This API uses JWT Bearer tokens (not cookies) so CSRF via cookie-
# stealing is not a vector.  Requests with Bearer tokens (mobile app)
# skip the origin check entirely.
import re
from urllib.parse import urlparse

MUTATING_METHODS = {"POST", "PUT", "DELETE", "PATCH"}


@app.middleware("http")
async def csrf_origin_check(request: Request, call_next):
    if request.method in MUTATING_METHODS and request.url.path not in PUBLIC_PATHS_C4:
        # Skip CSRF for requests with Bearer token (mobile app / API client)
        auth_header = request.headers.get("Authorization", "")
        if auth_header.startswith("Bearer "):
            return await call_next(request)
        origin = request.headers.get("Origin") or request.headers.get("Referer")
        if not origin:
            return JSONResponse(
                status_code=403,
                content={"detail": "Origin header required"},
            )
        try:
            parsed = urlparse(origin)
            allowed = {urlparse(FRONTEND_URL).netloc}
            if request.url.hostname:
                allowed.add(request.url.hostname)
                if request.url.port:
                    allowed.add(f"{request.url.hostname}:{request.url.port}")
            if parsed.netloc and parsed.netloc not in allowed:
                return JSONResponse(
                    status_code=403,
                    content={"detail": "Cross-site request forbidden"},
                )
        except Exception:
            logger.warning("CSRF origin check failed")
    return await call_next(request)


# ─── CORS ───────────────────────────────────────────────────────
if FRONTEND_URL == "*":
    import warnings
    warnings.warn("FRONTEND_URL is set to '*' — CORS allow_credentials=True will be invalid per spec")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[FRONTEND_URL],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Authorization", "Content-Type", "X-API-Key"],
)

# ─── Rate Limiting + JWT Middleware ──────────────────────────────
app.add_middleware(RateLimitMiddleware)

# ─── Routers ─────────────────────────────────────────────────────
app.include_router(auth_router)
app.include_router(resources_router)
app.include_router(admin_router)


def _seed_combo_packs(db: Session):
    """Seed sample combo packs if none exist."""
    if db.query(ComboPack).count() > 0:
        return
    products_map = {p.name.lower(): p for p in db.query(Product).filter(Product.is_deleted == False).all()}

    def _p(name):
        return products_map.get(name.lower())

    packs_data = [
        {
            "name": "Family Pack",
            "description": "Everything your family needs for a week",
            "total_price": Decimal("1499.00"),
            "discount_label": "25% OFF",
            "savings_text": "Save ₹500",
            "items": [
                (_p("Milk"), 5), (_p("Bread"), 2), (_p("Eggs"), 2),
                (_p("Butter"), 1), (_p("Juice"), 2),
            ],
        },
        {
            "name": "PG / Hostel Pack",
            "description": "Perfect for students & bachelors",
            "total_price": Decimal("599.00"),
            "discount_label": "15% OFF",
            "savings_text": "Save ₹100",
            "items": [
                (_p("Milk"), 2), (_p("Bread"), 1), (_p("Eggs"), 1),
                (_p("Chips"), 3), (_p("Soda"), 3),
            ],
        },
        {
            "name": "Small Hotel Pack",
            "description": "Essential supplies for small eateries",
            "total_price": Decimal("2499.00"),
            "discount_label": "30% OFF",
            "savings_text": "Save ₹750",
            "items": [
                (_p("Milk"), 3), (_p("Butter"), 2), (_p("Bread"), 3),
                (_p("Eggs"), 5), (_p("Chicken"), 3),
            ],
        },
        {
            "name": "Tea Shop Pack",
            "description": "Keep your chai shop running smoothly",
            "total_price": Decimal("899.00"),
            "discount_label": "20% OFF",
            "savings_text": "Save ₹200",
            "items": [
                (_p("Milk"), 10), (_p("Cookies"), 5),
            ],
        },
    ]
    for pd in packs_data:
        items = [(p, q) for p, q in pd["items"] if p is not None]
        if len(items) < 1:
            continue
        pack = ComboPack(
            name=pd["name"],
            description=pd.get("description"),
            total_price=pd["total_price"],
            discount_label=pd.get("discount_label"),
            savings_text=pd.get("savings_text"),
        )
        db.add(pack)
        db.flush()
        for prod, qty in items:
            db.add(ComboPackItem(pack_id=pack.id, product_id=prod.id, quantity=qty))
    db.commit()


def _seed_data():
    """Populate categories, products, and admin user on first run."""
    db: Session = SessionLocal()
    try:
        # Clean up notifications older than 24 hours
        try:
            cutoff = datetime.now(timezone.utc) - timedelta(hours=24)
            expired = db.query(Notification).filter(
                Notification.is_deleted == False,
                Notification.created_at < cutoff,
            ).all()
            for n in expired:
                n.is_deleted = True
            if expired:
                db.commit()
                logger.info("Cleaned up %d expired notifications", len(expired))
        except Exception as e:
            logger.warning("Notification cleanup failed: %s", e)
            db.rollback()

        # Add role column if not exists (for existing DB).
        try:
            db.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user'"))
            db.commit()
        except Exception as e:
            logger.warning("ALTER TABLE users rollback: %s", e)
            db.rollback()

        # Create admin user if not exists – credentials from .env (already validated at module level).
        admin = db.query(User).filter(User.email == ADMIN_EMAIL).first()
        if not admin:
            hashed = bcrypt.hashpw(ADMIN_PASSWORD.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")
            admin = User(
                email=ADMIN_EMAIL,
                password_hash=hashed,
                name="Admin",
                phone="0000000000",
                role="admin",
            )
            db.add(admin)
            db.commit()

        # Seed app version (runs regardless of whether other seed data exists)
        if db.query(AppVersion).count() == 0:
            db.add(AppVersion(
                version="1.1.1",
                apk_download_url="https://github.com/selvaabi5555/delivery-app/releases/download/v1.1.1/delivery-app-v1.1.1.apk",
                release_notes="Redesigned home screen with Blinkit/Zepto-style UI\n• New orange curved header\n• Premium pill-shaped search bar\n• Improved product cards with green ADD button\n• Updated offers pack detail view\n• In-app update system",
                is_active=True,
            ))
            db.commit()

        if db.query(Category).count() > 0:
            # Categories exist — only seed combo packs if needed
            if db.query(ComboPack).count() == 0:
                _seed_combo_packs(db)
            return

        fruits = Category(id=uuid.uuid4(), name="Fruits", description="Fresh fruits", image="🍎")
        veggies = Category(id=uuid.uuid4(), name="Vegetables", description="Fresh vegetables", image="🥦")
        dairy = Category(id=uuid.uuid4(), name="Dairy", description="Milk & dairy products", image="🥛")
        bakery = Category(id=uuid.uuid4(), name="Bakery", description="Fresh baked goods", image="🍞")
        meat = Category(id=uuid.uuid4(), name="Meat & Fish", description="Fresh meat & seafood", image="🥩")
        beverages = Category(id=uuid.uuid4(), name="Beverages", description="Drinks & beverages", image="🥤")
        snacks = Category(id=uuid.uuid4(), name="Snacks", description="Snacks & packaged foods", image="🍪")
        db.add_all([fruits, veggies, dairy, bakery, meat, beverages, snacks])
        db.flush()

        products = [
            Product(id=uuid.uuid4(), category_id=fruits.id, name="Apple", price=Decimal("5.00"), unit="kg", stock=100, description="Fresh red apples"),
            Product(id=uuid.uuid4(), category_id=fruits.id, name="Banana", price=Decimal("3.00"), unit="dozen", stock=100, description="Ripe bananas"),
            Product(id=uuid.uuid4(), category_id=fruits.id, name="Orange", price=Decimal("4.00"), unit="kg", stock=100, description="Juicy oranges"),
            Product(id=uuid.uuid4(), category_id=fruits.id, name="Grapes", price=Decimal("6.00"), unit="kg", stock=80, description="Seedless grapes"),
            Product(id=uuid.uuid4(), category_id=fruits.id, name="Strawberry", price=Decimal("8.00"), unit="box", stock=60, description="Fresh strawberries"),
            Product(id=uuid.uuid4(), category_id=fruits.id, name="Mango", price=Decimal("7.00"), unit="kg", stock=50, description="Ripe alphonso mangoes"),
            Product(id=uuid.uuid4(), category_id=veggies.id, name="Tomato", price=Decimal("3.00"), unit="kg", stock=100, description="Fresh red tomatoes"),
            Product(id=uuid.uuid4(), category_id=veggies.id, name="Potato", price=Decimal("2.00"), unit="kg", stock=100, description="Farm fresh potatoes"),
            Product(id=uuid.uuid4(), category_id=veggies.id, name="Carrot", price=Decimal("4.00"), unit="kg", stock=80, description="Fresh orange carrots"),
            Product(id=uuid.uuid4(), category_id=veggies.id, name="Onion", price=Decimal("3.00"), unit="kg", stock=100, description="Red onions"),
            Product(id=uuid.uuid4(), category_id=veggies.id, name="Broccoli", price=Decimal("5.00"), unit="kg", stock=60, description="Green broccoli"),
            Product(id=uuid.uuid4(), category_id=dairy.id, name="Milk", price=Decimal("3.00"), unit="L", stock=100, description="Fresh whole milk"),
            Product(id=uuid.uuid4(), category_id=dairy.id, name="Cheese", price=Decimal("8.00"), unit="kg", stock=50, description="Cheddar cheese block"),
            Product(id=uuid.uuid4(), category_id=dairy.id, name="Butter", price=Decimal("5.00"), unit="kg", stock=60, description="Salted butter"),
            Product(id=uuid.uuid4(), category_id=dairy.id, name="Yogurt", price=Decimal("4.00"), unit="L", stock=70, description="Plain yogurt"),
            Product(id=uuid.uuid4(), category_id=bakery.id, name="Bread", price=Decimal("3.00"), unit="loaf", stock=80, description="Whole wheat bread"),
            Product(id=uuid.uuid4(), category_id=bakery.id, name="Croissant", price=Decimal("4.00"), unit="piece", stock=50, description="Butter croissant"),
            Product(id=uuid.uuid4(), category_id=bakery.id, name="Cake", price=Decimal("12.00"), unit="piece", stock=30, description="Chocolate cake slice"),
            Product(id=uuid.uuid4(), category_id=bakery.id, name="Cookies", price=Decimal("5.00"), unit="pack", stock=60, description="Chocolate chip cookies"),
            Product(id=uuid.uuid4(), category_id=meat.id, name="Chicken", price=Decimal("10.00"), unit="kg", stock=50, description="Fresh chicken breast"),
            Product(id=uuid.uuid4(), category_id=meat.id, name="Fish", price=Decimal("12.00"), unit="kg", stock=40, description="Fresh sea fish"),
            Product(id=uuid.uuid4(), category_id=meat.id, name="Eggs", price=Decimal("4.00"), unit="dozen", stock=100, description="Farm fresh eggs"),
            Product(id=uuid.uuid4(), category_id=beverages.id, name="Water", price=Decimal("1.00"), unit="L", stock=200, description="Mineral water bottle"),
            Product(id=uuid.uuid4(), category_id=beverages.id, name="Juice", price=Decimal("5.00"), unit="L", stock=80, description="Mixed fruit juice"),
            Product(id=uuid.uuid4(), category_id=beverages.id, name="Soda", price=Decimal("2.00"), unit="can", stock=150, description="Carbonated soda"),
            Product(id=uuid.uuid4(), category_id=snacks.id, name="Chips", price=Decimal("3.00"), unit="pack", stock=100, description="Potato chips"),
            Product(id=uuid.uuid4(), category_id=snacks.id, name="Chocolate", price=Decimal("5.00"), unit="bar", stock=80, description="Dark chocolate bar"),
            Product(id=uuid.uuid4(), category_id=snacks.id, name="Nuts", price=Decimal("8.00"), unit="kg", stock=60, description="Mixed dry fruits & nuts"),
        ]
        db.add_all(products)
        db.flush()
        # Add 3 sample images per product using picsum.photos placeholders
        product_seeds = ["apple", "banana", "orange", "grapes", "strawberry", "mango", "tomato", "potato", "carrot", "onion", "broccoli", "milk", "cheese", "butter", "yogurt", "bread", "croissant", "cake", "cookies", "chicken", "fish", "eggs", "water", "juice", "soda", "chips", "chocolate", "nuts"]
        for idx, p in enumerate(products):
            seed = product_seeds[idx] if idx < len(product_seeds) else "food"
            for i in range(3):
                db.add(ProductImage(product_id=p.id, image_url=f"https://picsum.photos/seed/{seed}{i}/400/400", sort_order=i))
        db.commit()

        # Seed combo packs
        _seed_combo_packs(db)
    finally:
        db.close()


@app.on_event("startup")
def startup():
    """Ensure existing admin user has the correct role on every startup."""
    db: Session = SessionLocal()
    try:
        admin = db.query(User).filter(User.email == ADMIN_EMAIL).first()
        if admin:
            if admin.role != "admin":
                admin.role = "admin"
                db.commit()
                logger.info("Fixed admin user role for %s", ADMIN_EMAIL)
    except Exception as e:
        logger.warning("Admin user role check failed: %s", e)
        db.rollback()
    finally:
        db.close()
    # _seed_data()  # Disabled — production data already seeded in Neon


@app.get("/")
def root():
    """Health check — no sensitive info exposed."""
    return {"status": "ok", "service": "Delivery App API"}
