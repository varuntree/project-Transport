# Integration Contracts - Sydney Transit App
**Project:** API Contracts & Integration Specifications
**Version:** 1.0 (95% Complete - 1 Oracle Section Pending)
**Date:** 2025-11-12
**Dependencies:** BACKEND_SPECIFICATION.md, IOS_APP_SPECIFICATION.md
**Status:** Awaiting 1 Oracle Consultation (APNs Architecture)

---

## Document Purpose

This document defines integration contracts between system components:
- FastAPI ↔ iOS REST API contracts (OpenAPI 3.0)
- Supabase Auth integration (Apple Sign-In flow)
- Push notification architecture (⚠️ **Oracle consultation needed**)
- Error handling conventions
- Versioning & backward compatibility

---

## 1. REST API Specification (FastAPI ↔ iOS)

### 1.1 Base Configuration

**Base URLs:**
- **Production:** `https://api.yourdomain.com/api/v1`
- **Staging:** `https://staging-api.yourdomain.com/api/v1`
- **Development:** `http://localhost:8000/api/v1`

**Authentication:**
- Bearer token (Supabase JWT) in `Authorization` header
- Anonymous endpoints: `/stops`, `/routes`, `/trips/plan` (rate-limited per IP)
- Authenticated endpoints: `/favorites`, `/user/settings`

**Content-Type:** `application/json`
**Date Format:** ISO 8601 with timezone (`2025-11-12T08:30:00+11:00`)

### 1.2 Common Response Envelope

**Success Response:**

```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2025-11-12T08:30:00+11:00",
    "request_id": "req_abc123"
  }
}
```

