# Bug: Missing modalities and departures failing after Phase 2.1

## Bug Description
Searching for stops now only surfaces train stations; bus, ferry, light rail and other modes are absent. Selecting a stop and tapping “View Dispatches/Departures” returns a “Failed to load dispatches” error and shows empty data. Recent logs show repeated `no_static_departures` for stop IDs (e.g., 29443/29444) and zero `realtime_count/static_count`, indicating the backend is returning empty departures. Data volume in the app appears greatly reduced compared with earlier phases.

## Problem Statement
Stop discovery and departures are broken for non-train modes and returning empty results even for trains. We need to restore complete multi-modal stop coverage and make the departures endpoint succeed for any stop the client requests.

## Solution Statement
Reconcile stop identifiers between the iOS client (sid) and backend (GTFS stop_id), confirm GTFS ingestion still writes all modalities, and adjust backend queries (search + departures) plus client-side ID mapping so that any stop can be searched and its departures fetched. Add targeted logging and tests to prevent regressions.

## Steps to Reproduce
1. Run backend locally and ensure DB is populated.
2. Call `/api/v1/stops/search?q=bus` (or ferry/light rail terms) → results show only train stations.
3. In the app (or via curl) open a stop such as 29444 and hit `/api/v1/stops/29444/departures` → 200 OK with empty departures; UI shows “Failed to load dispatches.”
4. Observe backend logs emitting `no_static_departures` and total_count 0.

## Root Cause Analysis
- Likely stop ID mismatch: client may send integer `sid` while backend expects text `stop_id`, so pattern_stops lookup returns zero rows, producing empty departures.
- Possible data loss or filter in GTFS ingestion causing only train routes/stops to land in Postgres/SQLite, especially if route_type filtering/regression was introduced.
- Search endpoint may be reading from a reduced dataset or the client could be filtering results by `route_type` due to primaryRouteType/icon logic failing for non-train stops.
- Missing or unused `dict_stop` mapping table (sid ↔ stop_id) breaks departures requests and modality inference on the client.

## Relevant Files
Use these files to fix the bug:

- `backend/app/api/v1/stops.py` – search and departures endpoints; verify queries, edge-case handling, and logging.
- `backend/app/services/realtime_service.py` – merges static + RT departures; ensure stop_id lookups work for all modalities and handle sid→stop_id mapping.
- `backend/app/db/supabase_client.py` – validate connectivity and SQL RPC usage for raw queries.
- `backend/scripts/*` – GTFS ingestion/build scripts; confirm all route types/stops are loaded and no modality filters were added.
- `SydneyTransit/SydneyTransit/Data/Models/Stop.swift` – ID fields and primaryRouteType logic; ensure icons and modality detection don’t filter out non-train stops.
- `SydneyTransit/SydneyTransit/Features/Search/SearchView.swift` – client-side filtering/sorting of search results.
- `SydneyTransit/SydneyTransit/Features/Departures/DeparturesView*.swift` – what ID is sent to the backend when requesting departures.
- `SydneyTransit/SydneyTransit/Core/Database/DatabaseManager.swift` – verify bundled SQLite schema and presence of dict_stop mapping.
- `README.md` (not found in repo) – note absence; rely on specs/CLAUDE.md for overview.
- `.claude/commands/test_e2e.md` and `.claude/commands/e2e/test_basic_query.md` – instructions for writing E2E tests.

### New Files
- `.claude/commands/e2e/test_missing_modalities_departures.md` – new E2E script to validate multi-modal search and departures.

## Step by Step Tasks
IMPORTANT: Execute every step in order, top to bottom.

### 1) Establish baseline and reproduce
- Start backend (uvicorn) with current DB; tail logs for `no_static_departures`.
- `curl` search for generic terms (`bus`, `ferry`, `light`) and specific stop IDs (e.g., 200060, 29444) to confirm missing modalities and empty departures.
- Capture current counts from `stops`, `routes` grouped by `route_type` in Supabase and bundled SQLite to confirm or refute data loss.

