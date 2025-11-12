# Phase 1: Static Data + Basic UI
**Duration:** 2-3 weeks
**Timeline:** Week 3-5
**Goal:** Browse stops, routes, schedules offline (no real-time yet)

---

## Overview

This phase implements the complete GTFS static data pipeline and basic iOS browsing UI. By the end:
- GTFS data (227MB) parsed → Supabase pattern tables (~250-350MB)
- iOS SQLite generated (~15-20MB) and bundled
- iOS app can browse stops, routes, schedules **offline**
- Basic API endpoints for future real-time integration

**No real-time data yet** - pure static schedules from GTFS.

---

## Prerequisites

**Completed Phase 0:**
- [ ] Backend running locally
- [ ] iOS app running in simulator
- [ ] Supabase + Redis connected
- [ ] NSW Transport API key obtained

**User Setup for This Phase:**
- Download GTFS static dataset (see below)

---

## User Instructions (Complete First)

### Download GTFS Static Dataset

**Option 1: NSW API (Recommended)**
```bash
# Download all modes (trains, buses, ferries, light rail, metro)
mkdir -p ~/Downloads/gtfs-sydney
cd ~/Downloads/gtfs-sydney

# Sydney Trains
curl -H "Authorization: apikey YOUR_API_KEY" \
  https://api.transport.nsw.gov.au/v1/gtfs/schedule/sydneytrains/complete \
  -o sydneytrains.zip

# Buses
curl -H "Authorization: apikey YOUR_API_KEY" \
  https://api.transport.nsw.gov.au/v1/gtfs/schedule/buses/complete \
  -o buses.zip

# Ferries
curl -H "Authorization: apikey YOUR_API_KEY" \
  https://api.transport.nsw.gov.au/v1/gtfs/schedule/ferries/complete \
  -o ferries.zip

# Light Rail
curl -H "Authorization: apikey YOUR_API_KEY" \
  https://api.transport.nsw.gov.au/v1/gtfs/schedule/lightrail/complete \
  -o lightrail.zip

# Metro
curl -H "Authorization: apikey YOUR_API_KEY" \
  https://api.transport.nsw.gov.au/v1/gtfs/schedule/nswtrains/complete \
  -o metro.zip

# Unzip all
unzip sydneytrains.zip -d sydneytrains
unzip buses.zip -d buses
unzip ferries.zip -d ferries
unzip lightrail.zip -d lightrail
unzip metro.zip -d metro
```

**Expected files in each folder:**
- `agency.txt`
- `stops.txt`
- `routes.txt`
- `trips.txt`
- `stop_times.txt` (largest file, 100-150MB for buses)
- `calendar.txt`
- `calendar_dates.txt`
- `shapes.txt` (optional, for route polylines)

**Total size:** ~227MB compressed, ~600-800MB uncompressed

**Provide to AI agent:** Path to unzipped folders (e.g., `~/Downloads/gtfs-sydney/`)

---

## Implementation Checklist (AI Agent Tasks)

### Backend: GTFS Parser

**1. Install GTFS Parsing Library**
Add to `requirements.txt`:
```txt
gtfs-kit==6.0.0  # GTFS parsing & validation
```

**2. Create GTFS Service (app/services/gtfs_service.py)**
- [ ] Parse GTFS CSV files (using gtfs-kit or custom parser)
- [ ] Validate GTFS spec compliance
- [ ] Transform to pattern model (see DATA_ARCHITECTURE.md Section 5.4.3)
- [ ] Sydney-only filtering (see DATA_ARCHITECTURE.md Section 5.4.1):
  - Bounding box: lat [-34.5, -33.3], lon [150.5, 151.5]
  - Drop stops outside Sydney region
  - Drop routes with no stops in Sydney
- [ ] Log stats: # stops, routes, patterns, trips

**3. Pattern Model Implementation**
(From DATA_ARCHITECTURE.md Section 6)

