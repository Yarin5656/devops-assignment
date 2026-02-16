CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS geo_features (
  id BIGSERIAL PRIMARY KEY,
  source_bucket TEXT NOT NULL,
  source_key TEXT NOT NULL,
  feature_index INTEGER NOT NULL,
  properties JSONB,
  geom geometry(Geometry, 4326) NOT NULL,
  ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);