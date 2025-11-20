"""Stops API endpoints"""
from fastapi import APIRouter, HTTPException, Query, Depends
from typing import Optional
import time
from datetime import datetime
import pytz

from app.db.supabase_client import get_supabase
from app.models.stops import (
    StopResponse,
    StopNearbyResponse,
    StopDetailResponse,
    DepartureResponse,
    StopSearchResponse,
    RouteInStop
)
from app.services.realtime_service import get_realtime_departures, get_stop_earliest_departure
from app.utils.logging import get_logger
from supabase import Client

logger = get_logger(__name__)
router = APIRouter()

@router.get("/stops/nearby")
async def get_nearby_stops(
    lat: float = Query(..., ge=-90, le=90, description="Latitude"),
    lon: float = Query(..., ge=-180, le=180, description="Longitude"),
    radius: int = Query(500, ge=50, le=2000, description="Radius in meters"),
    limit: int = Query(20, ge=1, le=50, description="Max results"),
    supabase: Client = Depends(get_supabase)
):
    """Find stops within radius of coordinates (PostGIS spatial query)"""
    start_time = time.time()

    try:
        # CRITICAL: PostGIS expects (lon, lat) not (lat, lon)!
        query = f"""
        SELECT stop_id, stop_name, stop_code, stop_lat, stop_lon,
               wheelchair_boarding, location_type, parent_station,
               ST_Distance(location, ST_MakePoint({lon}, {lat})::geography) AS distance_meters
        FROM stops
        WHERE ST_DWithin(location::geography, ST_MakePoint({lon}, {lat})::geography, {radius})
        ORDER BY distance_meters ASC
        LIMIT {limit}
        """

        result = supabase.rpc("exec_raw_sql", {"query": query}).execute()
        stops = result.data or []

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("stops_nearby_request",
                   lat=lat, lon=lon, radius=radius,
                   result_count=len(stops), duration_ms=duration_ms)

        return {
            "data": {
                "stops": stops,
                "count": len(stops)
            },
            "meta": {
                "pagination": {
                    "offset": 0,
                    "limit": limit,
                    "total": len(stops)
                },
                "query": {
                    "lat": lat,
                    "lon": lon,
                    "radius": radius
                }
            }
        }
    except Exception as e:
        logger.error("stops_nearby_failed", lat=lat, lon=lon, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to fetch nearby stops: {str(e)}")

@router.get("/stops/search")
async def search_stops(
    q: str = Query(..., min_length=1, description="Search query"),
    limit: int = Query(20, ge=1, le=50, description="Max results"),
    supabase: Client = Depends(get_supabase)
):
    """Search stops by name using PostgreSQL trigram similarity"""
    start_time = time.time()

    try:
        # Sanitize input to prevent SQL injection (basic protection)
        q_sanitized = q.replace("'", "''")

        # Use pg_trgm for fuzzy search
        query = f"""
        SELECT stop_id, stop_name, stop_code, stop_lat, stop_lon,
               wheelchair_boarding, location_type, parent_station,
               similarity(stop_name, '{q_sanitized}') AS score
        FROM stops
        WHERE stop_name ILIKE '%{q_sanitized}%'
           OR stop_name % '{q_sanitized}'
        ORDER BY score DESC, stop_name
        LIMIT {limit}
        """

        result = supabase.rpc("exec_raw_sql", {"query": query}).execute()
        stops = result.data or []

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("stops_search", query=q, result_count=len(stops), duration_ms=duration_ms)

        return {
            "data": {
                "stops": stops,
                "count": len(stops)
            },
            "meta": {
                "pagination": {
                    "offset": 0,
                    "limit": limit,
                    "total": len(stops)
                },
                "query": {
                    "q": q
                }
            }
        }
    except Exception as e:
        logger.error("stops_search_failed", query=q, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to search stops: {str(e)}")

@router.get("/stops/{stop_id}")
async def get_stop(
    stop_id: str,
    supabase: Client = Depends(get_supabase)
):
    """Get stop details with routes serving this stop"""
    start_time = time.time()

    try:
        # Get stop details
        stop_result = supabase.table("stops").select("*").eq("stop_id", stop_id).execute()

        if not stop_result.data:
            logger.warning("stop_not_found", stop_id=stop_id)
            raise HTTPException(status_code=404, detail=f"Stop {stop_id} not found")

        stop = stop_result.data[0]

        # Get routes serving this stop
        routes_query = f"""
        SELECT DISTINCT r.route_id, r.route_short_name, r.route_long_name,
               r.route_type, r.route_color
        FROM routes r
        JOIN trips t ON r.route_id = t.route_id
        JOIN patterns p ON t.pattern_id = p.pattern_id
        JOIN pattern_stops ps ON p.pattern_id = ps.pattern_id
        WHERE ps.stop_id = '{stop_id}'
        ORDER BY r.route_short_name
        """

        routes_result = supabase.rpc("exec_raw_sql", {"query": routes_query}).execute()
        routes = routes_result.data or []

        stop['routes'] = routes

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("stop_fetched", stop_id=stop_id, routes_count=len(routes), duration_ms=duration_ms)

        return {
            "data": stop,
            "meta": {}
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error("stop_fetch_failed", stop_id=stop_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to fetch stop: {str(e)}")

@router.get("/stops/{stop_id}/departures")
async def get_departures(
    stop_id: str,
    time_param: Optional[int] = Query(None, alias="time", description="Seconds since midnight Sydney time (default: now)"),
    direction: str = Query("future", regex="^(past|future)$", description="Direction: 'past' for earlier departures, 'future' for later (default: future)"),
    limit: int = Query(10, ge=1, le=50, description="Max results"),
    supabase: Client = Depends(get_supabase)
):
    """Get real-time departures from stop (merges static schedules + GTFS-RT delays).

    Phase 2: Returns real-time predictions with delay_s and realtime flag.
    Bidirectional scroll: direction='past' for earlier departures, 'future' for later.
    Graceful degradation to static schedules if Redis cache unavailable.
    """
    start_time_ms = time.time()

    try:
        # Log received stop_id for debugging
        logger.info("departures_request", stop_id=stop_id, stop_id_type=type(stop_id).__name__)

        # Validate stop_id is non-empty
        if not stop_id or not stop_id.strip():
            logger.warning("departures_empty_stop_id")
            raise HTTPException(
                status_code=400,
                detail={
                    "error": {
                        "code": "INVALID_STOP_ID",
                        "message": "Stop ID cannot be empty",
                        "details": {}
                    }
                }
            )

        # Verify stop exists in database
        stop_check = supabase.table("stops").select("stop_id, stop_name").eq("stop_id", stop_id).execute()
        if not stop_check.data:
            logger.warning("stop_not_found", stop_id=stop_id)
            raise HTTPException(
                status_code=404,
                detail={
                    "error": {
                        "code": "STOP_NOT_FOUND",
                        "message": f"Stop with ID '{stop_id}' does not exist",
                        "details": {"stop_id": stop_id}
                    }
                }
            )

        # Default time to now (seconds since midnight Sydney)
        if time_param is None:
            sydney_tz = pytz.timezone('Australia/Sydney')
            now = datetime.now(sydney_tz)
            midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
            time_secs = int((now - midnight).total_seconds())
        else:
            time_secs = time_param

        # Validate time range (0-86399, seconds in a day)
        if not (0 <= time_secs < 86400):
            raise HTTPException(
                status_code=400,
                detail={
                    "error": {
                        "code": "INVALID_TIME",
                        "message": "Time parameter must be between 0 and 86399 (seconds since midnight)",
                        "details": {"time": time_secs}
                    }
                }
            )

        # Fetch real-time departures (merges static + Redis RT)
        # Pass Sydney-local service date and seconds since midnight
        service_date = datetime.now(pytz.timezone('Australia/Sydney')).strftime('%Y-%m-%d')
        departures = get_realtime_departures(
            stop_id=stop_id,
            time_secs_local=time_secs,
            service_date=service_date,
            direction=direction,
            limit=limit
        )

        if departures:
            occupancy_count = sum(1 for d in departures if d.get('occupancy_status') is not None)
            sample = departures[0]
            logger.debug(
                "departure_occupancy",
                stop_id=stop_id,
                trip_id=sample['trip_id'],
                occupancy_status=sample.get('occupancy_status'),
                occupancy_sample_count=occupancy_count
            )

        # Count realtime vs static
        realtime_count = sum(1 for d in departures if d['realtime'])
        static_count = len(departures) - realtime_count

        duration_ms = int((time.time() - start_time_ms) * 1000)
        logger.info("departures_fetched",
                   stop_id=stop_id,
                   time_secs=time_secs,
                   total_count=len(departures),
                   realtime_count=realtime_count,
                   static_count=static_count,
                   duration_ms=duration_ms)

        # Pagination metadata for infinite scroll
        # CRITICAL: Use realtime_time_secs (not scheduled) for boundaries to match sort dimension
        # Pagination must align with displayed order (realtime times, not scheduled times)
        pagination_meta = None
        if departures:
            earliest_time = min(d['realtime_time_secs'] for d in departures)
            latest_time = max(d['realtime_time_secs'] for d in departures)

            # Dynamic pagination threshold: query actual GTFS earliest departure for this stop
            # Replaces static 3900 (1:05 AM) with stop-specific earliest time
            stop_earliest_time = get_stop_earliest_departure(stop_id, service_date)
            if stop_earliest_time is None:
                # Fallback to static threshold if query fails
                stop_earliest_time = 3900

            pagination_meta = {
                "has_more_past": earliest_time > stop_earliest_time,  # Dynamic: actual GTFS min time
                "has_more_future": latest_time < 105723,  # Latest train ~29:22 (next day)
                "earliest_time_secs": earliest_time,
                "latest_time_secs": latest_time,
                "direction": direction
            }

        return {
            "data": {
                "departures": departures,
                "count": len(departures)
            },
            "meta": {
                "pagination": pagination_meta,
                "query": {
                    "stop_id": stop_id,
                    "time_secs": time_secs,
                    "direction": direction
                }
            }
        }

    except HTTPException:
        # Re-raise validation errors
        raise
    except Exception as e:
        duration_ms = int((time.time() - start_time_ms) * 1000)
        logger.error("departures_fetch_failed",
                    stop_id=stop_id,
                    error=str(e),
                    duration_ms=duration_ms)
        raise HTTPException(
            status_code=500,
            detail={
                "error": {
                    "code": "DEPARTURES_FETCH_FAILED",
                    "message": f"Failed to fetch departures: {str(e)}",
                    "details": {}
                }
            }
        )
