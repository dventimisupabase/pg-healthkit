# Probe System

## Purpose
Collect raw evidence from PostgreSQL.

## Categories
- Activity (pg_stat_database)
- Queries (pg_stat_statements)
- Concurrency (locks, connections)
- Storage (tables, indexes)
- Maintenance (vacuum/analyze)
- Replication
- WAL/checkpoints

## Properties
Each probe defines:
- SQL query
- prerequisites
- payload shape
- supported findings
- affected domains
