# Zipra Delivery App — Full System Audit Report

**Date:** 2026-06-14
**Scope:** All backend Python files + all frontend Dart files + API integration
**Commit:** `8d88cb7` (plus 28 uncommitted files with 201 insertions / 82 deletions from automated fix attempts)

---

## 🔴 CRITICAL (5)

### C1. `X-API-Key` header never sent from frontend
- **Files:** `lib/services/api_service.dart:159` vs `backend/main.py:82-91`
- The frontend never sends an `X-API-Key` header. If the `API_KEY` env var is set in production, ALL authenticated requests to non-public paths will fail with 403. The backend middleware only checks the API key if the env var is non-empty, so this is currently not failing — but it's a ticking bomb for production.

### C2. All prices truncated from float to int (data loss)
- **Files:** 6+ locations — `cart_model.dart:47`, `home_page.dart:188`, `wishlist_page.dart:51,252`, `orders_page.dart:85,117`
- All use `.toInt()` which truncates decimals. A product priced at ₹4.50 in the backend displays as ₹4. `total_amount` of ₹1499.00 → ₹1499 (works for whole rupees, but any fractional price loses data).

### C3. 422 validation errors invisible to user
- **File:** `lib/services/api_service.dart:69`
- FastAPI returns 422 errors as `{"detail": [{"loc": [...], "msg": "...", "type": "..."}]}` (a list of objects). Frontend casts `map['detail'] as String?` which throws `TypeError` on the list, caught silently, returning `null`. User sees generic "Request failed (422)" instead of "Password must have 8+ characters".

### C4. No JWT refresh mechanism — 30-min forced re-login
- **File:** `backend/auth.py:27` — `JWT_EXPIRY_MINUTES=30`
- No `/api/auth/refresh` endpoint exists. After 30 minutes, every 401-stale API call fails. Only `getOrders()` (api_service.dart:565-568) clears the token on 401; all other endpoints leave the stale token in storage, causing repeated silent failures.

### C5. Duplicated 200+ line Chennai locality mapping — never synced
- **Files:** `backend/resources.py:56-258` and `lib/services/api_service.dart:216-418`
- The full Chennai ward-to-locality mapping is duplicated verbatim across Python and Dart. Backend proxy endpoints `/api/places/reverse` and `/api/places/search` exist but are never called — the frontend calls Nominatim directly with its own copy. Any edit to one copy breaks the other.

---

## 🟠 HIGH (12)

### H1. No logging anywhere — all errors silently swallowed
- **Files:** All backend Python files
- No `import logging` or logger configuration exists. All `except Exception: pass` / `except Exception: continue` blocks across `resources.py`, `admin.py`, `auth.py`, `middleware.py`, `main.py` make production debugging impossible.

### H2. Email takeover via profile update (no uniqueness check)
- **File:** `backend/auth.py:209`
- `update_profile` sets `user.email = body.email.strip()` with no check that the new email isn't already taken. DB UNIQUE constraint catches it at commit → unhandled `IntegrityError` → 500 Internal Server Error.

### H3. Payment status uses "completed" instead of schema-valid "success"
- **File:** `backend/resources.py:1215` sets `payment.status = "completed"` but `schemas.py:37` defines `VALID_PAYMENT_STATUSES = {"pending", "success", "failed"}`. The status `"completed"` is not in the valid set. Frontend checking against these constants would never see "completed".

### H4. Duplicate public path lists (main.py:52 vs middleware.py:33)
- Both files maintain nearly identical lists of paths that bypass auth/API-key checks. Adding a new endpoint to one without the other causes 403 bypass or false rejections.

### H5. `api_service.dart` does not clear token on 401 for most endpoints
- Only `getOrders()` (api_service.dart:565-568) checks for 401 and calls `_clearToken()`. `getCart()`, `getWishlist()`, `getAddresses()`, `createAddress()`, `updateCartItem()`, `addToWishlist()`, etc. all throw a generic error on 401 without clearing the stale token.

### H6. Combo pack creation flushes before validation — dirty session
- **File:** `backend/admin.py:488-493`
- `db.add(pack)` + `db.flush()` sends the insert to DB. Iterating items then queries products — if a product is not found, `HTTPException` is raised but the flushed data remains in the session. Next request using that pooled session sees inconsistent state.

### H7. Profile image field always null — dead code on frontend
- **File:** `lib/pages/home_page.dart:419,1105` reads `_user?['profile_image']` — backend never returns this field in any user response (`id`, `name`, `email`, `role`, `phone` only). The avatar initial-letter fallback is always used.

### H8. Frontend uses Nominatim directly instead of backend proxy
- **Files:** `lib/services/api_service.dart:478-534` — calls `https://nominatim.openstreetmap.org/` directly
- Backend at `/api/places/reverse` and `/api/places/search` provides a proxy with rate limiting and area extraction. Frontend duplicates all this logic client-side (200+ lines) and bypasses backend entirely.

