# Delivery App — Full Security & Quality Audit

**Repository**: https://github.com/selvaabi5555/delivery-app  
**Audited**: 46 Dart files, 13 Python files, 4 SQL files, 4 config files  
**Date**: 2026-05-29

---

## Scoring Summary

| Category | Score | Max |
|---|---|---|
| 🔒 Security | 2/10 | 10 |
| ⚡ Performance | 5/10 | 10 |
| 🧹 Code Quality | 4/10 | 10 |
| ✅ Error Handling | 2/10 | 10 |
| 📱 UX | 4/10 | 10 |
| 🏗 Architecture | 3/10 | 10 |
| **Overall** | **3.3/10** | **10** |

**Verdict**: **FAIL** — Multiple CRITICAL security issues require immediate remediation before production deployment.

---

## 🔴 CRITICAL

### C1. Secrets committed to repository
**File**: `backend/.env.bak`  
**Exposed**:
- `DATABASE_URL=postgresql://delivery_user:D3l!v3ryDB%232024Secure` — database password
- `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` — Supabase admin JWT (full DB access, bypasses RLS)
- `JWT_SECRET=your-super-secret-jwt-key-2024!Secure#Delivery` — token signing key
- Admin credentials: `admin@yourdomain.com` / `YourStrongAdminPass#2024`
- `SECRET_KEY`, `FLASK_SECRET_KEY`, `ENCRYPTION_KEY`

**Fix**: `git rm --cached backend/.env.bak && git rebase` all history to purge. Add `*.env*` to `.gitignore`.

---

### C2. Self-signed SSL certificate bypass in production
**File**: `lib/main.dart:33-36`
```dart
(http.Client) {
  io.HttpClient client = ...;
  client.badCertificateCallback = (cert, host, port) => true;  // TRUSTS ANY CERT
  return client;
}
```
**File**: `lib/services/api_service.dart:9-14` — duplicate bypass in the HTTP client factory.

**Impact**: Man-in-the-middle attack. Anyone on the network can intercept HTTPS traffic, read all API requests/responses including auth tokens, passwords, and order data.

**Fix**: Remove `badCertificateCallback` entirely for production. Use only for dev builds behind `kReleaseMode` check.

---

### C3. Hardcoded production API URL (no environment config)
**File**: `lib/services/api_service.dart:22`
```dart
const _baseUrl = 'https://delivery-app-api-16t0.onrender.com';
```
**File**: `lib/services/admin_api_service.dart:6` — same URL.

**Impact**: Cannot change backend URL without rebuilding the app. If Render.com URL changes or needs staging/testing URLs, impossible without code change.

**Fix**: Read from environment/config at runtime. Use `--dart-define` or a `.env` file loaded at build time.

---

### C4. No API key / origin validation on backend
**File**: `backend/main.py` (all endpoints), `backend/middleware.py`

**Impact**: Backend CORS is set globally but there is **no enforcement** that requests come from the authorized mobile app. Any client can call the API.

**Fix**: Add `X-API-Key` header check or origin verification middleware. Validate that requests originate from known clients.

---

### C5. Insecure password reset — no backend API
**File**: `lib/pages/forgot_password_page.dart:45-47`
```dart
onPressed: () {
  setState(() => _sent = true);  // Just sets a local boolean!
},
```

**Impact**: Password reset is a **UI illusion**. No email is sent, no backend endpoint called, no token generated. Users are told "Email Sent!" but nothing happens.

**Fix**: Implement `/api/auth/forgot-password` and `/api/auth/reset-password` endpoints. Call them from the client.

---

### C6. Race condition in stock decrement
**File**: `backend/resources.py` (order creation endpoint — no atomic stock decrement)
**File**: `supabase_setup.sql` (contains atomic fix but it is NOT deployed/connected)

**Impact**: Two concurrent orders for the last item can both succeed, resulting in negative stock or overselling.

**Fix**: Use `UPDATE products SET stock = stock - ? WHERE stock >= ? AND id = ?` (atomic). The SQL in `supabase_setup.sql` has the correct pattern but the FastAPI code doesn't use it.

---

### C7. Global singleton cart — no user session scoping
**File**: `lib/models/cart_model.dart:83`
```dart
final cartNotifier = CartNotifier();  // global singleton
```

**Impact**: Cart state persists across user logins via `SharedPreferences`. User A logs out, User B logs in — sees User A's cart. Cart data is never synced to backend.

**Fix**: Scope cart to authenticated user. Clear on logout. Sync with backend `/api/cart` endpoints.

