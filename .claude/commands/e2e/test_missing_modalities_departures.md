# E2E Test: Multimodal Search and Departures

Test that all transport modalities (buses, ferries, light rail, trains, metro) appear in search results and that departures load successfully for non-train stops.

## User Story

As a Sydney transit user
I want to search for stops across all transport modes
So that I can find buses, ferries, light rail, and trains, not just trains

## Prerequisites

- Backend FastAPI server running on http://localhost:8000
- GTFS static data loaded to Supabase (all 6 modes)
- Celery worker running to populate GTFS-RT data in Redis

## Test Steps

### 1. Search for bus stops
```bash
curl -s "http://localhost:8000/api/v1/stops/search?q=town+hall" | jq '.data.stops[0:3]'
```
**Verify:** Results include bus stops (location_type=0 or 1)
**Verify:** At least one result has a stop_name containing "Town Hall"

### 2. Search for ferry stops
```bash
curl -s "http://localhost:8000/api/v1/stops/search?q=circular+quay" | jq '.data.stops[0:3]'
```
**Verify:** Results include ferry wharfs (Circular Quay is a major ferry terminal)
**Verify:** At least 2 stops returned

### 3. Search for light rail stops
```bash
curl -s "http://localhost:8000/api/v1/stops/search?q=dulwich+hill" | jq '.data.stops[0:3]'
```
**Verify:** Results include "Dulwich Hill Light Rail" stop
**Verify:** At least 1 result returned

### 4. Get departures for a bus stop (Town Hall)
```bash
curl -s "http://localhost:8000/api/v1/stops/2000249/departures" | jq '{count: .data.count, sample: .data.departures[0] | {route: .route_short_name, headsign, scheduled_time_secs, delay_s}}'
```
**Verify:** count > 0 (at least 1 departure)
**Verify:** sample.route is a bus route (e.g., starts with digit or "S")
**Verify:** sample.scheduled_time_secs is a valid epoch time
**Verify:** sample.delay_s is an integer (0 if no RT data)

### 5. Get departures for a ferry stop (Circular Quay Wharf 2)
```bash
curl -s "http://localhost:8000/api/v1/stops/20003/departures" | jq '{count: .data.count, modes: [.data.departures[].route_short_name] | unique}'
```
**Verify:** count > 0
**Verify:** modes includes ferry routes (e.g., "F1", "F2", "MFF", or other ferry routes)

### 6. Get departures for a light rail stop (Dulwich Hill)
```bash
curl -s "http://localhost:8000/api/v1/stops/220363/departures" | jq '{count: .data.count, sample: .data.departures[0] | {route: .route_short_name, route_type, headsign}}'
```
**Verify:** count > 0
**Verify:** sample.route is "L1" (light rail line)
**Verify:** sample.route_type is 900 (extended GTFS type for light rail)

### 7. Verify route_type distribution
```bash
curl -s "http://localhost:8000/api/v1/stops/search?q=central" | jq '[.data.stops[0:10][]] | group_by(.location_type) | map({location_type: .[0].location_type, count: length})'
```
**Verify:** Results include multiple location_types (0 and 1 for platforms and stations)

## Success Criteria

- ✅ Bus stops appear in search results
- ✅ Ferry stops appear in search results
- ✅ Light rail stops appear in search results
- ✅ Departures endpoint returns data for bus stops (count > 0)
- ✅ Departures endpoint returns data for ferry stops (count > 0)
- ✅ Departures endpoint returns data for light rail stops (count > 0, route_type=900)
- ✅ No 500 errors returned by any endpoint
- ✅ Static departures work (scheduled_time_secs populated) even if realtime=false

## Failure Cases (should NOT occur)

- ❌ Search results only contain train stops (route_type=2)
- ❌ Departures endpoint returns 500 error
- ❌ Departures endpoint returns 0 departures for major stops like Town Hall or Circular Quay
- ❌ Light rail stops missing from search (route_type=900 routes exist in DB)

## Expected Output Format

All API responses should follow the envelope format:
```json
{
  "data": { ... },
  "meta": { "pagination": {...}, "query": {...} }
}
```

Departures should include:
```json
{
  "trip_id": "string",
  "route_short_name": "string",
  "route_long_name": "string",
  "route_type": 2|4|401|700|712|900,
  "headsign": "string",
  "scheduled_time_secs": 12345,
  "realtime_time_secs": 12345,
  "delay_s": 0,
  "realtime": false,
  "stop_sequence": 1
}
```
