"""Pydantic models for routes and GTFS endpoints"""
from pydantic import BaseModel
from typing import Optional

class RouteResponse(BaseModel):
    """Route response model"""
    route_id: str
    route_short_name: str
    route_long_name: str
    route_type: int  # 0=tram, 1=metro, 2=rail, 3=bus, 4=ferry, 7=funicular
    route_color: Optional[str] = None
    route_text_color: Optional[str] = None

class GTFSMetadataResponse(BaseModel):
    """GTFS feed metadata response"""
    feed_version: str
    feed_start_date: str  # YYYY-MM-DD
    feed_end_date: str
    processed_at: str  # ISO 8601
    stops_count: int
    routes_count: int
    patterns_count: int
    trips_count: int
