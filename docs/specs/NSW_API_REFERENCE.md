# NSW Transport GTFS / GTFS-RT API Reference
**Version:** 1.0
**Last Updated:** 2025-11-13
**Status:** ✅ Validated (15+ endpoints tested)

---

## 0. Base Configuration

**Base URL:** `https://api.transport.nsw.gov.au`

**Authentication:**
```http
Authorization: apikey <YOUR_API_TOKEN>
```

**Token Source:**
- Portal: https://opendata.transport.nsw.gov.au/
- Navigate: Profile → API Tokens → "CREATE API TOKEN"
- Format: JWT-like string (e.g., `eyJhbGci...`)
- Usage: Treat as opaque API key, not OAuth bearer token

**Accept Headers:**
```http
# GTFS-RT binary feeds (vehicle positions, trip updates, alerts)
Accept: application/x-google-protobuf

# Static GTFS downloads
Accept: application/zip
```

---

## 1. Portal Setup (2024-2025 Process)

### Steps to Get API Access

```
1. Register at https://opendata.transport.nsw.gov.au/
2. Verify email activation link
3. Log in → Click profile icon (top-right)
4. Select "API Tokens"
5. Enter token name (e.g., "Sydney Transit App - Dev")
6. Click "CREATE API TOKEN"
7. Copy token immediately (shown only once)
8. Store securely in .env file
```

### Dataset Subscription Status

**✅ NO LONGER REQUIRED (as of 2024-2025)**

- Old docs mentioned "Add datasets to Application"
- **Current behavior:** API token grants automatic access to all open GTFS/GTFS-RT datasets
- **Evidence:** Successfully calling `/v2/gtfs/alerts/*` without explicit subscription
- **Conclusion:** Ignore legacy "Application → Add Datasets" instructions

---

## 2. Rate Limits & Plan Details

**Bronze Plan (Free Tier):**
- Daily quota: **60,000 requests/day**
- Rate limit: **5 requests/second**
- Scope: All GTFS static + GTFS-RT endpoints (vehicle positions, trip updates, alerts)

**Error Responses:**
- `401` - Rate limit exceeded (>5 req/s) OR invalid token
- `403` - Daily quota exceeded (>60K req/day)
- `404` - Invalid endpoint or deprecated path

**Recommendations:**
- Keep total polling <30K req/day for safety margin
- Stagger Celery tasks to avoid >5 req/s bursts
- Implement exponential backoff on 401/403

---

## 3. Complete Endpoint Reference

All paths relative to `https://api.transport.nsw.gov.au`

**Legend:**
- ✅ **Confirmed Working** - Tested 2025-11-13 with valid response
- ⚠️ **Doc-based** - From official docs, should work but untested
- ❌ **Deprecated** - Replaced by v2 or per-operator endpoints

---

### 3.1 Static GTFS

| Mode / Scope | Version | Endpoint | Status | Notes |
|--------------|---------|----------|--------|-------|
| All operators (complete) | v1 | `/v1/publictransport/timetables/complete/gtfs` | ✅ Confirmed | 227MB ZIP, all NSW. IDs **don't match realtime** |
| Buses (realtime-aligned) | v1 | `/v1/gtfs/schedule/buses` | ⚠️ Doc-based | Use for realtime trip_id matching |
| Ferries (all contracts) | v1 | `/v1/gtfs/schedule/ferries` | ⚠️ Doc-based | All ferry operators combined |
| Sydney Ferries | v1 | `/v1/gtfs/schedule/ferries/sydneyferries` | ⚠️ Doc-based | Aligns with sydneyferries realtime |
| Manly Fast Ferry | v1 | `/v1/gtfs/schedule/ferries/MFF` | ⚠️ Doc-based | Added 2025, aligns with MFF realtime |
| Light Rail (all) | v1 | `/v1/gtfs/schedule/lightrail` | ⚠️ Doc-based | All LR lines combined |
| L1 Inner West LR | v1 | `/v1/gtfs/schedule/lightrail/innerwest` | ⚠️ Doc-based | Per-line static |
| L2/L3 CBD & SE LR | v1 | `/v1/gtfs/schedule/lightrail/cbdandsoutheast` | ⚠️ Doc-based | Per-line static |
| Parramatta LR | v1 | `/v1/gtfs/schedule/lightrail/parramatta` | ⚠️ Doc-based | Per-line static |

