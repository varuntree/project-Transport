# Phase 2.2 Real-Time Feature Completion Implementation Plan

**Type:** Custom Plan (Ad-hoc)
**Context:** Complete real-time features: ServiceAlerts end-to-end, trip RT stop delays, color-coded delay badges, centralized RT architecture
**Complexity:** complex

---

## Problem Statement

Phase 2.1 complete: GTFS-RT poller running (TU/VP feeds), departures show RT delays/occupancy, 30s auto-refresh. Missing: ServiceAlerts parsing/display, trip intermediary RT delays, color-coded badges, centralized RT layer. Current patterns: per-mode Redis blobs, determine_mode() heuristic, inline TU/VP parsing in realtime_service.py.

---

## Affected Systems

**System: Backend GTFS-RT Poller**
- Current state: Polls TripUpdates + VehiclePositions for 5 modes every 30s. Caches gzipped JSON in Redis (tu:{mode}:v1, vp:{mode}:v1). No ServiceAlerts.
- Gap: Missing ServiceAlerts feed parsing/caching. No Pydantic models for RT data (raw dicts).
- Files affected:
  - backend/app/tasks/gtfs_rt_poller.py
  - backend/app/models/realtime.py (new)

**System: Backend Real-Time Service**
- Current state: realtime_service.py merges static departures + Redis TU/VP delays. Inline parsing, determine_mode() heuristic, graceful degradation.
- Gap: No centralized RT models, duplicated merge logic, no ServiceAlert matching, no reusable delay calculation.
- Files affected:
  - backend/app/services/realtime_service.py
  - backend/app/services/alert_service.py (new)

**System: Backend Trip Details API**
- Current state: trip_service.py returns static arrival_time_secs per stop. Fetches Redis TU for platforms but not per-stop delays.
- Gap: Missing RT delay merge for intermediary stops (arrival_delay from TU stop_time_updates).
- Files affected:
  - backend/app/services/trip_service.py
  - backend/app/api/v1/trips.py

**System: Backend ServiceAlerts API**
- Current state: No alerts endpoint exists.
- Gap: Need GET /stops/{id}/alerts with informed_entity matching, active_period filtering.
- Files affected:
  - backend/app/api/v1/stops.py (new endpoint)
  - backend/app/services/alert_service.py (new)

**System: iOS Departure Models**
- Current state: Departure.swift has delayS, realtime, occupancy_status. Computed: delayText ('+X min'), minutesUntil.
- Gap: No color logic for delay badges (early/late/on-time), no negative delay handling ('X min early').
- Files affected:
  - SydneyTransit/Data/Models/Departure.swift

**System: iOS Trip Models**
- Current state: TripStop has arrivalTimeSecs, platform, wheelchairAccessible. Shows static times only.
- Gap: Missing delayS, realtime, realtimeArrivalTimeSecs fields. No delay badge display in TripStopRow.
- Files affected:
  - SydneyTransit/Data/Models/Trip.swift
  - SydneyTransit/Features/Trips/TripDetailsView.swift

**System: iOS ServiceAlerts**
- Current state: No alert models, repositories, or UI.
- Gap: Need ServiceAlert model, AlertRepository, AlertBanner component for StopDetailsDrawer/DeparturesView.
- Files affected:
  - SydneyTransit/Data/Models/ServiceAlert.swift (new)
  - SydneyTransit/Data/Repositories/AlertRepository.swift (new)
  - SydneyTransit/Features/Map/Components/StopDetailsDrawer.swift

---

## Key Technical Decisions

### 1. Per-mode ServiceAlert blobs (sa:{mode}:v1) vs per-stop index

**Rationale:** Per-mode blobs consistent with TU/VP pattern, simpler poller logic, <10MB total. Per-stop would need 100K+ keys (one per stop). Client filters alerts by informed_entity.

**Reference:** gtfs_rt_poller.py:280-293 (TU/VP blob pattern)

**Critical constraint:** Maintain Redis key count <100 (cost/memory)

---

### 2. Backend merges trip RT delays (not iOS client-side)

**Rationale:** Consistency with departures endpoint (backend merge), single source of truth, offline mode uses static GRDB (no RT).