---

### C8. Checkout bypasses backend cart API entirely
**File**: `lib/pages/payment_page.dart:90-94`
```dart
final items = cartNotifier.items.map((i) => ({
  'product_id': i.productId,
  'quantity': i.count,
})).toList();
await _api.createOrder(items, 'cod', ...);
```

**Impact**: The backend has a `/api/cart` system but the frontend never uses it for checkout. Orders are constructed from local state — no server-side price validation, no stock check, no cart consistency.

**Fix**: Use backend cart API: add items → get cart from server → submit order from server cart.

---

### C9. Dual backend confusion — FastAPI + Flask overlapping routes
**Files**: `backend/main.py` (FastAPI), `backend/flask_app.py` (Flask)

**Impact**: Two separate Python backends with overlapping routes, separate database adapters (`database.py` using SQLAlchemy vs `supabase_db.py` using supabase-py), and inconsistent auth flows. Deployment ambiguity — which one runs?

**Fix**: Choose one framework, remove the other. Consolidate database access layer.

---

### C10. SupabaseService.initialize() throws on missing .env
**File**: `lib/services/supabase_service.dart:21`
```dart
await dotenv.load(fileName: ".env");  // throws FileNotFound if .env missing
```

**Impact**: App crashes on startup if `.env` file is not present. No graceful fallback to defaults or error handling.

**Fix**: Wrap in try-catch, log warning, fall back to defaults or show user-friendly error screen.

---

## 🟠 HIGH

### H1. DeliveryZoneService silently assumes serviceable on error
**File**: `lib/services/delivery_zone_service.dart:21`
```dart
} catch (_) {
  return ZoneCheckResult(true, null);  // returns serviceable=true on ANY error
}
```

**Impact**: If the network is down or the API returns an error, the app tells the user their location is serviceable. Invalid orders may be placed for out-of-zone areas.

**Fix**: Return a failure result on error, show error state to user.

---

### H2. No loading states on many pages
**Files**: Most `_load*` methods lack visual loading indicators, particularly:
- `addresses_page.dart` — `_loadAddresses()` no loading spinner
- `orders_page.dart` — `_loadOrders()` no loading spinner  
- `product_detail_page.dart` — no loading for product fetch
- `help_support_page.dart` — static placeholder (also H5)

**Impact**: Users experience blank screens during network calls. App feels unresponsive.

**Fix**: Add `_loading` state + `CircularProgressIndicator` consistently.

---

### H3. No empty state widgets in most list pages
**Files**: `orders_page.dart`, `addresses_page.dart`, `payments_page.dart`, `wishlist_page.dart`

**Impact**: Empty lists show nothing — users don't know if data is loading, empty, or errored.

**Fix**: Add empty state illustrations/messages like `offers_page.dart:64-73` does.

---

### H4. No form validation errors shown on UI
**File**: `lib/pages/signup_page.dart`, `lib/pages/login_page.dart`

**Impact**: Backend returns validation errors (e.g., "Password must contain uppercase letter") but they are caught generically and shown as raw exception text. Users get unhelpful error messages.

**Fix**: Parse error response and show field-level validation messages inline.

---

### H5. Help & Support page is a dead placeholder
**File**: `lib/pages/help_support_page.dart:10`
```dart
body: const Center(child: Text('FAQs & contact info coming soon'))
```

**Impact**: No FAQs, no contact info, no support functionality despite being a navigable page.

**Fix**: Implement contact form or at minimum display email/phone, or remove the page.

---

### H6. Suggest Products — no backend submission
**File**: `lib/pages/suggest_products_page.dart:22-33`
```dart
void _submit() {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Thanks for your suggestion!')),  // No API call
  );
  _productController.clear();
  _reasonController.clear();
}
```

**Impact**: Suggestions are never sent anywhere. User input is silently discarded.

**Fix**: Add backend endpoint `/api/suggestions` and POST user input.

---

### H7. Admin credentials hardcoded
**File**: `backend/.env.bak`
```
ADMIN_EMAIL=admin@yourdomain.com
ADMIN_PASSWORD=YourStrongAdminPass#2024
```

**Impact**: Anyone with repo access can log in as admin.

**Fix**: Rotate credentials. Use hashed passwords stored in database. Remove from repo.

---

### H8. No input sanitization in admin pages
**File**: `lib/pages/admin_*.dart` — admin CRUD operations don't validate input locally before sending to API

**Impact**: Empty names, negative prices, excessively long strings can be submitted.

