# ORACLE PROMPT: Rate Limiting Strategy

**Consultation ID:** 07_rate_limiting
**Context Document:** Attach `SYSTEM_OVERVIEW.md` + `BACKEND_SPECIFICATION.md`
**Priority:** HIGH - Protects against abuse and cost overruns
**Expected Consultation Time:** 1-3 hours (with research)

---

## Context Summary

**App:** Sydney transit app - iOS + FastAPI backend
**Users:** 0 initially → 1K (6 months) → 10K (12 months)
**Developer:** Solo, no team, no 24/7 incident response
**Budget:** $25/month MVP → scale with users

---

## Fixed Tech Stack (DO NOT CHANGE)

- **Backend:** FastAPI (Python 3.11+) + Celery workers
- **Message Broker/Cache:** Redis (Railway or Upstash)
- **Hosting:** Railway or Fly.io
- **CDN:** Cloudflare (free tier)
- **External API:** NSW Transport (5 req/s, 60K/day limits)

**NO new external services allowed.**

---

## Problem Statement

Design comprehensive rate limiting strategy that:

1. **Protects NSW API** - Never exceed 5 req/s or 60K/day (our target: <20K/day)
2. **Prevents abuse** - Stop scraping, DoS attacks, resource exhaustion
3. **Fair usage** - Ensure all users get reasonable access
4. **Graceful degradation** - Serve cached/stale data when limits hit
5. **Solo-dev friendly** - Simple to configure, debug, monitor

---

## Two Rate Limiting Problems

### Problem A: NSW API Rate Limiting (Outbound)

**Challenge:** Multiple Celery workers + FastAPI processes calling NSW API
- Shared limit: 5 requests/second (hard, enforced by NSW)
- Daily quota: 60,000 requests/day (soft, we target <20K)
- Current polling design: ~16,640 calls/day (from Oracle consultation 01)
- Room for: ~3,360 additional calls (user-triggered trip planning, manual refreshes)

**Questions:**
- How to coordinate rate limiting across multiple workers/processes?
- Redis-based distributed rate limiter vs queue-based serialization?
- Handle burst scenarios (5 req/s but not sustained)?
- What to do when limit hit (queue, reject, serve stale)?

---

### Problem B: Our API Rate Limiting (Inbound)

**Challenge:** Protect our backend from abuse
- Public endpoints (no auth): Stops, routes, departures, trip planning
- Protected endpoints (auth required): Favorites, saved trips, notifications
- Threats: Scraping, DoS, resource exhaustion, accidental loops (buggy clients)

**Questions:**
- Different limits for public vs authenticated users?
- Per-IP limits (anonymous) vs per-user limits (authenticated)?
- Per-endpoint limits (expensive queries vs cheap)?
- Cloudflare edge rate limiting vs application-level?

---

## Questions for Oracle

### 1. NSW API Distributed Rate Limiter

**Question:** Best pattern for coordinating 5 req/s limit across workers?

**Context:**
- 2-4 Celery workers polling GTFS-RT (peak load)
- 2 FastAPI web processes handling user requests (trip planning calls NSW)
- All need to share 5 req/s budget

**Pattern A: Redis Token Bucket (current draft)**
```python
class RedisTokenBucket:
    def __init__(self, redis, capacity=5, refill_rate=4.5):  # 4.5/s = safety margin
        self.redis = redis
        self.capacity = capacity
        self.refill_rate = refill_rate

    def acquire(self, block=True, max_sleep=0.25) -> bool:
        now = time.time()
        # Atomic token bucket update via Redis
        meta = self.redis.hgetall("nsw:rate")
        tokens = float(meta.get("tokens", self.capacity))
        ts = float(meta.get("ts", now))

        elapsed = now - ts
        tokens = min(self.capacity, tokens + elapsed * self.refill_rate)

        if tokens >= 1:
            tokens -= 1.0
            self.redis.hset("nsw:rate", mapping={"tokens": tokens, "ts": now})
            return True

        if not block:
            return False

        time.sleep(min(max_sleep, 1.0 / self.refill_rate))
        return self.acquire(block=False)
```
*Pro:* Distributed, fair, allows bursts
*Con:* Redis round-trip per call (latency)

