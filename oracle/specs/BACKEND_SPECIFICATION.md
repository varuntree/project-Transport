# Backend Specification - Sydney Transit App
**Project:** FastAPI + Celery Backend Architecture
**Version:** 1.0 (Draft - Requires 3 Oracle Reviews)
**Date:** 2025-11-12
**Dependencies:** SYSTEM_OVERVIEW.md, DATA_ARCHITECTURE.md
**Status:** 60% Complete - Awaiting 3 Oracle Consultations

---

## Document Purpose

This document defines the backend service architecture:
- FastAPI REST API endpoints
- Celery background workers (GTFS sync, real-time polling, alerts)
- Authentication & authorization (Supabase Auth)
- Rate limiting & security
- Deployment architecture (Railway/Fly.io)

**Critical Sections Requiring Oracle Consultation:**
1. ⚠️ Celery Worker Task Design (Section 4)
2. ⚠️ Background Job Scheduling (Section 5)
3. ⚠️ Rate Limiting Strategy (Section 6)

---

## 1. Technology Stack (Ratified)

### Core Framework
- **FastAPI** (Python 3.11+)
  - Async/await support
  - Automatic OpenAPI docs
  - Pydantic validation
  - Type hints throughout

### Background Workers
- **Celery** 5.3+
  - Redis as message broker
  - No result backend (ephemeral tasks)
  - Celery Beat for scheduling

### Database & Cache
- **Supabase** (PostgreSQL 14+ with PostGIS)
  - Connection pooling via Supabase
  - Row Level Security (RLS) enabled
- **Redis** (Railway or Upstash)
  - Cache + Celery broker
  - In-memory key-value store

### Hosting & Infrastructure
- **Railway** or **Fly.io** (backend + workers)
- **Cloudflare** (CDN for static assets, free tier)
- **Supabase** (database, auth, storage, free tier)

---

## 2. System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        EXTERNAL SERVICES                         │
│  ┌──────────────────┐  ┌──────────────┐  ┌─────────────────┐   │
│  │  NSW Transport   │  │   Supabase   │  │  Apple APNs     │   │
│  │  Open Data API   │  │  (Auth, DB)  │  │  (Push Notifs)  │   │
│  └────────┬─────────┘  └──────┬───────┘  └────────┬────────┘   │
└───────────┼────────────────────┼───────────────────┼────────────┘
            │                    │                   │
            │ 5 req/s            │ PostgreSQL        │ HTTP/2
            │ 60K/day            │ connections       │ tokens
            │                    │                   │
