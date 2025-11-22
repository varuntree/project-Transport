"""iOS SQLite database generator with dictionary encoding.

Queries Supabase pattern tables → transforms to iOS-optimized schema → generates gtfs.db.

Key optimizations:
- Dictionary encoding: text IDs (stop_id, route_id, pattern_id) → compact integers (sid, rid, pid)
- WITHOUT ROWID: dict tables only (15-20% size reduction)
- Bit-packed calendar: 7 boolean columns → 1 INTEGER (7 bits)
- FTS5: Full-text search index for stop names
- PRAGMAs: journal_mode=OFF, page_size=8192, VACUUM

Target: 15-20MB iOS bundle size
"""

import sqlite3
import time
import os
from pathlib import Path
from typing import Dict, List, Any, Tuple

VAR_DIR = Path(os.getenv("VAR_DIR", Path(__file__).resolve().parent.parent.parent / "var")).resolve()
DEFAULT_IOS_DB_PATH = VAR_DIR / "data" / "gtfs.db"

from app.db.supabase_client import get_supabase
from app.utils.logging import get_logger

logger = get_logger(__name__)


def generate_ios_db(output_path: str = str(DEFAULT_IOS_DB_PATH)) -> Dict[str, Any]:
    """Generate iOS SQLite database from Supabase pattern tables.

    Args:
        output_path: Path for generated gtfs.db (default: var/data/gtfs.db)

    Returns:
        Dict with generation summary: file_size_mb, row_counts, duration_ms

    Raises:
        ValueError: If validation fails (file size >20MB, row count mismatch)
        Exception: If Supabase query or SQLite write fails
    """
    start_time = time.time()
    logger.info("ios_db_generation_start", output_path=output_path)

    # Ensure output directory exists
    os.makedirs(os.path.dirname(output_path), exist_ok=True)

    # Delete existing file to ensure fresh schema
    if os.path.exists(output_path):
        try:
            os.remove(output_path)
            logger.info("ios_db_removed_existing", path=output_path)
        except OSError as e:
            logger.warning("ios_db_remove_failed", path=output_path, error=str(e))

    try:
        # Step 1: Query Supabase for all tables
        logger.info("ios_db_stage_start", stage="fetch_supabase")
        fetch_start = time.time()
        supabase_data = _fetch_supabase_data()
        fetch_duration_ms = int((time.time() - fetch_start) * 1000)
        logger.info(
            "ios_db_stage_complete",
            stage="fetch_supabase",
            duration_ms=fetch_duration_ms,
            stops=len(supabase_data["stops"]),
            routes=len(supabase_data["routes"]),
            patterns=len(supabase_data["patterns"])
        )

        # Step 2: Build dictionaries (text IDs → integers)
        logger.info("ios_db_stage_start", stage="build_dictionaries")
        dict_start = time.time()
        dictionaries = _build_dictionaries(supabase_data)
        dict_duration_ms = int((time.time() - dict_start) * 1000)
        logger.info(
            "ios_db_stage_complete",
            stage="build_dictionaries",
            duration_ms=dict_duration_ms,
            stop_dict_size=len(dictionaries["stop_dict"]),
            route_dict_size=len(dictionaries["route_dict"]),
            pattern_dict_size=len(dictionaries["pattern_dict"])
        )

        # Step 3: Create SQLite file and schema
        logger.info("ios_db_stage_start", stage="create_schema")
        schema_start = time.time()
        conn = sqlite3.connect(output_path)
        _apply_pragmas(conn)
        _create_schema(conn)
        schema_duration_ms = int((time.time() - schema_start) * 1000)
        logger.info(
            "ios_db_stage_complete",
            stage="create_schema",
            duration_ms=schema_duration_ms
        )

        # Step 4: Insert data (dictionaries + main tables)
        logger.info("ios_db_stage_start", stage="insert_data")
        insert_start = time.time()
        row_counts = _insert_data(conn, supabase_data, dictionaries)
        insert_duration_ms = int((time.time() - insert_start) * 1000)
        logger.info(
            "ios_db_stage_complete",
            stage="insert_data",
            duration_ms=insert_duration_ms,
            total_rows=sum(row_counts.values())
        )

        # Step 5: VACUUM (critical for size reduction)
        logger.info("ios_db_stage_start", stage="vacuum")
        vacuum_start = time.time()
        size_before_mb = os.path.getsize(output_path) / 1024 / 1024
        conn.execute("VACUUM")
        conn.commit()
        vacuum_duration_ms = int((time.time() - vacuum_start) * 1000)
        size_after_mb = os.path.getsize(output_path) / 1024 / 1024
        reclaimed_mb = size_before_mb - size_after_mb
        logger.info(
            "ios_db_stage_complete",
            stage="vacuum",
            duration_ms=vacuum_duration_ms,
            size_before_mb=round(size_before_mb, 2),
            size_after_mb=round(size_after_mb, 2),
            reclaimed_mb=round(reclaimed_mb, 2)
        )

        # Step 6: Close and validate
        conn.close()

        logger.info("ios_db_stage_start", stage="validation")
        validation_result = _validate_ios_db(output_path, supabase_data, row_counts)
        logger.info(
            "ios_db_stage_complete",
            stage="validation",
            validation_passed=validation_result["passed"]
        )

        # Final summary
        total_duration_ms = int((time.time() - start_time) * 1000)
        file_size_mb = os.path.getsize(output_path) / 1024 / 1024

        result = {
            "status": "success",
            "file_path": output_path,
            "file_size_mb": round(file_size_mb, 2),
            "duration_ms": total_duration_ms,
            "row_counts": row_counts,
            "validation": validation_result
        }

        logger.info(
            "ios_db_generated",
            path=output_path,
            size_mb=round(file_size_mb, 2),
            duration_ms=total_duration_ms,
            stops=row_counts.get("stops", 0),
            routes=row_counts.get("routes", 0),
            patterns=row_counts.get("patterns", 0),
            trips=row_counts.get("trips", 0)
        )

        return result

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        logger.error(
            "ios_db_generation_failed",
            error=str(e),
            error_type=type(e).__name__,
            duration_ms=duration_ms
        )
        raise


