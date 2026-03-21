-- Probe: bloat_estimate
-- Purpose: Approximate table bloat estimation from catalog statistics.
-- Prerequisites: None (prefer pgstattuple extension when available)
-- Category: v1.1 optional
-- Note: This query is approximate and inherently low-confidence.
--       Prefer an extension-backed path (pgstattuple) when available.

SELECT
  schemaname,
  tblname,
  pg_size_pretty(tbl_len) AS table_size,
  pg_size_pretty(tuple_len) AS tuple_size,
  pg_size_pretty(tbl_len - tuple_len) AS approx_bloat,
  ROUND(100 * (tbl_len - tuple_len) / NULLIF(tbl_len, 0)::numeric, 2) AS approx_bloat_pct
FROM (
  SELECT
    schemaname,
    tblname,
    bs * relpages AS tbl_len,
    (reltuples * ((datahdr + ma - (CASE WHEN datahdr % ma = 0 THEN ma ELSE datahdr % ma END)) + nullhdr2 + 4)) AS tuple_len
  FROM (
    SELECT
      schemaname,
      tblname,
      cc.reltuples,
      cc.relpages,
      bs,
      CEIL((cc.reltuples * (datawidth + (hdr + ma - (CASE WHEN hdr % ma = 0 THEN ma ELSE hdr % ma END)) + nullhdr2 + 4)) / bs) AS otta,
      datawidth,
      hdr,
      ma,
      nullhdr2
    FROM (
      SELECT
        schemaname,
        tablename AS tblname,
        hdr,
        ma,
        bs,
        SUM((1 - null_frac) * avg_width) AS datawidth,
        MAX(null_frac) * hdr AS nullhdr2
      FROM (
        SELECT
          schemaname,
          tablename,
          null_frac,
          avg_width,
          23 AS hdr,
          8 AS ma,
          current_setting('block_size')::numeric AS bs
        FROM pg_stats
      ) s
      GROUP BY schemaname, tablename, hdr, ma, bs
    ) rs
    JOIN pg_class cc ON cc.relname = rs.tblname
    JOIN pg_namespace nn ON nn.oid = cc.relnamespace AND nn.nspname = rs.schemaname
  ) s1
) s2
ORDER BY approx_bloat_pct DESC NULLS LAST
LIMIT 20;
