-- probe: pg_cron_job_health
-- purpose: Detect failed or long-running scheduled jobs.
-- prerequisites: pg_cron extension
-- profiles: default, reliability
-- note: Supabase-specific. Requires pg_cron extension installed.

SELECT
  j.jobid,
  j.schedule,
  j.command,
  j.nodename,
  j.nodeport,
  j.database,
  j.username,
  j.active AS job_active,
  d.runid,
  d.job_pid,
  d.status AS last_status,
  d.return_message,
  d.start_time,
  d.end_time,
  EXTRACT(EPOCH FROM (d.end_time - d.start_time))::numeric AS duration_seconds
FROM cron.job j
LEFT JOIN LATERAL (
  SELECT *
  FROM cron.job_run_details rd
  WHERE rd.jobid = j.jobid
  ORDER BY rd.start_time DESC
  LIMIT 1
) d ON true
ORDER BY d.start_time DESC NULLS LAST;