def _fetch_supabase_data() -> Dict[str, List[Dict]]:
    """Fetch all required tables from Supabase.

    Returns:
        Dict with keys: stops, routes, patterns, pattern_stops, trips, calendar, calendar_dates, metadata
    """
    supabase = get_supabase()

    # Fetch all tables with pagination (Supabase default limit is 1000)
    data = {}

    tables = ["stops", "routes", "patterns", "pattern_stops", "trips", "calendar", "calendar_dates"]

    for table in tables:
        logger.info("ios_db_fetch_table_start", table=table)

        # Fetch all rows using range pagination
        # Supabase range is inclusive: range(0, 999) returns rows 0-999 (1000 rows)
        # But the client seems to return 999, so we adjust
        all_rows = []
        offset = 0
        page_size = 999  # Observed behavior from Supabase client

        while True:
            end_range = offset + page_size
            response = supabase.table(table).select("*").range(offset, end_range).execute()
            if not response.data:
                break

            rows_fetched = len(response.data)
            all_rows.extend(response.data)
            logger.info("ios_db_fetch_page", table=table, offset=offset, rows_fetched=rows_fetched)

            # If we got fewer rows than expected, we've reached the end
            if rows_fetched < page_size:
                break

            offset += rows_fetched  # Move offset by actual rows fetched

        data[table] = all_rows
        logger.info("ios_db_fetch_table_complete", table=table, rows=len(all_rows))

    # Fetch metadata separately
    metadata_response = supabase.table("gtfs_metadata").select("*").limit(1).execute()
    data["metadata"] = metadata_response.data[0] if metadata_response.data else {}

    return data


