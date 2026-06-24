# ZIPRA ARCHITECTURE REPORT

**Generated:** 24 Jun 2026  
**Project:** zipra — Grocery Delivery App (Flutter + FastAPI)  
**Version:** 1.1.2+5  
**Repo:** github.com/selvaabi5555/delivery-app

---

## 1. Project Overview

Zipra is a grocery delivery mobile application with a Flutter frontend and Python/FastAPI backend. Users browse products by category, add items to cart, place orders with Cash-on-Delivery or Razorpay, and track delivery via OTP verification. Admins manage products, orders, categories, banners, delivery zones, notifications, and settings through an in-app admin panel.

| Layer | Technology | Version |
|-------|-----------|---------|
| Mobile Frontend | Flutter / Dart | ^3.11.5 |
| Backend API | FastAPI (Python) | ^0.115.0 |
| Database | PostgreSQL (Neon) | 16 |
| Auth | Firebase Auth + Google Sign-In + JWT | — |
| Payments | Razorpay | — |
| Image Storage | Supabase Storage | — |
| Deployment | Docker + Nginx + GCP VM | — |
| Error Tracking | Sentry | — |

**Total source files:** ~130 (60 Dart, 28 Python, 35 Android, 7 deploy/config)  
**Tests:** 1 Flutter widget test, 6 Python pytest files

---

## 2. Folder Structure

```
delivery-app/
├── AGENTS.md                          # Agent work rules
├── Dockerfile                         # Production Docker build
├── docker-compose.yml                 # Docker Compose (app + nginx)
├── pubspec.yaml                       # Flutter dependencies
├── analysis_options.yaml              # Dart linter rules
│
├── android/                           # Android platform
│   ├── app/
│   │   ├── build.gradle.kts           # Gradle config
│   │   ├── google-services.json       # Firebase config
│   │   └── src/main/kotlin/.../MainActivity.kt
│   ├── key.properties                 # Debug keystore only (no release)
│   ├── gradle/wrapper/
│   └── settings.gradle.kts
│
├── macos/                             # macOS desktop (Xcode project)
│   ├── Runner/
│   └── Flutter/
│
├── lib/                               # DART SOURCE CODE
│   ├── main.dart                      # App entry, routing, init
│   ├── constants/
│   │   ├── cloudinary.dart            # Cloudinary API config
│   │   └── theme.dart                 # Colors, typography, theme
│   ├── models/
│   │   ├── cart_model.dart            # Cart data model
│   │   ├── combo_pack.dart            # Combo pack model
│   │   └── grocery_product.dart       # Product model
│   ├── services/
│   │   ├── api_service.dart           # Main HTTP client (all endpoints)
│   │   ├── admin_api_service.dart     # Admin HTTP client
│   │   ├── app_info.dart              # App version info
│   │   ├── cloudinary_service.dart    # Cloudinary upload
│   │   ├── delivery_zone_service.dart # Delivery zone check
│   │   ├── location_service.dart      # GPS positioning
│   │   ├── notification_service.dart  # Push notifications
│   │   ├── permission_service.dart    # Runtime permissions
│   │   └── theme_service.dart         # Theme state
│   ├── pages/                         # 37 screen files
│   │   ├── login_page.dart
│   │   ├── home_page.dart             # ~100KB (largest file)
│   │   ├── cart_page.dart
│   │   ├── payment_page.dart
│   │   ├── payment_gateway_screen.dart
│   │   ├── order_detail_page.dart
│   │   ├── admin_home_page.dart
│   │   ├── admin_orders_page.dart
│   │   ├── admin_products_page.dart
│   │   ├── admin_categories_page.dart
│   │   ├── admin_banners_page.dart
│   │   ├── admin_delivery_zone_page.dart
│   │   ├── admin_users_page.dart
│   │   ├── admin_notifications_page.dart
│   │   ├── admin_combo_packs_page.dart
│   │   ├── admin_settings_page.dart
│   │   ├── admin_order_detail_page.dart # ~55KB
│   │   ├── addresses_page.dart
│   │   ├── address_form_page.dart
│   │   ├── delivery_location_page.dart
│   │   ├── map_picker_page.dart
│   │   ├── location_picker_sheet.dart
│   │   ├── product_detail_page.dart
│   │   ├── wishlist_page.dart
│   │   ├── orders_page.dart
│   │   ├── offers_page.dart
│   │   ├── pack_detail_sheet.dart
│   │   ├── check_updates_page.dart
│   │   ├── complete_profile_page.dart
│   │   ├── edit_profile_page.dart
│   │   ├── notifications_page.dart
│   │   ├── settings_page.dart
│   │   ├── help_support_page.dart
│   │   ├── suggest_products_page.dart
│   │   ├── payments_page.dart
│   │   └── terms_page.dart
│   ├── screens/                       # (empty - one file deleted)
│   └── widgets/                       # 11 reusable widgets
│       ├── product_card.dart
│       ├── product_grid.dart
│       ├── cart_item_card.dart
│       ├── quantity_selector.dart
│       ├── bottom_checkout_bar.dart
│       ├── order_summary.dart
│       ├── app_snackbar.dart
│       ├── state_widgets.dart
│       ├── empty_cart_widget.dart
│       ├── permission_bottom_sheet.dart
│       └── success_modal.dart
│
├── backend/                           # PYTHON BACKEND
│   ├── main.py                        # App entry, middleware, seed
│   ├── resources.py                   # User-facing API (2116 lines)
│   ├── admin.py                       # Admin API (806 lines)
│   ├── auth.py                        # Firebase + JWT auth
│   ├── models.py                      # SQLAlchemy ORM (21 tables)
│   ├── schemas.py                     # Pydantic validators
│   ├── config.py                      # Env vars, public paths
│   ├── database.py                    # DB engine, session
│   ├── middleware.py                  # Rate limiting + JWT
│   ├── requirements.txt
│   ├── alembic/
│   │   ├── alembic.ini
│   │   ├── env.py
│   │   └── versions/
│   │       ├── e00aea3f3315_initial_schema.py
│   │       ├── 8eb2038aa827_add_delivery_fee_and_settings.py
│   │       └── add_intent_id_to_payments.py
│   ├── legacy/migrations/             # Legacy raw SQL (7 files)
│   ├── scripts/                       # DB seed scripts (4 files)
│   ├── tests/                         # Pytest test suite (6 files)
│   └── uploads/                       # Upload directory placeholder
│
├── assets/
│   ├── icon/logo.png                  # App icon
│   └── login/IMG_*.png               # Login background
│
├── archive/                           # Old test DBs (6 files)
│
├── deploy/
│   ├── compose.yaml                   # Docker Compose config
│   └── nginx/                         # Reverse proxy config
│
├── nginx/
│   └── default.conf                   # Reverse proxy config
│
└── test/
    └── widget_test.dart               # Single smoke test
```

