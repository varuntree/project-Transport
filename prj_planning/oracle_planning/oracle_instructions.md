# Instructions for Oracle: System Architecture Design
**Role:** You are the Senior Architect (Oracle) - the most intelligent architecture expert with complete world knowledge
**Mission:** Design the complete, production-ready system architecture for our transit app
**Context:** 5 accompanying documents provide full project context
**Output:** Complete `ARCHITECTURE.md` following the iOS architecture template provided below

---

## 🎯 Your Task

You will design the **complete system architecture** for a Sydney transit app (iOS + FastAPI backend). This is a real project with a solo developer, zero users currently, and ambitious goals.

Your architecture must be:
1. **Implementation-ready** - developer can build directly from your spec
2. **Research-backed** - cite successful patterns from real transit apps
3. **Pragmatic** - optimized for solo developer with no team
4. **Scalable** - handles 0 → 50K users without full rewrite
5. **Cost-conscious** - maximizes free tiers, minimal monthly spend
6. **Resilient** - anticipates and mitigates edge cases/failures

---

## 📚 Context Documents (Read These First)

You have access to 5 context documents that provide complete project understanding:

### 1. **context.md** - Strategic Context
- Market validation: 6.4M TAM, proven willingness to pay
- Competitive landscape: TripView, Transit, NextThere
- Future vision: AI/voice features (Phase 2+), multi-city expansion
- Build philosophy: fundamentals-first, iOS-only, Sydney-first
- **Key insight:** We're building TripView reliability + Transit features + modern iOS UX

### 2. **phase1_feature_map.md** - Feature Requirements
- P0 features for Phase 1 MVP (14-18 weeks timeline)
- Real-time departures, stop search, trip planning, service alerts, push notifications
- Free vs Premium tier breakdown
- iOS + backend architecture sketches
- **Your job:** Design architecture that elegantly supports these features

### 3. **api_transit_data.md** - Data Source Specifications
- NSW Transport API: GTFS static (227MB), GTFS-RT feeds, Trip Planner API
- Rate limits: 5 req/s, 60K calls/day (generous for MVP)
- Complete GTFS schema documentation
- **Critical constraint:** All architecture decisions must respect these API limits

### 4. **backend_patterns.md** - Tech Stack & Patterns
- Recommended: FastAPI (Python), Supabase, Redis, Celery
- Deployment: Railway/Fly.io for backend, Supabase for database/auth/storage
- Cost analysis: $0-25/month MVP → $100-300/month at 10K users
- **These are recommendations, not mandates** - you can adjust if research shows better approach

### 5. **technical_requirements.md** - Requirements & Constraints
- Non-negotiable: iOS 16+, <50MB app size, $25/month max cost
- Required capabilities: background workers, caching, push notifications
- Success metrics: 99.9% uptime, <200ms queries, <5% battery for 30min trip
- **Hard constraints** - your architecture must satisfy all of these

---

## 🧠 Key Principles for Your Design

### 1. Solo Developer Reality
**Context:** No DevOps team, no 24/7 monitoring, no complex deployments.

**Design implications:**
- Every additional service = mental overhead + maintenance burden
- Self-healing systems preferred over manual intervention
- One-click deploys (Railway/Fly.io) over Kubernetes complexity
- Built-in observability (can't fix what you can't see)
- Failure modes must be obvious and recoverable

**Question to answer:** "Can one developer maintain this at 3am with no documentation?"

### 2. Zero-to-Scale Philosophy
**Current state:** 0 users, 0 revenue
**6-month target:** 1-5K users
**12-month dream:** 10-50K users

**Design implications:**
- Start with simplest architecture that could possibly work
- Add complexity only when metrics prove it necessary
- Define clear scaling triggers (when to add replicas, microservices, etc.)
- Maximize free tiers: Supabase (500MB, 50K MAU), Vercel (static), CloudFlare (CDN)
- Don't optimize for problems we don't have yet

**Scaling trigger examples:**
- Add read replicas when: DB CPU >70% sustained
- Add Redis when: same query >100 times/minute
- Migrate from free tier when: 80% of resource limit reached

### 3. Research Mandate (CRITICAL!)

