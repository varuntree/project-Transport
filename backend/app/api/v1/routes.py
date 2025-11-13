"""Routes API endpoints"""
from fastapi import APIRouter, HTTPException, Query, Depends
from typing import Optional
import time

from app.db.supabase_client import get_supabase
from app.models.routes import RouteResponse
from app.utils.logging import get_logger
from supabase import Client

logger = get_logger(__name__)
router = APIRouter()

@router.get("/routes")
async def list_routes(
    type: Optional[int] = Query(None, ge=0, description="Route type filter (0=tram, 1=metro, 2=rail, 3=bus, 4=ferry, 700-712=bus types)"),
    offset: int = Query(0, ge=0, description="Pagination offset"),
    limit: int = Query(20, ge=1, le=100, description="Page size (max 100)"),
    supabase: Client = Depends(get_supabase)
):
    """List routes with optional type filter and pagination"""
    start_time = time.time()

    try:
        # Build query
        query = supabase.table("routes").select("*", count="exact")

        # Apply type filter if provided
        if type is not None:
            query = query.eq("route_type", type)

        # Execute with pagination
        result = query.range(offset, offset + limit - 1).execute()

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("routes_list_request",
                   route_type=type, offset=offset, limit=limit,
                   result_count=len(result.data), total=result.count,
                   duration_ms=duration_ms)

        return {
            "data": result.data,
            "meta": {
                "pagination": {
                    "offset": offset,
                    "limit": limit,
                    "total": result.count
                }
            }
        }
    except Exception as e:
        logger.error("routes_list_failed", route_type=type, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to fetch routes: {str(e)}")

@router.get("/routes/{route_id}")
async def get_route(
    route_id: str,
    supabase: Client = Depends(get_supabase)
):
    """Get route details by ID"""
    start_time = time.time()

    try:
        result = supabase.table("routes").select("*").eq("route_id", route_id).execute()

        if not result.data:
            logger.warning("route_not_found", route_id=route_id)
            raise HTTPException(status_code=404, detail=f"Route {route_id} not found")

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("route_fetched", route_id=route_id, duration_ms=duration_ms)

        return {
            "data": result.data[0],
            "meta": {}
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error("route_fetch_failed", route_id=route_id, error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to fetch route: {str(e)}")
