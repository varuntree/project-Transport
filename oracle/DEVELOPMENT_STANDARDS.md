# Development Standards - Sydney Transit App
**Version:** 1.0
**Date:** 2025-11-12
**Purpose:** Coding patterns, conventions, and standards for consistent implementation across all phases

---

## Document Purpose

This document defines the coding standards and patterns to be followed across all 7 implementation phases. These standards ensure:
- Consistency across different AI agent implementations
- Maintainability for solo developer
- Alignment with architectural specifications
- Predictable code structure and behavior

**Critical:** Every phase implementation MUST adhere to these standards. No exceptions without updating this document first.

---

## 1. Project Structure Convention

### Backend (FastAPI) Structure

```
backend/
├── app/
│   ├── __init__.py
│   ├── main.py                      # FastAPI app instance, startup/shutdown
│   ├── config.py                    # Environment config (pydantic BaseSettings)
│   ├── dependencies.py              # FastAPI dependency injection
│   │
│   ├── api/                         # API routes (versioned)
│   │   ├── __init__.py
│   │   └── v1/
│   │       ├── __init__.py
│   │       ├── stops.py             # /api/v1/stops/*
│   │       ├── routes.py            # /api/v1/routes/*
│   │       ├── trips.py             # /api/v1/trips/*
│   │       ├── alerts.py            # /api/v1/alerts/*
│   │       ├── favorites.py         # /api/v1/favorites/*
│   │       └── gtfs.py              # /api/v1/gtfs/*
│   │
│   ├── models/                      # Pydantic models (request/response)
│   │   ├── __init__.py
│   │   ├── stop.py
│   │   ├── route.py
│   │   ├── trip.py
│   │   ├── alert.py
│   │   ├── favorite.py
│   │   └── common.py                # Shared models (Pagination, ErrorResponse)
│   │
│   ├── services/                    # Business logic layer
│   │   ├── __init__.py
│   │   ├── gtfs_service.py          # GTFS data queries
│   │   ├── realtime_service.py      # GTFS-RT cache access
│   │   ├── trip_planner_service.py  # Routing logic
│   │   ├── alert_service.py         # Alert matching
│   │   └── nsw_api_client.py        # NSW Transport API wrapper
│   │
│   ├── db/                          # Database access layer
│   │   ├── __init__.py
│   │   ├── supabase_client.py       # Singleton Supabase client
│   │   ├── redis_client.py          # Singleton Redis client
│   │   └── queries.py               # Reusable SQL queries
│   │
│   ├── tasks/                       # Celery tasks
│   │   ├── __init__.py
│   │   ├── celery_app.py            # Celery instance config
│   │   ├── gtfs_static_sync.py      # Daily GTFS sync task
│   │   ├── gtfs_rt_poller.py        # Real-time poller (30s)
│   │   ├── alert_matcher.py         # Alert matching task (2-5min)
│   │   └── apns_worker.py           # Push notification sender
│   │
│   ├── utils/                       # Shared utilities
│   │   ├── __init__.py
│   │   ├── logging.py               # Structured logging setup
│   │   ├── rate_limiter.py          # Token bucket (Redis Lua)
│   │   └── date_utils.py            # Timezone handling (Sydney)
│   │
│   └── schemas/                     # Database schemas (migration scripts)
│       ├── __init__.py
│       └── migrations/
│           ├── 001_initial_schema.sql
│           ├── 002_add_favorites.sql
│           └── ...
│
├── tests/                           # Tests (future phases)
│   ├── unit/
│   └── integration/
│
├── .env.example                     # Example environment variables
├── requirements.txt                 # Python dependencies
└── README.md                        # Setup instructions
```