**Pattern Extraction Algorithm:**
```python
def extract_patterns(gtfs_data):
    """
    Group trips by (route_id, direction_id, stop_sequence)
    Create pattern for each unique sequence
    Assign pattern_id to trips
    Calculate median offset_secs per pattern_stop
    """
    patterns = {}
    for trip in gtfs_data.trips:
        stop_seq = tuple(trip.stop_times.stop_id)  # unique sequence
        key = (trip.route_id, trip.direction_id, stop_seq)
        if key not in patterns:
            patterns[key] = {
                'pattern_id': len(patterns) + 1,
                'route_id': trip.route_id,
                'direction_id': trip.direction_id,
                'stops': stop_seq,
                'offsets': []  # collect all trip offsets
            }
        # Add this trip's offsets
        offsets = [st.departure_time - trip.start_time for st in trip.stop_times]
        patterns[key]['offsets'].append(offsets)

    # Calculate median offsets per pattern
    for pattern in patterns.values():
        pattern['median_offsets'] = [
            median([trip_offsets[i] for trip_offsets in pattern['offsets']])
            for i in range(len(pattern['stops']))
        ]
    return patterns
```

**4. Supabase Schema Migration (schemas/migrations/001_initial_schema.sql)**
(From DATA_ARCHITECTURE.md Section 6)

```sql
-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Agencies
CREATE TABLE agencies (
    agency_id TEXT PRIMARY KEY,
    agency_name TEXT NOT NULL,
    agency_timezone TEXT NOT NULL DEFAULT 'Australia/Sydney'
);

-- Routes
CREATE TABLE routes (
    route_id TEXT PRIMARY KEY,
    agency_id TEXT REFERENCES agencies(agency_id),
    route_short_name TEXT,
    route_long_name TEXT,
    route_type INT NOT NULL,
    route_color TEXT,
    route_text_color TEXT
);
CREATE INDEX idx_routes_type ON routes(route_type);

-- Stops (PostGIS geography)
CREATE TABLE stops (
    stop_id TEXT PRIMARY KEY,
    stop_code TEXT,
    stop_name TEXT NOT NULL,
    stop_lat DECIMAL(10, 8) NOT NULL,
    stop_lon DECIMAL(11, 8) NOT NULL,
    location GEOGRAPHY(POINT, 4326),
    parent_station TEXT
);
CREATE INDEX idx_stops_location ON stops USING GIST(location);
CREATE INDEX idx_stops_name ON stops USING GIN(to_tsvector('english', stop_name));

-- Trigger to auto-populate location from lat/lon
CREATE OR REPLACE FUNCTION update_stop_location()
RETURNS TRIGGER AS $$
BEGIN
    NEW.location = ST_SetSRID(ST_MakePoint(NEW.stop_lon, NEW.stop_lat), 4326)::geography;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_stop_location
BEFORE INSERT OR UPDATE ON stops
FOR EACH ROW EXECUTE FUNCTION update_stop_location();

-- Patterns (trip factoring)
CREATE TABLE patterns (
    pattern_id BIGSERIAL PRIMARY KEY,
    route_id TEXT NOT NULL REFERENCES routes(route_id),
    direction_id INT,
    shape_id TEXT
);
CREATE INDEX idx_patterns_route ON patterns(route_id);

-- Pattern stops (offsets)
CREATE TABLE pattern_stops (
    pattern_id BIGINT NOT NULL REFERENCES patterns(pattern_id),
    seq INT NOT NULL,
    stop_id TEXT NOT NULL REFERENCES stops(stop_id),
    offset_secs INT NOT NULL,
    PRIMARY KEY (pattern_id, seq)
);
CREATE INDEX idx_pattern_stops_stop ON pattern_stops(stop_id);

-- Trips (compressed)
CREATE TABLE trips (
    trip_id TEXT PRIMARY KEY,
    pattern_id BIGINT NOT NULL REFERENCES patterns(pattern_id),
    service_id TEXT NOT NULL,
    start_time_secs INT NOT NULL,
    headsign TEXT
);
CREATE INDEX idx_trips_pattern ON trips(pattern_id);
CREATE INDEX idx_trips_service ON trips(service_id);

-- Calendar (service patterns)
CREATE TABLE calendar (
    service_id TEXT PRIMARY KEY,
    monday BOOLEAN NOT NULL,
    tuesday BOOLEAN NOT NULL,
    wednesday BOOLEAN NOT NULL,
    thursday BOOLEAN NOT NULL,
    friday BOOLEAN NOT NULL,
    saturday BOOLEAN NOT NULL,
    sunday BOOLEAN NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL
);

-- Calendar dates (exceptions)
CREATE TABLE calendar_dates (
    service_id TEXT NOT NULL,
    date DATE NOT NULL,
    exception_type INT NOT NULL,
    PRIMARY KEY (service_id, date)
);
CREATE INDEX idx_calendar_dates_date ON calendar_dates(date);

-- GTFS version tracking
CREATE TABLE gtfs_metadata (
    id INT PRIMARY KEY DEFAULT 1,
    feed_version TEXT NOT NULL,
    feed_start_date DATE NOT NULL,
    feed_end_date DATE NOT NULL,
    last_updated TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = 1)
);
```

