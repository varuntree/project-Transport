# Bug: Backend unreachable in iOS & Celery alert matcher unregistered (phase 2)

## Bug Description
- Celery workers receive beat messages for `app.tasks.alert_matcher.match_delays_to_favorites`, but the task is not registered, causing `KeyError` and discarded messages in logs; beat keeps rescheduling every 2–5 minutes during phase 2 runs.
- iOS Xcode preview shows "backend unreachable / could not connect to the server"; tapping "All routes" fails with "GRDB row encoding error 1" and stop search is unreliable; realtime departures surface even when earlier phases should be static-only.
- Home screen still labels the build as "phase 0/1" despite the codebase being at phase 2, confusing QA.

## Problem Statement
We need the phase-2 app to load data and realtime reliably: Celery must register and safely execute (or gracefully no-op) the alert matcher task, the iOS client must reach the FastAPI backend and decode local GTFS data without errors, and the UI should reflect the correct phase state so testers can evaluate the intended features.

## Solution Statement
Register and stub the missing Celery tasks (alert matcher, APNs worker) and include their modules in Celery startup so beat scheduling no longer produces unregistered task errors. Fix the iOS base URL configuration to avoid double `/api/v1` prefixes, add diagnostics, and align GRDB models/queries with the bundled `gtfs.db` schema to eliminate row encoding failures. Update the phase indicator copy so the UI matches the active phase. Validate via celery beat/worker runs, backend health endpoints, SQLite schema checks, and iOS preview/manual/E2E flows.

## Steps to Reproduce
1. Backend: `cd backend && source venv/bin/activate && celery -A app.tasks.celery_app worker -l info` in one terminal; start beat `celery -A app.tasks.celery_app beat -l info` in another → observe repeated `Received unregistered task of type 'app.tasks.alert_matcher.match_delays_to_favorites'` and discarded messages.
2. iOS: Open `SydneyTransit.xcodeproj`, run iPhone preview; home shows "backend unreachable" banner; navigating to All Routes triggers "GRDB row encoding error 1"; searching a stop fails or shows stale realtime badges.
3. Inspect generated request URL by setting a breakpoint in `APIClient.request` → URL becomes `http://localhost:8000/api/v1/api/v1/stops/<id>/departures` (double prefix) leading to 404/connection errors.

## Root Cause Analysis
- Celery configuration lists `app.tasks.alert_matcher.match_delays_to_favorites` and `app.tasks.apns_worker.send_push_notifications` in routes/beat schedule, but their modules do not exist and `Celery(..., include=["app.tasks.gtfs_rt_poller"])` prevents discovery, so tasks are unregistered and beat payloads are dropped.
- Config.plist sets `API_BASE_URL` to `http://localhost:8000/api/v1` while `APIEndpoint` already prepends `/api/v1/...`; concatenation yields a duplicate prefix and unreachable backend.
- GRDB "row encoding error 1" likely arises from schema/model mismatch or decoding NIL-for-nonoptional values when reading `routes`/`stops` from the bundled `Resources/gtfs.db`; current models assume non-null strings for short/long names and lat/lon without guarding against empty/NULL rows or selecting only required columns.
- UI phase label is hardcoded to older phase value (static copy) and not synced to the current phase flag/config.

## Relevant Files
Use these files to fix the bug:
- `backend/app/tasks/celery_app.py`: Defines Celery app, task routes, beat schedule, and include list; missing modules registration causes unregistered task errors.
- `backend/app/tasks/` (new `alert_matcher.py`, stub `apns_worker.py`): Implement or stub tasks referenced by beat/routes so Celery can register them.
- `backend/app/services/realtime_service.py` & `backend/app/api/v1/stops.py`: Realtime departures path used by iOS; ensure safe behavior when alerts tasks are stubbed.
- `SydneyTransit/SydneyTransit/Config.plist` & `Core/Utilities/Constants.swift`: Base URL configuration; fix duplication and allow environment override.
- `SydneyTransit/SydneyTransit/Core/Network/APIClient.swift`: Builds request paths; add URL logging/asserts after base URL fix.
- `SydneyTransit/SydneyTransit/Data/Models/Route.swift`, `Stop.swift`, and `Core/Database/DatabaseManager.swift`: GRDB decoding; adjust optionality/queries to match `Resources/gtfs.db` schema.
- `SydneyTransit/SydneyTransit/Features/Home/HomeView.swift` (or equivalent phase banner copy): Update phase label to phase 2.
- `SydneyTransit/SydneyTransit/Resources/gtfs.db`: Validate schema vs models to remove row encoding errors.
- `.claude/commands/test_e2e.md`, `.claude/commands/e2e/test_basic_query.md`: Read to craft new E2E test instructions for UI/backend connectivity.

