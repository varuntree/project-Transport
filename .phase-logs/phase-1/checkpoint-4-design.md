# Checkpoint 4: GTFS Loader Task

## Goal
Load parsed GTFS data (from Checkpoint 2) → Supabase tables (from Checkpoint 3). Bulk insert in correct order (handle foreign keys), verify row counts match parser output, validate DB size <350MB, ensure NULL location count = 0.

## Approach

### Backend Implementation
- Orchestrate full pipeline: download → parse → load
- Use Supabase batch upsert (1000 rows/batch for performance)
- Files to create:
  - `app/tasks/gtfs_static_sync.py` - Main loader task with `load_gtfs_static()` function
- Files to modify: None
- Critical pattern: Supabase singleton client (Phase 0), bulk operations, dependency order

### Implementation Details

**Load Order (respects foreign keys):**
1. **agencies** (no dependencies)
2. **routes** (depends on agencies)
3. **stops** (no dependencies, trigger auto-populates location)
4. **calendar** (no dependencies)
5. **calendar_dates** (depends on calendar via service_id)
6. **patterns** (depends on routes)
7. **pattern_stops** (depends on patterns + stops)
8. **trips** (depends on routes + patterns + calendar)
9. **gtfs_metadata** (summary metadata, no dependencies)

**Batch Upsert Strategy:**
```python
from app.db.supabase_client import get_supabase_client

supabase = get_supabase_client()

# Batch insert (1000 rows at a time)
batch_size = 1000
for i in range(0, len(routes), batch_size):
    batch = routes[i:i+batch_size]
    response = supabase.table('routes').upsert(batch).execute()
    logger.info("routes_batch_inserted", batch_num=i//batch_size, rows=len(batch))
```

**Pipeline Orchestration:**
```python
def load_gtfs_static():
    # 1. Download GTFS from NSW API
    logger.info("gtfs_load_start", stage="download")
    download_gtfs_feeds()  # From Checkpoint 1

    # 2. Parse GTFS → pattern model
    logger.info("gtfs_load_start", stage="parse")
    data = parse_gtfs("temp/gtfs-downloads/")  # From Checkpoint 2

    # 3. Load to Supabase (in dependency order)
    logger.info("gtfs_load_start", stage="load", total_tables=9)

    load_table("agencies", data["agencies"])
    load_table("routes", data["routes"])
    load_table("stops", data["stops"])
    load_table("calendar", data["calendar"])
    load_table("calendar_dates", data["calendar_dates"])
    load_table("patterns", data["patterns"])
    load_table("pattern_stops", data["pattern_stops"])
    load_table("trips", data["trips"])

    # 4. Insert metadata
    metadata = {
        "feed_version": data["feed_version"],
        "feed_start_date": data["feed_start_date"],
        "feed_end_date": data["feed_end_date"],
        "stops_count": len(data["stops"]),
        "routes_count": len(data["routes"]),
        "patterns_count": len(data["patterns"]),
        "trips_count": len(data["trips"]),
    }
    supabase.table("gtfs_metadata").upsert([metadata]).execute()

    # 5. Validate
    validate_load()

    logger.info("gtfs_load_complete", duration_ms=total_duration)
```

**Validation Queries:**
```python
def validate_load():
    # Check row counts
    stops_count = supabase.table("stops").select("*", count="exact").execute().count
    assert stops_count > 10000, f"Too few stops: {stops_count}"

    # Check NULL locations (trigger should populate all)
    null_locations = supabase.table("stops").select("stop_id").is_("location", None).execute()
    assert len(null_locations.data) == 0, f"Found {len(null_locations.data)} NULL locations"

    logger.info("gtfs_validation_complete", stops=stops_count, null_locations=0)
```

**gtfs_metadata Structure:**
```python
{
    "feed_version": "2025-11-13",  # ISO date of download
    "feed_start_date": "2025-11-01",  # From calendar.txt min(start_date)
    "feed_end_date": "2026-01-31",  # From calendar.txt max(end_date)
    "processed_at": "2025-11-13T10:30:00Z",  # Auto-populated by DB
    "stops_count": 15000,
    "routes_count": 800,
    "patterns_count": 5000,
    "trips_count": 120000
}
```

## Design Constraints
- Use existing Supabase client from `app/db/supabase_client.py`
- Batch size: 1000 rows (Supabase recommended limit)
- Upsert (not insert): Allows re-running without duplicates (idempotent)
- Log progress after each batch: `logger.info("table_batch_loaded", table=name, batch_num=N)`
- Validate NULL locations = 0 (trigger must work)
- Follow DEVELOPMENT_STANDARDS.md:2.3.1 for Supabase patterns
- Run manually first (not Celery scheduled) - Phase 2 adds scheduling

## Risks
- **Foreign key violations:** Loading out of order
  - Mitigation: Strict load order (agencies → routes → stops → ...)
- **Supabase timeout:** Large batch insert takes >60s
  - Mitigation: 1000 row batches = ~2-5s per batch (tested safe)
- **Trip ID conflicts:** Multiple modes with same trip_id
  - Mitigation: Parser (Checkpoint 2) must prefix trip_id with mode
- **Trigger failure:** location stays NULL
  - Mitigation: Validate NULL count = 0, fail if any found
- **DB size >350MB:** Dataset larger than expected
  - Mitigation: Sydney filtering (Checkpoint 2) reduces by 40-60%

## Validation
```bash
# Run loader manually
cd backend
python -c "from app.tasks.gtfs_static_sync import load_gtfs_static; load_gtfs_static()"

# Expected logs:
# gtfs_load_start: stage=download
# gtfs_download_complete: ... (from Checkpoint 1)
# gtfs_load_start: stage=parse
# gtfs_parse_complete: stops=15000, routes=800, ... (from Checkpoint 2)
# gtfs_load_start: stage=load, total_tables=9
# routes_batch_inserted: batch_num=0, rows=800
# stops_batch_inserted: batch_num=0, rows=1000
# stops_batch_inserted: batch_num=1, rows=1000
# ... (15 batches for 15k stops)
# gtfs_validation_complete: stops=15000, null_locations=0
# gtfs_load_complete: duration_ms=45000

# Check Supabase SQL Editor:
SELECT COUNT(*) FROM stops;        -- 10000-25000
SELECT COUNT(*) FROM routes;       -- 400-1200
SELECT COUNT(*) FROM patterns;     -- 2000-10000
SELECT COUNT(*) FROM trips;        -- 50000-150000
SELECT COUNT(*) FROM stops WHERE location IS NULL;  -- 0 (CRITICAL)

# Check Supabase Dashboard → Database → Usage:
# Total size: <350MB (likely 200-300MB with Sydney filtering)

SELECT * FROM gtfs_metadata ORDER BY processed_at DESC LIMIT 1;
-- Expected: Latest feed_version, correct counts
```

## References for Subagent
- Exploration report: `previous_phase_state.files_created` - Supabase client exists
- Standards: DEVELOPMENT_STANDARDS.md:Section 2.3.1 (Supabase batch operations)
- Architecture: BACKEND_SPECIFICATION.md:L245-268 (bulk loading patterns)
- Supabase client: backend/app/db/supabase_client.py (Phase 0 singleton)
- Parser output: Checkpoint 2 result (data dict structure)
- Schema: Checkpoint 3 (table names, columns, foreign keys)

## Estimated Complexity
**moderate** - Orchestration straightforward, but must handle batch logic, dependency order, validation carefully. Error handling critical (fail fast, clear logs).
