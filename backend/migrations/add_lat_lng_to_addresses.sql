-- Add latitude/longitude columns to addresses table
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS latitude NUMERIC(10, 7);
ALTER TABLE addresses ADD COLUMN IF NOT EXISTS longitude NUMERIC(10, 7);
