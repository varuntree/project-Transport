# Bug: Missing multi‑mode stops, departures failing, GTFS‑RT poller segfaults

## Bug Description
Search results surface mostly train stops while bus, ferry, light rail, and metro stops are missing or sparse. Selecting a stop and tapping "View dispatches/departures" often returns "Failed to load dispatches/departures". Backend Celery workers repeatedly crash with SIGSEGV while running the GTFS‑RT poller, and real‑time data in Redis is empty, leaving only static results. A Supabase browser attempt shows "failed to decode responses / data could not be read" suggesting malformed or partial data. Expected behavior: all modalities appear in search, departures load with real‑time data, and poller runs stably without crashing.

## Problem Statement
Restore complete multimodal coverage (trains, buses, ferries, light rail, metro, MFF) in search and departures, and stop the GTFS‑RT poller crashes so real‑time data and platform info populate correctly. Ensure Supabase/SQLite data integrity and consistent IDs so departures return for any stop without errors.

## Solution Statement
Re‑validate and reload the GTFS static dataset for all modes, repair Supabase ↔ iOS ID alignment, and harden the GTFS‑RT poller against protobuf crashes (upgrade bindings, guard parsing per mode). Update search and departures code paths to use the corrected data, verify mode mappings, and add regression tests (API + E2E) that assert multimodal search results and working departures for non‑train stops.

## Steps to Reproduce
1. Start backend (FastAPI) and Celery worker/beat from `backend/` using existing scripts.
2. Call `GET /api/v1/stops/search?q=bus` (or `curl` the Supabase REST equivalent). Observe results are predominantly train stops and lack buses/ferries/light rail.
3. Call `GET /api/v1/stops/{bus_stop_id}/departures` (e.g., 202958). Response shows only static departures; real‑time count is zero and sometimes 500 errors.
4. Run Celery worker `celery -A app.tasks.celery_app worker -Q critical --loglevel=info`; within seconds the `poll_gtfs_rt` task dies with `WorkerLostError ... signal 11 (SIGSEGV)` and the task repeats.
5. Try opening the Supabase table browser; observe "failed to decode responses/data not in current format" errors, implying corrupted or incomplete records.

## Root Cause Analysis
- GTFS‑RT poller likely segfaults inside `gtfs_realtime_pb2` parsing (Python 3.13 + gtfs-realtime-bindings 1.0.0/protobuf C extensions) causing worker crashes and empty RT Redis blobs, which makes departures static‑only and sets modes to `["buses"]`.
- Static GTFS load may have dropped non‑train modes or failed midway, leaving partial stops/routes (search skewed to trains). MODE_DIRS includes `mff` and `sydneyferries`, but poller MODES_CONFIG omits `mff`, causing mismatched coverage between static and RT.
- Possible schema/data corruption in Supabase (decode errors) from partial upserts or inconsistent columns during last load.
- Departures and search both depend on stop_id strings; any mismatch between iOS `sid` and Supabase `stop_id` or missing pattern_stops rows results in empty queries for many non‑train stops.

## Relevant Files
Use these files to fix the bug:

- `backend/app/api/v1/stops.py`: Implements stop search and departures; adjust queries, ID handling, and error logging for multimodal coverage.
- `backend/app/services/realtime_service.py`: Merges static schedules with RT blobs; mode heuristic, Redis key usage, and logging of modes/RT counts.
- `backend/app/tasks/gtfs_rt_poller.py`: Poller that is segfaulting; protobuf parsing, mode list, Redis blob keys, and error handling need hardening.
- `backend/app/tasks/gtfs_static_sync.py`: Orchestrates GTFS static load; verify counts, reload all modes, and validate against Supabase.
- `backend/app/services/gtfs_service.py`: Parser that controls mode inclusion (MODE_DIRS) and Sydney filters; ensure all modes survive filtering.
- `backend/app/services/nsw_gtfs_downloader.py`: Defines GTFS endpoints per mode; confirm endpoints and inclusion of ferries/MFF.
- `backend/app/db/supabase_client.py`: Supabase client setup; ensures correct keys and retries for data reload.
- `backend/scripts/*.sh`: Start scripts for Celery/beat; use for repro and validation.
- `.claude/commands/test_e2e.md`, `.claude/commands/e2e/test_basic_query.md`: Read before adding the new E2E regression test.

### New Files
- `.claude/commands/e2e/test_missing_modalities_departures.md`: New E2E test script validating multimodal search results and departures loading for a bus/ferry/light‑rail stop.