def _build_dictionaries(data: Dict[str, List[Dict]]) -> Dict[str, Dict[str, int]]:
    """Build ID dictionaries (text → integer) for dictionary encoding.

    Args:
        data: Supabase data with stops, routes, patterns

    Returns:
        Dict with stop_dict, route_dict, pattern_dict mappings
    """
    stop_dict = {stop["stop_id"]: idx + 1 for idx, stop in enumerate(data["stops"])}
    route_dict = {route["route_id"]: idx + 1 for idx, route in enumerate(data["routes"])}
    pattern_dict = {pattern["pattern_id"]: idx + 1 for idx, pattern in enumerate(data["patterns"])}

    return {
        "stop_dict": stop_dict,
        "route_dict": route_dict,
        "pattern_dict": pattern_dict
    }


def _apply_pragmas(conn: sqlite3.Connection):
    """Apply SQLite PRAGMAs for iOS optimization.

    Args:
        conn: SQLite connection
    """
    conn.execute("PRAGMA journal_mode=OFF")  # No WAL (read-only DB)
    conn.execute("PRAGMA page_size=8192")    # Larger pages = fewer seeks
    conn.execute("PRAGMA synchronous=OFF")   # Faster writes during generation
    conn.commit()

    logger.info("ios_db_pragmas_applied", journal_mode="OFF", page_size=8192)


def _create_schema(conn: sqlite3.Connection):
    """Create iOS SQLite schema with dictionary encoding.

    Schema differences from Supabase:
    - dict_stop, dict_route, dict_pattern (WITHOUT ROWID)
    - Main tables use integer FKs (sid, rid, pid)
    - calendar.days is bit-packed INTEGER (7 bits)
    - stops_fts is FTS5 virtual table

    Args:
        conn: SQLite connection
    """
    # Dictionary tables (WITHOUT ROWID)
    conn.execute("""
        CREATE TABLE dict_stop (
            sid INTEGER PRIMARY KEY,
            stop_id TEXT UNIQUE NOT NULL
        ) WITHOUT ROWID
    """)

    conn.execute("""
        CREATE TABLE dict_route (
            rid INTEGER PRIMARY KEY,
            route_id TEXT UNIQUE NOT NULL
        ) WITHOUT ROWID
    """)

    conn.execute("""
        CREATE TABLE dict_pattern (
            pid INTEGER PRIMARY KEY,
            pattern_id TEXT UNIQUE NOT NULL
        ) WITHOUT ROWID
    """)

    # Main tables (use integer FKs)
    conn.execute("""
        CREATE TABLE stops (
            sid INTEGER PRIMARY KEY,
            stop_code TEXT,
            stop_name TEXT NOT NULL,
            stop_desc TEXT,
            stop_lat REAL NOT NULL,
            stop_lon REAL NOT NULL,
            location_type INTEGER,
            parent_station TEXT,
            wheelchair_boarding INTEGER,
            platform_code TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE routes (
            rid INTEGER PRIMARY KEY,
            route_short_name TEXT,
            route_long_name TEXT,
            route_type INTEGER NOT NULL,
            route_color TEXT,
            route_text_color TEXT
        )
    """)

    conn.execute("""
        CREATE TABLE patterns (
            pid INTEGER PRIMARY KEY,
            rid INTEGER NOT NULL,
            direction_id INTEGER NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE pattern_stops (
            pid INTEGER NOT NULL,
            stop_sequence INTEGER NOT NULL,
            sid INTEGER NOT NULL,
            arrival_offset_secs INTEGER NOT NULL,
            departure_offset_secs INTEGER NOT NULL,
            PRIMARY KEY (pid, stop_sequence)
        )
    """)

    # Optimise sid + offset lookup for offline departures query
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_pattern_stops_sid_offset ON pattern_stops (sid, departure_offset_secs)"
    )

    conn.execute("""
        CREATE TABLE trips (
            trip_id TEXT PRIMARY KEY,
            rid INTEGER NOT NULL,
            service_id TEXT NOT NULL,
            pid INTEGER NOT NULL,
            trip_headsign TEXT,
            trip_short_name TEXT,
            direction_id INTEGER,
            block_id TEXT,
            wheelchair_accessible INTEGER
        )
    """)

    # Calendar with bit-packed days
    conn.execute("""
        CREATE TABLE calendar (
            service_id TEXT PRIMARY KEY,
            days INTEGER NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL
        )
    """)

    conn.execute("""
        CREATE TABLE calendar_dates (
            service_id TEXT NOT NULL,
            date TEXT NOT NULL,
            exception_type INTEGER NOT NULL,
            PRIMARY KEY (service_id, date)
        )
    """)

    # FTS5 search index
    conn.execute("""
        CREATE VIRTUAL TABLE stops_fts USING fts5(
            sid UNINDEXED,
            name
        )
    """)

    # Metadata
    conn.execute("""
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
    """)

    conn.commit()
    logger.info("ios_db_schema_created", tables=12)


