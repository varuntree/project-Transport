# GTFS Coverage Hardening Implementation Plan

**Type:** Custom Plan (Ad-hoc)  
**Context:** Ensure static GTFS pipeline loads all required NSW stops (including ferry wharves like Davistown Central RSL Wharf), add strong validation, and document guardrails so coverage regressions are caught early.
**Complexity:** complex

---

## Problem Statement

The current GTFS static pipeline only ingests a subset of NSW per‑mode, realtime-aligned feeds (sydneytrains, metro, buses, sydneyferries, MFF, lightrail). As a result, stops that exist only in other static feeds (e.g. broader ferries or complete GTFS) such as **Davistown Central RSL Wharf** never enter our database or iOS bundle. The app then under‑reports available stops compared to other vendors, which is a critical correctness issue.

---

## Affected Systems

**System: GTFS static download + parse + load**
- Current state: `nsw_gtfs_downloader` fetches 6 mode-specific feeds; `gtfs_service` parses them into a pattern model; `gtfs_static_sync` loads data into Supabase and exports SQLite for iOS.
- Gap: Missing static feeds (complete, ferries_all, nswtrains, regionbuses) and no explicit coverage validation or critical-stop whitelist.
- Files affected:
  - `backend/app/services/nsw_gtfs_downloader.py`
  - `backend/app/services/gtfs_service.py`
  - `backend/app/tasks/gtfs_static_sync.py`
  - `backend/load_gtfs.py`
  - `backend/ios_output/gtfs.db` (generated)

**System: Documentation / architecture**
- Current state: NSW API reference and data architecture specs describe desired feed usage but do not explicitly capture coverage vs pattern roles or critical stops.
- Gap: No single place documenting coverage responsibilities or validation rules.
- Files affected:
  - `oracle/specs/NSW_API_REFERENCE.md`
  - `oracle/specs/DATA_ARCHITECTURE.md`
  - New: `oracle/specs/GTFS_COVERAGE_AND_VALIDATION.md`
  - New: `backend/gtfs-coverage-matrix.md`

---

## Key Technical Decisions

1. **Separate pattern feeds from coverage feeds**
   - Rationale: Pattern model + GTFS-RT alignment should remain based on realtime-compatible per‑mode feeds, while stop coverage must include all static feeds (complete + extra modes).
   - Reference: `oracle/specs/DATA_ARCHITECTURE.md` Section 5 (GTFS Static Ingestion Pipeline).
   - Critical constraint: Do not break existing pattern extraction or GTFS‑RT alignment.

2. **Treat coverage gaps as hard failures**
   - Rationale: Missing whole classes of stops (e.g. ferry wharves) is worse than failing the GTFS load; catching this at load time avoids shipping under‑reported data.
   - Reference: `backend/app/tasks/gtfs_static_sync.py` validation section.
   - Critical constraint: Loader must fail loudly if critical stops or expected modes are absent.

3. **Maintain a small critical-stop whitelist**
   - Rationale: A curated set of “must-exist” stops (Central, key light rail, metro platforms, Davistown wharf) gives a clear regression signal without needing full NSW diffing.
   - Reference: new `GTFS_COVERAGE_AND_VALIDATION.md`.
   - Critical constraint: List should remain small and curated; changes should be deliberate and documented.

---

## Implementation Checkpoints

### Checkpoint 1: NSW Feed Coverage Matrix

**Goal:** Capture a clear matrix of NSW static GTFS feeds, their roles (pattern vs coverage), and whether we currently ingest them.

**Backend Work:**
- Add `backend/gtfs-coverage-matrix.md` summarising:
  - Each GTFS static endpoint (complete, buses, sydneytrains v2, metro v2, ferries, sydneyferries, MFF, lightrail, nswtrains, regionbuses).
  - Columns: `used_for_download`, `used_for_pattern`, `used_for_coverage`, `notes`.
- Include Davistown Central RSL Wharf as an example of a stop that must appear from coverage feeds.

