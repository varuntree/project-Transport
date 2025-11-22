"""Real-Time Departures Service - Checkpoint 4.

Merges static schedules from Supabase with Redis GTFS-RT delays.
Service returns departures with delay_s, realtime flag, graceful degradation.

Architecture:
- Step 1: Fetch static schedules from Supabase (pattern model query)
- Step 2: Determine modes from route IDs (heuristic)
- Step 3: Fetch Redis RT delays (gzip blobs per mode)
- Step 4: Merge static + RT, sort by realtime_time_secs

Graceful degradation:
- Redis miss or gzip error → delay_s=0, realtime=false (static fallback)
- Trip ID mismatch → delay_s=0 (static schedule)
"""

import gzip
import json
import time
import redis
from typing import Optional, List, Dict, Set

from app.db.supabase_client import get_supabase
from app.config import settings
from app.utils.logging import get_logger

logger = get_logger(__name__)

# Redis client for binary blobs (gzipped data)
# Note: Separate from app.db.redis_client which uses decode_responses=True (strings)
_redis_binary_client: Optional[redis.Redis] = None


def get_redis_binary() -> redis.Redis:
    """Get Redis client for binary blob operations (gzipped data).

    Uses decode_responses=False to preserve binary data for gzip decompression.
    Separate from app.db.redis_client which returns strings.
    """
    global _redis_binary_client
    if _redis_binary_client is None:
        _redis_binary_client = redis.from_url(
            settings.REDIS_URL,
            decode_responses=False,
            max_connections=10
        )
    return _redis_binary_client


def determine_mode(route_id: str) -> str:
    """Determine transport mode from route ID prefix.

    Heuristic based on NSW GTFS route_id patterns:
    - T*, BMT* → sydneytrains
    - M* (except MFF) → metro
    - MFF → ferries (Manly Fast Ferry)
    - F*, 9-F* → ferries
    - L*, IWLR* → lightrail
    - else → buses

    Args:
        route_id: GTFS route_id (e.g., "T1", "M20", "L1", "199", "F1", "MFF", "IWLR-191")

    Returns:
        Mode string for Redis key lookup (sydneytrains, metro, ferries, lightrail, buses)
    """
    if not route_id:
        return "buses"

    route_id_upper = route_id.upper()

    # Check MFF before general M* check
    if route_id_upper == 'MFF':
        return 'ferries'
    elif route_id_upper.startswith('T') or route_id_upper.startswith('BMT'):
        return 'sydneytrains'
    elif route_id_upper.startswith('M') or route_id_upper.startswith('SMNW'):
        return 'metro'
    elif route_id_upper.startswith('F') or route_id_upper.startswith('9-F'):
        return 'ferries'
    elif route_id_upper.startswith('L') or route_id_upper.startswith('IWLR'):
        return 'lightrail'
    else:
        return 'buses'


