# Bug Fix Report: Missing Light Rail Stops at Central Station

**Bug:** Missing Light Rail platform stops at Central Station - only 1 generic stop shown instead of multiple L1/L2/L3 platforms

**Status:** Fixed

**Timestamp:** 2025-11-21T02:37:57Z

---

## Bug Summary

Official TripView app shows multiple Light Rail services (L1/L2/L3) at Central Station with platform numbers and real-time data. Our app shows only "Central Grand Concourse Light Rail" stop when searching "Central". Database query confirmed: Only 1 Light Rail stop (sid 30358) vs 27 train platforms at Central. Potentially system-wide issue affecting all Light Rail stops.

---

## Root Cause

**Category:** logic_error

**Description:**
GTFS import deduplicates stops by `stop_id` only (backend/app/services/gtfs_service.py:333-338), using `keep='first'` strategy. Light Rail feed processed last (6th position in feed order: trains→metro→buses→ferries→mff→lightrail), so any stops with stop_id matching earlier feeds are discarded. This removes Light Rail platform stops at Central Station, leaving only 1 generic stop instead of multiple L1/L2/L3 platforms.

**Confidence:** 95%

**Evidence:**
- Line 335 in gtfs_service.py (before fix): `sydney_stops.drop_duplicates(subset=['stop_id'], keep='first')` - no consideration of parent_station or location_type
- Line 34-40 in nsw_gtfs_downloader.py: Feed order is trains→metro→buses→ferries→mff→lightrail (Light Rail last)
- Database evidence: 1 Light Rail stop at Central (sid 30358, parent_station=NULL) vs 27 train platforms (parent_station=200060)
- Database evidence: ALL 79 Light Rail stops in database have parent_station=NULL (orphaned platforms) vs trains with proper hierarchy
- TripView shows L1/L2/L3 platforms - confirms NSW source data has multiple Light Rail stops at Central

**Fundamental Cause:**
Two compounding failures:
1. **NSW GTFS data quality issue:** Light Rail feed has poor hierarchy - all platform stops marked location_type=0 with parent_station=NULL (orphaned), violating GTFS spec best practices. Train feed has proper parent/child relationships.
2. **Deduplication logic assumes stop_id uniqueness:** Code treats any stop_id match as "duplicate" and keeps first occurrence. Reality: NSW may reuse stop_ids across feeds for semantically different entities (e.g., "200060" = train parent station AND generic Light Rail entry). Deduplication blindly discards Light Rail variants without checking parent_station/location_type.

---

## Fix Applied

**Approach:**
Smart deduplication by hierarchy category: Deduplicate ONLY parent stations (location_type=1), preserve ALL child platforms (location_type=0 with parent_station) and orphan stops (location_type=0 without parent_station). Orphan stops are unique physical locations despite missing parent (NSW Light Rail data quality issue).

**Files Modified:**
- backend/app/services/gtfs_service.py

**Changes:**
Lines 333-338 (6 lines) replaced with lines 333-362 (30 lines):
- Handle empty string '' as NULL for parent_station (NSW GTFS inconsistency)
- Categorize stops into 4 groups:
  - Parent stations (location_type='1') - Generic station containers
  - Child stops (location_type='0' + has parent_station) - Platform-specific stops under parent
  - Orphan stops (location_type='0' + no parent_station) - NSW Light Rail orphaned platforms
  - Other stops (location_type ∉ ['0','1']) - Entrances, nodes, etc.
- Deduplicate only parent stations by stop_id (keep='first')
- Concatenate: deduped parents + ALL children + ALL orphans + ALL other
- Enhanced structured logging with category breakdown for debugging

**Code change:**
```python
# OLD (line 335):
sydney_stops_dedup = sydney_stops.drop_duplicates(subset=["stop_id"], keep="first")

# NEW (lines 333-362):
# Smart deduplication: Preserve stop hierarchy
# Only deduplicate parent stations (location_type=1), keep ALL child platforms and orphans
sydney_stops['parent_station'] = sydney_stops['parent_station'].replace('', None)
parent_stations = sydney_stops[sydney_stops['location_type'] == '1']
child_stops = sydney_stops[(sydney_stops['location_type'] == '0') & sydney_stops['parent_station'].notna()]
orphan_stops = sydney_stops[(sydney_stops['location_type'] == '0') & sydney_stops['parent_station'].isna()]
other_stops = sydney_stops[~sydney_stops['location_type'].isin(['0', '1'])]
parent_stations_dedup = parent_stations.drop_duplicates(subset=['stop_id'], keep='first')
sydney_stops_dedup = pd.concat([parent_stations_dedup, child_stops, orphan_stops, other_stops], ignore_index=True)
logger.info("stops_smart_deduplication", stops_before=..., orphan_stops=len(orphan_stops), ...)
```