**You have access to:**
- Web search for production transit apps worldwide
- GitHub repos of successful open-source transit systems
- Research papers on real-time data architectures
- Stack Overflow discussions on GTFS optimization
- Blog posts from companies solving similar problems at scale

**MANDATORY research activities:**
1. **Find 3-5 successful transit apps** (any country) and analyze their architectures (if public)
2. **Search for "GTFS caching strategies"** - what do production apps do?
3. **Research "real-time transit data architecture"** - identify common patterns
4. **Study "API rate limiting strategies"** - how to stay within 5 req/s elegantly
5. **Find "Supabase + FastAPI architecture examples"** - any proven integration patterns?
6. **Look up "Celery background tasks best practices"** - polling frequency recommendations

**Output requirement:**
- Cite sources: "Based on [App X's architecture blog], I recommend..."
- Reference patterns: "CommonTransit pattern used by 3+ apps: [pattern description]"
- Justify decisions: "Research shows GTFS apps typically poll every X seconds because..."

**Don't guess - look up successful patterns and adapt them to our constraints.**

### 4. Edge Case Thinking

**For every architectural component, ask: "What if this fails?"**

**Design defenses against these disasters:**

💸 **Bill Explosion:**
- Celery task runs in infinite loop (runaway GTFS-RT polling)
- Redis memory fills up (no eviction policy)
- Supabase storage leak (temp files never cleaned)
- API calls spike unexpectedly (no rate limiting on our side)
- **Safeguard:** Cost alerts, task timeouts, memory limits, rate limiters

🔥 **Data Integrity:**
- GTFS feed corrupted (malformed protobuf)
- Partial data sync (crash mid-update)
- Stale cache served (Redis outlives source data)
- Concurrent writes conflict (race conditions)
- **Safeguard:** Validation, transactions, TTLs, optimistic locking

🚫 **Service Failures:**
- NSW API down for hours (no backup)
- Supabase outage (how long can iOS function offline?)
- Redis crash (does app break or degrade gracefully?)
- Celery worker dies silently (alerts stop, nobody notices)
- **Safeguard:** Fallbacks, offline mode, health checks, monitoring

**For each scenario, design the SIMPLEST safeguard that prevents catastrophe.**

### 5. Cost Consciousness

**Free tier maximization strategy:**
- Supabase: 500MB database, 50K monthly active users, 1GB storage
- Vercel: Next.js static site, unlimited bandwidth
- CloudFlare: CDN, unlimited bandwidth
- Railway: $5 monthly credit
- Upstash: 10K Redis requests/day free (alternative to Railway Redis)

**Built-in cost monitoring:**
- Alert when Supabase DB approaches 400MB (80% threshold)
- Track NSW API calls daily (stay well under 60K/day limit)
- Redis memory usage monitoring
- Monthly spend dashboard visible to developer

**Design principle:** Architecture should maximize free tiers and provide early warnings before costs spike.

### 6. Battle-Tested Over Novel

**Prefer proven technology:**
✅ FastAPI (production-proven since 2018)
✅ Celery (battle-tested since 2009)
✅ Supabase (100K+ production apps)
✅ Redis (industry standard)
✅ SwiftUI + MVVM (standard iOS pattern)

**Avoid (for now):**
❌ Experimental databases
❌ Alpha-stage frameworks
❌ Novel architectures from HackerNews front page
❌ Untested caching strategies
❌ Bleeding-edge Swift features

**When suggesting patterns, prioritize those successfully used in production by apps at similar scale.**

### 7. Observability from Day 1

**Solo developer needs confidence system is healthy at a glance.**

**Must-have from launch:**
- Request logging (every API call tracked)
- Error tracking (Sentry or similar)
- Performance metrics (response times, cache hit rates)
- Cost monitoring (Supabase usage, API call counts)
- Celery task success/failure rates
- NSW API health check (is their feed up?)

**Simple dashboards:**
- Real-time: NSW feed status, cache hit rate, API latency
- Daily: User count, API calls, errors, costs
- Weekly: Trends, anomalies, scaling triggers

**No complex APM tools** - keep it simple, actionable, glanceable.

### 8. Supabase-First Strategy

**Supabase provides 3 services in 1:**
- Database (PostgreSQL with PostGIS)
- Authentication (Apple Sign-In, JWT, sessions)
- Storage (1GB file storage)

