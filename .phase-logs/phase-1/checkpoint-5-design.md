# Checkpoint 5: iOS SQLite Generator

## Goal
Generate compressed iOS SQLite (15-20MB) from Supabase pattern tables. Apply dictionary encoding (text IDs → ints), WITHOUT ROWID optimization, bit-packed calendar, FTS5 search index. Output to `backend/ios_output/gtfs.db`.

## Approach

### Backend Implementation
- Query Supabase for all pattern tables
- Transform to iOS-optimized schema with dictionary encoding
- Files to create:
  - `app/services/ios_db_generator.py` - Main generator with `generate_ios_db(output_path)` function
  - `backend/ios_output/` - Directory for generated gtfs.db
- Files to modify: None
- Critical pattern: Dictionary encoding (30-40% space savings), FTS5 for search, WITHOUT ROWID for mapping tables

### Implementation Details

**iOS Schema (Different from Supabase):**

1. **dict_stop** - Stop ID dictionary (WITHOUT ROWID)
   ```sql
   CREATE TABLE dict_stop (
     sid INTEGER PRIMARY KEY,
     stop_id TEXT UNIQUE NOT NULL
   ) WITHOUT ROWID;
   ```
   Maps: "200060" → 1, "200061" → 2, etc.

2. **dict_route** - Route ID dictionary (WITHOUT ROWID)
   ```sql
   CREATE TABLE dict_route (
     rid INTEGER PRIMARY KEY,
     route_id TEXT UNIQUE NOT NULL
   ) WITHOUT ROWID;
   ```

3. **dict_pattern** - Pattern ID dictionary (WITHOUT ROWID)
   ```sql
   CREATE TABLE dict_pattern (
     pid INTEGER PRIMARY KEY,
     pattern_id TEXT UNIQUE NOT NULL
   ) WITHOUT ROWID;
   ```

4. **stops** - Stops table (uses sid foreign keys)
   ```sql
   CREATE TABLE stops (
     sid INTEGER PRIMARY KEY,
     stop_code TEXT,
     stop_name TEXT NOT NULL,
     stop_lat REAL NOT NULL,
     stop_lon REAL NOT NULL,
     wheelchair_boarding INTEGER
   );
   ```
   Foreign key: sid → dict_stop.sid

5. **routes** - Routes table (uses rid)
   ```sql
   CREATE TABLE routes (
     rid INTEGER PRIMARY KEY,
     route_short_name TEXT,
     route_long_name TEXT,
     route_type INTEGER NOT NULL,
     route_color TEXT,
     route_text_color TEXT
   );
   ```

6. **patterns** - Patterns table (uses pid, rid)
   ```sql
   CREATE TABLE patterns (
     pid INTEGER PRIMARY KEY,
     rid INTEGER NOT NULL,
     direction_id INTEGER NOT NULL,
     pattern_name TEXT
   );
   ```

7. **pattern_stops** - Pattern stop sequences
   ```sql
   CREATE TABLE pattern_stops (
     pid INTEGER NOT NULL,
     stop_sequence INTEGER NOT NULL,
     sid INTEGER NOT NULL,
     arrival_offset INTEGER NOT NULL,
     departure_offset INTEGER NOT NULL,
     PRIMARY KEY (pid, stop_sequence)
   );
   ```

8. **trips** - Trips (uses pid, service_id stays text)
   ```sql
   CREATE TABLE trips (
     trip_id TEXT PRIMARY KEY,
     rid INTEGER NOT NULL,
     service_id TEXT NOT NULL,
     pid INTEGER NOT NULL,
     trip_headsign TEXT,
     direction_id INTEGER
   );
   ```

9. **calendar** - Calendar with bit-packed days
   ```sql
   CREATE TABLE calendar (
     service_id TEXT PRIMARY KEY,
     days INTEGER NOT NULL,  -- 7 bits: SMTWTFS
     start_date TEXT NOT NULL,
     end_date TEXT NOT NULL
   );
   ```
   Bit packing: monday=bit0, tuesday=bit1, ..., sunday=bit6
   Example: weekdays = 0b0011111 = 31

10. **calendar_dates** - Calendar exceptions
    ```sql
    CREATE TABLE calendar_dates (
      service_id TEXT NOT NULL,
      date TEXT NOT NULL,
      exception_type INTEGER NOT NULL,
      PRIMARY KEY (service_id, date)
    );
    ```

11. **stops_fts** - FTS5 search index
    ```sql
    CREATE VIRTUAL TABLE stops_fts USING fts5(
      sid UNINDEXED,
      name,
      tokenize='porter'
    );
    ```

12. **metadata** - Feed version info
    ```sql
    CREATE TABLE metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    );
    ```
    Rows: feed_version, feed_start_date, feed_end_date

**Generation Process:**

