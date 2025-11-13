# Checkpoint 6: Stops API Endpoints

## Goal
Create 4 stops endpoints: nearby (PostGIS spatial), get by ID, search (text), departures (pattern model). All responses use envelope pattern. PostGIS query must swap lat/lon → lon/lat order.

## Approach

### Backend Implementation
- Create FastAPI router for stops endpoints
- Files to create:
  - `app/api/v1/stops.py` - Stops router with 4 endpoints
  - `app/models/stops.py` - Pydantic request/response models
- Files to modify:
  - `backend/app/main.py` - Register stops router
- Critical pattern: API envelope (data + meta), PostGIS lon/lat order!, structured logging

### Implementation Details

**Endpoint 1: GET /api/v1/stops/nearby**

Query params:
- `lat` (required): Latitude (e.g., -33.8615)
- `lon` (required): Longitude (e.g., 151.2106)
- `radius` (optional, default=500): Radius in meters
- `limit` (optional, default=20): Max results

PostGIS Query (CRITICAL - lon,lat order!):
```python
from app.db.supabase_client import get_supabase_client

supabase = get_supabase_client()

# PostGIS: ST_DWithin expects (lon, lat) not (lat, lon)!
query = f"""
SELECT stop_id, stop_name, stop_code, stop_lat, stop_lon,
       ST_Distance(location, ST_MakePoint({lon}, {lat})::geography) AS distance_meters
FROM stops
WHERE ST_DWithin(location::geography, ST_MakePoint({lon}, {lat})::geography, {radius})
ORDER BY distance_meters ASC
LIMIT {limit}
"""

result = supabase.rpc("exec_raw_sql", {"query": query}).execute()
stops = result.data

return {
    "data": stops,
    "meta": {
        "pagination": {"offset": 0, "limit": limit, "total": len(stops)},
        "query": {"lat": lat, "lon": lon, "radius": radius}
    }
}
```

**Endpoint 2: GET /api/v1/stops/{stop_id}**

Path param: `stop_id` (e.g., "200060")

Query:
```python
result = supabase.table("stops").select("*").eq("stop_id", stop_id).execute()
if not result.data:
    raise HTTPException(status_code=404, detail=f"Stop {stop_id} not found")

return {"data": result.data[0], "meta": {}}
```

**Endpoint 3: GET /api/v1/stops/search**

Query params:
- `q` (required): Search query (e.g., "circular")
- `limit` (optional, default=20)

Text Search (PostgreSQL FTS):
```python
# Use pg_trgm for fuzzy search
query = f"""
SELECT stop_id, stop_name, stop_code, stop_lat, stop_lon,
       similarity(stop_name, '{q}') AS score
FROM stops
WHERE stop_name % '{q}'  -- Trigram similarity operator
ORDER BY score DESC
LIMIT {limit}
"""

result = supabase.rpc("exec_raw_sql", {"query": query}).execute()

return {
    "data": result.data,
    "meta": {
        "pagination": {"offset": 0, "limit": limit, "total": len(result.data)},
        "query": {"q": q}
    }
}
```

**Endpoint 4: GET /api/v1/stops/{stop_id}/departures**

Query params:
- `time` (optional): Unix epoch seconds (default: now)
- `limit` (optional, default=20)

Pattern Model Query (Complex JOIN):
```python
import time as time_module
from datetime import datetime

now_epoch = time if time else int(time_module.time())
now_date = datetime.utcfromtimestamp(now_epoch).strftime("%Y%m%d")
now_secs = now_epoch % 86400  # Seconds since midnight

query = f"""
SELECT
  t.trip_id,
  t.trip_headsign,
  r.route_short_name,
  r.route_long_name,
  r.route_type,
  ps.departure_offset_secs,
  ps.stop_sequence,
  (t.start_time + ps.departure_offset_secs) AS departure_epoch
FROM pattern_stops ps
JOIN patterns p ON ps.pattern_id = p.pattern_id
JOIN trips t ON t.pattern_id = p.pattern_id
JOIN routes r ON t.route_id = r.route_id
JOIN calendar c ON t.service_id = c.service_id
WHERE ps.stop_id = '{stop_id}'
  AND c.start_date <= '{now_date}'
  AND c.end_date >= '{now_date}'
  AND (t.start_time + ps.departure_offset_secs) >= {now_secs}
ORDER BY departure_epoch ASC
LIMIT {limit}
"""

# Note: This is simplified - Phase 2 adds calendar day-of-week checks
result = supabase.rpc("exec_raw_sql", {"query": query}).execute()

return {
    "data": result.data,
    "meta": {
        "pagination": {"offset": 0, "limit": limit, "total": len(result.data)},
        "query": {"stop_id": stop_id, "time": now_epoch}
    }
}
```

