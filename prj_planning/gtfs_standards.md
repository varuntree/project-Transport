# GTFS Standards & Transit Routing Reference

## Executive Summary

### Key Concepts
- **GTFS Static**: Text-based specification defining scheduled transit data (routes, stops, schedules)
- **GTFS Realtime**: Protocol Buffer-based format for live vehicle positions, trip updates, service alerts
- **Transit Routing**: Algorithms designed for multi-criteria optimization (arrival time + transfers)
- **Complexity**: Medium-high; requires understanding time calculations, timezone handling, calendar logic, graph algorithms

### Recommended Approach for iOS App
1. **Data Storage**: SQLite with integer identifiers, denormalized data for performance
2. **Routing Algorithm**: RAPTOR (Round-based Public Transit Optimized Router) - no preprocessing, good mobile performance
3. **Realtime Integration**: Swift Protobuf with server-side parsing layer
4. **Update Strategy**: Background updates with incremental GTFS refresh

---

## GTFS Static Specification

### Overview
- **Format**: Collection of CSV text files (.txt) in single ZIP archive
- **License**: Apache 2.0
- **Current Version**: Revised July 9, 2025
- **Official Spec**: https://gtfs.org/documentation/overview/
- **GitHub**: https://github.com/google/transit/blob/master/gtfs/spec/en/reference.md

### Required Files (Core 7)

#### 1. agency.txt
Defines transit agencies operating the services.

**Key Fields**:
- `agency_id` - Unique identifier (required if multiple agencies)
- `agency_name` - Full agency name
- `agency_url` - Agency website
- `agency_timezone` - Timezone (IANA format, e.g., "America/New_York")
- `agency_lang` - Primary language (ISO 639-1)

**Best Practice**: Maintain stable `agency_id` across feed versions

#### 2. routes.txt
Transit routes (e.g., "Bus Line 5", "Blue Line Metro")

**Key Fields**:
- `route_id` - Unique identifier
- `agency_id` - References agency.txt
- `route_short_name` - Public-facing short name (e.g., "5", "Blue")
- `route_long_name` - Full descriptive name
- `route_type` - Mode of transportation:
  - 0: Tram/Light Rail
  - 1: Subway/Metro
  - 2: Rail
  - 3: Bus
  - 4: Ferry
  - 5: Cable Car
  - 6: Gondola
  - 7: Funicular
