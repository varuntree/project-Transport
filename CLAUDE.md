# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: Sydney Transit App (iOS + FastAPI Backend)

Transit app for Sydney: TripView reliability + Transit features + iOS polish. Real-time departures, trip planning, alerts, push notifications.

**Status:** Architecture complete, implementation not started (Phase 0 pending).

## Tech Stack (Fixed)

**Backend:**
- FastAPI (Python) + Celery workers (3 queues: critical/normal/batch)
- Supabase (PostgreSQL + Auth + Storage, 500MB free tier)
- Redis (Railway/Upstash for GTFS-RT caching)
- Railway/Fly.io hosting

**iOS:**
- Swift/SwiftUI, iOS 16+, MVVM + Coordinator pattern
- GRDB (bundled 15-20MB GTFS SQLite)
- Supabase Swift (auth, sync)

**Data:**
- NSW Transport GTFS (227MB static, GTFS-RT every 30s)
- NSW API: 5 req/s limit, 60K calls/day

## Key Constraints

- **Solo dev:** Simplicity > optimization, self-healing systems
- **Budget:** $25/mo MVP (0-1K users), maximize free tiers
- **App size:** <50MB download (pattern model, compression, Sydney-only filtering)
- **No new services:** Use only planned stack above

## Architecture Docs (Read Before Implementation)

All specs in `oracle/`:

**Core Specs:**
- `specs/SYSTEM_OVERVIEW.md` - Project summary, positioning, features
- `specs/DATA_ARCHITECTURE.md` - GTFS-RT caching (adaptive polling, blob model), GTFS pipeline (pattern model, 8-15× compression), DB schema (PostGIS, <50MB), cost safeguards
- `specs/BACKEND_SPECIFICATION.md` - FastAPI routes, Celery tasks (30s RT polling, DST-safe scheduling), rate limiting (Lua token bucket)
- `specs/IOS_APP_SPECIFICATION.md` - MVVM structure, repositories, coordinators, offline-first
- `specs/INTEGRATION_CONTRACTS.md` - REST API contracts, auth flow, APNs architecture (SQL alert matching, 3-layer dedup)

**Standards:**
- `DEVELOPMENT_STANDARDS.md` - Coding patterns, project structure, DB access, logging (structlog JSON), error handling, testing conventions

**Roadmap:**
- `IMPLEMENTATION_ROADMAP.md` - 7 phases, 14-20 weeks, vertical slicing
- `phases/PHASE_*.md` - Detailed per-phase plans (user setup, implementation checklist, acceptance criteria)

## Implementation Strategy

**Vertical slicing:** Build working features incrementally (backend + iOS together), not layers.

**Phase Order:**
1. **Phase 0** (Week 1-2): Foundation - local dev, hello-world, Supabase/Redis connected
2. **Phase 1** (Week 3-5): Static data - GTFS parser, iOS SQLite, offline browsing
3. **Phase 2** (Week 6-8): Real-time - Celery poller, Redis cache, live departures
4. **Phase 3** (Week 9-11): User features - Apple Sign-In, favorites, sync
5. **Phase 4** (Week 12-13): Trip planning - routing algorithm, MapKit
6. **Phase 5** (Week 14-16): Alerts - matching logic, in-app notifications
7. **Phase 6** (Week 17-18): APNs - push notifications, dedup, quiet hours
8. **Phase 7** (Week 19-20): Production - deploy, monitoring, TestFlight

**Quality gates:** Each phase must pass acceptance criteria before moving to next (prevents cascading failures).

## Dev Commands

**Backend (not yet implemented):**
```bash
# Setup
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # Fill in Supabase, Redis, NSW API keys

# Run
uvicorn app.main:app --reload  # http://localhost:8000
celery -A app.tasks.celery_app worker -Q critical,normal,batch --loglevel=info
celery -A app.tasks.celery_app beat --loglevel=info

# Test
curl http://localhost:8000/health
curl http://localhost:8000/api/v1/stops/200060
redis-cli GET gtfs_rt:train:blob
```

**iOS (not yet implemented):**
```bash
# Open in Xcode
open SydneyTransit.xcodeproj

# Run in simulator (Cmd+R)
# Edit scheme → select Config-Dev.plist for local backend

# Test offline mode (Xcode → Network Link Conditioner → 100% Loss)
```

## Critical Architecture Decisions (Oracle-Reviewed)

