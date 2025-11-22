# Bug Investigation Report & Fix Plan
Date: 2025-11-22

## 1. Summary of Issues
The system suffers from data inconsistencies and UI glitches primarily driven by **state synchronization gaps** between the Backend pagination logic and the iOS "Sliding Window" refresh strategy. Additionally, "Server Errors" are likely masking a fallback to static offline data, creating the perception that "Real-time is broken."

## 2. Bug Analysis & Root Causes

### Bug A: "Real-time departures not showing" (Frontend Layer)
*   **Symptom:** User sees static times or "Now" without delay info, or complains data is "incorrect".
*   **Root Cause:** 
    1.  **Offline Fallback:** The `DeparturesRepository` falls back to local GRDB (static only) whenever the API fails (e.g., 500 Error). The UI doesn't clearly indicate "Offline Mode", so users think the live data is wrong.
    2.  **RT-Only Mode Gap:** If Supabase is missing static data for a stop (common if `load_gtfs.py` filtered it out or failed), the API *tries* to serve RT-Only data. However, if the iOS app's `Departure` model expects specific fields that RT-Only mode approximates (like `scheduled_time_secs`), decoding might fail silently or display confusing data.
*   **Evidence:** `DeparturesRepository.swift` catches all errors and logs "API request failed, using offline data".

### Bug B: "Duplicate Departures" & "Departure lists jumping" (iOS State Management)
*   **Symptom:** Departure list shows the same train twice or jitters during refresh.
*   **Root Cause:** **State Management Conflict.**
    *   `refreshDeparturesInPlace` fetches a *new* window starting from `NOW`.
    *   It completely replaces `departures` and resets `earliestTimeSecs` to the new window's start.
    *   **The Gap:** If the user had previously scrolled up (loaded past departures), that history is wiped. If they are still scrolled to the top, the "Top Sentinel" (`isLoadingPast`) triggers immediately because the new `earliestTimeSecs` (NOW) is > the visible rows.
    *   `loadPastDepartures` then fetches the "Past" page.
    *   **Collision:** If the API's pagination isn't perfectly exclusive (e.g., `limit` logic overlaps), or if `deduplication` uses an ID that isn't truly unique across the "Real-time/Static" boundary, duplicates appear.
*   **Specific Logic Flaw:** `DeparturesViewModel.swift` uses `loadedDepartureIds` for deduplication but `refreshDeparturesInPlace` *clears* this set to match the new page, forgetting the "Past" items it just wiped, allowing them to be re-fetched and potentially duplicated if the UI state (scroll position) isn't reset.

### Bug C: "Server Errors" (Backend/Database)
*   **Symptom:** API returns 500.
*   **Root Cause:** `departures.py` relies on `supabase.rpc("exec_raw_sql")`.
    *   If the generated SQL query contains syntax errors (e.g., `stop_id` with special characters not escaped), Postgres throws an error.
    *   If `pattern_stops` or `trips` tables are missing data (referential integrity issues from `load_gtfs.py`), joins might return unexpected results or timeouts.
    *   **Timeout:** The `expanded_limit = max(limit * 3, 30)` combined with complex joins on large tables (without partition pruning) might be timing out on Supabase free tier limits.

### Bug D: "Static Data Messed Up" (Data Ingestion)
*   **Symptom:** Routes/Stops missing or wrong times.
*   **Root Cause:** `gtfs_service.py` uses a "Smart Deduplication" that might be overly aggressive or incorrect for "Parent Stations".
    *   The `load_gtfs.py` script (implied) might not be clearing old data before inserting, leading to primary key conflicts or "ghost" data if the `stop_id` logic changed between runs.

## 3. Implementation Plan

### Phase 1: Backend Stability (The "Server Error" Fix)
1.  **Sanitize SQL Inputs:** Modify `backend/app/api/v1/departures.py` to use parameterized queries (via `exec_raw_sql` params) instead of f-string injection `f"'{stop_id}'"`.
2.  **Optimize Query:** Add `EXPLAIN ANALYZE` logging to identify slow joins. Ensure `pattern_stops` has a composite index on `(stop_id, arrival_time_secs)` if not already present.
3.  **Graceful Error Handling:** Wrap the `rpc` call in a specific try/except to return a 404 or empty list instead of 500, allowing the "RT-Only" fallback to trigger reliably.

### Phase 2: iOS State Fixes (The "Duplicate" Fix)
1.  **Smart Refresh:** Update `DeparturesViewModel.swift`:
    *   Instead of replacing `departures` entirely in `refreshDeparturesInPlace`:
    *   **Merge Strategy:** Fetch the new "NOW" page.
    *   Diff the new list against the existing `departures`.
    *   Update existing items (to show new delays).
    *   Append new items.
    *   *Do not* wipe the "Past" items unless they are significantly old (> 1 hour).
2.  **Stable IDs:** Ensure `Departure.id` is robust. Combine `trip_id` + `scheduled_time` + `date`.

### Phase 3: Data Integrity (The "Static Data" Fix)
1.  **Validation Script:** Create a script `scripts/validate_patterns.py` to check for orphaned trips or stops without patterns.
2.  **Re-run Ingestion:** Clean slate re-ingestion of GTFS data with strict logging to ensure "Smart Deduplication" isn't dropping valid stops.

### Phase 4: UI "Real-time" Indicator
1.  **Offline Badge:** Add a visual indicator in `DeparturesView` when `viewModel.errorMessage` indicates "Using offline data" or when `repository` falls back.
2.  **Real-time Pulse:** Add a small "Live" dot next to the time if `realtime=true`.

## 4. Detailed Todo List
1.  [Backend] Refactor `departures.py` to use parameterized SQL.
2.  [Backend] Test `exec_raw_sql` with complex stop IDs.
3.  [iOS] Refactor `DeparturesViewModel` refresh logic (Merge vs Replace).
4.  [iOS] Add "Offline Mode" UI state.
5.  [Data] Validate `patterns` table for consistency.
