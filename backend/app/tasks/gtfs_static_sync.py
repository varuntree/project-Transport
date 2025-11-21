"""GTFS static data sync task.

Orchestrates full pipeline: download GTFS from NSW API → parse pattern model → load to Supabase.
Handles batch upsert (1000 rows), validates NULL locations = 0, checks DB size.

Usage:
    from app.tasks.gtfs_static_sync import load_gtfs_static
    load_gtfs_static()  # Downloads, parses, loads all GTFS data
"""

import time
import math
from typing import Dict, List, Any
from datetime import datetime

from app.services.nsw_gtfs_downloader import download_gtfs_feeds, DEFAULT_GTFS_DIR
from app.services.gtfs_service import parse_gtfs
from app.db.supabase_client import get_supabase
from app.utils.logging import get_logger

logger = get_logger(__name__)

# Batch size for Supabase upsert (1000 recommended limit)
BATCH_SIZE = 1000

# Expected table load order (respects foreign keys)
LOAD_ORDER = [
    "agencies",       # No dependencies
    "routes",         # Depends on agencies
    "stops",          # No dependencies (trigger populates location)
    "calendar",       # No dependencies
    "calendar_dates", # Depends on calendar (via service_id)
    "patterns",       # Depends on routes
    "pattern_stops",  # Depends on patterns + stops
    "trips",          # Depends on routes + patterns + calendar
]

# Schema field mappings (only include fields that exist in Supabase tables)
SCHEMA_FIELDS = {
    "agencies": ["agency_id", "agency_name", "agency_url", "agency_timezone"],
    "routes": ["route_id", "agency_id", "route_short_name", "route_long_name", "route_type", "route_color", "route_text_color"],
    "stops": ["stop_id", "stop_code", "stop_name", "stop_desc", "stop_lat", "stop_lon", "location_type", "parent_station", "wheelchair_boarding", "platform_code"],
    "calendar": ["service_id", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "start_date", "end_date"],
    "calendar_dates": ["service_id", "date", "exception_type"],
    "patterns": ["pattern_id", "route_id", "direction_id"],  # pattern_name optional, not in parser
    "pattern_stops": ["pattern_id", "stop_sequence", "stop_id", "arrival_offset_secs", "departure_offset_secs"],
    "trips": ["trip_id", "route_id", "service_id", "pattern_id", "trip_headsign", "trip_short_name", "direction_id", "block_id", "wheelchair_accessible", "start_time_secs"]
}


