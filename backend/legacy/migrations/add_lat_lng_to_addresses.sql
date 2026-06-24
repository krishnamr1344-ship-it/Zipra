-- Add latitude/longitude columns to addresses table
ALTER TABLE addresses
ADD COLUMN latitude NUMERIC(10, 7),
ADD COLUMN longitude NUMERIC(10, 7);