**Pattern B: Redis Queue (single consumer)**
```python
# All workers push NSW requests to Redis queue
def call_nsw_api(url):
    request_id = str(uuid.uuid4())
    redis.rpush("nsw:request_queue", json.dumps({"id": request_id, "url": url}))
    # Wait for response (blocking or polling)
    response = wait_for_response(request_id, timeout=10)
    return response

# Single dedicated worker (NSW API poller) consumes queue at 4.5/s
@app.task
def nsw_api_consumer():
    while True:
        req = redis.blpop("nsw:request_queue", timeout=1)
        if req:
            url = json.loads(req[1])["url"]
            response = requests.get(url, ...)
            # Store response for requester
        time.sleep(1.0 / 4.5)  # Rate limit
```
*Pro:* Guaranteed rate limit compliance, simple logic
*Con:* Single point of failure, latency (queue wait time)

**Pattern C: Hybrid (token bucket + fallback queue)**
```python
# Workers try token bucket first (fast path)
# If bucket empty, push to queue (slow path)
def call_nsw_api_smart(url):
    if token_bucket.acquire(block=False):
        return requests.get(url, ...)  # Fast: immediate call
    else:
        return call_via_queue(url)     # Slow: queue + wait
```

**Questions:**
- Which pattern is most reliable for 5 req/s compliance?
- Should we use Redis Lua script for atomic token bucket?
- How to handle 429 responses from NSW (exponential backoff)?
- Monitor: Current rate (req/s), daily quota usage (% of 60K)

---

### 2. Daily Quota Management (60K/day)

**Question:** How to stay under 60K/day and alert before exhaustion?

**Current usage:**
- Polling: ~16,640 calls/day (adaptive, from Oracle consultation 01)
- User requests: ~3,000-5,000 calls/day (trip planning, manual refreshes)
- Buffer: ~40K calls/day remaining (safety margin)

**Safeguards needed:**

**Safeguard A: Daily counter + alert**
```python
# Increment on every NSW call
redis.incr(f"nsw:daily:{date.today()}")
redis.expire(f"nsw:daily:{date.today()}", 86400 * 2)  # Keep 2 days

# Hourly check (Celery Beat task)
@app.task
def check_nsw_quota():
    today = date.today()
    calls_today = int(redis.get(f"nsw:daily:{today}") or 0)

    if calls_today > 48000:  # 80% of 60K
        alert(f"NSW API quota at {calls_today}/60K (80%)")

    if calls_today > 58000:  # 96% of 60K
        alert(f"CRITICAL: NSW API quota at {calls_today}/60K!")
        # Optional: Disable user-triggered calls, rely on cache only
```

**Safeguard B: Per-hour budget (prevent early exhaustion)**
```python
# Max 2500 calls/hour (60K / 24h)
# If hour exceeds budget, throttle or reject new calls

calls_this_hour = int(redis.get(f"nsw:hourly:{datetime.utcnow():%Y%m%d%H}") or 0)
if calls_this_hour > 2500:
    logger.warning("Hourly NSW budget exceeded, serving from cache")
    return serve_cached_data()
```

**Questions:**
- Should we enforce hard cap (reject calls at 59K) or soft alerts only?
- Dynamic adjustment: Reduce polling frequency if approaching quota?
- Prioritize: Polling (critical) over user requests (nice-to-have)?
- Reset strategy: What if quota exceeded mid-day (graceful degradation plan)?

---

### 3. Our API Rate Limiting (Inbound)

**Question:** Optimal rate limits for our endpoints?

**Endpoint categories:**

**Category A: Cheap queries (cached, fast)**
- `GET /stops/nearby` - Redis/DB query, <100ms
- `GET /stops/{id}/departures` - Redis cache hit ~90%, <50ms
- `GET /routes` - DB query, <100ms

**Category B: Expensive queries (compute-heavy)**
- `POST /trips/plan` - NSW Trip Planner API call + processing, ~2-5s
- `GET /routes/{id}` - Large response (shape data), ~200-500ms

**Category C: Protected (auth required)**
- `GET /favorites` - User-specific, RLS query, <100ms
- `POST /favorites` - Write, <100ms

**Current thinking (needs validation):**

| Endpoint Category | Anonymous (per-IP) | Authenticated (per-user) | Window |
|-------------------|-------------------:|--------------------------:|--------|
| Cheap (A)         | 60 req            | 120 req                   | 1 min  |
| Expensive (B)     | 10 req            | 30 req                    | 1 min  |
| Protected (C)     | N/A               | 60 req                    | 1 min  |

**Questions:**
- Are these limits reasonable? Too strict? Too lenient?
- Should we allow bursts (e.g., 20 req/s for 1s, then 1 req/s sustained)?
- Different limits for iOS app (identified by user-agent) vs web scrapers?
- Whitelist developer IP for testing (no limits)?

