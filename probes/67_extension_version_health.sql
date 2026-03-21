-- probe: extension_version_health
-- purpose: Detect outdated or potentially incompatible extensions.
-- prerequisites: none
-- profiles: default, reliability, supabase_default
-- note: Supabase-specific. Extension upgrades may be tied to platform versions.

SELECT
  e.extname AS name,
  e.extversion AS installed_version,
  av.version AS available_version,
  CASE
    WHEN e.extversion = av.version THEN false
    ELSE true
  END AS upgrade_available
FROM pg_extension e
LEFT JOIN LATERAL (
  SELECT version
  FROM pg_available_extension_versions v
  WHERE v.name = e.extname
    AND v.installed = false
  ORDER BY v.version DESC
  LIMIT 1
) av ON true
ORDER BY e.extname;
