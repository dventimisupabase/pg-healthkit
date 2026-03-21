-- Probe: extensions_inventory
-- Purpose: Detect available capability and potential operational risks.
-- Prerequisites: None
-- Profiles: default, performance, reliability, cost_capacity

SELECT extname, extversion
FROM pg_extension
ORDER BY extname;
