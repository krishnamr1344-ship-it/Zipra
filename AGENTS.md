# Delivery App Project

## Goal
Implement Zepto/Swiggy/Blinkit-style GPS delivery location system with editable address form, place search, multiple address types, and admin maps integration.

## Constraints & Preferences
- All payments COD only; 3 product images required; Flipkart-style order tracker; auto-redirect 20s after order
- Auto-ask location permission on first open; GPS reverse-geocode via Nominatim; allow manual address if GPS denied
- Delivery location UI must show Area+City (bold) first line, street/locality (gray) second line
- Tap location opens bottom sheet with: current location detect, search places, saved addresses
- Address form includes: house number, floor, landmark, address type (Home/Work/Other)
- Admin must receive: customer name, phone, full address, GPS coordinates, Google Maps link
- App language: Tamil (user communicates in Tamil)
- Backend port 8000; emulator uses host IP 192.168.1.3:8000

## Progress

### Done
- All 5 admin pages redesigned with gradient SliverAppBar, search bars, status filters, card shadows
- Created `admin_order_detail_page.dart` with order items, user details, GPS address, maps link, status change
- Added logout button to admin home page
- Added `address_line2`, `landmark`, `maps_link` to backend responses (admin.py, resources.py, schemas.py)
- Added `address_type` (Home/Work/Other), `house_number`, `floor_number` columns to addresses table + migration
- Updated backend models.py, schemas.py, resources.py, admin.py for all new address fields
- Added `GET /api/places/search` endpoint (Nominatim autocomplete)
- Added `createAddress`, `searchPlaces`, `updateAddress` to `api_service.dart`
- Added `url_launcher: ^6.2.6` to pubspec.yaml
- Created `address_form_page.dart` — full address editor with house/floor/landmark/type
- Created `place_search_page.dart` — Nominatim search with 500ms debounce
- Created `location_picker_sheet.dart` — Zepto-style bottom sheet (current location, search, saved addresses)
- Updated home page location bar to 2-line Zepto format (Area+City bold, street gray)
- Updated `api_service.dart`: `createGpsAddress` accepts optional landmark + address_type; added `searchPlaces`, `createAddress`, `updateAddress`
- Updated `location_service.dart`: saves all new address fields to SharedPreferences
- Fixed bug in `payment_page.dart`: `_loadAddress()` was not awaited causing empty `_addressId`
- HTTPS setup with self-signed cert + HttpOverrides
- Cloudflare Tunnel for public HTTPS access
- APK & AAB signed and built (package: com.jvs.app)
- Fixed MainActivity class path for release builds

### In Progress
- (none)

### Known Issues
- ⚠️ trycloudflare tunnel URL is EPHEMERAL — changes every time cloudflared restarts. Need a permanent domain before Play Store publish.

### Key Decisions
- Used separate Nominatim search endpoint (`/api/places/search`) to avoid API key exposure
- Address types: Home/Work/Other with Pydantic enum validation
- All address fields in separate columns (not JSON) for queryability
- New fields via ALTER TABLE migrations (not dropping/recreating)
- `url_launcher` for Google Maps navigation (lighter than webview)
- Location picker as bottom sheet using `LocationPickerSheet` widget
- SSL bypass via `HttpOverrides.global` in both `main.dart` and `api_service.dart`
- Cloudflare Tunnel for free public HTTPS
- Signing: upload-keystore.jks (password: myapp123)

### Next Steps
- Buy a domain (e.g., jvsgrocery.com) for permanent Cloudflare Tunnel
- Set up permanent tunnel with `cloudflared tunnel create`
- Remove self-signed cert HttpOverrides before Play Store
- Update _baseUrl in 3 files (api_service, admin_api_service, delivery_zone_service)
- Deploy latest backend to Cloud Run
- Build & test final APK with delivery fee logic
- Play Store publish

## Critical Context
- New columns: `address_type VARCHAR(20) DEFAULT 'Home'`, `house_number VARCHAR(50)`, `floor_number VARCHAR(50)` in addresses table
- Backend port 8000; admin: admin@admin.com / Admin@123; DB: delivery_user@localhost:5432/delivery_db
- `maps_link` format: `https://www.google.com/maps?q={lat},{lng}`
- PSelva user: selva555@gmail.com (password unknown)
- Tunnel URL (ephemeral): https://assist-legislature-temporarily-trackbacks.trycloudflare.com

### Added
- **Monthly Needs (Combo Packs)** — "Monthly Needs" section on Offers tab with ready-made grocery packs (Family Pack, PG/Hostel Pack, Small Hotel Pack, Tea Shop Pack)
- `backend/models.py` — `ComboPack` + `ComboPackItem` models
- `backend/schemas.py` — `ComboPackCreate/Update/Response`, `ComboPackItemInput/Response`, `PackAddRequest`
- `backend/resources.py` — `GET /api/combo-packs`, `POST /api/combo-packs/add-to-cart`
- `backend/admin.py` — Admin CRUD for packs (create/edit/delete/toggle enable)
- `backend/migrations/create_combo_packs.sql` — schema migration
- `lib/models/combo_pack.dart` — Flutter model
- `lib/pages/offers_page.dart` — Offers tab with Monthly Needs UI, big combo cards, offer badge, savings text, one-click add to cart
- `lib/pages/admin_combo_packs_page.dart` — Admin management page (list, create/edit bottom sheet, enable/disable toggle, delete)
- `lib/services/api_service.dart` — `getComboPacks()`, `addPackToCart()`
- `lib/services/admin_api_service.dart` — Admin CRUD methods for packs
- **Token Expiry Fix** — `delivery_location_page.dart` now detects token expiry on "Confirm Address", clears session, and redirects to login
- **Delivery Fee System** — New `DeliveryFee` backend model (min/max order amount, fee) with admin CRUD, public `POST /api/delivery-fee` endpoint to calculate applicable fee, Flutter admin page (`admin_delivery_fee_page.dart`) for managing fee tiers, and PaymentPage integration to fetch, display, and apply delivery fee to order total. Also added `delivery_fee` field to `OrderCreateRequest`/`OrderDirectCreateRequest` schemas.
- **Delivery Fee Public Endpoint** — `POST /api/delivery-fee` in `resources.py` accepts `subtotal` and returns matching fee tier (highest `min_order_amount` ≤ subtotal, respecting `max_order_amount` upper bound)
- **Admin Delivery Fee Page** — `lib/pages/admin_delivery_fee_page.dart` with full CRUD (list, create/edit bottom sheet, delete), linked from admin home page
- **PaymentPage Delivery Fee** — Fetches fee on init via `getDeliveryFee(subtotal)`, displays subtotal/fee/grand total breakdown, passes `deliveryFee` to `createOrder`

## Relevant Files
- `backend/migrations/add_address_fields.sql` — schema migration
- `lib/pages/address_form_page.dart` — address editor
- `lib/pages/place_search_page.dart` — place search
- `lib/pages/location_picker_sheet.dart` — Zepto-style location picker
- `lib/pages/home_page.dart` — 2-line location bar
- `lib/pages/admin_order_detail_page.dart` — admin maps link
- `lib/services/api_service.dart` — new endpoints
- `lib/services/location_service.dart` — prefs persistence
- `lib/main.dart` — HttpOverrides + error handling
- `android/app/build.gradle.kts` — signing config + package com.jvs.app
- `android/app/src/main/AndroidManifest.xml` — full MainActivity path
