"""
seed_india_products.py
Purpose: Add Indian grocery categories and products to the existing seed data.
Does NOT modify existing categories or products.
"""
import os
import sys
import uuid
from decimal import Decimal
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(__file__))

from sqlalchemy import create_engine
from sqlalchemy.orm import Session
from database import Base
from models import Category, Product, ProductImage, ProductFlag


DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    print("ERROR: DATABASE_URL environment variable is required")
    sys.exit(1)


ENGINE = create_engine(DATABASE_URL)


CATEGORIES = [
    {"name": "Dairy Products", "description": "Milk, curd, butter & more", "image": "🥛"},
    {"name": "Bathroom Products", "description": "Soaps, shampoo & toiletries", "image": "🧴"},
    {"name": "Flowers", "description": "Fresh flower garlands & bouquets", "image": "🌺"},
    {"name": "Personal Care", "description": "Hair oil, deodorants & hygiene", "image": "🧑‍🦰"},
    {"name": "Home Care", "description": "Detergents, cleaners & more", "image": "🧹"},
    {"name": "Snacks & Biscuits", "description": "Biscuits, chips & traditional snacks", "image": "🍪"},
    {"name": "Fruits & Vegetables", "description": "Fresh fruits & vegetables", "image": "🥦"},
]

PRODUCTS_BY_CATEGORY = {
    "Dairy Products": [
        {"name": "Aavin Milk 500ml", "price": 35, "unit": "500ml", "stock": 100, "desc": "Fresh Aavin toned milk"},
        {"name": "Aavin Curd 500g", "price": 45, "unit": "500g", "stock": 80, "desc": "Fresh Aavin curd"},
        {"name": "Amul Butter 100g", "price": 60, "unit": "100g", "stock": 80, "desc": "Creamy Amul butter"},
        {"name": "Amul Paneer 200g", "price": 100, "unit": "200g", "stock": 60, "desc": "Fresh Amul paneer"},
        {"name": "Aavin Ghee 200ml", "price": 160, "unit": "200ml", "stock": 50, "desc": "Pure Aavin ghee"},
    ],
    "Bathroom Products": [
        {"name": "Lux Soap 100g", "price": 40, "unit": "100g", "stock": 100, "desc": "Lux beauty soap"},
        {"name": "Dove Soap 100g", "price": 60, "unit": "100g", "stock": 100, "desc": "Dove moisturizing soap"},
        {"name": "Clinic Plus Shampoo 180ml", "price": 120, "unit": "180ml", "stock": 80, "desc": "Clinic Plus strong hair shampoo"},
        {"name": "Colgate Toothpaste 200g", "price": 110, "unit": "200g", "stock": 80, "desc": "Colgate strong teeth toothpaste"},
        {"name": "Oral-B Toothbrush", "price": 40, "unit": "piece", "stock": 100, "desc": "Oral-B manual toothbrush"},
    ],
    "Flowers": [
        {"name": "Malligai Poo 100g", "price": 80, "unit": "100g", "stock": 50, "desc": "Fresh jasmine flowers"},
        {"name": "Rose Flowers 1kg", "price": 150, "unit": "1kg", "stock": 30, "desc": "Fresh rose flowers"},
        {"name": "Kanakambaram 100g", "price": 60, "unit": "100g", "stock": 40, "desc": "Fresh firecracker flowers"},
        {"name": "Saamanthi 100g", "price": 50, "unit": "100g", "stock": 40, "desc": "Fresh marigold flowers"},
        {"name": "Flower Garland", "price": 120, "unit": "piece", "stock": 30, "desc": "Traditional flower garland"},
    ],
    "Personal Care": [
        {"name": "Hair Oil 200ml", "price": 120, "unit": "200ml", "stock": 80, "desc": "Coconut hair oil"},
        {"name": "Talcum Powder 100g", "price": 90, "unit": "100g", "stock": 80, "desc": "Refreshing talcum powder"},
        {"name": "Deodorant 150ml", "price": 220, "unit": "150ml", "stock": 60, "desc": "Long-lasting deodorant spray"},
        {"name": "Sanitary Napkin Pack", "price": 120, "unit": "pack", "stock": 100, "desc": "Soft sanitary napkins"},
    ],
    "Home Care": [
        {"name": "Surf Excel 1kg", "price": 240, "unit": "1kg", "stock": 60, "desc": "Surf Excel detergent powder"},
        {"name": "Rin Bar", "price": 25, "unit": "piece", "stock": 100, "desc": "Rin whitening laundry bar"},
        {"name": "Vim Dishwash Liquid 500ml", "price": 110, "unit": "500ml", "stock": 80, "desc": "Vim lemon dishwash liquid"},
        {"name": "Harpic Toilet Cleaner 500ml", "price": 120, "unit": "500ml", "stock": 60, "desc": "Harpic toilet cleaner"},
        {"name": "Lizol Floor Cleaner 500ml", "price": 130, "unit": "500ml", "stock": 60, "desc": "Lizol disinfectant floor cleaner"},
    ],
    "Snacks & Biscuits": [
        {"name": "Good Day Biscuits", "price": 20, "unit": "pack", "stock": 100, "desc": "Britannia Good Day biscuits"},
        {"name": "Marie Gold", "price": 10, "unit": "pack", "stock": 100, "desc": "Sunfeast Marie Gold biscuits"},
        {"name": "Lays Chips", "price": 20, "unit": "pack", "stock": 100, "desc": "Lays potato chips"},
        {"name": "Murukku", "price": 50, "unit": "pack", "stock": 60, "desc": "Traditional crispy murukku"},
        {"name": "Mixture", "price": 60, "unit": "pack", "stock": 60, "desc": "Spicy snack mixture"},
    ],
    "Fruits & Vegetables": [
        {"name": "Apple 1kg", "price": 180, "unit": "1kg", "stock": 50, "desc": "Fresh red apples"},
        {"name": "Banana 1 dozen", "price": 70, "unit": "dozen", "stock": 80, "desc": "Fresh ripe bananas"},
        {"name": "Orange 1kg", "price": 120, "unit": "1kg", "stock": 50, "desc": "Juicy oranges"},
        {"name": "Tomato 1kg", "price": 40, "unit": "1kg", "stock": 80, "desc": "Fresh red tomatoes"},
        {"name": "Onion 1kg", "price": 35, "unit": "1kg", "stock": 80, "desc": "Fresh red onions"},
        {"name": "Potato 1kg", "price": 45, "unit": "1kg", "stock": 80, "desc": "Farm fresh potatoes"},
    ],
}

