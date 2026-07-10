CREATE TABLE IF NOT EXISTS delivery_fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    min_order_amount NUMERIC(10,2) DEFAULT 0.00 NOT NULL,
    max_order_amount NUMERIC(10,2),
    fee NUMERIC(10,2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE NOT NULL,
    is_deleted BOOLEAN DEFAULT FALSE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW() NOT NULL
);
