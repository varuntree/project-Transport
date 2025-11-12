# Phase 2: Real-Time Foundation
**Duration:** 2-3 weeks
**Timeline:** Week 6-8
**Goal:** Live departures with GTFS-RT integration (30s polling, Redis caching)

---

## Overview

This phase adds real-time data to the app. By the end:
- Celery workers polling NSW GTFS-RT API every 30s (adaptive peak/off-peak)
- Redis blob caching (per-mode, gzipped JSON)
- Real-time departures API (merges static schedules + live delays)
- iOS departures screen with auto-refresh
- Graceful degradation (stale cache when API fails)

**No user auth yet** - all endpoints anonymous (Phase 3 adds auth).

---

## Prerequisites

**Completed Phase 1:**
- [ ] GTFS static data in Supabase
- [ ] iOS SQLite bundled
- [ ] API endpoints working
- [ ] iOS app browses stops offline

**User Setup for This Phase:**
- Verify Redis connection (Railway)
- Verify NSW API key has GTFS-RT access

---

## User Instructions (Complete First)

### Test NSW GTFS-RT Access

```bash
# Test all GTFS-RT feeds (Vehicle Positions, Trip Updates, Alerts)
curl -H "Authorization: apikey YOUR_API_KEY" \
  https://api.transport.nsw.gov.au/v1/gtfs/vehiclepos/buses \
  --output buses_vp.pb

curl -H "Authorization: apikey YOUR_API_KEY" \
  https://api.transport.nsw.gov.au/v1/gtfs/realtime/buses \
  --output buses_tu.pb

curl -H "Authorization: apikey YOUR_API_KEY" \
  https://api.transport.nsw.gov.au/v1/gtfs/alerts/buses \
  --output buses_alerts.pb

# All should download protobuf files (binary, not JSON)
# If 401: Invalid API key
# If 403: Rate limit (wait 1s, retry)
```

### Verify Redis Connection

```bash
# Test Redis (from Phase 0)
redis-cli -u $REDIS_URL

# Once connected:
PING  # Should return PONG
SET test_key "hello"
GET test_key  # Should return "hello"
DEL test_key
```

---

## Implementation Checklist (AI Agent Tasks)

### Backend: Celery Setup

**1. Install Celery Dependencies**
Add to `requirements.txt`:
```txt
celery[redis]==5.3.4
redis==5.0.1
gtfs-realtime-bindings==1.0.0  # Protobuf parser
```

**2. Celery App Config (app/tasks/celery_app.py)**
(From BACKEND_SPECIFICATION.md Section 4)

```python
from celery import Celery
from kombu import Queue
from app.config import settings

celery_app = Celery(
    'sydney_transit',
    broker=settings.CELERY_BROKER_URL,
    include=[
        'app.tasks.gtfs_rt_poller',
        'app.tasks.gtfs_static_sync'
    ]
)

# Queue configuration (3 queues)
celery_app.conf.task_queues = (
    Queue('critical', routing_key='critical'),  # GTFS-RT poller (singleton, time-sensitive)
    Queue('normal', routing_key='normal'),      # Alert matcher, APNs (parallel)
    Queue('batch', routing_key='batch'),        # GTFS static sync (long-running)
)

# Worker configuration
celery_app.conf.update(
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='Australia/Sydney',
    enable_utc=True,
    task_track_started=True,
    task_time_limit=None,  # Per-task override
    worker_prefetch_multiplier=1,  # Fairness (prevents one worker grabbing all tasks)
    broker_connection_retry_on_startup=True,
)

# Celery Beat schedule (periodic tasks)
celery_app.conf.beat_schedule = {
    'poll-gtfs-rt': {
        'task': 'app.tasks.gtfs_rt_poller.poll_gtfs_rt',
        'schedule': 30.0,  # Every 30s (adaptive inside task)
        'options': {'queue': 'critical'}
    },
    'sync-gtfs-static': {
        'task': 'app.tasks.gtfs_static_sync.sync_gtfs_static',
        'schedule': crontab(hour=3, minute=10),  # 03:10 Australia/Sydney (DST-safe)
        'options': {'queue': 'batch'}
    },
}

# Beat config (prevent overlap)
celery_app.conf.beat_cron_starting_deadline = 120  # Allow 2 min jitter for cron tasks
```

