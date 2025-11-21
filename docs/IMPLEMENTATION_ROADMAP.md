# Implementation Roadmap - Sydney Transit App
**Version:** 1.0
**Date:** 2025-11-12
**Timeline:** 14-20 weeks (7 phases + buffer)
**Dependencies:** All architecture specs (SYSTEM_OVERVIEW, DATA_ARCHITECTURE, BACKEND_SPECIFICATION, IOS_APP_SPECIFICATION, INTEGRATION_CONTRACTS), DEVELOPMENT_STANDARDS

---

## Document Purpose

This roadmap breaks down the complete implementation of Sydney Transit App MVP into 7 sequential phases. By the end of Phase 7, we will have a production-ready iOS app with all core features:

**Core Features (MVP):**
- Browse stops, routes, schedules (offline)
- Real-time departures (live GTFS-RT)
- Trip planner (A→B routing)
- User authentication (Apple Sign-In)
- Favorites (sync across devices)
- Service alerts (subscriptions)
- Push notifications (APNs)

**What's Deferred (Post-MVP):**
- Widgets, Live Activities
- Multi-language support
- Advanced analytics/monitoring
- Third-party transit agencies

---

## Implementation Philosophy

### Vertical Slicing (Feature-Layer Hybrid)

**Strategy:** Build working features incrementally, not layers.

