# Bug: Missing Light Rail Coverage - RESOLVED

**Status:** ✅ RESOLVED (2025-11-21)

## Original Issue
4 interrelated failures in light rail GTFS data:
1. Only L1 route in lightrail feed patterns (missing L2, L3, L4)
2. 116 train platforms contaminating lightrail feed patterns
3. iOS filter missing route_type 0 (GTFS standard)
4. Stale data accumulation from previous loads

## Root Cause
- lightrail feed had incomplete coverage (only L1) AND train platform contamination
- complete feed had all 6 routes (L1, L2, L3, L4, LX, NLR) with clean data
- Initially both feeds loaded → contamination persisted

## Solution Implemented

### Option 2: Contamination Filter + Complete Feed Merge
GTFS-RT requires lightrail feed trip_ids → cannot exclude lightrail from MODE_DIRS

**Changes:**
1. **gtfs_service.py:157-186** - Filter train platforms from lightrail feed
   - Detects stops with "Platform" NOT containing "Light Rail"
   - Removes from stop_times and stops before pattern extraction

2. **gtfs_service.py:232-282** - Merge L2/L3/L4 from complete feed
   - Prefixes trip_ids: "complete_lr_" + original
   - Adds missing routes while preserving GTFS-RT alignment

3. **gtfs_static_sync.py:161-220** - Cleanup stale light rail data
   - Deletes in reverse dependency order before load

4. **gtfs_static_sync.py:496-556** - Hardened validation
   - min_lr_routes=3, min_lr_trips=6000, min_lr_stops=100

5. **SearchView.swift:20** - Include both route_types
   - Changed from [900] to [0, 900]

6. **ios_db_generator.py:648-655** - Relaxed file size limit
   - 50MB → 100MB (iOS allows 100MB without WiFi warning)

## Validation Results

### Supabase (Post-Load)
```sql
-- 6 routes
SELECT COUNT(*) FROM routes WHERE route_type IN (0, 900);
-- Result: 6 (L1, L1 Dulwich Hill, L2, L3, L4, LX)

-- 8,511 trips
SELECT COUNT(*) FROM trips
WHERE route_id IN (SELECT route_id FROM routes WHERE route_type IN (0, 900));
-- Result: 8,511

-- 116 stops
SELECT COUNT(DISTINCT s.stop_id) FROM stops s
JOIN pattern_stops ps ON s.stop_id = ps.stop_id
JOIN patterns p ON ps.pattern_id = p.pattern_id
JOIN routes r ON p.route_id = r.route_id
WHERE r.route_type IN (0, 900);
-- Result: 116

-- 0 contamination
WITH lr_routes AS (SELECT route_id FROM routes WHERE route_type IN (0, 900)),
     lr_patterns AS (SELECT pattern_id FROM patterns WHERE route_id IN (SELECT route_id FROM lr_routes)),
     lr_pattern_stops AS (SELECT DISTINCT ps.stop_id FROM pattern_stops ps WHERE ps.pattern_id IN (SELECT pattern_id FROM lr_patterns)),
     contaminated AS (SELECT s.stop_id, s.stop_name FROM stops s WHERE s.stop_id IN (SELECT stop_id FROM lr_pattern_stops) AND s.stop_name LIKE '%Platform%' AND s.stop_name NOT LIKE '%Light Rail%')
SELECT COUNT(*) FROM contaminated;
-- Result: 0
```

### iOS Bundle (gtfs.db)
```bash
# 6 routes
sqlite3 gtfs.db "SELECT COUNT(*) FROM routes WHERE route_type IN (0, 900);"
# Result: 6

# 116 stops
sqlite3 gtfs.db "SELECT COUNT(DISTINCT s.sid) FROM stops s JOIN pattern_stops ps ON s.sid = ps.sid JOIN patterns p ON ps.pid = p.pid JOIN routes r ON p.rid = r.rid WHERE r.route_type IN (0, 900);"
# Result: 116

# 0 contamination
sqlite3 gtfs.db "WITH lr_routes AS (SELECT rid FROM routes WHERE route_type IN (0, 900)), lr_patterns AS (SELECT pid FROM patterns WHERE rid IN (SELECT rid FROM lr_routes)), lr_pattern_stops AS (SELECT DISTINCT ps.sid FROM pattern_stops ps WHERE ps.pid IN (SELECT pid FROM lr_patterns)), contaminated AS (SELECT s.sid, s.stop_name FROM stops s WHERE s.sid IN (SELECT sid FROM lr_pattern_stops) AND s.stop_name LIKE '%Platform%' AND s.stop_name NOT LIKE '%Light Rail%') SELECT COUNT(*) FROM contaminated;"
# Result: 0

# File size: 74.10 MB (within 100MB iOS limit)
```

## Impact
- ✅ All 6 light rail routes now in Supabase and iOS bundle
- ✅ 0 train platforms contaminating light rail patterns
- ✅ iOS search filter correctly shows both GTFS standard (0) and NSW variant (900)
- ✅ GTFS-RT alignment maintained (lightrail feed trip_ids preserved)
- ✅ Stale data cleanup prevents accumulation

## Files Modified
- `/backend/app/services/gtfs_service.py` (contamination filter + merge logic)
- `/backend/app/tasks/gtfs_static_sync.py` (cleanup + validation)
- `/backend/app/services/ios_db_generator.py` (file size limit)
- `/SydneyTransit/SydneyTransit/Features/Search/SearchView.swift` (route_type filter)

## Regeneration Commands
```bash
# Backend: Re-run GTFS load
cd backend && source venv/bin/activate
python scripts/load_gtfs.py

# iOS: Regenerate bundle
python scripts/generate_ios_db.py
# Copies to: ../SydneyTransit/SydneyTransit/Resources/gtfs.db
```

## Lessons Learned
1. **GTFS-RT Dependency:** Must verify trip_id alignment before excluding feeds
2. **Data Archaeology:** NSW feeds have overlapping but incomplete coverage
3. **Contamination Patterns:** lightrail feed has train platforms, complete feed is clean
4. **Dual route_types:** Light rail uses both 0 (GTFS standard) and 900 (NSW variant)
5. **Stale Data:** Always cleanup before load to prevent accumulation