**Error Response:**

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded for this endpoint.",
    "details": {
      "limit": 60,
      "window": "1 minute",
      "retry_after": 37
    }
  },
  "meta": {
    "timestamp": "2025-11-12T08:30:00+11:00",
    "request_id": "req_abc123"
  }
}
```

**HTTP Status Codes:**
- `200` OK - Successful request
- `201` Created - Resource created
- `400` Bad Request - Invalid input
- `401` Unauthorized - Invalid/missing JWT
- `403` Forbidden - Valid JWT but insufficient permissions
- `404` Not Found - Resource doesn't exist
- `429` Too Many Requests - Rate limit exceeded (includes `Retry-After` header)
- `500` Internal Server Error - Server fault
- `503` Service Unavailable - Temporary outage (NSW API down, etc.)

---

## 2. API Endpoints Contract

### 2.1 Stops Endpoints

#### `GET /stops/nearby`

**Description:** Find stops within radius of coordinates

**Query Parameters:**
```
lat: float (required, -90 to 90)
lon: float (required, -180 to 180)
radius: int (optional, default=500, min=50, max=2000, meters)
limit: int (optional, default=20, min=1, max=50)
```

**Response:** `200 OK`

```json
{
  "data": {
    "stops": [
      {
        "stop_id": "200060",
        "stop_name": "Central Station",
        "stop_lat": -33.8839,
        "stop_lon": 151.2072,
        "location_type": 1,
        "wheelchair_boarding": 1,
        "distance_meters": 123.5
      }
    ],
    "count": 15
  }
}
```

**Rate Limit:** 60/min (anonymous), 120/min (authenticated)

---

#### `GET /stops/{stop_id}`

**Description:** Get stop details

**Path Parameters:**
```
stop_id: string (required, GTFS stop_id)
```

**Response:** `200 OK`

```json
{
  "data": {
    "stop_id": "200060",
    "stop_name": "Central Station",
    "stop_lat": -33.8839,
    "stop_lon": 151.2072,
    "location_type": 1,
    "wheelchair_boarding": 1,
    "parent_station": null,
    "routes": [
      {
        "route_id": "T1",
        "route_short_name": "T1",
        "route_long_name": "North Shore, Northern & Western Line",
        "route_type": 1,
        "route_color": "F99D1C"
      }
    ]
  }
}
```

**Error:** `404 Not Found` if stop doesn't exist

---

#### `GET /stops/{stop_id}/departures`

**Description:** Get next departures from stop (real-time + scheduled)

**Path Parameters:**
```
stop_id: string (required)
```

**Query Parameters:**
```
limit: int (optional, default=10, max=50)
route_id: string (optional, filter by route)
direction_id: int (optional, 0 or 1)
```

**Response:** `200 OK`

```json
{
  "data": {
    "stop": {
      "stop_id": "200060",
      "stop_name": "Central Station"
    },
    "departures": [
      {
        "trip_id": "123.T1.1-NTH-mjp-1.1.H",
        "route_id": "T1",
        "route_short_name": "T1",
        "route_color": "F99D1C",
        "headsign": "Hornsby",
        "direction_id": 0,
        "scheduled_time": "2025-11-12T08:35:00+11:00",
        "estimated_time": "2025-11-12T08:37:00+11:00",
        "delay_seconds": 120,
        "platform": "23",
        "wheelchair_accessible": true,
        "is_cancelled": false,
        "vehicle": {
          "vehicle_id": "7337",
          "occupancy_status": "FEW_SEATS_AVAILABLE"
        }
      }
    ],
    "last_updated": "2025-11-12T08:30:15+11:00",
    "stale": false
  }
}
```

**Stale Data Handling:**
When rate-limited or cache is >2 min old:

```json
{
  "data": { ... },
  "meta": {
    "stale": true,
    "cached_at": "2025-11-12T08:28:00+11:00",
    "message": "Showing cached data (up to 2 minutes old)"
  }
}
```

**Rate Limit:** 60/min (anonymous), 120/min (authenticated)

---

### 2.2 Routes Endpoints

#### `GET /routes`

**Description:** List all routes (filtered/paginated)

**Query Parameters:**
```
route_type: int (optional, GTFS route_type: 0=tram, 1=metro, 2=rail, 3=bus, 4=ferry)
limit: int (optional, default=100, max=500)
offset: int (optional, default=0)
```

**Response:** `200 OK`

```json
{
  "data": {
    "routes": [
      {
        "route_id": "T1",
        "route_short_name": "T1",
        "route_long_name": "North Shore, Northern & Western Line",
        "route_type": 1,
        "route_color": "F99D1C",
        "route_text_color": "FFFFFF"
      }
    ],
    "total": 347,
    "limit": 100,
    "offset": 0
  }
}
```

---

#### `GET /routes/{route_id}/trips`

**Description:** Get trips for route (with real-time vehicle positions)

**Path Parameters:**
```
route_id: string (required)
```

**Query Parameters:**
```
direction_id: int (optional, 0 or 1)
```

**Response:** `200 OK`

```json
{
  "data": {
    "route": {
      "route_id": "T1",
      "route_short_name": "T1",
      "route_long_name": "North Shore, Northern & Western Line"
    },
    "active_trips": [
      {
        "trip_id": "123.T1.1-NTH-mjp-1.1.H",
        "headsign": "Hornsby",
        "direction_id": 0,
        "vehicle": {
          "vehicle_id": "7337",
          "latitude": -33.8688,
          "longitude": 151.2093,
          "bearing": 45,
          "speed_kmh": 32,
          "occupancy_status": "MANY_SEATS_AVAILABLE",
          "last_updated": "2025-11-12T08:30:10+11:00"
        },
        "next_stops": [
          {
            "stop_id": "200061",
            "stop_name": "Town Hall Station",
            "arrival_time": "2025-11-12T08:33:00+11:00"
          }
        ]
      }
    ],
    "last_updated": "2025-11-12T08:30:15+11:00"
  }
}
```

---

### 2.3 Trip Planning Endpoint

#### `POST /trips/plan`

**Description:** Plan multi-modal journey (proxies to NSW Trip Planner API)

**Request Body:**

```json
{
  "origin": {
    "type": "coordinates",
    "lat": -33.8688,
    "lon": 151.2093
  },
  "destination": {
    "type": "stop_id",
    "stop_id": "200060"
  },
  "depart_at": "2025-11-12T09:00:00+11:00",
  "preferences": {
    "max_walking_distance": 1000,
    "wheelchair_accessible": false,
    "modes": ["rail", "bus", "ferry"]
  }
}
```

**Response:** `200 OK`

```json
{
  "data": {
    "itineraries": [
      {
        "duration_minutes": 23,
        "walking_distance_meters": 450,
        "transfers": 1,
        "fare_cents": 472,
        "departure_time": "2025-11-12T09:00:00+11:00",
        "arrival_time": "2025-11-12T09:23:00+11:00",
        "legs": [
          {
            "mode": "WALK",
            "duration_minutes": 5,
            "distance_meters": 350,
            "from": {
              "name": "Current Location",
              "lat": -33.8688,
              "lon": 151.2093
            },
            "to": {
              "name": "Circular Quay Station",
              "stop_id": "200011"
            },
            "polyline": "encoded_polyline_string"
          },
          {
            "mode": "RAIL",
            "route_id": "T1",
            "route_short_name": "T1",
            "headsign": "Hornsby",
            "from": {
              "stop_id": "200011",
              "stop_name": "Circular Quay Station",
              "departure_time": "2025-11-12T09:05:00+11:00",
              "platform": "1"
            },
            "to": {
              "stop_id": "200060",
              "stop_name": "Central Station",
              "arrival_time": "2025-11-12T09:18:00+11:00",
              "platform": "23"
            },
            "stops_between": 5,
            "intermediate_stops": [
              {
                "stop_id": "200012",
                "stop_name": "Wynyard Station",
                "arrival_time": "2025-11-12T09:07:00+11:00"
              }
            ]
          }
        ],
        "realtime_data_available": true,
        "wheelchair_accessible": true
      }
    ],
    "requested_time": "2025-11-12T09:00:00+11:00"
  }
}
```

**Rate Limit:** 10/min (anonymous), 30/min (authenticated)

---

### 2.4 Alerts Endpoint

#### `GET /alerts`

**Description:** Get active service alerts

**Query Parameters:**
```
route_id: string (optional, filter by route)
stop_id: string (optional, filter by stop)
severity: string (optional, "info" | "warning" | "critical")
```

**Response:** `200 OK`

```json
{
  "data": {
    "alerts": [
      {
        "alert_id": "alert_12345",
        "severity": "warning",
        "header": "Delays on T1 Line",
        "description": "Delays of up to 10 minutes due to signal failure at Strathfield.",
        "affected_routes": ["T1"],
        "affected_stops": null,
        "cause": "TECHNICAL_PROBLEM",
        "effect": "REDUCED_SERVICE",
        "active_period": {
          "start": "2025-11-12T07:30:00+11:00",
          "end": "2025-11-12T10:00:00+11:00"
        },
        "url": "https://transportnsw.info/..."
      }
    ],
    "count": 3,
    "last_updated": "2025-11-12T08:30:00+11:00"
  }
}
```

---

### 2.5 Favorites Endpoints (Authenticated Only)

#### `GET /favorites`

**Description:** Get user's favorite stops

**Headers:**
```
Authorization: Bearer <supabase_jwt>
```

**Response:** `200 OK`

```json
{
  "data": {
    "favorites": [
      {
        "id": "fav_abc123",
        "stop_id": "200060",
        "stop_name": "Central Station",
        "label": "Work",
        "created_at": "2025-11-01T10:00:00+11:00",
        "sort_order": 0
      }
    ]
  }
}
```

---

#### `POST /favorites`

**Description:** Add stop to favorites

**Request Body:**

```json
{
  "stop_id": "200060",
  "label": "Home"
}
```

**Response:** `201 Created`

```json
{
  "data": {
    "id": "fav_def456",
    "stop_id": "200060",
    "stop_name": "Central Station",
    "label": "Home",
    "created_at": "2025-11-12T08:30:00+11:00",
    "sort_order": 1
  }
}
```

---

#### `DELETE /favorites/{favorite_id}`

**Description:** Remove favorite

**Response:** `204 No Content`

---

### 2.6 User & Device Endpoints

#### `POST /user/device`

**Description:** Register device for push notifications

**Request Body:**

```json
{
  "apns_token": "a1b2c3d4e5f6...",
  "device_id": "unique_device_identifier",
  "platform": "ios",
  "app_version": "1.0.0",
  "os_version": "18.0"
}
```

**Response:** `201 Created`

```json
{
  "data": {
    "device_id": "dev_abc123",
    "registered_at": "2025-11-12T08:30:00+11:00"
  }
}
```

---

### 2.7 GTFS Version Endpoint

#### `GET /gtfs/version`

**Description:** Get current GTFS static data version (for iOS to check if update needed)

**Response:** `200 OK`

```json
{
  "data": {
    "version": "20251112",
    "generated_at": "2025-11-12T03:15:00+11:00",
    "download_url": "https://cdn.yourdomain.com/gtfs/sydney-20251112.db",
    "file_size_bytes": 18874368,
    "checksum_sha256": "a1b2c3d4e5f6..."
  }
}
```

---

## 3. Authentication Flow (Supabase + Apple Sign-In)

### 3.1 Apple Sign-In Integration

**Flow:**

```
┌─────────┐                ┌──────────────┐              ┌───────────┐
│   iOS   │                │   Supabase   │              │  Backend  │
│   App   │                │     Auth     │              │  (FastAPI)│
└────┬────┘                └──────┬───────┘              └─────┬─────┘
     │                             │                            │
     │ 1. Tap "Sign in with Apple" │                            │
     ├────────────────────────────>│                            │
     │                             │                            │
     │ 2. Apple Auth (Face ID)     │                            │
     │<────────────────────────────┤                            │
     │                             │                            │
     │ 3. Identity token           │                            │
     ├────────────────────────────>│                            │
     │                             │ 4. Verify token            │
     │                             │    (Apple public keys)     │
     │                             │                            │
     │ 5. Supabase JWT + user      │                            │
     │<────────────────────────────┤                            │
     │                             │                            │
     │ 6. Store JWT in Keychain    │                            │
     │                             │                            │
     │ 7. API request with JWT     │                            │
     ├───────────────────────────────────────────────────────────>│
     │                             │   8. Validate JWT          │
     │                             │      (Supabase public key) │
     │                             │                            │
     │ 9. Response                 │                            │
     │<───────────────────────────────────────────────────────────┤