**Data layer (8/8 Oracle consultations complete):**
1. **GTFS-RT caching:** Adaptive polling (30s), per-mode blobs (not per-entity keys), ~16.6K calls/day
2. **GTFS pipeline:** Pattern model (8-15× smaller vs stop_times), Sydney filtering (40-60% reduction), 15-20MB iOS SQLite
3. **DB schema:** Pattern tables, PostGIS spatial indexes, <50MB total
4. **Cost safeguards:** Circuit breakers, TTL enforcement, monitoring SQL views
5. **Celery:** 3 queues (not single priority queue), Worker A (1 proc RT), Worker B (2-3 proc service)
6. **Scheduling:** GTFS sync at 03:10 Sydney (DST-safe), RT polling 30s, alert matcher 2-5min peak/off-peak
7. **Rate limiting:** Redis Lua token bucket (4.5 req/s safety margin), SlowAPI sliding windows, Cloudflare WAF
8. **APNs:** SQL alert matching (upgrade to Redis index when DB p95 >150ms), PyAPNs2 batch fan-out, 3-layer dedup

## Code Patterns (from DEVELOPMENT_STANDARDS.md)

**Backend structure:**
```
backend/app/
├── api/v1/          # Routes (stops.py, routes.py, trips.py, etc.)
├── models/          # Pydantic request/response models
├── services/        # Business logic (gtfs_service, realtime_service, nsw_api_client)
├── db/              # Supabase/Redis singletons
├── tasks/           # Celery tasks (gtfs_rt_poller, alert_matcher, apns_worker)
└── utils/           # Logging, rate_limiter, date_utils
```

**iOS structure:**
```
SydneyTransit/
├── Core/            # Network (APIClient), Database (GRDB), Auth (Supabase)
├── Data/            # Models, Repositories (protocol-based), DTOs
├── Features/        # MVVM modules (Home, Search, Departures, TripPlanner, etc.)
├── UI/              # Shared components, styles
└── Resources/       # gtfs.db (bundled), Assets
```

**API envelope (all responses):**
```json
{
  "data": { ... },
  "meta": { "pagination": { "offset": 0, "limit": 20, "total": 150 } }
}
```

**Error response:**
```json
{
  "error": {
    "code": "STOP_NOT_FOUND",
    "message": "Stop with ID '12345' does not exist",
    "details": {}
  }
}
```

**Logging (structlog JSON):**
```python
logger.info("stop_fetched", stop_id="12345", user_id="user_abc", duration_ms=120)
```
- Never log PII (email, name), tokens, full bodies

**Celery tasks:**
```python
@celery_app.task(
    name='poll_gtfs_rt',
    queue='critical',
    bind=True,
    max_retries=3,
    time_limit=15,
    soft_time_limit=10
)
def poll_gtfs_rt(self):
    # Redis SETNX lock for idempotency
    pass
```

**iOS repositories (protocol-based):**
```swift
protocol StopRepository {
    func fetchStop(id: String) async throws -> Stop
}

class StopRepositoryImpl: StopRepository {
    func fetchStop(id: String) async throws -> Stop {
        // Try GRDB (offline), fallback to APIClient
    }
}
```

**iOS ViewModels (@MainActor):**
```swift
@MainActor
class DeparturesViewModel: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: RealtimeRepository

    func loadDepartures(stopId: String) async { ... }
}
```

## Git Workflow

**Branches:** `phase-N-feature-name` (e.g., `phase-0-project-setup`, `phase-2-realtime-poller`)

**Commits:** `<type>: <description>` (feat/fix/refactor/docs/test/chore)
- Example: `feat: add stop search API endpoint`

**Per phase:**
1. Work in `phase-N-*` branch
2. At phase end: merge to `main`, tag `phase-N-complete`

## When Starting Implementation

**Phase 0 (next step):**
1. Read `oracle/phases/PHASE_0_FOUNDATION.md` (detailed plan)
2. User must complete setup: Supabase account, Railway account, NSW API key, Xcode/Python installed
3. Follow DEVELOPMENT_STANDARDS.md exactly (structure, logging, patterns)
4. Verify acceptance criteria before moving to Phase 1

**For any phase:**
- Always check `oracle/phases/PHASE_N_*.md` first (user setup, implementation checklist)
- Follow DEVELOPMENT_STANDARDS.md (no exceptions unless updated)
- Log structured events (JSON), handle errors gracefully (4xx/5xx)
- Manual test with acceptance criteria before marking complete

## Critical Principles

1. **Simplicity first:** 0 users initially, avoid premature optimization
2. **Cost-conscious:** Maximize free tiers, monitor at 80% thresholds
3. **Offline-first (iOS):** GRDB bundled data, graceful degradation
4. **Self-healing:** Circuit breakers, TTL enforcement, task timeouts
5. **Solo-friendly:** Clear logs, one-click deploy, predictable patterns
6. **Standards compliance:** DEVELOPMENT_STANDARDS.md is law (update doc if pattern changes)

## Current Status

- Architecture: 100% complete (5 specs, 8 Oracle consultations integrated)
- Implementation: 0% (waiting for Phase 0 start)
- Next action: User completes Phase 0 setup → AI implements PHASE_0_FOUNDATION.md
