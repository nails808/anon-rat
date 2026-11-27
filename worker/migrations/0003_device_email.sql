-- Link console user email to device for operator targeting
ALTER TABLE devices ADD COLUMN email TEXT;
CREATE INDEX IF NOT EXISTS idx_devices_email ON devices(email);