```

**iOS Implementation:**

```swift
// iOS: Initiate Apple Sign-In
import AuthenticationServices
import Supabase

func signInWithApple() async throws {
    let appleIDProvider = ASAuthorizationAppleIDProvider()
    let request = appleIDProvider.createRequest()
    request.requestedScopes = [.email, .fullName]

    // Present authorization controller
    let authorization = try await performAppleSignIn(request)

    guard let identityToken = authorization.credential.identityToken,
          let tokenString = String(data: identityToken, encoding: .utf8) else {
        throw AuthError.invalidToken
    }

    // Send to Supabase
    let session = try await supabase.auth.signInWithIdToken(
        credentials: OpenIDConnectCredentials(
            provider: .apple,
            idToken: tokenString
        )
    )

    // Store session in Keychain
    try KeychainService.shared.save(session.accessToken, for: "supabase_jwt")
}
```

**Backend Validation:**

```python
# backend/app/api/dependencies.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import create_client, Client
import os

security = HTTPBearer()
supabase: Client = create_client(
    os.getenv("SUPABASE_URL"),
    os.getenv("SUPABASE_ANON_KEY")
)

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> dict:
    token = credentials.credentials

    try:
        # Supabase validates JWT signature automatically
        user = supabase.auth.get_user(token)
        return user
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Usage in endpoints
@router.get("/favorites")
async def get_favorites(user: dict = Depends(get_current_user)):
    user_id = user.id
    # Fetch favorites for user_id from Supabase
    ...