---

### 4. Rate Limiting Algorithm

**Question:** Token bucket vs sliding window vs fixed window?

**Algorithm comparison:**

**Token Bucket** (current choice)
```python
# Allows bursts, smooth refill
# Example: 60 tokens, refill 1/s → can burst 60 then sustain 1/s
```
*Pro:* Burst-friendly, intuitive
*Con:* Slightly complex to implement

**Sliding Window**
```python
# Counts requests in rolling window
# Example: Max 60 in last 60 seconds (exact)
```
*Pro:* Precise rate limiting
*Con:* Expensive (track timestamp per request)

**Fixed Window**
```python
# Counts requests per fixed minute
# Example: Max 60 from :00 to :59
```
*Pro:* Simple, cheap (single counter)
*Con:* Burst at boundary (59 req at :59, 60 req at :00 = 119 in 2s)

**Questions:**
- Best algorithm for our use case?
- FastAPI library recommendation (`slowapi`, `fastapi-limiter`, custom)?
- Redis-based (shared state) vs in-memory (per-worker, no coordination)?

---

### 5. Response When Rate Limited

**Question:** What to return when user hits rate limit?

**Option A: 429 Too Many Requests (standard)**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Try again in 30 seconds.",
    "retry_after": 30
  }
}
```
*Pro:* HTTP standard, clients know what happened
*Con:* No data returned, poor UX

**Option B: Serve stale cache with warning**
```json
{
  "stale": true,
  "cached_at": "2025-11-12T08:10:00Z",
  "message": "Rate limit reached. Showing cached data (5 minutes old).",
  "departures": [...]
}
```
*Pro:* Better UX, user still gets data
*Con:* Client might not notice "stale" flag

**Option C: Hybrid (429 for expensive, stale for cheap)**
- Cheap queries (departures): Serve stale cache
- Expensive queries (trip planning): Return 429

**Questions:**
- Best approach for transit app UX?
- Should we charge for stale data (count toward rate limit) or serve free?
- HTTP headers: `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After`?

---

### 6. Cloudflare Edge Rate Limiting

**Question:** Should we use Cloudflare rate limiting or application-level only?

**Cloudflare capabilities (Free tier):**
- Rate limiting: 10,000 req/s per IP (very high, anti-DoS)
- Challenge pages: CAPTCHA for suspicious IPs
- Bot detection: Block known bad bots
- No granular per-endpoint limits on Free tier (Pro+ feature)

**Approach:**
- **Cloudflare:** Coarse DDoS protection (10K req/s per IP)
- **Application:** Fine-grained limits (per-endpoint, per-user)

**Configuration:**
```python
# Cloudflare Security settings (via dashboard)
# - Bot Fight Mode: On (block known bots)
# - Security Level: Medium (challenge suspicious)
# - Rate Limiting: 10,000 req/min per IP (fallback DDoS)

# Application (FastAPI)
from slowapi import Limiter
limiter = Limiter(key_func=get_remote_address, storage_uri="redis://...")

@app.get("/stops/{id}/departures")
@limiter.limit("60/minute")
def get_departures(...):
    ...
```

**Questions:**
- Correct division of responsibility (Cloudflare vs app)?
- Should we upgrade Cloudflare to Pro for advanced rate limiting?
- Monitor: Cloudflare analytics (requests, threats blocked)

---

### 7. Exemptions & Overrides

**Question:** How to handle trusted clients (admin, developer, monitoring)?

**Use cases:**
- Developer testing (local dev, CI/CD pipelines)
- Admin dashboard (internal monitoring, manual refreshes)
- Health checks (uptime monitoring services like UptimeRobot)

**Patterns:**

**Pattern A: API key tiers**
```python
# Standard user: 60 req/min
# Developer key: 600 req/min
# Admin key: No limits

def get_rate_limit(request):
    api_key = request.headers.get("X-API-Key")
    if api_key == os.getenv("ADMIN_API_KEY"):
        return "10000/minute"  # Effectively no limit
    if api_key in load_dev_keys():
        return "600/minute"
    return "60/minute"

@limiter.limit(get_rate_limit)
def endpoint(...):
    ...
```

**Pattern B: IP whitelist**
```python
EXEMPT_IPS = ["1.2.3.4", "5.6.7.8"]  # Developer IPs

def is_exempt(request):
    return request.client.host in EXEMPT_IPS