**5. Run Migration**
- [ ] Execute migration via Supabase SQL Editor (Dashboard → SQL Editor → paste migration)
- [ ] Verify tables created: `SELECT table_name FROM information_schema.tables WHERE table_schema='public';`
- [ ] Verify PostGIS enabled: `SELECT PostGIS_version();`

**6. GTFS Loader Task (app/tasks/gtfs_static_sync.py)**
- [ ] Read GTFS CSV files from provided path
- [ ] Parse & validate (log errors)
- [ ] Transform to pattern model
- [ ] Sydney filtering (bounding box)
- [ ] Bulk insert to Supabase:
  ```python
  # Use Supabase bulk insert (faster than row-by-row)
  supabase.table('agencies').upsert(agencies_list).execute()
  supabase.table('routes').upsert(routes_list).execute()
  # ... etc
  ```
- [ ] Insert `gtfs_metadata` (feed_version, dates)
- [ ] Log stats: `gtfs_load_complete`, `stops_count`, `routes_count`, `patterns_count`, `trips_count`
- [ ] Validation queries (see DATA_ARCHITECTURE.md Section 6):
  ```sql
  SELECT COUNT(*) FROM stops;  -- Expect 10k-25k Sydney
  SELECT COUNT(*) FROM routes; -- Expect 400-1200
  SELECT COUNT(*) FROM patterns; -- Expect 2k-10k
  ```

**7. Run GTFS Loader Manually (First Time)**
```bash
# In Python console or Jupyter notebook
from app.tasks.gtfs_static_sync import load_gtfs_static
load_gtfs_static(gtfs_path='~/Downloads/gtfs-sydney/')
```
- [ ] Loader completes without errors
- [ ] Supabase tables populated (check row counts)
- [ ] Total DB size <350MB (check Supabase dashboard)

---

### Backend: iOS SQLite Generator

**8. Create iOS SQLite Generator (app/services/ios_db_generator.py)**
(From DATA_ARCHITECTURE.md Section 6 - iOS SQLite Optimization)

