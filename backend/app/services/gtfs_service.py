"""GTFS parser and pattern model extractor.

Parses NSW GTFS feeds (6 modes) into pattern model for Supabase storage.
Pattern model: Group trips by identical stop sequences, factor out offsets.

Key operations:
- Merge 6 mode directories into single dataset
- Sydney bbox filtering: lat [-34.5, -33.3], lon [150.5, 151.5]
- Pattern extraction: trips with same stop_sequence → pattern_id
- Offset calculation: median arrival/departure offset from trip start
"""

import time
from pathlib import Path
from typing import Dict, List, Tuple
import pandas as pd
import numpy as np

from app.utils.logging import get_logger

logger = get_logger(__name__)

# Sydney bbox coordinates (from DATA_ARCHITECTURE.md, checkpoint design)
SYDNEY_BBOX = {
    "lat_min": -34.5,
    "lat_max": -33.3,
    "lon_min": 150.5,
    "lon_max": 151.5
}

# Expected mode directories from checkpoint 1
MODE_DIRS = [
    "sydneytrains",
    "metro",
    "buses",
    "sydneyferries",
    "mff",
    "lightrail"
]

# Required GTFS files
REQUIRED_FILES = [
    "agency.txt",
    "stops.txt",
    "routes.txt",
    "trips.txt",
    "stop_times.txt",
    "calendar.txt"
]


def parse_gtfs(gtfs_base_dir: str) -> Dict:
    """Parse GTFS feeds from multiple mode directories.

    Args:
        gtfs_base_dir: Base directory containing mode subdirectories
                      (e.g., 'temp/gtfs-downloads/')

    Returns:
        Dict with keys: agencies, routes, stops, patterns, pattern_stops, trips, calendar, calendar_dates
        Each value is a list of dicts ready for Supabase insertion

    Raises:
        ValueError: If required files missing or Sydney filtering produces no stops
    """
    start_time = time.time()
    base_path = Path(gtfs_base_dir)

    logger.info("gtfs_parse_start", input_dir=gtfs_base_dir, total_modes=len(MODE_DIRS))

    # Step 1: Load and merge all mode feeds
    merged_data = _load_and_merge_feeds(base_path)

    # Step 2: Sydney filtering
    filtered_data = _apply_sydney_filter(merged_data)

    # Step 3: Pattern extraction
    patterns_data = _extract_patterns(filtered_data)

    # Step 4: Compile output
    result = {
        "agencies": filtered_data["agencies"],
        "routes": filtered_data["routes"],
        "stops": filtered_data["stops"],
        "patterns": patterns_data["patterns"],
        "pattern_stops": patterns_data["pattern_stops"],
        "trips": patterns_data["trips"],
        "calendar": filtered_data["calendar"],
        "calendar_dates": filtered_data.get("calendar_dates", [])
    }

    duration_ms = int((time.time() - start_time) * 1000)

    logger.info(
        "gtfs_parse_complete",
        stops=len(result["stops"]),
        routes=len(result["routes"]),
        patterns=len(result["patterns"]),
        trips=len(result["trips"]),
        duration_ms=duration_ms
    )

    return result


