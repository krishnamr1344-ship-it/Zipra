# Zipra Multi-App Project

## Goal
Multi-app grocery delivery platform with 3 separate Flutter apps:
1. **Customer App** (`apps/customer_app/`) — Customer-facing grocery shopping
2. **Shop Owner App** (`apps/shop_app/`) — Shop inventory, orders, earnings
3. **Admin App** (`apps/admin_app/`) — Full admin dashboard

Shared Python FastAPI backend serves all 3 apps.

## Constraints & Preferences
- All payments COD only; 3 product images required; Flipkart-style order tracker; auto-redirect 20s after order
- Auto-ask location permission on first open; GPS reverse-geocode via Nominatim; allow manual address if GPS denied
- Delivery location UI must show Area+City (bold) first line, street/locality (gray) second line
- Tap location opens bottom sheet with: current location detect, search places, saved addresses
- Address form includes: house number, floor, landmark, address type (Home/Work/Other)
- Admin must receive: customer name, phone, full address, GPS coordinates, Google Maps link
- Backend port 8000; emulator uses host IP 192.168.1.3:8000

## Architecture

### Backend (FastAPI) — `backend/app/`
- **Entry point:** `backend/app/main.py`
- **Models:** `backend/app/models/` (14 files: user, category, product, address, cart, order, payment, combo_pack, offer, delivery, shop, delivery_partner, earning, notification)
- **Schemas:** `backend/app/schemas/` (12 files: user, category, product, address, cart, order, payment, combo_pack, offer, delivery, shop, notification, common)
- **API Routes:**
  - Customer: `backend/app/api/customer/` (categories, products, cart, orders, addresses, payments, offers, delivery)
  - Admin: `backend/app/api/admin/` (products, categories, orders, users, delivery, offers, shops)
  - Shop: `backend/app/api/shop/` (shop_auth, products, orders, earnings)
  - Auth: `backend/app/api/auth.py`
- **Core:** `backend/app/core/` (config.py, security.py, constants.py)
- **DB:** `backend/app/db/` (base.py, session.py)
- **Middleware:** `backend/app/middleware/rate_limit.py`
- **Utils:** `backend/app/utils/helpers.py`
- **22 database tables**, **~107 API endpoints**
- Auth: Firebase (customer) + email/password (admin/shop owner)
- Backend URL: `https://zipra-api-txlyzg2aeq-el.a.run.app`

### Database Tables
**Original (15):** users, categories, products, addresses, cart_items, orders, order_items, payments, tokens_blacklist, delivery_zones, offers, offer_products, delivery_fees, combo_packs, combo_pack_items
**New (7):** shops, product_approvals, shop_orders, delivery_partners, delivery_assignments, earnings, notifications

## Progress

### Phase 1: Backend Foundation — DONE
- All 20 routers registered, 22 tables, 55 schemas, ~107 endpoints
- Shop owner auth (email/password), product CRUD, order workflow, earnings
- Admin shop management, delivery partner CRUD, product approval APIs
- Auth system: Firebase + email/password + forgot/reset/change password
- `delivery_fee` column added to Order model

### Phase 2: Shop Owner App — DONE
- 18 Dart files, 9 pages, 23 API methods, `flutter analyze` → 0 errors
- Login, Dashboard, Products (4-tab filter, CRUD, stock, images), Orders (4-tab filter, status workflow), Earnings (summary + history), Profile, Settings
- All at `apps/shop_app/` — independent Flutter project, package: `com.zipra.shop_owner`

### Phase 3: Admin App — DONE
- 16 Dart files, 9 admin pages, `flutter analyze` → 0 errors, 15 infos only
- Login (email/password), Dashboard (4 stat cards, 8 management tiles), Products, Categories, Orders (4-tab filter + detail), Users, Delivery Zones (map), Delivery Fees, Combo Packs, Offers
- All at `apps/admin_app/` — independent Flutter project, package: `com.zipra.zipra_admin`

### Phase 4: Customer App Cleanup — DONE
- Removed 10 admin pages + admin_api_service.dart from customer app
- Removed admin routing from main.dart and login_page.dart
- Customer app now customer-only, `flutter analyze` → 0 errors

### Bug Fixes Done
- Fixed `add_lat_lng_to_addresses.sql` — added `IF NOT EXISTS`
- Fixed `Order` model — added `delivery_fee` column
- Removed dead `PUBLIC_PATHS` entries (`/api/auth/register`, `/api/auth/login`)
- Removed deprecated `resources.py` and `admin.py` barrel files

### In Progress
- (none)

