# Checkpoint 10: Graceful Degradation Test

## Goal
Verify offline/stale cache behavior. Backend serves static schedules when Redis expired. iOS shows error message when offline.

## Approach

### Testing Strategy
- Test 3 scenarios:
  1. **Stale cache fallback:** Stop workers, wait for Redis TTL expiry, verify API returns static schedules
  2. **iOS offline mode:** Disable Wi-Fi in simulator, verify error message (no crash)
  3. **Network recovery:** Re-enable Wi-Fi, verify departures refresh

### Manual Test Steps

#### Test 1: Stale Cache Fallback
1. **Start backend + workers + beat:**
   ```bash
   # Terminal 1: cd backend && uvicorn app.main:app --reload
   # Terminal 2: cd backend && bash scripts/start_worker_critical.sh
   # Terminal 3: cd backend && bash scripts/start_beat.sh
   ```

2. **Wait 30s for first Redis cache, verify RT data:**
   ```bash
   curl 'http://localhost:8000/api/v1/stops/200060/departures' | jq '.data[] | {realtime, delay_s}'
   # Expected: Some items have realtime: true, delay_s > 0
   ```

3. **Stop workers (Ctrl+C in terminals 2-3), wait 2min for TTL expiry:**
   ```bash
   redis-cli TTL vp:buses:v1
   # Wait until returns -2 (key expired)
   ```

4. **Re-test API:**
   ```bash
   curl 'http://localhost:8000/api/v1/stops/200060/departures' | jq '.data[] | {realtime, delay_s}'
   # Expected: All items have realtime: false, delay_s: 0 (static fallback)
   # Expected: HTTP 200 OK (not 503 Service Unavailable)
   ```

5. **iOS simulator: Verify departures still load (static data):**
   - List populates (static schedules)
   - No delay badges (delay_s == 0)
   - No error message (graceful degradation)

#### Test 2: iOS Offline Mode
1. **iOS simulator → Settings → Wi-Fi off** (or Xcode → Network Link Conditioner → 100% Loss)

2. **Navigate to departures:**
   - Tap stop → 'View Departures'
   - Error message "No internet connection" (or similar)
   - No crash, app remains functional
   - Can browse offline GRDB data (search stops, view stop details)

#### Test 3: Network Recovery
1. **iOS simulator → Settings → Wi-Fi on**

2. **Verify departures refresh:**
   - Error message disappears
   - List populates (static fallback if workers still stopped)
   - Pull-to-refresh works

3. **Restart workers, wait 30s:**
   ```bash
   # Terminal 2: cd backend && bash scripts/start_worker_critical.sh
   # Terminal 3: cd backend && bash scripts/start_beat.sh
   ```

4. **iOS pull-to-refresh:**
   - Delays reappear (realtime: true)
   - Countdown updates

## Design Constraints
- Must verify stale cache → static fallback (no 503 errors)
- Must verify iOS offline mode → error message (no crash)
- Must verify network recovery → seamless transition
- iOS Research: `.phase-logs/phase-2/ios-research-network-monitor.md` (NWPathMonitor for offline detection)

## Validation
```bash
# Success criteria:
# - Stale cache: API returns static (realtime: false, delay_s: 0), HTTP 200
# - iOS offline: Error message "No internet connection", no crash
# - Network recovery: Offline banner disappears, departures refresh
# - Logs: Backend logs stale state at INFO level (not ERROR)

# If fails:
# - Check backend error handling (gzip.decompress exceptions caught)
# - Check iOS error handling (URLError.notConnectedToInternet handled)
# - Check iOS network monitor (NWPathMonitor.pathUpdateHandler firing)
```

## References for Subagent
- iOS Research: `.phase-logs/phase-2/ios-research-network-monitor.md` (NWPathMonitor)
- Architecture: BACKEND_SPECIFICATION.md:Section 5.3 (graceful degradation)
- Pattern: PHASE_2_REALTIME.md:L800-811
- Standards: DEVELOPMENT_STANDARDS.md:Section 5 (error handling)

## Estimated Complexity
**simple** - Manual testing checklist, no code changes (all logic implemented in previous checkpoints)
