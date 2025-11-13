# Technical Requirements for System Architecture
**Purpose:** Define constraints, requirements, and objectives for Oracle to design optimal architecture

---

## 🎯 Mission-Critical Objectives

**Primary Goal:** Design architecture for best-in-class transit app - TripView reliability + Transit features + modern iOS UX

**Key Success Criteria:**
1. **Accuracy:** Real-time data must be reliable and trustworthy
2. **Performance:** Fast response times, minimal latency for live data
3. **Efficiency:** Optimal resource usage (cost, bandwidth, battery)
4. **Modularity:** Easy extension to Melbourne/Brisbane (Phase 2)
5. **Scalability:** Architecture ready for future AI/voice features (Phase 3+)

---

## ⚙️ Non-Negotiable Technical Constraints

### Platform & Version Requirements
- **iOS:** 16+ minimum (96% market coverage)
- **Language:** Swift/SwiftUI for iOS app
- **Backend:** FastAPI (Python) - decision already made
- **Database:** Supabase (PostgreSQL + Auth + Storage) - consolidates 3 services for solo developer
- **Caching:** Redis
- **Background Workers:** Celery (Python)
- **Marketing Site:** Next.js (static) - separate from backend

### App Size Constraint
- **Initial download:** <50MB (critical competitive advantage)
- **Challenge:** NSW GTFS static data = 227MB raw
- **Oracle must solve:** How to architect for small app size while maintaining offline capability option

### API Rate Limits & Constraints
**NSW Transport API:**
- Rate limit: 5 requests/second
- Daily limit: Free tier sufficient for MVP
- GTFS static: 227MB ZIP, updated daily
- GTFS-RT feeds: Real-time updates (frequency varies by mode)

**Oracle must design:** Optimal polling/caching strategy within these limits

### Cost Constraint
- **MVP budget:** $25/month maximum (Supabase free tier + Railway/Fly.io + Vercel free)
- **Supabase free tier:** 500MB database, 50K monthly active users, 1GB file storage, authentication included
- **Growth phase:** Scale cost-efficiently with user growth
- **Oracle must optimize:** Architecture for minimal infrastructure cost while maximizing free tiers

### Timeline
- **Phase 1 MVP:** 14-18 weeks to launch
- **Must be pragmatic:** Ship fast, iterate based on real usage

---

## 🏗️ Required System Capabilities

### Backend Must Support:
1. **Real-time data aggregation** from NSW GTFS-RT feeds
2. **Background workers** for continuous polling (frequency TBD by Oracle)
3. **Efficient caching layer** to minimize API calls and reduce latency
4. **Push notifications** (APNs) for service alerts
5. **REST API** for iOS client communication
6. **GTFS static data** storage and querying via Supabase
7. **Authentication** via Supabase Auth (Apple Sign-In integration)
8. **File storage** via Supabase Storage (if needed for user uploads, GTFS exports)

### iOS App Must Support:
1. **Local database** (SQLite + GRDB) for offline/cached data
2. **Native iOS features:** MapKit, WeatherKit, CloudKit, Live Activities
3. **Minimal dependencies** (GRDB, SwiftDate, SwiftProtobuf only)
4. **Background data sync** for favorites and essential data
5. **Low battery consumption** for location-based features

### Data Management:
- **Favorites sync:** Supabase (backend) or CloudKit (iOS-only) - Oracle decides optimal approach
- **User authentication:** Supabase Auth with Apple Sign-In (primary), handles JWT, session management
- **Privacy-first:** Minimal data collection, GDPR-compliant, Supabase Row Level Security (RLS) for data isolation

---

## 📋 Phase 1 MVP Features (Priority Order)

**Core P0 Features** (must have for launch):
1. Real-time departures with countdown timers (all NSW modes)
2. Stop/station search and nearby stops (geolocation)
3. Service alerts and disruption notifications
4. Trip planning (multi-modal, door-to-door)
5. Favorites & quick access to saved stops
6. Push notifications for favorites alerts
7. Maps with live vehicle positions

**Enhanced P1 Features** (post-launch):
- Home screen widgets
- Live Activities for trip tracking
- Saved trips (common journeys)
- GO mode (step-by-step guidance)
- Weather integration
- Offline schedules (optional 300MB download)

**Oracle's task:** Design architecture that elegantly supports P0 features while making P1 features easy to add later

---

## 🌐 Data Sources & Integration Points

### NSW Transport Data (Primary - Phase 1)
- **GTFS Static:** 227MB ZIP, daily updates
- **GTFS-RT:** Real-time vehicle positions, trip updates, service alerts
- **Trip Planner API:** 60K free calls/day for multi-modal routing
- **Documentation:** See `api_transit_data.md` for full API specifications

### Future Expansion (Phase 2+ - Architecture Must Accommodate)
- **Melbourne:** Public Transport Victoria (PTV) APIs
- **Brisbane:** TransLink Queensland GTFS feeds
- **Oracle must design:** Modular city/data source abstraction layer

---

## 🧩 Extensibility Requirements

### Phase 2: Multi-City Expansion
**Oracle must ensure:**
- Easy addition of new cities (Melbourne, Brisbane) without major refactor
- City-specific data isolated (per-city databases? unified schema? Oracle decides)
- Efficient handling of multiple GTFS feeds
- User can switch cities or see multi-city trips

### Phase 3: AI/Voice Features
**Future capabilities** (context for architectural decisions):
- Voice AI assistant (multilingual, accessibility)
- Proactive "autopilot mode" with calendar integration
- Weather-aware suggestions
- Predictive transit recommendations