- `route_color` - Hex color (without #)
- `route_text_color` - Text color for readability

**Best Practice**: Use Mixed Case, not ALL CAPS; branches should use distinct `route_short_name` if marketed separately, otherwise use `trip_headsign`

#### 3. trips.txt
Individual journey instances along a route.

**Key Fields**:
- `trip_id` - Unique identifier
- `route_id` - References routes.txt
- `service_id` - References calendar.txt or calendar_dates.txt
- `trip_headsign` - Destination text shown to passengers
- `direction_id` - 0 or 1 for opposite directions
- `block_id` - Groups trips where vehicle continues between them
- `shape_id` - References shapes.txt (optional)
- `wheelchair_accessible` - 0=unknown, 1=yes, 2=no

**Best Practice**: Don't include route name in headsign; never begin with "To" or "Towards"; for loop routes, use `stop_headsign` to indicate direction changes

#### 4. stops.txt
Physical locations where vehicles stop.

**Key Fields**:
- `stop_id` - Unique identifier
- `stop_name` - Name visible to passengers
- `stop_lat` - Latitude (WGS84)
- `stop_lon` - Longitude (WGS84)
- `location_type` - 0=stop/platform, 1=station, 2=entrance/exit, 3=generic node, 4=boarding area
- `parent_station` - Groups platforms under station
- `wheelchair_boarding` - 0=unknown, 1=accessible, 2=not accessible
- `platform_code` - Platform identifier for passengers
- `stop_timezone` - Overrides agency_timezone if needed

**Best Practice**: Location accuracy within 4 meters; place on correct side of street; maintain persistent `stop_id` across versions

#### 5. stop_times.txt
Arrival/departure times for each stop on each trip.

**Key Fields**:
- `trip_id` - References trips.txt
- `arrival_time` - Time in HH:MM:SS (can exceed 24:00:00)
- `departure_time` - Time in HH:MM:SS
- `stop_id` - References stops.txt
- `stop_sequence` - Order of stops (0-based or 1-based, must increase)
- `pickup_type` - 0=regular, 1=none, 2=phone ahead, 3=coordinate with driver
- `drop_off_type` - Same as pickup_type
- `timepoint` - 0=approximate, 1=exact

**Critical Implementation Details**:
- Times measured from "noon minus 12h" in `agency_timezone` (effectively midnight)
- Service day can exceed 24 hours (e.g., 25:30:00 for 1:30 AM next day)
- Always use `agency_timezone` even for trips crossing timezones
- Times must always increase throughout trip

#### 6. calendar.txt
Regular service schedules (Monday-Sunday patterns).

**Key Fields**:
- `service_id` - Unique identifier
- `monday` through `sunday` - 1=available, 0=not available
- `start_date` - YYYYMMDD format
- `end_date` - YYYYMMDD format

**Best Practice**: Include `service_name` field (non-standard but recommended) for human readability

#### 7. calendar_dates.txt
Service exceptions (holidays, special events).

**Key Fields**:
- `service_id` - References calendar.txt
- `date` - YYYYMMDD format
- `exception_type` - 1=service added, 2=service removed

**Best Practice**: Remove expired services; use GTFS-Realtime for changes within 7 days rather than updating static feed

### Optional Files (15+)

#### shapes.txt
Geographic path taken by vehicles (route visualization).

**Key Fields**:
- `shape_id` - Unique identifier
- `shape_pt_lat` - Point latitude
- `shape_pt_lon` - Point longitude
- `shape_pt_sequence` - Order of points
- `shape_dist_traveled` - Distance from first point (meters)

**Best Practice**: Route alignment within 100m of served stops; remove extraneous points; downsample for mobile apps

**Implementation Notes**:
- One route may have many shapes (different trip patterns)
- Often unnecessarily high resolution
- Can aggregate points into PostGIS LineString for efficient querying

#### frequencies.txt
Headway-based service (frequency rather than fixed schedule).

**Key Fields**:
- `trip_id` - References trips.txt
- `start_time` - Period start (HH:MM:SS)
- `end_time` - Period end
- `headway_secs` - Seconds between departures
- `exact_times` - 0=frequency-based, 1=schedule-based compressed

**Two Service Types**:
1. **Frequency-based** (`exact_times=0`): Operators maintain headways, not specific times; actual stop times ignored except intervals between stops
2. **Schedule-based compressed** (`exact_times=1`): Fixed schedule with consistent headways

**Best Practice**: Set first stop time to 00:00:00 for clarity; avoid `headway_secs` > 1200 (20 min) for frequency-based

#### transfers.txt
Transfer rules between routes/stops.

**Key Fields**:
- `from_stop_id` - Origin stop
- `to_stop_id` - Destination stop
- `transfer_type`:
  - 0: Recommended transfer point
  - 1: Timed transfer (departing vehicle waits)
  - 2: Requires min_transfer_time
  - 3: Not possible
- `min_transfer_time` - Seconds required for transfer

**Best Practice**: Include buffer for schedule variance; MBTA model: `min_transfer_time = min_walk_time + suggested_buffer_time`; typical values: 300s (5 min) for bus, 600s (10 min) for long-distance

**Buffer Strategies**:
- Consider walking distance, schedule reliability, service frequency
- More critical connections need larger buffers
- Some agencies use flat defaults per mode

#### fare_attributes.txt & fare_rules.txt
Fare pricing and application rules.

**fare_attributes.txt**:
- `fare_id` - Unique identifier
- `price` - Fare amount
- `currency_type` - ISO 4217 code
- `payment_method` - 0=on board, 1=before boarding
- `transfers` - Number allowed (empty=unlimited)
- `transfer_duration` - Validity period (seconds)

**fare_rules.txt**:
- `fare_id` - References fare_attributes.txt
- `route_id` - Specific route (optional)
- `origin_id` - Origin zone (optional)
- `destination_id` - Destination zone (optional)
- `contains_id` - Zone that must be passed through (optional)

**Common Patterns**:
1. **Flat fare**: fare_attributes without rules
2. **Route-based**: One rule per route
3. **Zone-based**: Rules match exact zone set traversed
4. **Origin-destination**: Combines origin_id + destination_id

**Best Practice**: If accuracy impossible, represent fare as more expensive to prevent underpayment

**Limitation**: GTFS-Fares v2 proposal addresses limitations of current model

#### pathways.txt & levels.txt
Indoor navigation for complex stations.

**Files**:
- `pathways.txt` - Connections between locations
- `levels.txt` - Floor/level definitions

**Key Concepts**:
- Graph representation: nodes (stops with location_type) + edges (pathways)
- `location_type` in stops.txt:
  - 0: Stop/platform
  - 1: Station (parent)
  - 2: Entrance/exit
  - 3: Generic node
  - 4: Boarding area

**pathways.txt Fields**:
- `pathway_id` - Unique identifier
- `from_stop_id` - Origin node
- `to_stop_id` - Destination node
- `pathway_mode` - 1=walkway, 2=stairs, 3=moving sidewalk, 4=escalator, 5=elevator, 6=fare gate, 7=exit gate
- `is_bidirectional` - 0=one-way, 1=two-way
- `traversal_time` - Seconds required
- `wheelchair_accessible` - 0=unknown, 1=yes, 2=no

**Best Practice**: Exhaustively define all connections within station; not for indoor mapping (use GIS/BIM); for itinerary/accessibility guidance

**Tools**: GTFS Station Builder UI, Transitland Station Editor

### GTFS Extensions
- Translations (multi-language support)
- Attribution (data source credits)
- Feed Info (publisher metadata)
- Google Ticketing Extensions (fare payment integration)
- Locations.geojson (zone boundaries)

---

## GTFS Realtime Specification

### Overview
- **Format**: Protocol Buffers (binary, compact, fast)
- **Purpose**: Live fleet updates complementing static GTFS
- **Protocol**: https://gtfs.org/documentation/realtime/proto/
- **GitHub**: https://github.com/google/transit/blob/master/gtfs-realtime/proto/gtfs-realtime.proto

### Protocol Buffers
- Language/platform-neutral serialization (like XML but smaller, faster, simpler)
- Developed by Google (2008)
- Schema defined in `.proto` file
- Code generation for Java, C++, Python, Swift, etc.

### Message Types

#### 1. Trip Updates
Conveys schedule deviations.

**Use Cases**:
- Delays/early arrivals
- Cancellations
- Route modifications
- Added trips

**Key Fields**:
- `trip_id`, `route_id`, `start_time`, `start_date` - Identifies trip
- `stop_time_update` - Array of updates:
  - `stop_sequence` or `stop_id`
  - `arrival.delay` - Seconds behind/ahead of schedule
  - `departure.delay`
  - `schedule_relationship` - SCHEDULED, SKIPPED, NO_DATA

**Update Frequency**: Whenever new data from Automatic Vehicle Location (AVL) system

#### 2. Service Alerts
Communicates disruptions.

**Use Cases**:
- Stop relocated/closed
- Unexpected incidents
- Network-wide service impacts
- Construction/maintenance

**Key Fields**:
- `informed_entity` - Affected routes/stops/trips
- `cause` - UNKNOWN_CAUSE, TECHNICAL_PROBLEM, STRIKE, DEMONSTRATION, ACCIDENT, HOLIDAY, WEATHER, MAINTENANCE, CONSTRUCTION, etc.
- `effect` - NO_SERVICE, REDUCED_SERVICE, SIGNIFICANT_DELAYS, DETOUR, ADDITIONAL_SERVICE, MODIFIED_SERVICE, STOP_MOVED, etc.
- `header_text` - Brief description (multi-language support)
- `description_text` - Detailed explanation
- `active_period` - Time range(s) when alert applies

#### 3. Vehicle Positions
Current vehicle locations and status.

**Use Cases**:
- Real-time map display
- Crowding information
- Accurate ETAs

**Key Fields**:
- `trip` - Trip descriptor
- `vehicle` - Vehicle descriptor (ID, label, license plate)
- `position` - Latitude, longitude, bearing, speed
- `current_stop_sequence` - Which stop vehicle is at/approaching
- `current_status` - INCOMING_AT, STOPPED_AT, IN_TRANSIT_TO
- `timestamp` - Measurement time
- `congestion_level` - UNKNOWN_CONGESTION_LEVEL, RUNNING_SMOOTHLY, STOP_AND_GO, CONGESTION, SEVERE_CONGESTION
- `occupancy_status` - EMPTY, MANY_SEATS_AVAILABLE, FEW_SEATS_AVAILABLE, STANDING_ROOM_ONLY, CRUSHED_STANDING_ROOM_ONLY, FULL, NOT_ACCEPTING_PASSENGERS

### Integration with Static GTFS

**Matching Realtime to Static**:
- Trip updates/vehicle positions reference `trip_id` from trips.txt
- Service alerts reference `route_id`, `stop_id`, or entire agency
- Timestamps in POSIX time (seconds since Jan 1 1970 UTC)

**Best Practices**:
- Keep static feed valid for 7+ days (ideally 30+)
- Use realtime for short-term changes (<7 days)
- Update feed regularly aligned with AVL data
- Include all three message types for comprehensive service

**Data Flow**:
1. Parse static GTFS into database
2. Fetch realtime protobuf feeds (HTTP GET)
3. Decode protobuf messages
4. Match to static data via IDs
5. Apply updates to schedule/display

---

## GTFS Best Practices

### Calendar & Service Handling

**calendar.txt vs calendar_dates.txt**:
- Use `calendar.txt` for regular weekly patterns
- Use `calendar_dates.txt` for exceptions (holidays, special events)
- Can use `calendar_dates.txt` exclusively for irregular services
- Remove expired calendars from feed

**Service Day Definition**:
- May exceed 24:00:00 (e.g., service starts one day, ends next)
- Measured from "noon minus 12h" in agency_timezone
- Varies by agency (not always calendar day)
- Support time ranges: 00:00-24:00, 01:00-25:00, 02:00-26:00, even 00:00-27:00

**Daylight Saving Time**:
- Model trips during DST switch to previous day reference point
- Keep departure times consistent with vehicle travel time
- Consumer algorithms auto-calculate correct display times
- Always specify times in `agency_timezone`

### Dataset Publishing

**Versioning**:
- Maintain persistent IDs across versions (`stop_id`, `route_id`, `agency_id`, `trip_id`)
- Publish at stable, permanent, public URL
- Configure HTTP Last-Modified headers correctly
- Merged datasets: Include current + upcoming service in single file
- Valid for 7+ days minimum, 30+ days recommended

**URL Best Practice**: https://agency.org/gtfs/gtfs.zip (not dated/versioned URLs)

### Text Formatting

**Casing**:
- Use Mixed Case for customer-facing fields
- NEVER use ALL CAPS
- Exception: Official place names that are actually capitalized

**Headsigns**:
- Don't include route name (it's shown separately)
- Never begin with "To" or "Towards"
- For branches: Use distinct `trip_headsign` if on same route
- Loop routes: Include first/last stop twice in `stop_times.txt`; use `stop_headsign` for direction changes
- Lasso routes: Use `stop_headsign` on shared segments