```python
import sqlite3
from app.db.supabase_client import get_supabase_client

def generate_ios_db(output_path: str):
    # 1. Query Supabase for all tables
    supabase = get_supabase_client()
    stops = supabase.table("stops").select("*").execute().data
    routes = supabase.table("routes").select("*").execute().data
    patterns = supabase.table("patterns").select("*").execute().data
    # ... fetch all tables

    # 2. Create SQLite file
    conn = sqlite3.connect(output_path)
    conn.execute("PRAGMA journal_mode=OFF")
    conn.execute("PRAGMA page_size=8192")

    # 3. Create schema (see above)
    create_schema(conn)

    # 4. Build dictionaries
    stop_dict = {stop["stop_id"]: idx+1 for idx, stop in enumerate(stops)}
    route_dict = {route["route_id"]: idx+1 for idx, route in enumerate(routes)}
    pattern_dict = {pattern["pattern_id"]: idx+1 for idx, pattern in enumerate(patterns)}

    # 5. Insert dict tables
    conn.executemany("INSERT INTO dict_stop VALUES (?, ?)", stop_dict.items())
    # ... (dict_route, dict_pattern)

    # 6. Transform and insert main tables
    stops_ios = [
        (stop_dict[s["stop_id"]], s["stop_code"], s["stop_name"], s["stop_lat"], s["stop_lon"], s["wheelchair_boarding"])
        for s in stops
    ]
    conn.executemany("INSERT INTO stops VALUES (?, ?, ?, ?, ?, ?)", stops_ios)

    # 7. Populate FTS5
    fts_data = [(stop_dict[s["stop_id"]], s["stop_name"]) for s in stops]
    conn.executemany("INSERT INTO stops_fts VALUES (?, ?)", fts_data)

    # 8. Calendar bit packing
    def pack_days(cal):
        days = 0
        if cal["monday"]: days |= 1 << 0
        if cal["tuesday"]: days |= 1 << 1
        # ... (all 7 days)
        return days

    # 9. VACUUM and close
    conn.execute("VACUUM")
    conn.close()

    # 10. Log file size
    import os
    size_mb = os.path.getsize(output_path) / 1024 / 1024
    logger.info("ios_db_generated", path=output_path, size_mb=size_mb)
```

**Optimization PRAGMAs:**
- `journal_mode=OFF` - No WAL (read-only DB, faster)
- `page_size=8192` - Larger pages = fewer seeks
- `VACUUM` - Reclaim fragmented space (critical!)

## Design Constraints
- Dictionary encoding: Assign integer IDs sequentially (1, 2, 3, ...) for compact representation
- WITHOUT ROWID: Only for dict tables (integer PK ≤64 bits), NOT for main tables
- FTS5 tokenize='porter': Stemming (e.g., "Station" → "station")
- Bit packing: calendar.days single INTEGER (not 7 BOOLEAN columns)
- Follow DATA_ARCHITECTURE.md:Section 6 iOS schema exactly
- Use `executemany()` for bulk inserts (not individual INSERT statements)
- Target size: 15-20MB (validate after VACUUM)
- iOS research: `.phase-logs/phase-1/ios-research-without-rowid.md` for WITHOUT ROWID benefits

## Risks
- **DB size >20MB:** Dictionary encoding or compression insufficient
  - Mitigation: VACUUM reclaims ~10-15% space, Sydney filtering already reduced 40-60%
- **FTS5 not available:** Older SQLite versions
  - Mitigation: SQLite 3.9+ has FTS5 (Python 3.7+ bundles 3.22+)
- **Memory usage:** Loading all Supabase data at once
  - Mitigation: ~15k stops × 200 bytes = 3MB in-memory (acceptable)
- **WITHOUT ROWID errors:** Using on tables with large rows
  - Mitigation: Only dict tables (2 columns, <100 bytes per row)

## Validation
```bash
cd backend
python -c "from app.services.ios_db_generator import generate_ios_db; generate_ios_db('ios_output/gtfs.db')"

# Expected logs:
# ios_db_generation_start
# ios_db_dicts_created: stops=15000, routes=800, patterns=5000
# ios_db_tables_inserted: stops=15000, routes=800, trips=120000
# ios_db_fts_populated: stops=15000
# ios_db_vacuum_complete: reclaimed_mb=2.1
# ios_db_generated: path=ios_output/gtfs.db, size_mb=17.3, duration_ms=8000

ls -lh backend/ios_output/gtfs.db
# Expected: 15-20MB

# SQLite validation:
sqlite3 backend/ios_output/gtfs.db <<EOF
SELECT COUNT(*) FROM stops;        -- Matches Supabase count
SELECT COUNT(*) FROM dict_stop;    -- Same as stops count
SELECT * FROM stops_fts WHERE stops_fts MATCH 'circular' LIMIT 5;
-- Expected: Rows with "Circular Quay" stops

.tables
-- Expected: calendar, calendar_dates, dict_pattern, dict_route, dict_stop, metadata, pattern_stops, patterns, routes, stops, stops_fts, trips (12 tables)

SELECT value FROM metadata WHERE key='feed_version';
-- Expected: "2025-11-13" or latest date

PRAGMA page_size;
-- Expected: 8192

PRAGMA journal_mode;
-- Expected: delete (OFF not persistent, reverts to delete)
EOF
```

## References for Subagent
- Exploration report: `key_decisions[2]` - iOS SQLite dictionary encoding rationale
- Standards: DEVELOPMENT_STANDARDS.md:Section 2.1 (iOS database patterns)
- Architecture: DATA_ARCHITECTURE.md:Section 6 (iOS schema, Table 6)
- iOS research: `.phase-logs/phase-1/ios-research-without-rowid.md` (15-20% size reduction)
- iOS research: `.phase-logs/phase-1/ios-research-grdb-fts5-match.md` (FTS5 tokenization)
- Supabase client: backend/app/db/supabase_client.py
- Checkpoint 4 result: Supabase row counts (for validation)

## Estimated Complexity
**complex** - Multiple transformations (text→int dictionaries, bit packing, FTS5 population), schema translation, optimization PRAGMAs, size validation critical for iOS bundle target
