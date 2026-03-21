-- Probe: prepared_transactions
-- Purpose: Detect abandoned two-phase commit transactions.
-- Prerequisites: max_prepared_transactions > 0
-- Category: v1.1 optional
-- Note: Prepared transactions hold locks and prevent vacuum progress
--   just like long-running transactions, but are harder to discover
--   because they survive connection close and server restart.

SELECT
  gid,
  prepared,
  owner,
  database,
  now() - prepared AS age
FROM pg_prepared_xacts
ORDER BY prepared ASC;
