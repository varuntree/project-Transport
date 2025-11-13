"""GTFS metadata and download endpoints"""
from fastapi import APIRouter, HTTPException, Depends
from fastapi.responses import FileResponse
import os
import time

from app.db.supabase_client import get_supabase
from app.models.routes import GTFSMetadataResponse
from app.utils.logging import get_logger
from supabase import Client

logger = get_logger(__name__)
router = APIRouter()

@router.get("/version")
async def get_gtfs_version(
    supabase: Client = Depends(get_supabase)
):
    """Get latest GTFS feed metadata"""
    start_time = time.time()

    try:
        # Get latest metadata
        result = supabase.table("gtfs_metadata") \
            .select("*") \
            .order("processed_at", desc=True) \
            .limit(1) \
            .execute()

        if not result.data:
            logger.warning("gtfs_metadata_not_found")
            raise HTTPException(status_code=404, detail="No GTFS data loaded")

        duration_ms = int((time.time() - start_time) * 1000)
        logger.info("gtfs_version_fetched",
                   feed_version=result.data[0].get("feed_version"),
                   duration_ms=duration_ms)

        return {
            "data": result.data[0],
            "meta": {}
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error("gtfs_version_failed", error=str(e))
        raise HTTPException(status_code=500, detail=f"Failed to fetch GTFS version: {str(e)}")

@router.get("/download")
async def download_gtfs_db():
    """Download iOS SQLite database (streams file, does not load to memory)"""
    start_time = time.time()

    # Path to iOS SQLite file
    db_path = os.path.join(os.path.dirname(__file__), "../../../ios_output/gtfs.db")
    db_path = os.path.abspath(db_path)

    if not os.path.exists(db_path):
        logger.error("gtfs_db_not_found", path=db_path)
        raise HTTPException(status_code=404, detail="iOS SQLite not generated yet")

    # Get file size for logging
    file_size_mb = os.path.getsize(db_path) / 1024 / 1024
    duration_ms = int((time.time() - start_time) * 1000)

    logger.info("gtfs_download_requested",
               file_size_mb=round(file_size_mb, 2),
               duration_ms=duration_ms)

    # Stream file to client (FileResponse handles chunking automatically)
    return FileResponse(
        path=db_path,
        media_type="application/x-sqlite3",
        filename="gtfs.db",
        headers={
            "Content-Disposition": "attachment; filename=gtfs.db"
        }
    )