def _load_and_merge_feeds(base_path: Path) -> Dict:
    """Load GTFS CSV files from all mode directories and merge.

    Args:
        base_path: Base directory with mode subdirectories

    Returns:
        Dict with merged DataFrames: agencies, stops, routes, trips, stop_times, calendar, calendar_dates
    """
    all_agencies = []
    all_stops = []
    all_routes = []
    all_trips = []
    all_stop_times = []
    all_calendar = []
    all_calendar_dates = []

    for mode in MODE_DIRS:
        mode_path = base_path / mode

        if not mode_path.exists():
            logger.warning("gtfs_mode_missing", mode=mode, path=str(mode_path))
            continue

        # Validate required files exist
        missing_files = [f for f in REQUIRED_FILES if not (mode_path / f).exists()]
        if missing_files:
            logger.error("gtfs_missing_files", mode=mode, missing=missing_files)
            raise ValueError(f"Mode {mode} missing required files: {missing_files}")

        # Read CSV files
        try:
            agencies = pd.read_csv(mode_path / "agency.txt", dtype=str)
            stops = pd.read_csv(mode_path / "stops.txt", dtype=str)
            routes = pd.read_csv(mode_path / "routes.txt", dtype=str)
            trips = pd.read_csv(mode_path / "trips.txt", dtype=str)
            stop_times = pd.read_csv(mode_path / "stop_times.txt", dtype=str)
            calendar = pd.read_csv(mode_path / "calendar.txt", dtype=str)

            # Prefix IDs to avoid conflicts across modes
            trips["trip_id"] = mode + "_" + trips["trip_id"].astype(str)
            stop_times["trip_id"] = mode + "_" + stop_times["trip_id"].astype(str)

            all_agencies.append(agencies)
            all_stops.append(stops)
            all_routes.append(routes)
            all_trips.append(trips)
            all_stop_times.append(stop_times)
            all_calendar.append(calendar)

            # calendar_dates is optional
            calendar_dates_path = mode_path / "calendar_dates.txt"
            if calendar_dates_path.exists():
                calendar_dates = pd.read_csv(calendar_dates_path, dtype=str)
                all_calendar_dates.append(calendar_dates)

            logger.info(
                "gtfs_mode_loaded",
                mode=mode,
                stops=len(stops),
                routes=len(routes),
                trips=len(trips),
                stop_times=len(stop_times)
            )

        except Exception as e:
            logger.error("gtfs_mode_load_failed", mode=mode, error=str(e), error_type=type(e).__name__)
            raise

    # Merge all modes
    merged = {
        "agencies": pd.concat(all_agencies, ignore_index=True),
        "stops": pd.concat(all_stops, ignore_index=True),
        "routes": pd.concat(all_routes, ignore_index=True),
        "trips": pd.concat(all_trips, ignore_index=True),
        "stop_times": pd.concat(all_stop_times, ignore_index=True),
        "calendar": pd.concat(all_calendar, ignore_index=True)
    }

    if all_calendar_dates:
        merged["calendar_dates"] = pd.concat(all_calendar_dates, ignore_index=True)

    logger.info(
        "gtfs_merge_complete",
        total_stops=len(merged["stops"]),
        total_routes=len(merged["routes"]),
        total_trips=len(merged["trips"]),
        total_stop_times=len(merged["stop_times"])
    )

    return merged


