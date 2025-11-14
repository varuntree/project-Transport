# Checkpoint 9: Integration Test (Backend + iOS Real-Time)

## Goal
End-to-end test: Worker polls → Redis caches → API serves → iOS displays. Verify 30s auto-refresh synchronizes with backend polling.

## Approach

### Testing Strategy
- Start all services: backend, worker, beat, iOS simulator
- Verify data flows through entire stack:
  1. Celery Beat triggers poll_gtfs_rt every 30s
  2. Worker fetches NSW API, caches to Redis (vp:*, tu:*)
  3. iOS calls API, API enriches static schedules with Redis RT delays
  4. iOS displays departures with delays, countdown timers
  5. iOS auto-refreshes every 30s, countdown updates

### Manual Test Steps
1. **Start backend + workers + beat:**
   ```bash
   # Terminal 1: cd backend && source venv/bin/activate && uvicorn app.main:app --reload
   # Terminal 2: cd backend && bash scripts/start_worker_critical.sh
   # Terminal 3: cd backend && bash scripts/start_beat.sh
   ```

2. **Wait 30s for first Redis cache:**
   ```bash
   redis-cli KEYS vp:*  # Expect 5 keys
   redis-cli KEYS tu:*  # Expect 5 keys
   redis-cli TTL vp:buses:v1  # Expect 60-75s
   ```

3. **Start iOS simulator:**
   ```bash
   open SydneyTransit.xcodeproj
   # Cmd+R to run simulator
   ```

4. **Navigate to departures:**
   - Tap stop → 'View Departures'
   - List populates (<2s initial load)
   - Delays show '+X min' if NSW has delays
   - Countdown shows '5 min' (or similar)

5. **Wait 30s:**
   - List auto-refreshes (loading indicator briefly)
   - Countdown updates to '4 min'
   - Delays still show (or updated if NSW changed)

6. **Pull-to-refresh:**
   - Pull down list
   - Loading indicator appears
   - Refresh completes (<2s)

7. **Check Redis TTL throughout test:**
   ```bash
   redis-cli TTL vp:buses:v1
   # Should be 60-75s throughout test (not decreasing to 0)
   ```

8. **Check logs (structured JSON):**
   - Worker: `poll_gtfs_rt_started`, `vp_cached`, `tu_cached`, `poll_gtfs_rt_complete`
   - Backend: `departures_fetched`, `stop_id=200060`, `realtime_count=X`

## Design Constraints
- Must test full stack: Celery Beat → Worker → Redis → FastAPI → iOS
- Verify 30s auto-refresh synchronizes with backend polling
- Verify graceful degradation if Redis misses (static fallback)
- No auth yet—all anonymous endpoints

## Validation
```bash
# Success criteria:
# - List populates (<2s initial load)
# - Delays show '+X min' if NSW has delays
# - Auto-refresh every 30s (countdown changes)
# - Pull-to-refresh works (loading indicator)
# - Redis TTL stays 60-75s throughout (not expiring)
# - Logs show structured JSON events (not raw protobuf dumps)

# If fails:
# - Check Redis connection (redis-cli PING)
# - Check NSW API key (curl NSW API directly)
# - Check worker logs for errors (protobuf parse errors, timeout errors)
# - Check backend logs for Redis errors (gzip decompress errors)
```

## References for Subagent
- Acceptance criteria: exploration-report.json (lines 250-264)
- Architecture: Full stack flow (SYSTEM_OVERVIEW.md)

## Estimated Complexity
**simple** - Manual testing checklist, no code changes