---

## 3. Frontend Architecture

### 3.1 State Management

**No state management library** (no Provider, Bloc, Riverpod, GetX). The app uses:
- **`setState()`** in StatefulWidgets for local UI state
- **Global singleton services** (`api_service.dart`, `cart_model.dart` etc.) for shared data
- **`shared_preferences`** / **`flutter_secure_storage`** for persistent state (tokens, preferences)

This works for the current scale but will become unwieldy as complexity grows. The cart model (`cart_model.dart`) acts as a simple in-memory singleton with no reactive state propagation — other widgets won't automatically rebuild when cart changes.

### 3.2 Navigation

**Custom manual navigation** using `Navigator.push()` and `Navigator.pushReplacement()`. No named routes, no `go_router`, no declarative routing. The splash screen logic in `main.dart` determines the initial route:

```
App Start → main()
  ├─ Token in secure storage? → Check /auth/me → HomePage
  └─ No token? → LoginPage
  
LoginPage → (success) → HomePage (pushReplacement)
HomePage → ProductDetail → CartPage → PaymentPage → OrderDetail
```

### 3.3 API Services

Two separate HTTP clients — both using the `http` package:

| Service | Base URL | Purpose |
|---------|----------|---------|
| `api_service.dart` | `API_BASE_URL` (env) | User-facing API calls |
| `admin_api_service.dart` | Same base URL | Admin API calls |

Both services are **global singletons** instantiated at the top of each file. They share the same token management (read from `flutter_secure_storage`, attach as `Bearer` header).

### 3.4 Auth Flow

```
Google Sign-In Button
  ↓
google_sign_in package → Google ID Token
  ↓
Firebase Auth → Firebase ID Token
  ↓
POST /api/auth/google-login { id_token }
  ↓
Backend verifies Firebase token (RS256, Google public keys)
  ↓
Backend creates/links user, generates JWT
  ↓
JWT stored in flutter_secure_storage (key: "jwt_token")
  ↓
All subsequent requests include: Authorization: Bearer <jwt>
```

### 3.5 Payment Integration

Razorpay Flutter SDK (`razorpay_flutter: ^1.4.5`) for in-app payment UI:

```
User taps "Pay with Razorpay"
  ↓
POST /api/payments/create-order → receives razorpay_order_id
  ↓
Open Razorpay checkout sheet with order_id + amount + key
  ↓
User completes UPI/Card/NetBanking
  ↓
Razorpay SDK calls onSuccess callback with payment_id + signature
  ↓
POST /api/payments/verify { intent_id, payment_id, signature }
  ↓
Backend verifies HMAC → creates Order → confirms payment
```

### 3.6 Image Loading

Images are loaded directly from Supabase Storage public URLs using standard `Image.network()`. No caching layer (no `cached_network_image` package). This means every image re-fetches from the network on every build, unless the OS-level HTTP cache intervenes.

### 3.7 Key Screen Breakdown

| Screen | File | Est. Lines | Role |
|--------|------|-----------|------|
| HomePage | `home_page.dart` | ~1200 | Product grid, banners, categories, search bar, offers |
| LoginPage | `login_page.dart` | ~200 | Google Sign-In button |
| CartPage | `cart_page.dart` | ~150 | Item list, quantity, total |
| PaymentPage | `payment_page.dart` | ~350 | Payment method selection + checkout |
| PaymentGatewayScreen | `payment_gateway_screen.dart` | ~400 | Razorpay WebView wrapper |
| AdminOrderDetailPage | `admin_order_detail_page.dart` | ~1000 | Order management, status updates, OTP delivery |

### 3.8 Admin Panel (Flutter Side)