BEVERAGES_PRODUCTS = [
    {"name": "Tea Powder 250g", "price": 140, "unit": "250g", "stock": 80, "desc": "CTC tea powder"},
    {"name": "Coffee Powder 200g", "price": 180, "unit": "200g", "stock": 60, "desc": "Filter coffee powder"},
    {"name": "Boost 500g", "price": 320, "unit": "500g", "stock": 50, "desc": "Boost health drink"},
    {"name": "Horlicks 500g", "price": 280, "unit": "500g", "stock": 50, "desc": "Horlicks nutritive drink"},
    {"name": "Coca Cola 750ml", "price": 40, "unit": "750ml", "stock": 100, "desc": "Coca Cola soft drink"},
]


def seed():
    db = Session(ENGINE)
    try:
        cats_created = 0
        prods_created = 0
        imgs_created = 0

        existing_cat_names = {
            c.name for c in db.query(Category).filter(Category.is_deleted == False).all()
        }

        for cat_def in CATEGORIES:
            if cat_def["name"] in existing_cat_names:
                print(f"  SKIP category '{cat_def['name']}' — already exists")
                continue
            cat = Category(
                id=uuid.uuid4(),
                name=cat_def["name"],
                description=cat_def["description"],
                image=cat_def["image"],
            )
            db.add(cat)
            db.flush()
            cats_created += 1
            print(f"  ADDED category '{cat_def['name']}'")

            products_def = PRODUCTS_BY_CATEGORY.get(cat_def["name"], [])
            for i, pdef in enumerate(products_def):
                prod = Product(
                    id=uuid.uuid4(),
                    category_id=cat.id,
                    name=pdef["name"],
                    description=pdef["desc"],
                    price=Decimal(str(pdef["price"])),
                    unit=pdef["unit"],
                    stock=pdef["stock"],
                )
                db.add(prod)
                db.flush()
                prods_created += 1

                flag = ProductFlag(product_id=prod.id, is_enabled=True)
                db.add(flag)

                seed_slug = pdef["name"].lower().replace(" ", "").replace(".", "")
                db.add(ProductImage(
                    product_id=prod.id,
                    image_url=f"https://picsum.photos/seed/{seed_slug}/300/300",
                    sort_order=0,
                ))
                imgs_created += 1

        # Handle Beverages separately — reuse existing "Beverages" category
        beverages_cat = db.query(Category).filter(
            Category.name == "Beverages",
            Category.is_deleted == False,
        ).first()
        if beverages_cat:
            existing_beverage_names = {
                p.name for p in db.query(Product).filter(
                    Product.category_id == beverages_cat.id,
                    Product.is_deleted == False,
                ).all()
            }
            for pdef in BEVERAGES_PRODUCTS:
                if pdef["name"] in existing_beverage_names:
                    print(f"  SKIP product '{pdef['name']}' — already exists under Beverages")
                    continue
                prod = Product(
                    id=uuid.uuid4(),
                    category_id=beverages_cat.id,
                    name=pdef["name"],
                    description=pdef["desc"],
                    price=Decimal(str(pdef["price"])),
                    unit=pdef["unit"],
                    stock=pdef["stock"],
                )
                db.add(prod)
                db.flush()
                prods_created += 1
                flag = ProductFlag(product_id=prod.id, is_enabled=True)
                db.add(flag)
                seed_slug = pdef["name"].lower().replace(" ", "").replace(".", "")
                db.add(ProductImage(
                    product_id=prod.id,
                    image_url=f"https://picsum.photos/seed/{seed_slug}/300/300",
                    sort_order=0,
                ))
                imgs_created += 1
        else:
            print("  SKIP Beverages — category 'Beverages' not found (should not happen)")

        db.commit()
        print(f"\nDone! Added {cats_created} categories, {prods_created} products, {imgs_created} images.")

    except Exception as e:
        db.rollback()
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        db.close()


if __name__ == "__main__":
    seed()