┌───────────▼────────────────────▼───────────────────▼────────────┐
│                     BACKEND SERVICES                             │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │              FastAPI (Web Server)                          │ │
│  │  - Gunicorn + Uvicorn workers (async)                     │ │
│  │  - OpenAPI docs at /docs                                  │ │
│  │  - Health checks at /health                               │ │
│  │  - Metrics at /metrics                                    │ │
│  └───────────────────┬────────────────────────────────────────┘ │
│                      │                                           │
│  ┌───────────────────▼────────────────────────────────────────┐ │
│  │                   API Endpoints                            │ │
│  │  /api/v1/stops/*        (search, nearby, departures)      │ │
│  │  /api/v1/routes/*       (list, details, vehicles)         │ │
│  │  /api/v1/trips/*        (plan, details, realtime)         │ │
│  │  /api/v1/alerts/*       (active, subscribe)               │ │
│  │  /api/v1/favorites/*    (CRUD, sync)                      │ │
│  │  /api/v1/gtfs/*         (version, download)               │ │
│  └───────────────────┬────────────────────────────────────────┘ │
│                      │                                           │
│  ┌───────────────────▼────────────────────────────────────────┐ │
│  │              Celery Workers (Background)                   │ │
│  │  ┌──────────────────────┐  ┌─────────────────────────┐   │ │
│  │  │ gtfs_static_sync.py  │  │  gtfs_rt_poller.py      │   │ │
│  │  │ - Daily 3am          │  │  - Every 30-60s         │   │ │
│  │  │ - Download GTFS      │  │  - Poll NSW GTFS-RT     │   │ │
│  │  │ - Parse & transform  │  │  - Update Redis cache   │   │ │
│  │  │ - Load to Supabase   │  │  ⚠️ ORACLE DECIDES      │   │ │
│  │  │ - Generate iOS DB    │  │    OPTIMAL DESIGN       │   │ │
│  │  └──────────────────────┘  └─────────────────────────┘   │ │
│  │  ┌──────────────────────┐  ┌─────────────────────────┐   │ │
│  │  │ alert_matcher.py     │  │  apns_worker.py         │   │ │
│  │  │ - Match RT delays    │  │  - Send push notifs     │   │ │
│  │  │ - Check favorites    │  │  - Batch delivery       │   │ │
│  │  │ - Queue APNs         │  │  - Handle failures      │   │ │
│  │  └──────────────────────┘  └─────────────────────────┘   │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    Shared Services                          │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌────────────────┐  │ │
│  │  │ Redis Cache  │  │  Supabase    │  │  Rate Limiter  │  │ │
│  │  │ - GTFS-RT    │  │  - GTFS DB   │  │  - Token bucket│  │ │
│  │  │ - Departures │  │  - User data │  │  - Per user/IP │  │ │
│  │  │ - Sessions   │  │  - RLS auth  │  │  ⚠️ ORACLE     │  │ │
│  │  └──────────────┘  └──────────────┘  └────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
            │
            │ HTTPS REST API (JSON)
            │
┌───────────▼──────────────────────────────────────────────────────┐
│                        iOS APPLICATION                            │
└───────────────────────────────────────────────────────────────────┘
```

---

## 3. FastAPI REST Endpoints

### 3.1 Stops API

#### GET /api/v1/stops/nearby
**Purpose:** Find stops near a location (geospatial query)

**Query Parameters:**
```python
lat: float          # Latitude (-90 to 90)
lon: float          # Longitude (-180 to 180)
radius: int = 500   # Meters (default 500, max 2000)
limit: int = 20     # Max results (default 20, max 50)
```

**Response:**
```json
{
  "stops": [
    {
      "stop_id": "200060",
      "stop_name": "Central Station",
      "stop_lat": -33.8835,
      "stop_lon": 151.2065,
      "distance_meters": 120,
      "location_type": 1,
      "wheelchair_accessible": true
    }
  ],
  "count": 15
}
```

**Implementation:**
```python
@router.get("/stops/nearby")
async def get_nearby_stops(
    lat: float = Query(..., ge=-90, le=90),
    lon: float = Query(..., ge=-180, le=180),
    radius: int = Query(500, ge=50, le=2000),
    limit: int = Query(20, ge=1, le=50),
    db: AsyncSession = Depends(get_db)
):
    # PostGIS query (from DATA_ARCHITECTURE.md Section 6)
    query = text("""
        SELECT s.stop_id, s.stop_name, s.stop_lat, s.stop_lon,
               ST_Distance(s.location, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography) AS distance_meters
        FROM stops s
        WHERE ST_DWithin(s.location, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :radius)
        ORDER BY s.location <-> ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography
        LIMIT :limit
    """)

    result = await db.execute(query, {"lat": lat, "lon": lon, "radius": radius, "limit": limit})
    stops = result.fetchall()

    return {"stops": [dict(row) for row in stops], "count": len(stops)}
```

**Performance Target:** <100ms p95 (geospatial index optimized)

---

#### GET /api/v1/stops/{stop_id}/departures
**Purpose:** Get next departures for a stop with real-time delays

**Path Parameters:**
- `stop_id`: string (GTFS stop_id)

**Query Parameters:**
```python
limit: int = 5      # Number of departures (default 5, max 20)
include_alerts: bool = True  # Include relevant service alerts
```

**Response:**
```json
{
  "stop_id": "200060",
  "stop_name": "Central Station",
  "as_of": "2025-11-12T08:15:30+11:00",
  "stale": false,
  "departures": [
    {
      "route_short_name": "T1",
      "route_long_name": "North Shore Line",
      "headsign": "Hornsby",
      "scheduled_time": "2025-11-12T08:18:00+11:00",
      "realtime": true,
      "delay_seconds": 120,
      "estimated_time": "2025-11-12T08:20:00+11:00",
      "countdown_minutes": 4,
      "trip_id": "trip_12345",
      "platform": "4"
    }
  ],
  "alerts": [
    {
      "alert_id": "alert_001",
      "severity": "warning",
      "header": "Delays on T1 Line",
      "description": "Expect delays of up to 10 minutes due to signal failure."
    }
  ]
}
```

**Implementation:**
```python
@router.get("/stops/{stop_id}/departures")
async def get_departures(
    stop_id: str,
    limit: int = Query(5, ge=1, le=20),
    include_alerts: bool = True,
    redis: Redis = Depends(get_redis),
    db: AsyncSession = Depends(get_db)
):
    # Check Redis cache first (TTL 25-30s from DATA_ARCHITECTURE.md)
    cache_key = f"departures:{stop_id}"
    cached = await redis.get(cache_key)

    if cached:
        return json.loads(cached)

    # Cache miss: compute from pattern model + GTFS-RT blobs
    # (Implementation from DATA_ARCHITECTURE.md Section 4)
    departures = await compute_departures(stop_id, limit, redis, db)

    # Cache for 30s
    await redis.setex(cache_key, 30, json.dumps(departures))

    return departures
```

**Performance Target:** <200ms p95

---

### 3.2 Routes API

#### GET /api/v1/routes
**Purpose:** List all routes (with optional filtering)

**Query Parameters:**
```python
mode: str | None = None        # Filter by mode (trains, buses, ferries, etc.)
search: str | None = None      # Search by route name
limit: int = 50
offset: int = 0
```

**Response:**
```json
{
  "routes": [
    {
      "route_id": "T1_SYD",
      "route_short_name": "T1",
      "route_long_name": "North Shore & Western Line",
      "route_type": 2,
      "route_color": "f99d1c",
      "agency_name": "Sydney Trains"
    }
  ],
  "total": 523,
  "limit": 50,
  "offset": 0
}
```

---

#### GET /api/v1/routes/{route_id}
**Purpose:** Get route details with stops (for map visualization)

**Response:**
```json
{
  "route_id": "T1_SYD",
  "route_short_name": "T1",
  "route_long_name": "North Shore & Western Line",
  "directions": [
    {
      "direction_id": 0,
      "headsign": "City via Strathfield",
      "stops": [
        {"stop_id": "...", "stop_name": "...", "stop_lat": -33.88, "stop_lon": 151.21, "sequence": 1},
        ...
      ],
      "shape": "encoded_polyline_string"  # Google encoded polyline
    }
  ]
}
```

---

### 3.3 Trips API

#### POST /api/v1/trips/plan
**Purpose:** Multi-modal journey planning

**Request Body:**
```json
{
  "origin": {
    "type": "coordinates",
    "lat": -33.8688,
    "lon": 151.2093
  },
  "destination": {
    "type": "stop",
    "stop_id": "200060"
  },
  "time": "2025-11-12T08:00:00+11:00",
  "time_type": "depart_at",  // or "arrive_by"
  "modes": ["trains", "buses", "ferries"],
  "preferences": {
    "max_walking_distance": 1000,
    "wheelchair_accessible": false
  }
}
```

**Response:**
```json
{
  "itineraries": [
    {
      "duration_seconds": 1800,
      "walk_distance_meters": 450,
      "transfers": 1,
      "departure_time": "2025-11-12T08:05:00+11:00",
      "arrival_time": "2025-11-12T08:35:00+11:00",
      "legs": [
        {
          "mode": "WALK",
          "from": {"lat": -33.8688, "lon": 151.2093},
          "to": {"stop_id": "12345", "stop_name": "Town Hall Station"},
          "duration_seconds": 300,
          "distance_meters": 400,
          "polyline": "encoded_polyline"
        },
        {
          "mode": "TRANSIT",
          "route_short_name": "T2",
          "headsign": "Central",
          "from_stop": {"stop_id": "12345", "stop_name": "Town Hall"},
          "to_stop": {"stop_id": "200060", "stop_name": "Central"},
          "departure_time": "2025-11-12T08:10:00+11:00",
          "arrival_time": "2025-11-12T08:25:00+11:00",
          "trip_id": "trip_67890",
          "realtime_delay_seconds": 60
        }
      ]
    }
  ]
}
```

**Implementation Strategy:**
- **Phase 1 (MVP):** Proxy to NSW Trip Planner API (cache results 10 min)
- **Phase 2:** Custom routing engine (OpenTripPlanner or custom)

---

### 3.4 Favorites API

#### GET /api/v1/favorites
**Purpose:** Get user's favorite stops/routes

**Headers:**
- `Authorization: Bearer <supabase_jwt>`

**Response:**
```json
{
  "favorites": [
    {
      "favorite_id": "uuid",
      "entity_type": "stop",
      "entity_id": "200060",
      "stop_name": "Central Station",
      "display_order": 0,
      "created_at": "2025-11-10T10:00:00Z"
    }
  ]
}
```

**Implementation:**
```python
@router.get("/favorites")
async def get_favorites(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # Supabase RLS automatically filters by auth.uid()
    result = await db.execute(
        select(Favorite).where(Favorite.user_id == user.id).order_by(Favorite.display_order)
    )
    favorites = result.scalars().all()
    return {"favorites": [f.to_dict() for f in favorites]}
```

---

### 3.5 GTFS Version API

#### GET /api/v1/gtfs/version
**Purpose:** Check iOS SQLite version (for background download)

**Response:**
```json
{
  "feed_version": "2025-11-12",
  "feed_start_date": "2025-11-12",
  "feed_end_date": "2026-02-12",
  "file_size_bytes": 18874368,
  "sha256": "abc123...",
  "download_url": "https://cdn.example.com/gtfs/sydney-2025-11-12.sqlite",
  "generated_at": "2025-11-12T03:30:00+11:00"
}
```

---

## 4. ✅ Celery Worker Task Design (Oracle Reviewed)

**Oracle Consultation:** Based on production patterns from Open edX, Sentry, Instagram/Disqus ([docs.openedx.org](https://docs.openedx.org/projects/edx-platform/en/latest/how-tos/celery.html), Celery official docs)

### Queue Architecture (3 Queues for Isolation)

**Decision:** Use **3 separate queues** instead of single queue with priorities
- `critical` - GTFS-RT poller (every 30s, must not be blocked)
- `normal` - Alert matcher + APNs delivery
- `batch` - Daily GTFS static sync (long-running, low priority)

**Rationale:** Redis priority support is limited/quirky; Celery recommends queue routing for isolation. This prevents batch work from blocking real-time paths.

```
┌─────────────────────────────────────────────────┐
│                  Celery Beat                    │
│  - periodic: RT poll (30s), alerts (2m),       │
│    daily static sync (03:10 Australia/Sydney)  │
│  - run exactly ONE instance                     │
└───────────────────┬─────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│                   Redis Broker                  │
│  Queues:  critical | normal | batch             │
└───────────────────┬──────────┬──────────────────┘
                    │          │
         ┌──────────┘          └───────────┐
         ▼                                 ▼
┌────────────────────────┐        ┌────────────────────────┐
│ Worker A (critical)    │        │ Worker B (service)     │
│ -Q critical            │        │ -Q normal,batch        │
│ -c 1, prefetch=1       │        │ -c 2 (autoscale 3..1), │
│ Only: gtfs_rt_poller   │        │ prefetch=1             │
└────────────────────────┘        │ alert_matcher,         │
                                  │ apns_worker,           │
                                  │ gtfs_static_sync       │
                                  └────────────────────────┘
```

### Task Configuration Matrix

| Task                 | Queue      | Priority | Soft Limit | Hard Limit | Retries | Backoff                     | Notes                                        |
| -------------------- | ---------- | -------: | ---------: | ---------: | ------: | --------------------------- | -------------------------------------------- |
| **gtfs_rt_poller**   | `critical` |     High |       10 s |       15 s |       0 | n/a                         | Singleton lock; skip on overlap              |
| **alert_matcher**    | `normal`   |      Med |       20 s |       30 s |       2 | exp (2→10s) + jitter        | Idempotent matching                          |
| **apns_worker**      | `normal`   |      Med |        8 s |       12 s |       3 | exp (1→8s), honor Retry-After | Rate limit `50/s` initially                  |
| **gtfs_static_sync** | `batch`    |      Low |       30 m |       60 m |       3 | exp (5→15→30m)              | Daily lock; chunk ETL; alert on failure      |

### Validated Celery Configuration

```python
# app/workers/celery_app.py
import os
from celery import Celery

app = Celery("backend")

app.conf.update(
    # Broker (Redis) — prefer managed plan over free Upstash (10k req/day is too low)
    broker_url=os.getenv("REDIS_URL"),

    # Results: off (stateless tasks). NOTE: 'task_track_started' requires a result backend;
    # we use events + custom metrics instead to keep costs low
    result_backend=None,  # no result storage

    # Routing: 3 queues
    task_queues={
        "critical": {},  # rt poller
        "normal":   {},  # alerts + apns
        "batch":    {},  # static sync
    },
    task_default_queue="normal",

    # Acks & redelivery on crash (keep tasks idempotent!)
    task_acks_late=True,
    task_reject_on_worker_lost=True,  # requeue if worker disappears

    # Fairness (no hoarding)
    worker_prefetch_multiplier=1,      # one message per process

    # Global defaults (per-task overrides below)
    task_time_limit=300,               # 5 min hard
    task_soft_time_limit=240,          # 4 min soft

    # Recycling
    worker_max_tasks_per_child=100,
    worker_max_memory_per_child=200_000,  # ~200MB

    # Broker transport (Redis)
    broker_transport_options={
        "visibility_timeout": 3700,  # > longest hard limit (60m) to prevent dupes
        "health_check_interval": 30,
    },

    # Publishing resilience
    task_publish_retry=True,                     # retry publish on broker hiccups
    broker_connection_retry_on_startup=True,     # robust boot

    # Serialization
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",

    # Time zone
    timezone="Australia/Sydney",
    enable_utc=False,  # run Beat in local AU time; mind DST transitions
)
```

### Task Implementations (Pseudocode)

**GTFS-RT Poller (singleton, skip on overlap, fail fast):**

```python
# app/workers/gtfs_poller.py
import time, json, logging
import redis, requests
from celery import shared_task
from celery.exceptions import SoftTimeLimitExceeded

r = redis.from_url(os.getenv("REDIS_URL"))
LOCK_KEY = "lock:rt_poller"
LOCK_TTL = 30  # > hard limit

@shared_task(bind=True, queue="critical",
             soft_time_limit=10, time_limit=15,
             # no autoretry: rely on next scheduled tick
             )
def gtfs_rt_poller(self):
    got = r.set(LOCK_KEY, "1", nx=True, ex=LOCK_TTL)
    if not got:
        logging.info("rt_poller: previous run still active; skipping")
        return

    try:
        # one HTTP call with tight timeouts
        resp = requests.get(NSW_RT_URL, headers=AUTH,
                            timeout=(3, 8))  # (connect, read)
        resp.raise_for_status()
        entities = parse_protobuf(resp.content)
        write_to_redis_cache(entities)  # short TTLs
    except SoftTimeLimitExceeded:
        logging.warning("rt_poller soft limit -> exit quickly")
    except requests.HTTPError as e:
        logging.exception("rt_poller http error: %s", e)
        # no retry; next schedule handles it
    finally:
        r.delete(LOCK_KEY)
```

**Daily GTFS Static Sync (dedupe, backoff):**

```python
# app/workers/gtfs_static_sync.py
from celery import shared_task
from celery.exceptions import SoftTimeLimitExceeded

@shared_task(bind=True, queue="batch",
             autoretry_for=(requests.Timeout, requests.ConnectionError),
             retry_backoff=True, retry_backoff_max=1800, retry_jitter=True,
             max_retries=3,
             soft_time_limit=1800, time_limit=3600)
def gtfs_static_sync(self):
    lock_key = f"lock:gtfs_sync:{today()}"
    if not r.set(lock_key, "1", nx=True, ex=7200):
        logger.info("GTFS static sync already running; skipping")
        return
    try:
        z = download_gtfs_zip()       # stream to disk
        unpack_dir = safe_extract(z)  # avoid zip-slip
        load_to_supabase(unpack_dir)  # chunked UPSERTs
        mark_version(todays_hash())
    except SoftTimeLimitExceeded:
        logger.warning("GTFS sync soft limit; stopping early, will retry")
        raise
    finally:
        r.delete(lock_key)
```

**Alert Matcher (short-lived, gentle retries):**

```python
@shared_task(bind=True, queue="normal",
             autoretry_for=(redis.ConnectionError, requests.Timeout),
             retry_backoff=True, retry_jitter=True, max_retries=2,
             soft_time_limit=20, time_limit=30)
def alert_matcher(self):
    delays = read_delays_from_cache()
    favs = fetch_user_favorites()  # Supabase, fast query
    notifications = match(delays, favs)  # pure function
    enqueue_apns(notifications)
```

**APNs Worker (rate limiting + idempotency):**

```python
@shared_task(bind=True, queue="normal",
             autoretry_for=(requests.HTTPError, requests.Timeout),
             retry_backoff=True, retry_jitter=True, max_retries=3,
             # Celery rate limit per worker; tune conservative first:
             rate_limit="50/s",   # adjust based on 429s
             soft_time_limit=8, time_limit=12)
def apns_worker(self, payloads):
    for p in payloads:
        headers = {
          "apns-id": p["id"],  # trace each send
          "apns-collapse-id": p["collapse_id"],  # dedupe on device
          "apns-push-type": "alert",
        }
        resp = apns_post(p["token"], p["payload"], headers=headers)
        if resp.status_code in (400, 410):  # BadDeviceToken / Unregistered
            delete_device_token(p["token"])
        elif resp.status_code in (429, 500, 503):
            wait = resp.headers.get("Retry-After")
            if wait:
                time.sleep(parse_retry_after(wait))  # respect server hint
            raise requests.HTTPError("transient")  # let Celery back off
```

### Worker Pool Sizing & Scaling

**MVP (0-1K users):**
- Worker A (critical): `-Q critical -c 1 --prefetch-multiplier=1`
- Worker B (service): `-Q normal,batch -c 2 --prefetch-multiplier=1 --autoscale=3,1`
- Beat: same container (budget), singleton

**Scale up when:**
- `len(normal)` > **50** for **5+ min**, or p95 CPU > **70%**, or p95 RT poller duration > **8s**
- Daily GTFS sync overlaps with morning peak → add dedicated `batch` worker (even `-c 1` is fine)

**Start Commands (single container, budget-friendly):**

```bash
#!/usr/bin/env bash
set -e
# Enable events so Flower (when you run it) sees activity
export CELERY_OPTS="-E --without-gossip --without-mingle"

# Worker A: critical
celery -A app.workers.celery_app worker -n critical@%h -Q critical -c 1 \
  --prefetch-multiplier=1 -O fair $CELERY_OPTS &

# Worker B: service
celery -A app.workers.celery_app worker -n service@%h -Q normal,batch -c 2 \
  --prefetch-multiplier=1 --autoscale=3,1 -O fair $CELERY_OPTS &

# Beat (singleton)
celery -A app.workers.celery_app beat --pidfile=/tmp/celerybeat.pid

wait -n
```

### Monitoring (solo-dev friendly)

**Flower (on demand):** Real-time web UI using Celery events—ideal for incident triage. Run it ad-hoc to keep baseline costs at zero.

```bash
celery -A app.workers.celery_app flower --port=5555
```

**Sentry:** Capture exceptions from workers (first, most valuable signal)

**Lightweight metrics (Supabase table):** Append rows from Celery signals (`task_prerun`, `task_postrun`, `task_failure`) with `{task, status, duration_ms, queue_depth, worker_mem_mb}`. This avoids standing up Prometheus/Grafana and meets your budget.

**Alert rules** (trigger e.g., by a FastAPI cron or tiny Beat task that scans the metrics table):
- `gtfs_static_sync` **failed** last run → immediate APN/email to dev
- `gtfs_rt_poller` **failed 5+ times in 10 min** → alert
- `queue_depth(normal) > 100 for 5+ min` → alert
- `worker_memory > 180 MB` sustained → warning

### Cost Notes (MVP Budget)

- **Redis broker:** Upstash **free** (10k requests/day) isn't sufficient for Celery + your cache; pick a paid plan or Railway's managed Redis to avoid hitting the cap
- **One container with Beat + two workers** keeps service count low (Railway/Fly bill per service/resources)
- **CPU/mem:** `-c 1` + `-c 2` with 512 MB–1 GB RAM total is typically enough for 0–1k users (poller is lightweight; static sync happens off-peak)

**Source:** Based on Celery routing best practices ([Celery Documentation](https://docs.celeryq.dev/en/latest/userguide/workers.html)), Open edX production guidance ([docs.openedx.org](https://docs.openedx.org/projects/edx-platform/en/latest/how-tos/celery.html)), and time limit/acks patterns from Celery official docs.

---

## 5. ✅ Background Job Scheduling (Oracle Reviewed)

**Oracle Consultation:** Based on Celery periodic tasks docs, Sydney DST handling (Reserve Bank of Australia), and production scheduling patterns

### DST-Safe Validated Schedule

**Critical Settings (app-level):**

```python
# app/workers/celery_settings.py
# Core timezone/DST-safe settings
timezone = "Australia/Sydney"         # Celery uses this TZ for crontab schedules
enable_utc = True                     # keep UTC on; Celery handles TZ conversion

# Beat behavior: don't "catch up" cron slots far in the past after a restart
# (prevents a burst at boot if beat was down)
beat_cron_starting_deadline = 120     # seconds (added in Celery 5.3+)

# Make beat responsive for sub-minute schedules without burning CPU
beat_max_loop_interval = 30           # default scheduler is 300s; 30s is safer for 30s ticks

# Worker-side safety for long tasks
worker_prefetch_multiplier = 1        # don't prefetch many long jobs per process
task_acks_late = True                 # ack after task finishes (idempotency required)
```

**Verified 2025 Sydney DST Dates:**
- **DST ends (fall back):** Sun 6 Apr 2025, 03:00 AEDT → 02:00 AEST
- **DST starts (spring forward):** Sun 5 Oct 2025, 02:00 AEST → 03:00 AEDT

**Strategy:** Schedule daily GTFS sync at **03:10** (avoids 02:00–03:00 hazard window on both DST transitions)

### Complete Beat Schedule

```python
# app/celerybeat_schedule.py
from celery.schedules import crontab

CELERYBEAT_SCHEDULE = {
    # 1) GTFS Static Pipeline (chain) — runs daily *after* DST hazard window
    #    03:10 local Sydney time is safe on both DST start/end days
    "gtfs-pipeline": {
        "task": "app.workers.gtfs_pipeline.run",      # chain inside this task
        "schedule": crontab(hour=3, minute=10),
        "options": {
            "queue": "batch",                         # single-concurrency queue
            "expires": 4 * 3600,                      # drop if not started within 4h
            "time_limit": 5400,                       # 90m hard
            "soft_time_limit": 3600,                  # 60m soft
            "priority": 5,
        },
    },

    # 2) GTFS-RT Polling — every 30s; task decides how hard to work based on hour
    #    (Off-peak: do lighter fetch or early-return; Peak: full refresh)
    "gtfs-rt-poll": {
        "task": "app.workers.gtfs_rt_poller.poll_gtfs_rt_feeds",
        "schedule": 30.0,
        "options": {
            "queue": "critical",
            "expires": 25,          # if delayed >25s, skip (prevents backlog)
            "priority": 7,
        },
    },

    # 3) Alert Matching — minute-granularity; keep two declarative slots for peak/off-peak
    "alert-matcher-peak": {
        "task": "app.workers.alert_matcher.match_delays_to_favorites",
        "schedule": crontab(minute="*/2", hour="7-9,17-19"),   # 2 min during peak
        "options": {"queue": "normal", "expires": 60, "priority": 6},
    },
    "alert-matcher-offpeak": {
        "task": "app.workers.alert_matcher.match_delays_to_favorites",
        "schedule": crontab(minute="*/5", hour="0-6,10-16,20-23"),  # 5 min off-peak
        "options": {"queue": "normal", "expires": 180, "priority": 6},
    },

    # 4) Hourly housekeeping
    "usage-rollup": {
        "task": "app.workers.usage.rollup_usage_hourly",
        "schedule": crontab(minute=5),
        "options": {"queue": "normal", "expires": 1800},
    },
    "cost-check": {
        "task": "app.workers.cost_monitor.check_cost_limits",
        "schedule": crontab(minute=10),
        "options": {"queue": "normal", "expires": 1800},
    },

    # 5) Storage cleanup (weekly, well outside DST hazard)
    "storage-cleanup": {
        "task": "app.workers.cleanup.cleanup_old_gtfs_files",
        "schedule": crontab(hour=2, minute=0, day_of_week=0),
        "options": {"queue": "batch", "expires": 6 * 3600},
    },

    # 6) Beat heartbeat (for self-monitoring)
    "beat-heartbeat": {
        "task": "app.workers.monitoring.beat_heartbeat",
        "schedule": 60.0,
        "options": {"queue": "normal", "expires": 120},
    },
}
```

### Overlap Prevention Pattern

**Use Redis-backed singleton + single-concurrency queue:**

```python
# app/workers/locks.py
import os, uuid, redis