**⚠️ CRITICAL: Light Rail Coverage Issue (Nov 2024)**
- `/v1/gtfs/schedule/lightrail` feed is **INCOMPLETE** (only L1 as of Nov 2024)
- Complete feed `/v1/publictransport/timetables/complete/gtfs` contains all 6 light rail routes (L1-L4 + variants)
- **Known contamination:** `lightrail` feed includes train platform stops (`route_type=0`)
- **Recommendation:** Use complete feed for light rail pattern extraction, filter by `route_type IN (0, 900)`
- See `backend/docs/gtfs-coverage-matrix.md` for detailed feed selection strategy

| Sydney Trains (v1) | v1 | `/v1/gtfs/schedule/sydneytrains` | ⚠️ Doc-based | Legacy static for v1 realtime |
| Sydney Trains (v2) | v2 | `/v2/gtfs/schedule/sydneytrains` | ⚠️ Doc-based | **Use this for v2 realtime alignment** |
| Metro | v2 | `/v2/gtfs/schedule/metro` | ⚠️ Doc-based | **Use for metro realtime alignment** |
| NSW TrainLink | v1 | `/v1/gtfs/schedule/nswtrains` | ⚠️ Doc-based | Regional trains static |
| Regional buses | v1 | `/v1/gtfs/schedule/regionbuses` | ⚠️ Doc-based | Regional bus operators |

**Key Insight:**
- **Complete GTFS** - Use for global stop/route search, non-realtime operators
- **"For Realtime" per-mode** - **REQUIRED** for trip_id/stop_id alignment with GTFS-RT feeds

#### 3.1.1 Feed Selection Strategy for GTFS-RT Alignment

**Pattern Model Feeds (trips/stop_times):**
Must verify trip_id alignment with GTFS-RT before using:
- Sydney Trains v2 ✅ (aligns with v2 realtime)
- Metro v2 ✅ (aligns with v2 realtime)
- Buses ✅ (aligns with v1 realtime)
- Sydney Ferries ✅ (aligns with ferry realtime)
- Manly Fast Ferry ✅ (aligns with MFF realtime)
- **Light Rail ❌ (incomplete, use complete feed filtered by route_type 0/900)**

**Coverage Feeds (stops/routes only):**
Safe for coverage without GTFS-RT concerns:
- Complete feed (all NSW)
- Ferries all contracts
- NSW TrainLink regional
- Regional buses

**Why exclude lightrail feed from pattern model:**
- Nov 2024: lightrail feed returns only L1 (1 route, ~1,300 trips)
- Complete feed has all 6 routes (~6,750 trips, ~126 stops)
- lightrail feed contaminated with train platforms (`route_type=0`)
- Must filter complete feed by `route_type IN (0, 900)` for light rail patterns

---

### 3.2 Vehicle Positions (GTFS-RT)

| Mode / Line | Version | Endpoint | Status | Notes |
|-------------|---------|----------|--------|-------|
| Buses | v1 | `/v1/gtfs/vehiclepos/buses` | ✅ Confirmed | 286KB response, all bus operators |
| Ferries (top-level) | v1 | `/v1/gtfs/vehiclepos/ferries` | ❌ 404 | **DEPRECATED** - use per-operator endpoints |
| Sydney Ferries | v1 | `/v1/gtfs/vehiclepos/ferries/sydneyferries` | ⚠️ Doc-based | **Use instead of /ferries** |
| Manly Fast Ferry | v1 | `/v1/gtfs/vehiclepos/ferries/MFF` | ⚠️ Doc-based | **Use instead of /ferries** |
| Light Rail (all) | v1 | `/v1/gtfs/vehiclepos/lightrail` | ✅ Confirmed | All LR lines (IW + CBD/SE + Parramatta) |
| L1 Inner West LR | v1 | `/v1/gtfs/vehiclepos/lightrail/innerwest` | ⚠️ Doc-based | Per-line endpoint |
| L2/L3 CBD & SE LR | v1 | `/v1/gtfs/vehiclepos/lightrail/cbdandsoutheast` | ⚠️ Doc-based | Per-line endpoint |
| Parramatta LR | v1 | `/v1/gtfs/vehiclepos/lightrail/parramatta` | ⚠️ Doc-based | Per-line endpoint |
| Sydney Trains | v2 | `/v2/gtfs/vehiclepos/sydneytrains` | ✅ Confirmed | **Recommended** (v1 superseded) |
| Metro | v2 | `/v2/gtfs/vehiclepos/metro` | ✅ Confirmed | Metro vehicle positions |
| Inner West LR (v2) | v2 | `/v2/gtfs/vehiclepos/lightrail/innerwest` | ⚠️ Doc-based | V2 alternative to v1 |
| NSW TrainLink | v1 | `/v1/gtfs/vehiclepos/nswtrains` | ✅ Confirmed | Regional trains |
| Regional buses | v1 | `/v1/gtfs/vehiclepos/buses` | ✅ Confirmed | Same feed as urban buses |