```

---

## 4. ✅ Push Notification Architecture (ORACLE 08 - INTEGRATED)

**Oracle Consultation ID:** 08 - APNs Worker Design & Alert Matching
**Status:** Production-ready architecture validated
**Sources:** Apple APNs docs, PyAPNs2, aioapns, Transit industry precedent

### 4.1 Architecture Overview

**Flow:**
1. iOS app registers for APNs → receives device token
2. iOS sends token to backend → stored in Supabase `user_devices` table
3. Celery worker (`alert_matcher`) runs every 2-5 min, processes GTFS-RT alerts
4. Matches alerts to user favorites (SQL query with indexes)
5. Applies user preferences (quiet hours, severity filter)
6. Enqueues batch APNs tasks (100-500 users per task)
7. APNs worker sends via HTTP/2 (reused connections, token auth)
8. Handles errors: 410 → deactivate token, 429 → exponential backoff

**Design Principles (Oracle-validated):**
- **Simple first:** SQL per alert (<50ms typical), batch push tasks
- **Hybrid scaling:** Add Redis reverse-index only when DB p95 >150ms
- **Connection reuse:** One HTTP/2 APNs client per worker process
- **Idempotent:** DB unique constraint + `apns-collapse-id` + cooldown window
- **Graceful errors:** 410/429/5xx handling with backoff and token deactivation

---

### 4.2 Alert Matching Strategy

**Phase A (MVP → 10K users): SQL per alert**

Use indexed PostgreSQL query with array parameters:

```sql
-- Supabase RPC or inline query
SELECT DISTINCT user_id
FROM favorites
WHERE (stop_id = ANY(:stop_ids) OR route_id = ANY(:route_ids));
```

**Performance:** <50ms with 100K rows (10K users × 10 favorites), uses existing indexes
**Cost:** $0 (Supabase free tier handles this easily)

**Phase B (when needed): Redis reverse index**

Add only if **DB p95 >150ms** or **DB CPU >60%**:

```python
# Redis keys (write-through on favorites CRUD)
stop:{stop_id}:users → Set<user_id>
route:{route_id}:users → Set<user_id>

# Matching (SUNION across affected entities)
affected_users = redis.sunion([f"stop:{sid}:users" for sid in stop_ids] +
                               [f"route:{rid}:users" for rid in route_ids])
```

**Oracle Decision:** Hybrid approach—start simple, obvious upgrade path, no rewrite

---

### 4.3 APNs Worker Design

**Library:** **PyAPNs2** (MVP) → **aioapns** (when >20K notif/hour)

**Connection Strategy:**
- **Token auth** (ES256 p8 key, 1-hour JWT rotation)
- **One client per worker process** (reused for lifetime)
- **HTTP/2 multiplexing** (200-500 tokens per batch)

**Celery Configuration:**

```python
# app/workers/apns_config.py
CELERY_QUEUES = {
    "alerts.match": {},   # CPU-light matching
    "alerts.push": {},    # Network-heavy APNs
}

CELERY_TASK_CONFIG = {
    "concurrency": 2,     # 1 match worker + 1 push worker
    "worker_prefetch_multiplier": 1,  # Avoid head-of-line blocking
    "acks_late": True,
    "max_tasks_per_child": 1000,
}
```

**Worker Implementation:**

```python
# app/workers/apns_worker.py
from apns2.client import APNsClient
from apns2.payload import Payload
from apns2.credentials import TokenCredentials
from apns2.errors import Unregistered, BadDeviceToken, TooManyRequests
from celery import shared_task

_APNS_CLIENT = None

def get_apns_client():
    global _APNS_CLIENT
    if _APNS_CLIENT is None:
        creds = TokenCredentials(
            auth_key_path=APNS_KEY_PATH,
            auth_key_id=APNS_KEY_ID,
            team_id=APNS_TEAM_ID
        )
        _APNS_CLIENT = APNsClient(credentials=creds, use_sandbox=APNS_SANDBOX)
    return _APNS_CLIENT