### H9. Login loses stored phone number
- **File:** `lib/services/api_service.dart:96` — `await _saveUserLocally(..., '', ...)` passes hardcoded empty string for phone. `register()` correctly saves phone on line 84. After logging out and back in, phone is lost.

### H10. Login saves location every time unnecessarily
- **File:** `lib/pages/login_page.dart:70` — `LocationService().saveLocationToServer(...)` called on every login, overwriting previously stored location. Should only save on location change.

### H11. `forgotPassword` generates code but never emails it
- **File:** `backend/auth.py:220-249`
- Generates a 6-digit code and stores its hash in DB but has zero email-sending logic. The feature is a dead end for users.

### H12. Rediscovered: Guest users can still see protected tabs briefly
- **File:** `lib/pages/home_page.dart:320-328`
- If user is not logged in taps Cart/Account → pushes `LoginPage`. After login (or cancel), tab index switch fires even on cancel, showing empty protected tab.

---

## 🟡 MEDIUM (15)

### M1. CSRF middleware silently catches all exceptions
- **File:** `backend/main.py:122-123` — `except Exception: pass` — if `urlparse(origin)` fails, CSRF check is bypassed silently.

### M2. Old admin role preserved on soft-delete reactivation
- **File:** `backend/auth.py:111` — registers `existing.role` when reactivating soft-deleted user. An attacker registering an old admin's email gains admin privileges.

### M3. Missing FK indexes on 5 frequently queried tables
- **File:** `backend/models.py` — `CartItem.product_id`, `OrderItem.product_id`, `Order.address_id`, `ComboPackItem.product_id`, `WishlistItem.product_id` — no indexes on foreign keys. Sequential scans under load.

### M4. No spatial index on DeliveryZone.geojson_data
- **File:** `backend/models.py:274-282` — stored as `Text`, not PostGIS GEOMETRY. `check_delivery_zone` iterates ALL zones and checks `polygon.contains(point)` O(n) per request.

### M5. Global singleton notifiers (no DI, no testability)
- **File:** `lib/models/cart_model.dart:173,241` — `final cartNotifier = CartNotifier()`, `final wishlistNotifier = WishlistNotifier()`. Global singletons throughout the app lifecycle.

### M6. WishlistPage._remove() followed by _load() creates race
- **File:** `lib/pages/wishlist_page.dart:42-44` — calls `wishlistNotifier.remove(id)` (optimistic rollback) then immediately `_load()` (re-fetch). If API remove fails, rollback restores item, then `_load()` overwrites with fresh data. If re-fetch also fails, item stays removed despite server failure.

### M7. Order status navigation timer not cancelled on user action
- **File:** `lib/pages/payment_page.dart:360-366` — 20-second auto-redirect timer to HomePage fires even if user already navigated to OrdersPage via "View My Orders" button. Timer not cancelled on button press.

### M8. Combo pack response IndexError on empty images
- **File:** `backend/admin.py:452`, `backend/resources.py:1277` — `prod.images[0].image_url if prod and prod.images else None` — correct guard, but fragile. If `prod.images` is an empty list, `prod.images` is truthy and `[0]` raises `IndexError`.

### M9. `_check_payment_expiry` is dead code
- **File:** `backend/resources.py:1175-1183` — defined but never called anywhere.

### M10. `_appEntry._checkTokenOnResume` does nothing useful
- **File:** `lib/main.dart:133-139` — checks token exists, prints debug message. Does not validate expiry, refresh, or redirect. Dead code.

### M11. Cart/wishlist state accessed before load completes
- **File:** `lib/pages/home_page.dart:908-909` — `cartMap`/`favMap` computed in `build()` but `cartNotifier.load()`/`wishlistNotifier.load()` are fire-and-forget in `initState`. First frame sees empty state.

### M12. Pincode validation is weak
- **File:** `lib/pages/delivery_location_page.dart:98`, `lib/pages/address_form_page.dart:51` — only checks `length < 5`, no numeric check.

### M13. `_handleListResponse` rejects non-200 status codes
- **File:** `lib/services/api_service.dart:53` — `if (res.statusCode != 200)` rejects 201 Created, 204 No Content, etc. Currently not triggered but is a latent bug.

### M14. No connection pooling limits or statement timeout
- **File:** `backend/database.py:17` — default pool size of 5, no overflow, no `pool_timeout`. Under load, requests queue up. No statement timeout means slow queries hang indefinitely.

### M15. `API_KEY` validation bypassed if env var is missing
- **File:** `backend/main.py:83` — `if API_KEY and ...` — if `API_KEY` is `None`/empty, entire API key check is bypassed. `.env.example` does not even include `API_KEY`.

---

## 🟢 LOW (20+)