**Oracle's consideration:** Design data layer and API contracts that won't break when adding AI orchestration layer

---

## 🏆 Architecture Quality Attributes

**Oracle should optimize for:**

### 1. Reliability
- Handle NSW API outages gracefully (fallback to cached/scheduled data)
- No crashes, no data corruption
- Clear user communication when real-time data unavailable

### 2. Performance
- Real-time departure queries: <200ms response time (target)
- App launch: <2 seconds to usable state
- Live data updates: Fresh data without excessive polling

### 3. Resource Efficiency
- **Backend:** Minimize compute/database costs through smart caching
- **iOS:** Battery-efficient location tracking, minimal network usage
- **Data transfer:** Optimize payloads, use compression

### 4. Developer Experience
- Clear separation of concerns (iOS ↔ Backend ↔ Data sources)
- Easy local development setup
- Well-defined API contracts (OpenAPI/Swagger)

### 5. Maintainability
- Modular architecture (easy to change one piece without affecting others)
- Clear data flow diagrams
- Production-ready code structure (not prototype-quality)

---

## 🚫 What Oracle Should NOT Include

**Avoid over-engineering:**
- No microservices (modular monolith is sufficient for MVP)
- No GraphQL (REST is fine, can add later if needed)
- No complex message queues (Redis + Celery sufficient)
- No Kubernetes (Railway/Fly.io handles deployment)

**Don't prescribe implementation details user will handle:**
- UI/UX design (Oracle focuses on architecture, not visual design)
- Exact Swift code patterns (high-level iOS architecture only)

---

## 📦 Deliverables Expected from Oracle

### 1. System Architecture Diagram
- Backend components (FastAPI, Celery workers, Supabase, Redis)
- iOS app layers (UI, services, data layer)
- Data flow: NSW APIs → Backend → Supabase → iOS
- External services (APNs, Supabase Auth, CloudKit if used)

### 2. Database Schema Design
- Supabase (PostgreSQL) schema for GTFS static data
- User authentication tables (Supabase Auth built-in)
- User data model (favorites, preferences, saved trips)
- Supabase Row Level Security (RLS) policies for data isolation
- Redis data structures for caching real-time data
- iOS SQLite schema (if different from backend)

### 3. API Contract Specification
- REST API endpoints (request/response schemas)
- Authentication flow (Supabase Auth + Apple Sign-In integration)
- Supabase client integration patterns (direct iOS↔Supabase or via FastAPI proxy)
- Error handling patterns
- Versioning strategy

### 4. Background Worker Design
- Celery tasks breakdown (GTFS-RT polling, alert matching, APNs delivery)
- Task scheduling strategy (Oracle decides optimal polling frequency)
- Error handling and retry logic
- Monitoring & logging approach

### 5. iOS Architecture Blueprint
- App structure (MVVM, Clean Architecture, or other pattern)
- Data layer design (GRDB, network layer, caching strategy)
- Service layer (location, notifications, etc.)
- Dependency management approach

### 6. Deployment Architecture
- Railway/Fly.io setup for FastAPI + Celery workers
- Supabase project setup (database, auth, storage configuration)
- Environment configuration (Supabase keys, API secrets)
- Redis setup (Railway managed or Upstash serverless)
- Monitoring & error tracking setup (Supabase logs + Sentry)

### 7. Development Roadmap
- Phase 1 breakdown into sprints/milestones (14-18 weeks)
- Feature implementation order (considering dependencies)
- Testing strategy (unit, integration, end-to-end)
- Launch checklist

---

## 🎨 Oracle's Creative Freedom

**Areas where Oracle has full autonomy to decide:**
- Polling frequency for GTFS-RT feeds (optimize for freshness vs cost)
- Caching strategy (TTLs, cache invalidation, prefetching)
- Data flow optimization (where to process, transform, filter data)
- Database indexing strategy
- iOS data synchronization patterns
- Error handling and retry mechanisms
- Logging and monitoring architecture
- Deployment workflow (CI/CD if applicable)

**Guiding principle:** Oracle should design the MOST EFFICIENT, RELIABLE, and MAINTAINABLE architecture possible within the stated constraints.

---

## 📊 Success Metrics (For Oracle's Design Validation)

**Oracle's architecture should enable:**
- 99.9% uptime for backend services
- <5 second app cold start time
- Real-time data freshness: <60 seconds staleness maximum
- Infrastructure cost: <$1/user/month at 1K users
- Battery consumption: <5% for 30-minute commute with location tracking
- App store rating target: 4.5+ stars (good architecture = good UX)

---

## 🤝 Collaboration Notes

**What Oracle can ask back:**
- Clarifications on any requirement
- Trade-off decisions (e.g., "Option A: faster but more expensive, Option B: cheaper but more complex")
- Missing information needed for design

**What Oracle should assume:**
- User (developer) has Python/Swift experience, can implement detailed design
- Standard software engineering best practices apply
- Security basics handled (HTTPS, JWT, input validation, etc.)

---

## 📚 Reference Documents Provided

1. **context.md** - Strategic decisions, market context, future vision
2. **phase1_feature_map.md** - Detailed feature specifications and UI requirements
3. **api_transit_data.md** - NSW Transport API documentation and GTFS schema
4. **backend_patterns.md** - Recommended tech stack and deployment patterns

**Oracle should reference these for full context but is not bound by implementation suggestions in them - optimize as you see fit.**

---

**Ready for Oracle to begin system architecture design.**