**Fix**: Add `TextFormField` with validators matching backend schema constraints.

---

### H9. Backend lacks request logging
**Files**: `backend/main.py`, `backend/flask_app.py`, `backend/middleware.py`

**Impact**: No audit trail of API requests. Cannot debug issues, track abuse, or monitor admin actions.

**Fix**: Add structured request logging (method, path, user_id, status, latency).

---

### H10. No CSRF protection
**Files**: All backend endpoints

**Impact**: Though primarily mobile (not browser-based), cookie-based auth in Flask backend is vulnerable to CSRF if accessed via web.

**Fix**: Add CSRF tokens for cookie-based auth routes. Use only token-based auth.

---

## 🟡 MEDIUM

### M1. Duplicate supabase client code
**Files**: `backend/supabase_db.py`, `backend/supabase_service.py`

**Impact**: Two files create async supabase clients with identical logic. Creates confusion and maintenance burden.

**Fix**: Consolidate into one factory function.

---

### M2. No backend cart model in SQLAlchemy
**File**: `backend/models.py`

**Impact**: Backend has `/api/cart` endpoints in `resources.py` but no `Cart` or `CartItem` SQLAlchemy model. Likely using raw SQL or supabase — inconsistency with rest of ORM.

**Fix**: Define `Cart` and `CartItem` ORM models or remove unused ORM references.

---

### M3. No `combo_packs` table in SQLAlchemy
**File**: `backend/models.py` vs `backend/migrations/create_combo_packs.sql`

**Impact**: Combo packs exist only in Supabase SQL, not in the ORM. SQLAlchemy sessions cannot interact with them.

**Fix**: Add `ComboPack` and `ComboPackItem` models to `models.py`.

---

### M4. Unused imports
**Files**:
- `lib/widgets/product_grid.dart` — `useProductGrid` unused
- `lib/pages/login_page.dart` — unused theme imports
- `lib/pages/offers_page.dart` — unused import of `cart_model.dart` (check)
- Multiple pages import `AppColors`/`AppTheme` but don't use all referenced constants

**Fix**: Run `dart fix --apply` and remove unused imports.

---

### M5. `wishlistNotifier` never calls SharedPreferences for persistence
**File**: `lib/models/cart_model.dart:85-105`

**Impact**: Wishlist state is lost on app restart. Unlike cart and orders, wishlist has no persistence.

**Fix**: Add `init()`/`_save()` methods matching `OrderNotifier` pattern.

---

### M6. OrderNotifier stores order data locally, not from API
**File**: `lib/models/cart_model.dart:163-172`

**Impact**: After placing an order via API (`payment_page.dart:94`), the local `OrderNotifier.add()` creates a NEW order with a local `ORD` prefix ID, duplicating the server order. Orders list shows local copies, not authoritative server data.

**Fix**: Fetch orders from backend API. Remove local order persistence.

---

### M7. `OrderData` model incompatible with API response
**File**: `lib/models/cart_model.dart:107-139`

**Impact**: `OrderData` uses `CartItem` (with icon/codePoint/color) while API returns `OrderItemResponse` (with product_id/name/price). The local model can't deserialize API responses.

**Fix**: Create separate `ApiOrder` model or align `OrderData` with API schema.

---

### M8. No pull-to-refresh on list pages
**Files**: `orders_page.dart`, `addresses_page.dart`, `payments_page.dart`, `wishlist_page.dart`

**Impact**: Users cannot refresh data without navigating away and back.

**Fix**: Wrap lists in `RefreshIndicator`.

---

### M9. `product_card.dart` manages local `_quantity` state separate from cart
**File**: `lib/widgets/product_card.dart:29`

**Impact**: The stepper in `ProductCard` has its own `_quantity` counter that doesn't sync with `CartNotifier`. After adding to cart, the card shows `_quantity > 0` even on other product list pages.

**Fix**: Derive quantity from `CartNotifier` state, not local widget state.

---

### M10. `CartNotifier.add()` matches by name only, not ID
**File**: `lib/models/cart_model.dart:53`
```dart
final existing = _items.where((i) => i.name == item.name).firstOrNull;
```

**Impact**: Two products with the same name (different categories/vendors) are incorrectly merged.

**Fix**: Match by `productId` instead of `name`.

---

### M11. Payment validation enforces only "COD"/"cod" but backend always returns "COD"
**File**: `backend/schemas.py:490,503,559`
```dart
return "COD";  // Hardcodes return value regardless of input
```