### L1. No URL validation for image/link fields
- `CategoryCreate.image`, `ProductCreate.images[]`, `NotificationCreate.image_url`/`link`, `ComboPackCreate.image_url` — all accept any string.

### L2. 4 models missing `updated_at` audit column
- `ProductImage`, `ComboPackItem`, `PasswordResetCode`, `WishlistItem` — have `created_at` but no `updated_at`. All other models have both.

### L3. Redundant `httpx` imports inside functions
- `backend/resources.py:720,757` — `import httpx` inside `reverse_geocode` and `search_places` despite top-level import at line 19.

### L4. `maps_link` generation duplicated ~8 times
- Pattern `f"https://www.google.com/maps?q={lat},{lng}"` written in `resources.py` and `admin.py` across ~8 functions. Should be a shared helper.

### L5. `_validate_uuid` duplicated
- `backend/admin.py:44-49` and `backend/resources.py:340-345` — same function.

### L6. Smart chips have no functional effect
- `lib/pages/home_page.dart:654-678` — `_selectedChip` is toggleable via `setState` but never used to filter products.

### L7. Filter/tune button does nothing
- `lib/pages/home_page.dart:629` — `onPressed: () {}`.

### L8. Search field never filters
- `lib/pages/home_page.dart:599` — `onChanged: (_) => setState(() {})` — triggers rebuilds but search text never used.

### L9. "HOME" label hardcoded
- `lib/pages/home_page.dart:494` — always shows "HOME" regardless of actual address type.

### L10. Discount badge shows "0% off" or "null% off"
- `lib/widgets/product_card.dart:84-95` — guard prevents null, but `discount_percent=0` still shows "0% off".

### L11. Non-functional Dark Mode switch
- `lib/pages/settings_page.dart:36` — `onChanged: null`, toggles visually but does nothing.

### L12. `Responsive` utility class never initialized — crash if called
- `lib/constants/responsive.dart` — `init()` and `initResponsive()` extension never invoked. Accessing `Responsive.w()`/`h()` throws `LateInitializationError`.

### L13. `address_form_page.dart` dead parameter `isNew`
- `lib/pages/address_form_page.dart:8` — `isNew` declared but redundant with `initialData == null` check.

### L14. `CheckUpdatesPage` deprecated `canLaunchUrl`
- `lib/pages/check_updates_page.dart:70` — deprecated in newer url_launcher.

### L15. Version comparison strips pre-release/build tags
- `lib/pages/check_updates_page.dart:56-66` — `_compareVersions` only compares 3 numeric segments. "1.2.3-beta" and "1.2.3+1" both stripped to "1.2.3".

### L16. `success_modal.dart` `onDismiss` only fires on auto-dismiss
- `lib/widgets/success_modal.dart:92` — user tap on buttons pops dialog without calling `onDismiss`. Only auto-dismiss (3s timer) fires it. Possibly intentional but undocumented.

### L17. Cart update with `quantity=0` returns different response shape
- `backend/resources.py:941-945` — returns `{"detail": "Item removed from cart"}` instead of `CartItemResponse`, violating OpenAPI contract.

### L18. `AddressCreate.address_line2` validator inconsistent strip
- `backend/schemas.py:294-299` — returns `v` (original) instead of `v.strip()` for empty string. Minor consistency issue.

### L19. No email format validation on forgot password
- `lib/pages/forgot_password_page.dart:31`, `backend/schemas.py:776-785` — only checks non-empty, no regex.

### L20. `_seed_data` runs on every startup with race risk
- `backend/main.py:317-319` — on first startup with multiple instances, both may try to create admin/categories concurrently. UNIQUE constraint prevents duplicates but error is unhandled.

---

## Summary Statistics

| Severity | Count |
|---|:---:|
| 🔴 CRITICAL | 5 |
| 🟠 HIGH | 12 |
| 🟡 MEDIUM | 15 |
| 🟢 LOW | 20 |

## Action Items Recommended

**Must fix before production:**
1. Fix `X-API-Key` header — send it from frontend or remove from backend middleware
2. Fix price truncation — use `.toDouble()` or parse as `double` everywhere
3. Fix 422 error parsing — handle list-of-objects format
4. Add token refresh endpoint (or increase TTL significantly)
5. Route Nominatim calls through backend proxy — remove duplicated Dart mapping
6. Handle 401 token clearance globally (interceptor pattern)
7. Fix email uniqueness check in `update_profile`
8. Fix payment status constant ("completed" → "success")
7. Single-source public paths list

**Should fix soon:**
1. Add logging to all backend files
2. Add missing FK indexes
3. Add spatial index to DeliveryZone
4. Fix `completed` → `success` in payment status
5. Add email format validation to forgot password
6. Fix login phone save
7. Connect Nominatim frontend calls through backend proxy
8. Handle dirty session on combo pack validation failure
9. Add stale-role guard on soft-delete reactivation
10. Cancel timer on OrdersPage navigation

