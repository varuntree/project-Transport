# Project Context - Strategic Decisions
**For Architecture Design**

---

## Project Vision

**Building:** Best public transit app in Australia - reliability-first, then enhanced with AI capabilities.

**Platform:** iOS application (primary)

**Mission:** Be the definitive transit app in Australia - start with Sydney, expand nationwide, nail core functionality first, layer intelligence after.

---

## Build Philosophy

1. **iOS only** - focused platform, no Android
2. **Fundamentals first** - nail core transit features before AI/voice
3. **Sydney-first** - perfect one city (NSW) before expanding to Melbourne/Brisbane
4. **Modular architecture** - easy to add cities later, backend serves iOS app + marketing site
5. **FastAPI backend** - Python for API + background workers, Next.js (static) for marketing site
6. **Low app size** - aggressive optimization, smart caching (<50MB initial download)
7. **Match then exceed competitors** - TripView reliability + Transit features + better UX
8. **Generous free tier** - don't artificially limit core features
9. **Web later** (2026) - government/agency analytics dashboards, not user-facing transit app

---

## Strategic Positioning

**Phase 1 Goal:** Best transit app in Australia (core functionality)

**Immediate Differentiators:**
1. TripView reliability + Transit features + modern UX
2. Generous free tier (don't artificially limit core features)
3. Sydney perfection - nail one city completely before expanding
4. iOS-focused polish (better than cross-platform competitors)
5. Ultra-lightweight - <50MB app vs competitors' 100-200MB bloat
6. Modular architecture (future-ready for AI layer + city expansion)

---

## Technology Foundations

### Data Sources
- **Sydney:** Transport NSW Open Data Hub (GTFS feeds, Trip Planner APIs)

### Architecture Principles
1. **Platform:** iOS only (Swift/SwiftUI), iOS 16+ minimum
2. **Backend:** FastAPI (Python) for API + background workers, Next.js (static) for marketing site
3. **Geographic:** Sydney/NSW first, modular for Melbourne/Brisbane later
4. **Storage:** SQLite + GRDB (227MB NSW GTFS optimized to ~300MB on-device)
5. **Routing:** NSW Trip Planner API (60K free calls/day) + local caching
6. **Native-first:** MapKit, WeatherKit, CloudKit, Live Activities
7. **Libraries:** Minimal (GRDB, SwiftDate, SwiftProtobuf only)
8. **App size:** <50MB initial, optional offline data download
9. **Future AI layer:** Pluggable, modular (Phase 2+)

---

## Strategic Decisions Locked

### Geographic Scope
**Sydney/NSW only for Phase 1**
- NSW has best API (227MB GTFS, daily updates, 5 req/s, all modes real-time)
- Modular architecture for easy Melbourne/Brisbane expansion
- Perfect one city before multi-city complexity

### Backend Stack
**FastAPI (Python) + Next.js (static)**
- FastAPI for REST API + background workers (GTFS polling, alerts, APNs)
- Next.js (SSG) for marketing site only
- Hosting: Railway/Fly.io (backend), Vercel (marketing site)
- PostgreSQL + Redis for data/caching

### App Size Priority
**Must be low (<50MB initial download)**
- Challenge: 227MB NSW GTFS data
- Solution: Optional offline data, aggressive caching, smart compression

### iOS Version
**iOS 16+ (96% market coverage)**
- Gets: WeatherKit, Live Activities, Lock widgets
- Native capabilities: MapKit, CloudKit, CoreLocation

### Libraries
**Minimal dependencies**
- GRDB (SQLite wrapper)
- SwiftDate (timezone handling)
- SwiftProtobuf (GTFS-RT parsing)

---

## Self-Funded Reality

- Must be financially sustainable (bootstrapped, no VC)
- Cost-effective architecture (modular backend, native iOS)
- Freemium model with generous free tier
- **Budget constraint:** $50/month max for MVP infrastructure

---

## Build Philosophy

- Modular architecture allows AI evolution
- Quality > Speed (reliability is table stakes)
- TripView took years to reach 500K users - don't rush
