# GTFS Coverage and Validation Specification

**Purpose:**  
Define how NSW static GTFS feeds are used for both the pattern model and stop/route coverage, and specify validation rules that prevent regressions such as missing ferry wharves (e.g. Davistown Central RSL Wharf).

---

## 1. Background

Earlier versions of the GTFS pipeline ingested only a subset of NSW per‑mode, realtime‑aligned static feeds:

- `sydneytrains`, `metro`, `buses`, `sydneyferries`, `mff`, `lightrail`

This was sufficient for GTFS‑RT alignment, but **insufficient for full stop coverage**. Stops that existed only in other static feeds (e.g. broader ferries or the complete NSW bundle) could be silently omitted. One example is **Davistown Central RSL Wharf**, which appears in other vendor apps but was completely absent from our `stops` table and iOS bundle.

To prevent this class of bug, the pipeline has been extended to:

1. Download additional static feeds aimed at **coverage**.  
2. Merge these into agencies/stops/routes (without disturbing the pattern model).  
3. Add **hard validation checks** for mode coverage and a **critical-stop whitelist**.  

---

## 2. Feed Roles: Pattern vs Coverage

Static feeds are divided into two roles:

### 2.1 Pattern Model Feeds (Realtime‑Aligned)

Used for:
- `trips`
- `stop_times`
- pattern extraction
- GTFS‑RT alignment

Feeds:
- `/v1/gtfs/schedule/sydneytrains`  → key: `sydneytrains`
- `/v2/gtfs/schedule/metro`         → key: `metro`
- `/v1/gtfs/schedule/buses`         → key: `buses`
- `/v1/gtfs/schedule/ferries/sydneyferries` → key: `sydneyferries`
- `/v1/gtfs/schedule/ferries/MFF`   → key: `mff`
- `/v1/gtfs/schedule/lightrail`     → key: `lightrail`

These feeds are the only ones that contribute to:
- `trips`
- `stop_times`
- downstream `patterns` + `pattern_stops`

### 2.2 Coverage Feeds (Static‑Only)

Used to **augment agencies/stops/routes coverage** but not the pattern model:

Feeds:
- `/v1/publictransport/timetables/complete/gtfs`  → key: `complete`
- `/v1/gtfs/schedule/ferries`                     → key: `ferries_all`
- `/v1/gtfs/schedule/nswtrains`                   → key: `nswtrains`
- `/v1/gtfs/schedule/regionbuses`                 → key: `regionbuses`

These feeds are merged into:
- `agencies`
- `stops`
- `routes`

but **do not** currently provide `trips`/`stop_times` into the pattern model. They are primarily responsible for ensuring:

- All ferry wharves within the Sydney bbox are present as stops.  
- Regional and fringe stops are available for search and static display.  

For a concrete matrix, see:  
`backend/gtfs-coverage-matrix.md`

---

## 3. Pipeline Behaviour

### 3.1 Download

Component: `backend/app/services/nsw_gtfs_downloader.py`

- Downloads all feeds in `GTFS_ENDPOINTS`, which includes both pattern and coverage feeds.
- Writes each mode to `temp/gtfs-downloads/{mode}/gtfs.zip` and extracts CSV files.

### 3.2 Parse and Merge

Component: `backend/app/services/gtfs_service.py`

Key points:

1. **Realtime‑aligned feeds** (`MODE_DIRS`) are loaded with full GTFS data:
   - `agency.txt`, `stops.txt`, `routes.txt`, `trips.txt`, `stop_times.txt`, `calendar.txt`, `calendar_dates.txt` (optional).
   - IDs are prefixed by mode for `trip_id` and `stop_times.trip_id`.

2. **Coverage‑only feeds** (`COVERAGE_EXTRA_DIRS`) are loaded best-effort:
   - Only `agency.txt`, `stops.txt`, and `routes.txt` are read (if present).
   - Data is appended to the previously merged pattern-mode DataFrames:
     - `agencies`, `stops`, `routes`.
   - Any load error is logged but does **not** abort the parsing phase (to avoid failures due to optional feeds).

3. `_apply_sydney_filter`:
   - Operates on the combined `stops` DataFrame.
   - Converts lat/lon to floats and applies the Sydney bbox:
     - `lat ∈ [-34.5, -33.3]`, `lon ∈ [150.5, 151.5]`.
   - Deduplicates stops by `stop_id` (first occurrence wins).
   - Filters `stop_times`, `trips`, `routes`, `calendar`, `calendar_dates` based on the surviving Sydney stops/trips.

Result:
- Pattern model remains based solely on realtime‑aligned feeds.
- Stop/route coverage is widened with any additional agencies/stops/routes from coverage feeds.

---

## 4. Validation Rules

Component: `backend/app/tasks/gtfs_static_sync.py` (`_validate_load`).