**Reference:** trip_service.py:108-147 (TU fetch pattern), realtime_service.py:208-282 (TU merge)

**Critical constraint:** API p95 latency <200ms (trip details endpoint)

---

### 3. Pydantic models for all RT data (TripUpdate, VehiclePosition, ServiceAlert)

**Rationale:** Type safety, validation, clear schema docs. Current raw dicts error-prone.

**Reference:** DEVELOPMENT_STANDARDS.md (Pydantic for all API models)

**Critical constraint:** Follow DEVELOPMENT_STANDARDS.md patterns

---

### 4. Color-coded delay badges: time-based thresholds (not percentage)

**Rationale:** User-facing clarity: green (early >1min), gray (on-time ±1min), orange (late 1-5min), red (late >5min). Percentage irrelevant for transit (1min delay on 5min trip = critical, 1min on 60min = minor).

**Reference:** Departure.swift:49-53 (delayText computation)

**Critical constraint:** iOS 16+ Color API, accessibility labels

---

## Implementation Checkpoints

### Checkpoint 1: Centralized RT Models + ServiceAlert Parsing

**Goal:** Pydantic RT models, ServiceAlert poller integration, Redis sa:{mode}:v1 blobs

**Backend Work:**
- Create backend/app/models/realtime.py (TripUpdate, VehiclePosition, ServiceAlert Pydantic models)
- Update gtfs_rt_poller.py: add parse_service_alerts(), cache sa:{mode}:v1 blobs (TTL 90s)
- NSW API: GET /v1/gtfs/alerts/{mode} (5 new endpoints)
- Logging: alert_cached events (mode, count, key)

**iOS Work:**
- Create SydneyTransit/Data/Models/ServiceAlert.swift (Codable)
- Fields: alertId, headerText, descriptionText, effect, cause, activePeriod, informedEntity

**Design Constraints:**
- Follow gtfs_rt_poller.py:280-293 blob caching pattern
- Use google.transit.gtfs_realtime_pb2 for protobuf parsing
- Must achieve Redis key count <100

**Validation:**
```bash
# Redis check
redis-cli GET sa:trains:v1 | gunzip
# Expected: valid JSON array [{id: "...", header_text: "...", ...}]

# Poller logs
docker logs backend-worker | grep alert_cached
# Expected: alert_cached events for 5 modes (trains, buses, metro, ferries, lightrail)
```

**References:**
- Pattern: Redis binary client (decode_responses=False) for gzip blobs (realtime_service.py:34-47)
- Architecture: DATA_ARCHITECTURE.md: GTFS-RT blob model
- GTFS spec: See docs/oracle/oracle-instructions-*.md external_services_research section

---

### Checkpoint 2: ServiceAlerts API + iOS Repository

**Goal:** Backend alerts endpoint, iOS AlertRepository, fetch/display alerts for stop

**Backend Work:**
- Create backend/app/services/alert_service.py: get_alerts_for_stop(stop_id) -> filters sa:{mode}:v1 blobs by informed_entity.stop_id
- Add GET /stops/{stop_id}/alerts endpoint (stops.py)
- Active period filtering (exclude expired alerts)
- API envelope: {data: {alerts: [...], count: N}, meta: {}}

**iOS Work:**
- Create AlertRepository protocol + AlertRepositoryImpl
- DI: Inject into StopDetailsDrawer/DeparturesViewModel
- Fetch alerts on stop load, store in @Published var alerts: [ServiceAlert]

**Design Constraints:**
- Follow stops.py:336-349 API envelope pattern
- Use determine_mode() heuristic (realtime_service.py:50-84) to find relevant modes
- Must achieve API p95 <150ms

**Validation:**
```bash
# Backend API
curl http://localhost:8000/api/v1/stops/200060/alerts
# Expected: {data: {alerts: [...], count: N}, meta: {stop_id: "200060", at: 1732253100}}

# iOS logs (Xcode)
# Load StopDetailsDrawer for stop with alerts
# Expected: APIClient logs show /stops/{id}/alerts request, alerts fetched
```

