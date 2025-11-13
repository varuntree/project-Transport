# Checkpoint 7: Routes + GTFS API Endpoints

## Goal
Create routes endpoints (list, get by ID) + GTFS endpoints (version, download iOS SQLite). FileResponse for gtfs.db download, query gtfs_metadata for version.

## Approach

### Backend Implementation
- Create two FastAPI routers: routes, gtfs
- Files to create:
  - `app/api/v1/routes.py` - Routes router (list, get)
  - `app/api/v1/gtfs.py` - GTFS router (version, download)
  - `app/models/routes.py` - Pydantic models
- Files to modify:
  - `backend/app/main.py` - Register 2 routers
- Critical pattern: FileResponse for large file streaming, envelope pattern for JSON responses

### Implementation Details

**Routes Endpoint 1: GET /api/v1/routes**

Query params:
- `type` (optional): Filter by route_type (0=tram, 1=metro, 2=rail, 3=bus, 4=ferry)
- `offset` (optional, default=0): Pagination offset
- `limit` (optional, default=20): Page size

Query:
```python
from app.db.supabase_client import get_supabase_client

supabase = get_supabase_client()

query = supabase.table("routes").select("*", count="exact")

if route_type is not None:
    query = query.eq("route_type", route_type)

result = query.range(offset, offset + limit - 1).execute()

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
```

**Routes Endpoint 2: GET /api/v1/routes/{route_id}**

Path param: `route_id` (e.g., "T1")

Query:
```python
result = supabase.table("routes").select("*").eq("route_id", route_id).execute()
if not result.data:
    raise HTTPException(status_code=404, detail=f"Route {route_id} not found")

return {"data": result.data[0], "meta": {}}
```

**GTFS Endpoint 1: GET /api/v1/gtfs/version**

No params - returns latest feed metadata

Query:
```python
result = supabase.table("gtfs_metadata") \
    .select("*") \
    .order("processed_at", desc=True) \
    .limit(1) \
    .execute()

if not result.data:
    raise HTTPException(status_code=404, detail="No GTFS data loaded")

return {"data": result.data[0], "meta": {}}
```

Response example:
```json
{
  "data": {
    "feed_version": "2025-11-13",
    "feed_start_date": "2025-11-01",
    "feed_end_date": "2026-01-31",
    "processed_at": "2025-11-13T10:30:00Z",
    "stops_count": 15000,
    "routes_count": 800,
    "patterns_count": 5000,
    "trips_count": 120000
  },
  "meta": {}
}
```

**GTFS Endpoint 2: GET /api/v1/gtfs/download**

No params - streams iOS SQLite file

Implementation:
```python
from fastapi.responses import FileResponse
import os

@router.get("/download")
async def download_gtfs_db():
    db_path = "ios_output/gtfs.db"

    if not os.path.exists(db_path):
        raise HTTPException(status_code=404, detail="iOS SQLite not generated yet")

    # Log download request
    logger.info("gtfs_download_requested", file_size_mb=os.path.getsize(db_path) / 1024 / 1024)

    return FileResponse(
        path=db_path,
        media_type="application/x-sqlite3",
        filename="gtfs.db",
        headers={
            "Content-Disposition": "attachment; filename=gtfs.db"
        }
    )
```

**Pydantic Models:**
```python
# app/models/routes.py
from pydantic import BaseModel

class RouteResponse(BaseModel):
    route_id: str
    route_short_name: str
    route_long_name: str
    route_type: int  # 0=tram, 1=metro, 2=rail, 3=bus, 4=ferry
    route_color: str | None
    route_text_color: str | None

class GTFSMetadataResponse(BaseModel):
    feed_version: str
    feed_start_date: str  # YYYY-MM-DD
    feed_end_date: str
    processed_at: str  # ISO 8601
    stops_count: int
    routes_count: int
    patterns_count: int
    trips_count: int
```

**Router Registration:**
```python
# app/main.py
from app.api.v1 import routes, gtfs

app.include_router(routes.router, prefix="/api/v1", tags=["routes"])
app.include_router(gtfs.router, prefix="/api/v1/gtfs", tags=["gtfs"])
```

## Design Constraints
- **FileResponse streaming:** Don't load entire file to memory, stream chunks
- **Content-Disposition header:** Forces browser to download (not display)
- **route_type enum:** 0=Tram, 1=Metro/Subway, 2=Rail, 3=Bus, 4=Ferry, 7=Funicular (GTFS spec)
- **Pagination:** Use Supabase `.range(start, end)` method
- **Error handling:** 404 for missing route/metadata, 500 for file read errors
- Follow INTEGRATION_CONTRACTS.md:Section 2.5-2.7 for contracts
- Follow DEVELOPMENT_STANDARDS.md:Section 2.2 for API patterns

## Risks
- **Large file download:** 15-20MB gtfs.db over slow network
  - Mitigation: FileResponse streams automatically, client handles resume
- **File missing:** iOS DB not generated yet
  - Mitigation: Check file exists, return 404 with clear error
- **routes list OOM:** Pagination with limit=1000 requested
  - Mitigation: Max limit = 100 (validate param)
- **Concurrent downloads:** Multiple iOS clients downloading simultaneously
  - Mitigation: Read-only file, no locking issues

## Validation
```bash
# Start backend
cd backend
uvicorn app.main:app --reload

# Test routes list
curl http://localhost:8000/api/v1/routes
# Expected: {"data": [{route_id: "T1", route_short_name: "T1", route_type: 1}, ...], "meta": {"pagination": {total: 800, ...}}}

# Test routes list with filter
curl 'http://localhost:8000/api/v1/routes?type=1'
# Expected: Only metro/train routes (route_type=1)

# Test route by ID
curl http://localhost:8000/api/v1/routes/T1
# Expected: {"data": {route_id: "T1", route_long_name: "North Shore Line", ...}, "meta": {}}

# Test GTFS version
curl http://localhost:8000/api/v1/gtfs/version
# Expected: {"data": {feed_version: "2025-11-13", stops_count: 15000, ...}, "meta": {}}

# Test GTFS download
curl -O http://localhost:8000/api/v1/gtfs/download
ls -lh gtfs.db
# Expected: 15-20MB file downloaded

# Verify SQLite integrity
sqlite3 gtfs.db "SELECT COUNT(*) FROM stops;"
# Expected: Matches stops_count from version endpoint
```

## References for Subagent
- Exploration report: `critical_patterns` → "API response envelope (data + meta)"
- Standards: DEVELOPMENT_STANDARDS.md:Section 2.2 (API patterns)
- Architecture: INTEGRATION_CONTRACTS.md:Section 2.5-2.7 (routes, gtfs endpoints)
- Supabase client: backend/app/db/supabase_client.py
- FileResponse: FastAPI docs (streaming files)
- iOS SQLite: Checkpoint 5 output (backend/ios_output/gtfs.db)

## Estimated Complexity
**simple** - Straightforward CRUD endpoints, FileResponse well-documented, pagination standard pattern
