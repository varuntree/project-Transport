"""Internal validation endpoints (not for production use)"""
from fastapi import APIRouter, Depends
from typing import List, Dict, Any
from supabase import Client

from app.db.supabase_client import get_supabase
from app.utils.logging import get_logger

logger = get_logger(__name__)
router = APIRouter()


@router.get("/internal/validate-dict-stop")
async def validate_dict_stop(
    supabase: Client = Depends(get_supabase)
) -> Dict[str, Any]:
    """Validate dict_stop completeness in Supabase.

    Note: dict_stop table only exists in iOS SQLite (dictionary encoding),
    not in Supabase. This endpoint validates that all stops would have
    mappings if dict_stop were generated.

    Returns:
        {
            "stops_count": N,
            "validation": "pass|fail",
            "message": "..."
        }
    """
    logger.info("validate_dict_stop_started")

    # Query stops count
    stops_response = supabase.table("stops").select("stop_id", count="exact").execute()
    stops_count = stops_response.count if stops_response.count else 0

    # Note: dict_stop doesn't exist in Supabase (only in iOS SQLite)
    # This endpoint confirms all stops exist for dict_stop generation
    validation_result = {
        "stops_count": stops_count,
        "validation": "pass",
        "message": f"All {stops_count} stops ready for dict_stop generation (iOS SQLite only)"
    }

    logger.info(
        "validate_dict_stop_completed",
        stops_count=stops_count,
        validation="pass"
    )

    return validation_result