**Rules:**
- API routes: One file per resource (stops.py handles all /stops/* endpoints)
- Services: Business logic only, no direct DB access (use db/ layer)
- Models: Pydantic for validation, match API contracts from INTEGRATION_CONTRACTS.md
- Tasks: One file per background job type

---

### iOS (SwiftUI) Structure

```
SydneyTransit/
├── SydneyTransitApp.swift           # App entry point
├── Config.plist                     # Environment config (dev/prod)
│
├── Core/                            # Core utilities
│   ├── Network/
│   │   ├── APIClient.swift          # Base HTTP client (async/await)
│   │   ├── APIEndpoint.swift        # Endpoint definitions
│   │   └── APIError.swift           # Error types
│   ├── Database/
│   │   ├── DatabaseManager.swift    # GRDB setup
│   │   ├── GTFSDatabase.swift       # GTFS SQLite queries
│   │   └── Migrations.swift         # GRDB migrations
│   ├── Auth/
│   │   └── SupabaseAuthManager.swift
│   └── Utilities/
│       ├── Logger.swift             # swift-log wrapper
│       ├── DateFormatter+Extensions.swift
│       └── Constants.swift
│
├── Data/                            # Data layer
│   ├── Models/                      # Domain models
│   │   ├── Stop.swift
│   │   ├── Route.swift
│   │   ├── Trip.swift
│   │   ├── Alert.swift
│   │   └── Favorite.swift
│   ├── Repositories/                # Repository pattern
│   │   ├── StopRepository.swift     # Protocol + impl (network + DB)
│   │   ├── RouteRepository.swift
│   │   ├── TripRepository.swift
│   │   ├── AlertRepository.swift
│   │   └── FavoriteRepository.swift
│   └── DTOs/                        # API response models (Codable)
│       ├── StopDTO.swift
│       └── ...
│
├── Features/                        # Feature modules (MVVM + Coordinator)
│   ├── Home/
│   │   ├── HomeCoordinator.swift
│   │   ├── HomeView.swift
│   │   ├── HomeViewModel.swift
│   │   └── Components/
│   │       ├── FavoriteStopCard.swift
│   │       └── NearbyStopsSection.swift
│   ├── Search/
│   │   ├── SearchCoordinator.swift
│   │   ├── SearchView.swift
│   │   ├── SearchViewModel.swift
│   │   └── Components/
│   │       └── SearchResultRow.swift
│   ├── Departures/
│   │   ├── DeparturesCoordinator.swift
│   │   ├── DeparturesView.swift
│   │   └── DeparturesViewModel.swift
│   ├── TripPlanner/
│   │   └── ...
│   ├── Favorites/
│   │   └── ...
│   ├── Alerts/
│   │   └── ...
│   └── Settings/
│       └── ...
│
├── UI/                              # Shared UI components
│   ├── Components/
│   │   ├── LoadingView.swift
│   │   ├── ErrorView.swift
│   │   ├── EmptyStateView.swift
│   │   └── ModeIcon.swift           # Transit mode icons
│   ├── Styles/
│   │   ├── Colors.swift             # Color palette
│   │   ├── Typography.swift         # Text styles
│   │   └── Spacing.swift            # Layout constants
│   └── Modifiers/
│       └── CardModifier.swift
│
└── Resources/
    ├── Assets.xcassets              # Images, icons
    ├── Localizable.strings          # (Future: i18n)
    └── gtfs.db                      # Bundled GTFS SQLite (generated)
```

**Rules:**
- Features: One folder per feature, MVVM + Coordinator pattern
- Repositories: Always protocol-based (for testability)
- ViewModels: @MainActor, @Published properties for UI state
- Views: No business logic, delegate to ViewModel
- Coordinators: Handle navigation, own child coordinators

---

## 2. Database Access Patterns

### Supabase (Backend)

**Singleton Client:**
```python
# db/supabase_client.py
from supabase import create_client, Client
from app.config import settings

_supabase_client: Client | None = None

def get_supabase() -> Client:
    """Singleton Supabase client. Call from FastAPI Depends()."""
    global _supabase_client
    if _supabase_client is None:
        _supabase_client = create_client(
            settings.SUPABASE_URL,
            settings.SUPABASE_SERVICE_KEY  # Use service key for backend
        )
    return _supabase_client
```

**Usage in API Routes:**
```python
# api/v1/stops.py
from fastapi import APIRouter, Depends
from app.db.supabase_client import get_supabase

router = APIRouter()

@router.get("/stops/{stop_id}")
async def get_stop(stop_id: str, supabase: Client = Depends(get_supabase)):
    result = supabase.table('stops').select('*').eq('id', stop_id).execute()
    # Always check result.data before returning
    if not result.data:
        raise HTTPException(status_code=404, detail="Stop not found")
    return result.data[0]
```

**Query Patterns:**
- **Always use Supabase client methods** (`.select()`, `.insert()`, `.update()`) unless PostGIS required
- **Avoid N+1:** Use `.select('stops(*), routes(*)')` for joins
- **Pagination:** `.range(offset, offset + limit - 1)`
- **Filtering:** `.eq()`, `.in_()`, `.gte()`, `.lte()` (chainable)
- **RLS enforcement:** User-scoped queries (favorites, alerts) automatically filtered by RLS policies

**PostGIS Queries (Raw SQL):**
```python
# For spatial queries (nearby stops), use raw SQL via supabase.rpc()
query = """
SELECT * FROM stops
WHERE ST_DWithin(
    location::geography,
    ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography,
    $3
)
ORDER BY ST_Distance(location::geography, ST_SetSRID(ST_MakePoint($1, $2), 4326)::geography)
LIMIT $4;
"""
result = supabase.rpc('exec_sql', {'query': query, 'params': [lng, lat, radius_m, limit]})
```

---

### Redis (Backend Caching)

**Singleton Client:**
```python
# db/redis_client.py
import redis.asyncio as redis
from app.config import settings

_redis_client: redis.Redis | None = None

async def get_redis() -> redis.Redis:
    """Singleton Redis client. Call from FastAPI startup or Depends()."""
    global _redis_client
    if _redis_client is None:
        _redis_client = await redis.from_url(
            settings.REDIS_URL,
            encoding="utf-8",
            decode_responses=True  # Auto-decode bytes to str
        )
    return _redis_client
```

**Caching Patterns (from DATA_ARCHITECTURE.md):**
- **GTFS-RT blobs:** `gtfs_rt:train:blob`, `gtfs_rt:bus:blob` (JSON strings)
- **TTL enforcement:** Always set TTL (30-120s for RT data)
- **Get-or-fetch:** Try cache first, fetch from NSW API on miss, update cache
- **Atomic operations:** Use Redis pipelines for multi-key updates

```python
# Example: Cache GTFS-RT train data
await redis_client.setex(
    'gtfs_rt:train:blob',
    60,  # TTL 60s
    json.dumps(gtfs_rt_data)
)
```

---

### GRDB (iOS SQLite)

**Database Manager:**
```swift
// Core/Database/DatabaseManager.swift
import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()
    private var dbQueue: DatabaseQueue!

    private init() {
        let path = Bundle.main.path(forResource: "gtfs", ofType: "db")!
        dbQueue = try! DatabaseQueue(path: path)
    }

    func read<T>(_ block: (Database) throws -> T) throws -> T {
        return try dbQueue.read(block)
    }
}
```

**Repository Pattern:**
```swift
// Data/Repositories/StopRepository.swift
protocol StopRepository {
    func fetchStop(id: String) async throws -> Stop
    func searchStops(query: String) async throws -> [Stop]
}

class StopRepositoryImpl: StopRepository {
    private let dbManager = DatabaseManager.shared
    private let apiClient: APIClient

    func fetchStop(id: String) async throws -> Stop {
        // Try local DB first (offline support)
        if let stop = try dbManager.read({ db in
            try Stop.fetchOne(db, key: id)
        }) {
            return stop
        }
        // Fallback to API if not found locally
        return try await apiClient.fetchStop(id: id)
    }
}
```

**Query Patterns:**
- **Read-only:** GTFS data is immutable (bundled with app)
- **FTS5 search:** Use full-text search for stop names (see DATA_ARCHITECTURE.md Section 6)
- **Spatial queries:** Use R*Tree index for nearby stops

---

## 3. API Design Standards

### Request/Response Envelope (from INTEGRATION_CONTRACTS.md)

**Success Response:**
```json
{
  "data": { ... },           // Single object or array
  "meta": {                  // Optional metadata
    "pagination": {
      "offset": 0,
      "limit": 20,
      "total": 150
    }
  }
}
```

**Error Response:**
```json
{
  "error": {
    "code": "STOP_NOT_FOUND",
    "message": "Stop with ID '12345' does not exist",
    "details": {}            // Optional extra context
  }
}
```

**FastAPI Implementation:**
```python
# models/common.py
from pydantic import BaseModel
from typing import Generic, TypeVar, Optional

T = TypeVar('T')

class SuccessResponse(BaseModel, Generic[T]):
    data: T
    meta: Optional[dict] = None

class ErrorDetail(BaseModel):
    code: str
    message: str
    details: Optional[dict] = None

class ErrorResponse(BaseModel):
    error: ErrorDetail

# Usage in routes:
@router.get("/stops/{stop_id}", response_model=SuccessResponse[Stop])
async def get_stop(stop_id: str):
    stop = fetch_stop(stop_id)
    return SuccessResponse(data=stop)
```

---

### Pagination Pattern

**Query Parameters:**
- `offset` (default: 0)
- `limit` (default: 20, max: 100)

**Example:**
```python
@router.get("/stops", response_model=SuccessResponse[list[Stop]])
async def list_stops(
    offset: int = 0,
    limit: int = 20,
    supabase: Client = Depends(get_supabase)
):
    limit = min(limit, 100)  # Enforce max
    result = supabase.table('stops').select('*').range(offset, offset + limit - 1).execute()
    total = supabase.table('stops').select('id', count='exact').execute().count

    return SuccessResponse(
        data=result.data,
        meta={'pagination': {'offset': offset, 'limit': limit, 'total': total}}
    )
```

---

### Error Handling Convention

**HTTP Status Codes:**
- 200: Success
- 400: Bad request (validation error)
- 401: Unauthorized (missing/invalid auth token)
- 403: Forbidden (authenticated but not authorized)
- 404: Not found
- 429: Rate limited
- 500: Internal server error

**FastAPI Exception Handling:**
```python
# main.py
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

app = FastAPI()

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content=ErrorResponse(
            error=ErrorDetail(
                code=exc.detail.get('code', 'UNKNOWN_ERROR'),
                message=exc.detail.get('message', str(exc.detail)),
                details=exc.detail.get('details')
            )
        ).dict()
    )
```

**iOS Error Handling:**
```swift
// Core/Network/APIError.swift
enum APIError: Error {
    case unauthorized
    case notFound
    case rateLimited(retryAfter: Int)
    case serverError(message: String)
    case networkError(Error)
}

// In APIClient:
func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
    // Handle 429 with backoff
    if response.statusCode == 429 {
        let retryAfter = response.value(forHTTPHeaderField: "Retry-After") ?? "60"
        throw APIError.rateLimited(retryAfter: Int(retryAfter) ?? 60)
    }
    // ... other status codes
}
```

---

### Authentication Header Format

**Backend (FastAPI):**
```python
# dependencies.py
from fastapi import Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    supabase: Client = Depends(get_supabase)
) -> dict:
    """Verify Supabase JWT token, return user data."""
    token = credentials.credentials
    try:
        user = supabase.auth.get_user(token)
        return user
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

# Usage in protected routes:
@router.post("/favorites")
async def create_favorite(
    favorite: FavoriteCreate,
    user: dict = Depends(get_current_user)
):
    # user['id'] is available
    pass
```

**iOS (APIClient):**
```swift
// Core/Network/APIClient.swift
class APIClient {
    private var authToken: String?

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        var request = URLRequest(url: endpoint.url)
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // ... rest of request
    }
}
```

---

## 4. Logging Standards

### Structured Logging (JSON format)

**Backend (Python structlog):**
```python
# utils/logging.py
import structlog
import logging

def setup_logging():
    structlog.configure(
        processors=[
            structlog.stdlib.add_log_level,
            structlog.stdlib.add_logger_name,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

# Usage in code:
import structlog
logger = structlog.get_logger()

logger.info("stop_fetched", stop_id="12345", user_id="user_abc", duration_ms=120)
logger.error("api_error", error="NSW API timeout", endpoint="/gtfs-rt/trip-updates")
```

**Required Fields:**
- `timestamp` (ISO 8601)
- `level` (DEBUG/INFO/WARN/ERROR)
- `logger` (module name)
- `event` (action description: `stop_fetched`, `alert_matched`)
- `request_id` (trace requests across services, use `X-Request-ID` header)
- `user_id` (if authenticated, NEVER log email/name)

**Never Log:**
- PII (email, name, phone)
- Auth tokens (JWT, API keys)
- Full request/response bodies (only IDs/status codes)

---

**iOS (swift-log):**
```swift
// Core/Utilities/Logger.swift
import Logging

extension Logger {
    static let app = Logger(label: "com.sydneytransit.app")
}

// Usage:
Logger.app.info("Stop fetched", metadata: [
    "stop_id": "\(stopId)",
    "duration_ms": "\(duration)"
])

Logger.app.error("API error", metadata: [
    "error": "\(error.localizedDescription)",
    "endpoint": "/stops/\(stopId)"
])
```

---

### Log Levels

- **DEBUG:** Development only (verbose SQL queries, cache hits)
- **INFO:** Normal operations (API calls, task completions, user actions)
- **WARN:** Recoverable errors (stale cache served, NSW API slow response)
- **ERROR:** Failures requiring attention (DB connection lost, task crashed)

**Production:** INFO and above only

---

## 5. Celery Task Patterns (from BACKEND_SPECIFICATION.md)

### Task Naming Convention

**Pattern:** `verb_noun` (lowercase, underscores)

Examples:
- `sync_gtfs_static` (not `GTFSSyncTask`)
- `poll_gtfs_rt`
- `match_alerts`
- `send_push_notification`

---

### Queue Assignment (3 Queues)

**From BACKEND_SPECIFICATION.md Section 4:**
- **critical:** GTFS-RT poller (singleton, time-sensitive)
- **normal:** Alert matcher, APNs worker (parallel)
- **batch:** GTFS static sync (long-running, low priority)

**Task Declaration:**
```python
# tasks/gtfs_rt_poller.py
from app.tasks.celery_app import celery_app

@celery_app.task(
    name='poll_gtfs_rt',
    queue='critical',
    bind=True,
    max_retries=3,
    default_retry_delay=5,  # 5s
    time_limit=15,          # Hard timeout (SIGKILL)
    soft_time_limit=10      # Soft timeout (exception)
)
def poll_gtfs_rt(self):
    try:
        # Fetch NSW GTFS-RT, update Redis
        pass
    except Exception as exc:
        logger.error("poll_gtfs_rt_failed", error=str(exc))
        raise self.retry(exc=exc)
```

---

### Idempotency (Singleton Tasks)

**Redis SETNX Lock Pattern:**
```python
import redis

def poll_gtfs_rt(self):
    lock_key = 'lock:poll_gtfs_rt'
    lock_acquired = redis_client.set(lock_key, '1', nx=True, ex=30)  # 30s expiry

    if not lock_acquired:
        logger.info("poll_gtfs_rt_skipped", reason="already_running")
        return

    try:
        # Do work
        pass
    finally:
        redis_client.delete(lock_key)  # Always release lock
```

**Why:** Prevents overlapping executions (e.g., if task runs longer than schedule interval)

---

### Error Handling & Retries

**Retry Strategy:**
- **Transient errors** (network timeout, 503): Retry with exponential backoff
- **Permanent errors** (404, validation): Don't retry, log and alert
- **Max retries:** 3 (tasks should fail fast, not loop forever)

**Example:**
```python
@celery_app.task(bind=True, max_retries=3)
def fetch_external_data(self):
    try:
        response = requests.get('https://api.example.com/data', timeout=10)
        response.raise_for_status()
    except requests.Timeout as exc:
        # Transient: retry
        raise self.retry(exc=exc, countdown=2 ** self.request.retries)  # Exponential backoff
    except requests.HTTPError as exc:
        if exc.response.status_code == 404:
            # Permanent: don't retry
            logger.error("data_not_found", url=exc.request.url)
            return
        raise self.retry(exc=exc)
```

---

### Timeout Configuration (from BACKEND_SPEC Section 4)

| Task              | Soft Timeout | Hard Timeout | Queue    |
|-------------------|--------------|--------------|----------|
| poll_gtfs_rt      | 10s          | 15s          | critical |
| match_alerts      | 15s          | 20s          | normal   |
| send_apns         | 8s           | 12s          | normal   |
| sync_gtfs_static  | 30m          | 60m          | batch    |

**Why Two Timeouts:**
- **Soft:** Raises `SoftTimeLimitExceeded` exception (task can cleanup)
- **Hard:** Kills task process (no cleanup, use for hung tasks)

---

## 6. iOS Data Flow (MVVM + Repository)

### Architecture Pattern

```
View (SwiftUI)
    ↓ user actions
ViewModel (@MainActor, @Published state)
    ↓ business logic
Repository (protocol)
    ↓ data fetching
    ├─→ Network (APIClient)
    └─→ Database (GRDB)
```

---

### Repository Pattern (Protocol-Based)

**Protocol Definition:**
```swift
// Data/Repositories/StopRepository.swift
protocol StopRepository {
    func fetchStop(id: String) async throws -> Stop
    func searchStops(query: String, limit: Int) async throws -> [Stop]
    func nearbyStops(latitude: Double, longitude: Double, radius: Int) async throws -> [Stop]
}

class StopRepositoryImpl: StopRepository {
    private let apiClient: APIClient
    private let dbManager: DatabaseManager

    init(apiClient: APIClient, dbManager: DatabaseManager) {
        self.apiClient = apiClient
        self.dbManager = dbManager
    }

    func fetchStop(id: String) async throws -> Stop {
        // Try DB first (offline support)
        if let stop = try dbManager.read({ db in
            try Stop.fetchOne(db, key: id)
        }) {
            return stop
        }
        // Fallback to API
        return try await apiClient.request(.getStop(id: id))
    }
}
```

**Why Protocol:** Enables dependency injection, testability (mock repositories in tests)

---

### ViewModel Responsibilities

**Do:**
- Transform repository data into UI state (@Published properties)
- Handle user actions (button taps → repository calls)
- Manage loading/error states
- Format data for display (dates, distances)

**Don't:**
- Direct network calls (use repository)
- Direct database queries (use repository)
- Business logic (routing algorithms, complex validation)
- Navigation (use coordinator)

**Example:**
```swift
// Features/Departures/DeparturesViewModel.swift
@MainActor
class DeparturesViewModel: ObservableObject {
    @Published var departures: [Departure] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let stopRepository: StopRepository
    private let realtimeRepository: RealtimeRepository

    init(stopRepository: StopRepository, realtimeRepository: RealtimeRepository) {
        self.stopRepository = stopRepository
        self.realtimeRepository = realtimeRepository
    }

    func loadDepartures(stopId: String) async {
        isLoading = true
        errorMessage = nil

        do {
            departures = try await realtimeRepository.fetchDepartures(stopId: stopId)
        } catch {
            errorMessage = "Failed to load departures"
            Logger.app.error("Load departures failed", metadata: ["stop_id": "\(stopId)", "error": "\(error)"])
        }

        isLoading = false
    }
}
```

---

### Coordinator Pattern (Navigation)

**Purpose:** Decouple view navigation from views/viewmodels

**Example:**
```swift
// Features/Home/HomeCoordinator.swift
class HomeCoordinator: ObservableObject {
    @Published var path = NavigationPath()

    enum Destination: Hashable {
        case stopDetails(stopId: String)
        case departures(stopId: String)
        case search
    }

    func navigate(to destination: Destination) {
        path.append(destination)
    }

    func pop() {
        path.removeLast()
    }

    @ViewBuilder
    func view(for destination: Destination) -> some View {
        switch destination {
        case .stopDetails(let stopId):
            StopDetailsView(stopId: stopId, coordinator: self)
        case .departures(let stopId):
            DeparturesView(stopId: stopId, coordinator: self)
        case .search:
            SearchView(coordinator: self)
        }
    }
}

// Usage in View:
struct HomeView: View {
    @StateObject var coordinator = HomeCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            // Home content
            Button("View Stop") {
                coordinator.navigate(to: .stopDetails(stopId: "12345"))
            }
        }
        .navigationDestination(for: HomeCoordinator.Destination.self) { destination in
            coordinator.view(for: destination)
        }
    }
}
```

---

## 7. Configuration Management

### Backend Environment Variables

**Required Variables (.env file):**
```bash
# Supabase
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

# Redis
REDIS_URL=redis://default:password@redis.railway.app:6379

# NSW Transport API
NSW_API_KEY=apikey_xxxxxxxxxxxxxxxx

# Celery
CELERY_BROKER_URL=redis://default:password@redis.railway.app:6379
CELERY_RESULT_BACKEND=  # Leave empty (no result backend)

# APNs (Phase 6)
APNS_KEY_ID=ABCD1234
APNS_TEAM_ID=TEAM1234
APNS_BUNDLE_ID=com.sydneytransit.app
APNS_PRIVATE_KEY_PATH=/etc/secrets/apns_key.p8

# Environment
ENVIRONMENT=development  # or 'production'
LOG_LEVEL=INFO           # DEBUG in dev, INFO in prod
```

**Usage (Pydantic Settings):**
```python
# config.py
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    SUPABASE_URL: str
    SUPABASE_SERVICE_KEY: str
    NSW_API_KEY: str
    REDIS_URL: str
    ENVIRONMENT: str = 'development'
    LOG_LEVEL: str = 'INFO'

    class Config:
        env_file = '.env'
        case_sensitive = True

settings = Settings()
```

**NEVER:**
- Commit `.env` to git (use `.env.example` with dummy values)
- Hardcode secrets in code
- Log environment variables

---

### iOS Configuration (Config.plist)

**Structure:**
```xml
<!-- Config.plist -->
<plist version="1.0">
<dict>
    <key>API_BASE_URL</key>
    <string>https://api.sydneytransit.com</string>  <!-- Dev: http://localhost:8000 -->

    <key>SUPABASE_URL</key>
    <string>https://xxxxx.supabase.co</string>

    <key>SUPABASE_ANON_KEY</key>
    <string>eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...</string>

    <key>LOG_LEVEL</key>
    <string>debug</string>  <!-- Prod: info -->
</dict>
</plist>
```

**Usage:**
```swift
// Core/Utilities/Constants.swift
enum Config {
    static let apiBaseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String else {
            fatalError("API_BASE_URL not found in Config.plist")
        }
        return url
    }()

    static let supabaseURL: String = {
        guard let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else {
            fatalError("SUPABASE_URL not found in Config.plist")
        }
        return url
    }()
}
```

**Dev vs Prod:** Use Xcode schemes/targets to swap Config.plist (Config-Dev.plist, Config-Prod.plist)

---

## 8. Testing Conventions (Manual for MVP)

### Per-Phase Acceptance Criteria

**Format:**
```markdown
## Acceptance Criteria

**Backend:**
- [ ] API endpoint `/api/v1/stops/{id}` returns 200 with stop data
- [ ] API returns 404 for non-existent stop
- [ ] Response matches INTEGRATION_CONTRACTS.md schema
- [ ] Logs contain `stop_fetched` event with stop_id

**iOS:**
- [ ] Stop details screen displays name, location, routes
- [ ] Loading spinner shown while fetching
- [ ] Error message displayed on network failure
- [ ] Offline mode: data loaded from local GRDB

**Manual Testing Steps:**
1. Start backend: `uvicorn app.main:app --reload`
2. Test API: `curl http://localhost:8000/api/v1/stops/200060`
3. Open iOS simulator
4. Navigate to stop "Circular Quay"
5. Verify departures refresh every 30s
```

---

### Verification Commands (cURL Examples)

**Test API Endpoints:**
```bash
# Get stop
curl -X GET "http://localhost:8000/api/v1/stops/200060" -H "accept: application/json"

# Search stops
curl -X GET "http://localhost:8000/api/v1/stops?query=circular&limit=10"

# Create favorite (authenticated)
curl -X POST "http://localhost:8000/api/v1/favorites" \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"stop_id": "200060", "nickname": "Home"}'
```

**Test Celery Tasks:**
```bash
# Trigger GTFS-RT poll manually
celery -A app.tasks.celery_app call app.tasks.gtfs_rt_poller.poll_gtfs_rt

# Check Redis cache
redis-cli GET gtfs_rt:train:blob
```

---

## 9. Git Workflow

### Branch Naming

**Pattern:** `phase-N-feature-name`

Examples:
- `phase-0-project-setup`
- `phase-1-gtfs-parser`
- `phase-2-realtime-poller`
- `phase-3-auth-flow`

**Main Branch:** `main` (protected, all phases merge here)

---

### Commit Message Format

**Pattern:** `<type>: <description>`

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring (no behavior change)
- `docs`: Documentation changes
- `test`: Add/update tests
- `chore`: Tooling, dependencies

**Examples:**
- `feat: add stop search API endpoint`
- `fix: handle 404 when stop not found`
- `refactor: extract NSW API client into service`
- `docs: update API contracts for favorites`

**When to Commit:**
- Per feature (not per file)
- Before moving to next task
- End of day (checkpoint)

---

### Pull Request / Merge Strategy

**Per Phase:**
1. Work in `phase-N-*` branch
2. Commit frequently (atomic commits)
3. At phase end: merge to `main` (squash or merge commit)
4. Tag release: `git tag phase-N-complete`

---

## 10. Error Handling Patterns

### Backend (FastAPI)

**Try-Except with Structured Logging:**
```python
@router.get("/stops/{stop_id}")
async def get_stop(stop_id: str):
    try:
        stop = fetch_stop_from_db(stop_id)
        logger.info("stop_fetched", stop_id=stop_id)
        return SuccessResponse(data=stop)
    except StopNotFoundError:
        logger.warn("stop_not_found", stop_id=stop_id)
        raise HTTPException(status_code=404, detail={"code": "STOP_NOT_FOUND", "message": f"Stop {stop_id} not found"})
    except DatabaseError as exc:
        logger.error("database_error", stop_id=stop_id, error=str(exc))
        raise HTTPException(status_code=500, detail={"code": "DATABASE_ERROR", "message": "Internal error"})
```

**Return 4xx/5xx:**
- 4xx: Client error (bad request, not found, unauthorized)
- 5xx: Server error (DB down, external API timeout)

---

### iOS (Result Type)

**APIClient Pattern:**
```swift
// Core/Network/APIClient.swift
func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
    do {
        let (data, response) = try await URLSession.shared.data(for: endpoint.request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(NSError(domain: "Invalid response", code: -1))
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After") ?? "60"
            throw APIError.rateLimited(retryAfter: Int(retryAfter) ?? 60)
        case 500...599:
            throw APIError.serverError(message: "Server error")
        default:
            throw APIError.networkError(NSError(domain: "HTTP \(httpResponse.statusCode)", code: httpResponse.statusCode))
        }
    } catch let error as APIError {
        throw error
    } catch {
        throw APIError.networkError(error)
    }
}
```

**User-Facing Error Messages:**
```swift
// ViewModel error handling
func loadDepartures() async {
    do {
        departures = try await repository.fetchDepartures(stopId: stopId)
    } catch APIError.unauthorized {
        errorMessage = "Please sign in to view departures"
    } catch APIError.notFound {
        errorMessage = "Stop not found"
    } catch APIError.rateLimited(let retryAfter) {
        errorMessage = "Too many requests. Try again in \(retryAfter)s"
    } catch APIError.networkError {
        errorMessage = "Network error. Check your connection."
    } catch {
        errorMessage = "An error occurred. Please try again."
    }
}
```

---

### Graceful Degradation (from BACKEND_SPEC Section 6)

**Stale Cache When API Fails:**
```python
async def get_departures(stop_id: str):
    try:
        # Try fresh data from NSW API
        data = await nsw_api_client.fetch_departures(stop_id)
        await redis_client.setex(f'departures:{stop_id}', 120, json.dumps(data))
        return data
    except NSWAPIError:
        # Fallback to stale cache
        stale_data = await redis_client.get(f'departures:{stop_id}')
        if stale_data:
            logger.warn("serving_stale_cache", stop_id=stop_id)
            return json.loads(stale_data)
        raise HTTPException(status_code=503, detail="Service temporarily unavailable")
```

**iOS Offline Mode:**
```swift
func fetchDepartures(stopId: String) async throws -> [Departure] {
    do {
        // Try API first
        return try await apiClient.request(.getDepartures(stopId: stopId))
    } catch APIError.networkError {
        // Fallback to last cached data (if available)
        if let cached = try? dbManager.read({ db in
            try Departure.fetchAll(db, sql: "SELECT * FROM cached_departures WHERE stop_id = ?", arguments: [stopId])
        }), !cached.isEmpty {
            Logger.app.info("Serving cached departures (offline)", metadata: ["stop_id": "\(stopId)"])
            return cached
        }
        throw APIError.networkError(NSError(domain: "No cached data available", code: -1))
    }
}
```

---

## 11. Additional Standards

### Rate Limiting (Client-Side Backoff)

**iOS Backoff Strategy (429 Handling):**
```swift
func request<T: Decodable>(_ endpoint: APIEndpoint, retryCount: Int = 0) async throws -> T {
    do {
        return try await _request(endpoint)
    } catch APIError.rateLimited(let retryAfter) {
        if retryCount < 3 {
            Logger.app.warn("Rate limited, retrying", metadata: ["retry_after": "\(retryAfter)", "attempt": "\(retryCount + 1)"])
            try await Task.sleep(nanoseconds: UInt64(retryAfter) * 1_000_000_000)  // Sleep retryAfter seconds
            return try await request(endpoint, retryCount: retryCount + 1)
        }
        throw APIError.rateLimited(retryAfter: retryAfter)
    }
}
```

---

### Database Migrations (Supabase Schema Changes)

**Migration Files (SQL):**
```sql
-- schemas/migrations/001_initial_schema.sql
-- Generated by Phase 1

CREATE TABLE IF NOT EXISTS stops (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    location GEOGRAPHY(POINT, 4326),
    ...
);

CREATE INDEX idx_stops_location ON stops USING GIST(location);
```

**Versioning:**
- One migration file per phase
- Sequential numbering (001, 002, 003)
- Never modify old migrations (create new migration to alter)
- Run migrations manually via Supabase dashboard or SQL editor

---

### Dependency Management

**Backend (requirements.txt):**
```
fastapi==0.104.1
uvicorn[standard]==0.24.0
celery[redis]==5.3.4
redis==5.0.1
supabase==2.0.3
structlog==23.2.0
pydantic-settings==2.1.0
```

**iOS (Swift Package Manager):**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.22.0"),
    .package(url: "https://github.com/supabase/supabase-swift.git", from: "2.0.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
    .package(url: "https://github.com/malcommac/SwiftDate.git", from: "7.0.0")
]
```

**Pinning Versions:**
- Backend: Use exact versions in `requirements.txt` (avoid `>=`)
- iOS: Use `from:` for minor updates, exact versions for major dependencies

---

## 12. Privacy & Security

### Data Collection (Minimal)

**Backend:**
- Store only user_id (UUID from Supabase Auth)
- Favorites: stop_id + nickname (no location tracking)
- Alerts: stop_id + route_id (no trip history)
- Device tokens: hashed, not linked to identifiable info

**iOS:**
- No analytics/tracking libraries (Phase 0-7)
- Location: Only when user explicitly searches nearby stops (prompt permission)
- No PII collected

---

### API Security

**Backend:**
- Rate limiting (SlowAPI + Cloudflare WAF)
- CORS: Whitelist iOS app origin only
- SQL injection: Use parameterized queries (Supabase client handles this)
- Auth: Supabase JWT validation on all protected endpoints

**iOS:**
- Certificate pinning (optional, Phase 7)
- Keychain storage for auth tokens (never UserDefaults)
- No hardcoded secrets (use Config.plist)

---

## Summary Checklist

Before starting each phase, verify:

- [ ] Project structure matches conventions (Section 1)
- [ ] Database clients are singletons (Section 2)
- [ ] API follows envelope format (Section 3)
- [ ] Structured logging configured (Section 4)
- [ ] Celery tasks follow naming/queue conventions (Section 5)
- [ ] iOS uses MVVM + Repository + Coordinator (Section 6)
- [ ] Environment variables configured (Section 7)
- [ ] Manual testing checklist prepared (Section 8)
- [ ] Git branch created (`phase-N-*`) (Section 9)
- [ ] Error handling patterns implemented (Section 10)

**This document is living:** Update when patterns evolve across phases.

---

**End of DEVELOPMENT_STANDARDS.md**