- [ ] Query Supabase pattern tables
- [ ] Transform to dictionary-coded schema:
  ```sql
  -- Map text IDs → compact ints
  CREATE TABLE dict_route (rid INTEGER PRIMARY KEY, route_id TEXT UNIQUE);
  CREATE TABLE dict_stop (sid INTEGER PRIMARY KEY, stop_id TEXT UNIQUE);

  -- Stops with int keys
  CREATE TABLE stops (
      sid INTEGER PRIMARY KEY,
      name TEXT NOT NULL,
      lat REAL NOT NULL,
      lon REAL NOT NULL
  ) WITHOUT ROWID;

  -- Routes
  CREATE TABLE routes (
      rid INTEGER PRIMARY KEY,
      short_name TEXT,
      long_name TEXT,
      route_type INT,
      color TEXT
  ) WITHOUT ROWID;

  -- Patterns
  CREATE TABLE patterns (
      pid INTEGER PRIMARY KEY,
      rid INTEGER NOT NULL,
      direction_id INT
  ) WITHOUT ROWID;

  -- Pattern stops
  CREATE TABLE pattern_stops (
      pid INTEGER NOT NULL,
      seq INTEGER NOT NULL,
      sid INTEGER NOT NULL,
      offset_secs INTEGER NOT NULL,
      PRIMARY KEY (pid, seq)
  ) WITHOUT ROWID;

  -- Trips
  CREATE TABLE trips (
      trip_id TEXT PRIMARY KEY,
      pid INTEGER NOT NULL,
      service_id TEXT NOT NULL,
      start_time_secs INTEGER NOT NULL,
      headsign TEXT
  );

  -- Calendar
  CREATE TABLE calendar (
      service_id TEXT PRIMARY KEY,
      days INTEGER NOT NULL,  -- Bit flags: Mon=1, Tue=2, Wed=4, etc.
      start_date INTEGER NOT NULL,  -- Unix timestamp
      end_date INTEGER NOT NULL
  );

  -- Metadata
  CREATE TABLE metadata (
      key TEXT PRIMARY KEY,
      value TEXT
  );
  INSERT INTO metadata VALUES ('feed_version', '2025-11-12');
  INSERT INTO metadata VALUES ('generated_at', '2025-11-12T08:00:00+11:00');
  ```

- [ ] Optimize SQLite file:
  ```sql
  PRAGMA journal_mode=OFF;
  PRAGMA synchronous=OFF;
  PRAGMA page_size=8192;
  VACUUM;
  ```
- [ ] Write to `gtfs.db` (save to `backend/ios_output/gtfs.db`)
- [ ] Verify size: 15-20MB target (log actual size)
- [ ] Create FTS5 search index:
  ```sql
  CREATE VIRTUAL TABLE stops_fts USING fts5(sid, name, tokenize='porter');
  INSERT INTO stops_fts SELECT sid, name FROM stops;
  ```

**9. Run Generator**
```bash
python -c "from app.services.ios_db_generator import generate_ios_db; generate_ios_db()"
```
- [ ] Generator completes without errors
- [ ] `gtfs.db` created in `backend/ios_output/`
- [ ] File size 15-20MB (if >30MB, re-check optimization)
- [ ] Test query: `sqlite3 gtfs.db "SELECT COUNT(*) FROM stops;"`

---

### Backend: API Endpoints

**10. Stops API (app/api/v1/stops.py)**
(From INTEGRATION_CONTRACTS.md Section 2.1)

**GET /stops/nearby**
```python
@router.get("/stops/nearby")
async def get_nearby_stops(
    lat: float,
    lon: float,
    radius: int = 500,  # meters
    limit: int = 20,
    supabase: Client = Depends(get_supabase)
):
    """Find stops within radius of coordinates."""
    # PostGIS query
    query = """
    SELECT stop_id, stop_name, stop_lat, stop_lon,
           ST_Distance(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography) AS distance
    FROM stops
    WHERE ST_DWithin(location, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography, $3)
    ORDER BY distance
    LIMIT $4;
    """
    result = supabase.rpc('exec_raw_sql', {'query': query, 'params': [lon, lat, radius, limit]}).execute()
    return SuccessResponse(data=result.data)
```

**GET /stops/{stop_id}**
```python
@router.get("/stops/{stop_id}")
async def get_stop(stop_id: str, supabase: Client = Depends(get_supabase)):
    """Get stop details by ID."""
    result = supabase.table('stops').select('*').eq('stop_id', stop_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail={"code": "STOP_NOT_FOUND"})
    return SuccessResponse(data=result.data[0])
```

**GET /stops/search**
```python
@router.get("/stops/search")
async def search_stops(
    query: str,
    limit: int = 20,
    supabase: Client = Depends(get_supabase)
):
    """Full-text search on stop names."""
    # PostgreSQL FTS
    result = supabase.table('stops').select('*').textSearch('stop_name', query).limit(limit).execute()
    return SuccessResponse(data=result.data)
```

