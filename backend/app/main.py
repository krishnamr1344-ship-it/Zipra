import os
import uuid
from decimal import Decimal
from datetime import datetime, timezone

from dotenv import load_dotenv
load_dotenv()

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.orm import Session
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse

from app.db import engine, SessionLocal, Base
from app.core.config import FRONTEND_URL, ADMIN_EMAIL, ADMIN_PASSWORD
from app.core.security import hash_password
from app.middleware.rate_limit import RateLimitMiddleware

# Auth
from app.api.auth import router as auth_router

# Customer routes
from app.api.customer.categories import router as categories_router
from app.api.customer.products import router as products_router
from app.api.customer.addresses import router as addresses_router
from app.api.customer.cart import router as cart_router
from app.api.customer.orders import router as orders_router
from app.api.customer.payments import router as payments_router
from app.api.customer.offers import router as offers_router
from app.api.customer.delivery import router as delivery_router

# Admin routes
from app.api.admin.products import router as admin_products_router
from app.api.admin.categories import router as admin_categories_router
from app.api.admin.orders import router as admin_orders_router
from app.api.admin.users import router as admin_users_router
from app.api.admin.delivery import router as admin_delivery_router
from app.api.admin.offers import router as admin_offers_router
from app.api.admin.shops import router as admin_shops_router

# Shop routes
from app.api.shop.shop_auth import router as shop_router
from app.api.shop.products import router as shop_products_router
from app.api.shop.orders import router as shop_orders_router
from app.api.shop.earnings import router as shop_earnings_router

from app.models import Category, Product, ProductImage, User, ComboPack, ComboPackItem, Offer

# Create all tables
Base.metadata.create_all(bind=engine)

# Auto-migrate
with engine.connect() as conn:
    conn.execute(text("ALTER TABLE products ADD COLUMN IF NOT EXISTS original_price NUMERIC(10,2) NULL"))
    conn.commit()

app = FastAPI(
    title="Delivery App API",
    description="Secure backend for delivery application",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

class BodySizeLimitMiddleware(BaseHTTPMiddleware):
    MAX_BODY = 10 * 1024 * 1024  # 10MB

    async def dispatch(self, request: Request, call_next):
        content_length = request.headers.get('content-length')
        if content_length and content_length.isdigit() and int(content_length) > self.MAX_BODY:
            return JSONResponse({"detail": "Request body too large"}, status_code=413)
        return await call_next(request)


app.add_middleware(BodySizeLimitMiddleware)

# CORS
origins = [
    "http://localhost:5000",
    "http://localhost:5001",
    "http://localhost:5002",
    "https://zipra-api-583825347591.asia-south1.run.app",
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Rate Limiting + JWT Middleware
app.add_middleware(RateLimitMiddleware)

# Routers
app.include_router(auth_router)
app.include_router(categories_router)
app.include_router(products_router)
app.include_router(addresses_router)
app.include_router(cart_router)
app.include_router(orders_router)
app.include_router(payments_router)
app.include_router(offers_router)
app.include_router(delivery_router)
app.include_router(admin_products_router)
app.include_router(admin_categories_router)
app.include_router(admin_orders_router)
app.include_router(admin_users_router)
app.include_router(admin_delivery_router)
app.include_router(admin_offers_router)
app.include_router(admin_shops_router)
app.include_router(shop_router)
app.include_router(shop_products_router)
app.include_router(shop_orders_router)
app.include_router(shop_earnings_router)

# Static files
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


def _seed_combo_packs(db: Session):
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
            "items": [(_p("Milk"), 5), (_p("Bread"), 2), (_p("Eggs"), 2), (_p("Butter"), 1), (_p("Juice"), 2)],
        },
        {
            "name": "PG / Hostel Pack",
            "description": "Perfect for students & bachelors",
            "total_price": Decimal("599.00"),
            "discount_label": "15% OFF",
            "savings_text": "Save ₹100",
            "items": [(_p("Milk"), 2), (_p("Bread"), 1), (_p("Eggs"), 1), (_p("Chips"), 3), (_p("Soda"), 3)],
        },
        {
            "name": "Small Hotel Pack",
            "description": "Essential supplies for small eateries",
            "total_price": Decimal("2499.00"),
            "discount_label": "30% OFF",
            "savings_text": "Save ₹750",
            "items": [(_p("Milk"), 3), (_p("Butter"), 2), (_p("Bread"), 3), (_p("Eggs"), 5), (_p("Chicken"), 3)],
        },
        {
            "name": "Tea Shop Pack",
            "description": "Keep your chai shop running smoothly",
            "total_price": Decimal("899.00"),
            "discount_label": "20% OFF",
            "savings_text": "Save ₹200",
            "items": [(_p("Milk"), 10), (_p("Cookies"), 5)],
        },
    ]
    for pd in packs_data:
        items = [(p, q) for p, q in pd["items"] if p is not None]
        if len(items) < 1:
            continue
        pack = ComboPack(
            name=pd["name"], description=pd.get("description"),
            total_price=pd["total_price"], discount_label=pd.get("discount_label"),
            savings_text=pd.get("savings_text"),
        )
        db.add(pack)
        db.flush()
        for prod, qty in items:
            db.add(ComboPackItem(pack_id=pack.id, product_id=prod.id, quantity=qty))
    db.commit()


def _seed_data():
    db: Session = SessionLocal()
    try:
        try:
            db.execute(text("ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(20) NOT NULL DEFAULT 'user'"))
            db.commit()
        except Exception:
            db.rollback()

        if not ADMIN_EMAIL or not ADMIN_PASSWORD:
            print("WARNING: ADMIN_EMAIL and ADMIN_PASSWORD must be set in .env")
            return
        admin = db.query(User).filter(User.email == ADMIN_EMAIL).first()
        if not admin:
            hashed = hash_password(ADMIN_PASSWORD)
            admin = User(email=ADMIN_EMAIL, password_hash=hashed, name="Admin", phone="0000000000", role="admin")
            db.add(admin)
            db.commit()

        if db.query(Category).count() > 0:
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
        product_seeds = ["apple", "banana", "orange", "grapes", "strawberry", "mango", "tomato", "potato", "carrot", "onion", "broccoli", "milk", "cheese", "butter", "yogurt", "bread", "croissant", "cake", "cookies", "chicken", "fish", "eggs", "water", "juice", "soda", "chips", "chocolate", "nuts"]
        for idx, p in enumerate(products):
            seed = product_seeds[idx] if idx < len(product_seeds) else "food"
            for i in range(3):
                db.add(ProductImage(product_id=p.id, image_url=f"https://picsum.photos/seed/{seed}{i}/400/400", sort_order=i))
        db.commit()
        _seed_combo_packs(db)
    finally:
        db.close()


@app.on_event("startup")
def startup():
    _seed_data()


@app.get("/")
def root():
    return {"status": "ok", "service": "Delivery App API"}
