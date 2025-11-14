# Checkpoint 5: Update Stops API for Real-Time

## Goal
Replace static departures endpoint with realtime_service. API returns realtime: true for delayed trips.

## Approach

### Backend Implementation
- Update `backend/app/api/v1/stops.py`
- Replace `@router.get('/stops/{stop_id}/departures')` handler:
  ```python
  from app.services.realtime_service import get_realtime_departures
  import pytz
  from datetime import datetime

  @router.get('/stops/{stop_id}/departures')
  async def get_stop_departures(stop_id: str, time: Optional[int] = None):
      # Default time to now (seconds since midnight Sydney)
      if time is None:
          sydney_tz = pytz.timezone('Australia/Sydney')
          now = datetime.now(sydney_tz)
          midnight = now.replace(hour=0, minute=0, second=0, microsecond=0)
          time = int((now - midnight).total_seconds())

      # Validate time range (0-86399)
      if not (0 <= time < 86400):
          raise HTTPException(status_code=400, detail="Invalid time parameter (0-86399)")

      # Fetch realtime departures
      try:
          departures = await get_realtime_departures(stop_id, time, limit=10)
      except StopNotFoundError:
          raise HTTPException(status_code=404, detail=f"Stop {stop_id} not found")

      # Log event
      realtime_count = sum(1 for d in departures if d['realtime'])
      logger.info('departures_fetched', stop_id=stop_id, realtime_count=realtime_count, total=len(departures))

      return SuccessResponse(data=departures)
  ```

### Critical Pattern
- **Time parameter:** Defaults to now (seconds since midnight Sydney), allows manual override for testing
- **Error handling:** 404 if stop_id not found, 400 if time invalid
- **Structured logging:** Log realtime_count (how many trips have delays)

## Design Constraints
- Follow INTEGRATION_CONTRACTS.md:L163-228 for API response format
- Must handle `stop_id` not found (404), invalid `time` param (400)
- Must use pytz for Sydney timezone (not system timezone, can differ on server)
- Response format: `SuccessResponse(data=[...])` (Phase 1 pattern)

## Risks
- Timezone mismatch (server in UTC, Sydney DST) → wrong departures
  - Mitigation: Explicitly use `pytz.timezone('Australia/Sydney')`, not system timezone
- realtime_service exception not caught → 500 error
  - Mitigation: Catch generic exceptions, return 500 with error code (DEVELOPMENT_STANDARDS.md error handling)

## Validation
```bash
# Start backend + workers + beat (3 terminals):
# Terminal 1: cd backend && uvicorn app.main:app --reload
# Terminal 2: cd backend && bash scripts/start_worker_critical.sh
# Terminal 3: cd backend && bash scripts/start_beat.sh

# Wait 30s for first Redis cache, then test API:
curl 'http://localhost:8000/api/v1/stops/200060/departures'
# Expected: JSON response with data array
# Check: Some items have realtime: true, delay_s != 0 (if NSW has delays)
# Check: scheduled_time_secs < realtime_time_secs when delayed
# Check: Response includes meta: {pagination: null} (not paginated)

# Test without workers (graceful degradation):
# Stop workers (Ctrl+C in terminals 2-3), wait 2min for TTL expiry
curl 'http://localhost:8000/api/v1/stops/200060/departures'
# Expected: All items have realtime: false, delay_s: 0 (static fallback)

# Test 404:
curl 'http://localhost:8000/api/v1/stops/INVALID'
# Expected: 404 error with message "Stop INVALID not found"
```

## References for Subagent
- API contract: INTEGRATION_CONTRACTS.md:L163-228 (response format)
- Architecture: BACKEND_SPECIFICATION.md:Section 3 (API routes)
- Standards: DEVELOPMENT_STANDARDS.md:Section 5 (error handling)

## Estimated Complexity
**simple** - Update existing endpoint, add realtime_service call, timezone handling