def _apply_sydney_filter(data: Dict) -> Dict:
    """Filter stops to Sydney bbox, remove trips with no Sydney stops.

    Args:
        data: Dict with DataFrames (stops, routes, trips, stop_times, etc.)

    Returns:
        Dict with filtered DataFrames
    """
    stops_before = len(data["stops"])

    # Convert lat/lon to float for filtering
    stops = data["stops"].copy()
    stops["stop_lat"] = pd.to_numeric(stops["stop_lat"], errors="coerce")
    stops["stop_lon"] = pd.to_numeric(stops["stop_lon"], errors="coerce")

    # Apply bbox filter
    sydney_stops = stops[
        (stops["stop_lat"] >= SYDNEY_BBOX["lat_min"]) &
        (stops["stop_lat"] <= SYDNEY_BBOX["lat_max"]) &
        (stops["stop_lon"] >= SYDNEY_BBOX["lon_min"]) &
        (stops["stop_lon"] <= SYDNEY_BBOX["lon_max"])
    ]

    stops_after = len(sydney_stops)
    reduction_pct = int((1 - stops_after / stops_before) * 100) if stops_before > 0 else 0

    if stops_after == 0:
        logger.error("sydney_filter_empty", bbox=SYDNEY_BBOX)
        raise ValueError("Sydney filtering removed all stops - check bbox coordinates")

    sydney_stop_ids = set(sydney_stops["stop_id"])

    # Filter stop_times to only Sydney stops
    stop_times = data["stop_times"]
    sydney_stop_times = stop_times[stop_times["stop_id"].isin(sydney_stop_ids)]

    # Keep trips with at least 1 Sydney stop
    trip_ids_with_sydney_stops = set(sydney_stop_times["trip_id"].unique())
    trips = data["trips"]
    sydney_trips = trips[trips["trip_id"].isin(trip_ids_with_sydney_stops)]

    # Filter routes to only those with Sydney trips
    route_ids_with_trips = set(sydney_trips["route_id"].unique())
    routes = data["routes"]
    sydney_routes = routes[routes["route_id"].isin(route_ids_with_trips)]

    # Filter calendar to only service_ids used by Sydney trips
    service_ids = set(sydney_trips["service_id"].unique())
    calendar = data["calendar"]
    sydney_calendar = calendar[calendar["service_id"].isin(service_ids)]

    calendar_dates = data.get("calendar_dates")
    sydney_calendar_dates = None
    if calendar_dates is not None:
        sydney_calendar_dates = calendar_dates[calendar_dates["service_id"].isin(service_ids)]

    logger.info(
        "sydney_filtering_complete",
        stops_before=stops_before,
        stops_after=stops_after,
        reduction_pct=reduction_pct,
        trips_before=len(trips),
        trips_after=len(sydney_trips)
    )

    # Deduplicate stops (some stops appear in multiple mode feeds)
    # Keep first occurrence (based on order: trains, metro, buses, ferries, lightrail)
    sydney_stops_dedup = sydney_stops.drop_duplicates(subset=["stop_id"], keep="first")
    deduplicated_count = len(sydney_stops) - len(sydney_stops_dedup)
    if deduplicated_count > 0:
        logger.info("stops_deduplicated", duplicates_removed=deduplicated_count)

    # Convert to list of dicts for easier Supabase insertion
    result = {
        "agencies": data["agencies"].to_dict("records"),
        "stops": sydney_stops_dedup.to_dict("records"),
        "routes": sydney_routes.to_dict("records"),
        "trips": sydney_trips,  # Keep as DataFrame for pattern extraction
        "stop_times": sydney_stop_times,  # Keep as DataFrame
        "calendar": sydney_calendar.to_dict("records"),
    }

    if sydney_calendar_dates is not None:
        result["calendar_dates"] = sydney_calendar_dates.to_dict("records")

    return result