After loading into Supabase, validation performs the following checks:

1. **Row count parity**  
   - Confirms `stops`, `routes`, `patterns`, `trips` counts from Supabase match the parser output.

2. **Supabase stops count**  
   - Verifies Supabase `stops` count matches `loaded_counts["stops"]`.

3. **NULL locations**  
   - Ensures no stops have `location` = NULL (PostGIS trigger must populate all).

4. **Minimum thresholds**  
   - `stops` ≥ 10,000  
   - `routes` ≥ 400  

5. **Mode coverage (route_type presence)**  
   - Queries `routes` to ensure at least one route exists for key `route_type` values:
     - `2` (rail), `3` (bus), `4` (ferry), `900` (light rail), `401` (metro).
   - If any expected `route_type` is missing, validation fails.

6. **Critical-stop whitelist**  
   - A curated list of “must-exist” stops is checked by `stop_name` or `stop_id`:
     - `Central Station`
     - `Central Grand Concourse Light Rail`
     - `Central Station, Platform 26`
     - `Davistown Central RSL Wharf`
   - For each, Supabase `stops` is queried; if no row is found, validation fails with a clear log entry.

If any check fails:
- `_validate_load` raises `ValueError` with details.
- `load_gtfs_static` logs and propagates the failure, preventing silent deployment of incomplete data.

---

## 5. Davistown Central RSL Wharf Case

**Bug recap:**

- Other NSW-based apps show **Davistown Central RSL Wharf** as a ferry stop with scheduled departures.
- Our app initially:
  - Returned “search failed / no stops found” when searching for this wharf.
  - Showed Davistown road bus stops but no wharf in `stops` or the iOS SQLite bundle.
- Root cause:
  - The pipeline only ingested the realtime-aligned feeds, which did not include this wharf.
  - We never downloaded or merged the broader ferries/complete feeds that *do* contain this stop.

**Resolution:**

1. Add coverage feeds (`complete`, `ferries_all`, `nswtrains`, `regionbuses`) to downloader.
2. Merge these feeds into `agencies/stops/routes` alongside realtime-mode data.
3. Add a critical-stop whitelist that includes `Davistown Central RSL Wharf`.
4. Fail the GTFS load if the wharf is absent after parsing and filtering.

This ensures that:
- If a future change, network issue, or upstream dataset regression drops Davistown wharf (or any other whitelisted stop), the validation stage will fail and surface a clear error, rather than silently shipping incomplete data.

---

## 6. Runbook: GTFS Load & Validation

### 6.1 Running the Loader

```bash
cd backend
export NSW_API_KEY=...  # from NSW Transport Open Data portal
python load_gtfs.py
```

Expected behaviour:
- Downloads all pattern and coverage feeds.
- Parses and merges them into the pattern model + coverage stops/routes.
- Loads into Supabase in dependency order.
- Inserts/updates `gtfs_metadata`.
- Runs validation, including coverage and critical-stop checks.

### 6.2 Interpreting Failures

Common failure types:

- **Missing/invalid NSW_API_KEY**  
  → Fix the environment variable and re-run.

- **Download failures (HTTP errors)**  
  → Check `gtfs_download_http_error` logs for endpoint and status code.

- **Validation failures (coverage/regressions)**  
  → Look for:
    - `gtfs_validation_mode_coverage_failed` (missing route_type).  
    - `gtfs_validation_critical_stop_missing` (e.g. Davistown wharf missing).  
  → Confirm NSW feeds are healthy via the NSW portal and consider temporarily relaxing checks only with a documented reason.

### 6.3 Updating the Critical-Stop Whitelist

- Keep the whitelist small and meaningful:
  - Major hubs (Central, key interchanges).
  - Representative stops for each mode (train, metro, ferry, light rail).
  - Known business-critical locations (e.g. Davistown Central RSL Wharf).
- When adding or changing entries:
  - Confirm the exact `stop_name`/`stop_id` in the NSW GTFS.
  - Update both:
    - `_validate_load` critical-stops list.
    - This specification, with a short rationale.

---

## 7. References

- NSW API Reference: `oracle/specs/NSW_API_REFERENCE.md`
- Data Architecture: `oracle/specs/DATA_ARCHITECTURE.md`
- Backend Specification: `oracle/specs/BACKEND_SPECIFICATION.md`
- Coverage Matrix: `backend/gtfs-coverage-matrix.md`
- Loader & Validator:
  - `backend/app/services/nsw_gtfs_downloader.py`
  - `backend/app/services/gtfs_service.py`
  - `backend/app/tasks/gtfs_static_sync.py`

---

**Status:**  
This document is the canonical reference for GTFS coverage behaviour and validation rules. Any future changes to feed usage or validation logic should be reflected here.