**3. GTFS-RT Poller Task (app/tasks/gtfs_rt_poller.py)**
(From DATA_ARCHITECTURE.md Section 4)

```python
import structlog
import gzip
import json
from datetime import datetime
import pytz
from google.transit import gtfs_realtime_pb2
import requests
from app.tasks.celery_app import celery_app
from app.db.redis_client import get_redis
from app.config import settings

logger = structlog.get_logger()

MODES = ['buses', 'sydneytrains', 'metro', 'ferries', 'lightrail']
PEAK_HOURS = {7, 8, 9, 17, 18, 19}  # Sydney local time
SYDNEY_TZ = pytz.timezone('Australia/Sydney')

@celery_app.task(
    name='poll_gtfs_rt',
    queue='critical',
    bind=True,
    max_retries=0,  # Don't retry, just skip and wait for next poll
    time_limit=15,  # Hard timeout (SIGKILL)
    soft_time_limit=10  # Soft timeout (exception)
)
def poll_gtfs_rt(self):
    """Poll NSW GTFS-RT feeds (Vehicle Positions + Trip Updates), cache in Redis."""
    redis_client = get_redis()

    # Singleton lock (prevent overlapping runs)
    lock_key = 'lock:poll_gtfs_rt'
    lock_acquired = redis_client.set(lock_key, '1', nx=True, ex=30)
    if not lock_acquired:
        logger.info("poll_gtfs_rt_skipped", reason="already_running")
        return

    try:
        now_sydney = datetime.now(SYDNEY_TZ)
        is_peak = now_sydney.hour in PEAK_HOURS

        # Adaptive cadence (peak vs off-peak)
        # Note: Beat runs every 30s, but we check if we should poll VP or TU based on elapsed time
        # For simplicity in Phase 2, always poll both (optimization in later phases)

        logger.info("poll_gtfs_rt_started", is_peak=is_peak, sydney_time=now_sydney.isoformat())

        for mode in MODES:
            # Poll Vehicle Positions
            try:
                vp_data = fetch_gtfs_rt(mode, 'vehiclepos')
                parsed_vp = parse_vehicle_positions(vp_data)
                cache_blob(redis_client, f'vp:{mode}:v1', parsed_vp, ttl=75)
                logger.info("vp_cached", mode=mode, vehicle_count=len(parsed_vp['vehicles']))
            except Exception as exc:
                logger.error("vp_fetch_failed", mode=mode, error=str(exc))

            # Poll Trip Updates
            try:
                tu_data = fetch_gtfs_rt(mode, 'realtime')
                parsed_tu = parse_trip_updates(tu_data)
                cache_blob(redis_client, f'tu:{mode}:v1', parsed_tu, ttl=90)
                logger.info("tu_cached", mode=mode, trip_count=len(parsed_tu['trips']))
            except Exception as exc:
                logger.error("tu_fetch_failed", mode=mode, error=str(exc))

        logger.info("poll_gtfs_rt_complete")

    finally:
        redis_client.delete(lock_key)


def fetch_gtfs_rt(mode: str, feed_type: str) -> bytes:
    """Fetch GTFS-RT protobuf from NSW API."""
    url = f"https://api.transport.nsw.gov.au/v1/gtfs/{feed_type}/{mode}"
    headers = {'Authorization': f'apikey {settings.NSW_API_KEY}'}
    response = requests.get(url, headers=headers, timeout=8)
    response.raise_for_status()
    return response.content


def parse_vehicle_positions(pb_data: bytes) -> dict:
    """Parse GTFS-RT VehiclePosition protobuf to JSON."""
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(pb_data)

    vehicles = []
    for entity in feed.entity:
        if entity.HasField('vehicle'):
            vp = entity.vehicle
            vehicles.append({
                'vehicle_id': entity.id,
                'trip_id': vp.trip.trip_id if vp.HasField('trip') else None,
                'route_id': vp.trip.route_id if vp.HasField('trip') else None,
                'lat': vp.position.latitude if vp.HasField('position') else None,
                'lon': vp.position.longitude if vp.HasField('position') else None,
                'bearing': vp.position.bearing if vp.HasField('position') else None,
                'speed': vp.position.speed if vp.HasField('position') else None,
                'timestamp': vp.timestamp or int(feed.header.timestamp)
            })

    return {
        'generated_at': int(feed.header.timestamp),
        'vehicles': vehicles
    }


def parse_trip_updates(pb_data: bytes) -> dict:
    """Parse GTFS-RT TripUpdate protobuf to JSON."""
    feed = gtfs_realtime_pb2.FeedMessage()
    feed.ParseFromString(pb_data)

    trips = []
    for entity in feed.entity:
        if entity.HasField('trip_update'):
            tu = entity.trip_update
            stop_time_updates = []
            for stu in tu.stop_time_update:
                stop_time_updates.append({
                    'stop_id': stu.stop_id,
                    'stop_sequence': stu.stop_sequence,
                    'arrival_delay': stu.arrival.delay if stu.HasField('arrival') else None,
                    'departure_delay': stu.departure.delay if stu.HasField('departure') else None
                })

            trips.append({
                'trip_id': tu.trip.trip_id,
                'route_id': tu.trip.route_id,
                'delay_s': tu.delay if tu.HasField('delay') else 0,
                'schedule_relationship': tu.trip.schedule_relationship,
                'stop_time_updates': stop_time_updates,
                'timestamp': tu.timestamp or int(feed.header.timestamp)
            })

    return {
        'generated_at': int(feed.header.timestamp),
        'trips': trips
    }


def cache_blob(redis_client, key: str, data: dict, ttl: int):
    """Cache JSON blob (gzipped) in Redis."""
    json_str = json.dumps(data)
    gzipped = gzip.compress(json_str.encode('utf-8'))
    redis_client.setex(key, ttl, gzipped)
```

