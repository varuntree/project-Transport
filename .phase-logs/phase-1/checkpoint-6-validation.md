# Checkpoint 6 Validation Results

## Endpoints Created

1. **GET /api/v1/stops/nearby** - PostGIS spatial query
2. **GET /api/v1/stops/search** - Text search with pg_trgm
3. **GET /api/v1/stops/{stop_id}** - Stop details with routes
4. **GET /api/v1/stops/{stop_id}/departures** - Pattern model departures

## Critical Fix: exec_raw_sql RPC

The original RPC implementation was incorrect and returned an integer instead of JSON array.

Fixed implementation:
```sql
CREATE OR REPLACE FUNCTION exec_raw_sql(query text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result jsonb;
BEGIN
  -- Execute query and convert results to JSONB array
  EXECUTE format('SELECT jsonb_agg(row_to_json(t)) FROM (%s) t', query) INTO result;
  RETURN COALESCE(result, '[]'::jsonb);
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Query execution failed: %', SQLERRM;
END;
$$;
```

## Validation Tests

### 1. Nearby Stops (PostGIS)
```bash
curl 'http://localhost:8000/api/v1/stops/nearby?lat=-33.8615&lon=151.2106&radius=500&limit=3'
```
✓ Returns 3 stops near Circular Quay
✓ Distance calculated correctly (27.6m, 32.8m, 38.7m)
✓ PostGIS lon,lat order verified correct

### 2. Get Stop by ID
```bash
curl 'http://localhost:8000/api/v1/stops/200013'
```
✓ Returns stop details: "Sussex St at Erskine St"
✓ Routes array populated: 3 routes serving this stop

### 3. Search Stops
```bash
curl 'http://localhost:8000/api/v1/stops/search?q=circular&limit=3'
```
✓ Returns 3 stops matching "circular"
✓ Trigram similarity scores: 0.409 (good match)
✓ Results ordered by relevance

### 4. Get Departures
```bash
curl 'http://localhost:8000/api/v1/stops/200013/departures?limit=3'
```
✓ Returns 3 departures for stop 200013
✓ Pattern model JOIN works: route 288 trips
✓ Calendar date filtering works (2025-11-13 within range)

## Envelope Pattern Compliance

All responses follow INTEGRATION_CONTRACTS.md envelope:

```json
{
  "data": { ... },
  "meta": {
    "pagination": { "offset": 0, "limit": N, "total": N },
    "query": { ... }
  }
}
```

## Structured Logging

All endpoints log JSON events:
- `stops_nearby_request`: lat, lon, radius, result_count, duration_ms
- `stop_fetched`: stop_id, routes_count, duration_ms
- `stops_search`: query, result_count, duration_ms
- `departures_fetched`: stop_id, time_epoch, result_count, duration_ms

## Known Limitations (Phase 1)

1. **Departures query simplified**: No real-time data yet (Phase 2)
2. **SQL injection risk**: Basic sanitization only (Phase 2 adds parameterized queries)
3. **No day-of-week filtering**: Calendar check simplified (Phase 2 adds proper validation)
4. **Some stops have no trips**: Pattern model coverage depends on GTFS data quality

## Files Created

- `backend/app/models/stops.py` - Pydantic models
- `backend/app/api/v1/stops.py` - FastAPI router (4 endpoints)
- `backend/app/api/__init__.py` - API package init
- `backend/app/api/v1/__init__.py` - v1 API package init

## Files Modified

- `backend/app/main.py` - Registered stops router

## Database Changes

- Fixed `exec_raw_sql` RPC function (replaced in Supabase)