**References:**
- Pattern: API envelope format {data: {...}, meta: {pagination: ...}} (INTEGRATION_CONTRACTS.md)
- Architecture: BACKEND_SPECIFICATION.md: REST endpoints
- iOS: IOS_APP_SPECIFICATION.md: MVVM + protocol repositories

---

### Checkpoint 3: ServiceAlerts UI (iOS AlertBanner)

**Goal:** Display alerts at top of StopDetailsDrawer, error states, accessibility

**Backend Work:**
N/A

**iOS Work:**
- Create AlertBanner component (VStack with alert icon, header, description, effect label)
- StopDetailsDrawer: Show alerts above departures list if alerts.count > 0
- Error states: No alerts (hide banner), failed fetch (show error message)
- Accessibility: VoiceOver labels for alert severity

**Design Constraints:**
- Follow .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-alert-banner-design.md
- Use SF Symbols: exclamationmark.triangle.fill (NO_SERVICE), clock.fill (DELAY)
- Colors: red (NO_SERVICE), orange (REDUCED_SERVICE), yellow (DELAY)
- Must achieve VoiceOver semantic labels ("Service disruption: Buses not stopping at Central")

**Validation:**
```bash
# Manual test: Redis SET test alert
redis-cli SET sa:trains:v1 <gzipped_json_with_test_alert>

# Xcode: Load train stop -> verify banner appears
# Test offline mode: Airplane mode -> expect no alerts, no crash
```

**References:**
- iOS Research: .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-alert-banner-design.md
- iOS Research: .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-voiceover-accessibility.md
- Pattern: iOS @MainActor ViewModels, @Published state (IOS_APP_SPECIFICATION.md)

---

### Checkpoint 4: Trip RT Delays - Backend Merge

**Goal:** trip_service.py merges TU stop_time_updates delays into arrival_time_secs per stop

**Backend Work:**
- Update trip_service.py:149-188: Extract arrival_delay from TU stop_time_updates[stop_id]
- Compute realtime_arrival_secs = arrival_time_secs + delay_s
- Add delay_s, realtime fields to stop dict (backward-compatible optional fields)
- Logging: trip_realtime_delays_merged (trip_id, stops_with_delays_count)

**iOS Work:**
- Update Trip.swift: TripStop add delayS, realtime, realtimeArrivalTimeSecs (optional Int?)
- CodingKeys: delay_s, realtime, realtime_arrival_time_secs

**Design Constraints:**
- Follow realtime_service.py:208-282 TU merge pattern
- Use determine_mode() + index_trip_updates_by_trip() pattern
- Must achieve API p95 <200ms, backward-compatible (old iOS clients ignore optional fields)

**Validation:**
```bash
# Backend API
curl http://localhost:8000/api/v1/trips/{trip_id}
# Expected: stops array has delay_s, realtime_arrival_time_secs fields

# iOS decoding test (Xcode)
# Load trip with delays -> verify TripStop.delayS decoded
# Load trip without delays -> verify nil delayS, no crash
```

**References:**
- Pattern: Backend merges trip RT delays (trip_service.py:108-147)
- Pattern: Graceful degradation (realtime_service.py:278-282 error handling)
- Architecture: INTEGRATION_CONTRACTS.md: REST contracts

---

### Checkpoint 5: Trip RT Delays - iOS UI

**Goal:** TripDetailsView shows RT arrival times + delay badges per stop

**Backend Work:**
N/A

**iOS Work:**
- TripStopRow: Show realtimeArrivalTimeSecs if delayS != 0, else scheduled
- Delay badge: Text('+\(delayS/60) min') in orange/red (late) or green (early)
- Label: 'Actual' vs 'Scheduled' based on realtime flag
- Handle negative delays: 'X min early' (green badge)

**Design Constraints:**
- Follow .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-negative-delay-ux.md
- Display negative delays as "X min early" (abs value + suffix), not "-X min"
- Must achieve accessibility labels ("3 minutes early", not "green badge")

**Validation:**
```bash
# Manual test (Xcode): Load trip with delayed stops
# Redis: Inject TU blob with delays for trip
# Expected: TripStopRow shows actual times, delay badges (orange/red for late, green for early)

# Test static trip (no TU): Shows scheduled times only, no badges
```

