-- Probe: role_inventory
-- Purpose: Detect superuser sprawl, unused roles, and risky role configurations.
-- Prerequisites: None
-- Profiles: default, reliability

SELECT
  rolname,
  rolsuper,
  rolcreaterole,
  rolcreatedb,
  rolreplication,
  rolcanlogin,
  rolvaliduntil
FROM pg_roles
ORDER BY rolname;
