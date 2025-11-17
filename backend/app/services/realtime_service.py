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
    limit: int = 10,
) -> List[Dict]:
    """Get real-time departures for a stop (merges static schedules + GTFS-RT delays).

    Args:
        stop_id: GTFS stop_id
        time_secs_local: Seconds since local (Sydney) midnight for filtering; required.
        service_date: Service date in YYYY-MM-DD (Sydney time); required.
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

        # Step 1: Fetch static schedules (phase 1 query)
        # Calculate actual departure time: trip_start_time + offset_secs
        # Filter WHERE actual_departure_time >= current_time
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
        WHERE ps.stop_id = '{stop_id}'
          AND c.start_date <= '{service_date}'
          AND c.end_date >= '{service_date}'
          AND (t.start_time_secs + ps.departure_offset_secs) >= {time_secs_local}
        ORDER BY (t.start_time_secs + ps.departure_offset_secs) ASC
        LIMIT 20
        """

        result = supabase.rpc("exec_raw_sql", {"query": query}).execute()
        static_deps = result.data or []

        if not static_deps:
            logger.info("no_static_departures", stop_id=stop_id, service_date=service_date, time_secs=time_secs_local)
            return []

        # Step 2: Determine modes needed (heuristic from route_ids)
        modes_needed: Set[str] = {determine_mode(dep['route_id']) for dep in static_deps}

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

                if vp_blob:
                    decompressed = gzip.decompress(vp_blob)
                    vp_data = json.loads(decompressed)

                    # Extract occupancy_status from vehicle positions
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

            departures.append({
                'trip_id': trip_id,
                'route_short_name': dep['route_short_name'],
                'route_long_name': dep['route_long_name'],
                'route_type': dep['route_type'],
                'route_color': dep.get('route_color'),
                'headsign': dep['trip_headsign'],
                'scheduled_time_secs': scheduled_time_secs,
                'realtime_time_secs': realtime_time_secs,
                'delay_s': delay_s,
                'realtime': delay_s != 0,
                'stop_sequence': dep['stop_sequence'],
                'platform': platform,
                'wheelchair_accessible': wheelchair_accessible,
                'occupancy_status': occupancy_status,
            })

        # Sort by realtime departure time (earliest first)
        departures.sort(key=lambda x: x['realtime_time_secs'])

        # Limit results
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
