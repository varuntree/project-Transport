# Bug: Missing Light Rail Coverage and Corrupted Light Rail Search Results

## Bug Description
When selecting **Light Rail** and searching for “Central”, the iOS app shows train platforms (e.g., Central Station Platform 20) and only one light rail stop, while the official Transport NSW app shows multiple L1/L2/L3 departures. The bundled iOS `gtfs.db` contains only one light rail route (type 900) and its pattern includes many train platforms, so light rail results are incomplete and polluted.

## Problem Statement
The data pipeline must ingest and surface all Sydney light rail routes (L1–L3 at minimum) and ensure the Light Rail filter returns only light rail stops. We need to locate where light rail data is dropped or corrupted in the GTFS download/parse/load/generation chain and prevent future data loss.

## Solution Statement
Extend the GTFS pipeline to ingest full light rail schedules, clean stale GTFS rows before loading, and harden validations so missing or corrupted light rail data fails the build. Regenerate Supabase tables and the iOS SQLite bundle, and adjust the Light Rail filter to cover all relevant route types.

## Steps to Reproduce
1. In the iOS app, select the **Light Rail** filter and search “Central” → train platforms appear and L2/L3 stops are missing.
2. Inspect bundled DB: `sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "select route_type, count(*) from routes group by route_type;"` → only one `route_type=900` route, none with `route_type=0`.
3. Check pattern contamination: `sqlite3 ... "select stop_name from pattern_stops ps join patterns p on ps.pid=p.pid join routes r on p.rid=r.rid join stops s on ps.sid=s.sid where r.route_type=900 and stop_name like '%Platform%' limit 5;"` → train platforms returned.
4. Compare GTFS feeds: `wc -l backend/var/data/gtfs-downloads/lightrail/routes.txt` shows one route (L1), while `python - <<'PY' ...` over `backend/var/data/gtfs-downloads/complete` shows 6 light rail routes and ~6750 trips for `route_type=900`.

## Root Cause Analysis
- The NSW `lightrail` GTFS endpoint currently returns only L1; the pipeline builds patterns/trips exclusively from “realtime-aligned” mode feeds, so L2/L3 schedules (present in the “complete” coverage feed) are never parsed into patterns/trips.
- Supabase loads use batch **upsert** without truncating tables, so stale pattern/trip rows persist when feeds shrink; the current pattern for `route_type=900` contains 101 stops including train platforms, polluting Light Rail search results.
- Validation in `_validate_load` only checks that *some* `route_type` 0/900 route exists; it does not assert minimum route/trip/stop counts for light rail, so the data loss escaped detection. The iOS DB generator pulls whatever is in Supabase, propagating the bad dataset to the app.
- The Light Rail filter in `SearchView` only includes `route_type=900`; if the GTFS feed ever reports light rail as the GTFS-standard `route_type=0`, those stops would be filtered out.

## Relevant Files
Use these files to fix the bug:

- `backend/app/services/nsw_gtfs_downloader.py` — defines which GTFS feeds are downloaded; needs a light-rail-complete source/fallback.
- `backend/app/services/gtfs_service.py` — merges feeds and extracts patterns; must merge light rail trips/stop_times from the complete feed (route_type 0/900) into the pattern model.
- `backend/app/tasks/gtfs_static_sync.py` — orchestrates load/validation; add table cleanup before upsert and strengthen light rail coverage validations.
- `backend/app/services/ios_db_generator.py` — builds the bundled SQLite; ensure it runs after the cleaned Supabase load and optionally asserts light rail counts.
- `backend/scripts/load_gtfs.py` — entry point to run the end-to-end static load.
- `SydneyTransit/SydneyTransit/Features/Search/SearchView.swift` — Light Rail filter currently only includes `route_type=900`; needs to include the GTFS-standard `route_type=0` as well.

## Step by Step Tasks
IMPORTANT: Execute every step in order, top to bottom.

### 1. Baseline and Reproduce
- Run the reproduction SQL queries to capture current light rail route counts and the presence of train platforms under `route_type=900`.
- Capture app-side repro (Light Rail filter on “Central”) to confirm UI symptoms match the data issues.

### 2. Inspect GTFS Inputs
- Verify `backend/var/data/gtfs-downloads/lightrail/routes.txt` has only one route and no L2/L3 trips.
- Verify `backend/var/data/gtfs-downloads/complete` contains 6 light rail routes and ~6750 trips with `route_type=900`, confirming the data exists upstream.

### 3. Fix GTFS Ingestion for Light Rail
- Update downloader/parse pipeline to ingest light rail trips/stop_times from the complete feed (filter `route_type` 0/900) and prefix trip_ids to avoid collisions.
- Merge the filtered light rail trips/stop_times/calendar into the pattern extraction path so L2/L3 patterns/trips are generated.
- Ensure stop deduplication preserves light rail child stops when merging additional feed data.

### 4. Prevent Stale/Corrupted Rows on Load
- Add a pre-load truncate or targeted delete of routes/patterns/trips/pattern_stops (at least for `route_type` in {0,900}) before batch upserts to avoid stale rows.
- Keep load ordering and foreign-key integrity intact after the cleanup.

### 5. Harden Validation for Light Rail Coverage
- In `_validate_load`, assert minimum light rail counts (e.g., routes ≥3, trips ≥6000, distinct stops ≈120) and fail if below thresholds.
- Add a guard that pattern_stops for `route_type=900` do not include obvious train-only platforms (e.g., stop_name LIKE '%Platform%') beyond a tiny tolerance, emitting actionable logs.
- Log feed-versus-DB deltas for light rail so future regressions are caught in CI.

### 6. Regenerate and Wire the Data
- Run the fixed GTFS pipeline to reload Supabase with the full light rail dataset.
- Regenerate `gtfs.db` via `ios_db_generator`, replace the bundled SQLite, and update `SearchView` to include `route_type` 0 in the Light Rail filter.

### 7. Run Validation Commands
- Execute all commands in the Validation Commands section and record outputs to confirm light rail coverage and absence of cross-mode contamination.

## Validation Commands
Execute every command to validate the bug is fixed with zero regressions.
- `sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "select route_type, count(*) from routes group by route_type;"` — confirm light rail shows ≥3 routes (0/900).
- `sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "select count(distinct ps.sid) from pattern_stops ps join patterns p on ps.pid=p.pid join routes r on p.rid=r.rid where r.route_type in (0,900);"` — confirm light rail stop coverage (~120) restored.
- `sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "select count(*) from pattern_stops ps join patterns p on ps.pid=p.pid join routes r on p.rid=r.rid join stops s on ps.sid=s.sid where r.route_type=900 and stop_name like '%Platform%';"` — expect 0 after cleanup (no train platforms under light rail).
- `cd backend && python scripts/load_gtfs.py` — rerun GTFS download/parse/load with fixes.
- `cd backend && python -m pytest` — backend regression suite.

## Notes
- Light rail data exists in the “complete” GTFS feed (6 routes, ~6750 trips, ~126 stops); the current “lightrail” feed is incomplete and should be treated as supplemental at best.
- Strengthened validation must fail the pipeline if light rail counts regress to catch future NSW feed changes. 
