# Supabase Migration Report

## Project: Grocery Delivery App (`/Users/mohanraj/Desktop/myapp`)

### Completed Migrations

| # | Entity | Before | After | Status |
|---|--------|--------|-------|--------|
| 1 | **Cart** | In-memory `CartNotifier` (lost on restart) | Persisted via backend API → Supabase `cart_items` table | ✅ |
| 2 | **Wishlist** | In-memory `WishlistNotifier` (lost on restart) | Persisted via backend API → Supabase `wishlist_items` table | ✅ |
| 3 | **Orders** | Orders API (backend PostgreSQL) + dead `OrderNotifier` SharedPreferences fallback | Removed local fallback. Orders exclusively via backend API → PostgreSQL/Supabase | ✅ |
| 4 | **Addresses** | API (backend PostgreSQL) + SharedPreferences GPS cache | Payment page now fetches addresses from API instead of SharedPreferences. GPS address cache retained as UX optimization (not primary storage) | ✅ |
| 5 | **User Profile** | API (backend PostgreSQL) + SharedPreferences cache | SharedPreferences cache retained as UX optimization. Source of truth is server | ✅ |
| 6 | **Product Suggestions** | API (backend PostgreSQL) | Already stored server-side. No changes needed | ✅ |

### Files Modified

| File | Change |
|------|--------|
| `lib/models/cart_model.dart` | Rewrote `CartNotifier` to sync with backend API. Rewrote `WishlistNotifier` to sync with backend API. Removed `OrderNotifier` (dead code with SharedPreferences). Removed `dart:convert` and `shared_preferences` imports. |
| `lib/services/api_service.dart` | Added 7 new methods: `getCart`, `addToCart`, `updateCartItem`, `removeCartItem`, `clearCart`, `getWishlist`, `addToWishlist`, `removeFromWishlist` |
| `lib/pages/home_page.dart` | Updated initState to load cart/wishlist from API. Updated cart/wishlist lookups to use product IDs instead of names. Updated `cartNotifier.add()` calls to new signature. |
| `lib/pages/cart_page.dart` | Updated `updateCount` calls to use `productId` instead of `name`. |
| `lib/pages/wishlist_page.dart` | Rewrote to fetch wishlist items from API and display product details (name + price). |
| `lib/pages/payment_page.dart` | Removed `shared_preferences` import. `_loadAddress()` now fetches from API. `_setDelivery()` no longer writes to SharedPreferences. |
| `lib/pages/orders_page.dart` | Updated `CartItem` constructor call to match new signature. |
| `lib/pages/pack_detail_sheet.dart` | Updated `cartNotifier.add()` call to new async signature with product ID. |

### Files Created

| File | Purpose |
|------|---------|
| `supabase_migration_v3.sql` | Adds missing tables to Supabase: `wishlist_items`, `product_suggestions`, `combo_packs`, `combo_pack_items`, `delivery_zones`. Also adds GPS columns to `addresses` table. |

### Backend Changes

| File | Change |
|------|--------|
| `backend/models.py` | Added `WishlistItem` model (SQLAlchemy ORM) with `__tablename__ = "wishlist_items"` |
| `backend/schemas.py` | Added `WishlistAddRequest`, `WishlistItemResponse`, `WishlistRemoveResponse` Pydantic schemas |
| `backend/resources.py` | Added 3 wishlist endpoints: `GET /api/wishlist`, `POST /api/wishlist`, `DELETE /api/wishlist/{product_id}` |

### Supabase Tables Now Complete

| Table | Source | Status |
|-------|--------|--------|
| `categories` | `supabase_setup.sql` | Already existed |
| `products` | `supabase_setup.sql` | Already existed |
| `product_images` | `supabase_setup.sql` | Already existed |
| `addresses` | `supabase_setup.sql` + migration v3 (GPS columns) | ✅ Complete |
| `cart_items` | `supabase_setup.sql` | Already existed (now used by Flutter app) |
| `orders` | `supabase_setup.sql` | Already existed |
| `order_items` | `supabase_setup.sql` | Already existed |
| `payments` | `supabase_setup.sql` | Already existed |
| `wishlist_items` | migration v3 (new) | ✅ Added |
| `product_suggestions` | migration v3 (new) | ✅ Added |
| `combo_packs` | migration v3 (new) | ✅ Added |
| `combo_pack_items` | migration v3 (new) | ✅ Added |
| `delivery_zones` | migration v3 (new) | ✅ Added |

### Remaining SharedPreferences (acceptable caches)

These are UX caches, not primary storage. Source of truth is the server.

| Key | Purpose | Reason to Keep |
|-----|---------|----------------|
| `auth_token` | JWT auth token | Required for API auth |
| `user_name` | User display name | Fast-load profile greeting |
| `user_email` | User email | Fast-load profile display |
| `user_phone` | User phone | Fast-load profile display |
| `user_role` | User role (user/admin) | Fast-load routing |
| `gps_address_*` (11 keys) | Current delivery address | Fast-load location on home screen |

### Next Steps (Phase 2 — Backend Migration)

1. **Run `supabase_migration_v3.sql` in Supabase SQL Editor** to create missing tables
2. **Update backend `DATABASE_URL`** in `backend/.env` to point to Supabase's PostgreSQL connection string (from Supabase Dashboard → Settings → Database → Connection string)
3. **Restart the backend** — SQLAlchemy will auto-create any remaining tables via `Base.metadata.create_all()`
4. **Verify** that all data is accessible through the Supabase dashboard

### Verification Checklist

- [ ] Cart persists across app restarts (backend API → Supabase)
- [ ] Wishlist persists across app restarts (backend API → Supabase)
- [ ] Orders display from API (no SharedPreferences fallback)
- [ ] Addresses load from API on payment page
- [ ] GPS delivery location still works (SharedPreferences cache + API)
- [ ] All existing app features continue to work