**Impact**: The payment method validator normalizes input and always returns "COD". Future payment methods (UPI, card) will require schema changes.

**Fix**: Store the validated method instead of hardcoding.

---

### M12. No `__init__.py` in backend package
**File**: Missing `backend/__init__.py`

**Impact**: Python may not recognize `backend` as a package. Imports like `from database import SessionLocal` may fail depending on Python path setup.

**Fix**: Add `backend/__init__.py`.

---

## 🟢 LOW

### L1. Redundant rebuilds in `ListenableBuilder`
**Files**: Multiple pages wrap entire widget trees in `ListenableBuilder` listening to `cartNotifier`/`wishlistNotifier`

**Impact**: Entire screen rebuilds on cart change instead of only the affected widgets (e.g., cart badge).

**Fix**: Scope listenable to only the widget that needs rebuilding (e.g., the app bar badge).

---

### L2. `product_card.dart` uses `withValues(alpha:)` (deprecated in newer Flutter)
**File**: `lib/widgets/product_card.dart:84`
```dart
color: Colors.white.withValues(alpha: 0.9),
```

**Fix**: Use `withOpacity(0.9)` or `Color.fromRGBO()`.

---

### L3. Magic color/string constants scattered
**Files**: Multiple pages hardcode `Color(0xFFFF6B00)`, `Color(0xFF1A1A1A)`, `Color(0xFF888888)` etc. instead of using `AppColors` theme constants.

**Fix**: Centralize all color values in `lib/constants/theme.dart`.

---

### L4. No tests — zero test files
**Files**: No `test/` directory, no `test_*.py`, no widget tests, no unit tests.

**Impact**: Regression risk is high. No safety net for refactoring.

**Fix**: Add at minimum unit tests for `schemas.py` validators and widget smoke tests.

---

### L5. `Procfile` and `render.yaml` not reviewed for production readiness
**File**: `backend/Procfile`, `backend/render.yaml`

**Impact**: Deployment configuration may point at the wrong entry point (FastAPI vs Flask).

**Fix**: Verify entry points match chosen backend.

---

### L6. `flutter_map` with OSM tiles — no attribution
**File**: `lib/pages/map_picker_page.dart:155`
```dart
TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png')
```

**Impact**: OSM requires attribution. Missing attribution violates OSM terms of use.

**Fix**: Add attribution overlay "© OpenStreetMap contributors" per OSM guidelines.

---

### L7. `Image.network` without caching
**Files**: Multiple pages load product images via `Image.network()` with no caching strategy.

**Impact**: Every image fetch hits the network. Slow load times, high bandwidth usage.

**Fix**: Use `cached_network_image` package.

---

### L8. `Timer`-based countdown instead of `Ticker` for order status redirect
**File**: `lib/pages/payment_page.dart:263-274`
```dart
void _startTimer() {
  Future.delayed(const Duration(seconds: 1), () {
    if (_seconds > 1) { setState(() => _seconds--); _startTimer(); }
    else { Navigator.pushAndRemoveUntil(...); }
  });
}
```

**Impact**: Recursive `Future.delayed` with `setState` is imprecise and doesn't respect widget lifecycle. If widget is disposed, timer still fires (though `mounted` check mitigates).

**Fix**: Use `Timer.periodic` with proper cancellation in `dispose()`.

---

### L9. Code duplication in address serialization/deserialization
**Files**: `location_picker_sheet.dart:50-63`, `payment_page.dart:52-61`, `map_picker_page.dart:109-114`

**Impact**: Same SharedPreferences key pattern for `gps_*` keys repeated 3×. Changes require updates to all locations.

**Fix**: Create a `DeliveryAddressHelper` class that wraps read/write.

---

### L10. `maps_link` field defined in `AddressResponse` schema but never generated
**File**: `backend/schemas.py:409`
```python
maps_link: Optional[str] = None
```

**Impact**: Field exists in API response but backend never populates it. Frontend may be expecting it.

**Fix**: Generate Google Maps/OSM deep link from lat/lng or remove field.

---

## 🔧 Fix Recommendations (Priority Order)

### Immediate (1-2 days)
1. **Remove `.env.bak` from Git history** — rotate ALL exposed secrets
2. **Remove `badCertificateCallback`** from production code paths
3. **Implement real password reset** — backend endpoint + frontend integration
4. **Set `.env` in `.gitignore`** — prevent future secret leaks

