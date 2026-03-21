-- probe: role_inventory
-- purpose: Detect superuser sprawl, unused roles, and risky role configurations.
-- prerequisites: none
-- profiles: default, reliability, supabase_default

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