**Abbreviations**:
- Avoid unless official place names
- Spell out street directions (North, not N)

### Location Accuracy

**Stops**:
- Accuracy within 4 meters of actual boarding position
- Correct side of street
- For rail: Center of platform
- Use `parent_station` to group platforms

**Shapes**:
- Route alignment within 100 meters of served stops
- Remove extraneous points
- Follow actual vehicle path, not straight lines between stops

### Frequency vs Schedule-Based

**Frequency-based** (`exact_times=0`):
- Use when operators maintain headways, not fixed times
- Set first stop `arrival_time` to 00:00:00
- Only travel time intervals between stops matter
- Avoid `headway_secs` > 20 minutes (bad UX)

**Schedule-based** (`exact_times=1`):
- Use for compressed representation of consistent schedules
- Actual times matter: first departure + (n × headway)

**Block IDs**: Can be provided for frequency-based trips if vehicle continues

### Accessibility

**wheelchair_boarding** (stops.txt):
- 1 = Accessible from street AND can board vehicles
- 2 = Not accessible
- 0 or empty = Unknown
- Applies to both stop access and vehicle boarding capability

**wheelchair_accessible** (trips.txt):
- 1 = Vehicle can accommodate wheelchair
- 2 = Cannot accommodate
- 0 = Unknown
- Should have valid value for every trip

**Pathways**: If any pathways defined, must exhaustively define all station connections

### Common Pitfalls

1. **Stop times not increasing**: All times must increase throughout trip
2. **Timezone confusion**: Always use `agency_timezone` in `stop_times.txt`, even for cross-timezone trips
3. **Calendar expiry**: Old services bloat feed; remove them
4. **Missing shapes**: Improves UX significantly; worth the effort
5. **Inconsistent IDs**: Breaking ID changes across versions breaks consumer apps
6. **ALL CAPS TEXT**: Looks unprofessional; use Mixed Case
7. **Inaccurate fare modeling**: If unsure, err on higher fare to prevent underpayment
8. **Headsign route names**: Redundant and clutters display

---

## Transit Routing Algorithms

### Overview

Traditional graph algorithms (Dijkstra, A*) too slow for large transit networks. Modern algorithms designed for:
- **Multi-criteria optimization**: Minimize arrival time AND transfers simultaneously
- **Large-scale networks**: Nationwide timetables with thousands of routes
- **Dynamic updates**: Incorporate realtime delays

### Algorithm Comparison

| Algorithm | Preprocessing | Query Time | Memory | Multi-Criteria | Notes |
|-----------|---------------|------------|--------|----------------|-------|
| **Dijkstra** | None | Slow (baseline) | Low | No | Time-expanded graph; too slow for large networks |
| **A*** | None | Medium | Low | No | Heuristic-guided; still too slow for transit |
| **CSA** | None | Medium | Low | Yes | Simple, scans connections array; degrades on large networks |
| **RAPTOR** | None | Fast | Medium | Yes | Round-based; good mobile performance; Pareto-optimal results |
| **TBTR** | 30s-2min | Very Fast (70ms) | Medium | Yes | Precalculates transfers; excellent for repeated queries |
| **Transfer Patterns** | Heavy | Very Fast | High | Varies | Fastest but requires significant preprocessing |

### RAPTOR (Round-based Public Transit Optimized Router)

**Recommended for iOS App**

#### How It Works

**Core Concept**: Organizes search into rounds, where each round = one additional transfer.

**Algorithm Flow**:
1. **Round 0**: Mark initial stop with departure time
2. **Round 1**: Explore all routes from marked stops (direct trips, 0 transfers)
3. **Round 2**: Apply footpaths, explore routes again (1 transfer)
4. **Round n**: Continue until no improvements found

**Data Structures**:
- **Routes**: Grouped trips by path
- **Stops**: Track earliest arrival time per round
- **Marked stops**: Stops with improved arrival times in previous round

**Example**:
```
Origin: Stop A at 08:00
Destination: Stop D

Round 1 (0 transfers):
- Route 1 from Stop A → reaches Stop B at 08:15
- Route 2 from Stop A → reaches Stop C at 08:20

Round 2 (1 transfer):
- Walk from Stop B to Stop C (2 min) → 08:17
- Route 3 from Stop C → reaches Stop D at 08:30 (via route starting 08:20)
- Route 3 from Stop C → reaches Stop D at 08:28 (via walk+transfer at 08:17)

Best result: Stop D at 08:28 with 1 transfer
```

#### Key Features

**Multi-Criteria**: Returns Pareto-optimal journeys (each round improves arrival time OR transfer count)

**No Preprocessing**: Can handle realtime updates immediately; just update arrival/departure times

**Footpaths**: Apply previous-round arrival times when calculating walk transfers (not current round)

**Range Queries**: Extend to McRAPTOR for full departure time ranges (e.g., all options 8am-9am)

#### Performance Characteristics

- **Query Time**: Milliseconds to seconds depending on network size
- **Memory**: O(routes × stops)
- **Mobile Suitability**: Good - no preprocessing, reasonable memory, fast enough for on-device
- **Comparison**: Faster than CSA, slower than TBTR, but much simpler than Transfer Patterns

#### Implementation Considerations

**Interchange Time**: Must consistently apply minimum transfer time at stops

**Result Extraction**: Store trip-boarding-exit triples for each stop per round, then backtrack from destination

**Footpath Handling**:
- Critical bug: Use arrival times from previous round, not current
- Prevents shortcuts through impossible transfers

**Optimization**:
- rRAPTOR (partitioned) for larger networks
- HypRAPTOR (hyperpartitioned) for nationwide scale
- One-To-Many variants for location-based queries

### Connection Scan Algorithm (CSA)

#### How It Works

**Core Concept**: Scan all connections (departure-arrival pairs) once in chronological order.

**Data Model**:
```
Connection = (departure_stop, arrival_stop, departure_time, arrival_time)
```

**Algorithm**:
```
For each connection c in chronological order:
  If arrival_time[c.departure_stop] < c.departure_time:
    If c.arrival_time < arrival_time[c.arrival_stop]:
      arrival_time[c.arrival_stop] = c.arrival_time
      in_connection[c.arrival_stop] = c
```

**Backtracking**: Follow `in_connection` from destination to origin to reconstruct journey

#### Performance

- **Query Time**: Comparable to RAPTOR on small/medium networks; degrades on large networks
- **Advantage**: Extremely simple implementation
- **Disadvantage**: Must scan ALL connections before terminating; includes unnecessary transfers
- **Mobile**: Suitable for city-scale, questionable for nationwide

#### Variants

- **One-To-Many CSA**: Improved for location queries
- **Multilevel Overlay CSA**: Nationwide networks (trains + buses)
- **Profile CSA**: Range queries (all departures in time window)

### Trip-Based Public Transit Routing (TBTR)

#### How It Works

**Core Concept**: Precalculate useful transfers between trips; query as breadth-first search on trip graph.

**Preprocessing**:
- Nodes = Trips
- Edges = Transfers between trips
- Calculates which trip transfers are useful
- **Time**: 30s for city (London), 2 min for country (Germany, 8-core)