All admin pages are regular Flutter pages accessible from the app — there's no separate admin app or web dashboard. Admin access is controlled server-side by the `role` field in the JWT. The admin sees an additional bottom nav item or a dedicated entry point on the home page.

Admin pages: `admin_home_page.dart`, `admin_products_page.dart`, `admin_categories_page.dart`, `admin_banners_page.dart`, `admin_orders_page.dart`, `admin_order_detail_page.dart`, `admin_users_page.dart`, `admin_combo_packs_page.dart`, `admin_delivery_zone_page.dart`, `admin_notifications_page.dart`, `admin_settings_page.dart`.

---

## 4. Backend Architecture

### 4.1 Application Structure

```
main.py ──→ FastAPI app
  ├── Middleware stack:
  │    1. Security headers
  │    2. API Key validation
  │    3. CSRF origin check
  │    4. CORS (single origin)
  │    5. Rate limiting + JWT validation
  ├── Startup events:
  │    ├── Base.metadata.create_all()  (auto-create tables)
  │    ├── Imperative ALTER TABLE migrations
  │    ├── Seed data (admin user, categories, products, packs, version)
  │    └── Admin role enforcement
  └── Routers:
       ├── /api/auth     (auth.py)
       ├── /api/          (resources.py)
       └── /api/admin    (admin.py)
```

### 4.2 All API Endpoints (Grouped)

#### Auth (`/api/auth`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/google-login` | Public | Firebase Google Sign-In → JWT |
| POST | `/logout` | User | Blacklist JWT |
| POST | `/logout-all` | User | Invalidate all sessions |
| GET | `/me` | User | Current profile |
| PUT | `/profile` | User | Update name/phone |
| PUT | `/profile/phone` | User | Update phone only |

#### Products & Categories (`/api`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/categories` | Public | Active categories |
| GET | `/products` | Public | Products (optional `?category_id=`) |
| GET | `/combo-packs` | Public | Enabled packs with stock check |

#### Addresses (`/api/addresses`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `` | User | List (default first) |
| POST | `` | User | Create (sets default) |
| PUT | `/{id}` | User | Update |
| PUT | `/{id}/default` | User | Set as default |
| DELETE | `/{id}` | User | Soft-delete |
| POST | `/auto` | User | GPS auto-address (Nominatim reverse geocode) |

#### Cart (`/api/cart`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `` | User | List with subtotals |
| POST | `` | User | Add item (stock check, increment) |
| PUT | `/{item_id}` | User | Update qty (0 = remove) |
| DELETE | `/{item_id}` | User | Remove item |
| DELETE | `` | User | Clear all |

#### Orders (`/api/orders`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `` | User | List (newest first) |
| GET | `/{id}` | User | Detail with address + map link |
| POST | `` | User | Create from cart |

#### Payments (`/api/payments`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/process` | User | Cash on Delivery |
| POST | `/create-order` | User | Razorpay order (new + retry) |
| POST | `/verify` | User | Razorpay HMAC verify |
| POST | `/cancel/{intent_id}` | User | Cancel intent |
| POST | `/webhook` | Public | Razorpay events |

#### Other
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/app-version` | Public | Latest APK info |
| GET | `/banners` | Public | Active banners |
| GET | `/notifications` | User | Recent (24h) |
| GET | `/settings` | Public | Delivery fee settings |
| POST | `/check-zone` | Public | Delivery zone check |
| GET | `/places/search` | Public | Nominatim search |
| GET | `/places/reverse` | Public | Nominatim reverse geocode |
| POST | `/upload` | Admin | Image to Supabase |
| POST | `/suggest-product` | User | Product suggestion |
| POST | `/combo-packs/add-to-cart` | User | Add pack items to cart |

#### Admin (`/api/admin`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/stats` | Dashboard (counts + revenue) |
| CRUD | `/products` | Product management |
| PUT | `/products/{id}/toggle` | Enable/disable |
| CRUD | `/categories` | Category management |
| GET | `/orders` | Order list (filterable) |
| PUT | `/orders/{id}/status` | Status transition |
| POST | `/orders/{id}/deliver` | OTP verify + deliver |
| GET | `/users` | User list |
| CRUD | `/combo-packs` | Combo pack management |
| PUT | `/combo-packs/{id}/toggle` | Enable/disable |
| CRUD | `/delivery-zones` | Zone management |
| CRUD | `/notifications` | Notification management |
| CRUD | `/banners` | Banner management |
| GET/PUT | `/settings` | Delivery settings |

### 4.3 Middleware Pipeline

```
Request → Security Headers → API Key Check → CSRF Check → CORS → Rate Limit + JWT
                                                                  ↓
                                                            Public path? → skip JWT
                                                            ↓
                                                            Valid token? → set user_id, role in request.state
                                                            ↓
                                                            Rate limit fail? → 429
```

### 4.4 Error Handling Pattern

- **Business logic exceptions**: `HTTPException` with specific status codes (404, 400, 409, 422)
- **Validation**: Pydantic schemas with detailed field validators
- **Ownership**: Every user-scoped query filters by `request.state.user_id`
- **Soft-delete**: All queries filter `is_deleted == False`
- **Transaction safety**: `db.commit()` with `db.rollback()` on exception

### 4.5 Background Tasks