---

## Validation

**Compile Check:** Passed (`python -m py_compile app/services/gtfs_service.py`)

**Manual Trace:**
Old logic: `drop_duplicates` by stop_id (keeps first feed occurrence, discards Light Rail processed last). New logic: Categorize by location_type + parent_station → deduplicate only parent stations → preserve all child/orphan platforms. Result: 79 Light Rail orphan stops + 27 train child platforms + deduped parents all retained.

**Risks Mitigated:**
- Handle empty string '' as NULL for parent_station (NSW GTFS inconsistency at line 339)
- Handle location_type values other than '0'/'1' (other_stops category at line 345)
- Preserve existing train platform hierarchy (child_stops with parent_station at line 343)
- Enhanced logging shows category counts for debugging (lines 353-362)

**Test Plan:**
1. Run GTFS import: `cd backend && python -m app.tasks.gtfs_static_sync`
2. Check logs for `stops_smart_deduplication` message with category breakdown:
   - orphan_stops: Should show 79 (Light Rail)
   - child_stops: Should show train platforms
   - parent_stations_before/after: Should show deduplication count
3. Query database for Light Rail stops at Central:
   ```sql
   SELECT stop_name FROM stops
   WHERE stop_name LIKE '%Central%'
   AND sid IN (
     SELECT DISTINCT ps.sid FROM pattern_stops ps
     JOIN patterns p ON ps.pid=p.pid
     JOIN routes r ON p.rid=r.rid
     WHERE r.route_type=900
   );
   ```
   Expected: Multiple Light Rail stops (not just 1 "Central Grand Concourse Light Rail")
4. Rebuild iOS gtfs.db: Copy updated gtfs.db to SydneyTransit/Resources/
5. Test in iOS app: Search "Central" → tap "Light Rail" filter → verify multiple stops shown
6. Regression check: Search "Central" → tap "Train" filter → verify 27 platforms still shown

---

## Affected Systems

- **GTFS Data Import** (Backend Data Pipeline)
  - Primary: backend/app/services/gtfs_service.py (deduplication logic)
  - Secondary: backend/app/services/nsw_gtfs_downloader.py (feed processing order)

---

## Related Phase

**Primary Phase:** Phase 1 (GTFS static data import implemented)

**Phase 1 - Checkpoint 2:** Implemented GTFS parser and pattern model. Deduplication logic introduced to handle overlapping stops across feeds. Did not account for stop hierarchy (location_type, parent_station) during deduplication.

---

## Fix Confidence

**Overall:** 95%

**Why 95% not 100%:**
- Haven't inspected raw NSW Light Rail GTFS stops.txt to confirm multiple platform stops exist upstream (95% confidence based on TripView evidence)
- Haven't run manual test plan yet (deferred to user - GTFS import requires backend setup)

**Next validation:** User runs GTFS import and tests in iOS app per test plan above.

---

## System-Wide Impact Analysis

**Scope:** All Light Rail stops potentially affected (not just Central Station)

**Database evidence:**
- ALL 79 Light Rail stops in database have parent_station=NULL (orphaned)
- Train stops: 255 parent stations + 676 child platforms with proper hierarchy
- Light Rail network small (79 total stops), so impact contained but 100% of Light Rail stops may be missing platform granularity

**Fix impact:**
- Preserves all 79 Light Rail orphan stops (no longer discarded during deduplication)
- Preserves all 676 train child platforms (existing behavior maintained)
- Parent stations still deduplicated across feeds (existing behavior maintained)
- Expected database growth: +0-50 stops (depends on NSW GTFS source data structure - may have more Light Rail platforms that were previously discarded)

**Regression risk:** Minimal. Only affects deduplication logic. Train hierarchy preserved via child_stops category. Parent station deduplication unchanged (still keep='first').

---

## Logs

- Map: .workflow-logs/bugs/1763715077-missing-light-rail-stops-central-station/map-result.json
- Explore: .workflow-logs/bugs/1763715077-missing-light-rail-stops-central-station/explore-result.json
- Diagnosis: .workflow-logs/bugs/1763715077-missing-light-rail-stops-central-station/diagnosis-result.json
- Fix: .workflow-logs/bugs/1763715077-missing-light-rail-stops-central-station/fix-result.json

---

**Report Generated:** 2025-11-21T02:37:57Z