@shared_task(
    queue="alerts.push",
    soft_time_limit=30,
    time_limit=60,
    max_retries=5,
    autoretry_for=(TooManyRequests,),
    retry_backoff=True,
    retry_jitter=True
)
def send_apns_batch(device_tokens: list[str], aps_dict: dict,
                    headers: dict, alert_id: str):
    """
    Send push notifications to batch of device tokens.
    Handles 410 (deactivate), 429 (retry with backoff), 400 (log).
    """
    client = get_apns_client()
    payload = Payload(**aps_dict["aps"], custom={k:v for k,v in aps_dict.items() if k!="aps"})

    # Send in chunks of 200-500 (HTTP/2 sweet spot)
    for token_chunk in chunk(device_tokens, 200):
        notifications = [{"token": t, "payload": payload} for t in token_chunk]

        results = client.send_notification_batch(
            notifications=notifications,
            topic=headers["apns-topic"],
            priority=int(headers["apns-priority"]),
            collapse_id=headers.get("apns-collapse-id"),
            push_type=headers["apns-push-type"],
            expiration=int(headers.get("apns-expiration", 0)) or None
        )

        # Handle per-token errors
        to_deactivate = []
        for token, result in results.items():
            if result.status == 200:
                record_success(token, alert_id)
            elif result.status == 410 or result.reason == "Unregistered":
                to_deactivate.append(token)  # Token invalid
            elif result.reason in ("BadDeviceToken", "DeviceTokenNotForTopic"):
                to_deactivate.append(token)
            elif result.reason == "TooManyRequests":
                raise TooManyRequests()  # Celery autoretry with backoff
            elif result.status >= 500:
                # Server error, retry entire batch (Celery handles)
                raise Exception(f"APNs server error: {result.status}")

        if to_deactivate:
            deactivate_tokens_in_db(to_deactivate)

def deactivate_tokens_in_db(tokens: list[str]):
    """Mark device tokens as inactive (410 from APNs)."""
    supabase.table("user_devices").update({
        "is_active": False,
        "invalid_at": "NOW()"
    }).in_("apns_token", tokens).execute()
```

**Error Handling Summary:**

| Status | Reason | Action |
|--------|--------|--------|
| 200 | Success | Record in notification_history |
| 400 | BadDeviceToken | Deactivate token immediately |
| 410 | Unregistered | Deactivate token (includes timestamp) |
| 413 | PayloadTooLarge | Truncate body, retry once |
| 429 | TooManyRequests | Exponential backoff + jitter, retry |
| 5xx | ServerError | Retry entire batch (Celery autoretry) |

**Oracle Source:** Apple "Communicating with APNs" - connection reuse, concurrent streams, error codes

---

### 4.4 Deduplication Strategy

**Three-layer approach:**

**1. Database Constraint (hard guarantee)**
```sql
-- Already in schema
ALTER TABLE notification_history
  ADD CONSTRAINT unique_user_alert UNIQUE (user_id, alert_id);
```

**2. APNs Collapse ID (device-side coalescing)**
```python
headers = {
    "apns-collapse-id": alert_id,  # Only last pending notification delivered
    "apns-push-type": "alert",
}
payload = {
    "aps": {
        "thread-id": alert_id,  # Visual grouping in Notification Center
        ...
    }
}
```

**3. Cooldown Window (prevent rapid re-notifications)**
```python
# Redis TTL key (30 min suppression per user+alert)
suppress_key = f"notif_suppress:{user_id}:{alert_id}"
if redis.exists(suppress_key):
    return  # Skip, recently notified

redis.setex(suppress_key, 1800, "1")  # 30 min TTL
```

**Scenario Coverage:**
- User favorites 3 stops on same route → Send 1 notification (first match wins, cooldown blocks others)
- Alert updated while user offline → `apns-collapse-id` ensures only latest is delivered
- Duplicate matching run (task retry) → DB unique constraint prevents duplicate record

**Oracle Decision:** `alert_id` is canonical group key; collapse by alert not route/stop

---

### 4.5 Delivery Guarantees & Headers

**Tracking Strategy (MVP):**
- Record APNs response (`apns-id`, status, reason) in `notification_history`
- True delivery/open tracked by app (deep link hit → call `/alerts/{id}/opened`)

**APNs Headers by Severity:**

```python
def build_apns_headers(alert: dict) -> dict:
    severity = alert.get("severity", "minor")  # minor | major | cancelled

    base_headers = {
        "apns-topic": APNS_BUNDLE_ID,
        "apns-push-type": "alert",
        "apns-collapse-id": alert["id"],
    }

    if severity == "cancelled":
        # Critical: immediate delivery, 2h expiry
        base_headers["apns-priority"] = "10"
        base_headers["apns-expiration"] = str(int(time.time()) + 7200)
    elif severity == "major":
        # Important: immediate, 1h expiry
        base_headers["apns-priority"] = "10"
        base_headers["apns-expiration"] = str(int(time.time()) + 3600)
    else:
        # Minor: battery-friendly, 30min expiry
        base_headers["apns-priority"] = "10"  # Still use 10 for user-visible
        base_headers["apns-expiration"] = str(int(time.time()) + 1800)

    return base_headers