REDIS_URL = os.getenv("REDIS_URL")
r = redis.Redis.from_url(REDIS_URL)

# Lua script for safe release: delete only if token matches
_RELEASE_IF_MATCH = r.register_script("""
if redis.call("GET", KEYS[1]) == ARGV[1] then
  return redis.call("DEL", KEYS[1])
else
  return 0
end
""")

class SingletonLock:
    def __init__(self, name: str, ttl: int):
        self.key = f"lock:{name}"
        self.ttl = ttl
        self.token = uuid.uuid4().hex

    def acquire(self) -> bool:
        # SET key value NX EX ttl  — atomic lock with expiration
        return bool(r.set(self.key, self.token, nx=True, ex=self.ttl))

    def refresh(self):  # optional heartbeat extension if long-running
        r.expire(self.key, self.ttl)

    def release(self):
        _RELEASE_IF_MATCH(keys=[self.key], args=[self.token])
```

**GTFS Pipeline with chain + lock:**

```python
# app/workers/gtfs_pipeline.py
from celery import shared_task, chain
from app.workers.locks import SingletonLock
from datetime import date

@shared_task(bind=True, name="app.workers.gtfs_pipeline.run",
             soft_time_limit=3600, time_limit=5400, acks_late=True)
def run(self):
    # One pipeline per day, no overlaps
    lock = SingletonLock(f"gtfs_pipeline:{date.today().isoformat()}", ttl=7200)
    if not lock.acquire():
        return "skipped: already running"

    try:
        workflow = chain(
            gtfs_static_sync.s(),
            refresh_materialized_views.s(),
            generate_ios_sqlite.s(),
            upload_to_cdn.s()
        )
        return workflow.apply_async()
    finally:
        lock.release()
