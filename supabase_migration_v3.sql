-- ============================================
-- SUPABASE MIGRATION v3: Missing Tables + Wishlist
-- Run this in Supabase SQL Editor after supabase_setup.sql
-- Adds: wishlist_items, product_suggestions, combo_packs, combo_pack_items, delivery_zones
-- ============================================

-- ============================================
-- WISHLIST ITEMS (new table — not in v2)
-- ============================================
CREATE TABLE IF NOT EXISTS wishlist_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) NOT NULL,
    product_id UUID REFERENCES products(id) NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, product_id)
);

ALTER TABLE wishlist_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "wishlist_items_own_select"
    ON wishlist_items FOR SELECT
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "wishlist_items_own_insert"
    ON wishlist_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wishlist_items_own_update"
    ON wishlist_items FOR UPDATE
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "wishlist_items_own_delete"
    ON wishlist_items FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY "wishlist_items_service_select"
    ON wishlist_items FOR SELECT
    USING (auth.role() = 'service_role');

CREATE POLICY "wishlist_items_service_insert"
    ON wishlist_items FOR INSERT
    WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "wishlist_items_service_update"
    ON wishlist_items FOR UPDATE
    USING (auth.role() = 'service_role');

CREATE POLICY "wishlist_items_service_delete"
    ON wishlist_items FOR DELETE
    USING (auth.role() = 'service_role');

-- ============================================
-- PRODUCT SUGGESTIONS (missing from v2)
-- ============================================
CREATE TABLE IF NOT EXISTS product_suggestions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    product_name VARCHAR(200) NOT NULL,
    reason VARCHAR(2000),
    status VARCHAR(20) DEFAULT 'pending' NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE product_suggestions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "product_suggestions_own_insert"
    ON product_suggestions FOR INSERT
    WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

CREATE POLICY "product_suggestions_own_select"
    ON product_suggestions FOR SELECT
    USING (auth.uid() = user_id AND is_deleted = FALSE);

CREATE POLICY "product_suggestions_service_all"
    ON product_suggestions FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================
-- COMBO PACKS (missing from v2)
-- ============================================
CREATE TABLE IF NOT EXISTS combo_packs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    image_url VARCHAR(500),
    total_price NUMERIC(10,2) NOT NULL,
    discount_label VARCHAR(100),
    savings_text VARCHAR(200),
    is_enabled BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE combo_packs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "combo_packs_public_read"
    ON combo_packs FOR SELECT
    USING (is_deleted = FALSE AND is_enabled = TRUE);

CREATE POLICY "combo_packs_service_all"
    ON combo_packs FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================
-- COMBO PACK ITEMS (missing from v2)
-- ============================================
CREATE TABLE IF NOT EXISTS combo_pack_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pack_id UUID REFERENCES combo_packs(id) ON DELETE CASCADE NOT NULL,
    product_id UUID REFERENCES products(id) NOT NULL,
    quantity INTEGER DEFAULT 1 NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_combo_pack_items_pack ON combo_pack_items(pack_id);

ALTER TABLE combo_pack_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "combo_pack_items_public_read"
    ON combo_pack_items FOR SELECT
    USING (is_deleted = FALSE);

CREATE POLICY "combo_pack_items_service_all"
    ON combo_pack_items FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================
-- DELIVERY ZONES (missing from v2)
-- ============================================
CREATE TABLE IF NOT EXISTS delivery_zones (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    zone_name VARCHAR(100) NOT NULL,
    geojson_data TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    is_deleted BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE delivery_zones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "delivery_zones_service_all"
    ON delivery_zones FOR ALL
    USING (auth.role() = 'service_role');

-- ============================================
-- ADDRESSES: Add missing GPS columns if not exist
-- (Safe to run — ALTER TABLE ADD IF NOT EXISTS)
-- ============================================
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS address_type VARCHAR(20) DEFAULT 'Home';
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS house_number VARCHAR(50);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS floor_number VARCHAR(50);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS landmark VARCHAR(255);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS maps_link VARCHAR(500);
