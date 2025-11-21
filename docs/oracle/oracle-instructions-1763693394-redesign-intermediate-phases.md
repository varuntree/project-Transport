# Oracle Consultation: Redesign Intermediate Phases Between Phase 1 and Phase 2

**Session ID:** 1763693394-redesign-intermediate-phases
**Generated:** 2025-11-21T05:23:14Z
**Project:** Sydney Transit App (iOS + FastAPI Backend)

---

## Task Description

The user has completed Phase 0, Phase 1 (static data), and Phase 2 (real-time) of a 7-phase implementation roadmap, but discovered critical flaws in the phase structure:

**Problem:**
- Phase 1 delivered GTFS parsing + basic API, but NOT complete static data features (no comprehensive search UI, no map drawer)
- Phase 2 added real-time polling + departures API, but static data features still incomplete
- Current implementation has bugs: missing departures for non-train stops, modal coverage gaps (bus/ferry/light rail)
- Roadmap jumped to real-time integration before validating static data features work correctly

**User's Request:**
Design intermediate phases (Phase 1.5, 1.6, etc.) to:
1. **First**: Fix existing bugs (missing departures, modal coverage - issue-144)
2. **Second**: Complete full static data feature set (search → stop list all modalities → departures → map drawer with stop highlights)
3. **Third**: Validate static data features work bug-free across all modalities BEFORE integrating real-time
4. **Fourth**: Only then integrate real-time on top of working static foundation
5. **Fifth**: Apply same vertical slicing rigor to redesign Phases 3-7

**Core User Flows to Implement (static data):**
- User opens app → Search icon → Types "bus" → All bus stops shown (multi-modal search)
- Tap stop → Show stop details + departures list (static schedules)
- Tap "View on Map" → Bottom drawer shows map with stop markers
- Tap stop marker on map → Highlight selected stop, show quick departures
- All flows work offline (GRDB bundled data), no real-time yet

**Key Quote (user):**
"Only after we built the complete features that are necessary, once we're done with static data, only then we already built real-time foundations, but we have not integrated that. I don't want to because only after we're done with static data and complete features that is relevant to static data, then we can integrate on top logically."

---

## Project Context

**Tech Stack:**
- Backend: FastAPI + Celery (3 queues), Supabase PostgreSQL, Redis (GTFS-RT cache)
- iOS: Swift/SwiftUI, GRDB (15-20MB bundled GTFS), Supabase Auth
- Data: NSW Transport GTFS (227MB static, GTFS-RT 30s polling)

**Current Status:**
- Implementation Phase: Phase 2.1 (fixes) completed, main branch clean
- Recent Changes:
  - 34ef853 oracle and cleaning
  - e90ddcc Implemented the drawer
  - 171d1ac Add departures scroll fixes and GTFS coverage documentation
  - 71e6062 fix: departures page critical bugs - continuous reload, 0 minute display, sentinel trigger

**Key Constraints:**
- Solo dev, budget $25/mo MVP (0-1K users)
- App size <50MB, offline-first
- NSW API: 5 req/s limit, 60K calls/day
- Stack fixed (no new services)

**Architecture Docs:** `docs/specs/` (SYSTEM_OVERVIEW, DATA_ARCHITECTURE, BACKEND_SPECIFICATION, IOS_APP_SPECIFICATION, INTEGRATION_CONTRACTS, DEVELOPMENT_STANDARDS)

**Roadmap Structure (current 7 phases):**
- Phase 0: Foundation (hello-world, local dev)
- Phase 1: Static Data (GTFS parser, iOS SQLite, basic API, search) ← **INCOMPLETE**
- Phase 2: Real-Time (Celery poller, Redis cache, live departures API) ← **DONE** but premature
- Phase 3: User features (auth, favorites, sync)
- Phase 4: Trip planning
- Phase 5: Alerts
- Phase 6: APNs
- Phase 7: Production

**Problem with Current Roadmap:**
- Phase 1 deliverables said "basic UI" but didn't define "complete static data features"
- Phase 2 jumped to real-time before static features validated
- No intermediate phases to complete static data flows (map integration, multi-modal search UI comprehensive)
- Bugs discovered after Phase 2: missing departures (issue-144), modal coverage gaps

---

## Your Task (Oracle)

Given the task description and codebase context in `oracle-context-1763693394-redesign-intermediate-phases.txt`, provide:

### 1. Root Cause Analysis

