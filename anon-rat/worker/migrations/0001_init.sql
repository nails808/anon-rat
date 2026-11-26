CREATE TABLE IF NOT EXISTS devices (
  id TEXT PRIMARY KEY,
  meta TEXT,
  last_seen INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS jobs (
  id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  name TEXT NOT NULL,
  args TEXT,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_jobs_device ON jobs(device_id);

CREATE TABLE IF NOT EXISTS results (
  id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  name TEXT NOT NULL,
  ok INTEGER NOT NULL,
  payload TEXT,
  error TEXT,
  created_at INTEGER NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_results_device ON results(device_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_results_job ON results(job_id);