**Use Supabase built-in features:**
- Auth: Apple Sign-In integration, JWT handling, session management
- Row Level Security (RLS): user data isolation without backend code
- Real-time subscriptions: consider for live vehicle positions (research if viable)
- Auto-generated REST API: for simple queries (reduces FastAPI code)
- Storage: if needed for user uploads, GTFS exports

**When to bypass Supabase (use FastAPI):**
- Complex GTFS queries requiring custom logic
- Real-time caching (Redis faster than Supabase queries)
- Background jobs (Celery, not Supabase Edge Functions)
- Heavy data transformations

**Decision you must make:** Which operations go direct to Supabase vs through FastAPI proxy? Optimize for fewer moving parts.

### 9. Architecture Evolution Triggers

**Define clear metrics that trigger architectural changes:**

**Add database read replicas when:**
- Primary DB CPU >70% sustained
- Query response time >200ms at p95
- Read/write ratio exceeds 80/20

**Split services into microservices when:**
- Team grows to >5 developers (not applicable yet)
- Specific component needs independent scaling
- Deployment coupling causes issues

**Migrate from Supabase free tier when:**
- Database >400MB (80% of 500MB limit)
- Monthly active users >40K (80% of 50K limit)
- Storage >800MB (80% of 1GB limit)

**Upgrade backend hosting when:**
- API response time consistently >500ms
- Request rate exceeds free tier limits
- Need multi-region deployment

**Make decision-making objective, not subjective.** Provide clear numbers.

### 10. Non-Negotiable Simplicity Rules

**DO NOT add unless absolutely necessary:**
❌ Kubernetes (Railway/Fly.io handles orchestration)
❌ Message queues beyond Redis (Celery + Redis sufficient)
❌ GraphQL (REST fine for MVP, add later if needed)
❌ Separate auth service (Supabase Auth handles it)
❌ Separate file storage (Supabase Storage included)
❌ Complex CI/CD (GitHub + Railway auto-deploy sufficient)
❌ Multiple databases (Supabase + Redis only)
❌ Service mesh, API gateway (premature optimization)

**ONLY add if:**
- Solves actual problem proven with metrics
- Simpler solution insufficient
- Free tier exhausted or no free tier exists
- Complexity cost justified by benefit

**Challenge every component - justify its existence or remove it. Default to simpler.**

---

## 📋 Your Deliverable: Complete `ARCHITECTURE.md`

You will produce a complete architecture document following the template below. Every section must be filled out thoughtfully based on your research and the provided context.

### Required Document Structure

