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
    - M* → metro
    - F* → ferries
    - L* → lightrail
    - else → buses

    Args:
        route_id: GTFS route_id (e.g., "T1", "M20", "L1", "199", "F1")

    Returns:
        Mode string for Redis key lookup (sydneytrains, metro, ferries, lightrail, buses)
    """
    if not route_id:
        return "buses"

    route_id_upper = route_id.upper()

    if route_id_upper.startswith('T') or route_id_upper.startswith('BMT'):
        return 'sydneytrains'
    elif route_id_upper.startswith('M'):
        return 'metro'
    elif route_id_upper.startswith('F'):
        return 'ferries'
    elif route_id_upper.startswith('L'):
        return 'lightrail'
    else:
        return 'buses'


def get_realtime_departures(
    stop_id: str,
    now_secs: int,
    limit: int = 10
) -> List[Dict]:
    """Get real-time departures for a stop (merges static schedules + Redis RT delays).

    Args:
        stop_id: GTFS stop_id
        now_secs: Current time in Unix epoch seconds
        limit: Max departures to return (default 10)

    Returns:
        List of departure dicts with fields:
        - trip_id: str
        - route_short_name: str
        - route_long_name: str
        - route_type: int
        - route_color: str | None
        - headsign: str
        - scheduled_time_secs: int (pattern start_time + departure_offset_secs)
        - realtime_time_secs: int (scheduled + delay_s)
        - delay_s: int (0 if no RT data)
        - realtime: bool (true if delay_s != 0)
        - stop_sequence: int

    Example:
        >>> deps = get_realtime_departures('200060', 32400, 10)
        >>> deps[0]
        {
            'trip_id': 'T1.1234',
            'route_short_name': 'T1',
            'headsign': 'Hornsby',
            'scheduled_time_secs': 32500,
            'realtime_time_secs': 32620,
            'delay_s': 120,
            'realtime': True,
            'stop_sequence': 5
        }
    """
    start_time = time.time()

    try:
        supabase = get_supabase()
        redis_binary = get_redis_binary()

        # Step 1: Fetch static schedules (reuse Phase 1 query)
        # Note: departure_offset_secs is seconds since midnight (00:00:00)
        # Phase 1 query returns all trips serving this stop today
        from datetime import datetime
        now_date = datetime.utcfromtimestamp(now_secs).strftime("%Y-%m-%d")

        query = f"""
        SELECT
            t.trip_id,
            t.trip_headsign,
            t.direction_id,
            t.wheelchair_accessible,
            r.route_id,
            r.route_short_name,
            r.route_long_name,
            r.route_type,
            r.route_color,
            ps.departure_offset_secs,
            ps.stop_sequence
        FROM pattern_stops ps
        JOIN patterns p ON ps.pattern_id = p.pattern_id
        JOIN trips t ON t.pattern_id = p.pattern_id
        JOIN routes r ON t.route_id = r.route_id
        JOIN calendar c ON t.service_id = c.service_id
        WHERE ps.stop_id = '{stop_id}'
          AND c.start_date <= '{now_date}'
          AND c.end_date >= '{now_date}'
        ORDER BY ps.departure_offset_secs ASC
        LIMIT 100
        """

        result = supabase.rpc("exec_raw_sql", {"query": query}).execute()
        static_deps = result.data or []

        if not static_deps:
            logger.info("no_static_departures", stop_id=stop_id, now_secs=now_secs)
            return []

        # Step 2: Determine modes needed (heuristic from route_ids)
        modes_needed: Set[str] = {determine_mode(dep['route_id']) for dep in static_deps}

        # Step 3: Fetch Redis RT delays + platform codes (gzip blobs per mode)
        trip_delays: Dict[str, int] = {}  # {trip_id: delay_s}
        trip_platforms: Dict[str, str] = {}  # {trip_id: platform_code}

        for mode in modes_needed:
            try:
                redis_key = f'tu:{mode}:v1'
                blob = redis_binary.get(redis_key)

                if blob:
                    # Decompress gzipped JSON blob (blob is bytes with decode_responses=False)
                    decompressed = gzip.decompress(blob)
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

                    logger.debug("realtime_data_fetched", mode=mode, trip_count=len(data))
                else:
                    logger.debug("realtime_data_miss", mode=mode, key=redis_key)

            except gzip.BadGzipFile:
                logger.warning("realtime_gzip_error", mode=mode, key=f'tu:{mode}:v1')
            except json.JSONDecodeError as exc:
                logger.warning("realtime_json_error", mode=mode, key=f'tu:{mode}:v1', error=str(exc))
            except Exception as exc:
                logger.warning("realtime_fetch_failed", mode=mode, error=str(exc))

        # Step 4: Merge static + RT
        departures = []

        for dep in static_deps:
            trip_id = dep['trip_id']

            # departure_offset_secs is already seconds since midnight (00:00:00)
            # No need to parse start_time - it's the absolute time within the service day
            scheduled_time_secs = dep['departure_offset_secs']

            # Get RT delay (default 0 if no data)
            delay_s = trip_delays.get(trip_id, 0)
            realtime_time_secs = scheduled_time_secs + delay_s

            # Get platform from RT data (may be None)
            platform = trip_platforms.get(trip_id)

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
            now_secs=now_secs,
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
            now_secs=now_secs,
            error=str(exc),
            duration_ms=duration_ms
        )
        raise