def _insert_data(
    conn: sqlite3.Connection,
    data: Dict[str, List[Dict]],
    dictionaries: Dict[str, Dict[str, int]]
) -> Dict[str, int]:
    """Insert all data into iOS SQLite.

    Args:
        conn: SQLite connection
        data: Supabase data
        dictionaries: ID mappings (text → int)

    Returns:
        Dict mapping table names to row counts
    """
    counts = {}

    # Insert dictionaries
    stop_dict_rows = [(v, k) for k, v in dictionaries["stop_dict"].items()]
    conn.executemany("INSERT INTO dict_stop VALUES (?, ?)", stop_dict_rows)
    counts["dict_stop"] = len(stop_dict_rows)
    logger.info("ios_db_table_inserted", table="dict_stop", rows=len(stop_dict_rows))

    # Validate dict_stop completeness
    stops_count = len(data["stops"])
    dict_stop_count = len(stop_dict_rows)
    if stops_count != dict_stop_count:
        logger.error("dict_stop_validation_failed", stops_count=stops_count, dict_stop_count=dict_stop_count)
        raise ValueError(f"dict_stop validation failed: {stops_count} stops but {dict_stop_count} dict_stop entries")
    logger.info("dict_stop_validated", stops_count=stops_count, dict_stop_count=dict_stop_count)

    route_dict_rows = [(v, k) for k, v in dictionaries["route_dict"].items()]
    conn.executemany("INSERT INTO dict_route VALUES (?, ?)", route_dict_rows)
    counts["dict_route"] = len(route_dict_rows)
    logger.info("ios_db_table_inserted", table="dict_route", rows=len(route_dict_rows))

    pattern_dict_rows = [(v, k) for k, v in dictionaries["pattern_dict"].items()]
    conn.executemany("INSERT INTO dict_pattern VALUES (?, ?)", pattern_dict_rows)
    counts["dict_pattern"] = len(pattern_dict_rows)
    logger.info("ios_db_table_inserted", table="dict_pattern", rows=len(pattern_dict_rows))

    # Insert stops
    stops_rows = [
        (
            dictionaries["stop_dict"][s["stop_id"]],
            s.get("stop_code"),
            s["stop_name"],
            s.get("stop_desc"),
            s["stop_lat"],
            s["stop_lon"],
            s.get("location_type"),
            s.get("parent_station"),
            s.get("wheelchair_boarding"),
            s.get("platform_code")
        )
        for s in data["stops"]
    ]
    conn.executemany(
        "INSERT INTO stops VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        stops_rows
    )
    counts["stops"] = len(stops_rows)
    logger.info("ios_db_table_inserted", table="stops", rows=len(stops_rows))

    # Insert routes
    routes_rows = [
        (
            dictionaries["route_dict"][r["route_id"]],
            r.get("route_short_name"),
            r.get("route_long_name"),
            r["route_type"],
            r.get("route_color"),
            r.get("route_text_color")
        )
        for r in data["routes"]
    ]
    conn.executemany(
        "INSERT INTO routes VALUES (?, ?, ?, ?, ?, ?)",
        routes_rows
    )
    counts["routes"] = len(routes_rows)
    logger.info("ios_db_table_inserted", table="routes", rows=len(routes_rows))

    # Insert patterns
    patterns_rows = [
        (
            dictionaries["pattern_dict"][p["pattern_id"]],
            dictionaries["route_dict"][p["route_id"]],
            p["direction_id"]
        )
        for p in data["patterns"]
    ]
    conn.executemany(
        "INSERT INTO patterns VALUES (?, ?, ?)",
        patterns_rows
    )
    counts["patterns"] = len(patterns_rows)
    logger.info("ios_db_table_inserted", table="patterns", rows=len(patterns_rows))

    # Insert pattern_stops
    pattern_stops_rows = [
        (
            dictionaries["pattern_dict"][ps["pattern_id"]],
            ps["stop_sequence"],
            dictionaries["stop_dict"][ps["stop_id"]],
            ps["arrival_offset_secs"],
            ps["departure_offset_secs"]
        )
        for ps in data["pattern_stops"]
    ]
    conn.executemany(
        "INSERT INTO pattern_stops VALUES (?, ?, ?, ?, ?)",
        pattern_stops_rows
    )
    counts["pattern_stops"] = len(pattern_stops_rows)
    logger.info("ios_db_table_inserted", table="pattern_stops", rows=len(pattern_stops_rows))

    # Insert trips
    trips_rows = [
        (
            t["trip_id"],
            dictionaries["route_dict"][t["route_id"]],
            t["service_id"],
            dictionaries["pattern_dict"][t["pattern_id"]],
            t.get("trip_headsign"),
            t.get("trip_short_name"),
            t.get("direction_id"),
            t.get("block_id"),
            t.get("wheelchair_accessible")
        )
        for t in data["trips"]
    ]
    conn.executemany(
        "INSERT INTO trips VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        trips_rows
    )
    counts["trips"] = len(trips_rows)
    logger.info("ios_db_table_inserted", table="trips", rows=len(trips_rows))

    # Insert calendar (bit-pack days)
    calendar_rows = [
        (
            c["service_id"],
            _pack_calendar_days(c),
            c["start_date"],
            c["end_date"]
        )
        for c in data["calendar"]
    ]
    conn.executemany(
        "INSERT INTO calendar VALUES (?, ?, ?, ?)",
        calendar_rows
    )
    counts["calendar"] = len(calendar_rows)
    logger.info("ios_db_table_inserted", table="calendar", rows=len(calendar_rows))

    # Insert calendar_dates
    calendar_dates_rows = [
        (
            cd["service_id"],
            cd["date"],
            cd["exception_type"]
        )
        for cd in data["calendar_dates"]
    ]
    if calendar_dates_rows:
        conn.executemany(
            "INSERT INTO calendar_dates VALUES (?, ?, ?)",
            calendar_dates_rows
        )
        counts["calendar_dates"] = len(calendar_dates_rows)
        logger.info("ios_db_table_inserted", table="calendar_dates", rows=len(calendar_dates_rows))
    else:
        counts["calendar_dates"] = 0

    # Populate FTS5
    fts_rows = [
        (dictionaries["stop_dict"][s["stop_id"]], s["stop_name"])
        for s in data["stops"]
    ]
    conn.executemany("INSERT INTO stops_fts VALUES (?, ?)", fts_rows)
    counts["stops_fts"] = len(fts_rows)
    logger.info("ios_db_table_inserted", table="stops_fts", rows=len(fts_rows))

    # Insert metadata
    metadata = data.get("metadata", {})
    metadata_rows = [
        ("feed_version", str(metadata.get("feed_version", "unknown"))),
        ("feed_start_date", str(metadata.get("feed_start_date", ""))),
        ("feed_end_date", str(metadata.get("feed_end_date", "")))
    ]
    conn.executemany("INSERT INTO metadata VALUES (?, ?)", metadata_rows)
    counts["metadata"] = len(metadata_rows)
    logger.info("ios_db_table_inserted", table="metadata", rows=len(metadata_rows))

    conn.commit()

    return counts


