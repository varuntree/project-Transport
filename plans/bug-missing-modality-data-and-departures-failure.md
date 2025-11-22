# Bug: Missing Data for Non-Train Modalities and Departure Display Issues

## Bug Description
The application has two critical data issues:

1. **Search results only show train stops**: When searching for stops, only train stations appear in results, while bus stops, ferries, and light rail stops are missing from the UI
2. **Departures fail to load**: When clicking "View Departures" on any stop, the app shows "Failed to load departures" error
3. **Incomplete modality coverage**: The iOS app shows primarily train-related stops despite having full data for all modalities (buses, ferries, light rail, metro) in both databases

**Expected behavior**:
- Search should return stops for all transport modes (trains, buses, ferries, light rail, metro)
- Departures view should load and display upcoming departures for selected stops
- All modalities should be represented in search results

**Actual behavior**:
- Search returns predominantly train stops
- Departures view fails with error
- Bus stops, ferry stops, and light rail stops are not visible in search results

## Problem Statement
The iOS app's local SQLite database contains all modality data (30,397 stops, 171,534 trips across 7 route types), but:

1. The `Stop` model's `primaryRouteType` computation only searches for routes serving a stop, which may fail or return incorrect results for stops not properly linked to routes in the pattern_stops table
2. The iOS database uses integer surrogate keys (`sid`, `rid`, `pid`) while the backend Supabase database uses text keys (`stop_id`, `route_id`, `pattern_id`), causing a disconnect in the departures API
3. The `realtime_service.py` queries use text `stop_id` which doesn't match the iOS integer `sid` values, causing "no_static_departures" responses

## Solution Statement
Fix the data pipeline and API integration to ensure:

1. **iOS database structure alignment**: The iOS database already has all data but needs proper linking between stops and routes through pattern_stops
2. **Departures API fix**: Update the departures endpoint to handle both text `stop_id` (from Supabase) and accept lookups that can map iOS `sid` to Supabase `stop_id`
3. **iOS app stop lookup**: Add a `dict_stop` table or mapping to translate between `sid` (iOS) and `stop_id` (Supabase) for API calls
4. **Search result diversity**: Ensure search results include stops from all modalities, not just those with route connections

## Steps to Reproduce
1. Open the Sydney Transit iOS app
2. Navigate to Search view
3. Search for any stop name (e.g., "Central", "Circular Quay", "Bus")
4. Observe: Results show mostly/only train stations
5. Select any stop from search results
6. Click "View Departures"
7. Observe: "Failed to load departures" error appears

## Root Cause Analysis

### Database Investigation Results

**Supabase (Backend):**
- Routes by type: Type 2 (87 rail), Type 4 (11 ferry), Type 401 (1), Type 700 (679 bus), Type 712 (3866 bus), Type 714 (23 bus), Type 900 (1)
- Total: 30,397 stops, 4,668 routes, 171,534 trips, 12,005 patterns
- Uses text primary keys: `stop_id`, `route_id`, `pattern_id`

**iOS SQLite:**
- Routes by type: IDENTICAL to Supabase (same 7 types, same counts)
- Total: 30,397 stops, 171,534 trips, 12,005 patterns
- Uses integer surrogate keys: `sid`, `rid`, `pid`
- Has `dict_stop` table mentioned in code but not verified to exist

### Code Analysis

**iOS Stop Model Issue (`Stop.swift:65-85`):**
- `primaryRouteType` computed property queries pattern_stops → patterns → routes
- This query may fail for stops not in pattern_stops or return nil
- No fallback mechanism, causing stops without route links to show generic icon

**Backend Departures Issue (`realtime_service.py:153`):**
- Query uses `WHERE ps.stop_id = '{stop_id}'` expecting text stop_id
- iOS passes `sid` (integer) via API, but backend expects stop_id (text)
- Results in "no_static_departures" as query finds no matches

**iOS-Backend Disconnect:**
- iOS `Stop.swift:53-61` has `fetchByStopID` method that joins with `dict_stop` table
- This suggests a mapping table exists, but:
  - Not confirmed in database
  - Not being used in departures API call flow
  - DeparturesView likely passes `sid` instead of `stop_id`

### Departure Flow Failure

