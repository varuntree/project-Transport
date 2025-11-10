# Technical Requirements & Constraints
**For System Architecture Design**

---

## Non-Negotiable Constraints

### Platform
- iOS 16+ only (Swift/SwiftUI)
- Target: iPhone (iOS 16, 17, 18)
- Support: Live Activities, Widgets, Lock Screen widgets

### Backend
- FastAPI (Python) for REST API + background workers
- PostgreSQL for data storage
- Redis for caching
- Celery for background job processing

### Data Sources
- NSW GTFS static feed (227MB compressed, daily updates)
- NSW GTFS-RT feed (real-time updates)
- NSW Trip Planner API (60K free calls/day, 5 req/s rate limit)

### Budget
- **MVP infrastructure: $50/month maximum**
- Must stay within free tiers where possible

### App Size
- **Initial download: <50MB strict limit**
- Challenge: NSW GTFS is 227MB (must solve data delivery)

### Timeline
- Phase 1 MVP: 14-18 weeks

---

## Performance Requirements

### Real-Time Data Accuracy
- Users must see accurate arrival times
- Delays/cancellations must be reflected quickly
- Goal: Information should feel "live" to users

### App Responsiveness
- Departure queries should feel instant
- Search results should appear quickly
- Map interactions should be smooth

### Reliability
- App must work even when backend has issues
- Graceful degradation when NSW APIs are down
- Must handle network interruptions on mobile

### Battery & Data Efficiency
- Minimize battery drain from location services
- Minimize mobile data usage
- Optimize background activity

---

## Functional Requirements

### P0 Features (Must Have for Launch)

1. **Real-Time Departures**
   - Show next 3-5 departures for any stop
   - All Sydney transit modes (trains, metro, buses, ferries, light rail)
   - Live countdown timers
   - Show delays/cancellations
   - Wheelchair accessibility info

2. **Stop/Station Search & Nearby**
   - Search by stop name or number
   - Show nearest stops based on user location
   - Map view with stop pins
   - Fast, responsive search

3. **Service Alerts**
   - System-wide disruption alerts
   - Filter by mode (e.g., show only train alerts)
   - Push notifications for user's favorited stops/routes
   - Clear indication of which lines/routes affected

4. **Favorites & Quick Access**
   - Save frequently used stops/routes
   - Home screen shows favorited stops with next departures
   - Reorderable favorites
   - Sync across devices (CloudKit)

5. **Trip Planning**
   - Multi-modal journey planning
   - Door-to-door directions (address → address)
   - Multiple route options
   - Real-time aware (accounts for delays)
   - Walking + transit combinations

6. **Maps & Route Visualization**
   - Live vehicle positions on map
   - Route shapes visualization
   - Stop locations

7. **Push Notifications**
   - Alerts for service disruptions on favorites
   - Configurable by user
   - Time-sensitive delivery (iOS priority notifications)

---

## Data Challenges to Solve

### NSW GTFS Static (227MB)
- Too large to bundle in app
- Must provide offline capability option
- Must support users with limited storage
- **Oracle must design data delivery strategy**

### NSW API Rate Limits
- NSW Trip Planner: 60K calls/day, 5 req/s
- GTFS-RT feeds: Available for polling
- **Oracle must design request/caching strategy**

### Real-Time Data Freshness
- GTFS-RT data changes constantly
- Users expect current information
- **Oracle must design update strategy**

### User Data Sync
- Favorites must sync across devices
- Decision: Use CloudKit (no backend) or backend storage?
- **Oracle should evaluate trade-offs**

---

## Architecture Goals

### Optimize For
1. **Accuracy**: Users trust the data
2. **Speed**: Feels instant, not slow
3. **Efficiency**: Minimal resources (battery, data, compute, cost)
4. **Reliability**: Works even when things break
5. **Simplicity**: Easy to build, maintain, debug

### System Must Handle
- Background jobs (GTFS-RT polling, alerts, push notifications)
- High read load (many users checking departures)
- Occasional write load (user favorites, trip saves)
- API integrations (NSW GTFS, Trip Planner, APNs)
- Caching for cost efficiency

---

## Scaling Expectations

### Initial Launch
- Target: 100-1,000 active users
- Infrastructure: Must run on $50/month budget

### 6 Months
- Target: 5,000 active users
- Budget: Can increase to $100-200/month if needed

### 12 Months
- Target: 10,000-50,000 active users
- Budget: Will scale with revenue

**Architecture must be designed to scale gradually without major rewrites**

---

## Security & Privacy Requirements

### Authentication
- Apple Sign-In (primary)
- JWT-based sessions
- Secure token storage (iOS Keychain)

### Data Privacy
- Minimal data collection
- No location tracking/history
- GDPR/CCPA compliant
- Easy account deletion

### API Security
- Rate limiting (prevent abuse)
- Input validation
- Protection against common vulnerabilities (SQL injection, XSS, etc.)

---

## Integration Requirements

### iOS Native
- MapKit for maps
- CoreLocation for user location
- WeatherKit for weather (optional, P1)
- CloudKit for favorites sync
- WidgetKit for home screen widgets
- ActivityKit for Live Activities (P1)
- APNs for push notifications

### NSW APIs
- GTFS static feed download + parsing
- GTFS-RT feed consumption
- Trip Planner API integration (respect rate limits)

### Third-Party Services
- Railway/Fly.io for hosting
- Vercel for marketing site
- Sentry for error tracking (free tier)

---

## Questions for Oracle to Answer

Oracle should determine optimal solutions for:

1. **Data Architecture**
   - How to handle 227MB GTFS while keeping app <50MB?
   - How to structure PostgreSQL schema for GTFS data?
   - How to optimize SQLite for iOS app?

2. **Real-Time Updates**
   - How frequently to poll NSW GTFS-RT?
   - How to cache real-time data efficiently?
   - How to push updates to users?

3. **Caching Strategy**
   - What should be cached and for how long?
   - Where to cache (Redis vs iOS local)?
   - Cache invalidation strategy?

4. **Background Workers**
   - What Celery tasks are needed?
   - How to schedule them?
   - How to handle failures?

5. **API Design**
   - What REST endpoints are needed?
   - Request/response schemas?
   - Error handling patterns?

6. **iOS Architecture**
   - How to structure SwiftUI app (MVVM, clean arch)?
   - How to manage data layer?
   - How to handle offline mode?

7. **Deployment**
   - How to set up Railway/Fly.io?
   - Environment configuration?
   - CI/CD pipeline?

---

## Success Criteria

### MVP Launch Ready When:
- ✅ All P0 features working
- ✅ App size <50MB
- ✅ Infrastructure cost <$50/month
- ✅ Real-time data feels current
- ✅ App responsive on iPhone (iOS 16+)
- ✅ No critical bugs
- ✅ Can handle 1,000 concurrent users

### Good Architecture Means:
- Easy to understand and modify
- Easy to test
- Easy to deploy
- Scales without major rewrites
- Costs stay reasonable as users grow
- Maintainable by small team (2-3 developers)

---

**Oracle's Deliverable:**
Complete system architecture that addresses all requirements and questions above, implementation-ready for development team.
