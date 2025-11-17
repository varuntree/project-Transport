"""Trips API endpoints"""
from fastapi import APIRouter, HTTPException
import time

from app.services.trip_service import get_trip_details
from app.utils.logging import get_logger

logger = get_logger(__name__)
router = APIRouter()


@router.get("/trips/{trip_id}")
async def get_trip(trip_id: str):
    """Get trip details with intermediary stops and real-time arrivals.

    Returns trip metadata + stop sequence with arrival times merged from GTFS-RT.
    """
    start_time = time.time()

    try:
        # Fetch trip details (static + Redis RT merge)
        trip_data = get_trip_details(trip_id)

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("trip_api_success",
                   trip_id=trip_id,
                   stops_count=len(trip_data['stops']),
                   duration_ms=duration_ms)

        return {
            "data": trip_data,
            "meta": {}
        }

    except ValueError as e:
        # Trip not found (ValueError from trip_service)
        duration_ms = int((time.time() - start_time) * 1000)
        logger.warning("trip_not_found", trip_id=trip_id, duration_ms=duration_ms)
        raise HTTPException(
            status_code=404,
            detail={
                "error": {
                    "code": "TRIP_NOT_FOUND",
                    "message": str(e),
                    "details": {}
                }
            }
        )
    except Exception as e:
        duration_ms = int((time.time() - start_time) * 1000)
        logger.error("trip_api_failed",
                    trip_id=trip_id,
                    error=str(e),
                    duration_ms=duration_ms)
        raise HTTPException(
            status_code=500,
            detail={
                "error": {
                    "code": "TRIP_FETCH_FAILED",
                    "message": f"Failed to fetch trip details: {str(e)}",
                    "details": {}
                }
            }
        )