**What went wrong with the current phase structure?**
- Why did Phase 1 feel "complete" when it wasn't (acceptance criteria gaps)?
- What static data features were missed that should have been in Phase 1?
- Why wasn't the map drawer implemented before real-time?
- How did bugs (missing departures, modal coverage) slip through Phase 1-2 testing?

**Patterns in the specs:**
- Reference specific sections from IMPLEMENTATION_ROADMAP.md, PHASE_1_STATIC_DATA.md, PHASE_2_REALTIME.md
- Identify vague acceptance criteria (e.g., "basic UI" vs. "complete user flows")
- Spot where vertical slicing broke down (did backend first, then iOS, instead of end-to-end features)

### 2. Immediate Fixes (Phase 2.2 - Bug Squashing)

**Issue-144 Resolution:**
- Diagnose why departures missing for stops 29443/29444 and other non-train stops
- Is it stop_id mapping (dict_stop table empty/incomplete)?
- Is it modal heuristic (determine_mode() in realtime_service.py)?
- Is it data pipeline (GTFS ingestion filtering out bus/ferry routes)?
- Is it iOS logic (primaryRouteType returning nil for non-train stops)?

**Recommended fix approach:**
- Step-by-step diagnostic (check dict_stop row count, verify Supabase routes table has all 4687 routes, test API manually)
- Which files to modify (`backend/app/services/realtime_service.py:line`, `SydneyTransit/Data/Models/Stop.swift:line`)
- Concrete code snippets (SQL queries, Swift property logic)
- Testing strategy (E2E test script for multi-modal search + departures)

**Acceptance criteria for Phase 2.2:**
- [ ] All 4687 routes visible in database (verify route_type distribution: {2: 99, 4: 11, 401: 1, 700: 679, 712: 3866, 714: 30, 900: 1})
- [ ] dict_stop mapping table populated (30K rows, sid ↔ stop_id)
- [ ] Search "bus" returns bus stops, "ferry" returns ferry stops
- [ ] Departures API works for stop_id 29443, 29444 (returns >0 static schedules)
- [ ] iOS primaryRouteType correctly identifies bus/ferry/light rail (not nil)

### 3. Static Data Feature Completion (Phase 1.5 - Complete Offline Flows)

**Goal:** Implement full static data feature set BEFORE re-integrating real-time

**Missing Features (identify from SYSTEM_OVERVIEW.md P0 feature list):**
1. Map integration (MapKit with stop pins, bottom drawer)
2. Comprehensive search UI (filter by modality, nearby stops with distance)
3. Stop details page (routes serving stop, schedules, favorite button)
4. Route details page (stop sequence, service pattern, map polyline)
5. Offline trip planning (static schedules only, no real-time overlay)

**Prioritized feature list:**
- **P0 (must have):** Map drawer with stop markers, tap to highlight, show quick departures
- **P0 (must have):** Multi-modal search (segmented control: All/Train/Bus/Ferry/Light Rail/Metro)
- **P1 (should have):** Nearby stops (CoreLocation + distance sort)
- **P1 (should have):** Route details (stop sequence, service pattern)
- **P2 (nice to have):** Offline trip planning (defer to Phase 4 if complex)

**Implementation breakdown:**
- Backend work needed: New APIs? (e.g., `/stops/nearby?lat=...&lon=...&radius=500`)
- iOS work: New screens (MapView with annotations, segmented search, route details)
- Data model changes: Any new fields in Stop/Route/Trip models?
- Offline validation: All features work without network (GRDB queries only)

**Vertical slicing approach:**
1. Feature A (Map drawer): Backend `/stops/{id}` returns coordinates → iOS MapView + bottom drawer → E2E test
2. Feature B (Multi-modal search): iOS segmented control → filter FTS5 query by route_type → E2E test
3. Feature C (Route details): Backend `/routes/{id}/stops` → iOS route detail page → E2E test

**Acceptance criteria for Phase 1.5:**
- [ ] Map view shows all stops as pins (color-coded by modality)
- [ ] Tap pin → bottom drawer slides up with stop name + next 3 static departures
- [ ] Search has segmented control (All, Train, Bus, Ferry, Light Rail, Metro)
- [ ] Filter works correctly (Bus shows 679 routes, Ferry shows 11 routes, etc.)
- [ ] Nearby stops shows 20 closest stops sorted by distance (<500m radius)
- [ ] All features work offline (airplane mode test)

### 4. Real-Time Integration (Phase 2.3 - Overlay RT on Static Foundation)

**Goal:** Re-integrate real-time data on top of validated static features

**Current state:**
- Real-time poller works (Celery task, Redis cache)
- Departures API merges static + RT correctly (when stop_id valid)
- iOS auto-refresh implemented

