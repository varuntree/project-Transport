# Bug: Phase 2 System Stabilization - Multiple Critical Issues

## Bug Description
After completing Phase 0, Phase 1, and Phase 2 implementation, several critical bugs prevent the system from working correctly:

1. **Celery Task Registration Error**: `alert_matcher.match_delays_to_favorites` task is referenced in `celery_app.py` but the actual task file doesn't exist, causing "unregistered task" errors
2. **iOS Backend Connectivity**: iOS app shows "Backend unreachable - could not connect to server"
3. **GRDB Row Encoding Error**: RouteListView fails with "GRDB row encoding error 1" when loading routes
4. **Outdated Phase Labels**: HomeView still shows "Phase 0: Foundation" despite completing Phase 2; departures features showing when not fully implemented
5. **Missing Search Implementation**: Search functionality may not be properly connected

## Problem Statement
The system has implementation gaps and configuration mismatches that prevent Phase 0, 1, and 2 functionality from working end-to-end. Specifically:
- Backend Celery configuration references unimplemented Phase 5 tasks
- iOS app cannot connect to backend API
- iOS GRDB database queries failing due to model/schema mismatches
- UI labels don't reflect actual implementation progress

## Solution Statement
Fix all bugs systematically by:
1. Removing premature Phase 5 task references from Celery config (keep only implemented tasks)
2. Diagnosing and fixing iOS-backend connectivity issues (CORS, URL config, network)
3. Fixing GRDB model encoding issues in Route model
4. Updating UI labels to reflect Phase 2 completion
5. Ensuring all Phase 0-2 acceptance criteria pass

## Steps to Reproduce
1. **Celery Error**: Start Celery beat scheduler → observe "unregistered task" errors in logs for `alert_matcher.match_delays_to_favorites`
2. **iOS Backend**: Launch iOS app in Xcode → HomeView shows "Backend unreachable"
3. **GRDB Error**: Navigate to "All Routes" → app shows "Failed to load routes: GRDB row encoding error 1"
4. **Phase Labels**: HomeView displays "Phase 0: Foundation" instead of "Phase 2: Real-Time Foundation"

## Root Cause Analysis
1. **Celery Task Registration**: `backend/app/tasks/celery_app.py` lines 33, 108-125 reference `app.tasks.alert_matcher.match_delays_to_favorites` but `backend/app/tasks/alert_matcher.py` doesn't exist. This is a Phase 5 task that shouldn't be scheduled yet.

2. **iOS Backend Connectivity**: Likely causes:
   - Backend not running on expected URL/port
   - CORS configuration not allowing iOS simulator origin
   - iOS `Config.plist` has incorrect `API_BASE_URL`
   - Network configuration issue in iOS simulator

3. **GRDB Encoding Error**: `Route.swift` model CodingKeys don't match GRDB column names exactly, or `FetchableRecord` conformance has issues. The error "row encoding error 1" suggests column name mismatch.

4. **Phase Labels**: Hardcoded UI strings in `HomeView.swift` line 16 and other views not updated after Phase 1/2 completion.

## Relevant Files
Use these files to fix the bug:

- `backend/app/tasks/celery_app.py` - Remove Phase 5 task references (lines 33, 108-125)
- `backend/app/tasks/__init__.py` - Ensure only implemented tasks are imported
- `backend/app/main.py` - Check CORS configuration for iOS simulator
- `SydneyTransit/SydneyTransit/Features/Home/HomeView.swift` - Update phase label to "Phase 2: Real-Time Foundation"
- `SydneyTransit/SydneyTransit/Data/Models/Route.swift` - Fix GRDB encoding issues
- `SydneyTransit/SydneyTransit/Core/Utilities/Constants.swift` - Verify API_BASE_URL configuration
- `SydneyTransit/Config.plist` (or Config-Example.plist) - Check API endpoint URL
- `backend/app/api/v1/stops.py` - Verify endpoints return correct data
- `backend/app/api/v1/routes.py` - Check routes endpoint implementation

## Step by Step Tasks
IMPORTANT: Execute every step in order, top to bottom.

### 1. Fix Celery Configuration - Remove Unimplemented Tasks
- Remove `alert_matcher` task routing from `celery_app.py` line 33
- Remove `alert-matcher-peak` and `alert-matcher-offpeak` beat schedules from lines 108-125
- Remove `app.tasks.alert_matcher.match_delays_to_favorites` from task routes
- Keep only implemented tasks: `gtfs_rt_poller.poll_gtfs_rt` and `gtfs_static_sync.sync_gtfs_static`
- Update `include` list in celery config to only reference implemented task modules
- Restart Celery workers and beat to verify no "unregistered task" errors

### 2. Verify Backend API is Running and Accessible
- Check if backend is running: `curl http://localhost:8000/health`
- If not running, start backend: `cd backend && source venv/bin/activate && uvicorn app.main:app --reload`
- Verify health endpoint returns 200 with `{"status": "healthy"}`
- Test root endpoint: `curl http://localhost:8000/` should return `{"data": {"message": "Sydney Transit API"}}`
- Test stops endpoint: `curl http://localhost:8000/api/v1/stops/200060`