None. The webhook handler runs synchronously in the request thread. No Celery, no async task queue, no background workers.

---

## 5. Database Schema & Relationships

### 5.1 Entity Relationship Summary

```
User ──┬── Address (1:N)
       ├── CartItem (1:N) ── Product (N:1)
       ├── Order (1:N) ──┬── OrderItem (1:N) ── Product
       │                 └── Payment (1:1)
       ├── PaymentIntent (1:N) ── Payment (1:1)
       ├── WishlistItem (1:N) ── Product
       └── ProductSuggestion (1:N)

Category ── Product (1:N)
Product ──┬── ProductImage (1:N)
          ├── ProductFlag (1:1)
          ├── CartItem
          ├── OrderItem
          ├── WishlistItem
          └── ComboPackItem

ComboPack ── ComboPackItem ── Product
```

### 5.2 Tables (21 total)

| Table | PK | FK(s) | Unique | Indexes |
|-------|----|-------|--------|---------|
| `users` | UUID(id) | — | email, firebase_uid, phone | email, firebase_uid |
| `token_blacklist` | UUID(id) | — | token_jti | token_jti |
| `categories` | UUID(id) | — | name | name |
| `products` | UUID(id) | category_id | — | category_id, name |
| `product_flags` | UUID(product_id) | product_id (CASCADE) | — | — |
| `product_images` | UUID(id) | product_id | — | product_id |
| `addresses` | UUID(id) | user_id | — | user_id |
| `cart_items` | UUID(id) | user_id, product_id | (user_id, product_id) | user+deleted, product+deleted |
| `orders` | UUID(id) | user_id, address_id | idempotency_key | user+deleted, status+deleted |
| `order_items` | UUID(id) | order_id (CASCADE), product_id | — | order_id, product_id |
| `payments` | UUID(id) | order_id, user_id, intent_id | transaction_id | gateway_order_id, order+user+deleted |
| `payment_intents` | UUID(id) | user_id | razorpay_order_id | user_id |
| `combo_packs` | UUID(id) | — | — | name |
| `combo_pack_items` | UUID(id) | pack_id (CASCADE), product_id | — | pack_id, product_id |
| `product_suggestions` | UUID(id) | user_id | — | — |
| `wishlist_items` | UUID(id) | user_id, product_id | (user_id, product_id) | user+deleted |
| `delivery_zones` | UUID(id) | — | — | — |
| `app_versions` | UUID(id) | — | — | — |
| `banners` | UUID(id) | — | — | — |
| `notifications` | UUID(id) | — | — | — |
| `app_settings` | UUID(id) | — | key | key |

### 5.3 Missing Indexes (Performance Risk)

| Table | Column(s) | Reason |
|-------|-----------|--------|
| `payments` | `intent_id` | Joined in payment flow queries |
| `order_items` | `product_id` | Already indexed ✓ |
| `payments` | `gateway_payment_id` | Partial unique index exists (good) |
| `product_suggestions` | `user_id` | FK to users, could be slow for admin listing |
| `notifications` | `created_at` | Filtered by "last 24 hours" |
| `banners` | `is_active` | Filtered by is_active + sort_order |

### 5.4 Nullable Columns of Concern

- `products.image` (String 500) — nullable, but images stored in product_images table makes this redundant
- `payments.gateway_payment_id` — nullable until payment completes (expected)
- `orders.address_id` — nullable (allowable for cancelled/failed orders)

---

## 6. Auth Flow Diagram

```
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   Flutter App    │     │   FastAPI Backend │     │  Firebase/Google │
├──────────────────┤     ├──────────────────┤     ├──────────────────┤
│                  │     │                  │     │                  │
│ User taps        │     │                  │     │                  │
│ "Sign in w/Google"│    │                  │     │                  │
│      │           │     │                  │     │                  │
│      ▼           │     │                  │     │                  │
│ google_sign_in   │─────│─── OAuth flow ───│────>│ ID Token issued  │
│ package          │     │                  │<────│                  │
│      │           │     │                  │     │                  │
│ Firebase Auth    │     │                  │     │                  │
│ verifyToken()   │     │                  │     │                  │
│      │           │     │                  │     │                  │
│ POST /google-login│────│──────────────────│────>│                  │
│ { id_token }    │     │                  │     │                  │
│                  │     │      │           │     │                  │
│                  │     │ verify Firebase  │     │                  │
│                  │     │ ID token (RS256  │     │                  │
│                  │     │ via Google pub   │     │                  │
│                  │     │ key cache)       │     │                  │
│                  │     │      │           │     │                  │
│                  │     │ Find or create   │     │                  │
│                  │     │ User by email    │     │                  │
│                  │     │ Link firebase_uid│     │                  │
│                  │     │      │           │     │                  │
│                  │     │ Generate HS256   │     │                  │
│                  │     │ JWT: {sub, jti,  │     │                  │
│                  │     │  role, tok_ver}  │     │                  │
│                  │     │      │           │     │                  │
│<────────────────│──────│──────────────────│     │                  │
│ { jwt, user }   │     │                  │     │                  │
│      │           │     │                  │     │                  │
│ Store JWT in     │     │                  │     │                  │
│ flutter_secure_  │     │                  │     │                  │
│ storage          │     │                  │     │                  │
│      │           │     │                  │     │                  │
│ Navigate to      │     │                  │     │                  │
│ HomePage         │     │                  │     │                  │
│                  │     │                  │     │                  │
└──────────────────┘     └──────────────────┘     └──────────────────┘

── Protecting routes ──────────────────────────────────────────

Flutter: No route guards. Protected by:
  1. Token existence check (main.dart startup)
  2. Server-side 401 on invalid/expired JWT
  3. Middleware decodes JWT and validates:
     a. Not in token_blacklist table
     b. User exists and not deleted
     c. token_version matches (session revocation)

── Logout ──────────────────────────────────────────────────────

POST /api/auth/logout
  → JWT's jti saved to token_blacklist
  → Flutter clears secure storage
  → Navigate to LoginPage

POST /api/auth/logout-all
  → user.token_version incremented
  → All existing JWTs (with old tok_ver) rejected
```