**Query**:
- Breadth-first search across trip graph
- Considers both arrival time and transfer count (bicriteria)
- **Time**: ~70ms for 24-hour profile on metropolitan network

#### Performance

- **Preprocessing**: Moderate (30s-2min)
- **Query Time**: Very fast (70ms for full profile)
- **Memory**: Medium-high (stores precalculated transfers)
- **Mobile**: Preprocessing on server, query results can be cached/downloaded

#### Advanced Variants

- **rTBTR**: Partitioned variant for improved query times
- **HypTBTR**: Hypergraph-based, 23-37% faster than TBTR
- **One-To-Many rTBTR**: 90-95% speedup for location queries
- **MHypTBTR**: Multilevel, 53% faster preprocessing
- **Arc-Flag TB**: Two orders of magnitude speedup, <1ms queries on countrywide networks

**Best Use Case**: Server-side routing with high query volume; too much preprocessing for on-device

### Transfer Patterns

#### How It Works

**Core Concept**: Precompute all optimal transfer patterns between stop pairs.

**Preprocessing**:
- Heavy computation (hours)
- Large storage (GB of patterns)

**Query**:
- Lookup: Fastest possible
- Essentially table lookup + time adjustments

**Performance**:
- **Preprocessing**: Very heavy
- **Query Time**: Extremely fast
- **Memory**: Very high
- **Mobile**: Preprocessing prohibitive; patterns could be downloaded but storage requirements high

**Use Case**: Large-scale commercial routing services with server infrastructure

### Recommendations for iOS App

**Primary: RAPTOR**
- No preprocessing: Can update with realtime data instantly
- Good performance: Fast enough for on-device (<1s queries)
- Pareto-optimal: Returns best options per transfer count
- Reasonable memory: Fits on mobile device
- Simple to implement: Clearer than TBTR/Transfer Patterns

**Alternative: CSA**
- Even simpler implementation
- Good for single-city app
- Degrades on multi-city/regional networks

**Server-Side Option: TBTR**
- Precompute on server
- Serve results via API
- Best query performance
- Allows caching common queries

**Hybrid Approach**:
1. RAPTOR on-device for quick queries
2. TBTR on server for complex/range queries
3. Cache TBTR results locally
4. Fall back to RAPTOR if offline

---

## Multi-Modal Routing

### Concept

Combining walking, cycling, bus, train, ferry, etc. in single journey.

### Transfer Types

**1. In-Seat Transfers**:
- Same vehicle continues on different route
- No physical transfer
- Modeled with `block_id` in trips.txt

**2. Timed Transfers**:
- Coordinated schedules
- Departing vehicle waits for arriving vehicle
- `transfer_type=1` in transfers.txt

**3. Walk Transfers**:
- Physical movement between stops/platforms
- `min_transfer_time` in transfers.txt
- Footpaths in routing algorithm

**4. Station Transfers**:
- Complex multi-level stations
- Modeled with pathways.txt
- Accessibility considerations

### Transfer Handling Strategies

**Minimum Transfer Time**:
```
min_transfer_time = min_walk_time + suggested_buffer_time
```

**Components**:
- **Walking distance**: Physical distance / average walk speed (1.4 m/s typical)
- **Vertical movement**: Stairs/escalators/elevators
- **Wayfinding**: Time to navigate complex stations
- **Schedule variance buffer**: Account for delays
- **Service frequency**: Lower frequency → larger buffer

**Typical Values**:
- Bus-to-bus (same stop): 0-120s
- Bus-to-bus (different stops): 300s (5 min)
- Rail-to-rail (platform change): 180-300s (3-5 min)
- Long-distance coach: 600s+ (10+ min)
- Inter-city rail: 600-900s (10-15 min)

### Connection Intelligence

**1. Transfer Reliability**:
- Consider on-time performance of connecting services
- Increase buffer for unreliable routes
- Real-time: Skip questionable connections if delay detected

**2. Time-of-Day**:
- Off-peak: Longer buffers (lower frequency makes missed connection more costly)
- Peak: Shorter acceptable (next vehicle soon)

**3. Station Complexity**:
- Simple stop: Minimal buffer
- Complex station: Account for walking, wayfinding
- Multi-level: Add vertical movement time

**4. Accessibility**:
- Wheelchair users: Longer transfer times
- Check `wheelchair_boarding` and pathway `wheelchair_accessible`
- Escalator vs stairs vs elevator

### Algorithm Extensions for Multi-Modal

**RAPTOR Multi-Modal**:
- Include footpaths between nearby stops
- Model bike/car as "routes" with specific characteristics
- Different "mode" per round

**Transfer Costs**:
- Not just time: Transfers have inherent penalty
- Users prefer fewer transfers even if slightly longer
- Typical: 2-5 minute penalty per transfer beyond time

**Multi-Criteria**:
- Minimize: Travel time, transfers, walking distance, cost
- Pareto frontier: All non-dominated solutions
- User preferences: Weight criteria differently

### Implementation Pattern

**Data Preparation**:
1. Load GTFS static data
2. Build stop proximity index (spatial search for nearby stops)
3. Calculate walk times between nearby stops
4. Parse transfers.txt for explicit transfer rules
5. Load pathways.txt for station internals

**Query Flow**:
1. Find nearby stops from origin location (walking distance)
2. Run RAPTOR/CSA with all nearby origin stops
3. Include walk transfers between rounds
4. Apply transfer time penalties
5. Find routes to nearby stops of destination
6. Add final walking leg
7. Return Pareto-optimal journeys

**Data Structures**:
```
FootPath:
  from_stop_id
  to_stop_id
  walk_time_seconds
  distance_meters
  wheelchair_accessible

NearbyStops:
  location (lat/lon)
  stops: [
    { stop_id, walk_time, distance }
  ]
```

---

## Implementation Guidance

### Database Schema Patterns

#### PostgreSQL + PostGIS (Server-Side)

**Tools**:
- `gtfs-via-postgres`: Creates tables + helpful views
- `gtfsdb`: SQLAlchemy ORM with PostGIS support
- `gtfs-schema`: Pre-built schemas for worldwide feeds

**Schema Design**:

```sql
-- Core tables (mirror GTFS files)
CREATE TABLE agency (...);
CREATE TABLE routes (...);
CREATE TABLE trips (...);
CREATE TABLE stops (
  stop_id TEXT PRIMARY KEY,
  stop_lat NUMERIC,
  stop_lon NUMERIC,
  stop_loc GEOGRAPHY(Point, 4326)  -- PostGIS
);
CREATE TABLE stop_times (...);
CREATE TABLE calendar (...);
CREATE TABLE calendar_dates (...);
CREATE TABLE shapes (
  shape_id TEXT,
  shape_pt_sequence INTEGER,
  shape_pt_lat NUMERIC,
  shape_pt_lon NUMERIC,
  shape_geom GEOGRAPHY(Point, 4326)
);

-- Foreign keys
ALTER TABLE routes ADD FOREIGN KEY (agency_id) REFERENCES agency(agency_id);
ALTER TABLE trips ADD FOREIGN KEY (route_id) REFERENCES routes(route_id);
ALTER TABLE stop_times ADD FOREIGN KEY (trip_id) REFERENCES trips(trip_id);
ALTER TABLE stop_times ADD FOREIGN KEY (stop_id) REFERENCES stops(stop_id);

-- Spatial indexes
CREATE INDEX idx_stops_loc ON stops USING GIST (stop_loc);
CREATE INDEX idx_shapes_geom ON shapes USING GIST (shape_geom);

-- Helpful views
CREATE VIEW service_days AS
  -- Applies calendar_dates to calendar
  -- Returns (service_id, date) for all operating days
  ...;

CREATE VIEW arrivals_departures AS
  -- Combines stop_times, trips, calendar
  -- Returns actual arrival/departure times for each stop
  ...;

CREATE VIEW connections AS
  -- Pairs of (departure, arrival) for routing
  SELECT
    st1.trip_id,
    st1.stop_id as from_stop,
    st2.stop_id as to_stop,
    st1.departure_time as departure,
    st2.arrival_time as arrival
  FROM stop_times st1
  JOIN stop_times st2 ON st1.trip_id = st2.trip_id
    AND st2.stop_sequence = st1.stop_sequence + 1;

CREATE VIEW shapes_aggregated AS
  -- Aggregates shape points into LineStrings
  SELECT
    shape_id,
    ST_MakeLine(shape_geom ORDER BY shape_pt_sequence) as geom
  FROM shapes
  GROUP BY shape_id;
```