```

### Peak vs Off-Peak Handling

**Alert matcher:** Use **two crontab entries** (simple, readable)
- Peak (7-9am, 5-7pm): Every 2 minutes
- Off-peak: Every 5 minutes

**GTFS-RT poller:** Use **one 30s schedule** and branch inside task:

```python
# Inside poller
now = datetime.now(tz=pytz.timezone("Australia/Sydney"))
is_peak = now.hour in {7,8,9,17,18,19}
if not is_peak:
    # off-peak mode: smaller set of feeds, or return early 50% of ticks
    if now.second % 60 != 0:    # only work once per minute off-peak
        return "off-peak skip"
# proceed with full poll
```

This gives ~50% fewer calls at night without scheduler complexity.

### Failure Recovery & Beat Heartbeat

**Beat Heartbeat (self-healing):**

```python
# app/workers/monitoring.py
import time
@shared_task(name="app.workers.monitoring.beat_heartbeat")
def beat_heartbeat():
    r.set("beat:last_heartbeat", int(time.time()), ex=300)

def check_beat_health():
    last = r.get("beat:last_heartbeat")
    if not last or (time.time() - int(last) > 180):
        # Alert dev: e.g., Sentry capture_message or APNs to self
        pass
```

**What if beat restarts and misses 03:10?**
- Celery doesn't "catch up" by default
- With `beat_cron_starting_deadline=120`, beat **won't** dispatch old cron slots beyond 2 minutes
- If you reach 04:00 and pipeline didn't happen, manual trigger (or health task) will run the idempotent pipeline exactly once thanks to `gtfs:last_sync_date`

### Task Chaining (Dependencies)

**Decision:** Chain the daily pipeline behind a **single beat trigger** (03:10) so refresh/generation/upload strictly follow sync

**Why:** This prevents overlap and guessing durations. Handle mid-chain failure by retrying the failed task; idempotency makes re-runs safe.

```python
# Chain example (already shown above)
workflow = chain(
    gtfs_static_sync.s(),           # Step 1: Download + parse GTFS
    refresh_materialized_views.s(), # Step 2: Refresh aggregated views
    generate_ios_sqlite.s(),        # Step 3: Build iOS database
    upload_to_cdn.s()                # Step 4: Upload to CDN
)
```

### Bill Explosion Safeguards

**Startup validation:**

```python
def validate_schedule(schedule_config):
    MIN_SECONDS = 10.0
    for name, cfg in schedule_config.items():
        sched = cfg["schedule"]
        if isinstance(sched, (int, float)):
            assert sched >= MIN_SECONDS, f"{name}: interval < {MIN_SECONDS}s not allowed"
        # validate expires < 50% of interval for intervals
        opts = cfg.get("options", {})
        if isinstance(sched, (int,float)) and "expires" in opts:
            assert opts["expires"] <= sched, f"{name}: expires must be <= interval"