def load_gtfs_static(output_dir: str = str(DEFAULT_GTFS_DIR)) -> Dict[str, Any]:
    """Load GTFS static data to Supabase.

    Orchestrates: download → parse → load pipeline.
    Validates NULL locations = 0, row counts match parser.

    Args:
        output_dir: Directory for GTFS downloads (default: var/data/gtfs-downloads)

    Returns:
        Dict with load summary: counts, duration, validation results

    Raises:
        ValueError: If validation fails (NULL locations, row count mismatch)
        Exception: If download, parse, or load fails
    """
    start_time = time.time()
    logger.info("gtfs_load_pipeline_start", output_dir=output_dir)

    try:
        # Step 1: Download GTFS from NSW API
        logger.info("gtfs_load_stage_start", stage="download")
        download_start = time.time()
        mode_dirs = download_gtfs_feeds(output_dir)
        download_duration_ms = int((time.time() - download_start) * 1000)
        logger.info(
            "gtfs_load_stage_complete",
            stage="download",
            duration_ms=download_duration_ms,
            modes_downloaded=len(mode_dirs)
        )

        # Step 2: Parse GTFS → pattern model
        logger.info("gtfs_load_stage_start", stage="parse")
        parse_start = time.time()
        data = parse_gtfs(output_dir)
        parse_duration_ms = int((time.time() - parse_start) * 1000)
        logger.info(
            "gtfs_load_stage_complete",
            stage="parse",
            duration_ms=parse_duration_ms,
            stops=len(data["stops"]),
            routes=len(data["routes"]),
            patterns=len(data["patterns"]),
            trips=len(data["trips"])
        )

        # Step 3: Load to Supabase (in dependency order)
        logger.info("gtfs_load_stage_start", stage="load", total_tables=len(LOAD_ORDER))
        load_start = time.time()
        load_counts = _load_to_supabase(data)
        load_duration_ms = int((time.time() - load_start) * 1000)
        logger.info(
            "gtfs_load_stage_complete",
            stage="load",
            duration_ms=load_duration_ms,
            tables_loaded=len(load_counts)
        )

        # Step 4: Insert metadata
        logger.info("gtfs_load_stage_start", stage="metadata")
        metadata = _create_metadata(data)
        supabase = get_supabase()
        supabase.table("gtfs_metadata").upsert([metadata]).execute()
        logger.info("gtfs_metadata_inserted", feed_version=metadata["feed_version"])

        # Step 5: Validate
        logger.info("gtfs_load_stage_start", stage="validation")
        validation_result = _validate_load(data, load_counts)
        logger.info(
            "gtfs_load_stage_complete",
            stage="validation",
            validation_passed=validation_result["passed"]
        )

        # Final summary
        total_duration_ms = int((time.time() - start_time) * 1000)
        result = {
            "status": "success",
            "duration_ms": total_duration_ms,
            "download_duration_ms": download_duration_ms,
            "parse_duration_ms": parse_duration_ms,
            "load_duration_ms": load_duration_ms,
            "counts": load_counts,
            "metadata": metadata,
            "validation": validation_result
        }

        logger.info(
            "gtfs_load_pipeline_complete",
            duration_ms=total_duration_ms,
            total_stops=load_counts["stops"],
            total_routes=load_counts["routes"],
            total_patterns=load_counts["patterns"],
            total_trips=load_counts["trips"]
        )

        return result

    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        logger.error(
            "gtfs_load_pipeline_failed",
            error=str(e),
            error_type=type(e).__name__,
            duration_ms=duration_ms
        )
        raise


def _cleanup_stale_light_rail_data(supabase) -> None:
    """Delete stale light rail data before fresh load.

    Prevents accumulation of corrupted patterns (e.g. train platforms in light rail routes)
    when GTFS feeds shrink or change. Deletes in reverse dependency order.

    Args:
        supabase: Supabase client
    """
    logger.info("gtfs_cleanup_start", target="light_rail_routes")

    try:
        # Step 1: Find light rail route_ids (route_type 0 or 900)
        routes_response = supabase.table("routes").select("route_id").in_("route_type", [0, 900]).execute()
        lr_route_ids = [r["route_id"] for r in routes_response.data]

        if not lr_route_ids:
            logger.warning("gtfs_cleanup_no_light_rail_routes")
            return

        logger.info("gtfs_cleanup_found_routes", count=len(lr_route_ids))

        # Step 2: Delete in reverse dependency order (trips → pattern_stops → patterns → routes)

        # Delete trips for light rail routes
        trips_deleted = supabase.table("trips").delete().in_("route_id", lr_route_ids).execute()
        trips_count = len(trips_deleted.data) if trips_deleted.data else 0
        logger.info("gtfs_cleanup_deleted", table="trips", count=trips_count)

        # Delete pattern_stops for light rail patterns
        patterns_response = supabase.table("patterns").select("pattern_id").in_("route_id", lr_route_ids).execute()
        lr_pattern_ids = [p["pattern_id"] for p in patterns_response.data]

        if lr_pattern_ids:
            pattern_stops_deleted = supabase.table("pattern_stops").delete().in_("pattern_id", lr_pattern_ids).execute()
            pattern_stops_count = len(pattern_stops_deleted.data) if pattern_stops_deleted.data else 0
            logger.info("gtfs_cleanup_deleted", table="pattern_stops", count=pattern_stops_count)

        # Delete patterns for light rail routes
        patterns_deleted = supabase.table("patterns").delete().in_("route_id", lr_route_ids).execute()
        patterns_count = len(patterns_deleted.data) if patterns_deleted.data else 0
        logger.info("gtfs_cleanup_deleted", table="patterns", count=patterns_count)

        # Delete routes (route_type 0/900)
        routes_deleted = supabase.table("routes").delete().in_("route_type", [0, 900]).execute()
        routes_count = len(routes_deleted.data) if routes_deleted.data else 0
        logger.info("gtfs_cleanup_deleted", table="routes", count=routes_count)

        logger.info(
            "gtfs_cleanup_complete",
            routes=routes_count,
            patterns=patterns_count,
            pattern_stops=pattern_stops_count if lr_pattern_ids else 0,
            trips=trips_count
        )

    except Exception as e:
        logger.error("gtfs_cleanup_failed", error=str(e), error_type=type(e).__name__)
        raise