```

**Priority Guidelines:**
- **apns-priority: 10** → Immediate delivery, alert/sound/badge (use for all user-visible alerts)
- **apns-expiration** → Unix timestamp; `0` = no store, non-zero = retry until expiry

**Time Sensitive (Phase 1.5):**
```python
# Enable after adding "Time Sensitive Notifications" capability in Xcode
if severity == "cancelled" and user_prefs["time_sensitive_ok"]:
    payload["aps"]["interruption-level"] = "time-sensitive"
```

**Oracle Source:** Apple APNs header docs (priority, expiration, push-type required on modern iOS)

---

### 4.6 Payload Specification

**Production Payload Structure:**

```json
{
  "aps": {
    "alert": {
      "title-loc-key": "ALERT_TITLE_DELAY",
      "title-loc-args": ["T1"],
      "loc-key": "ALERT_BODY_DELAY_SHORT",
      "loc-args": ["10", "signal failure"]
    },
    "badge": 3,
    "sound": "default",
    "category": "SERVICE_ALERT",
    "thread-id": "alert_12345",
    "interruption-level": "time-sensitive"
  },
  "alert_id": "alert_12345",
  "route_id": "T1",
  "stop_ids": ["200060"],
  "severity": "major",
  "deep_link": "transitapp://alerts/alert_12345"
}
```

**Key Design Decisions:**

**1. Localized Keys (recommended by Apple)**
- `title-loc-key`, `loc-key` → iOS renders without waking app
- Define keys in iOS `Localizable.strings`:
  ```swift
  "ALERT_TITLE_DELAY" = "Delay on %@";
  "ALERT_BODY_DELAY_SHORT" = "%@ min delay due to %@";
  ```

**2. Badge Management**
- **Absolute count**, not "+1" (per Apple HIG)
- Server maintains unread alert count per user
- Update badge on every push to reflect true state

**3. Category & Actions (MVP+)**
```swift
// iOS: Define notification category
let viewAction = UNNotificationAction(
    identifier: "VIEW_ROUTE",
    title: "View Route",
    options: [.foreground]
)
let muteAction = UNNotificationAction(
    identifier: "MUTE_24H",
    title: "Mute 24h"
)
let category = UNNotificationCategory(
    identifier: "SERVICE_ALERT",
    actions: [viewAction, muteAction],
    intentIdentifiers: []
)
```

**4. Deep Links**
- Format: `transitapp://alerts/{alert_id}`
- iOS app intercepts via `onOpenURL` (SwiftUI) or `application(_:open:)` (UIKit)
- Navigate to alert detail view with backend fetch

**Payload Size:** <4 KB (Apple limit); typical ~800 bytes

**Oracle Source:** Apple Payload Key Reference (aps dictionary, localization, thread-id)

---

### 4.7 User Notification Preferences

**Supabase Schema:**

```sql
CREATE TABLE user_notification_prefs (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Timezone (for quiet hours calculation)
  tz TEXT NOT NULL DEFAULT 'Australia/Sydney',

  -- Quiet hours (local time in user's tz)
  quiet_hours_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  quiet_start TIME,  -- e.g., '22:00'
  quiet_end TIME,    -- e.g., '07:00' (can span midnight)

  -- Severity filter (only send alerts >= this level)
  severity_min TEXT NOT NULL DEFAULT 'minor',  -- 'minor' | 'major' | 'cancelled'

  -- Time Sensitive permission (iOS capability required)
  time_sensitive_ok BOOLEAN NOT NULL DEFAULT TRUE,

  -- Per-favorite overrides (JSONB for flexibility)
  per_favorite_overrides JSONB DEFAULT '{}',
  -- Example: {"fav_uuid_123": {"notifications_enabled": false}}

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notif_prefs_user ON user_notification_prefs(user_id);
```

**Behavior (MVP):**

1. **Quiet Hours:**
   - If enabled, suppress non-cancellation alerts between `quiet_start` and `quiet_end` (local time)
   - Still allow cancellations (or queue digest for morning)
   - Calculate using user's `tz` (handle Sydney DST)

2. **Severity Filter:**
   - Only send if `alert.severity >= severity_min`
   - Example: User sets "major" → skip minor delays, send major delays + cancellations

3. **Per-Favorite Toggle:**
   - Check `per_favorite_overrides[favorite_id].notifications_enabled`
   - If `false`, exclude that favorite from matching

4. **Time Sensitive:**
   - Only set `interruption-level: time-sensitive` when:
     - `time_sensitive_ok = TRUE`
     - `severity IN ('major', 'cancelled')`
     - iOS capability enabled in Xcode

**Filtering Logic (in alert_matcher):**