1. User selects stop in iOS (has `sid` integer)
2. `DeparturesView` makes API call to `/api/v1/stops/{stop_id}/departures`
3. iOS likely passes `sid` or needs to map `sid` → `stop_id`
4. Backend queries `pattern_stops` with text stop_id
5. Query fails (0 results) because:
   - Either wrong ID type passed
   - Or ID mapping missing
   - Or pattern_stops not properly populated

## Relevant Files

### Backend Files
- `backend/app/api/v1/stops.py:176-260` - Departures endpoint that fails. Uses `stop_id` parameter directly in query without validation or type checking
- `backend/app/services/realtime_service.py:83-280` - Real-time departures service. Lines 153-158 query assumes text `stop_id`, no handling for iOS sid vs Supabase stop_id mismatch
- `backend/app/services/gtfs_service.py` - GTFS parser (working correctly), successfully loads all modalities

### iOS Files
- `SydneyTransit/SydneyTransit/Data/Models/Stop.swift:1-113` - Stop model. Lines 65-85 `primaryRouteType` computation may fail. Lines 88-98 returns generic icon when primaryRouteType is nil
- `SydneyTransit/SydneyTransit/Features/Search/SearchView.swift:1-135` - Search view (working). Results include all stops, issue is display/icon selection
- `SydneyTransit/SydneyTransit/Features/Stops/StopDetailsView.swift:1-131` - Stop details. Lines 89-103 navigation to DeparturesView passes Stop object with sid
- `SydneyTransit/SydneyTransit/Core/Database/DatabaseManager.swift` - Database access. Need to verify dict_stop table exists and is populated
- `SydneyTransit/SydneyTransit/Features/Departures/DeparturesView.swift` - Departures view that calls API
- `SydneyTransit/SydneyTransit/Features/Departures/DeparturesViewModel.swift` - Departures view model that makes API call

### New Files
- `SydneyTransit/SydneyTransit/Data/Repositories/StopRepository.swift` - New repository to handle stop ID mapping

## Step by Step Tasks

### 1. Verify iOS Database Schema and dict_stop Table
- Inspect iOS SQLite database schema
- Check if `dict_stop` table exists with columns: `sid INTEGER`, `stop_id TEXT`
- Verify table has mappings for all 30,397 stops
- If missing, identify where dict_stop should be created in iOS database build script

### 2. Fix iOS Database Build to Include dict_stop Mapping
- Locate iOS database build script (likely in `backend/scripts/` or similar)
- Add dict_stop table creation if missing
- Populate dict_stop with sid → stop_id mappings from Supabase stops table
- Regenerate iOS gtfs.db with dict_stop table

### 3. Fix DeparturesView/ViewModel to Use stop_id not sid
- Read `DeparturesView.swift` and `DeparturesViewModel.swift`
- Find where API call is made to `/api/v1/stops/{stop_id}/departures`
- Before making API call, query dict_stop table to get stop_id from sid
- Use text stop_id in API URL, not integer sid
- Add error logging to track what IDs are being used

### 4. Add Backend Logging and Validation
- Update `backend/app/api/v1/stops.py:176` departures endpoint
- Add logging to show received stop_id parameter value and type
- Add validation to ensure stop_id is non-empty string
- Return specific error codes: STOP_NOT_FOUND vs NO_DEPARTURES

### 5. Fix iOS Stop Model Icon Logic (Optional)
- Update `Stop.swift` primaryRouteType to handle nil gracefully
- Add fallback query if pattern_stops link missing
- Ensure all stops show appropriate transport icon
- This is lower priority than departures fix

### 6. Test All Modalities
- Test searching for bus stops (e.g., "George Street")
- Test searching for ferry stops (e.g., "Circular Quay")
- Test searching for light rail stops (e.g., "Central Chalmers Street")
- Test searching for train stops (e.g., "Central Station")
- Verify icons display correctly for each modality
- Verify departures load successfully for each modality

### 7. Run Validation Commands
Execute commands from "Validation Commands" section to ensure all bugs fixed with zero regressions

## Validation Commands
Execute every command to validate the bug is fixed with zero regressions.

