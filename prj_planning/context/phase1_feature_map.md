# Phase 1 Feature Map - Sydney MVP
**Target:** Best transit app in Sydney - TripView reliability + Transit features + iOS polish

---

## 🎯 Strategic Focus

**Geographic:** Sydney/NSW only
**Platform:** iOS 16+, Swift/SwiftUI
**Backend:** FastAPI (Python), PostgreSQL, Redis, Next.js (static) for marketing
**Data:** NSW GTFS (227MB) + NSW Trip Planner API
**App Size:** <50MB initial download, optional offline data

---

## Core Features (P0 - Must Have for Launch)

### 1. Real-Time Departures
**What:** Live countdown timers for all Sydney transit modes
- Sydney Trains, Metro, Buses, Ferries, Light Rail
- Next 3-5 departures per stop/platform
- Real-time delays/cancellations (NSW GTFS-RT, 10-15s updates)
- Accessibility info (wheelchair accessible vehicles)

**UI:**
- Clean list view with countdown
- Color-coded by mode (train/bus/ferry)
- Tap for trip details

**Data Source:** NSW GTFS-RT vehicle positions + trip updates

---

### 2. Stop/Station Search & Nearby
**What:** Find stops quickly by name or location
- Search by stop name/number
- "Nearby" view showing closest stops (geofenced radius)
- Map view with stop pins

**Native:**
- CoreLocation for user position
- MapKit for map display

**Data Source:** NSW GTFS stops.txt (local SQLite)

---

### 3. Service Alerts
**What:** Real-time disruption notifications
- System-wide alerts (track work, cancellations)
- Mode-specific filtering (show only trains)
- Push notifications for favorites

**UI:**
- Alert banner at top
- Dedicated alerts tab
- Affected lines highlighted

**Data Source:** NSW GTFS alerts feed

---

### 4. Favorites & Quick Access
**What:** Save frequently used stops/routes
- Tap to favorite any stop
- Home screen shows favorited stops with next departures
- Swipe to reorder

**Sync:** CloudKit for cross-device favorites

---

### 5. Trip Planning
**What:** Multi-modal journey planning door-to-door
- Enter origin + destination (address, stop, landmark)
- Multiple route options (fastest, least walking, accessible)
- Walk + transit combinations
- Real-time-aware (accounts for delays)

**Data Source:** NSW Trip Planner API (60K free calls/day)
**Fallback:** Local GTFS routing if API unavailable

---

### 6. Maps & Route Visualization
**What:** See routes on map
- Live vehicle positions (buses, trains, ferries)
- Route shapes visualization
- Stop locations

**Native:** MapKit for base maps

---

### 7. Push Notifications
**What:** Proactive alerts
- Service disruptions affecting favorites
- Departure reminders (optional)
- Time-sensitive notifications (iOS priority)

**Native:** APNs

---

## Enhanced Features (P1 - Post-Launch)

### 8. Widgets
- Home screen widgets (small/medium/large)
- Lock screen widgets (iOS 16+)
- Next departure for favorite stop

### 9. Live Activities
- Trip tracking with countdown (iOS 16.1+)
- Dynamic Island integration (iPhone 14 Pro+)
- "2 stops away" notifications

### 10. Saved Trips
- Save common journeys (home → work)
- One-tap to view next departure times

### 11. GO Mode (Basic)
- Step-by-step guidance during journey
- Notifications: "Board now", "2 stops away", "Next stop"
- GPS-based position tracking

### 12. Weather Integration
- Display current weather
- Rain warnings for walking portions

**Native:** WeatherKit (iOS 16+)

### 13. Offline Schedules
- Optional: Download full NSW GTFS (~300MB optimized SQLite)
- Works without internet (schedules only, no real-time)
- WiFi background download via Background Assets

---

## Feature Comparison vs Competitors

| Feature | Our App | TripView | Transit | NextThere |
|---------|---------|----------|---------|-----------|
| Real-time departures | ✅ All modes | ✅ All modes | ✅ All modes | ✅ Limited |
| Service alerts | ✅ Push + in-app | ✅ In-app only | ✅ Push + in-app | ❌ |
| Trip planning | ✅ Multi-modal | ✅ Basic | ✅ Advanced | ❌ |
| Offline mode | 🟡 Optional | ✅ Full | ✅ Partial | ❌ |
| Live Activities | ✅ iOS 16+ | ❌ | ✅ | ❌ |
| Widgets | ✅ All types | ✅ Basic | ✅ Advanced | ✅ Basic |
| GO mode | 🟡 P1 | ❌ | ✅ | ❌ |
| App size | <50MB | 5.44MB | 196MB | 119MB |
| Free tier | Generous | Limited | Restricted | 3 stops only |

---

## Free vs Premium Tiers

### Free (Generous)
✅ Real-time departures (unlimited stops)
✅ Service alerts
✅ Trip planning (unlimited)
✅ Maps & live vehicles
✅ Favorites (unlimited)
✅ Basic widgets
✅ Push notifications

### Premium ($4.99/month or $39.99/year)
✨ Live Activities & Dynamic Island
✨ GO mode (step-by-step guidance)
✨ Offline mode (full GTFS download)
✨ Weather-aware suggestions
✨ Advanced widgets (lock screen, interactive)
✨ Trip history & analytics
✨ Priority support

