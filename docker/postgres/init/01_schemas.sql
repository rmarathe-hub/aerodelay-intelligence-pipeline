-- AeroDelay Intelligence Pipeline — warehouse schemas (runs once on first Postgres init)

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS meta;

COMMENT ON SCHEMA raw IS 'Landing zone for BTS flights and ASOS/METAR weather observations';
COMMENT ON SCHEMA meta IS 'Pipeline metadata: run logs, freshness, DQ metrics';

GRANT ALL ON SCHEMA raw TO CURRENT_USER;
GRANT ALL ON SCHEMA meta TO CURRENT_USER;