**4. Alerts Poller Task (app/tasks/alerts_poller.py)**
(Optional for Phase 2, can defer to Phase 5)

For now, create stub:
```python
@celery_app.task(
    name='poll_alerts',
    queue='normal',
    time_limit=60
)
def poll_alerts():
    """Poll service alerts (Phase 5 implementation)."""
    logger.info("alerts_polling_stub")
    # TODO: Implement in Phase 5
```

**5. Worker Startup Scripts**

**Worker A (critical queue only):**
```bash
# scripts/start_worker_critical.sh
celery -A app.tasks.celery_app worker \
  -Q critical \
  -c 1 \
  --loglevel=info \
  -n worker_critical@%h
```

**Worker B (normal + batch queues):**
```bash
# scripts/start_worker_service.sh
celery -A app.tasks.celery_app worker \
  -Q normal,batch \
  -c 2 \
  --autoscale=3,1 \
  --loglevel=info \
  -n worker_service@%h
```

**Celery Beat (scheduler):**
```bash
# scripts/start_beat.sh
celery -A app.tasks.celery_app beat \
  --loglevel=info
```

**6. Test Celery Locally**
```bash
# Terminal 1: Start Redis (if not Railway)
redis-server

# Terminal 2: Start FastAPI
cd backend
source venv/bin/activate
uvicorn app.main:app --reload

# Terminal 3: Start Worker (critical)
bash scripts/start_worker_critical.sh

# Terminal 4: Start Beat
bash scripts/start_beat.sh

# Watch logs: Should see "poll_gtfs_rt_started" every 30s
```