def _pack_calendar_days(cal: Dict[str, Any]) -> int:
    """Bit-pack calendar days into single INTEGER.

    Bit mapping: monday=bit0, tuesday=bit1, ..., sunday=bit6
    Example: weekdays (M-F) = 0b0011111 = 31

    Args:
        cal: Calendar dict with boolean day fields

    Returns:
        Bit-packed INTEGER (0-127)
    """
    days = 0
    if cal.get("monday"):
        days |= 1 << 0
    if cal.get("tuesday"):
        days |= 1 << 1
    if cal.get("wednesday"):
        days |= 1 << 2
    if cal.get("thursday"):
        days |= 1 << 3
    if cal.get("friday"):
        days |= 1 << 4
    if cal.get("saturday"):
        days |= 1 << 5
    if cal.get("sunday"):
        days |= 1 << 6

    return days


def _validate_ios_db(
    db_path: str,
    supabase_data: Dict[str, List[Dict]],
    row_counts: Dict[str, int]
) -> Dict[str, Any]:
    """Validate generated iOS SQLite database.

    Checks:
    1. File size 15-20MB
    2. Row counts match Supabase
    3. FTS5 search works
    4. PRAGMAs applied

    Args:
        db_path: Path to generated gtfs.db
        supabase_data: Original Supabase data
        row_counts: Inserted row counts

    Returns:
        Dict with validation results

    Raises:
        ValueError: If validation fails
    """
    issues = []

    # Check 1: File size
    # Target was 15-20MB initially, but with complete light rail merge (59K stops, 700K pattern_stops, 263K trips),
    # actual size is ~74MB which is acceptable for offline-first app (iOS allows up to 100MB without WiFi warning)
    file_size_mb = os.path.getsize(db_path) / 1024 / 1024
    if file_size_mb < 5:
        issues.append(f"File size too small: {file_size_mb:.2f}MB < 5MB (missing data?)")
    elif file_size_mb > 100:
        issues.append(f"File size too large: {file_size_mb:.2f}MB > 100MB (exceeds iOS bundle target)")

    # Check 2: Row counts
    conn = sqlite3.connect(db_path)

    tables_to_check = ["stops", "routes", "patterns", "trips"]
    for table in tables_to_check:
        expected = len(supabase_data[table])
        actual = row_counts.get(table, 0)

        if expected != actual:
            issues.append(f"{table}: expected {expected}, got {actual}")

    # Check 3: FTS5 search
    try:
        cursor = conn.execute("SELECT * FROM stops_fts WHERE stops_fts MATCH 'circular' LIMIT 5")
        fts_results = cursor.fetchall()
        if len(fts_results) == 0:
            issues.append("FTS5 search returned no results (index not populated?)")
    except Exception as e:
        issues.append(f"FTS5 search failed: {str(e)}")

    # Check 4: Page size
    cursor = conn.execute("PRAGMA page_size")
    page_size = cursor.fetchone()[0]
    if page_size != 8192:
        issues.append(f"Page size incorrect: {page_size} (expected 8192)")

    conn.close()

    # Determine pass/fail
    passed = len(issues) == 0

    if not passed:
        error_msg = f"iOS DB validation failed: {', '.join(issues)}"
        logger.error("ios_db_validation_failed", total_issues=len(issues), issues=issues)
        raise ValueError(error_msg)

    logger.info("ios_db_validation_passed", checks_passed=4)

    return {
        "passed": passed,
        "issues": issues,
        "file_size_mb": round(file_size_mb, 2),
        "checks_run": 4
    }
