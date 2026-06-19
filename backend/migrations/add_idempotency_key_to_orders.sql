-- Add idempotency_key column to orders table for duplicate prevention
ALTER TABLE orders
ADD COLUMN idempotency_key VARCHAR(64) UNIQUE;

CREATE INDEX IF NOT EXISTS ix_orders_idempotency_key ON orders (idempotency_key);
