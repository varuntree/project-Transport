"""GTFS-RT Pydantic Models - Checkpoint 1.

Centralized models for all GTFS-RT entities:
- TripUpdate (trip delays, stop time updates)
- VehiclePosition (vehicle location, occupancy)
- ServiceAlert (disruptions, planned work)

These models provide type safety and validation for GTFS-RT data
parsed from NSW Transport API protobuf feeds.
"""

from pydantic import BaseModel, Field
from typing import List, Optional


# TripUpdate models
class StopTimeUpdate(BaseModel):
    """Stop time update from GTFS-RT TripUpdate feed."""

    stop_id: str
    arrival_delay: Optional[int] = None  # seconds (positive = late, negative = early)
    departure_delay: Optional[int] = None  # seconds
    stop_sequence: Optional[int] = None
    platform_code: Optional[str] = None  # NSW-specific extension (may be None)


class TripDescriptor(BaseModel):
    """Trip descriptor identifying a GTFS trip."""

    trip_id: str
    route_id: Optional[str] = None
    direction_id: Optional[int] = None  # 0 or 1
    start_date: Optional[str] = None  # YYYYMMDD format


class TripUpdate(BaseModel):
    """Trip update from GTFS-RT feed (delays, cancellations)."""

    trip: TripDescriptor
    stop_time_updates: List[StopTimeUpdate] = Field(default_factory=list)
    timestamp: Optional[int] = None  # Unix timestamp
    delay: Optional[int] = None  # Overall trip delay in seconds


# VehiclePosition models
class VehicleDescriptor(BaseModel):
    """Vehicle descriptor identifying a physical vehicle."""

    id: Optional[str] = None  # Vehicle ID
    label: Optional[str] = None  # Human-readable label (e.g., "5123")


class Position(BaseModel):
    """Geographic position of a vehicle."""

    latitude: float
    longitude: float
    bearing: Optional[float] = None  # 0-360 degrees
    speed: Optional[float] = None  # m/s


class VehiclePosition(BaseModel):
    """Vehicle position from GTFS-RT feed (location, occupancy)."""

    trip: Optional[TripDescriptor] = None
    vehicle: Optional[VehicleDescriptor] = None
    position: Optional[Position] = None
    current_stop_sequence: Optional[int] = None
    current_status: Optional[str] = None  # INCOMING_AT, STOPPED_AT, IN_TRANSIT_TO
    timestamp: Optional[int] = None  # Unix timestamp
    occupancy_status: Optional[int] = None  # 0-8 (0=EMPTY, 1=MANY_SEATS, ..., 8=FULL)


# ServiceAlert models
class TimeRange(BaseModel):
    """Time range for alert active period."""

    start: Optional[int] = None  # Unix timestamp (None = unbounded start)
    end: Optional[int] = None  # Unix timestamp (None = unbounded end)


class EntitySelector(BaseModel):
    """Entity selector identifying affected routes/stops/trips."""

    agency_id: Optional[str] = None
    route_id: Optional[str] = None
    route_type: Optional[int] = None  # GTFS route_type (0=tram, 1=metro, 2=rail, 3=bus, 4=ferry)
    trip: Optional[TripDescriptor] = None
    stop_id: Optional[str] = None


class ServiceAlert(BaseModel):
    """Service alert from GTFS-RT feed (disruptions, planned work).

    Represents a disruption or planned work affecting transit service.
    Used for:
    - Real-time disruption notifications
    - Alert matching for user favorites
    - Push notification filtering
    """

    id: str  # Alert ID (stable across updates)
    header_text: str  # Short summary (e.g., "T1 Line delays")
    description_text: Optional[str] = None  # Detailed description
    effect: Optional[str] = None  # Effect enum: NO_SERVICE, REDUCED_SERVICE, SIGNIFICANT_DELAYS, etc.
    cause: Optional[str] = None  # Cause enum: CONSTRUCTION, ACCIDENT, WEATHER, etc.
    active_period: List[TimeRange] = Field(default_factory=list)  # When alert is active
    informed_entity: List[EntitySelector] = Field(default_factory=list)  # What's affected
    severity_level: Optional[str] = None  # Severity enum: WARNING, SEVERE, INFO

    class Config:
        """Pydantic config."""

        # Allow arbitrary types for future extensions
        arbitrary_types_allowed = True