**What to change:**
- Remove real-time from current Phase 2 scope (revert to static-only departures)
- Create Phase 2.3 after Phase 1.5 complete: Add real-time overlay to working static UI
- Test real-time incremental: First trains only → then buses → then ferries/light rail
- Validate graceful degradation: Real-time fails → falls back to static schedules

**Phased real-time rollout:**
1. Phase 2.3a: Real-time for trains only (simplest, most reliable)
2. Phase 2.3b: Real-time for buses (more complex, frequent delays)
3. Phase 2.3c: Real-time for ferries/light rail (complete coverage)

**Acceptance criteria for Phase 2.3:**
- [ ] Departures show real-time delays for trains (delay_s >0, "Late X min" badge)
- [ ] Auto-refresh works (30s timer, no race conditions)
- [ ] Graceful degradation: Redis cache miss → shows static schedules
- [ ] Map shows live vehicle positions (trains on map, updated every 30s)
- [ ] All modalities have real-time coverage (buses, ferries, light rail tested)

### 5. Refined Phase Structure (Phases 3-7)

**Apply lessons learned to later phases:**

**Phase 3 (User features):**
- Break into sub-phases: 3.1 (Apple Sign-In only), 3.2 (Favorites CRUD), 3.3 (Sync across devices)
- Acceptance criteria: Define exact user flows (tap "Sign in with Apple" → token stored → favorites appear)
- Vertical slicing: Auth backend + iOS flow together, then favorites API + iOS UI together

**Phase 4 (Trip planning):**
- Sub-phases: 4.1 (Backend routing algorithm), 4.2 (iOS trip planner UI), 4.3 (Real-time overlay on trips)
- Acceptance criteria: "Central Station → Bondi Junction" returns 3 itineraries, map shows route

**Phase 5 (Alerts):**
- Sub-phases: 5.1 (Alerts API + in-app banners), 5.2 (Alert matching logic), 5.3 (Subscription management)
- Decouple from Phase 6 (APNs) - in-app alerts first, push later

**Phase 6 (APNs):**
- Sub-phases: 6.1 (APNs worker + device registration), 6.2 (Deduplication logic), 6.3 (Quiet hours + severity filter)
- Acceptance criteria: Push sent within 5s, no duplicate alerts, quiet hours respected

**Phase 7 (Production):**
- Sub-phases: 7.1 (Deploy to Railway), 7.2 (Monitoring + alerts), 7.3 (TestFlight + App Store)

**General principles:**
- Each sub-phase has clear acceptance criteria (measurable, testable)
- Vertical slicing: Backend + iOS + E2E test together (not layers)
- Quality gates: Manual testing checklist before moving to next sub-phase
- No phase >3 weeks (break down further if needed)

### 6. Implementation Roadmap (Revised)

**Concrete phase plan:**

| Phase | Duration | Goals | Deliverables | Acceptance Criteria |
|-------|----------|-------|--------------|---------------------|
| **2.2** (Bug Fixes) | 1 week | Fix issue-144, modal coverage | dict_stop populated, departures API works for all stops | Search "bus" returns bus stops, departures show for stop 29444 |
| **1.5** (Static Features) | 2-3 weeks | Complete offline flows (map, multi-modal search, route details) | MapView + drawer, segmented search, route detail page | All features work offline, map shows 30K stops |
| **2.3a** (RT Trains) | 1 week | Real-time for trains only | Live delays for trains, auto-refresh | Trains show "Late 5 min" badge, map shows live train positions |
| **2.3b** (RT Buses) | 1 week | Real-time for buses | Live delays for buses | Buses show real-time delays |
| **2.3c** (RT Complete) | 1 week | Real-time for ferries/light rail | Complete RT coverage | All modalities have real-time data |
| **3.1** (Auth) | 1-2 weeks | Apple Sign-In | Auth backend + iOS flow | Sign in works, token stored securely |
| **3.2** (Favorites) | 1 week | Favorites CRUD | Favorites API + iOS UI | Add/remove favorites, sync across devices |
| **4.1** (Trip Backend) | 1-2 weeks | Trip planning algorithm | `/trips/plan` API | "Central → Bondi" returns 3 itineraries |
| **4.2** (Trip UI) | 1 week | Trip planner UI | iOS trip planner screen | User can plan trip A→B |
| ... (continue for Phases 5-7) |

**Total revised timeline:** 18-22 weeks (vs original 14-20 weeks) - extra 4-6 weeks for intermediate phases, but higher confidence

