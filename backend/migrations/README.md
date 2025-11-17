# Database Migrations

This directory tracks all Supabase database migrations for the Sydney Transit backend.

## Migration Tracking

Since we use Supabase MCP for applying migrations (not local SQL files), this folder maintains a historical record of all schema changes.

## Migration Format

Filename: `YYYYMMDDHHMMSS_migration_name.sql`

Each migration file includes:
- Migration description
- Date applied
- Application method (Supabase MCP)
- Status
- SQL DDL statements

## Applied Migrations

| Version | Name | Date Applied | Status |
|---------|------|--------------|--------|
| 20251117102739 | add_start_time_secs_to_trips | 2025-11-17 | ✅ Applied |

## How to Apply Migrations

Migrations are applied via Supabase MCP tool:

```python
mcp__supabase__apply_migration(
    project_id="bmbeysyzagecyqidvjbd",
    name="migration_name",
    query="SQL DDL statements"
)
```

After applying via MCP, create corresponding `.sql` file in this directory for documentation.

## Rollback

To rollback a migration, create a new reverse migration with DDL to undo changes.

Example:
```sql
-- Rollback: Remove start_time_secs from trips
ALTER TABLE trips DROP COLUMN start_time_secs;
DROP INDEX IF EXISTS idx_trips_start_time;
```