**iOS Work:**  
- N/A.

**Design Constraints:**
- Keep matrix small and human-readable (single-page markdown).
- Align names with `NSW_API_REFERENCE.md` and `nsw_gtfs_downloader.py`.

**Validation:**
```bash
test -f backend/gtfs-coverage-matrix.md
```

---

### Checkpoint 2: Extend NSW GTFS Downloader Endpoints

**Goal:** Ensure all static feeds needed for pattern and coverage are downloaded.

**Backend Work:**
- Update `backend/app/services/nsw_gtfs_downloader.py`:
  - Keep existing entries for `sydneytrains`, `metro`, `buses`, `sydneyferries`, `mff`, `lightrail`.
  - Add endpoints for:
    - `complete` → `/v1/publictransport/timetables/complete/gtfs`
    - `ferries_all` → `/v1/gtfs/schedule/ferries`
    - `nswtrains` → `/v1/gtfs/schedule/nswtrains`
    - `regionbuses` → `/v1/gtfs/schedule/regionbuses`
- Log per-mode sizes and basic `stops.txt` stats (rows, presence of any `stop_name` containing `Davistown`) for ferry feeds.

**iOS Work:**  
- N/A.

**Design Constraints:**
- Respect NSW API rate limits (keep sequential downloads and existing delay).
- Fail clearly if new feeds 404 or are unavailable, with mode and endpoint logged.

**Validation:**
```bash
python backend/load_gtfs.py  # manual run in real environment
# Expected: logs show new modes in gtfs_download_start/gtfs_download_all_complete
```

---

### Checkpoint 3: Parser Enhancements for Coverage Feeds

**Goal:** Use all static feeds for stop coverage while keeping the pattern model based on realtime-aligned feeds.

**Backend Work:**
- In `backend/app/services/gtfs_service.py`:
  - Keep `MODE_DIRS` as the list of realtime-aligned pattern feeds.
  - Add a secondary list for coverage-only modes (e.g., `COVERAGE_EXTRA_DIRS = ["complete", "ferries_all", "nswtrains", "regionbuses"]`).
  - Extend `_load_and_merge_feeds` to:
    - Merge agencies/stops/routes from `MODE_DIRS` as today (pattern data).
    - Best-effort load `agency.txt`, `stops.txt`, `routes.txt` from any existing coverage-extra directories and append them to the main DataFrames.
  - Leave `trips` and `stop_times` based only on realtime-aligned feeds to avoid breaking GTFS‑RT alignment.
- Ensure `_apply_sydney_filter` operates on the combined `stops` DataFrame, deduplicates by `stop_id`, and applies the Sydney bbox.

**iOS Work:**  
- N/A (iOS consumes the SQLite output of this pipeline).

**Design Constraints:**
- Preserve existing pattern extraction semantics and performance.
- Log coverage-extra loading errors without aborting the entire parse unless all modes fail.

**Validation:**
```bash
python backend/load_gtfs.py  # in real environment
# Expected: gtfs_parse_complete logs unchanged pattern counts but potentially higher stops/routes counts.
```

---

### Checkpoint 4: Strong GTFS Validation (Coverage + Critical Stops)

**Goal:** Fail the GTFS load when key modes or critical stops (e.g. Davistown wharf) are missing.

**Backend Work:**
- In `backend/app/tasks/gtfs_static_sync.py` `_validate_load`:
  - Add mode coverage checks:
    - Use Supabase queries to ensure at least one route exists for important route types (e.g. trains, buses, ferries, light rail, metro).
  - Add a small critical-stop whitelist:
    - Include Central Station, key Central platforms (light rail + metro), and **Davistown Central RSL Wharf**.
    - For each, query the `stops` table by `stop_id` or strict `stop_name`.
    - If any is missing, add a clear issue string and treat validation as failed.
- Log validation failures with explicit reasons, including which critical stop or mode is missing.

**iOS Work:**  
- N/A.

