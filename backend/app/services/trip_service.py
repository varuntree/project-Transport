"""Trip service - fetch trip details with stop sequence.

Queries pattern model (trips → patterns → pattern_stops → stops).
Merges GTFS-RT trip_update from Redis for real-time arrival predictions.
"""

import gzip
import json
import time
from typing import Dict, Optional

from app.db.supabase_client import get_supabase
from app.services.realtime_service import get_redis_binary, determine_mode
from app.utils.logging import get_logger

logger = get_logger(__name__)


def get_trip_details(trip_id: str) -> dict:
    """Get trip details with stop sequence and real-time arrivals.

    Args:
        trip_id: GTFS trip_id

    Returns:
        dict with fields:
        - trip_id: str
        - route: {short_name: str, color: str | None}
        - headsign: str
        - stops: List[{stop_id, stop_name, arrival_time_secs, platform?, wheelchair_accessible}]

    Notes:
        - arrival_time_secs is the **actual** arrival time in seconds since
          midnight for the service day (including any real‑time delay), i.e.
          `start_time_secs + arrival_offset_secs + delay_s`. This matches the
          `actual_departure_secs` semantics used in the departures API.

    Raises:
        Exception if trip not found or query fails
    """
    start_time = time.time()

    try:
        supabase = get_supabase()
        redis_binary = get_redis_binary()

        # Step 1: Query trip metadata + pattern
        trip_query = f"""
        SELECT
            t.trip_id,
            t.trip_headsign,
            t.pattern_id,
            t.wheelchair_accessible AS trip_wheelchair_accessible,
            t.start_time_secs,
            r.route_id,
            r.route_short_name,
            r.route_color
        FROM trips t
        JOIN routes r ON t.route_id = r.route_id
        WHERE t.trip_id = '{trip_id}'
        LIMIT 1
        """

        trip_result = supabase.rpc("exec_raw_sql", {"query": trip_query}).execute()
        trip_data = trip_result.data

        if not trip_data or len(trip_data) == 0:
            raise ValueError(f"Trip {trip_id} not found")

        trip = trip_data[0]
        pattern_id = trip['pattern_id']
        route_id = trip['route_id']
        # start_time_secs can be NULL for some legacy rows; default to 0 in that case.
        trip_start_secs = trip.get('start_time_secs') or 0

        # Step 2: Query pattern_stops → stops for stop sequence
        pattern_query = f"""
        SELECT
            ps.stop_sequence,
            ps.stop_id,
            ps.arrival_offset_secs,
            s.stop_name,
            s.stop_lat,
            s.stop_lon,
            s.wheelchair_boarding
        FROM pattern_stops ps
        JOIN stops s ON ps.stop_id = s.stop_id
        WHERE ps.pattern_id = '{pattern_id}'
        ORDER BY ps.stop_sequence ASC
        """

        pattern_result = supabase.rpc("exec_raw_sql", {"query": pattern_query}).execute()
        pattern_stops = pattern_result.data or []

        if not pattern_stops:
            logger.warning("trip_no_pattern_stops", trip_id=trip_id, pattern_id=pattern_id)
            # Return trip with empty stops
            return {
                'trip_id': trip_id,
                'route': {
                    'short_name': trip['route_short_name'],
                    'color': trip.get('route_color')
                },
                'headsign': trip['trip_headsign'] or '',
                'stops': []
            }

        # Step 3: Fetch Redis RT trip_update for arrival predictions + platform
        mode = determine_mode(route_id)
        trip_platforms: Dict[str, str] = {}  # {stop_id: platform_code}
        trip_delays: Dict[str, int] = {}  # {stop_id: delay_s}

        try:
            redis_key = f'tu:{mode}:v1'
            blob = redis_binary.get(redis_key)

            if blob:
                # Decompress gzipped JSON blob
                decompressed = gzip.decompress(blob)
                data = json.loads(decompressed)

                # Find this trip's trip_update
                for tu in data:
                    if tu.get('trip_id') == trip_id:
                        # Extract stop-level arrivals + platforms
                        stop_time_updates = tu.get('stop_time_updates', [])
                        for stu in stop_time_updates:
                            stop_id = stu.get('stop_id')
                            if stop_id:
                                # Store platform if available
                                if stu.get('platform_code'):
                                    trip_platforms[stop_id] = stu['platform_code']
                                # Store arrival_delay if available
                                if stu.get('arrival_delay') is not None:
                                    trip_delays[stop_id] = stu['arrival_delay']
                        break

                logger.debug("trip_realtime_data_fetched", trip_id=trip_id, mode=mode, platforms_count=len(trip_platforms))
            else:
                logger.debug("trip_realtime_data_miss", trip_id=trip_id, mode=mode)

        except gzip.BadGzipFile:
            logger.warning("trip_realtime_gzip_error", trip_id=trip_id, mode=mode)
        except json.JSONDecodeError as exc:
            logger.warning("trip_realtime_json_error", trip_id=trip_id, mode=mode, error=str(exc))
        except Exception as exc:
            logger.warning("trip_realtime_fetch_failed", trip_id=trip_id, mode=mode, error=str(exc))

        # Step 4: Build stops list with real-time data merged
        stops = []
        stops_with_delays = 0
        for ps in pattern_stops:
            stop_id = ps['stop_id']
            # Convert offset from trip start into an absolute time-of-day
            # so iOS can format it as HH:mm, consistent with departures list.
            #
            # Schema guarantee: arrival_offset_secs is "seconds from trip start_time"
            # (see schemas/migrations/001_initial_schema.sql).
            scheduled_arrival_secs = trip_start_secs + ps['arrival_offset_secs']
            delay_s = trip_delays.get(stop_id)  # None if no RT data

            # Extract coordinates (PostGIS: lat = Y, lon = X)
            stop_lat = ps.get('stop_lat', 0.0)
            stop_lon = ps.get('stop_lon', 0.0)

            # Log warning if coordinates missing
            if stop_lat == 0.0 or stop_lon == 0.0:
                logger.warning("stop_coordinates_missing", stop_id=stop_id, trip_id=trip_id)

            has_coords = stop_lat != 0.0 and stop_lon != 0.0
            logger.debug(
                "trip_stop_coords",
                trip_id=trip_id,
                stop_id=stop_id,
                lat=stop_lat,
                lon=stop_lon,
                has_coords=has_coords
            )

            # Build stop dict with backward-compatible RT fields
            stop_dict = {
                'stop_id': stop_id,
                'stop_name': ps['stop_name'],
                'arrival_time_secs': scheduled_arrival_secs,  # Static scheduled time
                'lat': float(stop_lat) if stop_lat else 0.0,
                'lon': float(stop_lon) if stop_lon else 0.0,
                'platform': trip_platforms.get(stop_id),
                'wheelchair_accessible': ps.get('wheelchair_boarding', 0)
            }

            # Add RT fields only if delay data exists (backward compatibility)
            if delay_s is not None:
                stop_dict['delay_s'] = delay_s
                stop_dict['realtime'] = True
                stop_dict['realtime_arrival_time_secs'] = scheduled_arrival_secs + delay_s
                stops_with_delays += 1

            stops.append(stop_dict)

        stops_with_coords = sum(1 for s in stops if s['lat'] and s['lon'])
        duration_ms = int((time.time() - start_time) * 1000)
        logger.info(
            "trip_details_fetched",
            trip_id=trip_id,
            stops_count=len(stops),
            stops_with_delays=stops_with_delays,
            duration_ms=duration_ms
        )
        logger.info(
            "trip_coords_summary",
            trip_id=trip_id,
            total_stops=len(stops),
            stops_with_coords=stops_with_coords,
            duration_ms=duration_ms
        )

        return {
            'trip_id': trip_id,
            'route': {
                'short_name': trip['route_short_name'],
                'color': trip.get('route_color')
            },
            'headsign': trip['trip_headsign'] or '',
            'stops': stops
        }

    except ValueError:
        # Trip not found - re-raise
        raise
    except Exception as exc:
        duration_ms = int((time.time() - start_time) * 1000)
        logger.error("trip_details_failed",
                    trip_id=trip_id,
                    error=str(exc),
                    duration_ms=duration_ms)
        raise