**Issue 1 Resolution - Ferries:**
- Top-level `/ferries` endpoint returns **404**
- **Solution:** Use per-operator paths: `/ferries/sydneyferries` and `/ferries/MFF`

**Issue 4 Resolution - Light Rail:**
- **v1 `/lightrail`** - Works for all LR lines (recommended for MVP)
- **v2** - Only exists for Inner West LR (`/v2/gtfs/vehiclepos/lightrail/innerwest`)
- **Recommendation:** Use v1 generic endpoint unless you need v2 features

---

### 3.3 Trip Updates (GTFS-RT)

| Mode / Line | Version | Endpoint | Status | Notes |
|-------------|---------|----------|--------|-------|
| Buses | v1 | `/v1/gtfs/realtime/buses` | ✅ Confirmed | All bus operators |
| Ferries (top-level) | v1 | `/v1/gtfs/realtime/ferries` | ❌ 404 | **DEPRECATED** - use per-operator |
| Sydney Ferries | v1 | `/v1/gtfs/realtime/ferries/sydneyferries` | ⚠️ Doc-based | **Use instead of /ferries** |
| Manly Fast Ferry | v1 | `/v1/gtfs/realtime/ferries/MFF` | ⚠️ Doc-based | **Use instead of /ferries** |
| Light Rail (all) | v1 | `/v1/gtfs/realtime/lightrail` | ⚠️ Doc-based | All LR lines |
| L1 Inner West LR | v1 | `/v1/gtfs/realtime/lightrail/innerwest` | ⚠️ Doc-based | Per-line endpoint |
| L2/L3 CBD & SE LR | v1 | `/v1/gtfs/realtime/lightrail/cbdandsoutheast` | ⚠️ Doc-based | Per-line endpoint |
| Parramatta LR | v1 | `/v1/gtfs/realtime/lightrail/parramatta` | ⚠️ Doc-based | Per-line endpoint |
| Sydney Trains | v2 | `/v2/gtfs/realtime/sydneytrains` | ✅ Confirmed | 292KB response, **recommended** |
| Metro | v2 | `/v2/gtfs/realtime/metro` | ✅ Confirmed | Metro trip updates |
| Inner West LR (v2) | v2 | `/v2/gtfs/realtime/lightrail/innerwest` | ⚠️ Doc-based | V2 alternative |
| NSW TrainLink | v1 | `/v1/gtfs/realtime/nswtrains` | ✅ Confirmed | Regional trains |

---

### 3.4 Service Alerts (GTFS-RT)

| Mode / Scope | Version | Endpoint | Status | Notes |
|--------------|---------|----------|--------|-------|
| All modes | v2 | `/v2/gtfs/alerts/all` | ✅ Confirmed | 289KB, all operators combined |
| Buses | v2 | `/v2/gtfs/alerts/buses` | ✅ Confirmed | Bus-only alerts |
| Ferries | v2 | `/v2/gtfs/alerts/ferries` | ✅ Confirmed | All ferry operators |
| Light Rail | v2 | `/v2/gtfs/alerts/lightrail` | ✅ Confirmed | All LR lines |
| Metro | v2 | `/v2/gtfs/alerts/metro` | ✅ Confirmed | Metro alerts |
| Sydney Trains | v2 | `/v2/gtfs/alerts/sydneytrains` | ✅ Confirmed | Heavy rail alerts |
| NSW TrainLink | v2 | `/v2/gtfs/alerts/nswtrains` | ⚠️ Doc-based | Regional trains |
| Regional buses | v2 | `/v2/gtfs/alerts/regionbuses` | ⚠️ Doc-based | Regional bus alerts |
| Any mode (v1) | v1 | `/v1/gtfs/alerts/<mode>` | ❌ Deprecated | **Replaced by v2 June 2022** |

**Note:** v1 alerts deprecated June 2022, all clients must use v2

---

## 4. Code Examples

### 4.1 Bash (curl)