---

## 7. Payment Flow Diagram

### 7.1 Cash on Delivery

```
Cart → POST /api/orders → Order (status: "Pending")
  → POST /api/payments/process
    → Deduct product stock
    → Generate 6-digit delivery OTP
    → Create Payment record (method: "Cash on Delivery")
    → Clear cart items (soft-delete)
    → Order status → "Confirmed"
  → Return success
```

### 7.2 Razorpay (Intent-based — New Flow)

```
Cart → POST /api/payments/create-order { cart_items }
  ├── Check delivery zone (GeoJSON polygon via address lat/lng)
  ├── Validate stock
  ├── Create PaymentIntent (store cart_data snapshot)
  ├── Call Razorpay API: POST /orders { amount, currency, receipt }
  ├── Store razorpay_order_id on PaymentIntent
  └── Return { razorpay_order_id, amount, key_id, intent_id }

Flutter opens Razorpay checkout sheet:
  options = {
    key: key_id,
    amount: amount,
    order_id: razorpay_order_id,
    ...
  }

User completes payment → Razorpay SDK callback:
  onSuccess: { razorpay_payment_id, razorpay_signature }

POST /api/payments/verify { intent_id, payment_id, signature }
  ├── HMAC SHA256 verify: order_id + "|" + payment_id vs signature
  ├── Duplicate check: gateway_payment_id partial unique index
  ├── Create Order from PaymentIntent cart_data
  ├── Create Payment (method: "razorpay")
  ├── Deduct stock
  ├── Clear cart
  ├── Set Order status → "Confirmed"
  └── Return success
```

### 7.3 Razorpay (Legacy Retry — for failed orders)

```
Existing failed order
  → POST /api/payments/create-order { order_id }
    → Creates new Razorpay order for existing failed payment
    → Return { razorpay_order_id, amount, key_id }

Same verify flow, but tied to existing order_id (not intent_id)
```

### 7.4 Webhook Handler

```
Razorpay → POST /api/payments/webhook (HMAC SHA256 verified)
  ├── event: "payment.captured"
  │     → Mark payment successful if pending
  ├── event: "payment.failed"
  │     → Mark payment failed, store failure_reason
  └── event: "payment.refunded"
       → Mark payment refunded

Always returns 200 OK (prevents Razorpay retry storms)
```

---

## 8. Image Storage Flow

### 8.1 Architecture

```
Flutter app
  ├── Image Picker (camera/gallery)
  ├── Uploads to Supabase Storage via backend proxy
  │     (not client-side direct upload)
  └── Displays via Supabase public URL (no caching)

Backend:
  POST /api/upload (admin only)
    ├── Validate: magic bytes (PNG/JPEG/GIF/WEBP)
    ├── Validate: file extension (jpg/jpeg/png/gif/webp)
    ├── Validate: file size (max 5MB)
    └── Upload to Supabase Storage via REST API
         → Returns public URL

Supabase Storage:
  ├── Bucket: product-images (public? — likely public)
  ├── No signed URLs — direct public access
  └── Unique filenames generated by Supabase
```

### 8.2 Bucket Structure

```
product-images/ (bucket)
  ├── <uuid1>.png
  ├── <uuid2>.jpg
  └── ...
```

### 8.3 Issues

- **No client-side upload**: All uploads proxy through the backend, increasing latency and server load
- **No image optimization**: Raw uploads — no resizing, no WebP conversion, no compression
- **No CDN**: Supabase Storage has no built-in CDN; images served directly
- **No caching on Flutter side**: `Image.network()` without `cached_network_image` means every display re-downloads
- **Supabase used alongside Cloudinary** (`cloudinary_service.dart`, `cloudinary_constants.dart`) — dual image storage strategy exists but Cloudinary usage may be abandoned

---

## 9. Admin Panel Summary

### 9.1 Stack

- **Frontend**: Flutter in-app pages (no separate admin app/web dashboard)
- **Backend**: FastAPI router at `/api/admin` with role check
- **Auth check**: `_require_admin()` in every admin endpoint validates `request.state.user_role == "admin"`
- **Admin account**: Created at seed time via `ADMIN_EMAIL` env var

### 9.2 Admin Features

