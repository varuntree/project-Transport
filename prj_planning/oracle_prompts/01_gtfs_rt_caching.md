# ORACLE PROMPT: GTFS-RT Real-Time Data Caching Strategy

**Consultation ID:** 01_gtfs_rt_caching
**Context Document:** Attach `SYSTEM_OVERVIEW.md` when submitting this prompt
**Priority:** CRITICAL - Directly impacts cost, performance, and user experience
**Expected Consultation Time:** 2-4 hours (with research)

---

## Context Summary

**App:** Sydney transit app - iOS + FastAPI backend
**Users:** 0 initially → 1K (6 months) → 10K (12 months)
**Developer:** Solo, no team, no 24/7 monitoring
**Budget:** $25/month MVP → scale with users

---

## Fixed Tech Stack (DO NOT CHANGE)

These decisions are already made. Work within these constraints:

- **Backend:** FastAPI (Python 3.11+) + Celery workers
- **Database:** Supabase (PostgreSQL + Auth + Storage, 500MB free tier)
- **Cache:** Redis (Railway managed or Upstash serverless)
- **iOS:** Swift/SwiftUI, iOS 16+, MVVM pattern
- **Hosting:** Railway or Fly.io for backend
- **CDN:** CloudFlare (free tier)
- **Data Source:** NSW Transport GTFS-RT feeds (Protocol Buffer format)

**NO new external services allowed.** Use only the stack above.

---

## Problem Statement

Design an optimal Redis caching strategy for NSW Transport GTFS-RT (real-time) data that:

1. **Minimizes NSW API calls** - Stay well under 60K calls/day limit (ideally <20K/day)
2. **Maximizes data freshness** - Users expect <1 minute staleness for real-time departures
3. **Minimizes Redis memory usage** - Cost control, start small, scale predictably
4. **Scales to 10K users** - Without major architecture changes
5. **Handles peak load** - 7-9am, 5-7pm commute hours (70% of daily traffic)

---

## Data Source Specifications (NSW Transport)

### GTFS-RT Feeds Available

**1. Vehicle Positions**
- **Endpoint:** `https://api.transport.nsw.gov.au/v1/gtfs/vehiclepos/{mode}`
- **Modes:** buses, ferries, lightrail, nswtrains, sydneytrains, metro
- **Update Frequency:** Every 10-15 seconds (NSW publishes)
- **Data Size:** ~50-200 KB per mode per request (Protocol Buffer compressed)
- **Content:** vehicle_id, position (lat/lon), bearing, speed, trip_id, route_id, timestamp

**2. Trip Updates**
- **Endpoint:** `https://api.transport.nsw.gov.au/v1/gtfs/realtime/{mode}`
- **Update Frequency:** Every 10-15 seconds
- **Data Size:** ~100-500 KB per mode per request
- **Content:** trip_id, stop_sequence, arrival/departure delays, schedule_relationship (scheduled, cancelled, added)

**3. Service Alerts**
- **Endpoint:** `https://api.transport.nsw.gov.au/v1/gtfs/alerts/{mode}`
- **Update Frequency:** Ad-hoc (when disruptions occur, typically every 5-10 minutes)
- **Data Size:** ~10-100 KB per mode per request
- **Content:** alert_id, header_text, description, affected entities (routes, stops, trips), severity, time range

### API Rate Limits & Constraints

- **Throttle:** 5 requests/second (hard limit)
- **Daily Quota:** 60,000 requests/day (generous for MVP, but must stay under)
- **Authentication:** API key in header (`Authorization: apikey [key]`)
- **Error Responses:**
  - HTTP 403: Rate limit or quota exceeded
  - HTTP 401: Invalid API key
  - HTTP 503: Temporary API unavailability

---

## System Context

### Sydney Transit Data Scale

- **Stops:** ~2,000 unique stops in Sydney GTFS
- **Routes:** ~500 routes (all modes combined)
- **Active Trips (Peak Hour):** ~1,000 concurrent trips
- **Active Vehicles (Peak Hour):** ~500 vehicles with live tracking

### User Behavior Patterns

**Typical User Session:**
- Opens app during commute (7-9am or 5-7pm)
- Checks 3-5 favorite stops
- Views each stop 1-3 times (checking for updates)
- Session duration: 2-5 minutes
- Frequency: 2x per day (morning + evening commute)

**User Growth Projection:**
- **MVP (0-1K users):** 100-200 concurrent users at peak
- **Growth (1K-10K users):** 1,000-2,000 concurrent at peak
- **Peak load multiplier:** 10x average (70% of daily traffic in 4-hour window)