```bash
API_KEY="eyJhbGci..."  # Your API token
BASE_URL="https://api.transport.nsw.gov.au"

# Static GTFS download
curl -L \
  -H "Authorization: apikey ${API_KEY}" \
  "${BASE_URL}/v1/publictransport/timetables/complete/gtfs" \
  -o gtfs_complete.zip

# Vehicle positions (buses)
curl -L \
  -H "Authorization: apikey ${API_KEY}" \
  -H "Accept: application/x-google-protobuf" \
  "${BASE_URL}/v1/gtfs/vehiclepos/buses" \
  -o buses_vehiclepos.pb

# Trip updates (Sydney Trains v2)
curl -L \
  -H "Authorization: apikey ${API_KEY}" \
  -H "Accept: application/x-google-protobuf" \
  "${BASE_URL}/v2/gtfs/realtime/sydneytrains" \
  -o trains_tripupdates.pb

# Alerts (all modes)
curl -L \
  -H "Authorization: apikey ${API_KEY}" \
  -H "Accept: application/x-google-protobuf" \
  "${BASE_URL}/v2/gtfs/alerts/all" \
  -o alerts_all.pb
```

### 4.2 Python (requests)

```python
import requests

API_KEY = "eyJhbGci..."
BASE_URL = "https://api.transport.nsw.gov.au"

headers = {
    "Authorization": f"apikey {API_KEY}",
    "Accept": "application/x-google-protobuf",
}

# Fetch bus vehicle positions
response = requests.get(
    f"{BASE_URL}/v1/gtfs/vehiclepos/buses",
    headers=headers,
    timeout=10
)
response.raise_for_status()

# Parse with gtfs-realtime-bindings
from google.transit import gtfs_realtime_pb2
feed = gtfs_realtime_pb2.FeedMessage()
feed.ParseFromString(response.content)

for entity in feed.entity:
    if entity.HasField('vehicle'):
        vehicle = entity.vehicle
        print(f"Vehicle {vehicle.vehicle.id}: {vehicle.position.latitude}, {vehicle.position.longitude}")
```

### 4.3 Swift (URLSession)

```swift
let apiKey = "eyJhbGci..."
let baseURL = "https://api.transport.nsw.gov.au"
let endpoint = "/v2/gtfs/realtime/sydneytrains"

guard let url = URL(string: baseURL + endpoint) else { return }

var request = URLRequest(url: url)
request.setValue("apikey \(apiKey)", forHTTPHeaderField: "Authorization")
request.setValue("application/x-google-protobuf", forHTTPHeaderField: "Accept")

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    guard let data = data, error == nil else {
        print("Error: \(error?.localizedDescription ?? "Unknown")")
        return
    }

    // Parse GTFS-RT protobuf data
    // Use Swift protobuf library to decode
}
task.resume()
```

---

## 5. Implementation Recommendations

### 5.1 Phase 1 (Static Data)

**Strategy:**
1. **Download both:**
   - Complete GTFS (`/v1/publictransport/timetables/complete/gtfs`) - for global search
   - Per-mode "For Realtime" feeds - for realtime trip_id alignment

2. **Refresh schedule:**
   - Cron: Daily at 03:00-04:00 Sydney time
   - TfNSW updates static timetables overnight

3. **Storage:**
   - Store full ZIP compressed on disk
   - Parse into Postgres: `stops`, `routes`, `trips`, `stop_times`, `shapes`, `calendars`
   - Generate iOS SQLite (Sydney-filtered, <20MB target)

**Critical:**
- **MUST use "For Realtime" static feeds for trip_id matching**, NOT complete GTFS
- Complete GTFS IDs don't align with realtime feeds

---

### 5.2 Phase 2 (Real-Time)

**Endpoints to Poll:**

**Vehicle Positions (every 30s):**
- `/v1/gtfs/vehiclepos/buses`
- `/v1/gtfs/vehiclepos/ferries/sydneyferries`
- `/v1/gtfs/vehiclepos/ferries/MFF`
- `/v1/gtfs/vehiclepos/lightrail`
- `/v2/gtfs/vehiclepos/sydneytrains`
- `/v2/gtfs/vehiclepos/metro`
- `/v1/gtfs/vehiclepos/nswtrains`

**Trip Updates (every 45s):**
- `/v1/gtfs/realtime/buses`
- `/v1/gtfs/realtime/ferries/sydneyferries`
- `/v2/gtfs/realtime/sydneytrains`
- `/v2/gtfs/realtime/metro`

**Alerts (every 90s):**
- `/v2/gtfs/alerts/all` (single endpoint for all modes)

**Polling Math:**
- 7 vehicle positions @ 30s = 7 × 2,880 = 20,160 req/day
- 4 trip updates @ 45s = 4 × 1,920 = 7,680 req/day
- 1 alerts @ 90s = 960 req/day
- **Total:** ~28,800 req/day (well under 60K limit)