def get_realtime_departures(
    stop_id: str,
    time_secs_local: Optional[int] = None,
    service_date: Optional[str] = None,
    direction: str = "future",
    limit: int = 10,
) -> List[Dict]:
    """Get real-time departures for a stop (merges static schedules + GTFS-RT delays).

    Args:
        stop_id: GTFS stop_id
        time_secs_local: Seconds since local (Sydney) midnight for filtering; required.
        service_date: Service date in YYYY-MM-DD (Sydney time); required.
        direction: 'past' for earlier departures, 'future' for later (default 'future')
        limit: Max departures to return (default 10)

    Returns:
        List of departure dicts with fields:
        - trip_id, route_short_name/long_name/type/color, headsign
        - scheduled_time_secs, realtime_time_secs, delay_s, realtime, stop_sequence
        - platform, wheelchair_accessible, occupancy_status (0-8 or None)
    """
    start_time = time.time()

    try:
        supabase = get_supabase()
        redis_binary = get_redis_binary()

        # Backwards compatibility: if caller omits time/date, derive using Sydney timezone
        if service_date is None or time_secs_local is None:
            import pytz
            from datetime import datetime

            sydney_tz = pytz.timezone('Australia/Sydney')
            now_dt = datetime.now(sydney_tz)
            service_date = now_dt.strftime("%Y-%m-%d") if service_date is None else service_date
            if time_secs_local is None:
                midnight = now_dt.replace(hour=0, minute=0, second=0, microsecond=0)
                time_secs_local = int((now_dt - midnight).total_seconds())

        # Guard against missing/invalid time inputs
        if time_secs_local is None or not (0 <= time_secs_local < 86400):
            raise ValueError("Invalid time_secs_local; must be 0-86399 seconds since local midnight")
        if not service_date:
            raise ValueError("service_date is required")

        # Normalize service_date to GTFS calendar format (YYYYMMDD).
        # GTFS `calendar.txt` stores dates without hyphens; using the hyphenated
        # form causes the SQL filter to miss all rows and return no departures.
        service_date_gtfs = service_date.replace("-", "")

        # Log diagnostic info for debugging identifier handling
        logger.info(
            "departures_lookup_start",
            stop_id=stop_id,
            stop_id_type=type(stop_id).__name__,
            service_date=service_date,
            time_secs_local=time_secs_local
        )

        # Step 1: Fetch static schedules (phase 1 query)
        # Calculate actual departure time: trip_start_time + offset_secs
        # Bidirectional: >= time for future, <= time for past
        # Use parameterized query to prevent SQL injection
        # Params: [stop_id, service_date_gtfs, time_secs_local]
        # $1->>0 is stop_id (text)
        # $1->>1 is service_date_gtfs (text)
        # $1->>2 is time_secs_local (int, cast to integer)
        
        operator = ">=" if direction == "future" else "<="
        sort_order = "ASC" if direction == "future" else "DESC"

        # Expand SQL LIMIT to capture delayed trains outside user window
        # RT delays can push scheduled departures into realtime window (e.g., 07:15 scheduled → 07:42 delayed)
        # Fetch 3x user limit to ensure delayed trains included, then sort/trim after RT merge
        expanded_limit = max(limit * 3, 30)

        query = f"""
        SELECT
            t.trip_id,
            t.trip_headsign,
            t.direction_id,
            t.wheelchair_accessible,
            t.start_time_secs,
            r.route_id,
            r.route_short_name,
            r.route_long_name,
            r.route_type,
            r.route_color,
            ps.departure_offset_secs,
            ps.stop_sequence,
            (t.start_time_secs + ps.departure_offset_secs) as actual_departure_secs
        FROM pattern_stops ps
        JOIN patterns p ON ps.pattern_id = p.pattern_id
        JOIN trips t ON t.pattern_id = p.pattern_id
        JOIN routes r ON t.route_id = r.route_id
        JOIN calendar c ON t.service_id = c.service_id
        WHERE ps.stop_id = ($1->>0)
          AND c.start_date <= ($1->>1)
          AND c.end_date >= ($1->>1)
          AND (t.start_time_secs + ps.departure_offset_secs) {operator} ($1->>2)::integer
        ORDER BY (t.start_time_secs + ps.departure_offset_secs) {sort_order}
        LIMIT {expanded_limit}
        """

        params = [stop_id, service_date_gtfs, time_secs_local]
        result = supabase.rpc("exec_raw_sql", {"query": query, "params": params}).execute()
        static_deps = result.data or []

        if not static_deps:
            # Enhanced diagnostics: distinguish stop_not_found vs no_trips_scheduled
            # Check if stop exists in stops table
            stop_exists_result = supabase.table("stops").select("stop_id").eq("stop_id", stop_id).execute()
            stop_exists = len(stop_exists_result.data) > 0 if stop_exists_result.data else False

            # Check pattern_stops count for this stop (are there ANY trips for this stop?)
            pattern_count_query = "SELECT COUNT(*) as count FROM pattern_stops WHERE stop_id = ($1->>0)"
            pattern_count_result = supabase.rpc("exec_raw_sql", {"query": pattern_count_query, "params": [stop_id]}).execute()
            pattern_stops_count = pattern_count_result.data[0]["count"] if pattern_count_result.data else 0

            logger.warning(
                "no_static_departures",
                stop_id=stop_id,
                stop_exists=stop_exists,
                pattern_stops_count=pattern_stops_count,
                service_date=service_date,
                time_secs=time_secs_local
            )
            # Don't return early - continue to check RT data for RT-only mode
            # (previously returned [] here, blocking RT-only serving)

        # Step 2: Determine modes needed (heuristic from route_ids)
        # If static_deps empty, modes_needed will be empty set (RT merge skipped below)
        modes_needed: Set[str] = {determine_mode(dep['route_id']) for dep in static_deps} if static_deps else set()

        # Step 3: Fetch Redis RT delays + platform codes + occupancy (gzip blobs per mode)
        trip_delays: Dict[str, int] = {}  # {trip_id: delay_s}
        trip_platforms: Dict[str, str] = {}  # {trip_id: platform_code}
        trip_occupancy: Dict[str, int] = {}  # {trip_id: occupancy_status}

        for mode in modes_needed:
            try:
                # Fetch TripUpdates for delays
                tu_key = f'tu:{mode}:v1'
                tu_blob = redis_binary.get(tu_key)

                if tu_blob:
                    # Decompress gzipped JSON blob (blob is bytes with decode_responses=False)
                    decompressed = gzip.decompress(tu_blob)
                    data = json.loads(decompressed)

                    # Extract trip delays + platform codes from stop_time_updates
                    for tu in data:
                        trip_id = tu.get('trip_id')
                        delay_s = tu.get('delay_s', 0)
                        if trip_id:
                            trip_delays[trip_id] = delay_s

                            # Extract platform from first stop_time_update with platform_code
                            # (platform_code may be in stop_time_update, not guaranteed)
                            stop_time_updates = tu.get('stop_time_updates', [])
                            for stu in stop_time_updates:
                                if stu.get('stop_id') == stop_id and stu.get('platform_code'):
                                    trip_platforms[trip_id] = stu['platform_code']
                                    break

                    logger.debug("trip_updates_fetched", mode=mode, trip_count=len(data))
                else:
                    logger.debug("trip_updates_miss", mode=mode, key=tu_key)

                # Fetch VehiclePositions for occupancy
                vp_key = f'vp:{mode}:v1'
                vp_blob = redis_binary.get(vp_key)
                logger.debug(
                    "vp_blob_check",
                    mode=mode,
                    blob_exists=vp_blob is not None,
                    blob_size=len(vp_blob) if vp_blob else 0
                )

                if vp_blob:
                    decompressed = gzip.decompress(vp_blob)
                    vp_data = json.loads(decompressed)

                    # Extract occupancy_status from vehicle positions
                    if vp_data:
                        sample = vp_data[0]
                        logger.debug(
                            "vp_sample",
                            mode=mode,
                            trip_id=sample.get('trip_id'),
                            occupancy_status=sample.get('occupancy_status')
                        )

                    for vp in vp_data:
                        trip_id = vp.get('trip_id')
                        occupancy_status = vp.get('occupancy_status')
                        if trip_id and occupancy_status is not None:
                            trip_occupancy[trip_id] = occupancy_status

                    logger.debug("vehicle_positions_fetched", mode=mode, vehicle_count=len(vp_data))
                else:
                    logger.debug("vehicle_positions_miss", mode=mode, key=vp_key)

            except gzip.BadGzipFile:
                logger.warning("realtime_gzip_error", mode=mode)
            except json.JSONDecodeError as exc:
                logger.warning("realtime_json_error", mode=mode, error=str(exc))
            except Exception as exc:
                logger.warning("realtime_fetch_failed", mode=mode, error=str(exc))

        # Step 4: Merge static + RT
        departures = []

        for dep in static_deps:
            trip_id = dep['trip_id']

            # actual_departure_secs = trip_start_time + departure_offset (calculated in SQL)
            # This is the absolute departure time in seconds since midnight (can be >= 86400 for next-day trips)
            scheduled_time_secs = dep['actual_departure_secs']

            # Get RT delay (default 0 if no data)
            delay_s = trip_delays.get(trip_id, 0)
            realtime_time_secs = scheduled_time_secs + delay_s

            # Get platform from RT data (may be None)
            platform = trip_platforms.get(trip_id)

            # Get occupancy_status from RT data (may be None, enum 0-8)
            occupancy_status = trip_occupancy.get(trip_id)

            # Get wheelchair_accessible from static GTFS (0=unknown, 1=accessible, 2=not accessible)
            wheelchair_accessible = dep.get('wheelchair_accessible', 0)

            # Calculate minutes until (centralized logic)
            # Use time_secs_local (request time) vs realtime_time_secs
            secs_remaining = realtime_time_secs - time_secs_local
            minutes_until = max(0, secs_remaining // 60)

            departures.append({
                'trip_id': trip_id,
                'route_short_name': dep['route_short_name'],
                'route_long_name': dep['route_long_name'],
                'route_type': dep['route_type'],
                'route_color': dep.get('route_color'),
                'headsign': dep['trip_headsign'],
                'scheduled_time_secs': scheduled_time_secs,
                'realtime_time_secs': realtime_time_secs,
                'minutes_until': minutes_until,  # New centralized field
                'delay_s': delay_s,
                'realtime': delay_s != 0,
                'stop_sequence': dep['stop_sequence'],
                'platform': platform,
                'wheelchair_accessible': wheelchair_accessible,
                'occupancy_status': occupancy_status,
            })

        # Sort by realtime departure time
        # For future: earliest first (ascending), for past: latest first (descending)
        departures.sort(key=lambda x: x['realtime_time_secs'], reverse=(direction == "past"))

        # Trim to user-requested limit (after RT merge and sort)
        # SQL fetched expanded_limit to capture delayed trains, now filter to final result set
        departures = departures[:limit]

        # Count realtime vs static
        realtime_count = sum(1 for d in departures if d['realtime'])
        static_count = len(departures) - realtime_count

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info(
            "realtime_departures_fetched",
            stop_id=stop_id,
            service_date=service_date,
            time_secs=time_secs_local,
            total_count=len(departures),
            realtime_count=realtime_count,
            static_count=static_count,
            modes=list(modes_needed),
            duration_ms=duration_ms
        )

        return departures

    except Exception as exc:
        duration_ms = int((time.time() - start_time) * 1000)
        logger.error(
            "realtime_departures_failed",
            stop_id=stop_id,
            service_date=service_date,
            time_secs=time_secs_local,
            error=str(exc),
            duration_ms=duration_ms
        )
        raise


def get_stop_earliest_departure(stop_id: str, service_date: str) -> Optional[int]:
    """Get earliest departure time for a stop from GTFS static data.

    Queries Supabase for MIN(departure_time) for the given stop.
    Used for dynamic pagination boundary instead of static 3900 threshold.

    Args:
        stop_id: GTFS stop_id
        service_date: Service date in YYYY-MM-DD (Sydney time)

    Returns:
        Earliest departure time in seconds-since-midnight, or None if no departures.
    """
    try:
        supabase = get_supabase()

        # Query MIN(departure_time) from stop_times for this stop
        # Use pattern model: stop_times table has stop_id, pattern_id, stop_sequence, departure_time
        result = supabase.table('stop_times') \
            .select('departure_time') \
            .eq('stop_id', stop_id) \
            .order('departure_time', desc=False) \
            .limit(1) \
            .execute()

        if result.data and len(result.data) > 0:
            earliest = result.data[0]['departure_time']
            logger.info(
                "stop_earliest_departure_found",
                stop_id=stop_id,
                earliest_time_secs=earliest
            )
            return earliest
        else:
            logger.warning(
                "stop_earliest_departure_not_found",
                stop_id=stop_id
            )
            return None

    except Exception as exc:
        logger.error(
            "stop_earliest_departure_failed",
            stop_id=stop_id,
            error=str(exc)
        )
        # Fallback to default threshold on error
        return 3900  # 1:05 AM default


# ===== Architecture Decoupling: DeparturesPage with RT-Only Mode =====


def _compute_staleness(redis_binary: redis.Redis, modes: Set[str]) -> bool:
    """Check if any RT blob is stale (>90s old).

    Args:
        redis_binary: Redis client for binary operations
        modes: Set of transport modes to check

    Returns:
        True if any blob >90s old, False otherwise
    """
    import time as time_module

    for mode in modes:
        try:
            updated_key = f'tu:{mode}:v1:updated_at'
            updated_ts = redis_binary.get(updated_key)
            if updated_ts:
                blob_age = time_module.time() - float(updated_ts.decode('utf-8'))
                if blob_age > 90:
                    return True
        except Exception as exc:
            logger.warning("staleness_check_failed", mode=mode, error=str(exc))

    return False


def _build_rt_only_departures(
    stop_id: str,
    time_secs_local: int,
    direction: str,
    limit: int,
    redis_binary: redis.Redis
) -> List[Dict]:
    """Build departures from RT data only (no static schedules).

    Used when Supabase unavailable but Redis has GTFS-RT data.

    Args:
        stop_id: GTFS stop_id
        time_secs_local: Seconds since local midnight
        direction: 'past' or 'future'
        limit: Max results
        redis_binary: Redis client

    Returns:
        List of departure dicts with estimated_time (no scheduled_time)
    """
    departures = []

    # Fetch all RT blobs (all modes - we don't know stop's modes without static data)
    all_modes = ['sydneytrains', 'metro', 'buses', 'ferries', 'lightrail']

    for mode in all_modes:
        try:
            tu_key = f'tu:{mode}:v1'
            tu_blob = redis_binary.get(tu_key)

            if not tu_blob:
                continue

            # Decompress and parse
            decompressed = gzip.decompress(tu_blob)
            data = json.loads(decompressed)

            # Extract stop_time_updates for this stop
            for tu in data:
                trip_id = tu.get('trip_id')
                if not trip_id:
                    continue

                # Find stop_time_update for our stop
                stop_time_updates = tu.get('stop_time_updates', [])
                for stu in stop_time_updates:
                    if stu.get('stop_id') != stop_id:
                        continue

                    # Extract delay and estimate scheduled time
                    departure_delay = stu.get('departure_delay', 0)
                    # Note: RT-only mode can't compute scheduled_time without static data
                    # We'll use estimated_time as both scheduled and realtime
                    # This is approximate - client should handle RT-only gracefully
                    estimated_time_secs = time_secs_local + departure_delay

                    # Filter by direction
                    if direction == 'future' and estimated_time_secs < time_secs_local:
                        continue
                    if direction == 'past' and estimated_time_secs > time_secs_local:
                        continue

                    departures.append({
                        'trip_id': trip_id,
                        'route_short_name': f'{mode.upper()}',  # Placeholder - no static data
                        'route_long_name': f'{mode.title()} Service',
                        'route_type': 3,  # Default to bus
                        'route_color': None,
                        'headsign': 'Real-Time Update',
                        'scheduled_time_secs': estimated_time_secs - departure_delay,  # Approximation
                        'realtime_time_secs': estimated_time_secs,
                        'delay_s': departure_delay,
                        'realtime': True,
                        'stop_sequence': stu.get('stop_sequence', 0),
                        'platform': stu.get('platform_code'),
                        'wheelchair_accessible': 0,
                        'occupancy_status': None,
                    })

        except gzip.BadGzipFile:
            logger.warning("rt_only_gzip_error", mode=mode)
        except json.JSONDecodeError as exc:
            logger.warning("rt_only_json_error", mode=mode, error=str(exc))
        except Exception as exc:
            logger.warning("rt_only_fetch_failed", mode=mode, error=str(exc))

    # Sort and limit
    departures.sort(key=lambda x: x['realtime_time_secs'], reverse=(direction == 'past'))
    return departures[:limit]


async def get_departures_page(
    stop_id: str,
    time_secs: int,
    direction: str,
    limit: int,
    supabase
) -> "DeparturesPage":
    """Get departures page with RT-only fallback (Layer 2↔3 decoupling).

    Architecture: Tries static+RT merge first, falls back to RT-only if Supabase fails.
    Enables serving departures when Layer 3 (Supabase) empty but Layer 2 (Redis) has data.

    Args:
        stop_id: GTFS stop_id
        time_secs: Seconds since midnight Sydney
        direction: 'past' or 'future'
        limit: Max results
        supabase: Supabase client

    Returns:
        DeparturesPage with source metadata (static+rt | rt_only | static_only | no_data)
    """
    from app.models.departures import DeparturesPage
    import pytz
    from datetime import datetime

    start_time = time.time()

    # Derive service_date from current Sydney time (normalize to GTFS YYYYMMDD format)
    sydney_tz = pytz.timezone('Australia/Sydney')
    service_date = datetime.now(sydney_tz).strftime('%Y-%m-%d')

    # GTFS calendar.txt stores dates as YYYYMMDD (no hyphens). The previous code
    # used the hyphenated form in the SQL filter, which never matched and
    # returned zero static departures. Normalize here so calendar join succeeds.
    service_date_gtfs = service_date.replace('-', '')

    redis_binary = get_redis_binary()

    # Check if stop exists in any source (Supabase OR Redis RT)
    stop_exists_supabase = False
    try:
        stop_check = supabase.table("stops").select("stop_id").eq("stop_id", stop_id).execute()
        stop_exists_supabase = len(stop_check.data) > 0 if stop_check.data else False
    except Exception as exc:
        logger.warning("stop_exists_check_failed", stop_id=stop_id, error=str(exc))

    try:
        # Try static+RT merge first
        departures = get_realtime_departures(
            stop_id=stop_id,
            time_secs_local=time_secs,
            service_date=service_date,
            direction=direction,
            limit=limit
        )

        if departures:
            # Successfully fetched static+RT or static-only
            realtime_count = sum(1 for d in departures if d['realtime'])
            source = "static+rt" if realtime_count > 0 else "static_only"

            # Determine modes for staleness check
            modes_needed = {determine_mode(d.get('route_id', '')) for d in departures if d.get('route_id')}
            stale = _compute_staleness(redis_binary, modes_needed) if modes_needed else False

            # Build pagination metadata
            earliest_time = min(d['realtime_time_secs'] for d in departures) if departures else None
            latest_time = max(d['realtime_time_secs'] for d in departures) if departures else None

            stop_earliest_time = get_stop_earliest_departure(stop_id, service_date) or 3900

            return DeparturesPage(
                stop_exists=stop_exists_supabase,
                source=source,
                stale=stale,
                departures=departures,
                earliest_time_secs=earliest_time,
                latest_time_secs=latest_time,
                has_more_past=earliest_time > stop_earliest_time if earliest_time else False,
                has_more_future=latest_time < 105723 if latest_time else False
            )
        else:
            # No static departures - try RT-only mode
            logger.info("attempting_rt_only_mode", stop_id=stop_id)

            rt_departures = _build_rt_only_departures(
                stop_id=stop_id,
                time_secs_local=time_secs,
                direction=direction,
                limit=limit,
                redis_binary=redis_binary
            )

            if rt_departures:
                # RT-only mode successful
                all_modes = {'sydneytrains', 'metro', 'buses', 'ferries', 'lightrail'}
                stale = _compute_staleness(redis_binary, all_modes)

                earliest_time = min(d['realtime_time_secs'] for d in rt_departures)
                latest_time = max(d['realtime_time_secs'] for d in rt_departures)

                return DeparturesPage(
                    stop_exists=True,  # RT data proves stop exists
                    source="rt_only",
                    stale=stale,
                    departures=rt_departures,
                    earliest_time_secs=earliest_time,
                    latest_time_secs=latest_time,
                    has_more_past=False,  # Can't determine without static data
                    has_more_future=False
                )
            else:
                # No data from any source
                return DeparturesPage.empty(stop_id=stop_id, stop_exists=stop_exists_supabase)

    except Exception as exc:
        logger.error("departures_page_failed", stop_id=stop_id, error=str(exc))
        # Return empty page on error
        return DeparturesPage.empty(stop_id=stop_id, stop_exists=stop_exists_supabase)