**GET /stops/{stop_id}/departures**
```python
@router.get("/stops/{stop_id}/departures")
async def get_stop_departures(
    stop_id: str,
    date: str = None,  # YYYY-MM-DD, default today
    time: str = None,  # HH:MM, default now
    limit: int = 10,
    supabase: Client = Depends(get_supabase)
):
    """Get scheduled departures for a stop (static schedules only, no real-time yet)."""
    # Default to now
    if not date:
        date = datetime.now(pytz.timezone('Australia/Sydney')).strftime('%Y-%m-%d')
    if not time:
        time = datetime.now(pytz.timezone('Australia/Sydney')).strftime('%H:%M')

    # Convert to seconds since midnight
    now_secs = int(time.split(':')[0]) * 3600 + int(time.split(':')[1]) * 60

    # Query pattern model (see DATA_ARCHITECTURE.md Section 6)
    query = """
    SELECT t.trip_id, r.route_short_name, t.headsign,
           (t.start_time_secs + ps.offset_secs) AS dep_secs
    FROM pattern_stops ps
    JOIN trips t ON t.pattern_id = ps.pattern_id
    JOIN patterns p ON p.pattern_id = ps.pattern_id
    JOIN routes r ON r.route_id = p.route_id
    WHERE ps.stop_id = $1
      AND (t.start_time_secs + ps.offset_secs) >= $2
    ORDER BY dep_secs
    LIMIT $3;
    """
    result = supabase.rpc('exec_raw_sql', {'query': query, 'params': [stop_id, now_secs, limit]}).execute()

    # Convert dep_secs back to HH:MM format
    departures = []
    for row in result.data:
        dep_time = f"{row['dep_secs'] // 3600:02d}:{(row['dep_secs'] % 3600) // 60:02d}"
        departures.append({
            'trip_id': row['trip_id'],
            'route_short_name': row['route_short_name'],
            'headsign': row['headsign'],
            'departure_time': dep_time
        })

    return SuccessResponse(data=departures)
```

**11. Routes API (app/api/v1/routes.py)**

**GET /routes**
```python
@router.get("/routes")
async def list_routes(
    route_type: int = None,  # Filter by type (0=tram, 1=metro, 2=rail, 3=bus, 4=ferry)
    limit: int = 100,
    supabase: Client = Depends(get_supabase)
):
    """List all routes, optionally filtered by type."""
    query = supabase.table('routes').select('*')
    if route_type is not None:
        query = query.eq('route_type', route_type)
    result = query.limit(limit).execute()
    return SuccessResponse(data=result.data)
```

**GET /routes/{route_id}**
```python
@router.get("/routes/{route_id}")
async def get_route(route_id: str, supabase: Client = Depends(get_supabase)):
    """Get route details by ID."""
    result = supabase.table('routes').select('*').eq('route_id', route_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail={"code": "ROUTE_NOT_FOUND"})
    return SuccessResponse(data=result.data[0])
```

**12. GTFS Metadata API (app/api/v1/gtfs.py)**

**GET /gtfs/version**
```python
@router.get("/gtfs/version")
async def get_gtfs_version(supabase: Client = Depends(get_supabase)):
    """Get current GTFS feed version (for iOS update checks)."""
    result = supabase.table('gtfs_metadata').select('*').eq('id', 1).execute()
    if not result.data:
        return SuccessResponse(data={'feed_version': 'unknown'})
    return SuccessResponse(data=result.data[0])
```

**GET /gtfs/download**
```python
@router.get("/gtfs/download")
async def download_gtfs_db():
    """Serve iOS SQLite file for download."""
    file_path = Path('ios_output/gtfs.db')
    if not file_path.exists():
        raise HTTPException(status_code=404, detail={"code": "DB_NOT_FOUND"})
    return FileResponse(file_path, media_type='application/x-sqlite3', filename='gtfs.db')
```