**Database verification:**
```bash
# Verify iOS database has all modalities
cd /Users/varunprasad/code/prjs/prj_transport/backend
source venv/bin/activate
python -c "
import sqlite3
conn = sqlite3.connect('../SydneyTransit/SydneyTransit/Resources/gtfs.db')
cursor = conn.cursor()

# Check route types
cursor.execute('SELECT DISTINCT route_type, COUNT(*) FROM routes GROUP BY route_type')
print('Route types:', cursor.fetchall())

# Check if dict_stop exists
cursor.execute(\"SELECT name FROM sqlite_master WHERE type='table' AND name='dict_stop'\")
result = cursor.fetchone()
print('dict_stop table exists:', result is not None)

# If exists, check mapping
if result:
    cursor.execute('SELECT COUNT(*) FROM dict_stop')
    print('dict_stop rows:', cursor.fetchone()[0])

    # Sample mapping
    cursor.execute('SELECT sid, stop_id FROM dict_stop LIMIT 5')
    print('Sample mappings:', cursor.fetchall())

conn.close()
"
```

**Backend API test:**
```bash
# Start backend if not running
cd /Users/varunprasad/code/prjs/prj_transport/backend
source venv/bin/activate
# In separate terminal: uvicorn app.main:app --reload

# Test departures endpoint with known text stop_id from Supabase
curl -s "http://localhost:8000/api/v1/stops/200060/departures" | python -m json.tool | head -30
# Should return departures data array, not empty

# Test stop details to verify stop exists
curl -s "http://localhost:8000/api/v1/stops/200060" | python -m json.tool

# Test with non-existent stop
curl -s "http://localhost:8000/api/v1/stops/999999/departures" | python -m json.tool
# Should return 404 error with clear message
```

**iOS app manual testing:**
1. Launch iOS app in simulator
2. Search for "Circular Quay" - should show ferry stop with ferry icon 🛳️
3. Search for "George Street" - should show multiple bus stops with bus icons 🚌
4. Search for "Central Chalmers" - should show light rail stop with tram icon 🚋
5. Search for "Central Station" - should show train station with train icon 🚂
6. Click on each stop → "View Departures" → should load departures successfully
7. Verify departure times display, routes show, no errors
8. Verify icons match transport modality for each stop type

**iOS build verification:**
```bash
cd /Users/varunprasad/code/prjs/prj_transport/SydneyTransit
xcodebuild -scheme SydneyTransit -sdk iphonesimulator clean build 2>&1 | grep "BUILD SUCCEEDED"
# Should show BUILD SUCCEEDED
```

## Notes

### Route Type Codes (GTFS Extended)
- Type 0: Tram/Light Rail
- Type 1: Subway/Metro
- Type 2: Rail (heavy rail, commuter rail)
- Type 3: Bus (standard GTFS)
- Type 4: Ferry
- Type 401: Unknown (NSW custom)
- Type 700-714: Bus variants (NSW extended codes for different bus services)
- Type 900: Unknown (NSW custom)

### Current Data Distribution
Database contains excellent coverage:
- 87 rail routes
- 4,579 bus routes (700, 712, 714 combined)
- 11 ferry routes
- All 30,397 stops present in both Supabase and iOS databases

**The issue is NOT missing data** - data exists in full. The issue is:
1. iOS icon logic failing to identify non-rail modalities
2. API integration using wrong ID type (sid vs stop_id)
3. Missing or unutilized dict_stop mapping table

### Priority Fix
The most critical fix is #3 (Departures API Call Flow) as this completely breaks the departures feature. The icon display issue (#2, #5) is secondary but affects user experience.

### Celery SIGSEGV Error (Separate Issue)
The logs show `Worker exited prematurely: signal 11 (SIGSEGV)` in the Celery worker. This is likely related to:
- Python 3.13 compatibility issue with billiard/celery
- fork() safety on macOS
- Should be addressed separately from this data bug

Workaround: Use `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` environment variable or downgrade to Python 3.11.

### Key Insight
Both databases have identical, complete data. The bug is purely in the interface layer:
- iOS uses integer surrogate keys for performance/space efficiency
- Backend uses original GTFS text keys for API compatibility
- The dict_stop mapping table is the bridge - must exist and be used correctly