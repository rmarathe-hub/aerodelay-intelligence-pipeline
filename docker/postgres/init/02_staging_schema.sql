-- dbt staging schema (Week 1 Day 7+)

CREATE SCHEMA IF NOT EXISTS staging;

COMMENT ON SCHEMA staging IS 'dbt staging views: typed and cleaned raw BTS flights and weather observations';

GRANT ALL ON SCHEMA staging TO CURRENT_USER;