**13. Register Routes (app/main.py)**
```python
from app.api.v1 import stops, routes, gtfs

app.include_router(stops.router, prefix='/api/v1', tags=['stops'])
app.include_router(routes.router, prefix='/api/v1', tags=['routes'])
app.include_router(gtfs.router, prefix='/api/v1', tags=['gtfs'])
```

---

### iOS: GRDB Setup

**14. Add GRDB Dependency**
In Xcode: File → Add Packages → `https://github.com/groue/GRDB.swift.git` → Version 6.22.0+

**15. Bundle SQLite File**
- [ ] Copy `backend/ios_output/gtfs.db` to `SydneyTransit/Resources/gtfs.db`
- [ ] Add to Xcode: Right-click Resources → Add Files → gtfs.db → Ensure "Copy items if needed" checked
- [ ] Verify in Build Phases → Copy Bundle Resources

**16. Database Manager (Core/Database/DatabaseManager.swift)**
```swift
import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()
    private var dbQueue: DatabaseQueue!

    private init() {
        guard let path = Bundle.main.path(forResource: "gtfs", ofType: "db") else {
            fatalError("gtfs.db not found in bundle")
        }
        do {
            dbQueue = try DatabaseQueue(path: path)
        } catch {
            fatalError("Failed to open database: \(error)")
        }
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }
}
```

**17. Stop Model (Data/Models/Stop.swift)**
```swift
import GRDB

struct Stop: Codable, FetchableRecord {
    let sid: Int
    let name: String
    let lat: Double
    let lon: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

extension Stop {
    static func fetchAll(db: Database, limit: Int = 100) throws -> [Stop] {
        try Stop.fetchAll(db, sql: "SELECT * FROM stops LIMIT ?", arguments: [limit])
    }

    static func search(db: Database, query: String, limit: Int = 20) throws -> [Stop] {
        try Stop.fetchAll(db, sql: """
            SELECT s.* FROM stops s
            JOIN stops_fts ON stops_fts.sid = s.sid
            WHERE stops_fts MATCH ?
            LIMIT ?
            """, arguments: [query, limit])
    }
}
```

**18. Route Model (Data/Models/Route.swift)**
```swift
struct Route: Codable, FetchableRecord {
    let rid: Int
    let short_name: String?
    let long_name: String?
    let route_type: Int
    let color: String?
}
```

---

### iOS: UI Implementation

**19. Home Screen (Features/Home/HomeView.swift)**
```swift
struct HomeView: View {
    @State private var recentStops: [Stop] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Recent Stops") {
                    ForEach(recentStops, id: \.sid) { stop in
                        NavigationLink(value: stop) {
                            Text(stop.name)
                        }
                    }
                }

                Section("Quick Actions") {
                    NavigationLink("Search Stops", value: "search")
                    NavigationLink("Browse Routes", value: "routes")
                }
            }
            .navigationTitle("Sydney Transit")
            .navigationDestination(for: Stop.self) { stop in
                StopDetailsView(stop: stop)
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "search" {
                    SearchView()
                } else if destination == "routes" {
                    RouteListView()
                }
            }
            .onAppear {
                loadRecentStops()
            }
        }
    }

    func loadRecentStops() {
        do {
            recentStops = try DatabaseManager.shared.read { db in
                try Stop.fetchAll(db, limit: 5)
            }
        } catch {
            Logger.app.error("Failed to load stops: \(error)")
        }
    }
}
```

**20. Search Screen (Features/Search/SearchView.swift)**
```swift
struct SearchView: View {
    @State private var query = ""
    @State private var results: [Stop] = []

    var body: some View {
        List(results, id: \.sid) { stop in
            NavigationLink(value: stop) {
                VStack(alignment: .leading) {
                    Text(stop.name)
                        .font(.headline)
                    Text("\(stop.lat), \(stop.lon)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .searchable(text: $query, prompt: "Search stops")
        .onChange(of: query) { newQuery in
            performSearch(query: newQuery)
        }
        .navigationTitle("Search")
    }

    func performSearch(query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }

        do {
            results = try DatabaseManager.shared.read { db in
                try Stop.search(db: db, query: query, limit: 20)
            }
        } catch {
            Logger.app.error("Search failed: \(error)")
        }
    }
}
```