**Philosophy:** Don't paywall core features (learn from Transit's mistake)

---

## Technical Implementation

### iOS App Architecture
```
/SenseTransit (iOS App)
  /Core
    /Models       # GTFS data models (Stop, Route, Trip)
    /Services     # API clients (NSW API, GTFS-RT)
    /Database     # GRDB/SQLite layer
  /Features
    /Departures   # Real-time departure views
    /Search       # Stop search & nearby
    /TripPlanner  # Journey planning
    /Favorites    # Saved stops
    /Alerts       # Service alerts
    /Maps         # MapKit integration
  /Shared
    /UI           # Reusable components
    /Extensions   # Swift extensions
    /Utils        # Helpers
  /Widgets        # WidgetKit extensions
  /LiveActivities # ActivityKit
```

### Backend Architecture (FastAPI)
```
/app
  /api
    /gtfs         # GTFS data sync & parsing endpoints
    /realtime     # GTFS-RT proxy/cache endpoints
    /trips        # Trip planning (NSW API wrapper)
    /alerts       # Alert aggregation endpoints
    /users        # Auth (Apple Sign-In)
    /favorites    # User data sync (if not using CloudKit)
    /push         # APNs notification delivery
  /workers
    /gtfs_poller  # Background job: GTFS-RT polling (Celery)
    /alert_engine # Background job: Alert matching
    /apns_worker  # Background job: Push notification delivery
  /models         # SQLAlchemy database models
  /schemas        # Pydantic request/response schemas
  /services       # Business logic layer
  /utils          # Helpers, Redis abstractions
```

### Data Flow
1. **Static GTFS:** Daily sync from NSW → PostgreSQL → SQLite export for iOS
2. **Real-time:** iOS polls FastAPI → FastAPI caches NSW GTFS-RT (Redis, 15s TTL via Celery worker)
3. **Trip planning:** iOS → FastAPI → NSW Trip Planner API → Cache → iOS
4. **Favorites:** CloudKit sync (no backend needed)

---

## App Size Optimization Strategy

**Target:** <50MB initial download

### How:
1. **No bundled GTFS data** - download on-demand
2. **Minimal dependencies** (GRDB, SwiftDate, SwiftProtobuf only)
3. **Asset catalog optimization** - compress images
4. **On-demand resources** - download rarely used assets
5. **Aggressive code stripping** - remove unused symbols

**Optional Offline Data:**
- User opts in to download NSW GTFS
- Background download via WiFi (Background Assets framework)
- ~300MB optimized SQLite database
- "Low Storage Mode" - skip shapes, reduce indexes (~40% savings)

---

## Phase 1 Timeline Estimate

| Milestone | Duration | Deliverable |
|-----------|----------|-------------|
| Architecture setup | 1-2 weeks | iOS project structure, FastAPI scaffold, Celery workers |
| GTFS data pipeline | 2-3 weeks | Daily NSW GTFS sync, SQLite generation |
| Real-time departures | 2 weeks | NSW GTFS-RT integration, departure UI |
| Stop search & nearby | 1 week | Search, geolocation, map view |
| Trip planning | 2-3 weeks | NSW API integration, multi-route display |
| Service alerts | 1 week | Alert feed parsing, UI |
| Favorites | 1 week | CloudKit sync, UI |
| Push notifications | 1 week | APNs setup, alert routing |
| Basic widgets | 1-2 weeks | Home screen widgets |
| Testing & polish | 2-3 weeks | Bug fixes, performance, UX refinement |
| **Total** | **14-18 weeks** | **Phase 1 MVP launch** |

Post-launch (P1 features): 6-8 additional weeks

---

## Success Metrics

**Phase 1 Goals (6 months):**
- 5,000 active users
- 4.5+ App Store rating
- <1% crash rate
- <100ms departure query time
- 95% uptime for real-time data

**User Satisfaction:**
- Match TripView reliability (users trust it)
- Exceed Transit UX (modern, intuitive)
- Beat NextThere simplicity (one tap to info)

---

## Risk Mitigation

### Risk: NSW API rate limits (5 req/s)
**Mitigation:** Aggressive Redis caching (15s TTL), batch requests

### Risk: Large GTFS download (227MB)
**Mitigation:** Optional offline mode, WiFi-only, background download

### Risk: Real-time data outages
**Mitigation:** Graceful degradation to schedules, clear status indicator

### Risk: Trip Planner API downtime
**Mitigation:** Local RAPTOR routing fallback (implement Phase 1.5)

### Risk: App size bloat
**Mitigation:** Strict dependency review, code size audits, asset optimization

---

## Next Steps

1. **Finalize MVP scope** - Lock P0 features, cut anything non-essential
2. **Design technical architecture spec** - Detailed system design doc
3. **Create development roadmap** - Sprint planning, milestones
4. **Design core UI flows** - Wireframes for key screens
5. **Set up development environment** - Xcode project, FastAPI scaffold, Celery setup, GitHub repo
6. **Begin Phase 1 development** - Start with GTFS data pipeline

---

**Status:** Feature map complete - ready for architecture specification phase
