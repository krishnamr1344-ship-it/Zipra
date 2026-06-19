-- Migration: Add Razorpay columns to payments table
-- Run: psql $DATABASE_URL -f add_razorpay_to_payments.sql

ALTER TABLE payments ADD COLUMN IF NOT EXISTS gateway_order_id VARCHAR(100);
CREATE INDEX IF NOT EXISTS ix_payments_gateway_order_id ON payments (gateway_order_id);

ALTER TABLE payments ADD COLUMN IF NOT EXISTS gateway_payment_id VARCHAR(100);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS gateway_signature VARCHAR(500);
ALTER TABLE payments ADD COLUMN IF NOT EXISTS failure_reason VARCHAR(1000);

-- Drop unique constraint on order_id (allows multiple payment attempts per order)
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_order_id_key;

-- Partial unique index: only one successful payment per gateway_payment_id
CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_gateway_payment_id
ON payments (gateway_payment_id)
WHERE gateway_payment_id IS NOT NULL;
