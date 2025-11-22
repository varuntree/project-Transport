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
from app.services.realtime_service import get_realtime_departures, get_stop_earliest_departure, get_departures_page
from app.services.alert_service import get_alert_service
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
        # Use parameterized RPC to prevent SQL injection
        result = supabase.rpc(
            "search_stops_by_name",
            {"p_query": q, "p_limit": limit}
        ).execute()
        stops = result.data or []

        # Log route_type distribution for multi-modal coverage validation
        route_type_distribution = {}
        if stops:
            for stop in stops:
                # Query route_type for this stop via parameterized RPC
                try:
                    route_types = supabase.rpc(
                        "get_route_types_for_stop",
                        {"p_stop_id": stop["stop_id"]}
                    ).execute()

                    if route_types.data:
                        for rt_row in route_types.data:
                            route_type = rt_row.get("route_type")
                            if route_type is not None:
                                route_type_distribution[route_type] = route_type_distribution.get(route_type, 0) + 1
                except Exception as e:
                    # Log error but don't fail search
                    logger.warning("route_type_query_failed", stop_id=stop["stop_id"], error=str(e))

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("stops_search", query=q, result_count=len(stops), duration_ms=duration_ms)

        # Log route type distribution separately for modal coverage analysis
        if route_type_distribution:
            logger.info("search_results_modality",
                       query=q,
                       total_results=len(stops),
                       route_type_distribution=route_type_distribution)

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

        # Get routes serving this stop (parameterized via RPC to prevent SQL injection)
        routes_result = supabase.rpc(
            "get_routes_for_stop",
            {"p_stop_id": stop_id}
        ).execute()
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

        # Architecture decoupling: Remove hard Supabase check
        # Let get_departures_page() handle stop existence check across all layers
        # (Supabase OR Redis RT data)

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

        # Fetch departures page with RT-only fallback (Layer 2↔3 decoupling)
        page = await get_departures_page(
            stop_id=stop_id,
            time_secs=time_secs,
            direction=direction,
            limit=limit,
            supabase=supabase
        )

        # 404 only if stop not found in ANY data source (Supabase AND Redis RT)
        if not page.stop_exists:
            logger.warning("stop_not_found_any_source", stop_id=stop_id)
            raise HTTPException(
                status_code=404,
                detail={
                    "error": {
                        "code": "STOP_NOT_FOUND",
                        "message": f"Stop with ID '{stop_id}' does not exist in any data source",
                        "details": {"stop_id": stop_id}
                    }
                }
            )

        # Count realtime vs static
        realtime_count = sum(1 for d in page.departures if d['realtime'])
        static_count = len(page.departures) - realtime_count

        duration_ms = int((time.time() - start_time_ms) * 1000)
        logger.info("departures_response",
                   stop_id=stop_id,
                   count=len(page.departures),
                   source=page.source,
                   stale=page.stale,
                   realtime_count=realtime_count,
                   static_count=static_count,
                   duration_ms=duration_ms)

        # Return page with API envelope
        return page.to_dict()

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

@router.get("/stops/{stop_id}/alerts")
async def get_stop_alerts(
    stop_id: str,
    supabase: Client = Depends(get_supabase)
):
    """Get active service alerts for a stop.

    Fetches ServiceAlerts from Redis (sa:{mode}:v1 blobs) and filters by:
    - informed_entity.stop_id matches requested stop_id
    - active_period includes current time

    Graceful degradation: Returns empty array if Redis unavailable.

    Returns:
        {
            "data": {
                "alerts": [...],
                "count": N
            },
            "meta": {
                "stop_id": "200060",
                "at": 1732253100
            }
        }
    """
    start_time = time.time()

    try:
        # Validate stop exists (consistent with departures endpoint)
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

        # Fetch alerts from Redis
        alert_service = get_alert_service()
        alerts = alert_service.get_alerts_for_stop(stop_id)

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("stop_alerts_fetched",
                   stop_id=stop_id,
                   alert_count=len(alerts),
                   duration_ms=duration_ms)

        return {
            "data": {
                "alerts": alerts,
                "count": len(alerts)
            },
            "meta": {
                "stop_id": stop_id,
                "at": int(time.time())
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        logger.error("stop_alerts_failed",
                    stop_id=stop_id,
                    error=str(e),
                    duration_ms=duration_ms)
        raise HTTPException(
            status_code=500,
            detail={
                "error": {
                    "code": "ALERTS_FETCH_FAILED",
                    "message": f"Failed to fetch alerts: {str(e)}",
                    "details": {}
                }
            }
        )
