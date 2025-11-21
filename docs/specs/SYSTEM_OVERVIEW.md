# System Overview - Sydney Transit App
**Project:** Sydney Transit MVP (iOS + FastAPI Backend)
**Version:** 1.0 (Architecture Specification)
**Date:** 2025-11-12
**Status:** Foundation Document - No Implementation Yet

---

## 1. Executive Summary

### What We're Building
Best-in-class transit app for Sydney - combining **TripView's reliability** + **Transit's features** + **modern iOS polish**.

**Core Value Proposition:**
- Real-time departures with countdown timers (all Sydney modes)
- Intelligent trip planning (multi-modal, door-to-door)
- Proactive service alerts (push notifications)
- Generous free tier (learn from competitors' paywall mistakes)
- Ultra-lightweight (<50MB app size vs competitors' 100-200MB bloat)

### Target Users
**Primary:** Sydney commuters (6.4M regular transit users in greater Sydney)
- Daily commuters (fixed routes: home ↔ work)
- Occasional travelers (weekend/event trips)
- Visitors (tourists, temporary residents)

**No demographic segmentation:** Everyone gets the same best-in-class app.

### Market Context
**Proven demand:** TripView has 500K-1M users, $2.5M+ revenue despite dated UI
**Opportunity:** Incumbent stagnant (TripView hasn't innovated in years)
**Timing:** Perfect - on-device AI, government data free, modern iOS capabilities

---

## 2. Strategic Positioning

### Phase 1 Goal (This Architecture)
**Best transit app in Sydney** - nail core functionality before AI/voice features

**Immediate Differentiators:**
1. TripView reliability + Transit features + modern UX
2. Generous free tier (don't artificially limit core features)
3. Sydney perfection (nail one city completely)
4. iOS-focused polish (better than cross-platform competitors)
5. Ultra-lightweight architecture (<50MB initial download)
6. Modular design (future-ready for AI layer + city expansion)

**vs Competitors:**
- **vs NextThere:** More comprehensive features, same simplicity
- **vs TripView:** Modern UX, same reliability, better trip planning
- **vs Transit:** iOS-focused polish, more generous free tier, simpler

### Future Vision (Post-Phase 1)
- **Phase 2:** Multi-city expansion (Melbourne, Brisbane)
- **Phase 3+:** AI/voice layer (proactive autopilot mode, multilingual accessibility)
- **2026:** Web dashboard (government/agency analytics, not user-facing transit)

---

## 3. Core Constraints & Assumptions

### Non-Negotiable Constraints

#### Technical
- **Platform:** iOS 16+ only (Swift/SwiftUI) - no Android, no web app
- **App Size:** <50MB initial download (critical competitive advantage)
- **Geographic:** Sydney/NSW only for Phase 1
- **Data Source:** NSW Transport Open Data Hub only (no other APIs)

#### Resource
- **Team:** Solo developer (no DevOps, no 24/7 monitoring)
- **Budget:** $25/month maximum during MVP (0-1K users)
- **Timeline:** 14-18 weeks to Phase 1 launch
- **Users:** 0 initially → 1K (6 months) → 10K (12 months target)

#### Data
- **NSW API Rate Limits:** 5 requests/second, 60K calls/day (generous, must stay under)
- **GTFS Static:** 227MB ZIP file (daily updates)
- **GTFS-RT:** Updates every 10-15 seconds (real-time feeds)

### Key Assumptions
1. **NSW API Availability:** Assumes 99%+ uptime (historical data supports this)
2. **Internet Connectivity:** Users have internet most of the time (offline optional, P1 feature)
3. **Supabase Reliability:** Free tier sufficient for MVP (500MB DB, 50K MAU, 1GB storage)
4. **Free Tier Longevity:** Supabase, Railway, CloudFlare free tiers remain available
5. **Apple Ecosystem:** Users comfortable with Apple Sign-In (primary auth method)

### Risk Mitigation
- **NSW API Outages:** Graceful degradation to cached/scheduled data
- **Free Tier Exhaustion:** Monitoring alerts at 80% thresholds
- **Budget Overrun:** Cost alerts, task timeouts, memory limits, rate limiters
- **Solo Developer Scaling:** Self-healing systems, one-click deploys, built-in observability

---

## 4. Phase 1 Feature Scope

### P0 Features (Must Have for Launch)

#### 1. Real-Time Departures
- Live countdown timers for all Sydney modes (Trains, Metro, Buses, Ferries, Light Rail)
- Next 3-5 departures per stop/platform
- Real-time delays/cancellations (NSW GTFS-RT, 10-15s updates)
- Accessibility info (wheelchair accessible vehicles)
- Clean list view with mode color-coding

#### 2. Stop/Station Search & Nearby
- Search by stop name/number (instant results)
- "Nearby" view with closest stops (geolocation)
- Map view with stop pins (MapKit native)
- CoreLocation for user position

#### 3. Service Alerts
- Real-time disruption notifications (system-wide alerts)
- Mode-specific filtering (show only trains/buses/etc.)
- Push notifications for favorites
- Alert banner + dedicated alerts tab
- Affected lines highlighted

#### 4. Trip Planning
- Multi-modal journey planning (door-to-door)
- Enter origin + destination (address, stop, landmark)
- Multiple route options (fastest, least walking, accessible)
- Walk + transit combinations
- Real-time-aware (accounts for delays)
- **Data Source:** NSW Trip Planner API (60K free calls/day)

#### 5. Favorites & Quick Access
- Save frequently used stops/routes (unlimited, unlike competitors)
- Home screen shows favorited stops with next departures
- Swipe to reorder
- Sync via Supabase (cross-device, future-proof for web dashboard)

#### 6. Maps & Live Tracking
- Live vehicle positions (buses, trains, ferries on map)
- Route shapes visualization
- Stop locations with pins
- **Native:** MapKit for base maps

#### 7. Push Notifications
- Service disruptions affecting favorites
- Departure reminders (optional, user-configured)
- Time-sensitive notifications (iOS priority delivery)
- **Native:** APNs (Apple Push Notification service)

### P1 Features (Post-Launch, 6-8 Weeks After)
- Home screen widgets (small/medium/large)
- Lock screen widgets (iOS 16+)
- Live Activities (trip tracking with countdown, iOS 16.1+)
- Dynamic Island integration (iPhone 14 Pro+)
- Saved Trips (one-tap to view common journeys)
- GO Mode basics (step-by-step guidance during journey)
- Weather integration (WeatherKit, rain warnings for walking)
- Offline schedules (optional ~300MB download via Background Assets)

### Explicitly Out of Scope (Phase 1)
- ❌ Android app
- ❌ Web app (except static marketing site)
- ❌ Melbourne/Brisbane (multi-city support architecture, but NSW data only)
- ❌ AI/voice features (Phase 3+)
- ❌ Social features (sharing trips, rate-my-ride)
- ❌ Payment integration (Opal card top-up - future consideration)
- ❌ Multi-language support (English only, architecture ready for i18n)

---

## 5. Technology Stack (Ratified Decisions)

### iOS Application

**Language & Framework:**
- Swift 5.9+, Xcode 15+
- SwiftUI (iOS 16+ minimum)
- **Pattern:** MVVM + Coordinator + Repository

**Core Libraries (Minimal Dependencies):**
- **GRDB** - SQLite wrapper (local caching, offline data)
- **SwiftDate** - Timezone handling (critical for transit schedules)
- **SwiftProtobuf** - GTFS-RT parsing (binary Protocol Buffer format)
- **Supabase Swift SDK** - Authentication, database sync

**Native Capabilities:**
- MapKit (maps, location)
- WeatherKit (iOS 16+, weather data)
- CloudKit (future option for favorites sync)
- Live Activities (iOS 16.1+, trip tracking)
- WidgetKit (home/lock screen widgets)
- CoreLocation (nearby stops)
- UserNotifications (APNs integration)

**Why SwiftUI/MVVM:**
- SwiftUI: Modern, declarative, native iOS 16+ features
- MVVM: Natural fit for SwiftUI (@Published, ObservableObject)
- Coordinator: Clean navigation separation
- Repository: Data access abstraction (network vs local)

### Backend Services

**API Backend:**
- **FastAPI** (Python 3.11+)
- **Why Python:** Best GTFS ecosystem (`gtfs-realtime-bindings`), Celery for background jobs, future ML capabilities

**Background Workers:**
- **Celery** (Python) - GTFS-RT polling, alert matching, APNs delivery
- **Why Celery:** Battle-tested (2009+), perfect for continuous polling, task prioritization

**Database:**
- **Supabase** (PostgreSQL 14+ with PostGIS)
- **Consolidates 3 services:** Database + Authentication + File Storage
- **Why Supabase:** ACID compliance, geospatial (PostGIS), generous free tier (500MB DB, 50K MAU, 1GB storage), built-in Auth & RLS

**Caching:**
- **Redis** (Railway managed or Upstash serverless)
- **Why Redis:** Industry standard, fast in-memory cache, Celery broker, rate limiting

**Hosting:**
- **Backend:** Railway or Fly.io (decision pending - Oracle consultation)
- **Marketing Site:** Vercel (Next.js static, separate deployment)
- **Why:** Low cost ($0-25/month MVP), simple deploy, auto-scale, migrate to AWS/GCP at 50K+ users

**CDN:**
- **CloudFlare** (free tier)
- **Why:** Unlimited bandwidth, GTFS static file distribution, DDoS protection

### Data Sources

**Primary (NSW Transport Open Data Hub):**
- **GTFS Static:** 227MB ZIP, daily updates (stops, routes, trips, schedules)
- **GTFS-RT Feeds:**
  - Vehicle Positions (10-15s updates)
  - Trip Updates (delays, cancellations)
  - Service Alerts (disruptions)
- **Trip Planner API:** Multi-modal routing (60K free calls/day)

**Rate Limits:**
- 5 requests/second
- 60K requests/day
- **Strategy:** Aggressive caching (Redis), background polling (Celery), batch requests

### Development Tools

**Version Control:** Git + GitHub
**CI/CD:** GitHub Actions (iOS: TestFlight, Backend: Railway auto-deploy)
**Error Tracking:** Sentry (free tier: 5K events/month)
**Analytics:** Plausible (self-hosted) or PostHog (free tier)
**Monitoring:** Railway logs (backend), Xcode Instruments (iOS)
**API Documentation:** FastAPI auto-generated (OpenAPI/Swagger)

---

## 6. High-Level Architecture

### System Context Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         EXTERNAL SYSTEMS                         │
└─────────────────────────────────────────────────────────────────┘
                                  │
        ┌─────────────────────────┼─────────────────────────┐
        │                         │                         │
   ┌────▼────┐            ┌───────▼────────┐        ┌──────▼──────┐
   │   NSW   │            │  Apple APNs    │        │  Supabase   │
   │Transport│            │ (Push Notifs)  │        │   Cloud     │
   │   APIs  │            └────────────────┘        │ (Managed)   │
   └────┬────┘                                      └──────┬──────┘
        │                                                  │
        │ GTFS Static/RT                                  │ Auth/DB/Storage
        │                                                  │
┌───────▼──────────────────────────────────────────────────▼──────┐
│                     BACKEND LAYER (FastAPI)                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    REST API Server                        │   │
│  │  /api/v1/routes, /stops, /departures, /trips, /alerts   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              Background Workers (Celery)                  │   │
│  │  - GTFS-RT Poller (every 30-60s)                         │   │
│  │  - Alert Engine (match alerts → user favorites)          │   │
│  │  - APNs Worker (push notification delivery)              │   │
│  │  - GTFS Static Sync (daily at 3am Sydney time)           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────┐   │
│  │   PostgreSQL    │  │      Redis       │  │   Volumes    │   │
│  │   (Supabase)    │  │   (Cache/Queue)  │  │ (GTFS files) │   │
│  │ - GTFS data     │  │ - RT cache       │  │              │   │
│  │ - User data     │  │ - Rate limiting  │  │              │   │
│  │ - Favorites     │  │ - Celery broker  │  │              │   │
│  └─────────────────┘  └──────────────────┘  └──────────────┘   │
│                                                                  │
│  Hosting: Railway/Fly.io                                        │
└──────────────────────────────┬───────────────────────────────────┘
                               │
                               │ HTTPS REST API
                               │
┌──────────────────────────────▼───────────────────────────────────┐
│                      iOS APPLICATION                              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Views (SwiftUI)                        │   │
│  │  TabView: Home, Search, TripPlanner, Alerts, Profile    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                               │                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │              ViewModels (MVVM Pattern)                    │   │
│  │  Business logic, state management, API coordination      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                               │                                  │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────┐   │
│  │   Repositories  │  │    Services      │  │   Managers   │   │
│  │  (Data access)  │  │  (API clients)   │  │ (Auth, etc.) │   │
│  └─────────────────┘  └──────────────────┘  └──────────────┘   │
│                               │                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │        Local Persistence (GRDB + SQLite)                  │   │
│  │  - Cached GTFS data (~30MB subset)                       │   │
│  │  - Recent searches                                        │   │
│  │  - User favorites (offline access)                        │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Platform: iOS 16+, iPhone only (Phase 1)                      │
└──────────────────────────────────────────────────────────────────┘
                               │
                               │
┌──────────────────────────────▼───────────────────────────────────┐
│                    MARKETING WEBSITE                              │
│  Next.js (Static Site Generation)                               │
│  - Landing page, About, Privacy, Terms                          │
│  - App Store link                                               │
│  Hosting: Vercel (free tier)                                    │
└──────────────────────────────────────────────────────────────────┘
```

### Trust Boundaries

```
┌──────────────────────────────────────────────────────────┐
│ Device (User-Controlled)                                 │
│ - iOS App runs here                                      │
│ - User can inspect network traffic                       │
│ - Keychain protects tokens                              │
└───────────────────────┬──────────────────────────────────┘
                        │ HTTPS (encrypted)
                        │ Trust Boundary #1
┌───────────────────────▼──────────────────────────────────┐
│ Backend (Developer-Controlled)                           │
│ - FastAPI validates all inputs                           │
│ - Rate limiting enforced                                 │
│ - Supabase RLS isolates user data                       │
└───────────────────────┬──────────────────────────────────┘
                        │ API Keys, HTTPS
                        │ Trust Boundary #2
┌───────────────────────▼──────────────────────────────────┐
│ Third-Party Services (External Trust)                    │
│ - NSW Transport APIs (government-operated)               │
│ - Supabase (managed PostgreSQL, vetted provider)        │
│ - Apple APNs (Apple-operated)                           │
└──────────────────────────────────────────────────────────┘
```

**Security Implications:**
- **Device → Backend:** JWT in Authorization header, HTTPS only (ATS enforced)
- **Backend → Supabase:** Connection string in env vars (never in code)
- **Backend → NSW APIs:** API key in header (rate limited, monitored)
- **Backend → APNs:** Token-based JWT auth (rotated annually)

### Data Flow (Critical Paths)

#### Path 1: Real-Time Departures Query
```
User taps Stop
    ↓
iOS: StopDetailView
    ↓
iOS: StopDetailViewModel.loadDepartures()
    ↓
iOS: NetworkService.get("/stops/{id}/departures")
    ↓
Backend: FastAPI GET /api/v1/stops/{id}/departures
    ↓
Backend: Check Redis cache (key: "departures:{stop_id}", TTL: 30s)
    ↓
Cache HIT → Return cached data (fast path, <50ms)
Cache MISS ↓
    ↓
Backend: Query Supabase (GTFS static for scheduled times)
    ↓
Backend: Merge with Redis (GTFS-RT real-time updates from Celery worker)
    ↓
Backend: Return merged response
    ↓
Backend: Cache in Redis (30s TTL)
    ↓
iOS: Decode JSON, update @Published properties
    ↓
SwiftUI: View auto-updates (reactive)
```

#### Path 2: Background GTFS-RT Polling (Celery Worker)
```
Celery Beat: Schedule triggers (every 30-60s)
    ↓
Celery Worker: gtfs_poller.py executes
    ↓
Worker: Fetch NSW GTFS-RT feeds (VehiclePositions, TripUpdates, Alerts)
    ↓
Worker: Parse Protocol Buffer (gtfs-realtime-bindings)
    ↓
Worker: Transform to internal format
    ↓
Worker: Write to Redis (key: "gtfs-rt:{mode}:{entity_id}", TTL: 5min)
    ↓
Worker: Write to Supabase (historical analysis table, optional)
    ↓
Worker: Trigger alert_engine.py (if TripUpdate has delay >5min)
    ↓
alert_engine.py: Match against user favorites (query Supabase)
    ↓
alert_engine.py: Queue APNs notification (Redis queue)
    ↓
apns_worker.py: Send push notification (Apple APNs)
```

#### Path 3: User Login (Apple Sign-In)
```
User taps "Sign in with Apple"
    ↓
iOS: ASAuthorizationController triggers
    ↓
Apple: Returns identityToken (JWT), authorizationCode, email
    ↓
iOS: POST /api/v1/auth/apple {identityToken, authorizationCode}
    ↓
Backend: Validate JWT signature (fetch Apple public keys)
    ↓
Backend: Verify JWT claims (iss, aud, exp)
    ↓
Backend: Extract sub (Apple user ID), email
    ↓
Backend: Upsert user in Supabase (users table)
    ↓
Backend: Create session (Supabase Auth, JWT)
    ↓
Backend: Return {access_token, refresh_token, user}
    ↓
iOS: Store access_token in Keychain (secure)
    ↓
iOS: Store user in AuthenticationManager (@Published)
    ↓
iOS: Navigate to HomeView (authenticated)
```

---

## 7. Module Architecture

### iOS App Structure

```
TransitApp/
├── Application/
│   ├── TransitApp.swift              # App entry point, DI setup
│   ├── AppCoordinator.swift          # Root navigation coordinator
│   └── Config.swift                  # Environment configuration
│
├── Core/
│   ├── DesignSystem/
│   │   ├── Colors.swift              # Brand colors (light/dark)
│   │   ├── Typography.swift          # SF Pro text styles
│   │   ├── Spacing.swift             # 4pt grid system
│   │   └── Components/               # Reusable UI components
│   │       ├── CTAButton.swift
│   │       ├── LoadingView.swift
│   │       └── EmptyStateView.swift
│   │
│   ├── Utilities/
│   │   ├── Extensions/
│   │   │   ├── View+Extensions.swift
│   │   │   ├── Date+Extensions.swift
│   │   │   └── Color+Extensions.swift
│   │   ├── Logging.swift             # Unified logging
│   │   └── FeatureFlags.swift        # Local feature toggles
│   │
│   └── Analytics/
│       └── AnalyticsService.swift    # Posthog/Plausible integration
│
├── Data/
│   ├── API/
│   │   ├── APIClient.swift           # Base HTTP client
│   │   ├── APIEndpoints.swift        # Endpoint definitions
│   │   ├── APIModels.swift           # Request/Response DTOs
│   │   └── SupabaseClient.swift      # Supabase SDK wrapper
│   │
│   ├── Repositories/
│   │   ├── StopRepository.swift      # Stop data access (protocol)
│   │   ├── RouteRepository.swift     # Route data access
│   │   ├── TripRepository.swift      # Trip planning
│   │   └── FavoriteRepository.swift  # User favorites
│   │
│   └── Persistence/
│       ├── GRDBManager.swift         # SQLite database setup
│       ├── Models/                   # GRDB table definitions
│       │   ├── Stop+GRDB.swift
│       │   ├── Route+GRDB.swift
│       │   └── Trip+GRDB.swift
│       └── KeychainManager.swift     # Secure token storage
│
├── Features/
│   ├── Authentication/
│   │   ├── Views/
│   │   │   └── AppleSignInView.swift
│   │   ├── ViewModels/
│   │   │   └── AuthViewModel.swift
│   │   └── AuthenticationManager.swift # @EnvironmentObject
│   │
│   ├── Home/                         # Real-time departures
│   │   ├── Views/
│   │   │   ├── HomeView.swift
│   │   │   └── DepartureCardView.swift
│   │   └── ViewModels/
│   │       └── HomeViewModel.swift
│   │
│   ├── Search/                       # Stop/station search
│   │   ├── Views/
│   │   │   ├── SearchView.swift
│   │   │   ├── NearbyStopsView.swift
│   │   │   └── StopDetailView.swift
│   │   └── ViewModels/
│   │       ├── SearchViewModel.swift
│   │       └── StopDetailViewModel.swift
│   │
│   ├── TripPlanner/
│   │   ├── Views/
│   │   │   ├── TripPlannerView.swift
│   │   │   └── TripResultView.swift
│   │   └── ViewModels/
│   │       └── TripPlannerViewModel.swift
│   │
│   ├── Alerts/
│   │   ├── Views/
│   │   │   └── AlertsView.swift
│   │   └── ViewModels/
│   │       └── AlertsViewModel.swift
│   │
│   └── Profile/
│       ├── Views/
│       │   ├── ProfileView.swift
│       │   ├── FavoritesView.swift
│       │   └── SettingsView.swift
│       └── ViewModels/
│           └── ProfileViewModel.swift
│
├── Navigation/
│   ├── Route.swift                   # Enum-based route definitions
│   ├── Coordinator.swift             # Protocol
│   └── TabCoordinator.swift          # TabView navigation
│
└── Resources/
    ├── Assets.xcassets/              # Images, colors
    ├── Localizable.strings           # English only (Phase 1)
    └── Info.plist
```

### Backend Structure

```
backend/
├── app/
│   ├── main.py                       # FastAPI app entry point
│   ├── config.py                     # Environment config
│   │
│   ├── api/                          # REST endpoints
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   ├── auth.py               # Apple Sign-In, JWT
│   │   │   ├── stops.py              # Stop search, nearby
│   │   │   ├── routes.py             # Route list, details
│   │   │   ├── departures.py         # Real-time departures
│   │   │   ├── trips.py              # Trip planning
│   │   │   ├── alerts.py             # Service alerts
│   │   │   └── favorites.py          # User favorites CRUD
│   │   └── dependencies.py           # FastAPI dependencies
│   │
│   ├── workers/                      # Celery tasks
│   │   ├── __init__.py
│   │   ├── celery_app.py             # Celery configuration
│   │   ├── gtfs_poller.py            # GTFS-RT polling task
│   │   ├── gtfs_static_sync.py       # Daily GTFS import
│   │   ├── alert_engine.py           # Alert matching logic
│   │   └── apns_worker.py            # Push notification delivery
│   │
│   ├── models/                       # Pydantic models
│   │   ├── gtfs.py                   # GTFS entities
│   │   ├── user.py                   # User, session
│   │   ├── alert.py                  # Service alerts
│   │   └── api_responses.py          # Standard responses
│   │
│   ├── schemas/                      # Supabase table schemas
│   │   ├── stops.sql
│   │   ├── routes.sql
│   │   ├── trips.sql
│   │   ├── users.sql
│   │   └── favorites.sql
│   │
│   ├── services/                     # Business logic
│   │   ├── gtfs_service.py           # GTFS data processing
│   │   ├── nsw_api_service.py        # NSW API client
│   │   ├── cache_service.py          # Redis abstractions
│   │   ├── supabase_service.py       # Supabase client
│   │   └── notification_service.py   # APNs logic
│   │
│   └── utils/
│       ├── logging.py                # Structured logging
│       ├── rate_limiter.py           # Redis-based rate limiting
│       └── validators.py             # Input validation
│
├── tests/
│   ├── test_api/
│   ├── test_workers/
│   └── test_services/
│
├── requirements.txt                  # Python dependencies
├── Dockerfile                        # Container image
├── docker-compose.yml                # Local development
└── .env.example                      # Environment template
```

---

## 8. Success Metrics

### Technical Metrics (Phase 1)

**Performance:**
- App launch: Cold <2s, warm <1s
- API response: p50 <100ms, p95 <200ms, p99 <500ms
- Memory: iOS app <150MB typical, <200MB peak
- Battery: <5% drain for 30-minute commute with location tracking
- Real-time data staleness: <60 seconds maximum

**Reliability:**
- Backend uptime: 99.9% (allow 43 minutes downtime/month)
- Crash-free sessions: ≥99.5%
- API error rate: ≤1%
- Push notification delivery: 90%+ within 5 seconds

**Cost (Solo Developer Budget):**
- 0-1K users: <$25/month (MVP phase)
- 1K-10K users: <$150/month
- Target: <$1/user/month at scale

**App Size:**
- Initial download: <50MB (vs TripView 5.44MB, Transit 196MB)
- With optional offline data: <350MB total

### User Experience Metrics (Post-Launch)

**Engagement:**
- Daily active users (DAU)
- 7-day retention: >40% (benchmark: Transit has ~70% 6-month retention)
- 30-day retention: >20%
- Average sessions per day: 2-4 (commute use case)

**Feature Adoption:**
- Favorites usage: >60% of users save at least 1 stop
- Push notifications: >50% opt-in rate
- Trip planner: >30% use within first week

**Satisfaction:**
- App Store rating: 4.5+ stars (target: match TripView's 4.8)
- Crash reports: <10 per day at 1K users
- Support requests: <5% of user base (self-service app)

### Business Metrics (Phase 1)

**Launch Goals (6 months):**
- 1,000-5,000 active users
- 4.5+ App Store rating
- <1% crash rate
- Featured in App Store (Australia transit category)

**Validation Criteria:**
- User retention comparable to TripView (high loyalty)
- Feature usage demonstrates product-market fit
- Organic growth (word-of-mouth, no paid marketing initially)

---

## 9. Development Principles

### Simplicity First (0 Users Initially)
- Start with simplest architecture that could possibly work
- Add complexity only when metrics prove necessity
- Default to boring, proven technology over novel approaches
- Solo developer can understand entire system

### Cost Consciousness
- Maximize free tiers (Supabase, Railway/Fly.io, CloudFlare, Vercel)
- Alert at 80% of resource thresholds
- Optimize before scaling (caching reduces compute by 60-70%)
- Clear scaling triggers (metric-driven, not gut-driven)

### Modularity & Future-Proofing
- Easy city expansion (Melbourne, Brisbane) without refactor
- AI/voice layer can plug in later (Phase 3+)
- Web dashboard shares backend API (2026)
- Data models versioned, migrations planned

### Solo Developer Experience
- Self-healing systems (auto-retry, circuit breakers)
- One-click deploys (Railway/Fly.io auto-deploy from GitHub)
- Built-in observability (can't fix what can't see)
- Clear error messages (for debugging at 3am)
- Documentation as code (architecture specs guide implementation)

### Battle-Tested Over Novel
- FastAPI: Production-proven since 2018
- Celery: Battle-tested since 2009
- Supabase: 100K+ production apps
- Redis: Industry standard
- SwiftUI + MVVM: Standard iOS pattern

---

## 10. Open Questions & Decisions Pending

### ⚠️ ORACLE DECISION NEEDED (Next Steps)

These critical decisions require Oracle consultation (detailed in DATA_ARCHITECTURE.md and BACKEND_SPECIFICATION.md):

1. **GTFS-RT Caching Strategy:** Optimal TTL, prefetching, Redis structure
2. **GTFS Static Pipeline:** 227MB daily updates, minimize app size
3. **Database Schema:** Supabase tables, indexes, cost optimization
4. **Celery Worker Design:** Polling frequency, task priorities, error handling
5. **Background Job Scheduling:** Avoid bill explosion, peak vs off-peak
6. **Rate Limiting Strategy:** Stay within NSW 5 req/s
7. **Push Notification Architecture:** Alert matching, APNs worker design
8. **Cost Optimization:** $25/month at 1K users, scaling budget

### Trade-Offs Acknowledged

**iOS-Only (No Android):**
- ✅ Faster development, better polish, native features
- ❌ Limits addressable market to ~54% (iOS market share Australia)
- **Decision:** Accept trade-off, focus > reach in Phase 1

**Supabase vs Custom PostgreSQL:**
- ✅ Free tier, built-in Auth, RLS, Storage (consolidates 3 services)
- ❌ Vendor lock-in, less control than self-hosted
- **Decision:** Convenience > control for solo developer

**NSW Trip Planner API vs Custom Routing:**
- ✅ 60K free calls/day, maintained by government
- ❌ Dependency on external service, limited customization
- **Decision:** Use API for MVP, build custom routing if API unreliable (Phase 1.5)

**Generous Free Tier vs Early Monetization:**
- ✅ Faster user growth, better retention, learn from Transit's mistakes
- ❌ Delayed revenue
- **Decision:** Growth > revenue in Phase 1 (6-12 month window)

---

## 11. Environments

### Development (Local)
- iOS: Xcode simulator + physical device
- Backend: `docker-compose up` (FastAPI + Supabase local + Redis local)
- Database: Supabase local instance (via CLI)
- APIs: Mock NSW API responses (avoid rate limits during dev)

### Staging (Pre-Production)
- iOS: TestFlight (internal testers)
- Backend: Railway/Fly.io staging environment
- Database: Supabase staging project (separate from prod)
- APIs: Real NSW APIs (separate API key)
- Purpose: User acceptance testing, beta testing

### Production (Live)
- iOS: App Store (public release)
- Backend: Railway/Fly.io production environment
- Database: Supabase production project
- APIs: NSW APIs (production API key, monitored)
- Monitoring: Sentry (errors), Railway logs, Supabase dashboard

### Configuration Management
```python
# backend/app/config.py
class Settings:
    ENVIRONMENT: str = "development"  # development, staging, production

    # Supabase
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_KEY: str

    # NSW Transport
    NSW_API_KEY: str
    NSW_BASE_URL: str = "https://api.transport.nsw.gov.au/v1"

    # Redis
    REDIS_URL: str

    # APNs
    APNS_KEY_ID: str
    APNS_TEAM_ID: str
    APNS_BUNDLE_ID: str = "com.yourdomain.transitapp"

    # Feature Flags
    ENABLE_PUSH_NOTIFICATIONS: bool = True
    ENABLE_OFFLINE_MODE: bool = False  # P1 feature
```

---

## 12. Dependencies & Third-Party Services

### External Services (Free Tiers)

| Service | Purpose | Free Tier | Cost After |
|---------|---------|-----------|------------|
| **Supabase** | Database + Auth + Storage | 500MB DB, 50K MAU, 1GB storage | $25/month (Pro) |
| **Railway** | Backend hosting | $5 credit/month | $0.000231/GB-sec + usage |
| **Fly.io** | Backend hosting (alt) | ~Free (<$5 waived) | $0.02/GB RAM/month |
| **CloudFlare** | CDN | Unlimited bandwidth | Free forever |
| **Vercel** | Marketing site | Unlimited bandwidth | Free (Hobby) |
| **Sentry** | Error tracking | 5K events/month | $26/month (Team) |
| **Apple APNs** | Push notifications | Free | Free forever |
| **NSW Transport** | GTFS data | 60K calls/day | Free forever (government) |

### iOS Dependencies (Swift Package Manager)

```swift
// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    .package(url: "https://github.com/malcommac/SwiftDate", from: "7.0.0"),
    .package(url: "https://github.com/apple/swift-protobuf", from: "1.25.0"),
    .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
]
```

### Backend Dependencies (Python)

```txt
# requirements.txt (core)
fastapi==0.104.0
uvicorn[standard]==0.24.0
celery[redis]==5.3.4
redis==5.0.1
supabase==2.0.3
gtfs-realtime-bindings==1.0.0
apns2==0.7.2
pydantic==2.5.0
python-dotenv==1.0.0
```

---

## 13. Risk Register

### Technical Risks

**HIGH: NSW API Rate Limits Exceeded**
- **Likelihood:** Medium (without caching)
- **Impact:** High (app unusable)
- **Mitigation:** Aggressive Redis caching (60-70% reduction), monitoring at 80% threshold, alert developer
- **Contingency:** Increase cache TTLs, reduce polling frequency, request rate limit increase from NSW

**HIGH: Supabase Free Tier Exhaustion**
- **Likelihood:** Medium (at 5K+ users)
- **Impact:** High (database unavailable)
- **Mitigation:** Monitor at 80% (400MB DB, 40K MAU), optimize queries, indexes
- **Contingency:** Upgrade to Pro ($25/month), plan migration to self-hosted

**MEDIUM: Large GTFS Static File (227MB)**
- **Likelihood:** High (NSW updates daily)
- **Impact:** Medium (app size bloat, download issues)
- **Mitigation:** Differential updates, compression, optional offline mode (P1)
- **Contingency:** Serve minimal GTFS subset via backend API

**MEDIUM: Apple App Store Rejection**
- **Likelihood:** Low (following guidelines)
- **Impact:** High (delayed launch)
- **Mitigation:** Apple Sign-In required, privacy policy, no prohibited content
- **Contingency:** Address reviewer feedback, 2-week buffer in timeline

### Business Risks

**HIGH: No Product-Market Fit**
- **Likelihood:** Low (proven demand: TripView 500K users)
- **Impact:** Critical (app fails)
- **Mitigation:** Match TripView reliability first, add features second
- **Validation:** 6-month checkpoint: 1K+ users, 4.5+ rating, >40% 7-day retention

**MEDIUM: Competitor Response**
- **Likelihood:** Medium (TripView or Transit could modernize)
- **Impact:** Medium (harder to differentiate)
- **Mitigation:** Move fast (14-18 week launch), generous free tier, better UX
- **Advantage:** Incumbents slow to change (TripView hasn't updated in years)

### Operational Risks

**HIGH: Solo Developer Burnout**
- **Likelihood:** Medium (14-18 week sprint)
- **Impact:** Critical (project stalls)
- **Mitigation:** Simplicity first, avoid over-engineering, use managed services
- **Contingency:** Extend timeline, reduce P0 scope if needed

**MEDIUM: Bill Shock (Runaway Costs)**
- **Likelihood:** Low (with monitoring)
- **Impact:** High (budget exceeded)
- **Mitigation:** Cost alerts (80% thresholds), task timeouts, memory limits, rate limiters
- **Contingency:** Kill runaway tasks, scale down resources, optimize before scaling

---

## 14. Next Steps (Immediate)

### This Session (Architecture Specifications):

1. ✅ **SYSTEM_OVERVIEW.md** (this document) - COMPLETE
2. ⏳ **DATA_ARCHITECTURE.md** - Next (with 4 Oracle consultations)
3. ⏳ **BACKEND_SPECIFICATION.md** - (with 3 Oracle consultations)
4. ⏳ **IOS_APP_SPECIFICATION.md** - (minimal Oracle input)
5. ⏳ **INTEGRATION_CONTRACTS.md** - (1 Oracle consultation)

### Next Session (Implementation Roadmap):
- Create **IMPLEMENTATION_ROADMAP.md**
- Break down 14-18 week timeline into phases
- Define milestones, dependencies, success criteria per phase

### Post-Architecture (Development):
- Initialize Xcode project + GitHub repo
- Set up Railway/Fly.io + Supabase projects
- Implement Phase 1 (walking skeleton: auth + basic API)

---

**Document Status:** ✅ COMPLETE - Foundation established
**Next Document:** DATA_ARCHITECTURE.md (requires Oracle consultation)
**Last Updated:** 2025-11-12
