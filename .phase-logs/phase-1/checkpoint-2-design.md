# Checkpoint 2: GTFS Parser + Pattern Model

## Goal
Parse GTFS CSV from multiple mode directories → extract pattern model (group trips by stop sequence), apply Sydney bbox filtering, validate counts (10k-25k stops, 400-1200 routes, 2k-10k patterns).

## Approach

### Backend Implementation
- Use gtfs-kit library (battle-tested GTFS parser)
- Implement pattern extraction algorithm (group trips by route_id + direction_id + stop_sequence)
- Files to create:
  - `app/services/gtfs_service.py` - Main parsing service with `parse_gtfs()` and `extract_patterns()` functions
- Files to modify:
  - `backend/requirements.txt` - Add `gtfs-kit==6.0.0`
- Critical pattern: Pattern model compression (8-15× smaller than stop_times), Sydney filtering (40-60% reduction)

### Implementation Details

**Pattern Model Algorithm:**
1. Load GTFS feeds from all 6 mode directories (merge into single dataset)
2. Parse CSV files: agencies, routes, stops, trips, stop_times, calendar, calendar_dates
3. **Sydney filtering:** Remove stops outside bbox [-34.5, -33.3] × [150.5, 151.5]
4. **Pattern extraction:**
   - Group trips by: `(route_id, direction_id, ordered_stop_sequence)`
   - Trips with identical stop sequences = same pattern
   - Assign `pattern_id` to each unique stop sequence
   - Calculate offsets: median `arrival_time - trip_start_time` for each stop in pattern
5. Output: patterns table, pattern_stops table (stop_sequence → offsets), trips table (trip_id → pattern_id)

**Data Structures:**
```python
Pattern = {
    "pattern_id": "P001",
    "route_id": "T1",
    "direction_id": 0,
    "stops": [...]  # List of (stop_id, stop_sequence, arrival_offset, departure_offset)
}

Trip = {
    "trip_id": "trip123",
    "pattern_id": "P001",
    "service_id": "weekday",
    "trip_headsign": "...",
    "start_time": 25200  # Seconds since midnight (7:00 AM)
}
```

**Sydney Filtering:**
- Bbox: lat ∈ [-34.5, -33.3], lon ∈ [150.5, 151.5]
- Filter stops.txt rows: `stops.stop_lat BETWEEN -34.5 AND -33.3 AND stops.stop_lon BETWEEN 150.5 AND 151.5`
- Remove trips with NO stops in bbox (some regional routes pass through)
- Expected reduction: 40-60% of original dataset

**gtfs-kit Usage:**
```python
import gtfs_kit as gk
feed = gk.read_feed("path/to/gtfs/", dist_units="km")
# Validate GTFS spec compliance
errors = feed.validate()
if errors: raise Exception("GTFS validation failed")
```

## Design Constraints
- Must handle multiple input directories (6 modes) → merge feeds
- Pattern grouping: Use pandas `groupby([route_id, direction_id]).apply(lambda group: tuple(group.stop_sequence.tolist()))`
- Median offset calculation: Use `numpy.median()` for robustness (handles schedule variations)
- Sydney bbox exact coordinates from DATA_ARCHITECTURE.md:L341-350
- Follow DEVELOPMENT_STANDARDS.md:4.1 for logging (log counts: stops, routes, patterns, trips)
- Return parsed data as dicts (for Supabase insertion in Checkpoint 4)

## Risks
- **Memory usage:** 227MB GTFS → ~500MB in-memory (pandas DataFrames)
  - Mitigation: Use chunked reading if OOM (gtfs-kit supports chunking)
- **Pattern count explosion:** Too many unique stop sequences
  - Mitigation: Sydney filtering reduces by 40-60%, expect 2k-10k patterns
- **Trip ID conflicts:** Multiple modes may have overlapping trip IDs
  - Mitigation: Prefix trip_id with mode (e.g., `train_trip123`)
- **Invalid GTFS data:** Missing required fields, invalid coordinates
  - Mitigation: Use gtfs-kit validation, log errors, fail fast

## Validation
```bash
cd backend
python -c "from app.services.gtfs_service import parse_gtfs; data = parse_gtfs('temp/gtfs-downloads/'); print(f'Stops: {len(data[\"stops\"])}, Routes: {len(data[\"routes\"])}, Patterns: {len(data[\"patterns\"])}, Trips: {len(data[\"trips\"])}')"

# Expected logs (structured):
# gtfs_parse_start: input_dirs=['sydneytrains', 'metro', 'buses', 'ferries/sydneyferries', 'ferries/MFF', 'lightrail']
# gtfs_validation_complete: errors=0
# sydney_filtering_complete: stops_before=25000, stops_after=15000, reduction_pct=40
# pattern_extraction_complete: patterns=5000, avg_stops_per_pattern=18
# gtfs_parse_complete: stops=15000, routes=800, patterns=5000, trips=120000, duration_ms=15000

# Expected ranges:
# Stops: 10000-25000 (after Sydney filtering)
# Routes: 400-1200
# Patterns: 2000-10000
# Trips: 50000-150000
```

## References for Subagent
- Exploration report: `key_decisions[0]` - Pattern model rationale
- Standards: DEVELOPMENT_STANDARDS.md:Section 2.3.2 (service layer patterns)
- Architecture: DATA_ARCHITECTURE.md:Section 5.4.3 (pattern model algorithm)
- Sydney bbox: DATA_ARCHITECTURE.md:L341-350
- gtfs-kit docs: https://pypi.org/project/gtfs-kit/ (if uncertain about API)

## Estimated Complexity
**complex** - Pattern extraction algorithm non-trivial, must handle data merging from 6 feeds, memory management, coordinate filtering, validation