- [ ] Worker starts without errors
- [ ] Beat schedules tasks every 30s
- [ ] Logs show: `poll_gtfs_rt_started`, `vp_cached`, `tu_cached` for each mode
- [ ] Redis keys exist: `redis-cli KEYS vp:*` (should list 5 keys: buses, sydneytrains, metro, ferries, lightrail)

---

### Backend: Real-Time Departures API

**7. Real-Time Service (app/services/realtime_service.py)**

```python
import structlog
import gzip
import json
from app.db.redis_client import get_redis
from app.db.supabase_client import get_supabase

logger = structlog.get_logger()

async def get_realtime_departures(stop_id: str, now_secs: int, limit: int = 10) -> list:
    """
    Fetch departures for a stop, merging static schedules + real-time delays.
    Returns list of departures sorted by time.
    """
    redis_client = get_redis()
    supabase = get_supabase()

    # Step 1: Get static schedules from Supabase (pattern model)
    # (Same query as Phase 1, see PHASE_1 Section 10)
    query = """
    SELECT t.trip_id, r.route_short_name, r.route_id, p.route_id AS pattern_route_id, t.headsign,
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
    result = supabase.rpc('exec_raw_sql', {'query': query, 'params': [stop_id, now_secs, limit * 2]}).execute()
    static_deps = result.data

    # Step 2: Fetch real-time delays from Redis
    # Determine mode(s) from route_ids
    modes = set()
    for dep in static_deps:
        route_id = dep['route_id']
        # Heuristic: route_id prefix determines mode
        if route_id.startswith('T') or route_id.startswith('BMT'):
            modes.add('sydneytrains')
        elif route_id.startswith('M'):
            modes.add('metro')
        elif 'F' in route_id:
            modes.add('ferries')
        elif 'L' in route_id:
            modes.add('lightrail')
        else:
            modes.add('buses')

    # Fetch TripUpdates for all relevant modes
    trip_delays = {}  # trip_id -> delay_s
    for mode in modes:
        try:
            tu_blob = redis_client.get(f'tu:{mode}:v1')
            if tu_blob:
                tu_data = json.loads(gzip.decompress(tu_blob).decode('utf-8'))
                for trip in tu_data['trips']:
                    trip_delays[trip['trip_id']] = trip.get('delay_s', 0)
        except Exception as exc:
            logger.warn("tu_fetch_failed", mode=mode, error=str(exc))

    # Step 3: Merge static + real-time
    departures = []
    for dep in static_deps:
        trip_id = dep['trip_id']
        dep_secs = dep['dep_secs']
        delay_s = trip_delays.get(trip_id, 0)
        realtime_dep_secs = dep_secs + delay_s

        departures.append({
            'trip_id': trip_id,
            'route_short_name': dep['route_short_name'],
            'headsign': dep['headsign'],
            'scheduled_time_secs': dep_secs,
            'realtime_time_secs': realtime_dep_secs,
            'delay_s': delay_s,
            'realtime': delay_s != 0,
            'departure_time': format_time(realtime_dep_secs)
        })

    # Sort by realtime time, limit
    departures.sort(key=lambda d: d['realtime_time_secs'])
    return departures[:limit]


def format_time(secs: int) -> str:
    """Convert seconds since midnight to HH:MM format."""
    hours = secs // 3600
    mins = (secs % 3600) // 60
    return f"{hours:02d}:{mins:02d}"
```

**8. Update Stops API (app/api/v1/stops.py)**

Replace static departures endpoint from Phase 1:

```python
from app.services.realtime_service import get_realtime_departures

@router.get("/stops/{stop_id}/departures")
async def get_stop_realtime_departures(
    stop_id: str,
    time: str = None,  # HH:MM, default now
    limit: int = 10
):
    """Get real-time departures for a stop (merges static + GTFS-RT)."""
    # Default to now
    if not time:
        now_sydney = datetime.now(pytz.timezone('Australia/Sydney'))
        time = now_sydney.strftime('%H:%M')

    now_secs = int(time.split(':')[0]) * 3600 + int(time.split(':')[1]) * 60

    departures = await get_realtime_departures(stop_id, now_secs, limit)

    return SuccessResponse(data=departures)
```