| Feature | Flutter Page | Backend Endpoints |
|---------|-------------|-------------------|
| Dashboard | `admin_home_page.dart` | `GET /api/admin/stats` |
| Products CRUD | `admin_products_page.dart` | CRUD + toggle |
| Categories CRUD | `admin_categories_page.dart` | CRUD |
| Orders List | `admin_orders_page.dart` | GET list, status update |
| Order Detail | `admin_order_detail_page.dart` (~55KB) | GET, status, OTP delivery |
| Banners CRUD | `admin_banners_page.dart` | CRUD |
| Delivery Zones | `admin_delivery_zone_page.dart` | CRUD |
| Users List | `admin_users_page.dart` | GET list |
| Combo Packs | `admin_combo_packs_page.dart` | CRUD + toggle |
| Notifications | `admin_notifications_page.dart` | CRUD |
| Settings | `admin_settings_page.dart` | GET/PUT settings |

### 9.3 Access Control

```
JWT contains: { role: "admin" }
                   ↓
RateLimitMiddleware → request.state.user_role = decoded_jwt["role"]
                   ↓
Admin endpoint → _require_admin()
                   ↓
if user_role != "admin" → HTTP 403 Forbidden
```

---

## 10. Deployment Architecture

### 10.1 Current Setup (GCP VM)

```
Internet
    │
    ▼
GCP VM (34.100.218.97) — port 80
    │
    ▼
Docker: nginx:alpine (zipra-nginx)
    │  - Reverse proxy
    │  - client_max_body_size 10M
    │  - Proxies to app:8000
    │  - No SSL (HTTP only)
    ▼
Docker: zipra-api (Python 3.12-slim)
    │  - uvicorn 1 worker, port 8000
    │  - Healthcheck: GET /health
    │  - Loads .env for config
    │  - Database: external PostgreSQL (Neon)
    ▼
Neon PostgreSQL (remote, serverless)
```

### 10.2 Docker Configuration

```yaml
# docker-compose.yml
services:
  app:
    build: .                    # Dockerfile (python:3.12-slim + curl + pip)
    container_name: zipra-api
    restart: unless-stopped
    env_file: .env              # All secrets via env_file
    expose: ["8000"]
    healthcheck: { curl /health, 30s interval, 40s start_period }

  nginx:
    image: nginx:alpine
    container_name: zipra-nginx
    ports: ["80:80"]
    volumes: [./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro]
    depends_on: [app]
```

### 10.3 Environment Variables (30+ vars)

| Category | Variables |
|----------|-----------|
| **Database** | `DATABASE_URL` |
| **Auth** | `JWT_SECRET`, `JWT_EXPIRY_MINUTES`, `BCRYPT_ROUNDS`, `API_KEY` |
| **Firebase** | `FIREBASE_PROJECT_ID`, `FIREBASE_PROJECT_NUMBER` |
| **Payment** | `RAZORPAY_ENABLED`, `RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`, `RAZORPAY_WEBHOOK_SECRET` |
| **Storage** | `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_UPLOAD_KEY`, `SUPABASE_STORAGE_BUCKET` |
| **SMTP** | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `SMTP_FROM_EMAIL` |
| **Admin** | `ADMIN_EMAIL`, `ADMIN_PASSWORD` |
| **Rate Limit** | `RATE_LIMIT_MAX_ATTEMPTS`, `RATE_LIMIT_WINDOW_SECONDS`, `RATE_LIMIT_BLOCK_MINUTES` |
| **Other** | `FRONTEND_URL`, `BACKEND_URL`, `SENTRY_DSN` |

### 10.4 CI/CD

**None.** No GitHub Actions, no automated deployment pipeline. Manual deployment via:
1. `git push origin main`
2. `ssh` to GCP VM
3. `docker compose down && docker compose up --build -d`

### 10.5 Deployment

Deployment uses Docker Compose on GCP VM (`34.100.218.97`). See `compose.yaml` and `nginx/default.conf`.

---

## 11. Security Issues Found

### CRITICAL

| # | Issue | Location | Description |
|---|-------|----------|-------------|
| C1 | **Debug keystore for release builds** | `android/key.properties` | Uses default debug keystore (`debug.keystore` with password `android`). Any release APK built with this config is unsigned for production. Users cannot trust the APK integrity. |
| C2 | **Hardcoded API secret in HMAC comparison** | `backend/main.py:203-208` | The API key is compared with `hmac.compare_digest` but the comparison is against a stored constant — if the env var is weak or leaked, all mobile clients are compromised. (Mitigated by requiring env var.) |
| C3 | **No HTTPS** | `nginx/default.conf` | Nginx serves HTTP only. All traffic between user and server is plaintext, including JWT tokens and Razorpay responses. On production GCP VM, this is a critical gap. |

### HIGH

| # | Issue | Location | Description |
|---|-------|----------|-------------|
| H1 | **No release signing** | `android/key.properties` | No production keystore configured. App cannot be published to Play Store. |
| H2 | **No database encryption at rest** | `backend/config.py` | No mention of PostgreSQL encryption, TLS, or VPC. Data in transit is assumed encrypted via `sslmode=require` in DATABASE_URL (Neon default). |
| H3 | **In-memory rate limiting — resets on restart** | `backend/middleware.py` | Rate limit counters in Python dict. Server restart resets all counters. Attacker can time attacks between restarts. |
| H4 | **No input sanitization on product names** | `backend/schemas.py` | `ProductCreate.name` (2-200 chars) accepts any characters — potential XSS if displayed unsanitized (though Flutter renders safely). |
| H5 | **JWT secret validation only at import** | `config.py` | JWT secret minimum length (32 chars) is checked at module import time, not on every request. If env changes mid-run, old config persists. |