**References:**
- iOS Research: .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-negative-delay-ux.md
- iOS Research: .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-voiceover-accessibility.md
- Pattern: iOS @MainActor ViewModels (IOS_APP_SPECIFICATION.md)

---

### Checkpoint 6: Color-Coded Delay Badges (Departures + Trips)

**Goal:** Unified delay color logic, badge colors in DepartureRow + TripStopRow

**Backend Work:**
N/A

**iOS Work:**
- Departure.swift: Add delayColor computed property (Color) -> green (delayS < -60), gray (|delayS| <= 60), orange (60 < delayS <= 300), red (delayS > 300)
- DepartureRow: Use delayColor for badge background, update delayText for early ('-X min')
- TripStop.swift: Mirror delayColor logic
- TripStopRow: Apply color to delay badge

**Design Constraints:**
- Follow .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-swiftui-color-ios16.md
- Use Color.red/.orange/.green (iOS 13+ available, auto-adapt Dark Mode)
- Thresholds: green (<-60s), gray (±60s), orange (60-300s), red (>300s)
- Must achieve VoiceOver semantic labels ("3 minutes early", "5 minutes late")

**Validation:**
```bash
# Xcode preview: DepartureRow with test delays
# delayS=-120 -> green badge "2 min early"
# delayS=0 -> gray badge "On time"
# delayS=180 -> orange badge "3 min late"
# delayS=600 -> red badge "10 min late"

# Accessibility: VoiceOver reads semantic labels, not color names
```

**References:**
- iOS Research: .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-swiftui-color-ios16.md
- iOS Research: .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-negative-delay-ux.md
- iOS Research: .workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-voiceover-accessibility.md
- Pattern: Departure.swift:49-53 delayText computation

---

## Acceptance Criteria

- [ ] ServiceAlerts: Load stop -> alerts banner shows active disruptions (if any) with header/description/effect
- [ ] ServiceAlerts: Offline mode -> no alerts fetch, no error crash, graceful message
- [ ] Trip RT delays: Load delayed trip -> intermediary stops show actual arrival times + delay badges (orange/red for late, green for early)
- [ ] Trip RT delays: Load static trip (no RT data) -> shows scheduled times only, no delay badges
- [ ] Delay badges: Departures list shows color-coded badges: green (<-1min), gray (±1min), orange (1-5min late), red (>5min late)
- [ ] Delay badges: Negative delays display 'X min early' (not '+0 min')
- [ ] API: GET /stops/{id}/alerts returns active alerts filtered by stop_id in informed_entity
- [ ] Poller: Celery logs show alert_cached events for 5 modes every 30s, Redis sa:{mode}:v1 keys exist
- [ ] Performance: Trip details API p95 <200ms with RT merge, departures API unchanged (<150ms)
- [ ] Backward compatibility: Old iOS clients (pre-Phase 2.2) decode trip responses (optional delay fields)

---

## User Blockers (Complete Before Implementation)

None

---

## Research Notes

**iOS Research Completed:**
- VoiceOver Accessibility Labels (.workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-voiceover-accessibility.md)
- Alert Banner Design (.workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-alert-banner-design.md)
- Negative Delay Display UX (.workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-negative-delay-ux.md)
- SwiftUI Color iOS 16 (.workflow-logs/custom/phase-2-2-rt-feature-completion/ios-research-swiftui-color-ios16.md)

**On-Demand Research (During Implementation):**
- GTFS-RT ServiceAlert spec (informed_entity, effect, cause enums)
- NSW API /v1/gtfs/alerts/{mode} endpoints (protobuf format)
- Alert active_period format (Unix timestamps)

Agent will research these when implementing Checkpoint 1-2. Confidence check: If <80% confident, agent MUST research.

---

## Related Phases

**Phase 2:** extends (adds ServiceAlerts, trip RT delays, color badges to existing GTFS-RT foundation)

**Phase 2.1:** builds on (trip details view, departures RT polling already working)

---

## Exploration Report

Attached: `.workflow-logs/custom/phase-2-2-rt-feature-completion/exploration-report.json`

---

**Plan Created:** 2025-11-22
**Estimated Duration:** 4-6 days (6 checkpoints, ServiceAlerts research, iOS color logic, testing)