**21. Stop Details Screen (Features/Stops/StopDetailsView.swift)**
```swift
struct StopDetailsView: View {
    let stop: Stop
    @State private var departures: [String] = []  // Placeholder (real-time in Phase 2)

    var body: some View {
        List {
            Section("Location") {
                Text("Lat: \(stop.lat), Lon: \(stop.lon)")
            }

            Section("Upcoming Departures") {
                if departures.isEmpty {
                    Text("No upcoming departures")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(departures, id: \.self) { dep in
                        Text(dep)
                    }
                }
            }
        }
        .navigationTitle(stop.name)
        .onAppear {
            // Phase 2: Fetch real-time departures from API
            departures = ["12:30 PM - Route 400", "12:45 PM - Route 333"]  // Mock
        }
    }
}
```

**22. Route List Screen (Features/Routes/RouteListView.swift)**
```swift
struct RouteListView: View {
    @State private var routes: [Route] = []

    var body: some View {
        List(routes, id: \.rid) { route in
            HStack {
                Text(route.short_name ?? route.long_name ?? "Unknown")
                    .font(.headline)
                Spacer()
                Text(routeTypeLabel(route.route_type))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Routes")
        .onAppear {
            loadRoutes()
        }
    }

    func loadRoutes() {
        do {
            routes = try DatabaseManager.shared.read { db in
                try Route.fetchAll(db, sql: "SELECT * FROM routes LIMIT 100")
            }
        } catch {
            Logger.app.error("Failed to load routes: \(error)")
        }
    }

    func routeTypeLabel(_ type: Int) -> String {
        switch type {
        case 0: return "Tram"
        case 1: return "Metro"
        case 2: return "Rail"
        case 3: return "Bus"
        case 4: return "Ferry"
        default: return "Other"
        }
    }
}
```

---

## Acceptance Criteria (Manual Testing)

### Backend Tests

**1. GTFS Data Loaded**
```bash
# Connect to Supabase via psql or SQL Editor
SELECT COUNT(*) FROM stops;     -- Expect 10k-25k
SELECT COUNT(*) FROM routes;    -- Expect 400-1200
SELECT COUNT(*) FROM patterns;  -- Expect 2k-10k
SELECT COUNT(*) FROM trips;     -- Expect 40k-120k
```
- [ ] All counts within expected ranges
- [ ] No NULL location values: `SELECT COUNT(*) FROM stops WHERE location IS NULL;` (expect 0)

**2. API Endpoints Work**
```bash
# Nearby stops (Circular Quay coordinates)
curl "http://localhost:8000/api/v1/stops/nearby?lat=-33.8615&lon=151.2106&radius=500"

# Stop details
curl "http://localhost:8000/api/v1/stops/200060"  # Circular Quay stop ID

# Search
curl "http://localhost:8000/api/v1/stops/search?query=circular"

# Departures
curl "http://localhost:8000/api/v1/stops/200060/departures"

# Routes
curl "http://localhost:8000/api/v1/routes"

# GTFS version
curl "http://localhost:8000/api/v1/gtfs/version"

# Download DB
curl -O "http://localhost:8000/api/v1/gtfs/download"
```
- [ ] All return 200
- [ ] Data is valid (not empty, matches expected structure)

**3. iOS SQLite Generated**
```bash
ls -lh backend/ios_output/gtfs.db
sqlite3 backend/ios_output/gtfs.db "SELECT COUNT(*) FROM stops;"
sqlite3 backend/ios_output/gtfs.db "SELECT * FROM metadata;"
```
- [ ] File size 15-20MB
- [ ] Contains data (counts match Supabase)

---

### iOS Tests

**1. App Launches with Data**
- [ ] Open iOS app in simulator
- [ ] Home screen shows recent stops (5 stops)
- [ ] No crashes