# 0) Document metadata
* **Project name:** [Name the app]
* **Owners:** Solo developer + AI assistant (you, Oracle)
* **Revision:** v1.0 / [Today's date]
* **Status:** Proposed (awaiting developer review)
* **Related docs:** context.md, phase1_feature_map.md, api_transit_data.md, backend_patterns.md, technical_requirements.md

# 1) Executive summary
* **Problem & goals:** What problem does this solve? What's the Minimum Lovable Product (MLP)?
* **Target users & top journeys:** Who uses this? What are their critical paths?
* **What we're shipping in Phase 1 (out of scope explicitly):** P0 features vs P1 (post-launch)

# 2) Scope, assumptions, constraints
* **In scope:** Phase 1 features, iOS 16+, Sydney/NSW only
* **Out of scope:** Android, web app (except static marketing), Melbourne/Brisbane (Phase 2)
* **Assumptions:** NSW API availability, Supabase uptime, user has internet most of time
* **Constraints:** Solo developer, $25/month budget, 14-18 week timeline, <50MB app size

# 3) Non-functional requirements (NFRs)
* **Performance budgets:** App launch ≤2s cold, scroll 60fps, memory ≤150MB, API <200ms p95
* **Reliability:** Crash-free sessions ≥99.5%, error rate ≤1%
* **Offline:** Read schedules/favorites offline, write queued for sync, conflict resolution strategy
* **Security & privacy:** Encryption, Keychain, PII handling, Supabase RLS
* **Accessibility:** WCAG 2.1 AA targets, Dynamic Type support, VoiceOver labels
* **Localization:** English only Phase 1 (architecture ready for multi-language)
* **Analytics:** Posthog/Plausible, key events/funnels, 90-day retention, privacy-compliant

# 4) System context (C4: Context)
* **Diagram:** iOS App ↔ FastAPI Backend ↔ Supabase (DB/Auth/Storage) ↔ Redis ↔ NSW Transport APIs ↔ APNs ↔ CDN (CloudFlare)
* **Trust boundaries:** Device (user-controlled) ↔ Network ↔ Backend (developer-controlled) ↔ Third-party (NSW, Supabase)
* **Environments:** Dev (local), Staging (Railway staging), Prod (Railway prod + Supabase prod)

# 5) Platform targets & device matrix
* **OS:** iOS 16+ (iPhone only Phase 1, iPad/widgets Phase 2)
* **Device classes:** iPhone SE (small screen), iPhone 14 Pro (notch/Dynamic Island), iPhone 15 Pro Max (large)
* **Test matrix:** iOS 16.0, 17.0, 18.0 on physical devices

# 6) Key architecture decisions (high-level)

**iOS App:**
* **UI:** SwiftUI (iOS 16+)
* **Pattern:** MVVM + Coordinator + Repository
* **Concurrency:** async/await (Combine only for streams if needed)
* **Packages:** Swift Package Manager (SPM)
* **Why:** [Justify choices vs alternatives]

**Backend:**
* **Language:** Python (FastAPI)
* **Workers:** Celery for background jobs (GTFS-RT polling, alerts, APNs)
* **Database:** Supabase (PostgreSQL + Auth + Storage)
* **Cache:** Redis (Railway managed or Upstash serverless - you decide which)
* **Hosting:** Railway or Fly.io (you decide which based on research)
* **Why:** [Justify with research citations]

# 7) Tech stack & dependencies

**iOS:**
* **Language:** Swift 5.9+, Xcode 15+
* **Core libs:** GRDB (SQLite), SwiftDate (timezones), SwiftProtobuf (GTFS-RT), Supabase Swift SDK
* **Why these:** [Justify each dependency]
* **Prohibited:** Realm (performance issues at scale per swift_transit_libraries.md)

**Backend:**
* **Language:** Python 3.11+
* **Framework:** FastAPI + Celery
* **Database:** Supabase client library
* **Cache:** Redis client (redis-py)
* **GTFS:** gtfs-realtime-bindings (Python)
* **Push:** apns2 (Python)
* **Why these:** [Justify with research]

# 8) App capabilities & entitlements
* **Enabled:** Push Notifications (APNs), Keychain Sharing, Background Modes (fetch, remote-notification, processing), Associated Domains (universal links)
* **Info.plist usage strings:** Location When In Use (for nearby stops), Notifications (for service alerts)
* **Bundle identifiers:** com.yourcompany.transitapp (prod), com.yourcompany.transitapp.dev (dev)

# 9) Module layout (C4: Container/Component)

**iOS Repository structure:**
```
TransitApp/
  Application/ (AppDelegate, DI container, config)
  Navigation/ (Coordinator, Routes, deeplinks)
  Core/
    DesignSystem/ (colors, typography, components)
    Utilities/ (extensions, logging, feature flags)
    Analytics/ (Posthog integration)
  Data/
    API/ (FastAPI client, Supabase client, endpoints)
    Repositories/ (protocols + implementations)
    Persistence/ (GRDB database, Keychain)
  Features/
    Auth/ (Apple Sign-In via Supabase)
    Home/ (real-time departures)
    Search/ (stop search, nearby)
    TripPlanner/ (multi-modal routing)
    Alerts/ (service disruptions)
    Favorites/ (saved stops/trips)
    Profile/ (user settings)
  Resources/ (Assets.xcassets, Localizable.strings)
  Tests/ (Unit, UI, Snapshot)
```

**Backend structure:**
```
backend/
  app/
    api/ (FastAPI routers)
      gtfs.py (static GTFS endpoints)
      realtime.py (GTFS-RT cached endpoints)
      trips.py (NSW Trip Planner proxy)
      alerts.py (service alerts aggregation)
      users.py (user data if not using Supabase direct)
    workers/ (Celery tasks)
      gtfs_poller.py (GTFS-RT polling task)
      alert_engine.py (match alerts to user favorites)
      apns_worker.py (push notification delivery)
    models/ (SQLAlchemy if needed, or Supabase schema)
    schemas/ (Pydantic request/response models)
    services/ (business logic)
    utils/ (Redis abstractions, helpers)
  tests/
  requirements.txt
  Dockerfile
  docker-compose.yml (for local dev)
```

**Dependency rules:** [Define import rules, acyclic dependencies]

# 10) Navigation & routing

**iOS:**
* **Structure:** TabView (Home, Search, TripPlanner, Alerts, Profile) with NavigationStack per tab
* **Routes:** Enum-based routing, Coordinator owns NavigationPath
* **Deep links:** Universal Links via Associated Domains, map `transitapp.com/stop/123` → StopDetailView
* **Modals:** `.sheet` for filters, `.fullScreenCover` for trip planning

**Backend:**
* **API routing:** FastAPI routers per domain (gtfs, realtime, trips, alerts)
* **Versioning:** `/api/v1/` path prefix, maintain backward compatibility 12 months

# 11) State management & concurrency

**iOS:**
* **View state:** `@State`, `@StateObject` for ViewModels
* **Async loading:** `.task { await vm.load() }`, cancel on view disappear
* **Long-lived streams:** Combine/AsyncStream for real-time updates (if used - you decide)
* **Threading:** `@MainActor` for ViewModels, heavy work (GTFS parsing) off main thread

**Backend:**
* **Celery task concurrency:** [Define worker pool size, task priorities]
* **Database connections:** [Connection pool size based on expected load]

# 12) Domain model

**Entities:**
- Stop, Route, Trip, Service, Alert, Vehicle, User, Favorite, SavedTrip
- **Relationships:** [Define with ERD or table]
- **IDs:** GTFS uses strings (stop_id, route_id), User uses UUID

**Mapping layers:**
- GTFS DTO (from API) ↔ Domain model ↔ ViewModel (for UI)
- Validation rules at each boundary

# 13) Networking & API contracts

**iOS → Backend:**
* **Auth:** Supabase Auth (JWT in header: `Authorization: Bearer <token>`)
* **Base URLs:** Dev: `http://localhost:8000`, Staging: `https://staging.api.transitapp.com`, Prod: `https://api.transitapp.com`
* **Serialization:** Codable, ISO8601 dates, Decimal for currency
* **Pagination:** Cursor-based (if needed) or offset/limit
* **Retry:** Exponential backoff, max 3 retries, idempotency for writes
* **Errors:** Map HTTP status codes to user messages

**Backend → NSW APIs:**
* **Rate limiting:** [Your design for staying within 5 req/s]
* **Caching strategy:** [GTFS static: daily refresh, GTFS-RT: TTL you decide based on research]
* **Fallback:** [What happens when NSW API is down?]

**Backend → Supabase:**
* **Direct queries:** [Which tables accessed directly vs through ORM]
* **RLS policies:** [Define per-table security rules]

**Sample endpoints:** [Provide 3-5 key endpoint specs with request/response JSON]

# 14) Persistence & offline strategy

**iOS:**
* **Cached data:** GTFS stops/routes (via GRDB SQLite), recent searches, user favorites
* **TTLs:** GTFS static (24 hours), real-time (5 minutes), favorites (infinite until logout)
* **Storage size:** ~30MB for Sydney GTFS subset (stops, routes, shapes)
* **Session:** Keychain stores Supabase JWT, access group for app group sharing if needed
* **Conflict resolution:** [Client-wins vs server-wins for favorites, define rules]

**Backend:**
* **Supabase tables:** [List schema: users, favorites, saved_trips, etc.]
* **Migration strategy:** Supabase migrations via SQL files
* **Backup:** Supabase automatic backups (point-in-time recovery)

# 15) Background tasks & schedulers

**iOS:**
* **Background fetch:** Refresh favorite stops' real-time data (15-minute opportunistic)
* **Background processing:** Sync favorites/saved trips with Supabase (user-initiated or daily)
* **Identifiers:** `com.yourcompany.transitapp.refresh`, `com.yourcompany.transitapp.sync`

**Backend:**
* **Celery Beat schedule:** [Define tasks and intervals based on research]
  - GTFS-RT polling: every ___ seconds (you decide optimal frequency)
  - Alert matching: every ___ minutes
  - APNs delivery: immediate on alert match
  - GTFS static refresh: daily at 3am Sydney time
* **Task timeout:** [Define per task type to prevent runaway jobs]

# 16) Push notifications

**Provider:** APNs direct (no FCM)
* **Registration:** iOS sends device token to backend on app launch, stored in Supabase users table
* **Token rotation:** Update on every app launch (handle token invalidation)
* **Categories:** `DELAY_ALERT`, `CANCELLATION_ALERT`, `GENERAL_ALERT`
* **Actions:** "View Route", "Dismiss"
* **Payload schema:**
```json
{
  "aps": {
    "alert": {
      "title": "Delay on Route 333",
      "body": "10 min delay due to traffic"
    },
    "sound": "default",
    "badge": 1,
    "category": "DELAY_ALERT"
  },
  "route_id": "333",
  "stop_id": "12345"
}
```
* **Deep link:** Notification tap opens route detail view

# 17) Design system & UX rules

* **Tokens:** [Define color palette (light/dark), spacing scale (4pt grid), typography (SF Pro), corner radius]
* **Components:** Buttons (primary, secondary, destructive), Cards, TextFields, Empty/Loading/Error states, List cells
* **Accessibility:** 44pt minimum tap target, Dynamic Type support, VoiceOver labels/hints/actions
* **Haptics:** [When to trigger feedback: button taps, pull-to-refresh, errors]

# 18) Internationalization & localization

* **Languages Phase 1:** English (Australia)
* **Future:** Simplified Chinese, Arabic (right-to-left), Spanish (Latin America)
* **Architecture:** `Localizable.strings`, all user-facing text must use `NSLocalizedString`
* **Locale-aware formatting:** Dates via `DateFormatter`, numbers via `NumberFormatter`

# 19) Observability (analytics, logging, crashes)

**iOS:**
* **Crash reporting:** Sentry iOS SDK (free tier: 5K events/month)
* **Analytics:** Posthog or Plausible (you decide based on privacy + features)
* **Key events:** app_launch, stop_search, trip_planned, favorite_added, alert_received
* **User ID:** Supabase user UUID (no PII in events)

**Backend:**
* **Logging:** Structured JSON logs to stdout (Railway captures)
* **Error tracking:** Sentry Python SDK
* **Metrics:** [Define what to track: API latency, cache hit rate, Celery task success rate]
* **Dashboards:** Railway metrics + custom dashboard (you design simple Supabase table + view)

# 20) Performance & reliability

**Budgets:**
* **iOS app launch:** Cold <2s, warm <1s
* **API response time:** p50 <100ms, p95 <200ms, p99 <500ms
* **Memory:** iOS app <150MB typical, <200MB peak
* **Battery:** <5% drain for 30-minute commute with location tracking

**Instrumentation:** Xcode Instruments (Time Profiler, Allocations), Sentry performance monitoring

**Release gates:** [Define: fail PR if launch time >X on device Y, crash-free rate <99%]

# 21) Error handling & resilience

**iOS:**
* **User-facing errors:** Inline error messages, retry button, toast for transient errors
* **Network offline:** Banner "You're offline. Showing cached data."
* **Graceful degradation:** Show scheduled times when real-time unavailable

**Backend:**
* **Exponential backoff:** For NSW API calls (start 1s, max 60s, jitter)
* **Circuit breaker:** [Define thresholds: after X failures, stop calling NSW API for Y minutes]
* **Data integrity:** [How do you ensure GTFS data consistency during updates?]

# 22) Security & privacy

**Threat model:**
* **Primary threats:** Unauthorized access to user data, API key exposure, man-in-the-middle attacks
* **Mitigations:** Supabase RLS policies, Keychain for tokens, HTTPS only (ATS enforced)

**Key management:**
* **iOS:** Supabase JWT in Keychain (kSecAttrAccessibleAfterFirstUnlock)
* **Backend:** Secrets in Railway environment variables (never in code)

**Transport Security:** TLS 1.3, no custom cert pinning (use system trust)

**App Privacy labels:** Location (for nearby stops), Analytics (optional opt-out)

**Data deletion:** User-initiated from Profile → Delete Account → backend deletes from Supabase

# 23) Build configs, environments, feature flags

**iOS:**
* **Schemes:** Dev (local backend), Staging (staging API), Prod (production API)
* **`.xcconfig` per env:** API_BASE_URL, SUPABASE_URL, SUPABASE_ANON_KEY
* **Feature flags:** [Local UserDefaults for dev, remote via Supabase table for prod - you design simple system]

**Backend:**
* **Environments:** Dev (docker-compose local), Staging (Railway staging), Prod (Railway prod)
* **Config:** `.env` files per environment (Railway env vars in cloud)

# 24) CI/CD & release management

**iOS:**
* **Branching:** Trunk-based (main branch, short-lived feature branches)
* **CI:** GitHub Actions: lint → build → test → upload to TestFlight
* **fastlane lanes:** `test` (run tests), `beta` (TestFlight), `release` (App Store)
* **Signing:** App Store Connect API key (in GitHub Secrets), automatic provisioning
* **Versioning:** Semantic (1.0.0), build number auto-incremented
* **Beta:** Internal TestFlight → external testers (50+) → public release
* **Release cadence:** Every 2 weeks for MVP, weekly after launch

**Backend:**
* **CI:** GitHub Actions: lint → test → build Docker image → push to Railway
* **Deployment:** Railway auto-deploys from `main` branch (zero-downtime)
* **Rollback:** Railway rollback to previous deployment (one-click)

# 25) Testing strategy & QA

**iOS:**
* **Unit tests:** ViewModels (100% coverage goal), Repositories (mocked network), business logic
* **UI tests:** Happy paths (search stop → view departures → favorite)
* **Snapshot tests:** Key views (via swift-snapshot-testing)
* **Coverage target:** 80% unit, critical flows in UI

**Backend:**
* **Unit tests:** Services, Celery tasks (mocked NSW API)
* **Integration tests:** API endpoints (TestClient)
* **Contract tests:** NSW API response schemas match expectations

**Manual QA:**
* **Device matrix:** iOS 16/17/18 on iPhone SE, 14 Pro, 15 Pro Max
* **Accessibility:** VoiceOver walkthrough before each release
* **Offline testing:** Airplane mode, degraded network

# 26) Team process & governance

**RACI:**
* **Architecture:** Oracle (proposed), Developer (approved)
* **iOS development:** Developer (responsible)
* **Backend development:** Developer (responsible)
* **Releases:** Developer (accountable)
* **On-call:** Developer (24/7 for first 6 months, then evaluate)

**Code review:** Self-review (solo developer), AI assistant review for critical paths

**Coding guidelines:**
* No business logic in SwiftUI Views (ViewModels only)
* Max function complexity: cyclomatic complexity ≤10
* No force-unwraps in production code
* Dependency injection for testability

# 27) Risks, open questions, and spikes

**Top risks:**
* **NSW API unreliability:** [Your mitigation strategy]
* **Supabase free tier exhaustion faster than expected:** [Early warning system]
* **Background task reliability on iOS:** [Testing strategy]
* **App Store review rejection:** [Compliance checklist]

**Open questions:**
* [List any decisions you need developer to make]
* [Trade-offs requiring input]

**Spikes needed:**
* [Any proof-of-concept work before implementation]

# 28) Appendices

**A. System Architecture Diagrams**
* High-level C4 Context diagram (iOS ↔ Backend ↔ Supabase ↔ NSW APIs)
* Backend component diagram (FastAPI ↔ Celery ↔ Redis ↔ Supabase)
* Data flow diagrams (static GTFS sync, real-time polling, push notifications)

**B. Database Schema**
* Supabase tables (DDL + RLS policies)
* iOS SQLite schema (GRDB)
* Redis data structures

**C. API Contracts**
* FastAPI OpenAPI schema (auto-generated)
* Sample request/response JSONs for key endpoints

**D. Celery Task Definitions**
* Task names, schedules, timeouts, retry policies

**E. Deployment Checklist**
* Railway setup steps
* Supabase project configuration
* iOS App Store Connect setup
* DNS/domain configuration

**F. Cost Breakdown & Monitoring**
* Monthly cost estimation (0, 1K, 10K, 50K users)
* Cost alert thresholds
* Dashboard design for tracking

---

## 🎯 Output Format & Expectations

### 1. Start with Research Summary
Before diving into architecture, present:
- 3-5 successful transit apps you researched (with architecture insights if public)
- Common GTFS caching patterns you found
- Polling frequency recommendations from research
- Any relevant blog posts, papers, or GitHub repos cited

**Format:**
```markdown
## Research Summary

**Apps Analyzed:**
1. [App Name] - [Country] - [Key Architecture Insight]
2. ...

**Key Findings:**
- GTFS-RT polling frequency: Most apps poll every 30-60 seconds for vehicle positions
- Caching strategy: Common pattern is [X]
- Source: [Link to blog/paper/repo]

**Patterns Applied to Our Architecture:**
- [How you're adapting these learnings]
```

### 2. Provide High-Level Architecture First
Before detailed sections, give the 10,000-foot view:
- System context diagram (iOS ↔ Backend ↔ Supabase ↔ NSW APIs)
- Data flow diagram (how GTFS static/real-time flows through the system)
- Component diagram (backend services)

Use ASCII diagrams or Mermaid syntax (developer can render).

### 3. Complete Every Section Thoughtfully
Don't skip or write "TBD" - every section must be filled based on research and context.

If you need to make a decision between options, explain:
- Option A: [Pros/Cons]
- Option B: [Pros/Cons]
- **Recommendation:** [Your choice] because [research-backed reasoning]

### 4. Justify All Major Decisions
For key architectural choices (database, hosting, polling frequency, caching strategy), provide:
- **Decision:** [What you chose]
- **Rationale:** [Why, backed by research or constraints]
- **Alternatives considered:** [What you rejected and why]
- **Trade-offs:** [What you're giving up with this choice]

### 5. Include Code Structure (Not Code Itself)
Provide folder structures, file names, module boundaries - NOT actual implementation code.

**Example:**
```
✅ Good:
Features/
  Home/
    HomeView.swift (SwiftUI view)
    HomeViewModel.swift (business logic)
    HomeRepository.swift (data access)

❌ Bad (don't do this):
class HomeViewModel: ObservableObject {
  func load() async { ... } // No actual code
}
```

### 6. Provide Week-by-Week Roadmap
Break 14-18 week timeline into sprints:
- Week 1-2: [Walking skeleton - what must exist]
- Week 3-4: [Feature X]
- ...
- Week 16-18: [Polish, testing, launch]

Consider dependencies (can't do real-time before static GTFS pipeline).

### 7. Call Out Critical Paths & Risks
Highlight:
- **Critical path:** [What must be built in order]
- **High-risk items:** [What could derail project, with mitigation]
- **Unknown unknowns:** [What you don't know yet, how to de-risk]

---

## ✅ Success Criteria (How We'll Know You Succeeded)

Your architecture is successful if:

1. **Implementation-ready:** Developer can start coding immediately without asking "wait, how do we...?"
2. **Research-backed:** Every major decision cites a source or proven pattern
3. **Pragmatic:** Optimized for solo developer, not Google-scale team
4. **Complete:** No TBDs, every section filled thoughtfully
5. **Scalable:** Clear triggers for when to add complexity (with metrics)
6. **Cost-conscious:** Maximizes free tiers, provides early cost warnings
7. **Resilient:** Anticipates failures, includes safeguards and monitoring
8. **Simple:** Minimum moving parts to achieve goals (challenge every component)

---

## 🚀 Begin Your Architecture Design

You have:
- ✅ Full project context (5 documents)
- ✅ Clear principles (solo developer, research-backed, pragmatic)
- ✅ Complete template to fill (every section defined)
- ✅ Research tools (web search, GitHub, papers)
- ✅ Creative freedom within constraints

**Your mission:** Design the BEST architecture possible for this transit app.

Start with research, think deeply about trade-offs, cite your sources, and deliver a complete, production-ready architecture that a solo developer can build and scale from 0 to 50K users.

**Good luck, Oracle. We trust your judgment. 🙏**