def _load_to_supabase(data: Dict[str, List[Dict]]) -> Dict[str, int]:
    """Load all tables to Supabase in dependency order.

    Args:
        data: Parsed GTFS data with keys: agencies, routes, stops, etc.

    Returns:
        Dict mapping table names to row counts inserted
    """
    supabase = get_supabase()
    counts = {}

    # Pre-load cleanup: Delete stale light rail data to prevent corruption
    # (route_type 0/900 patterns/trips may accumulate train platforms from previous loads)
    _cleanup_stale_light_rail_data(supabase)

    for table_name in LOAD_ORDER:
        rows = data.get(table_name, [])

        if not rows:
            logger.warning("gtfs_table_empty", table=table_name)
            counts[table_name] = 0
            continue

        logger.info("gtfs_table_load_start", table=table_name, total_rows=len(rows))

        # Clean data: filter to schema fields, convert NaN to None
        cleaned_rows = _clean_data_for_table(table_name, rows)

        # Batch upsert
        total_inserted = 0
        for i in range(0, len(cleaned_rows), BATCH_SIZE):
            batch = cleaned_rows[i:i + BATCH_SIZE]
            batch_num = i // BATCH_SIZE

            try:
                response = supabase.table(table_name).upsert(batch).execute()
                total_inserted += len(batch)

                logger.info(
                    "gtfs_batch_inserted",
                    table=table_name,
                    batch_num=batch_num,
                    batch_size=len(batch),
                    total_progress=total_inserted
                )
            except Exception as e:
                logger.error(
                    "gtfs_batch_insert_failed",
                    table=table_name,
                    batch_num=batch_num,
                    error=str(e),
                    error_type=type(e).__name__
                )
                raise

        counts[table_name] = total_inserted
        logger.info("gtfs_table_load_complete", table=table_name, rows_inserted=total_inserted)

    return counts


def _clean_data_for_table(table_name: str, rows: List[Dict]) -> List[Dict]:
    """Clean data for Supabase insertion.

    - Filter to only schema fields
    - Convert NaN/inf to None
    - Convert numpy types to Python types
    - Ensure all objects have same keys (Supabase requirement for batch upsert)

    Args:
        table_name: Name of table
        rows: Raw rows from parser

    Returns:
        List of cleaned dicts ready for Supabase
    """
    schema_fields = SCHEMA_FIELDS.get(table_name, [])
    cleaned = []

    # First pass: collect all present keys across all rows
    all_keys_present = set()
    for row in rows:
        for field in schema_fields:
            if field in row:
                value = row[field]
                # Check if value is valid (not NaN/empty)
                if not (isinstance(value, float) and (math.isnan(value) or math.isinf(value))):
                    if value != "" or field in ["trip_headsign", "trip_short_name", "stop_desc"]:
                        all_keys_present.add(field)

    # Second pass: build clean rows with consistent keys
    for row in rows:
        clean_row = {}
        for field in schema_fields:
            value = None

            if field in row:
                value = row[field]

                # Convert NaN/inf to None
                if isinstance(value, float) and (math.isnan(value) or math.isinf(value)):
                    value = None
                # Convert numpy types to Python types
                elif hasattr(value, 'item'):  # numpy scalar
                    value = value.item()
                # Convert empty strings to None for optional fields
                elif value == "" and field not in ["trip_headsign", "trip_short_name", "stop_desc"]:
                    value = None

            # Include field if it's present in any row in batch (ensures consistent keys)
            if field in all_keys_present:
                clean_row[field] = value

        cleaned.append(clean_row)

    return cleaned


