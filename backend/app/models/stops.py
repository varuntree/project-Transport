"""Pydantic models for stops endpoints"""
from pydantic import BaseModel, Field
from typing import Optional

class StopBase(BaseModel):
    """Base stop model"""
    stop_id: str
    stop_name: str
    stop_lat: float
    stop_lon: float
    stop_code: Optional[str] = None
    wheelchair_boarding: Optional[int] = None
    location_type: Optional[int] = None
    parent_station: Optional[str] = None

class StopResponse(StopBase):
    """Stop detail response"""
    pass

class StopNearbyResponse(StopBase):
    """Nearby stop with distance"""
    distance_meters: float

class RouteInStop(BaseModel):
    """Route serving a stop"""
    route_id: str
    route_short_name: str
    route_long_name: str
    route_type: int
    route_color: Optional[str] = None

class StopDetailResponse(StopBase):
    """Stop with routes"""
    routes: list[RouteInStop] = []

class DepartureResponse(BaseModel):
    """Scheduled departure from a stop"""
    trip_id: str
    trip_headsign: str
    route_short_name: str
    route_long_name: str
    route_type: int
    route_color: Optional[str] = None
    departure_offset_secs: int
    stop_sequence: int
    departure_epoch: int

class StopSearchResponse(StopBase):
    """Search result with relevance score"""
    score: float
