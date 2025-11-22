# Fix GTFS Supabase Duplicate Key Error Implementation Plan

**Type:** Custom Plan (Bug Fix)
**Context:** After implementing smart stop deduplication (preserving Light Rail orphan stops), GTFS import fails with Supabase duplicate key error during batch upload
**Complexity:** Medium

---

## Problem Statement

Smart deduplication successfully preserves Light Rail orphan stops (orphan_stops=80) by deduplicating by `stop_id` within hierarchy categories. However, Supabase upload fails at batch ~26 with error: "ON CONFLICT DO UPDATE command cannot affect row a second time".

**Root cause:** Deduplication by `stop_id` doesn't prevent duplicate entries in the final dataset because the same `stop_id` can appear multiple times WITHIN the same hierarchy category (e.g., two "orphan_stops" from different feeds with identical `stop_id`). Supabase primary key is `stop_id`, so duplicate `stop_id` values in the same batch cause the upsert to fail.

**Current state:** GTFS downloads and parsing succeed, smart deduplication preserves hierarchy (orphan_stops=80, child_stops=689), but batch 26 upload to Supabase fails with duplicate key error.

**Why needed:** iOS database needs updated GTFS data with Light Rail platform stops. Currently stuck because Supabase upload fails, preventing iOS database regeneration.

---

## Affected Systems

**System: GTFS stop deduplication logic (gtfs_service.py)**
- Current state: Deduplicates by `stop_id` within hierarchy categories (lines 348-351), but duplicate `stop_id` values can still exist within a category if feeds provide identical `stop_id`
- Gap: Final deduplication by `stop_id` across ALL stops needed before Supabase upload
- Files affected: `backend/app/services/gtfs_service.py`

**System: Supabase batch upsert (gtfs_static_sync.py)**
- Current state: Batch inserts 1000 stops at a time with `ON CONFLICT DO UPDATE` (lines 161-216)
- Gap: Fails if same `stop_id` appears multiple times in batch (Postgres constraint violation)
- Files affected: `backend/app/tasks/gtfs_static_sync.py`

---

## Key Technical Decisions

1. **Add global stop_id deduplication AFTER hierarchy-based deduplication**
   - Rationale: Hierarchy logic preserves orphan stops (Light Rail fix), but must ensure no duplicate `stop_id` values exist in final dataset before Supabase upload
   - Reference: gtfs_service.py:333-368 (smart_deduplication section)
   - Critical constraint: Must preserve orphan_stops count (~80) - don't discard Light Rail stops

2. **Use keep='first' strategy for global deduplication**
   - Rationale: If same `stop_id` appears in multiple categories (e.g., parent station in one feed, orphan stop in another), keep first occurrence based on category priority order
   - Reference: DEVELOPMENT_STANDARDS.md pandas deduplication patterns
   - Critical constraint: Category order matters - prioritize child_stops > orphan_stops > parent_stations > other_stops to preserve most granular data

---

## Implementation Checkpoints

### Checkpoint 1: Add global stop_id deduplication after hierarchy logic

**Goal:** Eliminate duplicate `stop_id` values in final dataset while preserving hierarchy counts

**Backend Work:**
- Modify `gtfs_service.py` lines 354-368 (after hierarchy deduplication, before logging)
- After `sydney_stops_dedup = pd.concat([...])`, add global deduplication:
  ```python
  # Global deduplication by stop_id (Supabase primary key constraint)
  # Keep first occurrence (priority: child > orphan > parent > other based on concat order)
  sydney_stops_final = sydney_stops_dedup.drop_duplicates(subset=['stop_id'], keep='first')
  ```
- Update logging to show global deduplication impact:
  ```python
  logger.info(
      "stops_global_deduplication",
      stops_after_hierarchy=len(sydney_stops_dedup),
      stops_after_global=len(sydney_stops_final),
      duplicates_removed=len(sydney_stops_dedup) - len(sydney_stops_final)
  )
  ```
- Return `sydney_stops_final` instead of `sydney_stops_dedup`

**iOS Work:**
- N/A

**Design Constraints:**
- Follow DEVELOPMENT_STANDARDS.md pandas patterns (drop_duplicates with keep='first')
- Preserve concat order: `[parent_stations_dedup, child_stops_dedup, orphan_stops_dedup, other_stops_dedup]` so child/orphan take priority
- Must NOT reduce orphan_stops count significantly (max ~5% reduction acceptable if true duplicates exist)
- Add structured logging for debugging

**Validation:**
```bash
cd backend && source venv/bin/activate && python scripts/load_gtfs.py
# Expected logs:
# - stops_smart_deduplication: orphan_stops_after=80 (preserved)
# - stops_global_deduplication: duplicates_removed=N (small number)
# - gtfs_load_complete: SUCCESS (no Supabase error)
```

**References:**
- Pattern: pandas drop_duplicates (DEVELOPMENT_STANDARDS.md)
- Current code: gtfs_service.py:333-368 (smart_deduplication)
- Error location: gtfs_static_sync.py:193 (Supabase upsert failure)

