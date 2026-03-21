-- probe: extensions_inventory
-- purpose: Detect available capability and potential operational risks.
-- prerequisites: none
-- profiles: default, performance, reliability, cost_capacity

SELECT extname, extversion
FROM pg_extension
ORDER BY extname;
