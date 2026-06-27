-- dbt intermediate schema (Week 2 Day 8+)

CREATE SCHEMA IF NOT EXISTS intermediate;

COMMENT ON SCHEMA intermediate IS 'dbt intermediate models: airport dims, UTC departure context, weather join prep';

GRANT ALL ON SCHEMA intermediate TO CURRENT_USER;
