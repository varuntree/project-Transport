"""Stops API endpoints"""
from fastapi import APIRouter, HTTPException, Query, Depends
from typing import Optional
import time
from datetime import datetime

from app.db.supabase_client import get_supabase
from app.models.stops import (
    StopResponse,
    StopNearbyResponse,
    StopDetailResponse,
    DepartureResponse,
    StopSearchResponse,
    RouteInStop
)
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
    time_param: Optional[int] = Query(None, alias="time", description="Unix epoch seconds (default: now)"),
    limit: int = Query(20, ge=1, le=50, description="Max results"),
    supabase: Client = Depends(get_supabase)
):
    """Get scheduled departures from stop (pattern model query)

    Note: Phase 1 returns static schedule data without real-time predictions.
    Phase 2 adds GTFS-RT merging for live departure times.
    """
    start_time_ms = time.time()

    try:
        # Use current time if not provided
        now_epoch = time_param if time_param else int(time.time())
        now_date = datetime.utcfromtimestamp(now_epoch).strftime("%Y-%m-%d")

        # Simplified query - just get trips serving this stop
        # Phase 2 will add proper time-based filtering and real-time data
        query = f"""
        SELECT
            t.trip_id,
            t.trip_headsign,
            t.direction_id,
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
        ORDER BY r.route_short_name, ps.departure_offset_secs ASC
        LIMIT {limit}
        """

        result = supabase.rpc("exec_raw_sql", {"query": query}).execute()
        departures = result.data or []

        duration_ms = int((time.time() - start_time_ms) * 1000)
        logger.info("departures_fetched",
                   stop_id=stop_id, time_epoch=now_epoch,
                   result_count=len(departures), duration_ms=duration_ms)

        return {
            "data": {
                "departures": departures,
                "count": len(departures)
            },
            "meta": {
                "pagination": {
                    "offset": 0,
                    "limit": limit,
                    "total": len(departures)
                },
                "query": {
                    "stop_id": stop_id,
                    "time": now_epoch
                }
            }
        }
    except Exception as e:
        logger.error("departures_fetch_failed", stop_id=stop_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to fetch departures: {str(e)}")