### 7. Edge Cases & Risks

**CRITICAL:** Identify:

**Edge Cases:**
- What if dict_stop mapping incomplete? (Some stops have no stop_id → departures fail)
- What if GTFS ingestion filters out regional bus routes? (3866 school bus routes missing)
- What if primaryRouteType query times out? (30K stops × DB query on each access)
- What if user searches with special chars ("St. Peter's")? (FTS5 sanitization)
- What if map has 30K pins? (Performance issue, need clustering)

**Potential Regressions:**
- Fixing dict_stop mapping breaks existing iOS code (sid hardcoded in some views)?
- Adding real-time back breaks static-only tests?
- Map drawer conflicts with existing navigation patterns?

**Blast Radius:**
- Which features affected by dict_stop changes? (Departures, trip details, favorites)
- Which features affected by route_type enum expansion? (Search filter, route list, map pins)
- Backward compatibility: Can old iOS app (Phase 2.1 build) still call new APIs?

**Cost Implications:**
- Map rendering (MapKit) - free, no API calls
- Search (FTS5 local) - free, offline
- Nearby stops (CoreLocation) - free
- No new API usage, stays under $25/mo budget

**Testing Strategy:**
- E2E test for each sub-phase (e.g., test_map_drawer.md, test_multi_modal_search.md)
- Regression test suite (run all Phase 1-2.3 tests before Phase 3)
- Performance test (map with 30K pins, search with 100K trips)

### 8. Trade-Offs

**Pros/Cons of Intermediate Phases:**

**Pros:**
- Higher confidence (validate static features before real-time)
- Easier debugging (isolate static vs RT issues)
- Better user experience (polished static features > buggy real-time)
- Modular rollout (real-time per modality, not all-or-nothing)

**Cons:**
- Longer timeline (18-22 weeks vs 14-20 weeks)
- More planning overhead (sub-phase acceptance criteria, E2E tests)
- Delayed real-time (users see static schedules for 3-4 weeks longer)

**What You're Optimizing For:**
- Correctness > speed (fix bugs before adding features)
- Simplicity > features (complete static flows before real-time)
- Solo dev sustainability (clear quality gates, no cascading failures)

**What You're NOT Solving (Out of Scope):**
- Multi-city expansion (still Phase 8+)
- AI/voice features (Phase 3+ in future vision)
- Web dashboard (2026 roadmap)

---

## Response Format

Markdown file with sections above. Reference code using:
- `backend/app/services/realtime_service.py:45` (line numbers from context file)
- Inline code blocks with language tags
- Clear headings (use `##` for main sections)

**Tone:** Technical, concise, solo-dev-friendly. Prioritize actionable next steps over theory.

**Length:** Comprehensive but focused - aim for 800-1200 lines (detailed enough for solo dev to implement without further consultation)

---

## Codebase Context

See: `docs/oracle/oracle-context-1763693394-redesign-intermediate-phases.txt` (~28000 tokens)

**Key files in context:**
- IMPLEMENTATION_ROADMAP.md (current 7-phase structure)
- PHASE_1_STATIC_DATA.md, PHASE_2_REALTIME.md (phase specs)
- SYSTEM_OVERVIEW.md (project vision, constraints)
- issue-144 (missing modalities bug report)
- phase-2-1-fixes-plan.md (recent bug fixes)
- DeparturesView.swift, SearchView.swift, Stop.swift (iOS implementation)
- realtime_service.py (backend departures logic)

**What to focus on:**
1. Root cause why Phase 1 didn't include map drawer / multi-modal search UI
2. Concrete steps to fix issue-144 (missing departures, modal coverage)
3. Phase 1.5 feature breakdown (map drawer, segmented search, route details)
4. Phase 2.3 real-time integration strategy (incremental per modality)
5. Revised roadmap with sub-phases, acceptance criteria, timeline

**Expected deliverables from Oracle:**
- Root cause analysis (300-400 lines)
- Phase 2.2 bug fix plan (200-300 lines)
- Phase 1.5 feature spec (400-500 lines)
- Phase 2.3 real-time integration plan (200-300 lines)
- Revised phase structure template for Phases 3-7 (200-300 lines)
- Total: 1300-1800 lines of actionable guidance

---

**Document Status:** Ready for Oracle consultation
**Next Step:** Copy oracle-context + oracle-instructions to external Oracle model (ChatGPT, Claude Web, etc.)
**Expected Turnaround:** 24-48 hours (external Oracle review)

---

**End of Oracle Instructions**
