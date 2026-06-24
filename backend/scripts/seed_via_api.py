"""
seed_via_api.py
Adds Indian grocery categories and products via the admin API.
"""
import os, sys, json, urllib.request, time

BASE = os.environ.get("SEED_API_BASE", "http://localhost:8000")
EMAIL = os.environ.get("SEED_ADMIN_EMAIL")
PASSWORD = os.environ.get("SEED_ADMIN_PASSWORD")

if not EMAIL or not PASSWORD:
    print("FATAL: Set SEED_ADMIN_EMAIL and SEED_ADMIN_PASSWORD env vars", file=sys.stderr)
    sys.exit(1)


def api(method, path, data=None, token=None):
    url = f"{BASE}{path}"
    body = json.dumps(data).encode() if data else None
    h = {"Content-Type": "application/json", "Origin": BASE}
    if token:
        h["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=body, headers=h, method=method)
    try:
        resp = urllib.request.urlopen(req, timeout=20)
        return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        err = e.read().decode()
        print(f"  ERROR {e.code} on {method} {path}: {err[:200]}")
        return None


print("Logging in...")
r = api("POST", "/api/auth/login", {"email": EMAIL, "password": PASSWORD})
if not r or "token" not in r:
    print("Login failed", file=sys.stderr)
    sys.exit(1)
tok = r["token"]
print("OK\n")


CATEGORIES = [
    {"name": "Dairy Products", "description": "Milk, curd, butter & more", "image": "🥛"},
    {"name": "Bathroom Products", "description": "Soaps, shampoo & toiletries", "image": "🧴"},
    {"name": "Flowers", "description": "Fresh flower garlands & bouquets", "image": "🌺"},
    {"name": "Personal Care", "description": "Hair oil, deodorants & hygiene", "image": "🧑"},
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


total_cats = 0
total_prods = 0


print("=== Creating Categories ===")
for cat_def in CATEGORIES:
    r = api("POST", "/api/admin/categories", {
        "name": cat_def["name"],
        "description": cat_def["description"],
        "image": cat_def["image"],
    }, token=tok)
    if r and "id" in r:
        total_cats += 1
        print(f"  ✓ {cat_def['name']}")
    elif r and "message" in r:
        print(f"  ! {cat_def['name']} — {r['message']}")
    else:
        print(f"  ✗ {cat_def['name']} — failed")
    time.sleep(0.3)

print(f"\nCategories added: {total_cats}")


print("\n=== Creating Products ===")

# First, get the actual category IDs
r = api("GET", "/api/categories", token=tok)
cat_map = {}
if r:
    for c in r:
        cat_map[c["name"]] = c["id"]

for cat_name, products in PRODUCTS_BY_CATEGORY.items():
    cat_id = cat_map.get(cat_name)
    if not cat_id:
        print(f"  ✗ Category '{cat_name}' not found, skipping {len(products)} products")
        continue
    for pdef in products:
        r = api("POST", "/api/admin/products", {
            "name": pdef["name"],
            "category_id": cat_id,
            "price": pdef["price"],
            "unit": pdef["unit"],
            "stock": pdef["stock"],
            "description": pdef["desc"],
            "images": [f"https://picsum.photos/seed/{pdef['name'].lower().replace(' ','').replace('.','')}/300/300"],
        }, token=tok)
        if r and "id" in r:
            total_prods += 1
            print(f"  ✓ {pdef['name']} — ₹{pdef['price']}")
        elif r and "message" in r:
            print(f"  ! {pdef['name']} — {r['message']}")
        else:
            print(f"  ✗ {pdef['name']} — failed")
        time.sleep(0.2)

# Add beverages under the existing "Beverages" category
print("\n=== Creating Beverages Products ===")
beverages_cat_id = None
for c in r if False else []:
    pass
r = api("GET", "/api/categories", token=tok)
if r:
    for c in r:
        if c["name"] == "Beverages":
            beverages_cat_id = c["id"]
            break

if beverages_cat_id:
    for pdef in BEVERAGES_PRODUCTS:
        r = api("POST", "/api/admin/products", {
            "name": pdef["name"],
            "category_id": beverages_cat_id,
            "price": pdef["price"],
            "unit": pdef["unit"],
            "stock": pdef["stock"],
            "description": pdef["desc"],
            "images": [f"https://picsum.photos/seed/{pdef['name'].lower().replace(' ','').replace('.','')}/300/300"],
        }, token=tok)
        if r and "id" in r:
            total_prods += 1
            print(f"  ✓ {pdef['name']} — ₹{pdef['price']}")
        else:
            print(f"  ✗ {pdef['name']} — failed")
        time.sleep(0.2)
else:
    print("  ! Category 'Beverages' not found. Will add Beverages category first.")
    r = api("POST", "/api/admin/categories", {
        "name": "Beverages",
        "description": "Tea, coffee, health drinks & soft drinks",
        "image": "🥤",
    }, token=tok)
    if r and "id" in r:
        bevercat_id = r["id"]
        for pdef in BEVERAGES_PRODUCTS:
            r = api("POST", "/api/admin/products", {
                "name": pdef["name"],
                "category_id": bevercat_id,
                "price": pdef["price"],
                "unit": pdef["unit"],
                "stock": pdef["stock"],
                "description": pdef["desc"],
                "images": [f"https://picsum.photos/seed/{pdef['name'].lower().replace(' ','').replace('.','')}/300/300"],
            }, token=tok)
            if r and "id" in r:
                total_prods += 1
                print(f"  ✓ {pdef['name']} — ₹{pdef['price']}")
            else:
                print(f"  ✗ {pdef['name']} — failed")
            time.sleep(0.2)


print(f"\n{'='*50}")
print(f"Total categories added: {total_cats}")
print(f"Total products added:  {total_prods}")
print(f"{'='*50}")