**Optimization**:
- Composite indexes on `(trip_id, stop_sequence)`, `(stop_id, arrival_time)`
- Partial indexes for active service only
- Materialized views for expensive queries
- Partitioning by date for large systems

#### SQLite (Mobile App)

**Critical Optimizations for iOS**:

1. **Integer Identifiers**:
```sql
-- Don't do this (strings):
CREATE TABLE stops (
  stop_id TEXT PRIMARY KEY,
  ...
);

-- Do this (integers):
CREATE TABLE stops (
  id INTEGER PRIMARY KEY,
  stop_id TEXT UNIQUE,  -- Keep original for reference
  ...
);

CREATE TABLE stop_times (
  trip_internal_id INTEGER,
  stop_internal_id INTEGER,
  ...
  FOREIGN KEY (trip_internal_id) REFERENCES trips(id),
  FOREIGN KEY (stop_internal_id) REFERENCES stops(id)
);
```

**Benefit**: 50-70% size reduction, much faster joins

2. **Integer Times**:
```sql
-- Store times as seconds since midnight
CREATE TABLE stop_times (
  arrival_time INTEGER,  -- seconds since midnight
  departure_time INTEGER,
  ...
);

-- Handle times > 24:00:00:
-- 25:30:00 → (25 * 3600) + (30 * 60) = 91800 seconds
```

**Benefit**: Smaller storage, faster comparisons, easier math

3. **Denormalization**:
```sql
-- Instead of JOIN trips → routes → agency for every query
CREATE TABLE trips (
  id INTEGER PRIMARY KEY,
  route_internal_id INTEGER,
  route_short_name TEXT,  -- Denormalized
  route_color TEXT,       -- Denormalized
  ...
);
```

**Trade-off**: Larger database, faster queries (no joins on critical path)

4. **Exclude Unused Data**:
- If not showing detailed routes: Skip shapes.txt (can be 50%+ of feed size)
- If not handling fares: Skip fare_attributes/fare_rules
- If not showing translations: Skip translations.txt

5. **Pre-built Database**:
```
Bundle pre-processed .sqlite file in app
→ No startup time (parsing GTFS → SQLite)
→ Immediate queries
```

**Update Strategy**:
- Check for new GTFS version (HTTP HEAD, Last-Modified)
- Download new .zip in background
- Process to new .sqlite file
- Atomic swap when complete
- Keep old until new validated

6. **Indexes**:
```sql
-- Critical for query performance
CREATE INDEX idx_stop_times_trip ON stop_times(trip_internal_id, stop_sequence);
CREATE INDEX idx_stop_times_stop ON stop_times(stop_internal_id);
CREATE INDEX idx_trips_route ON trips(route_internal_id);
CREATE INDEX idx_trips_service ON trips(service_id);

-- For spatial queries (if using SpatiaLite extension)
SELECT CreateSpatialIndex('stops', 'geom');
```

**Tools**:
- `gtfs2sqlite`: Converts GTFS → SQLite
- `GTFSImporter`: iOS/Android SQLite importer
- `mobsql`: Mobility DB automatic ingestion

### Service Day Calculations

**Challenge**: Service days don't align with calendar days due to:
- Times exceeding 24:00:00
- Timezone complexities
- Daylight saving transitions

#### Implementation Pattern

**1. Determine Operating Days**:
```sql
-- For a specific date (e.g., 2025-10-30)
SELECT service_id FROM calendar
WHERE monday = 1  -- If Oct 30 is Monday
  AND start_date <= '20251030'
  AND end_date >= '20251030'
UNION
SELECT service_id FROM calendar_dates
WHERE date = '20251030' AND exception_type = 1
EXCEPT
SELECT service_id FROM calendar_dates
WHERE date = '20251030' AND exception_type = 2;
```

**2. Convert Times**:
```python
def gtfs_time_to_seconds(time_str):
    """Convert HH:MM:SS to seconds since midnight.
    Handles times > 24:00:00."""
    h, m, s = map(int, time_str.split(':'))
    return h * 3600 + m * 60 + s

def seconds_to_datetime(date_str, seconds_since_midnight, timezone_str):
    """Convert GTFS time to actual datetime."""
    import datetime
    import pytz

    # Parse service date
    service_date = datetime.datetime.strptime(date_str, '%Y%m%d')

    # Add seconds (may overflow to next day)
    dt = service_date + datetime.timedelta(seconds=seconds_since_midnight)

    # Apply timezone
    tz = pytz.timezone(timezone_str)
    dt_localized = tz.localize(dt)

    return dt_localized

# Example:
# Service date: 2025-10-30
# Departure time: 25:30:00
# Timezone: America/New_York
# Result: 2025-10-31 01:30:00 EDT
```

**3. Query for Specific Time**:
```sql
-- Find trips departing Stop A between 8:00 and 9:00 on 2025-10-30
SELECT DISTINCT t.*
FROM trips t
JOIN stop_times st ON t.id = st.trip_internal_id
WHERE st.stop_internal_id = (SELECT id FROM stops WHERE stop_id = 'A')
  AND st.departure_time >= 28800  -- 08:00:00
  AND st.departure_time < 32400   -- 09:00:00
  AND t.service_id IN (
    -- Active services on 2025-10-30
    ...
  );
```