**9. Test Real-Time API**
```bash
# Start backend + workers
# Wait 30s for first GTFS-RT poll

# Test departures endpoint
curl "http://localhost:8000/api/v1/stops/200060/departures"

# Expected response:
# {
#   "data": [
#     {
#       "trip_id": "...",
#       "route_short_name": "T1",
#       "headsign": "Emu Plains",
#       "scheduled_time_secs": 32400,
#       "realtime_time_secs": 32490,
#       "delay_s": 90,
#       "realtime": true,
#       "departure_time": "09:01"
#     },
#     ...
#   ]
# }
```

- [ ] API returns departures
- [ ] `realtime: true` for trips with delays
- [ ] `delay_s` reflects actual GTFS-RT data (not 0)
- [ ] Departures sorted by time

---

### iOS: Real-Time Departures UI

**10. Departure Model (Data/Models/Departure.swift)**

```swift
import Foundation

struct Departure: Codable, Identifiable {
    let trip_id: String
    let route_short_name: String
    let headsign: String
    let scheduled_time_secs: Int
    let realtime_time_secs: Int
    let delay_s: Int
    let realtime: Bool
    let departure_time: String

    var id: String { trip_id }

    var minutesUntil: Int {
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowSecs = (now.hour ?? 0) * 3600 + (now.minute ?? 0) * 60
        return max(0, (realtime_time_secs - nowSecs) / 60)
    }

    var delayText: String? {
        guard realtime && delay_s != 0 else { return nil }
        let mins = delay_s / 60
        return mins > 0 ? "+\(mins) min" : "\(mins) min"
    }
}
```

**11. Departures Repository (Data/Repositories/DeparturesRepository.swift)**

```swift
import Foundation

protocol DeparturesRepository {
    func fetchDepartures(stopId: String) async throws -> [Departure]
}

class DeparturesRepositoryImpl: DeparturesRepository {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchDepartures(stopId: String) async throws -> [Departure] {
        let endpoint = APIEndpoint.getDepartures(stopId: stopId)
        let response: SuccessResponse<[Departure]> = try await apiClient.request(endpoint)
        return response.data
    }
}
```

**12. API Endpoint (Core/Network/APIEndpoint.swift)**

```swift
enum APIEndpoint {
    case getDepartures(stopId: String)

    var path: String {
        switch self {
        case .getDepartures(let stopId):
            return "/stops/\(stopId)/departures"
        }
    }

    var url: URL {
        URL(string: Config.apiBaseURL + path)!
    }

    var request: URLRequest {
        URLRequest(url: url)
    }
}
```

**13. Departures ViewModel (Features/Departures/DeparturesViewModel.swift)**

```swift
import Foundation
import Combine

@MainActor
class DeparturesViewModel: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: DeparturesRepository
    private var refreshTimer: Timer?

    init(repository: DeparturesRepository) {
        self.repository = repository
    }

    func loadDepartures(stopId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            departures = try await repository.fetchDepartures(stopId: stopId)
            Logger.app.info("Departures loaded", metadata: ["stop_id": "\(stopId)", "count": "\(departures.count)"])
        } catch {
            errorMessage = "Failed to load departures"
            Logger.app.error("Departures load failed", metadata: ["stop_id": "\(stopId)", "error": "\(error)"])
        }

        isLoading = false
    }

    func startAutoRefresh(stopId: String) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task {
                await self?.loadDepartures(stopId: stopId)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
```

**14. Departures View (Features/Departures/DeparturesView.swift)**