### New Files
- `.claude/commands/e2e/test_celery-ios-connectivity.md`: E2E test script to verify Celery registration, backend reachability, routes list rendering, and departures loading without realtime until intended.
- `backend/app/tasks/alert_matcher.py`: Stub/implementation of match_delays_to_favorites task (even minimal no-op with logging) to register with Celery.
- `backend/app/tasks/apns_worker.py`: Stub send_push_notifications task to satisfy task_routes until feature implemented.

## Step by Step Tasks
### Analyze & Reproduce
- Read `README.md` (none present; note absence) and existing phase docs in `specs/phase-2-implementation-plan.md` for expected behaviors.
- Run Celery worker + beat to capture current unregistered task logs and save for comparison.
- Run backend FastAPI (`uvicorn app.main:app --reload`) and hit `/health` to confirm Redis/Supabase connectivity.
- Launch iOS preview/simulator; reproduce backend unreachable, All Routes load error, and stop search failure; capture request URLs via breakpoint/logging.
- Inspect `Resources/gtfs.db` schema with sqlite3 to identify nullable columns/extra fields that may break decoding.

### Register Celery Tasks
- Create `backend/app/tasks/alert_matcher.py` with `@app.task` (from celery_app) function `match_delays_to_favorites` that currently no-ops but logs invocation; ensure idempotent and safe when Supabase/Redis unavailable.
- Create `backend/app/tasks/apns_worker.py` stub `send_push_notifications` to satisfy task_routes; log and return immediately.
- Update `backend/app/tasks/__init__.py` and `celery_app.py include` to import new task modules so Celery discovers them; add unit smoke test or `celery inspect registered` validation.
- Adjust beat schedule if needed (e.g., guard with feature flag ENV) to prevent execution during development while keeping registration.

### Fix iOS Backend Connectivity
- Change `API_BASE_URL` in `Config.plist` (and example) to `http://localhost:8000` (no `/api/v1`).
- In `APIClient.request`, add debug log for built URL and assert no double `/api/v1` during debug builds.
- Optionally allow overriding baseURL via `UserDefaults`/scheme for simulator vs device to reduce future mismatch.

### Resolve GRDB Row Encoding Errors
- Compare `gtfs.db` schema to models; make any nullable text fields optional (e.g., `routeShortName`, `routeLongName`, stop coords) or provide decoding default.
- Narrow SQL selects to explicit columns present to avoid missing-column errors; add defensive decoding (e.g., `Route` init with defaults on NULL/empty name).
- Add a lightweight GRDB unit test (or runtime validation inside DatabaseManager) that loads first route/stop and surfaces detailed error logs instead of generic `row encoding error 1`.

### Update Phase Indicator & Realtime Flagging
- Locate home/phase badge copy and update to "Phase 2"; ensure realtime badges appear only when `departure.realtime == true` or backend indicates realtime=true.
- Add a configuration flag to hide realtime for phases 0/1 builds if needed; default to showing for phase 2.

### Add E2E Test Instruction File
- Read `.claude/commands/test_e2e.md` and `.claude/commands/e2e/test_basic_query.md` for format.
- Create `.claude/commands/e2e/test_celery-ios-connectivity.md` detailing steps: start backend + workers, verify no unregistered tasks, run app in simulator, confirm routes list renders without GRDB errors, and departures call hits backend with single `/api/v1` prefix. Include screenshot expectations.

### Validation
- Run `celery -A app.tasks.celery_app inspect registered` to ensure alert_matcher/apns_worker are registered.
- Start beat + worker for 5 minutes; confirm no `unregistered task` errors in logs.
- Hit `curl -i http://localhost:8000/api/v1/stops/200060/departures` to ensure backend responds (static fallback acceptable).
- Build iOS app in simulator; open All Routes and Stop details without GRDB errors; confirm network console shows correct URL.
- Execute validation commands below.

## Validation Commands
- `cd backend && source venv/bin/activate && celery -A app.tasks.celery_app inspect registered`
- `cd backend && source venv/bin/activate && pytest`  # backend unit tests
- `cd SydneyTransit && xcodebuild -scheme SydneyTransit -destination 'platform=iOS Simulator,name=iPhone 15' clean build`  # iOS build check
- Read `.claude/commands/test_e2e.md`, then read and execute `.claude/commands/e2e/test_celery-ios-connectivity.md` once created to validate end-to-end behavior.
- `cd app/server && uv run pytest`  # placeholder from instructions (ensure passes/skip if not applicable)
- `cd app/client && bun tsc --noEmit`  # placeholder from instructions (update/remove if client dir added)
- `cd app/client && bun run build`  # placeholder from instructions (update/remove if client dir added)

## Notes
- README.md is absent at repo root; noted during research. Base URL misconfiguration is the primary cause of "backend unreachable"; Celery include list missing alert/apns tasks triggers unregistered errors. GRDB decoding needs alignment with bundled gtfs.db schema; plan assumes environment is macOS/iOS simulator with backend running locally.