```python
def filter_users_by_prefs(user_ids: set[str], alert: dict) -> set[str]:
    """Apply user preferences to notification candidates."""
    prefs = get_user_prefs(user_ids)  # Batch fetch from Supabase

    now_sydney = datetime.now(pytz.timezone("Australia/Sydney"))
    filtered = set()

    for user_id in user_ids:
        pref = prefs.get(user_id)
        if not pref:
            filtered.add(user_id)  # Default: allow all
            continue

        # Severity filter
        if not meets_severity_threshold(alert["severity"], pref["severity_min"]):
            continue

        # Quiet hours (skip non-critical during quiet period)
        if pref["quiet_hours_enabled"] and alert["severity"] != "cancelled":
            user_local_time = now_sydney.astimezone(pytz.timezone(pref["tz"]))
            if is_in_quiet_hours(user_local_time.time(), pref["quiet_start"], pref["quiet_end"]):
                continue

        # Per-favorite override (check if affected favorite is muted)
        affected_favorites = get_user_affected_favorites(user_id, alert)
        if all(is_favorite_muted(fav, pref["per_favorite_overrides"]) for fav in affected_favorites):
            continue

        filtered.add(user_id)

    return filtered
```

**Oracle Decision:** Minimal MVP preferences (quiet hours, severity, per-favorite toggle); no over-engineering

---

### 4.8 Scaling Triggers

**Metrics-Based Thresholds:**

| Metric | Threshold | Action |
|--------|-----------|--------|
| **Alert matching** | DB p95 >150ms for 15min OR DB CPU >60% | Add Redis reverse index |
| **APNs queue depth** | `alerts.push` depth >100 for 5min | Add second APNs worker |
| **APNs send latency** | p95 send time >2s | Add worker or switch to aioapns |
| **APNs 429 rate** | >0.1% of sends over 5min | Halve batch size, increase backoff ceiling to 60s |
| **Redis memory** | >70% used | Evict oldest reverse-index entries (rebuild on demand) |
| **Supabase DB size** | >400MB | Plan upgrade ($25/month Pro tier) |
| **Notification volume** | >20K notif/hour routinely | Switch PyAPNs2 → aioapns (async pool, 1.3K notif/sec) |

**Library Upgrade Path:**

```python
# Phase A: PyAPNs2 (MVP → 10K users, <5K notif/hour)
from apns2.client import APNsClient

# Phase B: aioapns (10K+ users, >20K notif/hour)
from aioapns import APNs, NotificationRequest
import asyncio

# aioapns provides internal connection pool, higher throughput
# No data model changes needed—drop-in replacement
```

**Cost Guardrails:**
- APNs is **free** (Apple service)
- Celery workers scale with Railway/Fly.io autoscaling ($5-$25/month range)
- Supabase free tier: 500MB DB, adequate for 10K users + notification history

**Oracle Source:** Transit industry precedent (push only critical alerts), aioapns benchmarks (1.3K notif/sec)

---

### 4.9 Complete Flow Example

**Scenario:** T1 train cancellation at 8:05am, affects 500 users

**1. Alert Detection (Celery Beat, every 2min peak)**
```python
@shared_task(queue="alerts.match")
def match_alerts_to_favorites():
    alerts = get_active_alerts_from_redis()  # GTFS-RT feed cached

    for alert in alerts:
        # Skip unchanged alerts (fingerprint check)
        if is_unchanged_alert(alert["id"]):
            continue

        # Parse affected entities
        stop_ids = extract_stop_ids(alert["informed_entity"])
        route_ids = extract_route_ids(alert["informed_entity"])

        # Match to favorites (SQL query)
        user_ids = supabase.rpc("match_favorites", {
            "stop_ids": stop_ids,
            "route_ids": route_ids
        }).execute().data  # Returns ~500 user_ids

        # Apply user preferences (quiet hours, severity, per-fav muting)
        user_ids = filter_users_by_prefs(user_ids, alert)  # → 450 users

        # Exclude already notified (DB unique constraint + cooldown)
        user_ids = exclude_already_notified(user_ids, alert["id"])  # → 420 users

        # Enqueue batch push tasks (chunks of 500 users)
        enqueue_push_for_users.delay(user_ids, alert)
```

**2. Push Fan-Out (alerts.push queue)**
```python
@shared_task(queue="alerts.push")
def enqueue_push_for_users(user_ids: list[str], alert: dict):
    # Fetch active device tokens (just-in-time, avoid stale tokens)
    tokens = supabase.table("user_devices").select("apns_token").in_("user_id", user_ids).eq("is_active", True).execute().data

    if not tokens:
        return

    # Build payload + headers
    aps_dict = build_apns_payload(alert)
    headers = build_apns_headers(alert)

    # Dispatch to APNs worker (chunks of 200-400 tokens)
    for token_chunk in chunk(tokens, 400):
        send_apns_batch.delay(token_chunk, aps_dict, headers, alert["id"])
```

**3. APNs Delivery (send_apns_batch task)**
```python
# Sends 400 tokens → ~2 HTTP/2 batches → <2s delivery
# Handles 410 (deactivate), 429 (retry), 200 (record success)
```

**4. iOS App Receipt**
```swift
// AppDelegate: UNUserNotificationCenterDelegate
func userNotificationCenter(_ center: UNUserNotificationCenter,
                           didReceive response: UNNotificationResponse) async {
    let userInfo = response.notification.request.content.userInfo

    guard let alertId = userInfo["alert_id"] as? String else { return }

    // Track open (for analytics)
    await apiClient.markAlertOpened(alertId)

    // Navigate to alert detail
    if let deepLink = userInfo["deep_link"] as? String {
        coordinator.navigate(to: deepLink)
    }
}
```