**Why:**
- Always have a functional app (can demo at any phase)
- Catch integration issues early (backend + iOS together)
- Avoid waterfall risks (don't build full backend, then discover iOS issues)

**Order:**
1. **Foundation first** (Phase 0): Project setup, hello-world
2. **Static data** (Phase 1): Offline browsing (no external APIs yet)
3. **Real-time layer** (Phase 2): Live departures (first external integration)
4. **User features** (Phase 3): Auth, favorites, sync
5. **Complex features** (Phase 4-5): Trip planning, alerts
6. **Push notifications** (Phase 6): APNs integration (most complex)
7. **Production polish** (Phase 7): Deployment, monitoring, hardening

**Defer Complexity:** External services (APNs, complex scheduling) come AFTER basic app works.

---

## Phase Structure (Standard Per Phase)

Each phase follows this workflow:

```
┌─────────────────────────────────────────────┐
│ 1. USER SETUP (External Services)          │
│    - Create accounts, get API keys         │
│    - Download datasets (if needed)         │
│    - Configure external services           │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 2. PLANNING                                 │
│    - Read phase plan + specs               │
│    - Review DEVELOPMENT_STANDARDS.md       │
│    - Review previous phase implementation  │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 3. IMPLEMENTATION (AI Agent)                │
│    - Backend: APIs, Celery tasks, DB       │
│    - iOS: UI, ViewModels, Repositories     │
│    - Follow DEVELOPMENT_STANDARDS.md       │
│    - Structured logging, error handling    │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 4. MANUAL TESTING (User)                    │
│    - Run acceptance criteria checklist     │
│    - Verify backend (cURL, Celery logs)    │
│    - Verify iOS (simulator, manual flows)  │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 5. REVIEW & ITERATE                         │
│    - Fix bugs found in testing             │
│    - Refactor if needed                    │
│    - Update docs if patterns changed       │
└─────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────┐
│ 6. COMMIT & MOVE TO NEXT PHASE              │
│    - Git commit (feat: phase N complete)   │
│    - Tag release (phase-N-complete)        │
│    - Merge to main                         │
└─────────────────────────────────────────────┘
```

**Duration Per Phase:** 2-3 weeks (varies by complexity)

---

## 7 Phases Overview

### Phase 0: Foundation (Week 1-2)
**Goal:** Local dev environment, hello-world endpoints, basic project structure

**User Setup:**
- Create Supabase account (free tier)
- Create Railway account (free tier)
- Get NSW Transport API key (https://opendata.transport.nsw.gov.au/)
- Install Xcode 15+, Python 3.11+

**Deliverables:**
- Backend: FastAPI hello-world running locally (`http://localhost:8000`)
- iOS: Empty SwiftUI app running in simulator
- Supabase: Connected (empty DB, no tables yet)
- Redis: Connected (Railway managed Redis)
- Git: Repo initialized, `.gitignore` configured

**Acceptance Criteria:**
- `curl http://localhost:8000/health` returns 200
- iOS app launches in simulator (blank screen OK)
- Supabase connection works (can query empty DB)
- Redis connection works (can set/get key)

**Effort:** 1-2 weeks (setup overhead, learning curve)

---

### Phase 1: Static Data + Basic UI (Week 3-5)
**Goal:** Browse stops, routes, schedules offline (no real-time yet)

**User Setup:**
- Download GTFS static dataset (227MB) from NSW Transport
- Provide dataset to AI for processing

**Deliverables:**
- **Backend:**
  - GTFS parser (227MB → Supabase pattern tables)
  - Supabase schema (stops, routes, trips, patterns - see DATA_ARCHITECTURE.md Section 6)
  - iOS SQLite generator (15-20MB bundled DB)
  - API endpoints: `/api/v1/stops`, `/api/v1/routes`, `/api/v1/stops/{id}/departures` (static schedules only)
- **iOS:**
  - GRDB setup (bundled gtfs.db)
  - Home screen (list of example stops)
  - Stop details screen (name, location, routes)
  - Route list screen
  - Search screen (FTS5 search on stop names)

**Acceptance Criteria:**
- Backend: GTFS data loaded to Supabase (<50MB total)
- iOS: Can browse stops/routes offline (no network)
- Search: "Circular Quay" returns Central Station, Wynyard, etc.
- Static schedules: Show scheduled departure times (not real-time)

**Effort:** 2-3 weeks (GTFS parsing is complex)

---

### Phase 2: Real-Time Foundation (Week 6-8)
**Goal:** Live departures for any stop (GTFS-RT integration)

**User Setup:**
- Verify NSW API key has GTFS-RT access
- Deploy Redis to Railway (if not already)

**Deliverables:**
- **Backend:**
  - Celery setup (broker: Redis, 3 queues)
  - Celery Beat scheduler
  - GTFS-RT poller task (poll every 30s, update Redis cache)
  - Redis caching layer (blob model - see DATA_ARCHITECTURE.md Section 4)
  - Departures API: `/api/v1/stops/{id}/realtime-departures` (merges static + RT)
- **iOS:**
  - Departures screen (real-time departures for a stop)
  - Auto-refresh (every 30s)
  - Real-time badges (show delays, cancellations)
  - Network layer (APIClient, error handling)

**Acceptance Criteria:**
- Celery: Poller task runs every 30s, logs `poll_gtfs_rt` event
- Redis: Cache contains `gtfs_rt:train:blob`, `gtfs_rt:bus:blob` (TTL 60s)
- API: `/realtime-departures` returns live data (delays, vehicle positions)
- iOS: Departures screen shows "Arriving in 3 min" (real-time)
- Offline: Falls back to static schedules when network unavailable

**Effort:** 2-3 weeks (Celery setup + GTFS-RT parsing)

---

### Phase 3: User Features (Week 9-11)
**Goal:** Auth, favorites, sync across devices

**User Setup:**
- Enable Supabase Auth (Email + Apple Sign-In)
- Configure Apple Developer account (Sign in with Apple)
- Add redirect URIs to Supabase (for Apple OAuth)

**Deliverables:**
- **Backend:**
  - Supabase Auth integration (JWT validation)
  - Protected endpoints: `/api/v1/favorites` (CRUD)
  - RLS policies (users can only access their favorites)
- **iOS:**
  - Auth flow (Apple Sign-In)
  - SupabaseAuthManager (token storage in Keychain)
  - Favorites screen (list, add, delete)
  - Home screen: Show user's favorites (if signed in)
  - Sync: Favorites sync across devices (via Supabase)

**Acceptance Criteria:**
- Backend: `/favorites` requires `Authorization: Bearer <token>`
- Backend: User A cannot access User B's favorites (RLS enforced)
- iOS: Sign in with Apple works (token stored securely)
- iOS: Add favorite → appears on other device (sync verified)
- iOS: Sign out → favorites cleared locally

**Effort:** 2-3 weeks (Auth is complex, OAuth setup)

---

### Phase 4: Trip Planning (Week 12-13)
**Goal:** Plan trips A→B with real-time overlay

**User Setup:**
- None (all backend-side)

**Deliverables:**
- **Backend:**
  - Trip planner service (routing algorithm - see DATA_ARCHITECTURE.md Section 7)
  - API endpoint: `/api/v1/trips/plan` (POST: origin, destination, time)
  - Real-time overlay (merge trip with GTFS-RT delays)
- **iOS:**
  - Trip planner screen (search origin, destination)
  - Trip results screen (list of itineraries)
  - Trip details screen (step-by-step, map view)
  - MapKit integration (route polyline, stop markers)

**Acceptance Criteria:**
- Backend: Plan trip "Central Station → Bondi Junction" returns 3 itineraries
- Backend: Real-time delays reflected in arrival times
- iOS: Trip planner shows "Take T4 from Platform 23 → Town Hall (3 stops)"
- iOS: Map shows route path, stop locations
- iOS: Tap stop → navigate to stop details

**Effort:** 1.5-2 weeks (routing logic is well-defined)

---

### Phase 5: Alerts + Background Jobs (Week 14-16)
**Goal:** Users subscribe to alerts (in-app, no push yet)

**User Setup:**
- None (all backend-side)

**Deliverables:**
- **Backend:**
  - Alerts API: `/api/v1/alerts` (list active alerts)
  - Alert subscriptions: `/api/v1/alerts/subscribe` (user + stop/route)
  - Alert matcher task (Celery, runs every 2-5 min)
  - Match logic: User favorites → active alerts (see INTEGRATION_CONTRACTS.md Section 4)
- **iOS:**
  - Alerts screen (list active alerts)
  - Alert details screen (title, description, affected stops)
  - Subscribe toggle (on favorite stops)
  - In-app notifications (banner when alert matches)

**Acceptance Criteria:**
- Backend: Alert matcher runs every 2 min (peak) / 5 min (off-peak)
- Backend: User subscribed to "Central Station" → alert triggered for "T4 delays"
- iOS: Alert banner appears in-app (not push, just local notification)
- iOS: Tap alert → navigate to affected stop
- iOS: Unsubscribe → alert no longer shown

**Effort:** 2-3 weeks (alert matching is complex)

---

### Phase 6: Push Notifications (Week 17-18)
**Goal:** APNs integration (push alerts to device)

**User Setup:**
- Generate APNs certificate (Apple Developer Portal)
- Upload certificate to backend (APNS_PRIVATE_KEY_PATH env var)
- Configure APNs entitlements in Xcode

**Deliverables:**
- **Backend:**
  - APNs worker (Celery task, send push notifications)
  - Device registration API: `/api/v1/devices` (POST: device_token)
  - Alert matcher → APNs fan-out (see INTEGRATION_CONTRACTS.md Section 4.3)
  - Deduplication (3-layer: DB unique constraint + collapse-id + cooldown)
- **iOS:**
  - APNs registration (request permission, send token to backend)
  - Push notification handling (foreground, background, tapped)
  - Notification settings (quiet hours, severity filter)

**Acceptance Criteria:**
- Backend: Alert triggered → push sent to all subscribed devices
- Backend: Deduplication works (user doesn't get same alert twice)
- iOS: Push notification appears (even when app closed)
- iOS: Tap push → app opens to alert details
- iOS: Quiet hours respected (no push between 10pm-7am)

**Effort:** 1.5-2 weeks (APNs is well-documented, straightforward)

---

### Phase 7: Production Polish (Week 19-20)
**Goal:** Deploy to production, monitoring, App Store prep

**User Setup:**
- Deploy backend to Railway production (create prod project)
- Configure production Redis (Railway)
- Configure production Supabase (enable RLS, add indexes)
- Create TestFlight build (Xcode)
- Submit to App Store Connect (for review)

**Deliverables:**
- **Backend:**
  - Production configs (.env.production)
  - Health check endpoint (`/health` with DB/Redis/Celery status)
  - Metrics endpoint (`/metrics` for monitoring)
  - Error tracking (Sentry or similar)
  - Rate limiting enforced (SlowAPI + Cloudflare WAF)
  - Celery monitoring (Flower or logs)
- **iOS:**
  - Production build (release config)
  - TestFlight distribution
  - App Store metadata (screenshots, description)
  - Crash reporting (Sentry or Firebase Crashlytics)
  - Performance tuning (<2s launch, <150MB memory)
- **Monitoring:**
  - Cost alerts (Supabase, Railway, NSW API usage)
  - Uptime monitoring (backend endpoints)
  - Celery task failure alerts

**Acceptance Criteria:**
- Backend: Deployed to Railway, accessible via `https://api.sydneytransit.com`
- Backend: Health check returns 200 (DB + Redis + Celery healthy)
- iOS: TestFlight build available to beta testers
- iOS: All features work in production (auth, favorites, push, etc.)
- Monitoring: Alerts configured (cost spikes, errors, downtime)

**Effort:** 1-2 weeks (deployment + polish)

---

## Timeline Summary

| Phase | Duration  | Weeks    | Cumulative |
|-------|-----------|----------|------------|
| 0     | 1-2 weeks | 1-2      | 2 weeks    |
| 1     | 2-3 weeks | 3-5      | 5 weeks    |
| 2     | 2-3 weeks | 6-8      | 8 weeks    |
| 3     | 2-3 weeks | 9-11     | 11 weeks   |
| 4     | 1.5-2 weeks | 12-13  | 13 weeks   |
| 5     | 2-3 weeks | 14-16    | 16 weeks   |
| 6     | 1.5-2 weeks | 17-18  | 18 weeks   |
| 7     | 1-2 weeks | 19-20    | 20 weeks   |

**Total:** 14-20 weeks (~3.5-5 months)

**Buffer:** Add 2-3 weeks for unexpected issues (bugs, learning curve, external dependencies)

**Realistic Timeline:** 4-6 months to MVP launch

---

## Dependencies Between Phases

**Critical Path:**
```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4
                                  ↓
                            Phase 5 → Phase 6 → Phase 7
```

**Blocking Dependencies:**
- **Phase 1** requires **Phase 0** (project setup must be complete)
- **Phase 2** requires **Phase 1** (static data must exist before real-time)
- **Phase 3** can start after **Phase 2** (auth is independent of real-time)
- **Phase 4** requires **Phase 2** (trip planning needs real-time overlay)
- **Phase 5** requires **Phase 3** (alerts need user subscriptions → auth)
- **Phase 6** requires **Phase 5** (push notifications need alert matching)
- **Phase 7** requires **Phase 6** (all features must be complete)

**No Parallelization:** Phases are sequential (solo developer, vertical slicing)

---

## Risk Mitigation

### High-Risk Areas

1. **GTFS Parsing (Phase 1):**
   - **Risk:** 227MB dataset, complex GTFS spec, parsing errors
   - **Mitigation:** Use proven Python library (`gtfs-kit` or `transitfeed`), validate against GTFS spec, test with sample data first

2. **GTFS-RT Integration (Phase 2):**
   - **Risk:** NSW API rate limits (5 req/s), polling frequency, cache misses
   - **Mitigation:** Follow DATA_ARCHITECTURE.md Section 4 (adaptive polling, blob caching), monitor API usage, implement graceful degradation

3. **Apple Sign-In (Phase 3):**
   - **Risk:** OAuth flow complexity, token refresh, Supabase integration
   - **Mitigation:** Follow Supabase Auth docs, test with multiple devices, handle token expiry

4. **APNs Certificates (Phase 6):**
   - **Risk:** Certificate generation, key management, testing push (requires physical device)
   - **Mitigation:** Follow Apple docs exactly, test with physical device (not simulator), secure key storage

5. **Production Deployment (Phase 7):**
   - **Risk:** Environment config errors, database migrations, DNS setup
   - **Mitigation:** Test in staging environment first, use infrastructure-as-code (Railway configs), rollback plan

---

## Quality Gates (Per Phase)

**Before moving to next phase, verify:**
- [ ] All acceptance criteria met (see phase plan)
- [ ] Manual testing checklist completed (no critical bugs)
- [ ] Code follows DEVELOPMENT_STANDARDS.md (logging, error handling, structure)
- [ ] Git committed (`feat: phase N complete`)
- [ ] Tag created (`phase-N-complete`)
- [ ] User instructions followed (external setup complete)

**If any gate fails:** Fix issues before proceeding (prevents cascading failures)

---

## Success Metrics (Post-MVP)

**Phase 7 Complete → MVP Launch:**

**Technical Metrics:**
- App size: <50MB download
- Launch time: <2s cold start
- Memory usage: <150MB average
- Battery drain: <5% per hour (active use)
- API response time: p95 <500ms
- Uptime: 99.5% (backend)

**Business Metrics:**
- Cost: <$25/month (0-100 users)
- User acquisition: 100 users in first month (beta)
- Retention: 60% weekly active users (month 2)
- Alerts: 80% accuracy (no false positives)

**User Feedback:**
- App Store rating: 4.0+ stars
- NPS: 40+ (promoters > detractors)
- Support tickets: <5% users need help

---

## Post-MVP Roadmap (Phase 8+)

**Deferred Features (Next 6 months):**
1. **Widgets** (iOS Home Screen, Lock Screen)
2. **Live Activities** (Dynamic Island integration)
3. **Multi-language** (i18n, localization)
4. **Analytics** (user behavior, feature usage)
5. **Advanced trip planning** (multi-modal, bike/walk integration)
6. **Accessibility enhancements** (VoiceOver improvements, haptics)
7. **Third-party agencies** (Beyond Sydney, NSW regional)

**When to Start Phase 8:**
- MVP stable (no critical bugs)
- 1K+ active users
- Positive user feedback
- Cost under control (<$25/month)

---

## Phase Plan Documents

Detailed phase plans are in `oracle/phases/`:

```
oracle/phases/
├── PHASE_0_FOUNDATION.md          (~3-4 pages)
├── PHASE_1_STATIC_DATA.md         (~4-5 pages)
├── PHASE_2_REALTIME.md            (~4-5 pages)
├── PHASE_3_USER_FEATURES.md       (~3-4 pages)
├── PHASE_4_TRIP_PLANNING.md       (~3-4 pages)
├── PHASE_5_ALERTS.md              (~4-5 pages)
├── PHASE_6_PUSH_NOTIFICATIONS.md  (~3-4 pages)
└── PHASE_7_PRODUCTION.md          (~3-4 pages)
```

**Each phase plan contains:**
1. Overview & Goals
2. User Setup Instructions (external tasks)
3. Implementation Checklist (AI tasks)
4. Backend Work (APIs, Celery, DB)
5. iOS Work (UI, ViewModels, Repositories)
6. Acceptance Criteria (manual testing)
7. Troubleshooting (common issues)
8. Next Phase Preview

---

## How to Use This Roadmap

**For Solo Developer:**
1. **Start with Phase 0** (read PHASE_0_FOUNDATION.md)
2. **Complete user setup** (external services, accounts)
3. **Work with AI agent** (provide phase plan, iterate)
4. **Manual testing** (verify acceptance criteria)
5. **Move to next phase** (only if current phase passes quality gates)

**For AI Agent:**
1. **Read phase plan** (understand goals, scope)
2. **Review specs** (SYSTEM_OVERVIEW, DATA_ARCHITECTURE, BACKEND_SPECIFICATION, IOS_APP_SPECIFICATION, INTEGRATION_CONTRACTS)
3. **Follow DEVELOPMENT_STANDARDS.md** (coding patterns, structure)
4. **Implement checklist** (backend + iOS in parallel)
5. **Provide acceptance criteria** (cURL commands, simulator steps)

**Iteration:**
- If phase takes >3 weeks → break into sub-phases
- If blocked → consult Oracle (architecture question) or user (external service issue)
- If pattern changes → update DEVELOPMENT_STANDARDS.md

---

## Key Principles (Always Follow)

1. **Vertical slicing:** Complete features end-to-end (backend + iOS)
2. **Defer complexity:** Basic features first, advanced features later
3. **Manual testing:** Every phase must pass acceptance criteria
4. **Standards compliance:** Follow DEVELOPMENT_STANDARDS.md (no exceptions)
5. **Solo-friendly:** Optimize for single developer (no complex workflows)
6. **Cost-conscious:** Maximize free tiers, monitor spending
7. **Simplicity:** If two approaches work, choose simpler one

---

## Next Steps

**Immediate (Start Phase 0):**
1. Read `oracle/phases/PHASE_0_FOUNDATION.md`
2. Complete user setup (Supabase, Railway, NSW API key)
3. Start implementation (FastAPI hello-world)

**Long-term:**
- Complete Phase 0-7 (14-20 weeks)
- Launch MVP (TestFlight → App Store)
- Iterate based on feedback (Phase 8+)

---

**End of IMPLEMENTATION_ROADMAP.md**