```

**Per-task safeguards:**
- Message `expires` causes workers to **revoke** late tasks on receipt
- Task rate limits via annotations if needed to cap processing rates globally per task
- **Prefetch=1 for long tasks** to avoid a worker hoarding many heavy jobs

### Operational Runbook

- **Run exactly one beat** process (accidental double-beat is classic dupe source)
- **Queues/workers (low cost):**
  - `celery -A app.workers.celery_app worker -Q critical,normal,default,maintenance -c 2`
  - `celery -A app.workers.celery_app worker -Q batch --concurrency=1`
- **Deploy flags:** Include `--pidfile` and log file for beat; pin beat to same VM as small worker
- **Logs to watch:**
  - "Scheduler: Sending due task …" around 03:10
  - Lock "skipped: already running" (should be rare)
- **If you must reboot near 03:00–04:00:** Rely on `beat_cron_starting_deadline` + idempotency

**Source:** Based on Celery periodic tasks & timezone docs ([Celery Documentation](https://docs.celeryq.dev/en/stable/userguide/periodic-tasks.html)), Sydney DST official dates ([Reserve Bank of Australia](https://www.rba.gov.au/schedules-events/daylight-saving.html)), and Redis locking patterns ([Redis SET NX EX](https://redis.io/docs/latest/commands/set/))

---

## 6. ✅ Rate Limiting Strategy (Oracle Reviewed)

**Oracle Consultation:** Based on Redis Lua patterns, HTTP 429 standards (MDN), Cloudflare WAF docs, and NSW API limits ([Transport for NSW Developer Portal](https://developer.transport.nsw.gov.au/developers/api-basics))

### A) NSW API Distributed Rate Limiter (Outbound)

**Requirements:**
- NSW Bronze plan: **5 req/s** (hard limit), **60,000/day**
- Our target: **4.5 req/s safety margin**, <20K/day (met by adaptive polling)
- Must coordinate across **all FastAPI + Celery processes**

**Decision:** **Hybrid Pattern** = Redis Lua token bucket (fast path) + Redis Stream fallback (slow path for bursts)

**Why:** Atomic operations via Lua ensure exact rate limiting across distributed processes; Stream provides backpressure without blocking.

#### Implementation: Redis Lua Token Bucket

```python
# backend/app/utils/rate_limiters.py
from __future__ import annotations
import os, math, time, random
from dataclasses import dataclass
from typing import Optional, Tuple
import redis
from zoneinfo import ZoneInfo
from datetime import datetime

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