@limiter.limit("60/minute", exempt_when=is_exempt)
def endpoint(...):
    ...
```

**Questions:**
- Best pattern for exemptions?
- Store API keys in Supabase or environment variables?
- Should we log exempt requests separately (audit trail)?

---

## Expected Output Format

### 1. NSW API Rate Limiter Implementation

**Provide production-ready code:**
```python
# Complete implementation of distributed rate limiter
# - Redis-based coordination
# - Handles 5 req/s across workers
# - Daily quota tracking (60K)
# - Graceful degradation when limit hit
```

---

### 2. Rate Limit Configuration Table

| Endpoint                  | Method | Anonymous (per-IP) | Authenticated (per-user) | Algorithm | Window |
|---------------------------|--------|-------------------:|--------------------------:|-----------|--------|
| `/stops/nearby`           | GET    | 60                 | 120                       | Token     | 1 min  |
| `/stops/{id}/departures`  | GET    | 60                 | 120                       | Token     | 1 min  |
| `/trips/plan`             | POST   | 10                 | 30                        | Token     | 1 min  |
| `/favorites`              | GET    | N/A                | 60                        | Token     | 1 min  |
| `/favorites`              | POST   | N/A                | 30                        | Token     | 1 min  |

---

### 3. Response Format (Rate Limited)

**HTTP 429 response:**
```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded for this endpoint.",
    "limit": 60,
    "window": "1 minute",
    "retry_after": 37
  }
}
```

**HTTP headers:**
```
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1699876523
Retry-After: 37
```

---

### 4. Monitoring Metrics

**Essential metrics:**
- `api_rate_limit_hits_total` (counter, by endpoint, by user_type)
- `nsw_api_rate_limiter_wait_seconds` (histogram)
- `nsw_api_quota_usage` (gauge, current daily count)
- `nsw_api_quota_percent` (gauge, % of 60K)

**Dashboards:** Simple Supabase table + SQL queries

---

### 5. Cost Projection

**Rate limiting overhead:**

| Users | Requests/min | Redis Overhead | Latency Added | Cost Impact |
|------:|-------------:|---------------:|--------------:|------------:|
| 1K    | ~500         | ~1MB           | <5ms          | Negligible  |
| 5K    | ~2,500       | ~5MB           | <5ms          | +$1/mo      |
| 10K   | ~5,000       | ~10MB          | <10ms         | +$2/mo      |

---

### 6. Graceful Degradation Plan

**When NSW quota approaching 60K:**

1. **At 80% (48K calls):**
   - Alert developer (email/Slack)
   - Reduce GTFS-RT polling: 30s → 60s, 60s → 120s

2. **At 95% (57K calls):**
   - Critical alert
   - Disable user-triggered NSW calls (trip planning)
   - Serve cached/stale data only

3. **At 100% (60K calls):**
   - Hard stop on NSW calls
   - Serve cached data with "Service degraded" message
   - Wait for midnight reset (Sydney time)

---

## Research Mandate

### Required Research

1. **Distributed rate limiting:**
   - Search: "Redis distributed rate limiting token bucket"
   - Search: "FastAPI rate limiting best practices"
   - **Goal:** Production patterns, proven libraries

2. **NSW API rate limiting:**
   - Search: "Transport API rate limiting strategies"
   - Search: "5 requests per second rate limiter Python"
   - **Goal:** How other transit apps handle this

3. **Rate limit UX:**
   - Search: "Rate limit HTTP response best practices"
   - Search: "Graceful degradation rate limiting"
   - **Goal:** User-friendly rate limiting patterns

### Citation Format

```
Recommendation: Use Redis token bucket with Lua script for atomicity

Rationale: Production deployments at [Company X] use this pattern for
distributed rate limiting [1]. Redis Lua ensures atomic updates without
race conditions [2].

Sources:
[1] https://blog.company.com/rate-limiting-at-scale
[2] https://redis.io/docs/interact/programmability/eval-intro/
```

---

## Success Criteria

✅ **Protects NSW API:** Never exceed 5 req/s, stay under 20K/day
✅ **Prevents abuse:** Scraping, DoS attacks blocked
✅ **Fair usage:** All users get reasonable access
✅ **Graceful:** Serves stale data when limits hit (not blank errors)
✅ **Monitorable:** Clear metrics, alerts at 80% thresholds
✅ **Simple:** Solo dev can configure, debug without deep expertise

---

**Prompt Version:** 1.0
**Created:** 2025-11-12
**Status:** Ready for Oracle submission