### Backend Architecture (Celery Workers)

**Current Design:**
```python
# Celery worker: gtfs_rt_poller.py
# Scheduled by Celery Beat

@app.task
def poll_gtfs_rt_feeds():
    """
    Polls NSW GTFS-RT feeds and writes to Redis cache.
    Question: How often should this run? (every 15s, 30s, 60s?)
    """
    modes = ['buses', 'sydneytrains', 'metro', 'ferries', 'lightrail']

    for mode in modes:
        # Fetch VehiclePositions
        vehicle_data = fetch_nsw_api(f'/gtfs/vehiclepos/{mode}')
        parse_and_cache_vehicles(vehicle_data, mode)

        # Fetch TripUpdates
        trip_data = fetch_nsw_api(f'/gtfs/realtime/{mode}')
        parse_and_cache_trips(trip_data, mode)

        # Fetch Alerts (less frequently?)
        alert_data = fetch_nsw_api(f'/gtfs/alerts/{mode}')
        parse_and_cache_alerts(alert_data, mode)

    # Question: Should we batch these requests? Parallel? Sequential?
    # Question: How to handle failures? Retry? Skip?
```

---

## Constraints (CRITICAL - Must Respect)

### 1. Simplicity First (0 Users Initially)
- Avoid premature optimization
- Start with simplest strategy that works
- Add complexity only when metrics prove necessity
- Solo developer must understand and maintain

### 2. No New Services
- **ONLY use:** Redis (Railway or Upstash), Celery (already planned)
- **DO NOT suggest:** Kafka, RabbitMQ, additional caches, separate services
- Work within FastAPI + Redis + Celery architecture

### 3. Cost Conscious
- **Redis free tier (Upstash):** 10,000 requests/day free
- **Redis paid (Railway):** $5-10/month for 512MB-1GB instance
- **Target:** Stay on free tier as long as possible, migrate to paid when metrics show need
- **Provide:** Clear cost projection at 1K users, 10K users

### 4. Solo Developer Maintainability
- Self-healing (auto-retry, circuit breakers)
- Clear error handling (don't fail silently)
- Monitoring built-in (can't fix what can't see)
- Simple to debug at 3am

### 5. NSW API Respect
- Stay well under 60K calls/day (target <20K/day to leave headroom)
- Implement backoff if rate limited
- Don't spam API (batch requests, cache aggressively)
- Handle API downtime gracefully

---

## Questions for Oracle

### 1. Polling Frequency & Strategy

**Question:** How often should Celery worker poll NSW GTFS-RT feeds?

**Options to Consider:**
- A) Poll every 15 seconds (NSW updates every 10-15s, minimal staleness)
- B) Poll every 30 seconds (balance freshness vs API calls)
- C) Poll every 60 seconds (conservative, lower API usage)
- D) Adaptive polling (more frequent during peak hours, less off-peak)

**Calculate:**
- API calls per day for each option (5 modes × 3 feed types × polling frequency)
- Data staleness for each option
- Recommend optimal frequency with justification

### 2. Redis Cache Structure

**Question:** How should we structure Redis keys and values for efficient queries?

**Use Cases to Optimize For:**
- Query 1: Get next departures for stop_id "12345" (most frequent, ~80% of requests)
- Query 2: Get vehicle positions for route "T1" (for map visualization)
- Query 3: Get all active alerts for mode "trains"
- Query 4: Get delay status for specific trip_id

**Design:**
- Propose Redis key naming convention
- Recommend data types (Hash, String/JSON, Sorted Set, etc.)
- Define TTLs for each data type
- Show example queries (pseudocode)

### 3. TTL (Time-To-Live) Optimization

**Question:** What TTL should each data type have?

**Trade-offs:**
- **Shorter TTL (15-30s):** Fresher data, more cache misses, more API calls
- **Longer TTL (60-300s):** Fewer API calls, staler data, better cost efficiency

**Recommend TTLs for:**
- Vehicle positions: ?? seconds (high change rate)
- Trip updates (delays): ?? seconds (moderate change rate)
- Service alerts: ?? seconds (low change rate, but critical)
- API response cache (pre-computed departures): ?? seconds

**Justify:** Why each TTL balances freshness vs cost

### 4. Prefetching & Cache Warming

**Question:** Should we prefetch data for popular stops? How to identify "popular"?