_redis: Optional[redis.Redis] = None
def get_redis() -> redis.Redis:
    global _redis
    if _redis is None:
        _redis = redis.from_url(REDIS_URL, decode_responses=True)
    return _redis

# Lua token bucket script (atomic, uses Redis server time to avoid clock skew)
LUA_TOKEN_BUCKET = r"""
local key = KEYS[1]
local capacity = tonumber(ARGV[1])
local refill_rate = tonumber(ARGV[2])

-- get Redis server time in ms
local t = redis.call('TIME')
local now_ms = t[1] * 1000 + math.floor(t[2] / 1000)

local data = redis.call('HMGET', key, 'tokens', 'ts_ms')
local tokens = tonumber(data[1])
local ts_ms = tonumber(data[2])

if tokens == nil then
  tokens = capacity
end
if ts_ms == nil then
  ts_ms = now_ms
end

local elapsed_ms = now_ms - ts_ms
if elapsed_ms < 0 then
  elapsed_ms = 0
end

-- refill
local refill_tokens = (elapsed_ms / 1000.0) * refill_rate
tokens = math.min(capacity, tokens + refill_tokens)

local allowed = 0
local retry_ms = 0
if tokens >= 1.0 then
  tokens = tokens - 1.0
  allowed = 1
else
  local missing = 1.0 - tokens
  retry_ms = math.ceil(1000.0 * (missing / refill_rate))
end

redis.call('HMSET', key, 'tokens', tokens, 'ts_ms', now_ms)
return {allowed, tokens, retry_ms}
"""

@dataclass
class TbResult:
    allowed: bool
    tokens_left: float
    retry_after_ms: int

class RedisTokenBucket:
    """
    Distributed token bucket backed by Redis Lua.
    Intended for coordinating NSW API calls across FastAPI and Celery.
    """
    def __init__(self, key: str, capacity: float = 5.0, refill_rate: float = 4.5):
        self.r = get_redis()
        self.key = key
        self.capacity = float(capacity)
        self.refill_rate = float(refill_rate)
        self.sha = self.r.script_load(LUA_TOKEN_BUCKET)

    def acquire(self) -> TbResult:
        allowed, tokens_left, retry_ms = self.r.evalsha(
            self.sha, 1, self.key, self.capacity, self.refill_rate
        )
        return TbResult(bool(int(allowed)), float(tokens_left), int(retry_ms))

# Daily / hourly quota trackers (Australia/Sydney timezone)
SYD_TZ = ZoneInfo("Australia/Sydney")

def _sydney_day_key(prefix: str) -> str:
    today = datetime.now(SYD_TZ).strftime("%Y%m%d")
    return f"{prefix}:{today}"

def incr_nsw_counters(n: int = 1) -> Tuple[int, int]:
    """Increment daily and hourly counters; returns (day_total, hour_total)."""
    r = get_redis()
    now = datetime.now(SYD_TZ)
    k_day = _sydney_day_key("nsw:quota:day")
    k_hr = f"nsw:quota:hour:{now.strftime('%Y%m%d%H')}"
    pipe = r.pipeline()
    pipe.incrby(k_day, n)
    pipe.expire(k_day, 60*60*48)  # keep 2 days
    pipe.incrby(k_hr, n)
    pipe.expire(k_hr, 60*60*6)    # keep a few hours
    day_total, _, hr_total, _ = pipe.execute()
    return int(day_total), int(hr_total)

def get_nsw_counts() -> Tuple[int, int]:
    r = get_redis()
    k_day = _sydney_day_key("nsw:quota:day")
    now = datetime.now(SYD_TZ)
    k_hr = f"nsw:quota:hour:{now.strftime('%Y%m%d%H')}"
    day = int(r.get(k_day) or 0)
    hr = int(r.get(k_hr) or 0)
    return day, hr
```

#### NSW Gateway (Fast Path + Stream Fallback)

```python
# backend/app/services/nsw_gateway.py
import os, httpx
from app.utils.rate_limiters import RedisTokenBucket, incr_nsw_counters

NSW_BASE_URL = os.getenv("NSW_BASE_URL", "https://api.transport.nsw.gov.au/v1")
NSW_API_KEY = os.getenv("NSW_API_KEY")
NSW_REFILL_RPS = float(os.getenv("NSW_REFILL_RPS", "4.5"))  # <= 4.5 for safety
HOURLY_BUDGET = int(os.getenv("NSW_HOURLY_BUDGET", "2500"))

bucket = RedisTokenBucket("nsw:tb", capacity=5.0, refill_rate=NSW_REFILL_RPS)
_headers = {"Authorization": f"apikey {NSW_API_KEY}"} if NSW_API_KEY else {}

async def call_nsw_fast(method: str, path: str, *, params=None, json_body=None, timeout=10.0) -> httpx.Response:
    """Fast path: acquire token and call NSW immediately."""
    res = bucket.acquire()
    if not res.allowed:
        raise RuntimeError(f"Rate limited, retry in {res.retry_after_ms}ms")

    # Budget guards
    day_total, hr_total = incr_nsw_counters(1)
    if hr_total > HOURLY_BUDGET:
        raise RuntimeError("Hourly NSW budget exceeded")

    async with httpx.AsyncClient(base_url=NSW_BASE_URL, timeout=timeout) as client:
        resp = await client.request(method, path, params=params, json=json_body, headers=_headers)
    return resp
```

**429 Handling (Exponential Backoff + Retry-After):**

```python
# backend/app/utils/retries.py
import asyncio, math, random

async def respectful_retry_after(resp, attempt: int, base: float = 0.5, cap: float = 8.0):
    # If 429 + Retry-After present, obey it:
    ra = resp.headers.get("Retry-After")
    if resp.status_code == 429 and ra:
        try:
            await asyncio.sleep(float(ra))
            return
        except ValueError:
            pass
    # Else exponential backoff with full jitter (AWS best practice)
    delay = min(cap, (2 ** attempt) * base)
    await asyncio.sleep(random.random() * delay)