### 3. Fix iOS Backend Connectivity
- Read `SydneyTransit/Config.plist` or `Config-Example.plist` to verify `API_BASE_URL`
- Ensure `API_BASE_URL` is `http://localhost:8000/api/v1` (not missing /api/v1 suffix)
- Update `backend/app/main.py` CORS middleware to explicitly allow iOS simulator origins:
  - Add `http://localhost:*` pattern (already exists)
  - Ensure `allow_credentials=True`, `allow_methods=["*"]`, `allow_headers=["*"]`
- Verify iOS simulator network settings (Network Link Conditioner not blocking)
- Test connectivity from iOS: HomeView should fetch backend status successfully

### 4. Fix GRDB Route Model Encoding Issues
- Review `Route.swift` `CodingKeys` enum - ensure exact match with database column names
- Check that all columns in `routes` table are mapped: `rid`, `route_short_name`, `route_long_name`, `route_type`, `route_color`, `route_text_color`
- Verify `FetchableRecord` conformance - may need explicit `init(row:)` implementation
- Test query: `try Route.fetchAll(db, sql: "SELECT * FROM routes LIMIT 1")` in iOS debug console
- If encoding issue persists, implement custom `init(row: Row)` decoder instead of relying on `Codable`

### 5. Update UI Phase Labels
- Update `HomeView.swift` line 16: Change "Phase 0: Foundation" to "Phase 2: Real-Time Foundation"
- Review all UI files for hardcoded phase references
- Ensure DeparturesView is only accessible from implemented stop details flow
- Remove any premature Phase 3+ UI references (auth, favorites)

### 6. Verify Search Functionality
- Check `SearchView.swift` implementation
- Ensure search queries GRDB database correctly
- Test stop search with various queries (stop name, stop code)
- Verify results display correctly

### 7. End-to-End Testing
- Start all services: Backend API, Celery worker (critical queue), Celery beat
- Launch iOS app in Xcode simulator
- **HomeView**: Should show "Sydney Transit" with "Phase 2: Real-Time Foundation" and "Backend Status: Sydney Transit API" (green)
- **Search**: Tap "Search Stops" → enter stop name → results should display
- **Routes**: Tap "All Routes" → should display grouped route list (no GRDB error)
- **Departures**: Search for stop → tap stop → should navigate to stop details → check if departures work (if implemented)
- Monitor Celery logs: Should only see `poll_gtfs_rt` tasks, no "unregistered task" errors

### 8. Run Validation Commands
Execute all validation commands from the "Validation Commands" section below to ensure zero regressions.

## Validation Commands
Execute every command to validate the bug is fixed with zero regressions.

### Backend Validation
```bash
# Start backend if not running
cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && uvicorn app.main:app --reload &

# Wait for startup
sleep 3

# Test health endpoint
curl -s http://localhost:8000/health | jq '.'

# Test root endpoint
curl -s http://localhost:8000/ | jq '.'

# Test stops endpoint (example stop ID)
curl -s http://localhost:8000/api/v1/stops/200060 | jq '.'

# Test routes endpoint
curl -s http://localhost:8000/api/v1/routes | jq '.data | length'
```

### Celery Validation
```bash
# Start Celery worker (critical queue only) - check for errors
cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && celery -A app.tasks.celery_app worker -Q critical -c 1 --loglevel=info &

# Wait for worker startup
sleep 5

# Start Celery beat - check for "unregistered task" errors (should be NONE)
cd /Users/varunprasad/code/prjs/prj_transport/backend && source venv/bin/activate && celery -A app.tasks.celery_app beat --loglevel=info &

# Monitor logs for 60 seconds - should only see poll_gtfs_rt tasks
# NO "alert_matcher" errors should appear
sleep 60

# Kill background processes
pkill -f celery
pkill -f uvicorn
```

### Redis Validation
```bash
# Check Redis cache keys (should have vp:* and tu:* keys if poller ran)
redis-cli -u $REDIS_URL KEYS 'vp:*'
redis-cli -u $REDIS_URL KEYS 'tu:*'
```

### iOS Validation
- Build and run iOS app in Xcode (Cmd+R)
- Verify HomeView displays:
  - Title: "Sydney Transit"
  - Subtitle: "Phase 2: Real-Time Foundation" (NOT "Phase 0")
  - Backend Status: Green "Sydney Transit API" (NOT red "Backend unreachable")
- Tap "Search Stops" → enter "Circular" → results should display
- Tap "All Routes" → should display route list grouped by type (NO "GRDB row encoding error")
- Check Xcode console logs - should show successful network requests, no GRDB errors

### Database Validation
```bash
# Verify GRDB database exists and has routes
cd /Users/varunprasad/code/prjs/prj_transport/SydneyTransit
sqlite3 Resources/gtfs.db "SELECT COUNT(*) FROM routes;"

# Check route table schema matches Swift model
sqlite3 Resources/gtfs.db ".schema routes"
```

## Notes
- **Scope**: This bug fix focuses on stabilizing Phase 0-2 implementation. Do NOT implement Phase 3+ features (auth, favorites, etc.)
- **Celery Tasks**: Only `gtfs_rt_poller.poll_gtfs_rt` and `gtfs_static_sync.sync_gtfs_static` should be scheduled. Alert matcher is Phase 5.
- **CORS**: iOS simulator uses `http://localhost` origin, ensure backend allows it
- **GRDB**: If CodingKeys approach fails, implement manual `init(row: Row)` decoder for more control
- **Phase Labels**: Be conservative - only show features that are fully implemented and tested
- **Testing Priority**: Backend connectivity > GRDB errors > UI labels (fix in order of criticality)
