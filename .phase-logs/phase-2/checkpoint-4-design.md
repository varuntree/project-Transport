# Checkpoint 4: Real-Time Departures Service (Merge Static + RT)

## Goal
Fetch static schedules from Supabase, enrich with Redis RT delays. Service returns merged departures with delay_s, realtime flag.

## Approach

### Backend Implementation
- Create `backend/app/services/realtime_service.py`
- Function: `async def get_realtime_departures(stop_id: str, now_secs: int, limit: int = 10) -> List[Dict]`
- **Step 1: Fetch static schedules (reuse Phase 1 query):**
  ```python
  # Query pattern model (trips → pattern_stops → routes)
  # Same query as Phase 1 /stops/{id}/departures, returns:
  # [{trip_id, route_id, route_short_name, headsign, departure_time_secs}]
  ```
- **Step 2: Determine modes from route_ids (heuristic):**
  ```python
  def determine_mode(route_id: str) -> str:
      if route_id.startswith('T') or route_id.startswith('BMT'):
          return 'sydneytrains'
      elif route_id.startswith('M'):
          return 'metro'
      elif route_id.startswith('F'):
          return 'ferries'
      elif route_id.startswith('L'):
          return 'lightrail'
      else:
          return 'buses'

  modes_needed = {determine_mode(r['route_id']) for r in static_deps}
  ```
- **Step 3: Fetch Redis RT delays:**
  ```python
  trip_delays = {}  # {trip_id: delay_s}
  for mode in modes_needed:
      try:
          blob = redis.get(f'tu:{mode}:v1')
          if blob:
              data = json.loads(gzip.decompress(blob))
              for tu in data:
                  trip_delays[tu['trip_id']] = tu.get('delay_s', 0)
      except (gzip.BadGzipFile, json.JSONDecodeError, redis.exceptions.RedisError):
          logger.warning('realtime_fetch_failed', mode=mode, error=str(e))
  ```
- **Step 4: Merge static + RT:**
  ```python
  departures = []
  for dep in static_deps:
      delay_s = trip_delays.get(dep['trip_id'], 0)
      realtime_time_secs = dep['departure_time_secs'] + delay_s
      departures.append({
          'trip_id': dep['trip_id'],
          'route_short_name': dep['route_short_name'],
          'headsign': dep['headsign'],
          'scheduled_time_secs': dep['departure_time_secs'],
          'realtime_time_secs': realtime_time_secs,
          'delay_s': delay_s,
          'realtime': delay_s != 0
      })

  # Sort by realtime_time_secs, limit to 10
  departures.sort(key=lambda x: x['realtime_time_secs'])
  return departures[:limit]
  ```

### Critical Pattern
- **Graceful degradation:** If Redis miss or gzip error, fallback to `delay_s=0, realtime=false` (static schedule)
- **Mode heuristic:** Route ID prefixes determine which Redis tu:{mode}:v1 blob to fetch
- **Gzip decompress:** `gzip.decompress(blob)` then `json.loads()` to parse cached data

## Design Constraints
- Follow PHASE_2_REALTIME.md:L375-451 for merge algorithm
- Route ID heuristics per PHASE_2_REALTIME.md:L410-425
- Must handle Redis misses gracefully: `delay_s=0, realtime=false` (static fallback)
- Must handle gzip.decompress errors (corrupt blob), json.JSONDecodeError (invalid JSON)
- Log structured event: `logger.info('realtime_departures_fetched', stop_id=stop_id, realtime_count=N, static_count=M)`

## Risks
- Supabase query slow (>2s) → service timeout
  - Mitigation: Reuse Phase 1 optimized query (pattern model with indexes, <500ms)
- Redis miss → all static departures
  - Mitigation: Expected behavior (graceful degradation), log at INFO level (not ERROR)
- Trip ID mismatch between Supabase and NSW GTFS-RT (rare)
  - Mitigation: Fallback to delay_s=0 (treated as static), log mismatch at WARNING level

## Validation
```bash
# Python REPL test:
cd backend
source venv/bin/activate
python3
>>> from app.services.realtime_service import get_realtime_departures
>>> import asyncio
>>> asyncio.run(get_realtime_departures('200060', 32400, 10))
# Expected: List of departures, some with delay_s != 0 if NSW has delays
# Check: realtime: true for trips with delay_s > 0
# Check: sorted by realtime_time_secs (earliest departure first)

# If Redis empty (no workers running):
# Expected: All departures have delay_s=0, realtime=false (static fallback)
```

## References for Subagent
- Exploration patterns: critical_patterns → "Gzip blob caching"
- Architecture: PHASE_2_REALTIME.md:L375-451 (merge algorithm)
- API contract: INTEGRATION_CONTRACTS.md:L163-228 (response format)
- Standards: DEVELOPMENT_STANDARDS.md:Section 3 (error handling, logging)

## Estimated Complexity
**moderate** - Reuse Phase 1 query, add Redis fetch + gzip decompress, merge logic, error handling