---

### Checkpoint 2: Run GTFS import and verify Supabase success

**Goal:** GTFS import completes without Supabase duplicate key error

**Backend Work:**
- Run full GTFS import: `python scripts/load_gtfs.py`
- Monitor logs for:
  - `stops_smart_deduplication` counts (orphan_stops_after should be ~80)
  - `stops_global_deduplication` duplicates_removed count
  - `gtfs_load_complete` SUCCESS message
  - NO `gtfs_load_pipeline_failed` error
- Query Supabase stops table for Light Rail at Central:
  ```sql
  SELECT stop_name FROM stops
  WHERE stop_name LIKE '%Central%'
  AND stop_id IN (
    SELECT DISTINCT ps.stop_id FROM pattern_stops ps
    JOIN patterns p ON ps.pattern_id = p.pattern_id
    JOIN routes r ON p.route_id = r.route_id
    WHERE r.route_type = 900
  );
  ```

**iOS Work:**
- N/A

**Design Constraints:**
- GTFS import should take ~3-5 minutes (no performance regression)
- Supabase upload should reach 100% without errors
- Final stop count should be ~60K (similar to previous successful imports)

**Validation:**
```bash
# Check logs
tail -100 /tmp/gtfs_import2.log | grep -E "load_complete|SUCCESS|Failed"
# Expected: gtfs_load_complete SUCCESS

# Query Supabase (via Supabase dashboard or API)
# Expected: Multiple Light Rail stops at Central (not just 1)
```

**References:**
- Import script: backend/scripts/load_gtfs.py
- Supabase upload: gtfs_static_sync.py:161-216

---

### Checkpoint 3: Generate iOS database and verify fix

**Goal:** iOS database regenerated with multiple Light Rail stops at Central, search works correctly

**Backend Work:**
- Generate iOS SQLite from Supabase:
  ```bash
  cd backend && source venv/bin/activate
  python -c "from app.services.ios_db_generator import generate_ios_db; generate_ios_db()"
  ```
- Copy to iOS Resources:
  ```bash
  cp backend/var/data/gtfs.db SydneyTransit/SydneyTransit/Resources/gtfs.db
  ```

**iOS Work:**
- Rebuild iOS app in Xcode (Cmd+B)
- Test search:
  1. Search "Central"
  2. Tap "Light Rail" filter
  3. Verify multiple Light Rail stops shown (not just 1)
- Regression test:
  1. Search "Central"
  2. Tap "Train" filter
  3. Verify still shows 27 train platforms

**Design Constraints:**
- iOS gtfs.db should be ~15-20MB (within target size)
- Follow ios_db_generator.py validation (file size check)
- No schema changes (existing iOS code should work without modifications)

**Validation:**
```bash
# Query iOS database
sqlite3 SydneyTransit/SydneyTransit/Resources/gtfs.db "
  SELECT COUNT(*) FROM stops
  WHERE stop_name LIKE '%Central%'
  AND sid IN (
    SELECT DISTINCT ps.sid FROM pattern_stops ps
    JOIN patterns p ON ps.pid = p.pid
    JOIN routes r ON p.rid = r.rid
    WHERE r.route_type = 900
  );
"
# Expected: > 1 (multiple Light Rail stops at Central)

# Manual iOS app test
# Search 'Central' → Light Rail filter → Multiple stops shown
```

**References:**
- Generator: backend/app/services/ios_db_generator.py
- iOS database location: SydneyTransit/SydneyTransit/Resources/gtfs.db

---

## Acceptance Criteria

- [x] GTFS import completes successfully without Supabase duplicate key error
- [x] `orphan_stops` count preserved (~80, max 5% reduction acceptable)
- [x] Supabase stops table has multiple Light Rail stops at Central (not just 1)
- [x] iOS gtfs.db regenerated with multiple Light Rail stops at Central
- [x] iOS app search "Central" in Light Rail mode shows multiple stops
- [x] No regression: Train stops at Central still show 27 platforms

---

## User Blockers (Complete Before Implementation)

None - backend environment fully set up, all dependencies installed

---

## Research Notes

**iOS Research Completed:**
N/A - No iOS code changes required (bug fix in backend only)

**On-Demand Research (During Implementation):**
- None expected (standard pandas deduplication pattern)

---

## Related Phases

**Phase 1:** Implemented GTFS import pipeline with original simple deduplication (discarded Light Rail stops)

**Recent Bug Fixes:**
- Commit 85ee3fa: Implemented smart deduplication preserving hierarchy
- Commit 84495f5: Refined to deduplicate within hierarchy categories
- This fix: Add final global deduplication by stop_id before Supabase upload

---

## Exploration Report

Attached: `.workflow-logs/custom/fix-gtfs-supabase-duplicate-key-error/exploration-report.json`

---

**Plan Created:** 2025-11-21
**Estimated Duration:** 2-4 hours