### MEDIUM

| # | Issue | Location | Description |
|---|-------|----------|-------------|
| M1 | **No email verification** | `backend/auth.py` | Users can sign in with any Google account. No domain whitelist or email verification. |
| M2 | **Password hash code exists but is unused** | `backend/auth.py:31` | `_hash_password()` function with bcrypt exists but no endpoint uses it. Dead code that suggests incomplete password-based auth. |
| M3 | **Rate limiting window is second-granularity, fixed** | `backend/middleware.py` | Uses `time.time()` window. A burst of requests at window boundary could double the allowed rate. |
| M4 | **No soft-delete on TokenBlacklist cleanup** | `backend/models.py` | TokenBlacklist has no cleanup mechanism. Table grows unbounded as tokens are blacklisted. Potential storage issue at scale. |
| M5 | **FRONTEND_URL validated only at startup** | `backend/main.py` | If FRONTEND_URL env is empty, app raises RuntimeError. If set to `*`, CORS becomes permissive. |

### LOW

| # | Issue | Location | Description |
|---|-------|----------|-------------|
| L1 | **No request body size limit** | `backend/main.py` | No `max_request_size` middleware. Large payloads could cause OOM. Mitigated by Nginx `client_max_body_size 10M`. |
| L2 | **Seed data has picsum.photos placeholder images** | `backend/main.py:seed_data` | Placeholder images from external service. If picsum.photos is down, seed products have broken images. |
| L3 | **Multiple Express-like middleware classes** | `backend/middleware.py` | `BaseHTTPMiddleware` is considered deprecated in newer Starlette — potential upgrade issue. |
| L4 | **Logging filter uses regex on stringified dicts** | `backend/main.py:52-80` | The `_SecretsRedactFilter` filters log strings by regex. Structured logging (JSON) might bypass the filter. |

---

## 12. Performance Issues Found

| # | Issue | Location | Impact |
|---|-------|----------|--------|
| P1 | **N+1: Admin orders list fetches user for each order** | `backend/admin.py:admin_list_orders` | Each order in the list triggers a separate query for the user. At 100 orders = 101 queries. |
| P2 | **N+1: Product list fetches images individually** | `backend/resources.py:list_products` | Uses `selectin` relationship loading for images, but if paginated, could still lead to separate queries. |
| P3 | **No image caching on Flutter** | All `Image.network()` calls | Every product image re-downloads on every widget rebuild. No `cached_network_image` package. |
| P4 | **Synchronous Nominatim calls in request thread** | `backend/resources.py:reverse_geocode` | External HTTP call (Nominatim API) blocks the single uvicorn worker. All other requests queue behind it. |
| P5 | **Single uvicorn worker** | `Dockerfile` (and rate limiting design) | Only 1 worker in Docker. Rate limiting works with 1 worker but throughput is capped. |
| P6 | **No pagination on products endpoint** | `backend/resources.py:list_products` | Returns ALL products in one response. At scale, payload size grows unbounded. |
| P7 | **No pagination on admin orders list** | `backend/admin.py:admin_list_orders` | Same — returns all orders unfiltered (except by status). |
| P8 | **No pagination on admin users list** | `backend/admin.py:list_users` | Returns all users in one response. |
| P9 | **Full cart data stored as JSON text** | `backend/models.py:PaymentIntent.cart_data` | Text column stores serialized JSON of entire cart. Not queryable, no structure validation at DB level. |
| P10 | **Webhook runs synchronously** | `backend/resources.py:razorpay_webhook` | If Razorpay webhook processing takes time, it blocks the worker. Could timeout for large payloads. |

---

## 13. Dead Code & Duplicate Code

### 13.1 Dead Code (Already Removed)

The following were identified and removed prior to this report:

| Item | Reason |
|------|--------|
| `lib/screens/splash_screen.dart` | Replaced by inline init in main.dart |
| `lib/widgets/cart_bottom_nav.dart` | Unused |
| `lib/constants/responsive.dart` | Unused |
| `cupertino_icons` dependency | Unused |
| `razorpay` Python package | Unused (only razorpay_flutter used) |
| `PasswordResetCode` model | No endpoint references it |
| `BACKEND_URL` env var | Removed from config.py |
| `SUPABASE_ANON_KEY` | Removed from config.py |
| 10 dead API endpoints | Removed from resources.py |
| Old SQLite test DBs | Moved to archive/ |

### 13.2 Dead Code (Still Present)