### Short-term (1 week)
5. **Add API key validation** on backend middleware
6. **Consolidate dual backend** — remove Flask or FastAPI
7. **Fix stock race condition** — atomic `UPDATE` with stock guard
8. **Implement proper delivery zone check** — no silent `true` on error
9. **Scope cart to user session** — clear on logout, sync with backend
10. **Add loading/empty/error states** across all list pages

### Medium-term (2-4 weeks)
11. **Make API URL configurable** — `--dart-define` or runtime config
12. **Add backend cart persistence** — server-authoritative cart
13. **Add form validation UI** — show field-level errors from API
14. **Write tests** — unit tests for schemas, widget smoke tests
15. **Add request logging** — structured logs with user context

### Long-term (1-2 months)
16. **Migrate to proper state management** (Riverpod/Bloc) instead of global singletons
17. **Add CI/CD pipeline** — lint, test, security scan on PR
18. **Implement real payment gateway integration** — Razorpay/Stripe
19. **Add rate limiting to ALL endpoints** (currently only login/register)
20. **Performance audit** — image caching, list virtualization, rebuild optimization

---

## File Index

| File | Issues |
|---|---|
| `backend/.env.bak` | 🔴 C1, C7 |
| `backend/main.py` | 🔴 C4, C9; 🟡 M12 |
| `backend/flask_app.py` | 🔴 C9 |
| `backend/middleware.py` | 🔴 C4; 🟡 H9 |
| `backend/schemas.py` | 🟡 M11; 🟢 L10 |
| `backend/models.py` | 🟡 M2, M3 |
| `backend/resources.py` | 🔴 C6 |
| `backend/database.py` | — |
| `backend/supabase_db.py` | 🟡 M1 |
| `backend/supabase_service.py` | 🟡 M1 |
| `backend/auth.py` | — |
| `backend/admin.py` | — |
| `lib/main.dart` | 🔴 C2 |
| `lib/models/cart_model.dart` | 🔴 C7, C8; 🟡 M5, M6, M7, M10 |
| `lib/models/grocery_product.dart` | — |
| `lib/models/combo_pack.dart` | — |
| `lib/services/api_service.dart` | 🔴 C2, C3 |
| `lib/services/admin_api_service.dart` | 🔴 C3 |
| `lib/services/supabase_service.dart` | 🔴 C10 |
| `lib/services/delivery_zone_service.dart` | 🟠 H1 |
| `lib/services/location_service.dart` | — |
| `lib/services/theme_service.dart` | — |
| `lib/services/app_info.dart` | — |
| `lib/constants/theme.dart` | — |
| `lib/pages/login_page.dart` | 🟠 H4; 🟡 M4 |
| `lib/pages/signup_page.dart` | 🟠 H4 |
| `lib/pages/home_page.dart` | — |
| `lib/pages/cart_page.dart` | 🔴 C7 |
| `lib/pages/payment_page.dart` | 🔴 C8; 🟢 L8, L9 |
| `lib/pages/forgot_password_page.dart` | 🔴 C5 |
| `lib/pages/orders_page.dart` | 🟠 H2, H3; 🟡 M8 |
| `lib/pages/product_detail_page.dart` | 🟠 H2 |
| `lib/pages/addresses_page.dart` | 🟠 H2, H3; 🟡 M8 |
| `lib/pages/address_form_page.dart` | — |
| `lib/pages/delivery_location_page.dart` | — |
| `lib/pages/wishlist_page.dart` | 🟠 H3; 🟡 M5, M8 |
| `lib/pages/settings_page.dart` | — |
| `lib/pages/edit_profile_page.dart` | — |
| `lib/pages/payments_page.dart` | 🟠 H3; 🟡 M8 |
| `lib/pages/help_support_page.dart` | 🟠 H5 |
| `lib/pages/suggest_products_page.dart` | 🟠 H6 |
| `lib/pages/offers_page.dart` | — |
| `lib/pages/about_page.dart` | — |
| `lib/pages/pack_detail_sheet.dart` | — |
| `lib/pages/location_picker_sheet.dart` | 🟢 L9 |
| `lib/pages/map_picker_page.dart` | 🟢 L6, L9 |
| `lib/pages/place_search_page.dart` | — |
| `lib/pages/admin_*.dart` | 🟠 H8 |
| `lib/widgets/product_card.dart` | 🟡 M9; 🟢 L2 |
| `lib/widgets/product_grid.dart` | 🟡 M4 |
| `supabase_setup.sql` | — (has atomic fix) |
| `backend/migrations/*.sql` | — |