```swift
import SwiftUI

struct DeparturesView: View {
    let stop: Stop
    @StateObject private var viewModel: DeparturesViewModel

    init(stop: Stop) {
        self.stop = stop
        _viewModel = StateObject(wrappedValue: DeparturesViewModel(
            repository: DeparturesRepositoryImpl(apiClient: APIClient.shared)
        ))
    }

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.departures.isEmpty {
                ProgressView("Loading...")
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
            } else if viewModel.departures.isEmpty {
                Text("No upcoming departures")
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.departures) { departure in
                    DepartureRow(departure: departure)
                }
            }
        }
        .navigationTitle(stop.name)
        .refreshable {
            await viewModel.loadDepartures(stopId: String(stop.sid))
        }
        .onAppear {
            Task {
                await viewModel.loadDepartures(stopId: String(stop.sid))
            }
            viewModel.startAutoRefresh(stopId: String(stop.sid))
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
    }
}

struct DepartureRow: View {
    let departure: Departure

    var body: some View {
        HStack {
            // Route badge
            Text(departure.route_short_name)
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(4)

            // Headsign
            VStack(alignment: .leading) {
                Text(departure.headsign)
                    .font(.body)
                if let delayText = departure.delayText {
                    Text(delayText)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Time until departure
            VStack(alignment: .trailing) {
                if departure.minutesUntil == 0 {
                    Text("Now")
                        .font(.headline)
                        .foregroundColor(.red)
                } else {
                    Text("\(departure.minutesUntil) min")
                        .font(.headline)
                }
                Text(departure.departure_time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

**15. Update Stop Details to Navigate to Departures**

In `StopDetailsView.swift`:
```swift
Section("Actions") {
    NavigationLink("View Departures") {
        DeparturesView(stop: stop)
    }
}
```

---

## Acceptance Criteria (Manual Testing)

### Backend Tests

**1. Celery Workers Running**
```bash
# Check worker logs
# Terminal 3 (worker_critical): Should see "poll_gtfs_rt_started" every 30s
# Terminal 4 (beat): Should see "Scheduler: Sending due task poll-gtfs-rt"
```
- [ ] Workers start without errors
- [ ] Beat schedules tasks
- [ ] Tasks execute successfully

**2. Redis Cache Populated**
```bash
redis-cli -u $REDIS_URL

# Check keys
KEYS vp:*  # Should list 5 keys (buses, sydneytrains, metro, ferries, lightrail)
KEYS tu:*  # Should list 5 keys

# Check one key
GET vp:buses:v1  # Returns gzipped blob (binary)
TTL vp:buses:v1  # Should be ~60-75s (refresh every 30s, TTL 75s)
```
- [ ] 10 keys total (5 VP, 5 TU)
- [ ] All keys have TTL
- [ ] Values are gzipped (binary, not plain JSON)

**3. Real-Time API Returns Live Data**
```bash
curl "http://localhost:8000/api/v1/stops/200060/departures"

# Check for delays
# Compare "scheduled_time_secs" vs "realtime_time_secs"
# If different → realtime working
# If same for all trips → check GTFS-RT data quality (may have no delays currently)
```
- [ ] API returns 200
- [ ] At least one departure has `realtime: true` and `delay_s != 0` (if NSW has delays)
- [ ] Departures sorted by realtime time

**4. Graceful Degradation (Stale Cache)**
```bash
# Stop Celery workers (Ctrl+C in worker terminals)
# Wait 2 minutes (TTL expires)

# Try departures API again
curl "http://localhost:8000/api/v1/stops/200060/departures"