**Pydantic Models:**
```python
# app/models/stops.py
from pydantic import BaseModel, Field

class StopResponse(BaseModel):
    stop_id: str
    stop_name: str
    stop_code: str | None
    stop_lat: float
    stop_lon: float
    wheelchair_boarding: int | None

class StopNearbyResponse(StopResponse):
    distance_meters: float

class DepartureResponse(BaseModel):
    trip_id: str
    trip_headsign: str
    route_short_name: str
    route_long_name: str
    route_type: int
    departure_epoch: int
    stop_sequence: int
```

**Router Registration:**
```python
# app/main.py
from app.api.v1 import stops

app.include_router(stops.router, prefix="/api/v1", tags=["stops"])
```

## Design Constraints
- **PostGIS coordinate swap:** ST_MakePoint(lon, lat) - LONGITUDE FIRST!
- **Envelope pattern:** All responses {"data": ..., "meta": {"pagination": ...}}
- **Error handling:** 404 for stop not found, 400 for invalid coordinates
- **SQL injection:** Use RPC with parameterized queries (or sanitize inputs)
- **Logging:** Log each request: `logger.info("stops_nearby_request", lat=lat, lon=lon, radius=radius, result_count=len(stops))`
- Follow INTEGRATION_CONTRACTS.md:Section 2.1-2.4 for response structure
- Follow DEVELOPMENT_STANDARDS.md:Section 2.2 for API patterns

## Risks
- **PostGIS lat/lon confusion:** API receives (lat, lon) but PostGIS expects (lon, lat)
  - Mitigation: Explicit variable names `lon_first`, `lat_second` in query construction
- **SQL injection:** String interpolation in RPC queries
  - Mitigation: Phase 2 adds proper parameterization, for now sanitize inputs (reject special chars)
- **departures query slow:** Complex JOIN across 5 tables
  - Mitigation: Indexes on pattern_id, service_id (created in Checkpoint 3)
- **Empty results:** No departures for given time
  - Mitigation: Return empty array (not 404), user-friendly message in Phase 2

## Validation
```bash
# Start backend
cd backend
uvicorn app.main:app --reload

# Test nearby (Circular Quay coordinates)
curl 'http://localhost:8000/api/v1/stops/nearby?lat=-33.8615&lon=151.2106&radius=500'
# Expected: {"data": [{stop_name: "Circular Quay ...", distance_meters: 45.2}, ...], "meta": {...}}

# Test get by ID
curl http://localhost:8000/api/v1/stops/200060
# Expected: {"data": {stop_id: "200060", stop_name: "...", ...}, "meta": {}}

# Test search
curl 'http://localhost:8000/api/v1/stops/search?q=circular'
# Expected: {"data": [{stop_name: "Circular Quay ...", score: 0.87}, ...], "meta": {...}}

# Test departures (use current epoch time)
curl "http://localhost:8000/api/v1/stops/200060/departures?time=$(date +%s)"
# Expected: {"data": [{trip_id: "...", trip_headsign: "Central", route_short_name: "T1", departure_epoch: 1699123456}, ...], "meta": {...}}

# Check logs (structured JSON):
# stops_nearby_request: lat=-33.8615, lon=151.2106, radius=500, result_count=5, duration_ms=120
```

## References for Subagent
- Exploration report: `critical_patterns` → "API response envelope (data + meta)"
- Standards: DEVELOPMENT_STANDARDS.md:Section 2.2 (API patterns)
- Architecture: INTEGRATION_CONTRACTS.md:Section 2.1-2.4 (stops endpoints)
- PostGIS: DATA_ARCHITECTURE.md:L176-199 (lon,lat order warning!)
- RPC: Checkpoint 3 (exec_raw_sql function)
- Existing router: backend/app/main.py (Phase 0 health endpoint pattern)

## Estimated Complexity
**moderate** - FastAPI routing straightforward, but PostGIS coordinate swap critical, complex JOIN for departures, SQL injection risk requires careful handling