**Design Constraints:**
- Keep whitelist small and curated, with clear comments for each stop.
- Do not silently downgrade failures to warnings.

**Validation:**
```bash
python backend/load_gtfs.py  # in real environment
# Expected: validation fails if Davistown wharf or any other whitelisted stop is missing.
```

---

### Checkpoint 5: Regenerate Data and Verify Davistown & Sample Set

**Goal:** Confirm that coverage fixes actually surface Davistown wharf and other critical stops into the DB and iOS bundle.

**Backend Work (manual run in real environment):**
- Run `python backend/load_gtfs.py` with a valid NSW API key.
- After successful load:
  - In Supabase or the exported SQLite:
    - Verify `SELECT * FROM stops WHERE stop_name LIKE '%Davistown%' AND stop_name LIKE '%Wharf%';` returns at least one row.
    - Spot check Central and a handful of other critical stops.

**iOS Work (manual):**
- Regenerate `backend/ios_output/gtfs.db` as per existing tooling.
- Run the iOS app and confirm:
  - Searching for “Davistown” reveals the wharf stop.
  - Stop details load without errors; departures behave as designed (even if static-only).

**Design Constraints:**
- Use this checkpoint as a manual acceptance test; do not bake environment-specific commands into CI.

**Validation:**
```sql
-- Against Supabase / SQLite:
SELECT * FROM stops WHERE stop_name LIKE '%Davistown%' AND stop_name LIKE '%Wharf%';
```

---

### Checkpoint 6: Documentation & Guardrails

**Goal:** Document the coverage model, validation strategy, and critical-stop whitelist so future work understands and preserves these guarantees.

**Backend/Docs Work:**
- Add `oracle/specs/GTFS_COVERAGE_AND_VALIDATION.md`:
  - Explain:
    - Pattern vs coverage feeds and why both exist.
    - How the Davistown wharf bug occurred.
  - Document:
    - All static feeds we rely on and their roles.
    - The critical-stop whitelist and how to modify it safely.
    - All validation checks in `_validate_load` (counts, modes, critical stops, null locations, thresholds).
  - Include a short “runbook” for running `load_gtfs_static`, reading logs, and reacting to failures.
- Add short references in:
  - `oracle/specs/DATA_ARCHITECTURE.md`
  - `oracle/specs/BACKEND_SPECIFICATION.md`
  pointing to this new coverage spec.

**iOS Work:**  
- N/A.

**Design Constraints:**
- Keep the new spec focused and action-oriented (no duplication of existing docs).
- Make it the canonical reference for GTFS coverage assumptions and validation rules.

**Validation:**
```bash
test -f oracle/specs/GTFS_COVERAGE_AND_VALIDATION.md
```

---

## Acceptance Criteria

- [ ] NSW static feed coverage matrix exists and matches implementation.
- [ ] Downloader fetches all required static feeds (at least complete + per‑mode for buses, trains, metro, ferries, light rail).
- [ ] Parser merges coverage feeds into the stops set without breaking the existing pattern model.
- [ ] GTFS load validation fails if:
  - [ ] Any expected mode (e.g. ferries) has zero routes.
  - [ ] Any critical stop from the whitelist (including Davistown Central RSL Wharf) is missing.
- [ ] After a successful load with a valid NSW API key:
  - [ ] Davistown Central RSL Wharf exists in `stops`.
  - [ ] Central Station, key light rail and metro platforms exist as expected.
- [ ] GTFS coverage and validation are documented in `GTFS_COVERAGE_AND_VALIDATION.md` and referenced from the main data/ backend specs.

---

## User Blockers (Pre-Implementation)

- Valid NSW API key with access to static GTFS feeds is configured in environment (`NSW_API_KEY`) for live validation runs.

---

## Related Phases

- Related to Phase 2 GTFS static ingestion and realtime integration, but implemented as a standalone hardening pass focused on coverage correctness.

---

**Plan Created:** 2025-11-18  
**Estimated Duration:** A few working sessions (downloads + validation will dominate wall-clock time in real environment).