```

#### Daily Quota Management (60K/day)

**Soft alerts & graceful degradation:**

```python
# backend/app/workers/quota_guard.py
from celery import Celery
from app.utils.rate_limiters import get_nsw_counts

app = Celery("quota_guard")

@app.task
def check_nsw_quota():
    day, hr = get_nsw_counts()
    # Soft alerts at 80% (48K) and 95% (57K)
    if day >= 48000:
        print(f"[ALERT] NSW API quota at {day}/60000 (>=80%)")
    if day >= 57000:
        print(f"[CRITICAL] NSW API quota at {day}/60000 (>=95%) -- disable user-triggered planner")
```

**Degradation strategy:**
- **At 80% (48K/day):** Log alert; slow GTFS-RT polling (30→60s)
- **At 95% (57K/day):** Disable user-triggered trip planning (return 429); prefer stale cache
- **At 100% (60K):** Hard stop NSW calls; serve cached data only with banner "Service degraded until midnight Sydney time"
- **Reset:** Australia/Sydney midnight (not UTC)

---

### B) Inbound API Rate Limiting

**Principles:**
- **Anonymous = per-IP** buckets
- **Authenticated = per-user** (user id/sub)
- **Endpoint class budgets** (cheap vs expensive)
- **Cloudflare edge** for coarse protection; app for fine-grained limits

#### Validated Rate Limit Configuration

| Endpoint                 | Method | Anonymous (per-IP) | Authenticated (per-user) | Algorithm        | Window |
| ------------------------ | ------ | -----------------: | -----------------------: | ---------------- | ------ |
| `/stops/nearby`          | GET    |                 60 |                      120 | Sliding window   | 1 min  |
| `/stops/{id}/departures` | GET    |                 60 |                      120 | Sliding window   | 1 min  |
| `/trips/plan`            | POST   |                 10 |                       30 | Sliding window   | 1 min  |
| `/favorites`             | GET    |                N/A |                       60 | Sliding window   | 1 min  |
| `/favorites`             | POST   |                N/A |                       30 | Sliding window   | 1 min  |

**Rationale:** These numbers allow UI bursts without opening scraping room; trip planning is capped (most expensive path). Sliding/moving windows reduce boundary spikes vs fixed windows.

#### Implementation with SlowAPI

```python
# backend/app/main.py
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.middleware import SlowAPIMiddleware
from slowapi.errors import RateLimitExceeded
from fastapi import FastAPI, Request
from starlette.responses import JSONResponse

app = FastAPI()

REDIS_URL = os.getenv("REDIS_URL")
limiter = Limiter(
    key_func=lambda req: req.state.rate_key,
    storage_uri=REDIS_URL,
    headers_enabled=True,
    strategy="moving-window"  # sliding window counter
)
app.state.limiter = limiter
app.add_middleware(SlowAPIMiddleware)

# Per-request key: IP for anonymous, user_id for authenticated
@app.middleware("http")
async def rate_key_mw(request: Request, call_next):
    user = getattr(request.state, "user", None)
    if user and user.is_authenticated:
        request.state.rate_key = f"user:{user.id}"
    else:
        request.state.rate_key = f"ip:{get_remote_address(request)}"
    response = await call_next(request)
    return response

# Custom 429 handler
@app.exception_handler(RateLimitExceeded)
def ratelimit_handler(request, exc):
    reset = int(exc.reset_time) if hasattr(exc, "reset_time") else 0
    headers = {
        "Retry-After": str(max(1, int(exc.retry_after))) if hasattr(exc, "retry_after") else "1",
        "RateLimit-Policy": "60;w=60",  # example
    }
    return JSONResponse(
        status_code=429,
        content={
            "error": {
                "code": "RATE_LIMIT_EXCEEDED",
                "message": "Rate limit exceeded for this endpoint.",
                "limit": exc.detail if hasattr(exc, "detail") else None,
                "window": "1 minute",
                "retry_after": int(headers["Retry-After"]),
            }
        },
        headers=headers
    )

# Per-endpoint limits with dynamic callable
def cheap_limit(request: Request):
    return "120/minute" if request.state.rate_key.startswith("user:") else "60/minute"

@app.get("/stops/{id}/departures")
@limiter.limit(cheap_limit)
async def departures(...): ...

def expensive_limit(request: Request):
    return "30/minute" if request.state.rate_key.startswith("user:") else "10/minute"

@app.post("/trips/plan")
@limiter.limit(expensive_limit)
async def plan_trip(...): ...
```

#### Graceful Degradation (Cheap Endpoints)

**For departures:** Return **stale cache** (30-120s old) with clear flag instead of hard 429:

```json
{
  "stale": true,
  "cached_at": "2025-11-12T08:10:00Z",
  "message": "Rate limit reached. Showing cached data (up to 2 minutes old).",
  "departures": [...]
}
```

**For expensive endpoints (trip planning):** Return 429 with `Retry-After`

---

### C) Cloudflare Edge Protection (Free Plan)

**Enable:**
- **Bot Fight Mode** (Free plan)
- **Security Level:** Medium

**Create 1 WAF Rate Limiting Rule** (Free includes **one** unmetered rule):
- **Expression:** `http.host eq "api.yourdomain.com" and http.request.uri.path starts_with "/api/v1/"`
- **Threshold:** 600 req/min (per IP)
- **Action:** Challenge

**Why:** Cloudflare catches scrapers/loops before origin; app enforces nuanced per-endpoint logic.

**Source:** ([Cloudflare Unmetered Rate Limiting](https://blog.cloudflare.com/unmetered-ratelimiting/))

---

### D) Monitoring & Alerting

**Emit the following metrics** (Redis counters + logs; optionally mirror to Supabase):

- `api_rate_limit_hits_total{endpoint,user_type}` — counter
- `nsw_api_rate_limiter_wait_seconds` — histogram (record retry_after_ms/1000)
- `nsw_api_quota_usage` — gauge (daily count)
- `nsw_api_quota_percent` — gauge (`daily/60000*100`)

**If you later want charts:** Insert rows into a `metrics` table in Supabase and chart with SQL (no new services necessary)

---

### E) Cost Projection (Overhead of Limiters)

| Users | Requests/min | Redis Overhead | Latency Added | Cost Impact |
| ----: | -----------: | -------------: | ------------: | ----------: |
|    1K |         ~500 |          ~1 MB |         <5 ms |  Negligible |
|    5K |       ~2,500 |          ~5 MB |         <5 ms |      +$1/mo |
|   10K |       ~5,000 |         ~10 MB |        <10 ms |      +$2/mo |

Redis Lua runs in-process; round-trip is minimal and amortized by cache traffic.

---

### F) Algorithm Summary

**Outbound (NSW API):** Token bucket via Lua (fast path) + Redis Stream fallback (slow path for bursts)

**Inbound (our API):** Sliding/moving window via `limits` (SlowAPI) — balances burst-friendliness and fairness

**Why:** Token bucket allows bursts up to capacity while honoring steady average; sliding windows smooth boundary spikes vs fixed windows

**Sources:**
- Redis Lua programmability ([Redis Docs](https://redis.io/docs/latest/develop/programmability/eval-intro/))
- HTTP 429 + Retry-After semantics ([MDN](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Status/429))
- Exponential backoff with jitter ([AWS Architecture Blog](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/))
- Cloudflare WAF rate limiting ([Cloudflare Blog](https://blog.cloudflare.com/unmetered-ratelimiting/))
- NSW Bronze plan limits: **5/sec**, **60k/day** ([Transport for NSW](https://developer.transport.nsw.gov.au/developers/api-basics))

---

## 7. Authentication & Authorization

### Supabase Auth Integration

**Flow:**
```
iOS App → Apple Sign-In → Supabase Auth → JWT Token → FastAPI
```

**Implementation:**
```python
# app/dependencies/auth.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from supabase import Client

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    supabase: Client = Depends(get_supabase)
) -> User:
    token = credentials.credentials

    try:
        # Verify JWT with Supabase
        user_data = supabase.auth.get_user(token)

        if not user_data:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )

        return User(**user_data.user.dict())

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )

# Protected endpoint example
@router.get("/favorites")
async def get_favorites(user: User = Depends(get_current_user)):
    # RLS in Supabase automatically filters by user.id
    ...
```

**Public vs Protected Endpoints:**
- **Public (no auth):** Stops, routes, departures, trip planning
- **Protected (auth required):** Favorites, saved trips, notification preferences

---

## 8. Error Handling & Resilience

### Standard Error Responses

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "Stop with ID '12345' not found",
    "details": {},
    "timestamp": "2025-11-12T08:15:30Z",
    "request_id": "req_abc123"
  }
}
```

**Error Codes:**
- `INVALID_REQUEST` - 400 Bad Request
- `UNAUTHORIZED` - 401 Unauthorized
- `FORBIDDEN` - 403 Forbidden
- `RESOURCE_NOT_FOUND` - 404 Not Found
- `RATE_LIMIT_EXCEEDED` - 429 Too Many Requests
- `INTERNAL_ERROR` - 500 Internal Server Error
- `SERVICE_UNAVAILABLE` - 503 Service Unavailable (NSW API down)

### Circuit Breaker Pattern

```python
# app/utils/circuit_breaker.py
from pybreaker import CircuitBreaker, CircuitBreakerError

nsw_api_breaker = CircuitBreaker(fail_max=5, reset_timeout=60)

@nsw_api_breaker
async def fetch_nsw_api(url: str):
    # Wraps NSW API calls
    # Opens circuit after 5 consecutive failures
    # Resets after 60 seconds
    response = await httpx.get(url, timeout=5)
    response.raise_for_status()
    return response

# Usage
try:
    data = await fetch_nsw_api(url)
except CircuitBreakerError:
    # Circuit is open, serve stale cache
    logger.warning("NSW API circuit breaker open, serving stale data")
    return serve_stale_cache(stop_id)
```

---

## 9. Deployment Architecture (Railway/Fly.io)

### Service Configuration

**Railway:**
```yaml
# railway.toml
[build]
builder = "NIXPACKS"

[deploy]
startCommand = "gunicorn app.main:app --workers 2 --worker-class uvicorn.workers.UvicornWorker --bind 0.0.0.0:$PORT"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 3

[[services]]
name = "api"
port = 8000

[[services]]
name = "celery-worker"
command = "celery -A app.celery_app worker --loglevel=info --concurrency=2"

[[services]]
name = "celery-beat"
command = "celery -A app.celery_app beat --loglevel=info"
```

### Scaling Configuration

**MVP (0-1K users):**
- 1 web server (2 Uvicorn workers)
- 1 Celery worker (2 processes)
- 1 Celery Beat scheduler
- ~$10-20/month on Railway

**Growth (1K-10K users):**
- 2-3 web servers (horizontal scaling)
- 2-3 Celery workers
- 1 Celery Beat (singleton)
- ~$50-100/month

---

## 10. Observability & Monitoring

### Health Checks

```python
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat()
    }

@app.get("/health/detailed")
async def detailed_health_check(
    redis: Redis = Depends(get_redis),
    db: AsyncSession = Depends(get_db)
):
    checks = {
        "database": await check_database(db),
        "redis": await check_redis(redis),
        "nsw_api": await check_nsw_api(),
        "celery": await check_celery_workers()
    }

    all_healthy = all(c["status"] == "healthy" for c in checks.values())

    return {
        "status": "healthy" if all_healthy else "degraded",
        "checks": checks,
        "timestamp": datetime.utcnow().isoformat()
    }
```

### Metrics

```python
from prometheus_client import Counter, Histogram, Gauge

# Counters
api_requests_total = Counter("api_requests_total", "Total API requests", ["method", "endpoint", "status"])
nsw_api_calls_total = Counter("nsw_api_calls_total", "Total NSW API calls", ["feed_type"])

# Histograms
request_duration_seconds = Histogram("request_duration_seconds", "Request duration", ["endpoint"])

# Gauges
celery_workers_active = Gauge("celery_workers_active", "Active Celery workers")
redis_memory_usage_bytes = Gauge("redis_memory_usage_bytes", "Redis memory usage")

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time

    request_duration_seconds.labels(endpoint=request.url.path).observe(duration)
    api_requests_total.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()

    return response
```

---

## 11. Open Questions & Next Steps

### Awaiting Oracle Decisions

1. ✅ **Section 4:** Celery Worker Task Design (priorities, timeouts, retries, pool sizing)
2. ✅ **Section 5:** Background Job Scheduling (Beat config, overlap prevention, time zones)
3. ✅ **Section 6:** Rate Limiting Strategy (algorithms, limits per endpoint, NSW burst handling)

### After Oracle Consultation

**Update this document with:**
- Oracle's recommended Celery configuration
- Oracle's optimal Beat schedule
- Oracle's rate limiting architecture

**Then create:**
- IOS_APP_SPECIFICATION.md (MVVM, ViewModels, coordinators)
- INTEGRATION_CONTRACTS.md (API contracts, APNs architecture)

---

## 12. Success Criteria

This backend succeeds if:

✅ **Performance:**
- API response times: <200ms p95 for common queries
- Real-time data freshness: <60s staleness
- Background jobs complete on schedule (no delays/overlaps)

✅ **Reliability:**
- Uptime: 99.9% (43 min downtime/month allowed)
- Graceful degradation when NSW API down
- Circuit breakers prevent cascading failures
- Self-healing workers (automatic restarts, memory recycling)

✅ **Scalability:**
- Handles 1K users with single worker
- Clear triggers for scaling (CPU, memory, queue depth)
- Can scale to 10K users without refactor

✅ **Cost:**
- MVP: <$25/month (Railway + Redis + Supabase free tiers)
- Growth: <$150/month at 10K users
- No surprise bills (monitoring alerts at 80% thresholds)

✅ **Security:**
- Rate limiting prevents abuse
- Supabase RLS protects user data
- API keys/JWT tokens properly validated
- No SQL injection vulnerabilities

---

**Document Status:** 🟡 60% Complete - Awaiting 3 Oracle Consultations
**Critical Blockers:** 3 Oracle consultations required (Sections 4, 5, 6)
**Next Step:** Create 3 Oracle prompt files, submit for consultation
**Last Updated:** 2025-11-12