# Should still return data (static schedules), but all realtime: false
```
- [ ] API still returns 200 (doesn't crash)
- [ ] Departures based on static schedules (no delays)

---

### iOS Tests

**1. Departures Screen Displays Live Data**
- [ ] Launch app
- [ ] Navigate to stop (e.g., Circular Quay)
- [ ] Tap "View Departures"
- [ ] List of departures appears
- [ ] Delays shown (orange "+X min" badge)
- [ ] "Minutes until" updates every refresh

**2. Auto-Refresh Works**
- [ ] Stay on departures screen
- [ ] Wait 30s
- [ ] Screen auto-refreshes (see loading indicator briefly)
- [ ] Times update (minutes until decrease)

**3. Pull-to-Refresh Works**
- [ ] Pull down on departures list
- [ ] Loading indicator appears
- [ ] Data refreshes

**4. Offline Mode (Graceful Degradation)**
- [ ] Disable Wi-Fi on Mac
- [ ] Re-launch app
- [ ] Navigate to departures
- [ ] Shows error: "Failed to load departures"
- [ ] Does NOT crash

---

## Troubleshooting

### Backend Issues

**Problem:** Celery worker crashes with "Connection refused"
- **Solution:** Verify Redis URL in `.env` (should match Railway connection string)
- Test: `redis-cli -u $REDIS_URL PING`

**Problem:** "gtfs_realtime_pb2 not found"
- **Solution:** Install protobuf bindings: `pip install gtfs-realtime-bindings`

**Problem:** GTFS-RT fetch returns 403 (rate limit)
- **Solution:** Check NSW API rate limit (5 req/s)
- Reduce polling frequency temporarily (60s instead of 30s)
- Verify API key quota in NSW dashboard

**Problem:** Redis keys expire before next poll
- **Solution:** TTL too short (should be >poll interval)
- Change TTL to 75s (VP), 90s (TU)

**Problem:** Real-time departures show no delays (all `delay_s: 0`)
- **Solution:** NSW may have no delays currently (Sydney trains are reliable!)
- Test with buses during peak hour (more likely to have delays)
- Check GTFS-RT feed directly: Parse protobuf, verify `delay` field exists

### iOS Issues

**Problem:** Departures screen empty (no data)
- **Solution:** Check network connection
- Verify backend API returns data: `curl http://localhost:8000/api/v1/stops/200060/departures`
- Check APIClient logs in Xcode console

**Problem:** Auto-refresh doesn't work
- **Solution:** Verify Timer is scheduled on main thread
- Check ViewModel lifecycle (timer may be invalidated too early)

**Problem:** Times don't update (stuck on "5 min")
- **Solution:** `minutesUntil` calculation uses current time, but SwiftUI doesn't re-render automatically
- Force re-render on timer tick: Update `@Published` property or use `.id()` modifier

---

## Git Workflow

```bash
git checkout -b phase-2-realtime

git add backend/app/tasks/
git commit -m "feat: add Celery workers for GTFS-RT polling"

git add backend/app/services/realtime_service.py
git commit -m "feat: add real-time departures service"

git add SydneyTransit/Features/Departures/
git commit -m "feat: add real-time departures UI"

git add .
git commit -m "feat: phase 2 real-time foundation complete"
git tag phase-2-complete
git checkout main
git merge phase-2-realtime
```

---

## Deliverables Checklist

**Backend:**
- [ ] Celery setup (3 queues, 2 workers, Beat scheduler)
- [ ] GTFS-RT poller (30s interval, Redis blob caching)
- [ ] Real-time departures API (merges static + RT)
- [ ] Graceful degradation (stale cache fallback)

**iOS:**
- [ ] Departures screen (real-time data)
- [ ] Auto-refresh (30s timer)
- [ ] Pull-to-refresh
- [ ] Delay badges (orange "+X min")

**Infrastructure:**
- [ ] Redis cache working (<20MB memory)
- [ ] Celery workers running in background
- [ ] Logs structured (JSON format)

---

## Next Phase Preview

**Phase 3: User Features**
- Supabase Auth (Apple Sign-In)
- Favorites API (CRUD, sync)
- iOS auth flow (token storage)
- RLS policies (user data isolation)

**Estimated Start:** Week 9

---

**End of PHASE_2_REALTIME.md**