def _extract_patterns(data: Dict) -> Dict:
    """Extract pattern model from trips and stop_times.

    Groups trips by identical stop sequences, assigns pattern_id,
    calculates median offsets.

    Args:
        data: Dict with trips, stop_times DataFrames

    Returns:
        Dict with patterns, pattern_stops, trips lists
    """
    trips = data["trips"].copy()
    stop_times = data["stop_times"].copy()

    # Convert stop_sequence to int for sorting
    stop_times["stop_sequence"] = pd.to_numeric(stop_times["stop_sequence"], errors="coerce")
    stop_times = stop_times.sort_values(["trip_id", "stop_sequence"])

    # Convert arrival/departure times to seconds for offset calculation (vectorized)
    stop_times["arrival_time_secs"] = stop_times["arrival_time"].apply(_time_to_seconds)
    stop_times["departure_time_secs"] = stop_times["departure_time"].apply(_time_to_seconds)

    # Calculate trip start time (first stop departure)
    trip_start_times = stop_times.groupby("trip_id")["departure_time_secs"].first()

    # Create stop sequence signature for each trip using agg (faster than apply)
    trip_sequences = (
        stop_times.groupby("trip_id", as_index=False)["stop_id"]
        .agg(stop_sequence_sig=lambda x: "|".join(x.astype(str)))
        .set_index("trip_id")["stop_sequence_sig"]
    )

    # Merge trip metadata
    trips["stop_sequence_sig"] = trips["trip_id"].map(trip_sequences)
    trips["start_time_secs"] = trips["trip_id"].map(trip_start_times)
    trips["direction_id"] = trips["direction_id"].fillna("0")

    # Group by route_id, direction_id, and stop_sequence signature
    pattern_key_cols = ["route_id", "direction_id", "stop_sequence_sig"]
    pattern_groups = trips.groupby(pattern_key_cols, as_index=False).agg(
        pattern_trips=("trip_id", lambda x: list(x)),
        representative_trip=("trip_id", "first")
    )

    # Assign pattern_id to each unique pattern
    pattern_groups["pattern_id"] = [f"P{i:06d}" for i in range(len(pattern_groups))]

    # Create patterns list
    patterns = pattern_groups[["pattern_id", "route_id", "direction_id"]].copy()
    patterns["direction_id"] = patterns["direction_id"].apply(
        lambda x: int(x) if x != "" and x != "0" else 0
    )
    patterns_list = patterns.to_dict("records")

    # Map trip_id to pattern_id for efficient lookup
    trip_to_pattern = {}
    for _, row in pattern_groups.iterrows():
        pattern_id = row["pattern_id"]
        for trip_id in row["pattern_trips"]:
            trip_to_pattern[trip_id] = pattern_id

    # Add pattern_id to stop_times in bulk (vectorized)
    stop_times["pattern_id"] = stop_times["trip_id"].map(trip_to_pattern)

    # Add start times to stop_times for offset calculation
    stop_times["trip_start_secs"] = stop_times["trip_id"].map(trip_start_times)

    # Calculate offsets (vectorized)
    stop_times["arrival_offset"] = (
        stop_times["arrival_time_secs"] - stop_times["trip_start_secs"]
    )
    stop_times["departure_offset"] = (
        stop_times["departure_time_secs"] - stop_times["trip_start_secs"]
    )

    # Calculate median offsets per pattern/stop_sequence (vectorized groupby)
    # Group by (pattern_id, stop_sequence) - this is the primary key in DB
    # If a stop appears twice in same pattern (circular routes), use first occurrence
    pattern_stops = (
        stop_times.groupby(["pattern_id", "stop_sequence"], as_index=False)
        .agg({
            "stop_id": "first",  # Use first stop_id if duplicates (shouldn't happen)
            "arrival_offset": "median",
            "departure_offset": "median"
        })
    )

    # Convert to output format
    pattern_stops_list = []
    for _, row in pattern_stops.iterrows():
        pattern_stops_list.append({
            "pattern_id": str(row["pattern_id"]),
            "stop_id": str(row["stop_id"]),
            "stop_sequence": int(row["stop_sequence"]),
            "arrival_offset_secs": int(row["arrival_offset"]),
            "departure_offset_secs": int(row["departure_offset"])
        })

    # Prepare trips output
    trips["pattern_id"] = trips["trip_id"].map(trip_to_pattern)

    # Include all fields needed by Supabase schema
    output_fields = ["trip_id", "route_id", "pattern_id", "service_id", "trip_headsign"]

    # Add optional fields if they exist
    if "trip_short_name" in trips.columns:
        output_fields.append("trip_short_name")
    if "direction_id" in trips.columns:
        output_fields.append("direction_id")
    if "block_id" in trips.columns:
        output_fields.append("block_id")
    if "wheelchair_accessible" in trips.columns:
        output_fields.append("wheelchair_accessible")

    trips_output = trips[output_fields].copy()
    trips_output["trip_headsign"] = trips_output["trip_headsign"].fillna("")
    trips_list = trips_output.to_dict("records")

    avg_stops_per_pattern = (
        len(pattern_stops_list) / len(patterns_list) if len(patterns_list) > 0 else 0
    )

    logger.info(
        "pattern_extraction_complete",
        patterns=len(patterns_list),
        avg_stops_per_pattern=round(avg_stops_per_pattern, 1),
        total_trips=len(trips_list)
    )

    return {
        "patterns": patterns_list,
        "pattern_stops": pattern_stops_list,
        "trips": trips_list
    }


def _time_to_seconds(time_str: str) -> int:
    """Convert GTFS time string (HH:MM:SS) to seconds since midnight.

    GTFS allows hours >= 24 for trips after midnight.

    Args:
        time_str: Time string in format "HH:MM:SS"

    Returns:
        Seconds since midnight (can be > 86400 for next-day times)
    """
    if pd.isna(time_str) or time_str == "":
        return 0

    try:
        parts = time_str.strip().split(":")
        hours = int(parts[0])
        minutes = int(parts[1])
        seconds = int(parts[2])
        return hours * 3600 + minutes * 60 + seconds
    except (ValueError, IndexError):
        logger.warning("time_parse_failed", time_str=time_str)
        return 0