| # | Item | Location | Reason |
|---|------|----------|--------|
| D1 | `_hash_password()` / `_verify_password()` | `backend/auth.py:31-46` | Never called — no password-based auth endpoint exists |
| D2 | `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` in env | `.env.example` | Only used when `RAZORPAY_ENABLED=true`; dead if disabled |
| D3 | `CloudinaryService` / `cloudinary.dart` | `lib/services/cloudinary_service.dart`, `lib/constants/cloudinary.dart` | All images now in Supabase Storage — no Cloudinary usage visible |
| D4 | `admin_password` in `main.py:seed_data` | `backend/main.py:373` | Admin created with `password_hash=None` (Firebase-only) — password param unused |
| D5 | `Procfile` / `render.yaml` | `deploy/` | Removed — migrated to GCP Docker Compose |
| D7 | Archive SQLite DBs | `archive/*.db` | Legacy test databases, no longer needed |
| D8 | `DELIVERY_ZONE_TYPES` in schemas | `backend/schemas.py:688-691` | Appears unused in actual zone logic |
| D9 | `payments_page.dart` | `lib/pages/payments_page.dart` | Saved payment methods page — Razorpay doesn't save methods client-side; likely unused |
| D10 | `macos/` directory | Entire macOS platform | iOS/Android only project; macOS is unused platform target |

### 13.3 Duplicate Code

| # | Item | Location | Description |
|---|------|----------|-------------|
| Dup1 | Two separate API services | `api_service.dart` + `admin_api_service.dart` | Both do the same thing with different method names. ~80% code overlap. Could be merged with a base class. |
| Dup2 | Address validation in multiple schemas | `AddressCreate`, `AddressUpdate`, `GpsAddressCreate` in `schemas.py` | Each re-defines similar validation rules (pincode regex, phone format) |
| Dup3 | Cart item → response conversion | `_cart_item_to_response()` duplicated logic across cart endpoints | Similar calculations in multiple places |
| Dup4 | Order → response conversion | `_order_to_response()` called in multiple order endpoints | Could be a reusable helper (already extracted but could be cleaner) |
| Dup5 | Seed data SQL vs Alembic migrations | `main.py` imperative ALTER TABLE vs `alembic/versions/` | Dual strategy for table changes — potential drift |

---

## 14. Recommendations (Priority Order)

### P0 — Fix Before Next Release

1. **Configure proper Android release signing** — Generate a real keystore, update `key.properties`, secure the keystore file. Without this, the APK is untrusted.
2. **Enable HTTPS** — Add SSL termination (Let's Encrypt via certbot, or put behind GCP Cloud Load Balancer with managed SSL).
3. **Add `cached_network_image`** — Wrap all `Image.network()` calls with `CachedNetworkImage` to avoid re-downloading on every build.

### P1 — High Impact

4. **Unify API services** — Merge `api_service.dart` and `admin_api_service.dart` into a single service with a base HTTP client. Reduces maintenance burden.
5. **Add pagination to list endpoints** — `GET /products`, `GET /admin/orders`, `GET /admin/users` all need `?page=&limit=` parameters.
6. **Add N+1 query fix for admin orders** — Use `joinedload()` or `selectinload()` to eagerly load users with orders in a single query.
7. **Move Nominatim calls to background** — Use `BackgroundTasks` in FastAPI or async httpx for external API calls.

### P2 — Medium Impact

8. **Clean up dual migration strategy** — Consolidate to pure Alembic. Remove imperative `ALTER TABLE` from `main.py`.
9. **Remove dead Cloudinary code** — Delete `cloudinary_service.dart`, `cloudinary.dart` since Supabase Storage is now used.
10. **Remove dead code** — `_hash_password()` functions, `payments_page.dart` (if unused).
11. **Add TokenBlacklist cleanup job** — Regularly purge expired blacklisted tokens.
12. **Reduce home_page.dart size** — 101KB file is too large. Split into composable widgets (search bar, banner carousel, category grid, product grid, offers section).

### P3 — Low Impact / Future

13. **Add state management** — Introduce Provider or Riverpod for reactive state propagation (especially cart changes → UI updates).
14. **Add CI/CD (GitHub Actions)** — Automated test run + build on PR, automated deploy on main.
15. **Add image optimization** — Client-side image resizing before upload, or backend processing with Pillow.
16. **Add request body size limit middleware** — Safety net beyond Nginx's 10MB limit.
17. **Add database-level constraints** — `CHECK` constraints for order status values, numeric ranges.
18. **Fix Flutter analyzer warnings** — 11 `use_build_context_synchronously` warnings in admin_order_detail_page, complete_profile_page, delivery_location_page.

---

## SCORES

| Category | Score | Reasoning |
|----------|-------|-----------|
| **Architecture Score** | **7/10** | Clean separation (routers, models, services). Soft-delete pattern is good. But no state management, no CI/CD, dual migration strategy hurt the score. |
| **Code Quality Score** | **6/10** | Modular organization is decent. Some large files (home_page 101KB, admin_order_detail 55KB, resources 2116 lines). Two near-identical API services. No Dart lint CI. Tests exist but coverage is minimal (1 widget test, 6 backend tests). |
| **Security Score** | **5/10** | Good middleware stack (CORS, CSRF, rate limiting, JWT blacklist, log redaction). But: no HTTPS in production, debug keystore for release builds, no input sanitization on product names, no email verification. JWT handling is solid. |
| **Production Readiness Score** | **6/10** | Dockerized and running on GCP VM. Health check configured. Sentry connected. But: no CI/CD, no automated backups, no monitoring, no staging environment, single worker, no HTTPS. |
| **OVERALL** | **6/10** | Functional and well-structured for a small-scale app. Needs hardening for production scale: HTTPS, caching, pagination, CI/CD, and proper release signing. |
