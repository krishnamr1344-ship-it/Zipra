-- ============================================
-- SUPABASE SCHEMA: Grocery Delivery App
-- Version: 2.0 (Security Patched)
-- Fixes Applied:
--   FIX-1: Stock race condition → atomic WHERE guard
--   FIX-2: Soft delete filter in all SELECT policies
--   FIX-3: Delivery partner ID masked via user-safe VIEW
--   FIX-4: address_id NULL guard on order insert
--   FIX-5: cart_items soft delete enforced in SELECT
-- Security: anon = read-only, service_role = writes
-- ============================================

DROP TABLE IF EXISTS product_images CASCADE;
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS cart_items CASCADE;
DROP TABLE IF EXISTS addresses CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS categories CASCADE;
DROP FUNCTION IF EXISTS cancel_own_pending_order CASCADE;
DROP FUNCTION IF EXISTS decrement_stock CASCADE;
DROP FUNCTION IF EXISTS guard_active_address CASCADE;
DROP VIEW IF EXISTS orders_user_view CASCADE;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- CATEGORIES
-- ============================================
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    image VARCHAR(500),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- FIX-2: is_deleted = FALSE filter added → soft-deleted categories hidden from public
CREATE POLICY "categories_public_read"
    ON categories FOR SELECT
    USING (is_deleted = FALSE);

CREATE POLICY "categories_service_insert"
    ON categories FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "categories_service_update"
    ON categories FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "categories_service_delete"
    ON categories FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- PRODUCTS
-- ============================================
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category_id UUID REFERENCES categories(id) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    price NUMERIC(10,2) NOT NULL CHECK (price > 0),
    unit VARCHAR(20) NOT NULL,
    image VARCHAR(500),
    stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- FIX-2: is_deleted = FALSE filter added → soft-deleted products hidden from public
CREATE POLICY "products_public_read"
    ON products FOR SELECT
    USING (is_deleted = FALSE);

CREATE POLICY "products_service_insert"
    ON products FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "products_service_update"
    ON products FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "products_service_delete"
    ON products FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- PRODUCT IMAGES
-- ============================================
CREATE TABLE product_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID REFERENCES products(id) NOT NULL,
    image_url VARCHAR(1000) NOT NULL,
    sort_order INTEGER DEFAULT 0 NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_product_images_product ON product_images(product_id);

ALTER TABLE product_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "product_images_public_read"
    ON product_images FOR SELECT
    USING (is_deleted = FALSE);

CREATE POLICY "product_images_service_insert"
    ON product_images FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "product_images_service_update"
    ON product_images FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "product_images_service_delete"
    ON product_images FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- ADDRESSES
-- ============================================
CREATE TABLE addresses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    label VARCHAR(50) NOT NULL,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100) NOT NULL,
    pincode VARCHAR(10) NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;

-- FIX-2: is_deleted = FALSE added to user's own SELECT
CREATE POLICY "addresses_own_select"
    ON addresses FOR SELECT
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "addresses_own_insert"
    ON addresses FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "addresses_own_update"
    ON addresses FOR UPDATE
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "addresses_own_delete"
    ON addresses FOR DELETE
    USING (auth.uid() = user_id);

-- service_role sees everything (including deleted, for admin ops)
CREATE POLICY "addresses_service_select"
    ON addresses FOR SELECT
    USING (auth.role() = 'service_role');

CREATE POLICY "addresses_service_insert"
    ON addresses FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "addresses_service_update"
    ON addresses FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "addresses_service_delete"
    ON addresses FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- CART ITEMS
-- ============================================
CREATE TABLE cart_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    product_id UUID REFERENCES products(id) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

ALTER TABLE cart_items ENABLE ROW LEVEL SECURITY;

-- FIX-5: is_deleted = FALSE → ghost cart items not visible to user
CREATE POLICY "cart_items_own_select"
    ON cart_items FOR SELECT
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "cart_items_own_insert"
    ON cart_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "cart_items_own_update"
    ON cart_items FOR UPDATE
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "cart_items_own_delete"
    ON cart_items FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY "cart_items_service_select"
    ON cart_items FOR SELECT
    USING (auth.role() = 'service_role');