### 2) Inspect data pipeline and DB integrity
- Read GTFS ingestion scripts under `backend/scripts/` to ensure no modality filters/regressions were introduced in phase 2.1.
- Query Postgres (via Supabase RPC) for counts of routes/stops by type; compare with expected totals (~30k stops, ~4.6k routes across 7 types).
- Check bundled `gtfs.db` schema for `dict_stop` table and presence of bus/ferry/light rail stops; note mismatches.

### 3) Trace identifier flow (sid vs stop_id)
- In `DeparturesView` / `DeparturesViewModel`, identify which ID is sent in the API path; confirm whether sid is converted.
- Inspect `Stop.swift` and any repository layer for available mapping helpers; confirm whether `dict_stop` is queried.
- Add logging in client (temporary) if needed to print requested IDs.

### 4) Backend departures query hardening
- Update `realtime_service.get_realtime_departures` to validate stop_id, handle numeric sid by mapping via stops table or a dedicated mapping query, and guard against empty pattern_stops results.
- Add structured logging around stop_id input, lookup path (sid vs stop_id), and counts of static trips returned.
- Adjust `/stops/{stop_id}/departures` endpoint to surface clearer errors (STOP_NOT_FOUND vs NO_DEPARTURES) and to call normalized stop_id.

### 5) Restore multi-modal search coverage
- Verify `search_stops` SQL includes all modalities; ensure there is no unintended WHERE filter (route_type/location_type) and that trigram search works for bus/ferry names.
- If client filters by `primaryRouteType`, ensure `Stop.primaryRouteType` gracefully derives type (with fallback to `location_type` or stop code heuristics) so bus/ferry stops are not dropped.

### 6) Client ID mapping and departures request
- Implement or repair sid→stop_id lookup on the client using `dict_stop`; fall back to stop_code/parent_station heuristics if mapping absent.
- Ensure departures requests always use GTFS text stop_id expected by backend; add lightweight unit test or debug assertion.

### 7) Add automated coverage
- Backend: add unit/integration test for departures endpoint accepting an integer sid and returning departures for the mapped stop_id.
- Backend: add search test ensuring bus/ferry/light rail stops are returned for representative queries.
- UI: Read `.claude/commands/test_e2e.md` and `.claude/commands/e2e/test_basic_query.md`, then create `.claude/commands/e2e/test_missing_modalities_departures.md` to script simulator steps: search for bus/ferry/light rail stop, open departures, confirm results.

### 8) Data repair/backfill (if counts are low)
- If Supabase data is missing modalities, re-run ingestion with full feed; verify counts post-run.
- If bundled SQLite is stale, regenerate `gtfs.db` including `dict_stop` and all stops.

### 9) Validation
- Execute validation commands (below) to confirm search and departures work and no regressions.

## Validation Commands
Execute every command to validate the bug is fixed with zero regressions.

- Reproduce search & departures via API:
  - `cd backend && source venv/bin/activate && curl -s "http://localhost:8000/api/v1/stops/search?q=bus" | head`
  - `cd backend && source venv/bin/activate && curl -s "http://localhost:8000/api/v1/stops/29444/departures" | python -m json.tool | head -30`
- Backend tests: `cd backend && source venv/bin/activate && pytest`
- Frontend typecheck/build (client iOS not TS; skip tsc). For Swift build: `cd SydneyTransit && xcodebuild -scheme SydneyTransit -sdk iphonesimulator -quiet build`
- E2E: Read `.claude/commands/test_e2e.md`, then read and execute `.claude/commands/e2e/test_missing_modalities_departures.md` once created.
- Optional data check: `cd backend && source venv/bin/activate && python scripts/check_route_type_counts.py` (add script if missing) to ensure all modalities present.

## Notes
- `issue_json` environment variable was not present; issue number/adw id assumed as 144/phase2-1 for naming consistency—update if different.
- No root-level README found; relied on `CLAUDE.md` and specs for project context.
- Celery SIGSEGV in logs may be a separate Python 3.13/billiard fork issue; investigate after departures/search are fixed.