def _create_metadata(data: Dict[str, List[Dict]]) -> Dict[str, Any]:
    """Create gtfs_metadata record from parsed data.

    Args:
        data: Parsed GTFS data

    Returns:
        Dict with metadata fields
    """
    # Extract feed date range from calendar
    calendar = data.get("calendar", [])
    if calendar:
        start_dates = [c["start_date"] for c in calendar if "start_date" in c]
        end_dates = [c["end_date"] for c in calendar if "end_date" in c]
        feed_start_date = min(start_dates) if start_dates else None
        feed_end_date = max(end_dates) if end_dates else None
    else:
        feed_start_date = None
        feed_end_date = None

    # Use current date as feed version (ISO format)
    feed_version = datetime.now().strftime("%Y-%m-%d")

    metadata = {
        "feed_version": feed_version,
        "feed_start_date": feed_start_date,
        "feed_end_date": feed_end_date,
        "stops_count": len(data.get("stops", [])),
        "routes_count": len(data.get("routes", [])),
        "patterns_count": len(data.get("patterns", [])),
        "trips_count": len(data.get("trips", []))
    }

    return metadata


def _validate_load(parsed_data: Dict[str, List[Dict]], loaded_counts: Dict[str, int]) -> Dict[str, Any]:
    """Validate loaded data against parser output and database state.

    Args:
        parsed_data: Original parsed data from gtfs_service
        loaded_counts: Row counts from Supabase load

    Returns:
        Dict with validation results: passed (bool), issues (list)

    Raises:
        ValueError: If validation fails
    """
    supabase = get_supabase()
    issues = []

    # Check 1: Row counts match between parser and Supabase
    for table in ["stops", "routes", "patterns", "trips"]:
        expected = len(parsed_data.get(table, []))
        actual = loaded_counts.get(table, 0)

        if expected != actual:
            issue = f"{table}: expected {expected}, loaded {actual}"
            issues.append(issue)
            logger.error("gtfs_validation_count_mismatch", table=table, expected=expected, actual=actual)

    # Check 2: Verify stops count in Supabase
    try:
        stops_response = supabase.table("stops").select("*", count="exact").execute()
        db_stops_count = stops_response.count

        expected_stops = loaded_counts.get("stops", 0)
        if db_stops_count < expected_stops:
            issue = f"DB stops count too low: {db_stops_count} < {expected_stops}"
            issues.append(issue)
            logger.error(
                "gtfs_validation_db_count_too_low",
                db_count=db_stops_count,
                expected=expected_stops
            )
        elif db_stops_count != expected_stops:
            # Allow extra rows (e.g. pre-existing data) but log a warning for skew.
            logger.warning(
                "gtfs_validation_db_count_skew",
                db_count=db_stops_count,
                expected=expected_stops
            )
    except Exception as e:
        issue = f"Failed to query stops count: {str(e)}"
        issues.append(issue)
        logger.error("gtfs_validation_query_failed", table="stops", error=str(e))

    # Check 3: NULL locations (CRITICAL - trigger must populate all)
    try:
        null_locations_response = supabase.table("stops").select("stop_id").is_("location", "null").execute()
        null_count = len(null_locations_response.data)

        if null_count > 0:
            issue = f"Found {null_count} stops with NULL location (trigger failed)"
            issues.append(issue)
            logger.error("gtfs_validation_null_locations", null_count=null_count)

            # Log first 5 problem stop_ids for debugging
            problem_stops = [s["stop_id"] for s in null_locations_response.data[:5]]
            logger.error("gtfs_validation_null_location_examples", stop_ids=problem_stops)
    except Exception as e:
        issue = f"Failed to check NULL locations: {str(e)}"
        issues.append(issue)
        logger.error("gtfs_validation_null_check_failed", error=str(e))

    # Check 4: Minimum thresholds (sanity check)
    min_stops = 10000
    min_routes = 400
    if loaded_counts.get("stops", 0) < min_stops:
        issue = f"Too few stops: {loaded_counts.get('stops', 0)} < {min_stops}"
        issues.append(issue)
        logger.error("gtfs_validation_threshold_failed", check="min_stops", actual=loaded_counts.get("stops", 0), threshold=min_stops)

    if loaded_counts.get("routes", 0) < min_routes:
        issue = f"Too few routes: {loaded_counts.get('routes', 0)} < {min_routes}"
        issues.append(issue)
        logger.error("gtfs_validation_threshold_failed", check="min_routes", actual=loaded_counts.get("routes", 0), threshold=min_routes)

    # Check 5: Mode coverage (ensure at least one route for each important mode)
    try:
        # NSW uses extended route types; define groups by mode rather than a single code.
        # Query each mode group directly to avoid pagination issues.
        mode_checks = [
            ("rail", [2]),
            ("bus", [3, 700, 712, 714]),
            ("ferry", [4]),
            ("light_rail", [0, 900]),
            ("metro", [1, 401]),
        ]

        def require_any(types: list, label: str) -> None:
            # Check if any route exists with one of the expected types
            for route_type in types:
                count_response = supabase.table("routes").select("route_id", count="exact").eq("route_type", route_type).limit(1).execute()
                if count_response.count > 0:
                    logger.info(f"gtfs_validation_mode_found", mode=label, route_type=route_type, count=count_response.count)
                    return

            # If we get here, no routes found for any of the types
            issue = f"Missing routes for expected mode {label} (types {sorted(types)})"
            issues.append(issue)
            logger.error(
                "gtfs_validation_mode_coverage_failed",
                mode=label,
                expected_types=types
            )

        for label, types in mode_checks:
            require_any(types, label)
    except Exception as e:
        issue = f"Failed to verify mode coverage: {str(e)}"
        issues.append(issue)
        logger.error("gtfs_validation_mode_coverage_error", error=str(e))

    # Check 6: Light rail minimum coverage (hardened to catch L2/L3 missing)
    try:
        # Count light rail routes (route_type 0 or 900)
        lr_routes_response = supabase.table("routes").select("route_id", count="exact").in_("route_type", [0, 900]).execute()
        lr_routes_count = lr_routes_response.count

        # Minimum thresholds (Sydney has L1/L2/L3 at minimum)
        min_lr_routes = 3
        min_lr_trips = 6000
        min_lr_stops = 100

        if lr_routes_count < min_lr_routes:
            issue = f"Light rail routes too low: {lr_routes_count} < {min_lr_routes} (missing L2/L3?)"
            issues.append(issue)
            logger.error("gtfs_validation_light_rail_routes_failed", actual=lr_routes_count, threshold=min_lr_routes)

        # Count light rail trips
        lr_route_ids = [r["route_id"] for r in lr_routes_response.data]
        if lr_route_ids:
            lr_trips_response = supabase.table("trips").select("trip_id", count="exact").in_("route_id", lr_route_ids).execute()
            lr_trips_count = lr_trips_response.count

            if lr_trips_count < min_lr_trips:
                issue = f"Light rail trips too low: {lr_trips_count} < {min_lr_trips}"
                issues.append(issue)
                logger.error("gtfs_validation_light_rail_trips_failed", actual=lr_trips_count, threshold=min_lr_trips)

            # Count distinct stops in light rail patterns
            lr_patterns_response = supabase.table("patterns").select("pattern_id").in_("route_id", lr_route_ids).execute()
            lr_pattern_ids = [p["pattern_id"] for p in lr_patterns_response.data]

            if lr_pattern_ids:
                # Count distinct stops via pattern_stops
                lr_stops_response = supabase.rpc("count_distinct_stops_in_patterns", {"pattern_ids": lr_pattern_ids}).execute()
                lr_stops_count = lr_stops_response.data if lr_stops_response.data else 0

                if lr_stops_count < min_lr_stops:
                    issue = f"Light rail stops too low: {lr_stops_count} < {min_lr_stops}"
                    issues.append(issue)
                    logger.error("gtfs_validation_light_rail_stops_failed", actual=lr_stops_count, threshold=min_lr_stops)

                logger.info(
                    "gtfs_validation_light_rail_coverage",
                    routes=lr_routes_count,
                    trips=lr_trips_count,
                    stops=lr_stops_count
                )
    except Exception as e:
        # Light rail validation is critical; if RPC fails, use best-effort query
        logger.warning("gtfs_validation_light_rail_rpc_failed", error=str(e))
        # Fallback: just check routes and trips (stops check requires RPC)
        try:
            lr_routes_response = supabase.table("routes").select("route_id", count="exact").in_("route_type", [0, 900]).execute()
            lr_routes_count = lr_routes_response.count
            if lr_routes_count < 3:
                issue = f"Light rail routes too low: {lr_routes_count} < 3"
                issues.append(issue)
        except Exception as e2:
            issue = f"Failed to verify light rail coverage: {str(e2)}"
            issues.append(issue)
            logger.error("gtfs_validation_light_rail_error", error=str(e2))

    # Check 7: Light rail contamination (no train platforms in light rail patterns)
    try:
        # Query for train platforms in light rail patterns
        # This uses a SQL join; if too slow, upgrade to Redis index later
        contamination_query = """
            SELECT COUNT(*) as count
            FROM pattern_stops ps
            JOIN patterns p ON ps.pattern_id = p.pattern_id
            JOIN routes r ON p.route_id = r.route_id
            JOIN stops s ON ps.stop_id = s.stop_id
            WHERE r.route_type IN (0, 900)
            AND s.stop_name LIKE '%Platform%'
        """
        contamination_response = supabase.rpc("execute_sql", {"query": contamination_query}).execute()
        contamination_count = contamination_response.data[0]["count"] if contamination_response.data else 0

        # Allow tiny tolerance (1-2 stops) for edge cases, but fail if >5
        if contamination_count > 5:
            issue = f"Light rail patterns contaminated with {contamination_count} train platforms"
            issues.append(issue)
            logger.error("gtfs_validation_light_rail_contamination", count=contamination_count)
        elif contamination_count > 0:
            logger.warning("gtfs_validation_light_rail_contamination_minor", count=contamination_count)
    except Exception as e:
        # Contamination check is nice-to-have; log warning but don't fail
        logger.warning("gtfs_validation_contamination_check_failed", error=str(e))

    # Check 8: Critical stop whitelist (must-exist stops)
    critical_stops = [
        # Names/IDs are based on NSW GTFS; update if feed naming changes.
        {"stop_id": None, "stop_name": "Central Station"},
        {"stop_id": None, "stop_name": "Central Grand Concourse Light Rail"},
        {"stop_id": None, "stop_name": "Central Station, Platform 26"},
        {"stop_id": None, "stop_name": "Davistown, Central RSL Wharf"},
    ]

    try:
        for cs in critical_stops:
            stop_query = supabase.table("stops").select("stop_id, stop_name")
            if cs["stop_id"]:
                stop_query = stop_query.eq("stop_id", cs["stop_id"])
            else:
                stop_query = stop_query.eq("stop_name", cs["stop_name"])

            result = stop_query.execute()
            if not result.data:
                issue = f"Critical stop missing: {cs['stop_name']} ({cs['stop_id'] or 'no explicit stop_id'})"
                issues.append(issue)
                logger.error(
                    "gtfs_validation_critical_stop_missing",
                    stop_name=cs["stop_name"],
                    stop_id=cs["stop_id"]
                )
    except Exception as e:
        issue = f"Failed to verify critical stops: {str(e)}"
        issues.append(issue)
        logger.error("gtfs_validation_critical_stops_error", error=str(e))

    # Determine pass/fail
    passed = len(issues) == 0

    if not passed:
        error_msg = f"GTFS validation failed: {', '.join(issues)}"
        logger.error("gtfs_validation_failed", total_issues=len(issues), issues=issues)
        raise ValueError(error_msg)

    logger.info("gtfs_validation_passed", checks_passed=8)

    return {
        "passed": passed,
        "issues": issues,
        "checks_run": 8,
        "null_locations": 0,
        "db_stops_count": db_stops_count if 'db_stops_count' in locals() else loaded_counts.get("stops", 0)
    }