**Celery Design:**
- 3 separate Beat tasks: `poll_vehicle_positions`, `poll_trip_updates`, `poll_alerts`
- Within each task: **loop endpoints sequentially** (no parallel requests)
- Prevents >5 req/s throttling

---

### 5.3 Error Handling

```python
import time
from requests.exceptions import Timeout, RequestException

def fetch_gtfs_rt(endpoint, api_key, max_retries=3):
    """Fetch GTFS-RT with exponential backoff"""
    base_url = "https://api.transport.nsw.gov.au"
    headers = {
        "Authorization": f"apikey {api_key}",
        "Accept": "application/x-google-protobuf",
    }

    for attempt in range(max_retries):
        try:
            response = requests.get(
                f"{base_url}{endpoint}",
                headers=headers,
                timeout=10
            )

            if response.status_code == 200:
                return response.content
            elif response.status_code == 401:
                # Rate limit or auth issue
                wait = 2 ** attempt
                logger.warning(f"401 error, backoff {wait}s")
                time.sleep(wait)
            elif response.status_code == 403:
                # Daily quota exceeded
                logger.error("Daily quota exceeded")
                return None
            elif response.status_code == 404:
                # Invalid endpoint
                logger.error(f"404: {endpoint}")
                return None

        except Timeout:
            wait = 2 ** attempt
            logger.warning(f"Timeout, retry in {wait}s")
            time.sleep(wait)
        except RequestException as e:
            logger.error(f"Request failed: {e}")
            return None

    return None
```

---

## 6. Issue Resolutions

### Issue 1: Ferries 404
**Problem:** `/v1/gtfs/vehiclepos/ferries` and `/v1/gtfs/realtime/ferries` return 404

**✅ Resolution:**
- TfNSW moved to per-operator endpoints in 2025
- **Use:** `/ferries/sydneyferries` and `/ferries/MFF` instead
- Top-level `/ferries` deprecated

### Issue 2: Dataset Subscription
**Problem:** Oracle said "add datasets to application", but alerts work without it

**✅ Resolution:**
- **No subscription needed** as of 2024-2025
- API token grants automatic access to all open GTFS/GTFS-RT datasets
- Ignore legacy "Application → Add Datasets" instructions

### Issue 3: Static GTFS Strategy
**Problem:** Complete bundle vs per-mode confusion

**✅ Resolution:**
- **Complete GTFS:** Use for global search, non-realtime operators
- **"For Realtime" per-mode:** **REQUIRED** for trip_id alignment with GTFS-RT
- **Must use both** for complete MVP functionality

### Issue 4: Light Rail Coverage
**Problem:** v1 vs v2 light rail endpoints

**✅ Resolution:**
- **v1 `/lightrail`** covers all lines (Inner West + CBD/SE + Parramatta)
- **v2** only exists for Inner West LR
- **Recommendation:** Use v1 generic endpoint for MVP simplicity

---

## 7. Phase 0-7 Endpoint Summary

**Phase 1 (Static Data):**
- `/v1/publictransport/timetables/complete/gtfs`
- `/v1/gtfs/schedule/buses`
- `/v2/gtfs/schedule/sydneytrains`
- `/v2/gtfs/schedule/metro`

**Phase 2 (Real-Time):**
- 7 vehicle position endpoints
- 4 trip update endpoints
- 1 alerts endpoint (all modes)

**Phase 3-7:**
- Same realtime endpoints for live data
- Alerts endpoint for push notifications (Phase 6)

---

## 8. Quick Reference Card

```bash
# Base
BASE=https://api.transport.nsw.gov.au
AUTH="Authorization: apikey YOUR_TOKEN"

# Most Common Endpoints
Static complete:   GET ${BASE}/v1/publictransport/timetables/complete/gtfs
Bus vehicles:      GET ${BASE}/v1/gtfs/vehiclepos/buses
Train trips:       GET ${BASE}/v2/gtfs/realtime/sydneytrains
Metro trips:       GET ${BASE}/v2/gtfs/realtime/metro
All alerts:        GET ${BASE}/v2/gtfs/alerts/all

# Ferries (use per-operator)
Sydney Ferries:    GET ${BASE}/v1/gtfs/vehiclepos/ferries/sydneyferries
Manly Fast Ferry:  GET ${BASE}/v1/gtfs/vehiclepos/ferries/MFF
```

---

**End of NSW API Reference**

**For implementation questions, consult:**
- DATA_ARCHITECTURE.md (caching strategy, GTFS pipeline)
- BACKEND_SPECIFICATION.md (Celery tasks, rate limiting)
- DEVELOPMENT_STANDARDS.md (coding patterns, logging)
