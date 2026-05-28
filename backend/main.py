"""
main.py
Purpose: FastAPI application entry point.
Security:
  - CORS: only allows FRONTEND_URL from .env, never wildcard.
  - Rate-limit + JWT middleware applied globally.
  - Generic error responses only.

Database:
  - Local PostgreSQL via SQLAlchemy (models.py, database.py)
  - Supabase via supabase-py (supabase_db.py) — service_role key
  - Both run in parallel during migration
"""
import os
import uuid
from decimal import Decimal
from datetime import datetime, timezone

import bcrypt
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.orm import Session

from database import engine, SessionLocal, Base
from auth import router as auth_router
from middleware import RateLimitMiddleware
from resources import router as resources_router
from admin import router as admin_router
from models import Category, Product, ProductImage, User, ComboPack, ComboPackItem
import supabase_db

FRONTEND_URL = os.getenv("FRONTEND_URL", "http://localhost:3000")

# Create all tables on startup.
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Delivery App API",
    description="Secure backend for delivery application",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ─── CORS ───────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=[FRONTEND_URL],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["Authorization", "Content-Type"],
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
        # Add role column if not exists (for existing DB).
        try:
            db.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user'"))
            db.commit()
        except Exception:
            db.rollback()

        # Create admin user if not exists – credentials from .env.
        admin_email = os.getenv("ADMIN_EMAIL", "admin@yourdomain.com")
        admin_password = os.getenv("ADMIN_PASSWORD", "YourStrongAdminPass#2024")
        admin = db.query(User).filter(User.email == admin_email).first()
        if not admin:
            hashed = bcrypt.hashpw(admin_password.encode("utf-8"), bcrypt.gensalt(rounds=12)).decode("utf-8")
            admin = User(
                email=admin_email,
                password_hash=hashed,
                name="Admin",
                phone="0000000000",
                role="admin",
            )
            db.add(admin)
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
    _seed_data()


@app.get("/")
def root():
    """Health check — no sensitive info exposed."""
    return {"status": "ok", "service": "Delivery App API"}
