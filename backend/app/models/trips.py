"""Pydantic models for trips endpoints"""
from pydantic import BaseModel
from typing import Optional, List


class RouteInfo(BaseModel):
    """Route information within trip details"""
    short_name: str
    color: Optional[str] = None


class TripStop(BaseModel):
    """Stop within a trip pattern"""
    stop_id: str
    stop_name: str
    arrival_time_secs: int
    platform: Optional[str] = None
    wheelchair_accessible: int = 0


class TripDetailsResponse(BaseModel):
    """Trip details with stop sequence"""
    trip_id: str
    route: RouteInfo
    headsign: str
    stops: List[TripStop]