**2. Search Works**
- [ ] Navigate to Search
- [ ] Type "circular"
- [ ] Results appear (Circular Quay, etc.)
- [ ] Search is fast (<200ms)

**3. Stop Details**
- [ ] Tap a stop from search results
- [ ] Stop details screen shows name, location
- [ ] Mock departures displayed

**4. Route List**
- [ ] Navigate to Routes
- [ ] List of routes displayed
- [ ] Route types labeled correctly (Train, Bus, etc.)

**5. Offline Mode**
- [ ] Disable Wi-Fi on Mac (turns off simulator network)
- [ ] Re-launch iOS app
- [ ] Search still works (local DB)
- [ ] Stop details still show (no API call yet)

---

## Troubleshooting

### Backend Issues

**Problem:** GTFS loader fails with "Invalid CSV"
- **Solution:** Validate GTFS files with https://gtfs-validator.mobilitydata.org/
- Check for missing required files (stops.txt, routes.txt, trips.txt, stop_times.txt)

**Problem:** Pattern extraction is slow (>10 minutes)
- **Solution:** Process in batches (10K trips at a time)
- Use multiprocessing for parallel pattern extraction

**Problem:** Supabase DB size exceeds 500MB
- **Solution:** Check pattern model compression (should be 8-15×)
- Drop unused fields (stop_desc, wheelchair_boarding, etc.)
- Sydney filtering may not be working (check bounding box)

**Problem:** PostGIS query returns no results
- **Solution:** Verify `location` column populated: `SELECT COUNT(*) FROM stops WHERE location IS NOT NULL;`
- Check trigger is active: `SELECT * FROM pg_trigger WHERE tgname = 'trigger_update_stop_location';`

### iOS Issues

**Problem:** GRDB crashes with "database is locked"
- **Solution:** Ensure read-only mode: `file:\(path)?mode=ro&immutable=1`

**Problem:** Search returns no results
- **Solution:** Verify FTS5 index exists: `SELECT * FROM sqlite_master WHERE type='table' AND name='stops_fts';`

**Problem:** App binary size >50MB
- **Solution:** Check gtfs.db is downloaded, not bundled (Phase 1 bundles for simplicity, Phase 2 adds download)

**Problem:** Stop coordinates don't match map
- **Solution:** Verify lat/lon order (GTFS uses lat,lon; PostGIS uses lon,lat)

---

## Git Workflow

```bash
git checkout -b phase-1-static-data

# Commit backend work
git add backend/app/services/gtfs_service.py
git commit -m "feat: add GTFS parser and pattern model"

git add backend/schemas/migrations/001_initial_schema.sql
git commit -m "feat: add Supabase schema migration"

git add backend/app/api/v1/stops.py
git commit -m "feat: add stops API endpoints"

# Commit iOS work
git add SydneyTransit/Core/Database/
git commit -m "feat: add GRDB database manager"

git add SydneyTransit/Features/Search/
git commit -m "feat: add stop search UI"

# Phase complete
git add .
git commit -m "feat: phase 1 static data complete"
git tag phase-1-complete
git checkout main
git merge phase-1-static-data
```

---

## Deliverables Checklist

**Backend:**
- [ ] GTFS data loaded to Supabase (<350MB)
- [ ] Pattern model implemented (8-15× compression)
- [ ] iOS SQLite generated (15-20MB)
- [ ] API endpoints: stops, routes, GTFS metadata
- [ ] All APIs return correct data

**iOS:**
- [ ] GRDB setup complete
- [ ] Search works (FTS5)
- [ ] Stop details screen
- [ ] Route list screen
- [ ] Offline browsing works

**Documentation:**
- [ ] README updated with GTFS loader instructions
- [ ] API endpoints documented (cURL examples)

---

## Next Phase Preview

**Phase 2: Real-Time Foundation**
- Celery setup (background workers)
- GTFS-RT poller (poll NSW API every 30s)
- Redis caching (blob model)
- Real-time departures API
- iOS auto-refresh (departures screen)

**Estimated Start:** Week 6

---

**End of PHASE_1_STATIC_DATA.md**