### Completed
- **Phase 5: Enterprise Reorganization** — DONE
  - Backend: `backend/app/` modular structure (models/, schemas/, api/customer|admin|shop/, core/, db/, middleware/, utils/)
  - Customer App: `apps/customer_app/lib/` feature-based (`core/` + `features/` with 12 feature folders), 0 errors
  - Shop App: `apps/shop_app/lib/` feature-based (`core/` + `features/` with 6 feature folders), 0 errors
  - Admin App: `apps/admin_app/lib/` feature-based (`core/` + `features/` with 10 feature folders), 0 errors, 10 infos
- **Phase 6: Root Folder Reorganization** — DONE
  - All 3 Flutter apps moved under `apps/` directory
  - Customer app: root → `apps/customer_app/`
  - Shop app: `shop_app/` → `apps/shop_app/`
  - Admin app: `admin_app/` → `apps/admin_app/`
  - Created `docs/` and `scripts/` directories
  - Updated `.gitignore` and `AGENTS.md` paths

### Known Issues
- trycloudflare tunnel URL is EPHEMERAL — need permanent domain before Play Store
- `admin_combo_packs_page.dart` imports `api_service.dart` but only uses `AdminApiService` (unused import, harmless)

### Key Decisions
- 3 separate Flutter apps sharing one FastAPI backend
- Shop owner app uses local `api_service.dart` (simplified, no Firebase)
- Admin app uses local `api_service.dart` (simplified, email/password login only)
- All address fields in separate columns (not JSON) for queryability
- `url_launcher` for Google Maps navigation (lighter than webview)
- SSL bypass via `HttpOverrides.global` in both `main.dart` and `api_service.dart`
- Cloudflare Tunnel for free public HTTPS
- Signing: upload-keystore.jks (password: myapp123)
- Order model has `delivery_fee` column (nullable, default 0)

### Next Steps
- Buy a domain for permanent Cloudflare Tunnel
- Remove self-signed cert HttpOverrides before Play Store
- Deploy latest backend to Cloud Run
- Build & test final APKs for all 3 apps
- Play Store publish

## Critical Context
- Backend port 8000; admin: admin@admin.com / Admin@123; DB: Cloud SQL (PostgreSQL 16) - delivery_user@34.14.136.128:5432/delivery_db
- Backend URL: `https://zipra-api-txlyzg2aeq-el.a.run.app`
- Customer app: package `com.jvs.app`; Shop app: `com.zipra.shop_owner`; Admin app: `com.zipra.zipra_admin`
- `maps_link` format: `https://www.google.com/maps?q={lat},{lng}`

## Relevant Files

### Backend
- `backend/app/main.py` — registers all 20 routers, seed data
- `backend/app/models/` — 14 SQLAlchemy model files
- `backend/app/schemas/` — 12 Pydantic schema files
- `backend/app/api/customer/` — 8 customer route modules
- `backend/app/api/admin/` — 7 admin route modules
- `backend/app/api/shop/` — 4 shop route modules
- `backend/app/api/auth.py` — auth endpoints
- `backend/app/core/` — config, security, constants
- `backend/app/db/` — base, session
- `backend/app/middleware/rate_limit.py`
- `backend/app/utils/helpers.py`

### Customer App (`apps/customer_app/lib/`)
- `apps/customer_app/lib/main.dart` — entry point (admin routing removed)
- `apps/customer_app/lib/core/api/api_service.dart` — barrel file (8 feature modules)
- `apps/customer_app/lib/core/api/api_service_base.dart` — core class with token management
- `apps/customer_app/lib/features/` — 11 feature folders with pages

### Shop Owner App (`apps/shop_app/lib/`)
- `apps/shop_app/lib/main.dart` — entry point with auth check
- `apps/shop_app/lib/core/api/shop_api_service.dart` — 23 API methods
- `apps/shop_app/lib/core/models/` — shop_model, shop_product, shop_order, earning
- `apps/shop_app/lib/features/` — 6 feature folders (auth, dashboard, earnings, orders, products, profile)

### Admin App (`apps/admin_app/lib/`)
- `apps/admin_app/lib/main.dart` — entry point with auth check
- `apps/admin_app/lib/core/api/api_service.dart` — simplified (token + login)
- `apps/admin_app/lib/core/api/admin_api_service.dart` — 27 admin API methods
- `apps/admin_app/lib/core/constants/theme.dart` — AppColors (shared design tokens)
- `apps/admin_app/lib/features/` — 10 feature folders (auth, categories, combo_packs, dashboard, delivery, offers, orders, products, shops, users)
