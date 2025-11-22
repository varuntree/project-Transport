# Oracle Consultation: Phase 2.2 - Real-Time Feature Completion

**Session ID:** 1763779627-phase-2-2-rt-feature-completion
**Generated:** 2025-11-22T01:43:47Z
**Project:** Sydney Transit App (iOS + FastAPI Backend)

---

## Task Description

**Context:** Phase 2 (GTFS-RT integration) is partially complete. Following Phase 1.2 pattern (full static data features), now need Phase 2.2 for complete real-time feature set.

**Current State:**
- Backend GTFS-RT poller running (5 modes × 2 feeds every 30s → Redis)
- iOS shows real-time departures with delays, countdown timers, occupancy
- 30s auto-refresh working
- Trip details view shows scheduled times for intermediary stops

**Missing Features (from screenshots + requirements):**

1. **Centralized Real-Time Architecture:**
   - Clean, modular, documented real-time services
   - Clear schema definition for all RT data structures
   - Reusable logic across all features (no duplication)

2. **Real-Time Delay Display (Screenshot #1 shows):**
   - Departure list: Color-coded delay badges (green = early, orange/red = late, purple = estimated)
   - Show actual arrival time vs scheduled time for each departure
   - When user selects departure → Trip details view: show RT delays for ALL intermediary stops
   - Each stop in trip should show: scheduled time, actual time, delay minutes

3. **Service Alerts Integration:**
   - When user selects stop → Show all active alerts for that stop at top
   - GTFS-RT ServiceAlert feed (not currently parsed in poller)
   - Alert types: disruptions, delays, route changes
   - How do alerts work? (need research: matching logic, entity selectors, effect/cause enums)

4. **Other Planned RT Features:**
   - Review original architecture specs for any other RT features planned
   - Identify gaps between current implementation and original vision

**Screenshots Provided:**
- Image #1: TripView-style departure list with color-coded delay badges (green early, orange late, purple estimated), "On time" vs "1m late" badges
- Image #2: Map view showing trip route with bus icon, bottom sheet with intermediary stops showing actual arrival times + delay info

**Requirements:**
- Follow DEVELOPMENT_STANDARDS.md patterns (structlog JSON, Pydantic models, @MainActor ViewModels)
- Maintain offline-first iOS architecture (GRDB fallback)
- Backend graceful degradation (Redis miss → static schedules)
- Solo-dev friendly: clear docs, self-healing, simple patterns

---

## Your Task (Oracle)

Break down Phase 2.2 implementation into **multiple distinct parts**. Provide:

### 1. Analysis

**Current Implementation Assessment:**
- What's working well in current RT implementation?
- What patterns/anti-patterns exist in current code?
- How does current realtime_service.py align with DEVELOPMENT_STANDARDS.md?
- Architecture review: per-mode blob caching, merge logic, graceful degradation

**Missing Pieces:**
- GTFS-RT ServiceAlert feed parsing (not in poller)
- RT delays for intermediary stops in trip details
- Service alert display in iOS
- Color-coded delay badges (early/late/estimated states)
- Centralized RT data models/schemas
- Documentation gaps

**Alignment with Specs:**
- Reference DATA_ARCHITECTURE.md for adaptive polling, blob model, cost safeguards
- Reference BACKEND_SPECIFICATION.md for Celery tasks, rate limiting
- Reference IOS_APP_SPECIFICATION.md for MVVM, repositories, offline-first
- Reference INTEGRATION_CONTRACTS.md for REST envelope, error handling

### 2. Recommendations

**Centralized RT Architecture:**
- How should we structure RT services? (separate service per feed type vs monolithic?)
- Schema definitions: Where to document RT data models? (Pydantic models, iOS structs, shared docs?)
- Reusable components: Extract common merge logic, delay calculation, occupancy mapping

**Service Alerts:**
- GTFS-RT ServiceAlert spec: What fields exist? (header_text, description_text, effect, cause, active_period, informed_entity)
- Matching logic: How to match alerts to stops? (entity selectors: stop_id, route_id, trip_id)
- Display strategy: Top banner in StopDetailsView? Modal sheet? Inline in departures list?
- Backend caching: Redis key strategy for alerts (per-mode blob like TU/VP? or per-stop index?)

**RT Delay Enhancements:**
- Color logic: Green (early >1min), orange (late 1-5min), red (late >5min), purple (estimated/no RT data)?
- Trip intermediary stops: Fetch GTFS-RT trip_update from Redis, merge arrival delays per stop_id
- iOS state management: Update Departure model? New TripStopDelay model?

**Other RT Features:**
- Review original specs: What else was planned? (vehicle positions on map? predictive ETAs? disruption alerts?)
- Prioritize based on MVP scope (what's essential vs nice-to-have?)

### 3. Implementation Plan

**Break into Checkpoints (vertical slices):**

Example structure (you define the actual checkpoints):

**Checkpoint 1: Centralize RT Service Architecture**
- Extract shared logic from realtime_service.py
- Create RealTimeDataModels.md doc (schemas for TU, VP, SA)
- Pydantic models for TripUpdate, VehiclePosition, ServiceAlert
- iOS: Mirror models in Data/Models/RealTime/

**Checkpoint 2: Service Alerts - Backend**
- Add ServiceAlert parsing to gtfs_rt_poller.py
- Redis caching strategy (sa:{mode}:v1 blobs)
- API endpoint: GET /stops/{id}/alerts
- Alert matching logic (informed_entity selectors)

**Checkpoint 3: Service Alerts - iOS**
- ServiceAlert model (Codable)
- AlertRepository protocol + impl
- StopDetailsView: AlertBanner component at top
- Error states: no alerts, failed load

**Checkpoint 4: RT Delays for Trip Intermediary Stops**
- Backend: trips.py endpoint enrichment (merge trip_update delays per stop)
- iOS: TripStop model extended with delay_s, realtime fields
- TripDetailsView: Show actual time + delay badge per stop

**Checkpoint 5: Color-Coded Delay Badges**
- iOS: Departure model color logic (early/late/estimated)
- DepartureRow: Badge color + text updates
- TripStopRow: Badge color + text updates

**Checkpoint 6: Documentation + Testing**
- RealTimeFeatures.md guide (how RT works end-to-end)
- Acceptance criteria validation
- Edge cases testing checklist

**YOU DEFINE THE ACTUAL BREAKDOWN.** This is just an example structure.

### 4. Code Examples

**Concrete snippets for critical parts:**

- ServiceAlert Pydantic model (backend)
- ServiceAlert parsing from protobuf (gtfs_rt_poller.py)
- Alert matching logic (how to filter alerts by stop_id/route_id/trip_id)
- iOS ServiceAlert model (Codable)
- iOS delay color logic (computed property in Departure/TripStop)
- Trip endpoint RT merge (show before/after code)

**Follow DEVELOPMENT_STANDARDS.md:**
- Backend: structlog JSON logging, Celery task decorators, Pydantic models
- iOS: @MainActor ViewModels, protocol-based repositories
- API: Envelope format `{"data": {...}, "meta": {...}}`

### 5. Edge Cases & Risks

**CRITICAL - Identify:**

**ServiceAlert-Specific:**
- Multiple alerts for same stop (how to dedupe? priority ordering?)
- Alert active_period filtering (exclude expired alerts)
- Alerts with no informed_entity (global disruptions - show where?)
- Alert text localization (NSW API provides English only?)

**RT Delay Enhancements:**
- Trip intermediary stops: What if trip_update missing for some stops? (show scheduled time, no delay badge)
- Delays > 60min (formatting: "1h 15m late"?)
- Early arrivals (negative delays - show "+0 min" or "3 min early"?)
- Overnight trips (times >= 86400 secs, next-day arrivals)

**Offline Mode:**
- Alerts not cached in GRDB (API-only) - graceful degradation message
- GRDB fallback for trip details (static times only, no RT delays)

**Performance:**
- ServiceAlert blob size (could be large during major disruptions)
- Redis memory: 10 keys → 15 keys (TU, VP, SA per mode) - still <10MB total?
- API latency: trips endpoint now does Redis lookup + merge - p95 target <200ms?

**Cost:**
- NSW API calls: Adding SA feed → 5 more calls per poll → 14.4K/day → 43.2K/day total (still <60K limit ✅)

**Testing:**
- Manual test: Simulate alert (Redis SET sa:buses:v1 with test JSON)
- Manual test: Delayed trip (verify intermediary stops show delays)
- Manual test: Offline alert fetch (expect error message, no crash)

**Regressions:**
- Departure list performance (color computation on every render? - use computed property cached by SwiftUI)
- Trip details API breaking change (backward compatibility for clients without delay fields)

**Backward Compatibility:**
- API clients expecting old TripDetailsResponse (add optional fields, not required)
- iOS GRDB schema change (if caching alerts - need migration? - NO, API-only for Phase 2.2)

### 6. Trade-offs

**ServiceAlert Caching Strategy:**
- Option A: Per-mode blobs (sa:{mode}:v1) - consistent with TU/VP, simple
- Option B: Per-stop index (sa:stop:{stop_id}) - faster lookup, more keys (100K+ stops)
- Option C: Single global blob (sa:all:v1) - simplest, but merges all modes
- **Recommendation:** Option A (per-mode blobs), why?

**Alert Display:**
- Option A: Top banner in StopDetailsView (always visible)
- Option B: Modal sheet on tap (less intrusive)
- Option C: Inline in departures list (one alert per row)
- **Recommendation:** Option A or B, why?

**RT Delay Color Logic:**
- Option A: Time-based (early: <-1min, on-time: -1 to +1min, late: >1min)
- Option B: Percentage-based (early: <-5%, on-time: -5% to +5%, late: >5%)
- Option C: NSW API provides delay severity (use if available, else fallback to time-based)
- **Recommendation:** Which approach? Trade-offs?

**Trip Intermediary Stops RT Merge:**
- Option A: Backend merges in trips.py endpoint (consistent with departures API)
- Option B: iOS fetches trip + GTFS-RT separately, merges client-side (more flexible, offline-capable)
- **Recommendation:** Option A (consistency), why?

**What you're optimizing for:**
- Solo-dev simplicity > performance
- Graceful degradation > feature completeness
- Consistency with Phase 1/2 patterns > new patterns

**What you're NOT solving (out of scope):**
- Vehicle positions on map (Phase 4: Trip planning with MapKit)
- Predictive ETAs (future enhancement, requires ML models)
- Push notifications for alerts (Phase 6: APNs)
- Alert subscriptions (Phase 5: User favorites + alert matching)

---

## Response Format

Markdown file with sections above. Reference code using:
- `backend/app/services/realtime_service.py:45` (line numbers from context file)
- Inline code blocks with language tags
- Clear headings (use `##` for main sections)

**Tone:** Technical, concise, solo-dev-friendly. No fluff.

---

## Codebase Context

See: `docs/oracle/oracle-context-1763779627-phase-2-2-rt-feature-completion.txt` (~25K tokens)

**Key Files Included:**
- Backend: realtime_service.py, gtfs_rt_poller.py, celery_app.py, stops.py, trip_service.py
- iOS: Departure.swift, DeparturesViewModel.swift, TripDetailsViewModel.swift, Trip.swift
- Specs: (note: original architecture specs not in .phase-logs, recommend Oracle search web for "GTFS-RT ServiceAlert spec" if needed)
- Phase logs: Phase 2 REPORT.md, Phase 2.1 REPORT.md (completion status)

**Current Git Branch:** main (Phase 2.1 complete, Phase 2.2 pending)

**Recent Commits:**
- phase-2-1-checkpoint-5: Alphabetical index navigation
- phase-2-1-checkpoint-4: Route list modality filter
- phase-2-1-checkpoint-3: Trip details view
- phase-2-1-checkpoint-2: Real departures integration
- phase-2-1-checkpoint-1: Stop search icons

---

## Critical Instructions

1. **Break into 4-7 checkpoints** (vertical slices, backend + iOS together)
2. **Prioritize centralization first** (clean architecture foundation before new features)
3. **ServiceAlerts are NEW** (not implemented, need GTFS-RT spec research)
4. **RT delays for trip stops** (trips.py endpoint needs Redis merge, like departures endpoint)
5. **Color-coded badges** (iOS UI enhancement, simple computed property logic)
6. **Documentation critical** (RealTimeDataModels.md, RealTimeFeatures.md for future maintenance)
7. **Follow Phase 1.2 / 2.1 checkpoint pattern** (design docs → implementation → validation → git commit/tag)
8. **Maintain solo-dev principles** (simplicity, self-healing, graceful degradation, clear logs)

---

## Expected Output

**Sections 1-6 above, with:**
- Analysis: ~500 words (current state + gaps)
- Recommendations: ~800 words (architecture decisions + ServiceAlert research)
- Implementation plan: 4-7 checkpoints, each with:
  - Backend tasks (files to modify/create)
  - iOS tasks (files to modify/create)
  - Acceptance criteria (3-5 per checkpoint)
  - Estimated complexity (simple/moderate/complex)
- Code examples: 5-8 snippets (Pydantic models, parsing logic, iOS models, color logic, API responses)
- Edge cases: 10-15 items (grouped by: ServiceAlerts, RT delays, offline, performance, cost, regressions)
- Trade-offs: 3-4 decisions with pros/cons/recommendation

**Total length:** ~3000-4000 words (comprehensive, actionable, no fluff)

---

**Oracle: Provide the breakdown and plan.**
