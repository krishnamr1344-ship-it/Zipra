-- Rollback: Remove Razorpay columns from payments table
-- Run: psql $DATABASE_URL -f rollback_razorpay.sql

DROP INDEX IF EXISTS uq_payments_gateway_payment_id;
DROP INDEX IF EXISTS ix_payments_gateway_order_id;

ALTER TABLE payments DROP COLUMN IF EXISTS gateway_order_id;
ALTER TABLE payments DROP COLUMN IF EXISTS gateway_payment_id;
ALTER TABLE payments DROP COLUMN IF EXISTS gateway_signature;
ALTER TABLE payments DROP COLUMN IF EXISTS failure_reason;

-- Restore unique constraint on order_id
-- Note: This may fail if there are duplicate order_id values from Razorpay retries
-- In that case, remove duplicates first:
--   DELETE FROM payments p1 USING payments p2
--   WHERE p1.id < p2.id AND p1.order_id = p2.order_id AND p1.status = 'failed';
-- Then add the constraint:
ALTER TABLE payments ADD CONSTRAINT payments_order_id_key UNIQUE (order_id);