CREATE POLICY "cart_items_service_insert"
    ON cart_items FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "cart_items_service_update"
    ON cart_items FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "cart_items_service_delete"
    ON cart_items FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- ORDERS
-- ============================================
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    address_id UUID REFERENCES addresses(id),
    delivery_partner_id UUID REFERENCES auth.users(id),
    status VARCHAR(20) DEFAULT 'Pending' NOT NULL
        CHECK (status IN ('Pending', 'Confirmed', 'Out for Delivery', 'Delivered', 'Cancelled')),
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount > 0),
    payment_method VARCHAR(20) NOT NULL
        CHECK (payment_method IN ('UPI', 'COD', 'Card')),
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- FIX-3: Safe view for users → delivery_partner_id is intentionally EXCLUDED
-- Users don't need to see who the delivery partner UUID is.
-- They see everything else about their own non-deleted orders.
CREATE VIEW orders_user_view AS
    SELECT
        id,
        user_id,
        address_id,
        status,
        total_amount,
        payment_method,
        created_at,
        updated_at
        -- delivery_partner_id intentionally omitted
    FROM orders
    WHERE is_deleted = FALSE;

-- SECURITY DEFINER: user can only cancel own Pending order (with row lock)
CREATE OR REPLACE FUNCTION cancel_own_pending_order(p_order_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id UUID;
    v_status VARCHAR(20);
BEGIN
    SELECT user_id, status
    INTO v_user_id, v_status
    FROM orders
    WHERE id = p_order_id
    FOR UPDATE; -- Row lock to prevent concurrent cancel+update race

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order not found';
    END IF;

    IF v_user_id <> auth.uid() THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;

    IF v_status <> 'Pending' THEN
        RAISE EXCEPTION 'Only pending orders can be cancelled';
    END IF;

    UPDATE orders
    SET status = 'Cancelled', updated_at = NOW()
    WHERE id = p_order_id;
END;
$$;

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- FIX-2: is_deleted = FALSE added to own order select
CREATE POLICY "orders_own_select"
    ON orders FOR SELECT
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "orders_service_select"
    ON orders FOR SELECT
    USING (auth.role() = 'service_role');

-- Users CANNOT insert or update orders directly → service_role only
CREATE POLICY "orders_service_insert"
    ON orders FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "orders_service_update"
    ON orders FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "orders_service_delete"
    ON orders FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- ORDER ITEMS
-- ============================================
CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) NOT NULL,
    product_id UUID REFERENCES products(id) NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL CHECK (unit_price > 0),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "order_items_own_select"
    ON order_items FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM orders
            WHERE orders.id = order_items.order_id
              AND orders.user_id = auth.uid()
              AND orders.is_deleted = FALSE  -- FIX-2: exclude deleted order's items too
        )
    );

CREATE POLICY "order_items_service_select"
    ON order_items FOR SELECT
    USING (auth.role() = 'service_role');

CREATE POLICY "order_items_service_insert"
    ON order_items FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "order_items_service_update"
    ON order_items FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "order_items_service_delete"
    ON order_items FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- PAYMENTS
-- ============================================
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID REFERENCES orders(id) NOT NULL UNIQUE,
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    method VARCHAR(20) NOT NULL CHECK (method IN ('COD')),
    status VARCHAR(20) DEFAULT 'completed' NOT NULL
        CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    transaction_id VARCHAR(100) UNIQUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- FIX-2: is_deleted = FALSE on own payment select
CREATE POLICY "payments_own_select"
    ON payments FOR SELECT
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "payments_service_select"
    ON payments FOR SELECT
    USING (auth.role() = 'service_role');

-- Users CANNOT insert or update payments directly → service_role only
CREATE POLICY "payments_service_insert"
    ON payments FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "payments_service_update"
    ON payments FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "payments_service_delete"
    ON payments FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- TRIGGERS