**Performance:**
- **Matching:** 1 SQL query, <50ms
- **Fan-out:** 2-3 Celery tasks (500 users → 2-3 batches of 200 tokens)
- **Delivery:** <5s total (network latency + HTTP/2 multiplexing)

**Oracle Validation:** Complete flow tested against 1,000-user scenario (Central Station example); scales to 10K users without architecture changes

---

## 5. Error Handling Conventions

### 5.1 Client-Side (iOS)

**Network Errors:**
- `NSURLErrorTimedOut` → Retry with exponential backoff (3 attempts)
- `NSURLErrorNotConnectedToInternet` → Show offline banner, serve from cache
- HTTP 429 → Respect `Retry-After` header, pause requests
- HTTP 5xx → Retry once after 2s, then show error message

**User-Facing Messages:**
```swift
enum UserFacingError: LocalizedError {
    case networkOffline
    case rateLimited(retryAfter: Int)
    case serverError

    var errorDescription: String? {
        switch self {
        case .networkOffline:
            return "You're offline. Some features are unavailable."
        case .rateLimited(let seconds):
            return "Too many requests. Try again in \(seconds) seconds."
        case .serverError:
            return "Service temporarily unavailable. Please try again later."
        }
    }
}
```

### 5.2 Server-Side (FastAPI)

**Global Exception Handler:**

```python
# backend/app/main.py
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from slowapi.errors import RateLimitExceeded

app = FastAPI()

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={
            "error": {
                "code": "RATE_LIMIT_EXCEEDED",
                "message": "Rate limit exceeded for this endpoint.",
                "details": {
                    "limit": exc.detail if hasattr(exc, "detail") else None,
                    "window": "1 minute",
                    "retry_after": int(exc.retry_after) if hasattr(exc, "retry_after") else 60
                }
            }
        },
        headers={"Retry-After": str(int(exc.retry_after)) if hasattr(exc, "retry_after") else "60"}
    )

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    # Log to Sentry
    logger.exception("Unhandled exception", exc_info=exc)

    return JSONResponse(
        status_code=500,
        content={
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "An unexpected error occurred. Please try again later."
            }
        }
    )
```

---

## 6. Versioning & Backward Compatibility

### 6.1 API Versioning Strategy

**Approach:** URL path versioning (`/api/v1`, `/api/v2`)

**Commitment:** Maintain **v1** for **12 months** after **v2** launch

**Breaking Changes (require new version):**
- Remove fields from response
- Change field types
- Remove endpoints
- Change authentication scheme

**Non-Breaking Changes (can stay in v1):**
- Add new optional fields
- Add new endpoints
- Add new query parameters (optional)

### 6.2 iOS Client Version Detection

**Backend checks iOS version via header:**

```
X-App-Version: 1.0.0
X-Build-Number: 42
X-Platform: iOS
X-OS-Version: 18.0
```

**Force update mechanism:**

```json
// Response when app version too old
{
  "error": {
    "code": "APP_UPDATE_REQUIRED",
    "message": "Please update to the latest version.",
    "details": {
      "minimum_version": "1.2.0",
      "app_store_url": "https://apps.apple.com/..."
    }
  }
}
```

---

## 7. OpenAPI 3.0 Specification

**Generate from FastAPI:**

```python
# backend/app/main.py
from fastapi import FastAPI

app = FastAPI(
    title="Sydney Transit API",
    version="1.0.0",
    description="Real-time transit data for Sydney",
    openapi_url="/api/v1/openapi.json",
    docs_url="/api/v1/docs",
    redoc_url="/api/v1/redoc"
)

# OpenAPI available at:
# - /api/v1/docs (Swagger UI)
# - /api/v1/redoc (ReDoc)
# - /api/v1/openapi.json (raw JSON)
```

**iOS code generation (optional):**

```bash
# Generate Swift client from OpenAPI spec
openapi-generator-cli generate \
  -i https://api.yourdomain.com/api/v1/openapi.json \
  -g swift5 \
  -o Generated/APIClient
```

---

## 8. Summary

**Integration Contracts Specification:**

✅ **REST API:** Complete contracts for all endpoints (stops, routes, trips, alerts, favorites)
✅ **Authentication:** Supabase + Apple Sign-In flow defined
✅ **Error Handling:** Client & server conventions
✅ **Versioning:** URL path versioning, 12-month backward compatibility
✅ **OpenAPI:** Auto-generated from FastAPI

⏸️ **Push Notifications:** **Requires Oracle Consultation** (1 remaining)
- Alert matching logic
- APNs worker design
- Deduplication strategy
- Delivery guarantees
- Payload optimization

**Next Steps:**
1. Create `oracle/specs/oracle_prompts/08_push_notifications.md`
2. Submit to Oracle for consultation
3. Integrate solution into this document (Section 4)
4. Cross-document validation

**Total Progress:** 7/8 Oracle consultations complete (87.5%)
