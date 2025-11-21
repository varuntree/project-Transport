# GTFS Static Feed Coverage Matrix

Documents which NSW GTFS feeds participate in pattern model extraction vs coverage-only merging.

## Critical Architecture Decision: MODE_DIRS vs COVERAGE_EXTRA_DIRS

**Pattern Model Feeds (MODE_DIRS):**
Extract trips/stop_times for pattern-based schedule storage. MUST verify GTFS-RT trip_id alignment.

**Coverage Feeds (COVERAGE_EXTRA_DIRS):**
Agencies/stops/routes only (NO trips/stop_times). Improve coverage beyond realtime-aligned feeds.

| Feed Key      | Endpoint | Used for Patterns | Used for Coverage | Notes |
|--------------|----------|-------------------|-------------------|-------|
| sydneytrains | `/v1/gtfs/schedule/sydneytrains` | ✅ | ✅ | Sydney Trains v1, aligns with v1 realtime |
| metro | `/v2/gtfs/schedule/metro` | ✅ | ✅ | Metro v2, aligns with v2 realtime |
| buses | `/v1/gtfs/schedule/buses` | ✅ | ✅ | All bus operators, aligns with v1 realtime |
| sydneyferries | `/v1/gtfs/schedule/ferries/sydneyferries` | ✅ | ✅ | Sydney Ferries, aligns with ferry realtime |
| mff | `/v1/gtfs/schedule/ferries/MFF` | ✅ | ✅ | Manly Fast Ferry, aligns with MFF realtime |
| **complete** | `/v1/publictransport/timetables/complete/gtfs` | ✅ **filtered** | ✅ | **Light rail source:** filter route_type 0/900 for patterns. Full NSW agencies/stops/routes for coverage. |
| ferries_all | `/v1/gtfs/schedule/ferries` | ❌ | ✅ | All ferry contracts, coverage only (wharves like Davistown) |
| nswtrains | `/v1/gtfs/schedule/nswtrains` | ❌ | ✅ | NSW TrainLink regional, coverage only |
| regionbuses | `/v1/gtfs/schedule/regionbuses` | ❌ | ✅ | Regional buses, coverage only |
| ~~lightrail~~ | ~~`/v1/gtfs/schedule/lightrail`~~ | **❌ EXCLUDED** | ❌ | **INCOMPLETE (only L1) + CONTAMINATED (train platforms). Use complete feed filtered by route_type 0/900.** |

## Light Rail Coverage Fix (Nov 2024)

**Problem:** lightrail feed incomplete (1 route vs 6 in complete) + contaminated with train stops

**Solution:**
1. Exclude lightrail from MODE_DIRS
2. Add complete to MODE_DIRS with route_type filter
3. Extract patterns from complete feed WHERE route_type IN (0, 900)
4. Prefix trip_ids to avoid collisions: `complete_lr_{original_trip_id}`

**Validation:**
- Light rail routes ≥3
- Light rail trips ≥6000
- Light rail stops ~120-130 distinct
- Zero train platforms in light rail patterns

## Coverage Model Summary

- **Pattern model feeds (MODE_DIRS):** `sydneytrains`, `metro`, `buses`, `sydneyferries`, `mff`, `complete` (filtered)
  - Supply `trips`, `stop_times`, and associated `routes`/`calendar` for pattern extraction
  - **MUST** align with GTFS-RT trip_ids for real-time departures

- **Coverage-only feeds (COVERAGE_EXTRA_DIRS):** `complete`, `ferries_all`, `nswtrains`, `regionbuses`
  - Merged into `agencies`, `stops`, and `routes` only (NO trips/stop_times used)
  - Improve stop/route coverage (ferry wharves, regional services)
  - No GTFS-RT alignment concerns

## Davistown Central RSL Wharf

Reference "must-exist" stop from ferries_all/complete coverage feeds. Expected in Sydney bbox. Validation fails if missing.
