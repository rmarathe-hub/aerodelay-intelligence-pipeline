-- dbt marts schema (Week 3 Day 18+)

CREATE SCHEMA IF NOT EXISTS marts;

COMMENT ON SCHEMA marts IS 'dbt marts layer: fact tables for delay-risk analysis';

GRANT ALL ON SCHEMA marts TO CURRENT_USER;