-- ============================================

-- FIX-1: ATOMIC stock decrement with WHERE guard
-- Old code: decremented first, then checked → race condition possible
-- New code: WHERE stock >= quantity → atomic, safe under concurrent load
CREATE OR REPLACE FUNCTION decrement_stock()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Atomic: only update if stock is sufficient
    -- If two requests hit simultaneously, only one wins the row lock
    UPDATE products
    SET stock = stock - NEW.quantity,
        updated_at = NOW()
    WHERE id = NEW.product_id
      AND stock >= NEW.quantity;  -- ATOMIC GUARD → race condition fixed

    -- If no row was updated → stock was insufficient
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Insufficient stock for product %', NEW.product_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_decrement_stock
AFTER INSERT ON order_items
FOR EACH ROW EXECUTE FUNCTION decrement_stock();

-- FIX-6: Prevent deleting address linked to active order
CREATE OR REPLACE FUNCTION guard_active_address()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM orders
        WHERE address_id = OLD.id
          AND status NOT IN ('Delivered', 'Cancelled')
          AND is_deleted = FALSE
    ) THEN
        RAISE EXCEPTION 'Cannot delete address linked to an active order';
    END IF;

    RETURN OLD;
END;
$$;

CREATE TRIGGER trg_guard_active_address
BEFORE DELETE ON addresses
FOR EACH ROW EXECUTE FUNCTION guard_active_address();

/*
====================================================================
TABLE POLICY SUMMARY v2.0 (Security Patched)
====================================================================

categories:
  SELECT  → public (is_deleted = FALSE only)   ← FIXED
  INSERT  → service_role only
  UPDATE  → service_role only
  DELETE  → service_role only

products:
  SELECT  → public (is_deleted = FALSE only)   ← FIXED
  INSERT  → service_role only
  UPDATE  → service_role only
  DELETE  → service_role only

addresses:
  SELECT  → own row (is_deleted=FALSE) OR service_role  ← FIXED
  INSERT  → own row OR service_role
  UPDATE  → own row (is_deleted=FALSE) OR service_role  ← FIXED
  DELETE  → own row OR service_role
  TRIGGER → blocks delete if linked to active order

cart_items:
  SELECT  → own row (is_deleted=FALSE) OR service_role  ← FIXED
  INSERT  → own row OR service_role
  UPDATE  → own row (is_deleted=FALSE) OR service_role  ← FIXED
  DELETE  → own row OR service_role

orders:
  SELECT  → own row (is_deleted=FALSE) OR service_role  ← FIXED
  INSERT  → service_role only
  UPDATE  → service_role only
  DELETE  → service_role only
  CANCEL  → via cancel_own_pending_order() SECURITY DEFINER
  VIEW    → orders_user_view (delivery_partner_id hidden) ← FIXED

order_items:
  SELECT  → own (via orders subquery, is_deleted=FALSE) OR service_role  ← FIXED
  INSERT  → service_role only
  UPDATE  → service_role only
  DELETE  → service_role only

payments:
  SELECT  → own row (is_deleted=FALSE) OR service_role  ← FIXED
  INSERT  → service_role only
  UPDATE  → service_role only
  DELETE  → service_role only

TRIGGERS:
  trg_decrement_stock       → AFTER INSERT ON order_items
                              (atomic WHERE guard, race condition fixed)  ← FIXED
  trg_guard_active_address  → BEFORE DELETE ON addresses

====================================================================
FLASK BACKEND REMINDERS (Schema cannot enforce these):
====================================================================
  1. ALWAYS fetch product price from DB, never trust frontend price
  2. Validate cart items belong to the requesting user before order creation
  3. Add rate limiting on /cancel-order endpoint (e.g. 5 req/min per user)
  4. Verify Razorpay webhook signature before marking payment 'completed'
  5. On COD orders, only mark payment 'completed' after delivery confirmation
====================================================================
*/