## Step by Step Tasks
IMPORTANT: Execute every step in order, top to bottom.

### Baseline & Data Verification
- Note: `README.md` is absent in repo—log this and proceed via `CLAUDE.md` and code comments.
- Inspect Supabase datasets: query counts per `route_type`, `stops`, `pattern_stops`, `trips`, and verify sample non‑train stops exist (`exec_raw_sql` via Supabase REST or python client).
- Attempt Supabase table browsing to reproduce "failed to decode responses"; capture exact table(s)/columns causing decode errors.

### Reproduce API & Worker Failures
- Run FastAPI locally (`uvicorn app.main:app --reload`) and Celery worker/beat via `backend/scripts/start_worker_critical.sh` and `start_beat.sh`.
- Hit `/api/v1/stops/search?q=bus` and `/api/v1/stops/{bus_stop}/departures` plus a ferry/light‑rail stop; record result counts, modes, and errors.
- Run isolated `poll_gtfs_rt` task in a single-process worker to reproduce SIGSEGV; capture stack trace with `PYTHONFAULTHANDLER=1` and protobuf version info.

### Fix GTFS‑RT Poller Crash & Coverage
- Upgrade or pin `gtfs-realtime-bindings`/`protobuf` to a Python 3.13‑safe version; if needed, switch to pure‑Python parsing (`protobuf==5.28.x`) and regenerate bindings.
- Add per‑mode try/except + validation around `ParseFromString` to prevent crashes; skip bad modes instead of killing worker, and log counts.
- Align MODES_CONFIG with static modes (add `mff` if required, confirm lightrail/ferries endpoints) and ensure Redis keys match `realtime_service` expectations.

### Fix Static GTFS Load & Data Integrity
- Re-run `load_gtfs_static` end‑to‑end; validate row counts vs parser output and thresholds; resolve any missing mode directories or bbox over‑filtering.
- If Supabase contains corrupted rows, clean/truncate affected tables (stops/routes/pattern_stops/trips) before reload to avoid decode errors.
- Add validation script to check stop count per `route_type` and sample stops per mode after load.

### API Corrections for Multimodal Departures/Search
- In `realtime_service`, ensure `determine_mode` covers all NSW patterns (including BMT, T, M, F, L, bus numerics) and matches Redis keys.
- In `stops.py`, harden search to return mixed modes (consider adding a mode filter parameter and ensuring trigram similarity isn’t biased by route links), and ensure departures use the correct stop_id type with graceful fallback if Supabase uses int/str mismatch.
- Add structured logs for mode list and realtime/static counts per request to confirm coverage after fixes.

### Testing & Regression Safety
- Add unit/integration tests for `determine_mode`, static load validation (counts per route_type), and departures endpoint for a bus and ferry stop.
- Read `.claude/commands/e2e/test_basic_query.md` and `.claude/commands/e2e/test_complex_query.md`, then create `.claude/commands/e2e/test_missing_modalities_departures.md` that searches for a bus/ferry stop and verifies departures render without errors and with realtime/static counts.
- Run full validation suite.

### Validation Execution
- Run the commands in **Validation Commands** to certify the fix and absence of regressions.

## Validation Commands
Execute every command to validate the bug is fixed with zero regressions.

- `cd backend && source venv/bin/activate && python -m app.tasks.gtfs_static_sync`  # reload static data and ensure all modes load
- `cd backend && source venv/bin/activate && celery -A app.tasks.celery_app worker -Q critical --concurrency=1 --loglevel=info --without-gossip --without-mingle --without-heartbeat`  # verify poller runs without SIGSEGV for at least one poll cycle
- `curl -s "http://localhost:8000/api/v1/stops/search?q=bus" | head`  # confirm bus stops appear in search
- `curl -s "http://localhost:8000/api/v1/stops/<bus_stop_id>/departures"`  # confirm departures return realtime/static data
- `curl -s "http://localhost:8000/api/v1/stops/<ferry_stop_id>/departures"`  # confirm ferry/light‑rail coverage
- `cd backend && source venv/bin/activate && pytest`  # backend unit/integration tests
- Read `.claude/commands/test_e2e.md`, then read and execute `.claude/commands/e2e/test_missing_modalities_departures.md` to validate UI flows

## Notes
- `issue_json` environment variable was not provided; using placeholder issue_number=145 and adw_id=phase2-1—update filename if different.
- No `README.md` found in repo; primary guidance taken from `CLAUDE.md` and code comments.
- If a new protobuf/gtfs binding is added, record the `uv add` command and version pin here during implementation.