**Scenarios:**
- A) No prefetching (cache-on-demand only, simpler, cold starts)
- B) Prefetch top 100 stops (based on user favorites count, warm cache)
- C) Prefetch all stops at peak hours (7-9am, 5-7pm, aggressive)
- D) Adaptive (learn usage patterns, prefetch dynamically)

**Recommend:**
- Best strategy for MVP (0-1K users)
- Evolution strategy (what changes at 10K users)
- How to identify "popular" stops (metrics to track)

### 5. Cache Invalidation & Updates

**Question:** How to handle cache updates when NSW publishes new GTFS-RT data?

**Options:**
- A) Overwrite cache on every poll (simple, but wasteful if no changes)
- B) Compare timestamps, update only if changed (smarter, more complex)
- C) Publish/subscribe pattern (Redis pub/sub, notify listeners of updates)
- D) Lazy invalidation (TTL expires, refetch on next request)

**Recommend:**
- Strategy that balances simplicity vs efficiency
- Handle partial updates (some modes update, others don't)

### 6. Failure Handling & Resilience

**Question:** How to handle failures gracefully?

**Scenarios:**
- NSW API returns HTTP 503 (temporary outage)
- NSW API returns malformed protobuf (data corruption)
- Redis connection fails (cache unavailable)
- Celery worker crashes mid-poll

**Design:**
- Circuit breaker pattern (stop polling if N consecutive failures)
- Retry strategy (exponential backoff, max retries)
- Fallback behavior (serve stale cache, return scheduled times)
- Alerting (notify developer if failures persist >X minutes)

### 7. Memory Estimation & Scaling

**Question:** Estimate Redis memory usage at different scales.

**Calculate:**
- Memory per cached entity (vehicle, trip update, alert)
- Total memory at 1K users (100 concurrent at peak)
- Total memory at 10K users (1,000 concurrent at peak)
- Worst-case memory (all stops cached, all vehicles tracked)

**Provide:**
- Memory usage table (1K, 5K, 10K users)
- Scaling triggers (when to upgrade from 512MB → 1GB → 2GB Redis)
- Cost projection ($5/month → $10/month → $20/month thresholds)

### 8. Monitoring & Observability

**Question:** What metrics to track for cache health?

**Metrics to Track:**
- Cache hit rate (% of requests served from cache vs API)
- Cache miss rate
- Average response time (cached vs uncached)
- Memory usage (current, trend, % of limit)
- API calls per hour (track against 60K/day quota)
- Eviction rate (keys evicted due to memory pressure)

**Design:**
- Simple dashboard (Supabase table + SQL view, or Redis INFO output)
- Alerting thresholds (e.g., cache hit rate <70%, memory >80%)

---

## Expected Output Format

### 1. Architecture Diagram
Provide ASCII or descriptive diagram showing:
```
Celery Worker (poll every ??s)
    ↓
Fetch NSW GTFS-RT APIs (3 feeds × 5 modes = 15 calls per cycle)
    ↓
Parse Protocol Buffers
    ↓
Write to Redis (structure: ???)
    ↓
iOS App Request → FastAPI → Redis (cache hit) → Response
                          ↓
                   (cache miss) → Supabase + merge → Cache → Response
```

### 2. Redis Data Structure Specification

**Example format:**
```redis
# Vehicle Positions
Key: "vehicle:{mode}:{vehicle_id}"
Type: Hash
TTL: 30 seconds
Fields:
    vehicle_id: "bus_1234"
    route_id: "333"
    lat: "-33.8688"
    lon: "151.2093"
    bearing: "45"
    speed: "25"
    timestamp: "1699876543"

# Departures Cache (pre-computed for stops)
Key: "departures:{stop_id}"
Type: String (JSON)
TTL: 30 seconds
Value: JSON array of next 5 departures with real-time delays merged
```

### 3. Celery Task Implementation (Pseudocode)

**Example format:**
```python
@app.task
def poll_gtfs_rt_feeds():
    """
    Poll NSW GTFS-RT feeds and update Redis cache.
    Runs every [XX] seconds (Oracle's recommendation).
    """
    modes = ['buses', 'sydneytrains', 'metro', 'ferries', 'lightrail']

    for mode in modes:
        try:
            # Fetch vehicle positions
            vehicles = fetch_nsw_api(f'/gtfs/vehiclepos/{mode}')
            for vehicle in parse_protobuf(vehicles):
                redis.setex(
                    f"vehicle:{mode}:{vehicle.id}",
                    ttl=30,  # Oracle's recommendation
                    value=json.dumps(vehicle)
                )

            # Fetch trip updates
            trips = fetch_nsw_api(f'/gtfs/realtime/{mode}')
            # ... (Oracle provides detailed pseudocode)

        except APIError as e:
            # Circuit breaker logic (Oracle designs)
            handle_api_error(e, mode)
```

### 4. Cost Estimation Table

**Format:**
| User Count | Concurrent (Peak) | Redis Memory | API Calls/Day | Monthly Cost |
|------------|-------------------|--------------|---------------|--------------|
| 1K         | 100               | 50 MB        | 15,000        | $0 (free)    |
| 5K         | 500               | 200 MB       | 30,000        | $5 (512MB)   |
| 10K        | 1,000             | 400 MB       | 50,000        | $10 (1GB)    |

### 5. Scaling Triggers (Metric-Driven)

**Format:**
- **Upgrade Redis (512MB → 1GB):** When memory usage >400MB sustained for 1 hour
- **Add Redis replica:** When read throughput >10K req/s
- **Reduce polling frequency:** When API calls >50K/day (approaching limit)
- **Add cache layer:** When cache hit rate <60% (too many misses)

### 6. Validation Checklist

Before finalizing recommendation, ensure:
- ✅ API calls <20K/day at 1K users (leaves 70% headroom)
- ✅ Data staleness <60 seconds at p95
- ✅ Redis memory <512MB at 5K users (free tier sufficient)
- ✅ Solo developer can implement in 1 week
- ✅ No new external services required
- ✅ Graceful degradation on failures
- ✅ Cost scales linearly with users ($0.01/user/month target)

---

## Research Mandate (Oracle's Superpower)

**CRITICAL:** Do NOT guess or invent solutions. Research real-world patterns.

### Required Research Activities

1. **Find Production Transit Apps:**
   - Search: "Transit app GTFS-RT caching architecture" (blogs, GitHub)
   - Search: "Citymapper real-time data architecture"
   - Search: "Open source GTFS-RT cache Redis"
   - **Goal:** Find 3-5 real production examples, cite architectures

2. **GTFS-RT Best Practices:**
   - Search: "GTFS-RT polling frequency recommendations"
   - Search: "GTFS realtime API cache strategy"
   - Search: "Transit real-time data staleness user expectations"
   - **Goal:** Find industry standards, cite sources

3. **Redis Caching Patterns:**
   - Search: "Redis TTL optimization real-time data"
   - Search: "Redis cache warming strategies"
   - Search: "Redis memory estimation calculator"
   - **Goal:** Find proven Redis patterns for time-series data

4. **Cost Optimization:**
   - Search: "Redis cost optimization techniques"
   - Search: "API rate limiting cache strategy"
   - **Goal:** Find cost-saving strategies used in production

### Citation Format

For every major recommendation, cite source:
```
Recommendation: Poll GTFS-RT every 30 seconds

Rationale: Based on Transit app's architecture blog [1], they poll every 30s
to balance freshness (acceptable 30-60s staleness) vs API costs. Citymapper
uses similar 30-45s polling [2]. Research shows users tolerate <1 min staleness
for non-critical updates [3].

Sources:
[1] https://blog.transitapp.com/real-time-data-architecture
[2] https://github.com/citylines/citylines (open source, similar problem)
[3] "User Expectations for Real-Time Transit Data" - MIT 2019 study
```

**DO NOT cite sources that don't exist.** If research finds nothing, state: "No production examples found, recommending based on first principles and constraints."

---

## Success Criteria

Oracle's solution is successful if:

✅ **Practical:** Solo developer can implement in 1 week
✅ **Cost-Effective:** Stays under $25/month at 1K users
✅ **Scalable:** Works for 10K users without refactor
✅ **Research-Backed:** Cites 3+ real production examples
✅ **Simple:** No unnecessary complexity, clear trade-offs
✅ **Complete:** Includes pseudocode, memory estimates, cost projections
✅ **Aligned:** Uses only planned tech stack (Redis, Celery, FastAPI)

---

## Submission Instructions

When submitting to Oracle:

1. **Attach:** `SYSTEM_OVERVIEW.md` (full context)
2. **Paste:** This prompt in its entirety
3. **Request:** "Research production GTFS-RT caching architectures and design optimal strategy for our constraints"
4. **Expect:** 2-4 hour turnaround (includes research time)
5. **Output:** Detailed specification with cited sources

---

**Prompt Version:** 1.0
**Created:** 2025-11-12
**Status:** Ready for Oracle submission