**4. Handle Daylight Saving**:
- GTFS times always in standard agency_timezone
- DST transitions: Service day reference point shifts
- Algorithm auto-adjusts; no special handling needed in most cases
- Edge case: 2am-3am during "spring forward" (hour doesn't exist)
  - Model as previous day if needed
  - Ensure travel time consistency

### Timezone Complexities

**Rule**: ALL times in stop_times.txt use `agency_timezone`, even for trips crossing timezones.

**Example**:
```
Agency: Amtrak (America/New_York)
Trip: Boston → Chicago (crosses 1 timezone)

Stop A (Boston): Depart 08:00 (Eastern)
Stop B (Buffalo): Arrive 12:00 (still measured in Eastern)
Stop C (Cleveland): Arrive 15:00 (still measured in Eastern, even though Cleveland is Central)
Stop D (Chicago): Arrive 18:00 (measured in Eastern; local time is 17:00 Central)
```

**Why**: Ensures times always increase throughout trip.

**Display to User**:
```python
def display_time(stop_id, gtfs_time_seconds, service_date, agency_timezone):
    """Convert GTFS time to local time at stop."""
    # Get stop's local timezone (if stop_timezone provided)
    stop_tz = get_stop_timezone(stop_id) or agency_timezone

    # Convert GTFS time (agency TZ) to UTC
    dt_agency = seconds_to_datetime(service_date, gtfs_time_seconds, agency_timezone)
    dt_utc = dt_agency.astimezone(pytz.UTC)

    # Convert to stop's local time
    dt_local = dt_utc.astimezone(pytz.timezone(stop_tz))

    return dt_local
```

### Real-Time Integration Patterns

#### Pattern 1: In-Memory Update

**Flow**:
1. Load static GTFS into database/memory
2. Periodically fetch GTFS-RT protobuf (30-60s intervals)
3. Parse protobuf messages
4. Apply updates to in-memory schedule
5. Run routing on updated schedule

**Advantages**:
- Simple
- Always current
- No database writes

**Disadvantages**:
- Lost on app restart
- High memory if caching many updates

**Code (Swift)**:
```swift
import SwiftProtobuf

struct RealtimeUpdater {
    var tripUpdates: [String: TripUpdate] = [:]  // trip_id → update
    var vehiclePositions: [String: VehiclePosition] = [:]

    func fetchAndApply(url: URL) async throws {
        let data = try await URLSession.shared.data(from: url).0
        let feed = try TransitRealtime_FeedMessage(serializedData: data)

        for entity in feed.entity {
            if entity.hasTripUpdate {
                tripUpdates[entity.tripUpdate.trip.tripID] = entity.tripUpdate
            }
            if entity.hasVehicle {
                vehiclePositions[entity.vehicle.trip.tripID] = entity.vehicle
            }
        }
    }

    func getAdjustedArrival(tripId: String, stopSequence: Int, scheduledArrival: Int) -> Int {
        guard let update = tripUpdates[tripId],
              let stopUpdate = update.stopTimeUpdate.first(where: { $0.stopSequence == stopSequence }),
              stopUpdate.hasArrival else {
            return scheduledArrival
        }
        return scheduledArrival + Int(stopUpdate.arrival.delay)
    }
}
```

#### Pattern 2: Database Update

**Flow**:
1. Static GTFS in SQLite
2. Fetch GTFS-RT protobuf
3. Write updates to separate tables
4. JOIN static + realtime in queries

**Schema**:
```sql
CREATE TABLE realtime_trip_updates (
  trip_id TEXT,
  stop_sequence INTEGER,
  arrival_delay INTEGER,
  departure_delay INTEGER,
  schedule_relationship TEXT,
  timestamp INTEGER,
  PRIMARY KEY (trip_id, stop_sequence)
);

CREATE TABLE realtime_vehicle_positions (
  vehicle_id TEXT PRIMARY KEY,
  trip_id TEXT,
  latitude REAL,
  longitude REAL,
  bearing REAL,
  timestamp INTEGER
);

-- Query with realtime
SELECT
  st.stop_id,
  st.arrival_time + COALESCE(rtu.arrival_delay, 0) as actual_arrival
FROM stop_times st
LEFT JOIN realtime_trip_updates rtu
  ON st.trip_id = rtu.trip_id AND st.stop_sequence = rtu.stop_sequence
WHERE st.trip_id = ?;
```

**Advantages**:
- Persists across restarts
- Can query historical RT data
- Works with existing SQL queries

**Disadvantages**:
- Database writes (performance)
- Need cleanup of old data

#### Pattern 3: Server-Side Processing

**Flow**:
1. Server fetches GTFS-RT feeds
2. Server parses protobuf
3. Server exposes simplified JSON API
4. iOS app fetches JSON
5. Apply to in-memory schedule

**Advantages**:
- Offload protobuf parsing
- Server can aggregate multiple feeds
- Simpler iOS code
- Can add value (predictions, filtering)

**Disadvantages**:
- Requires server infrastructure
- Network dependency
- Latency

**API Example**:
```json
GET /api/trips/trip_123/realtime

{
  "trip_id": "trip_123",
  "vehicle": {
    "id": "vehicle_456",
    "lat": 42.3601,
    "lon": -71.0589,
    "bearing": 180,
    "speed": 12.5,
    "timestamp": 1730303400
  },
  "stop_updates": [
    {
      "stop_id": "stop_A",
      "stop_sequence": 5,
      "arrival_delay": 120,
      "departure_delay": 90,
      "relationship": "SCHEDULED"
    }
  ]
}
```

### Query Optimization Strategies

**1. Index Everything Used in WHERE/JOIN**:
```sql
-- Slow:
SELECT * FROM stop_times WHERE trip_id = 'ABC' ORDER BY stop_sequence;

-- Fast (with index):
CREATE INDEX idx_st_trip_seq ON stop_times(trip_id, stop_sequence);
```

**2. Use Covering Indexes**:
```sql
-- Query only needs trip_id, stop_id, arrival_time
CREATE INDEX idx_st_covering ON stop_times(trip_id, stop_sequence, stop_id, arrival_time);
-- Now query doesn't need to access table, just index
```

**3. Limit Result Sets**:
```sql
-- Don't fetch all trips, filter early
SELECT t.* FROM trips t
WHERE t.service_id IN (...)  -- Active today
  AND t.route_id = ?
LIMIT 50;
```

**4. Prepared Statements**:
```swift
let stmt = try db.prepare(
    "SELECT * FROM stop_times WHERE trip_id = ? ORDER BY stop_sequence"
)
// Reuse for many queries
```

**5. Spatial Queries (Nearby Stops)**:
```sql
-- With SpatiaLite or manual calculation
SELECT
  stop_id,
  (6371 * acos(cos(radians(?1)) * cos(radians(stop_lat)) *
   cos(radians(stop_lon) - radians(?2)) + sin(radians(?1)) *
   sin(radians(stop_lat)))) AS distance_km
FROM stops
WHERE stop_lat BETWEEN ?1 - 0.01 AND ?1 + 0.01  -- Bounding box
  AND stop_lon BETWEEN ?2 - 0.01 AND ?2 + 0.01
HAVING distance_km < 0.5
ORDER BY distance_km
LIMIT 10;
```

**6. Denormalize for Read Performance**:
```sql
-- Instead of 3 JOINs every query
SELECT
  st.arrival_time,
  s.stop_name,
  t.trip_headsign,
  r.route_short_name
FROM stop_times st
JOIN stops s ON st.stop_id = s.stop_id
JOIN trips t ON st.trip_id = t.trip_id
JOIN routes r ON t.route_id = r.route_id;

-- Store trip_headsign, route_short_name in stop_times table
-- No JOINs needed
```

**7. Cache Common Queries**:
- "Nearby stops" for fixed locations (home, work)
- Active service IDs for today
- Popular routes

---

## iOS-Specific Recommendations

### Architecture

**Layer 1: Data Layer**
- SQLite database (bundled + updatable)
- GTFS-RT protobuf parser
- Update manager

**Layer 2: Routing Engine**
- RAPTOR implementation in Swift
- Multi-modal support (walk + transit)
- Realtime-aware

**Layer 3: Presentation**
- MapKit for maps
- List views for schedules
- Realtime updates via Combine

### Libraries & Tools

**GTFS Parsing**:
- `emma-k-alexandra/GTFS`: Swift structures for GTFS & GTFS-RT
- `richwolf/transit`: Swift library for GTFS static datasets
- Note: GTFS initialization slow; do server-side or background processing

**Protobuf**:
- `apple/swift-protobuf`: Official Apple library
- Generate Swift classes: `protoc --swift_out=. gtfs-realtime.proto`

**Database**:
- SQLite.swift: Type-safe SQLite wrapper
- GRDB: Advanced SQLite toolkit
- SpatiaLite: If spatial queries needed

**Networking**:
- URLSession for GTFS-RT fetches
- Background URLSession for feed updates

### Performance Tips

**1. Preprocess on Server**:
- Parse GTFS → SQLite on server
- Download .sqlite file (smaller than .zip)
- Immediate startup

**2. Incremental Updates**:
- Don't re-download entire feed daily
- Diff changes, apply incrementally
- Only full refresh when major version change

**3. Background Processing**:
```swift
import BackgroundTasks

func scheduleGTFSUpdate() {
    let request = BGProcessingTaskRequest(identifier: "com.app.gtfs-update")
    request.requiresNetworkConnectivity = true
    try? BGTaskScheduler.shared.submit(request)
}
```

**4. Lazy Loading**:
- Don't load entire database into memory
- Fetch trips/stops on-demand
- Cache recent queries

**5. Spatial Indexing**:
- Use R-tree for stops (SpatiaLite or custom)
- Quick "nearby stops" queries
- Critical for user location → transit

**6. Memory Management**:
- GTFS data can be large (100MB+)
- Use autoreleasepool in tight loops
- Monitor memory, purge caches under pressure

### Data Update Strategy

**Scenario 1: Daily/Weekly Updates (Small Changes)**
1. Background task checks for new GTFS version
2. Download new .zip
3. Diff with current version (compare checksums)
4. Apply changes incrementally to SQLite
5. Swap databases when complete

**Scenario 2: Major Changes (New Routes, Schedule Overhaul)**
1. Full re-download and re-process
2. Prepare new .sqlite in temporary location
3. Validate (ensure queries work)
4. Atomic swap (rename files)
5. Delete old database

**Scenario 3: Realtime Updates (Continuous)**
1. Every 30-60s: Fetch GTFS-RT protobuf
2. Parse in background queue
3. Update in-memory structures
4. Notify UI via Combine/NotificationCenter
5. Don't persist (ephemeral data)

### User Experience

**Loading States**:
- Show skeleton/placeholder while routing
- Target: <1s for simple queries, <3s for complex

**Offline Support**:
- Bundled GTFS for initial use
- Cached routes
- Graceful degradation (no realtime)

**Accessibility**:
- VoiceOver for `wheelchair_accessible` routes
- Filter by accessibility in UI
- Show accessible transfer paths

**Localization**:
- Use GTFS translations.txt if available
- Fall back to system language
- Time/date formatting per locale

---

## Code Examples

### RAPTOR Implementation (Swift Pseudocode)

```swift
struct Route {
    let id: String
    let stops: [StopTime]  // Ordered stop times
}

struct StopTime {
    let stopId: String
    let arrivalTime: Int  // Seconds since midnight
    let departureTime: Int
}

struct Journey {
    let arrivalTime: Int
    let transfers: Int
    let legs: [Leg]
}

struct Leg {
    let route: Route
    let fromStop: String
    let toStop: String
    let boardTime: Int
    let alightTime: Int
}

class RAPTOR {
    let routes: [Route]
    let stops: Set<String>
    let routesByStop: [String: [Route]]  // Stop → routes serving it

    func search(from: String, to: String, departureTime: Int, maxTransfers: Int = 5) -> [Journey] {
        var bestArrivalTime: [String: [Int]] = [:]  // Stop → arrival time per round
        var markedStops: Set<String> = [from]
        var journeys: [Journey] = []

        // Initialize
        for stop in stops {
            bestArrivalTime[stop] = Array(repeating: Int.max, count: maxTransfers + 1)
        }
        bestArrivalTime[from]![0] = departureTime

        // Rounds (k = number of transfers)
        for k in 0...maxTransfers {
            var markedStopsNextRound: Set<String> = []

            // Scan routes
            for route in routes where route.stops.contains(where: { markedStops.contains($0.stopId) }) {
                var boarded = false
                var boardTime = 0
                var boardStopIdx = 0

                for (idx, stopTime) in route.stops.enumerated() {
                    // Can we board here?
                    if markedStops.contains(stopTime.stopId) &&
                       stopTime.departureTime >= bestArrivalTime[stopTime.stopId]![k] {
                        if !boarded || stopTime.departureTime < boardTime {
                            boarded = true
                            boardTime = stopTime.departureTime
                            boardStopIdx = idx
                        }
                    }

                    // Can we alight here?
                    if boarded && stopTime.arrivalTime < bestArrivalTime[stopTime.stopId]![k + 1] {
                        bestArrivalTime[stopTime.stopId]![k + 1] = stopTime.arrivalTime
                        markedStopsNextRound.insert(stopTime.stopId)

                        // Track journey
                        if stopTime.stopId == to {
                            // Construct journey...
                        }
                    }
                }
            }

            // Apply footpaths (walk transfers)
            for stop in markedStopsNextRound {
                for (nearbyStop, walkTime) in getFootpaths(stop) {
                    let arrivalViaWalk = bestArrivalTime[stop]![k + 1] + walkTime
                    if arrivalViaWalk < bestArrivalTime[nearbyStop]![k + 1] {
                        bestArrivalTime[nearbyStop]![k + 1] = arrivalViaWalk
                        markedStopsNextRound.insert(nearbyStop)
                    }
                }
            }

            markedStops = markedStopsNextRound

            if markedStops.isEmpty {
                break  // No improvements possible
            }
        }

        // Extract Pareto-optimal journeys
        for k in 0...maxTransfers {
            if let arrival = bestArrivalTime[to]?[k], arrival < Int.max {
                // Reconstruct journey from metadata (omitted for brevity)
                // journeys.append(reconstructedJourney)
            }
        }

        return journeys
    }

    func getFootpaths(_ stopId: String) -> [(String, Int)] {
        // Returns nearby stops and walk times
        // Could use spatial index, transfers.txt, or simple distance calc
        return []
    }
}
```

### SQLite Query Patterns (Swift)

```swift
import SQLite

let db = try Connection("path/to/gtfs.sqlite")

// Find active services for a date
func activeServices(for date: Date) -> [String] {
    let calendar = Table("calendar")
    let serviceId = Expression<String>("service_id")
    let monday = Expression<Int>("monday")
    let startDate = Expression<String>("start_date")
    let endDate = Expression<String>("end_date")

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMdd"
    let dateStr = dateFormatter.string(from: date)
    let weekday = Calendar.current.component(.weekday, from: date)  // 1=Sun, 2=Mon, ...

    var services: [String] = []

    // From calendar.txt
    let query = calendar
        .select(serviceId)
        .filter(startDate <= dateStr && endDate >= dateStr)
    // Filter by weekday (simplified; need to check correct weekday column)

    for row in try! db.prepare(query) {
        services.append(row[serviceId])
    }

    // TODO: Apply calendar_dates.txt additions/exceptions

    return services
}

// Find next departures from a stop
func nextDepartures(stopId: String, departureTime: Int, limit: Int = 10) -> [(tripId: String, routeName: String, headsign: String, time: Int)] {
    let stopTimes = Table("stop_times")
    let trips = Table("trips")

    let query = """
        SELECT
            st.trip_id,
            t.route_short_name,
            t.trip_headsign,
            st.departure_time
        FROM stop_times st
        JOIN trips t ON st.trip_internal_id = t.id
        WHERE st.stop_internal_id = (SELECT id FROM stops WHERE stop_id = ?)
          AND st.departure_time >= ?
          AND t.service_id IN (?)
        ORDER BY st.departure_time
        LIMIT ?
    """

    let services = activeServices(for: Date())  // Today
    var results: [(String, String, String, Int)] = []

    for row in try! db.prepare(query, stopId, departureTime, services.joined(separator: ","), limit) {
        results.append((
            tripId: row[0] as! String,
            routeName: row[1] as! String,
            headsign: row[2] as! String,
            time: row[3] as! Int
        ))
    }

    return results
}

// Nearby stops
func nearbyStops(lat: Double, lon: Double, radiusKm: Double = 0.5) -> [(stopId: String, name: String, distance: Double)] {
    let query = """
        SELECT
            stop_id,
            stop_name,
            (6371 * acos(cos(radians(?)) * cos(radians(stop_lat)) *
             cos(radians(stop_lon) - radians(?)) + sin(radians(?)) *
             sin(radians(stop_lat)))) AS distance
        FROM stops
        WHERE stop_lat BETWEEN ? AND ?
          AND stop_lon BETWEEN ? AND ?
        HAVING distance < ?
        ORDER BY distance
        LIMIT 20
    """

    let latDelta = 0.01  // Rough bounding box
    let lonDelta = 0.01

    var results: [(String, String, Double)] = []

    for row in try! db.prepare(query, lat, lon, lat,
                                lat - latDelta, lat + latDelta,
                                lon - lonDelta, lon + lonDelta,
                                radiusKm) {
        results.append((
            stopId: row[0] as! String,
            name: row[1] as! String,
            distance: row[2] as! Double
        ))
    }

    return results
}
```

### GTFS-RT Parsing (Swift)

```swift
import SwiftProtobuf

struct GTFSRealtime {
    func fetchTripUpdates(url: URL) async throws -> [TransitRealtime_TripUpdate] {
        let (data, _) = try await URLSession.shared.data(from: url)
        let feed = try TransitRealtime_FeedMessage(serializedData: data)

        return feed.entity.compactMap { $0.hasTripUpdate ? $0.tripUpdate : nil }
    }

    func fetchVehiclePositions(url: URL) async throws -> [TransitRealtime_VehiclePosition] {
        let (data, _) = try await URLSession.shared.data(from: url)
        let feed = try TransitRealtime_FeedMessage(serializedData: data)

        return feed.entity.compactMap { $0.hasVehicle ? $0.vehicle : nil }
    }

    func fetchServiceAlerts(url: URL) async throws -> [TransitRealtime_Alert] {
        let (data, _) = try await URLSession.shared.data(from: url)
        let feed = try TransitRealtime_FeedMessage(serializedData: data)

        return feed.entity.compactMap { $0.hasAlert ? $0.alert : nil }
    }
}

// Usage
let rt = GTFSRealtime()

// Fetch trip updates every 30s
Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
    Task {
        do {
            let updates = try await rt.fetchTripUpdates(url: URL(string: "https://agency.com/gtfs-rt/trip-updates")!)

            for update in updates {
                let tripId = update.trip.tripID

                for stopUpdate in update.stopTimeUpdate {
                    if stopUpdate.hasArrival {
                        let delay = stopUpdate.arrival.delay  // Seconds
                        print("\(tripId) at stop \(stopUpdate.stopSequence): +\(delay)s")
                    }
                }
            }
        } catch {
            print("GTFS-RT fetch error: \(error)")
        }
    }
}
```

---

## Summary & Quick Reference

### GTFS Static Core Files
1. **agency.txt**: Transit agencies (timezone critical)
2. **routes.txt**: Bus/rail lines (route_type for mode)
3. **trips.txt**: Individual journey instances (headsign, direction)
4. **stops.txt**: Physical locations (lat/lon, wheelchair_boarding)
5. **stop_times.txt**: Schedule (times in HH:MM:SS, can exceed 24:00)
6. **calendar.txt**: Weekly patterns
7. **calendar_dates.txt**: Exceptions (holidays)

### GTFS Static Optional (High Value)
- **shapes.txt**: Route visualization
- **transfers.txt**: Connection rules, transfer times
- **frequencies.txt**: Headway-based service
- **pathways.txt**: Station navigation

### GTFS Realtime Messages
1. **Trip Updates**: Delays, cancellations
2. **Service Alerts**: Disruptions, closures
3. **Vehicle Positions**: Live locations, crowding

### Routing Algorithm Selection
- **On-Device Mobile**: RAPTOR (no preprocessing, good performance)
- **Server-Side API**: TBTR (fast queries after preprocessing)
- **Simple City App**: CSA (easiest to implement)
- **Commercial Scale**: Transfer Patterns (fastest, heavy preprocessing)

### iOS Database Schema
- **Use integers** for IDs (not strings)
- **Denormalize** frequently joined data
- **Index** all WHERE/JOIN columns
- **Exclude** unused files (shapes if not displaying routes)
- **Bundle** pre-built .sqlite file

### Time Handling
- All times in **agency_timezone**
- Times can **exceed 24:00:00** (service day, not calendar day)
- Store as **seconds since midnight** (integer)
- DST: No special handling (algorithm adjusts)

### Transfer Time Formula
```
min_transfer_time = walk_time + buffer_time

Typical buffers:
- Bus-to-bus (same stop): 0-2 min
- Bus-to-bus (different stops): 5 min
- Rail platform change: 3-5 min
- Long-distance: 10+ min
```

### Best Practices Checklist
- [ ] Stop locations within 4m accuracy
- [ ] Persistent IDs across versions
- [ ] Mixed Case text (not ALL CAPS)
- [ ] Headsigns without "To" prefix
- [ ] Shapes within 100m of stops
- [ ] Feed valid for 7+ days
- [ ] Remove expired services
- [ ] Wheelchair accessibility populated
- [ ] Transfer times include buffer
- [ ] Published at stable URL

### Key URLs
- **Specification**: https://gtfs.org/
- **GitHub**: https://github.com/google/transit
- **Best Practices**: https://gtfs.org/documentation/schedule/schedule-best-practices/
- **Realtime Proto**: https://gtfs.org/documentation/realtime/proto/
- **Validator**: https://github.com/MobilityData/gtfs-validator

---

## Complexity Assessment

**Low Complexity**:
- Parsing GTFS files (CSV parsing)
- Displaying static routes/stops
- Basic schedule lookup

**Medium Complexity**:
- Service day calculations (calendar logic)
- Timezone handling (cross-timezone trips)
- Transfer time modeling
- Database schema design

**High Complexity**:
- Multi-criteria routing algorithms (RAPTOR, TBTR)
- Realtime integration (protobuf parsing, updates)
- Multi-modal routing (walk + transit)
- Performance optimization (large datasets)
- Pareto-optimal result sets

**Very High Complexity**:
- Preprocessing-based algorithms (TBTR, Transfer Patterns)
- Nationwide/multi-agency federation
- Custom GTFS extensions
- Real-time predictions (beyond simple delays)

**Estimated Development Time (iOS App)**:
- Basic viewer (routes, stops, schedules): 2-4 weeks
- Add trip planning (RAPTOR): +3-5 weeks
- Add realtime updates: +2-3 weeks
- Polish, optimization, edge cases: +3-4 weeks
- **Total**: 10-16 weeks for comprehensive transit app

**Recommended Approach**:
1. **Phase 1**: Static GTFS display (stops, routes, schedules)
2. **Phase 2**: Basic routing (RAPTOR, single mode)
3. **Phase 3**: Multi-modal (walk + transit)
4. **Phase 4**: Realtime integration
5. **Phase 5**: Polish (offline, accessibility, performance)

---

*Document Version: 1.0*
*Last Updated: 2025-10-30*
*Based on GTFS Specification revised 2025-07-09*
