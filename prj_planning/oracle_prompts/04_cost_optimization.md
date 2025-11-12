# ORACLE PROMPT: Cost Optimization Architecture & Safeguards

**Consultation ID:** 04_cost_optimization
**Context Document:** Attach `SYSTEM_OVERVIEW.md` when submitting this prompt
**Priority:** CRITICAL - Prevent bill explosions, maximize free tiers
**Expected Consultation Time:** 2-3 hours (with research + cost modeling)

---

## Context Summary

**App:** Sydney transit app - iOS + FastAPI backend
**Developer:** Solo, self-funded, no VC backing
**Budget:** $25/month maximum at MVP (0-1K users)
**Goal:** Maximize free tiers, provide early warnings before costs spike
**Constraint:** Must be profitable at scale (target <$1/user/month operational cost)

---

## Fixed Tech Stack (DO NOT CHANGE)

Free tier services we're using:
- **Supabase:** 500MB DB, 50K MAU, 1GB storage (FREE)
- **Railway/Fly.io:** $5 credit/month or pay-as-you-go
- **CloudFlare CDN:** Unlimited bandwidth (FREE forever)
- **Vercel (marketing):** Unlimited bandwidth for static (FREE)
- **Upstash Redis:** 10K requests/day (FREE) or Railway Redis ($5-10/month)
- **APNs:** Push notifications (FREE)
- **NSW Transport API:** 60K calls/day (FREE)

**NO paid services unless free tier exhausted.**

---

## Problem Statement

Design a cost-conscious architecture with built-in safeguards that:

1. **Maximizes free tiers** - Stay on free as long as possible (target: 5K users on free)
2. **Prevents bill explosions** - Safeguards against runaway costs (infinite loops, memory leaks)
3. **Provides early warnings** - Alert at 80% of limits before hard caps hit
4. **Scales cost-efficiently** - Predictable cost growth ($0.50-$1/user/month at scale)
5. **Monitoring built-in** - Dashboard shows real-time cost metrics (API calls, DB size, memory)

---

## Cost Risks (Where Bills Could Explode)

### Disaster Scenarios Oracle Must Design Safeguards For:

**Scenario 1: Runaway Celery Tasks (CRITICAL)**
```python
# Bug: Infinite loop in GTFS-RT poller
@app.task
def poll_gtfs_rt():
    while True:  # BUG: Forgot to return, runs forever
        fetch_nsw_api()  # Thousands of API calls per minute
        # Impact: Exhaust 60K/day quota in 30 minutes, rate limit ban

# Oracle: Design safeguards (task timeout, max runtime, circuit breaker)
```

**Scenario 2: Redis Memory Leak**
```redis
# Bug: Keys created without TTL
SET "temp_data_123" "{huge_json_blob}"  # No EXPIRE set
# Impact: Redis memory grows unbounded → $10/month → $50/month → $200/month

# Oracle: Design safeguards (mandatory TTL enforcement, eviction policy, memory alerts)
```

**Scenario 3: Supabase Storage Leak**
```python
# Bug: Daily GTFS downloads never cleaned up
download_gtfs("gtfs_2025-11-12.zip")  # 227 MB
download_gtfs("gtfs_2025-11-13.zip")  # 227 MB
# ... 30 days later: 6.8 GB → exceed 1GB free tier → $25/month

# Oracle: Design safeguards (retention policy, automated cleanup, alerts)
```

**Scenario 4: API Call Spike (App Goes Viral)**
```
# Scenario: App featured on App Store, 10K users overnight
# Impact: NSW API quota (60K/day) exhausted by 10am
# Without caching: 10K users × 10 requests/user = 100K requests needed

# Oracle: Design safeguards (aggressive caching, rate limiting, graceful degradation)
```

**Scenario 5: Database Size Explosion**
```sql
# Bug: GTFS-RT data written to Supabase instead of Redis
INSERT INTO realtime_positions ...  -- Millions of inserts/day
# Impact: 500MB limit exceeded in 2 days → $25/month Pro plan

# Oracle: Design safeguards (prevent writes to wrong tables, size monitoring)
```

---

## Constraints (CRITICAL - Must Respect)

### 1. Solo Developer Reality
- **No 24/7 monitoring** - alerts must be actionable (email/Slack, not dashboards to watch)
- **No DevOps team** - self-healing systems, auto-recovery preferred
- **No complex tools** - simple monitoring (Supabase SQL views, not Datadog)

### 2. Cost Targets by User Count

| Users | Monthly Cost | Notes |
|-------|-------------|-------|
| 0-1K | <$25 | MVP phase, mostly free tiers |
| 1K-5K | <$75 | Scale within free tiers as long as possible |
| 5K-10K | <$150 | Likely need paid Supabase, larger Redis |
| 10K-50K | <$500 | Multiple instances, read replicas |

**Target:** <$1/user/month operational cost (allows profitability with $4.99/month premium tier)

### 3. Free Tier Limits (Must Stay Under)

**Supabase:**
- Database: 500MB (target <400MB for headroom)
- Monthly Active Users: 50K (track unique auth.uid())
- File Storage: 1GB (target <800MB)
- Egress: 5GB/month (not a concern with CDN)

**Upstash Redis:**
- Requests: 10K/day free (track with counter)
- Storage: 256MB free (track memory usage)
- After free: $0.20/100K requests

**Railway/Fly.io:**
- Railway: $5/month credit (covers ~500MB RAM instance)
- Fly.io: First ~$5 waived (shared-cpu-1x, 256MB RAM)

**NSW Transport API:**
- Requests: 60K/day (track daily counter)
- Throttle: 5 req/s (implement client-side rate limiter)

### 4. Alerting Requirements

**Must alert developer when:**
- Any service approaching 80% of limit (time to optimize)
- Daily cost projection >$10 (unusual spike, investigate)
- Task runs longer than expected (potential infinite loop)
- Error rate >5% (system degradation)

**Alert Channels:**
- Email (primary, solo developer checks regularly)
- Slack webhook (optional, if dev uses Slack)
- In-app banner (for non-critical warnings)

---

## Questions for Oracle

### 1. Free Tier Maximization Strategy

**Question:** How to stay on free tiers as long as possible?

**Oracle Design:**

**A) Supabase Free Tier (500MB DB, 50K MAU, 1GB Storage)**
```sql
-- How to stay under limits?
-- 1. Database size optimization (see 03_database_schema.md Oracle solution)
-- 2. MAU tracking (count distinct auth.uid() per month)
-- 3. Storage cleanup (delete old GTFS files)

-- Oracle: Provide monitoring queries
SELECT
    pg_database_size(current_database()) / 1024 / 1024 AS db_size_mb,
    500 AS limit_mb,
    (pg_database_size(current_database()) / 1024 / 1024) / 500.0 * 100 AS percent_used;

-- Oracle: Design automated cleanup strategy
```

**B) Redis Free Tier (10K requests/day, 256MB storage)**
```redis
# How to stay under limits?
# 1. Track daily request count (Redis INCR counter)
# 2. Cache hit rate optimization (reduce requests)
# 3. TTL enforcement (prevent memory growth)

# Oracle: Provide request tracking implementation
```

**C) NSW API Free Tier (60K calls/day)**
```python
# How to stay under limit?
# 1. Aggressive caching (Redis 30s TTL = 97% reduction)
# 2. Batch requests (fetch all modes in one poll cycle)
# 3. Smart polling (more frequent during peak, less off-peak)

# Example without caching:
# 1K users × 5 requests/session × 2 sessions/day = 10K requests/day

# With caching (30s TTL):
# Celery polls: 5 modes × 3 feeds × 2880 polls/day (30s interval) = 43K/day
# Client cache hits: 95% → 500 requests/day from clients
# Total: 43.5K/day (72% of quota) ✅

# Oracle: Validate this math, optimize polling frequency
```

### 2. Cost Safeguards (Prevent Runaway Costs)

**Question:** Design safeguards for each disaster scenario above.

**Oracle Provide:**

**Safeguard 1: Celery Task Timeouts**
```python
# Prevent infinite loops
@app.task(time_limit=300, soft_time_limit=240)  # Hard limit 5min, soft 4min
def poll_gtfs_rt():
    try:
        # ... task logic
    except SoftTimeLimitExceeded:
        logger.warning("Task approaching time limit, exiting gracefully")
        return
    except TimeLimitExceeded:
        logger.error("Task killed due to timeout")
        send_alert("GTFS poller exceeded 5min runtime - investigate infinite loop")
        raise

# Oracle: Define optimal time limits for each task
# Oracle: Circuit breaker pattern (stop polling if NSW API down for N consecutive failures)
```

**Safeguard 2: Redis Memory Limits & Eviction**
```redis
# Set memory limit (Railway: 512MB instance)
CONFIG SET maxmemory 512mb
CONFIG SET maxmemory-policy volatile-lru  # Evict keys with TTL first

# Enforce TTL on all keys (code review rule)
# Oracle: Design code linting rule to reject SET without EXPIRE

# Monitor memory usage
INFO memory | grep used_memory_human

# Alert if >80% (410MB)
# Oracle: Provide monitoring script
```

**Safeguard 3: Supabase Storage Cleanup**
```python
# Retention policy: Keep only last 7 days of GTFS files
@app.task
def cleanup_old_gtfs_files():
    """
    Runs weekly (Celery Beat schedule: Sundays 2am)
    """
    cutoff_date = datetime.now() - timedelta(days=7)

    # Delete files from Supabase Storage older than 7 days
    files = supabase.storage.from_('gtfs-archives').list()
    for file in files:
        if file['created_at'] < cutoff_date:
            supabase.storage.from_('gtfs-archives').remove([file['name']])
            logger.info(f"Deleted old GTFS file: {file['name']}")

# Oracle: Validate this approach, suggest improvements
```

**Safeguard 4: Rate Limiting (Client-Side)**
```python
# Prevent API spam if caching fails
import time
from collections import deque

class RateLimiter:
    """
    Token bucket rate limiter for NSW API (5 req/s limit)
    """
    def __init__(self, max_rate=4.5, time_window=1.0):  # 4.5 req/s (leave headroom)
        self.max_rate = max_rate
        self.time_window = time_window
        self.requests = deque()

    def acquire(self):
        now = time.time()

        # Remove old requests outside time window
        while self.requests and self.requests[0] < now - self.time_window:
            self.requests.popleft()

        if len(self.requests) < self.max_rate:
            self.requests.append(now)
            return True
        else:
            # Rate limited, sleep until next window
            sleep_time = self.requests[0] + self.time_window - now
            time.sleep(sleep_time)
            self.requests.append(time.time())
            return True

rate_limiter = RateLimiter()

def fetch_nsw_api(endpoint):
    rate_limiter.acquire()  # Blocks if rate limit hit
    response = requests.get(f"https://api.transport.nsw.gov.au{endpoint}", ...)
    return response

# Oracle: Validate this implementation, suggest improvements
```

**Safeguard 5: Database Write Prevention (Wrong Table)**
```python
# Prevent accidental writes to GTFS tables (read-only except during sync)
class GTFSRepository:
    def __init__(self):
        self.write_allowed = False  # Default: read-only

    def enable_writes(self):
        """Only call during gtfs_static_sync task"""
        self.write_allowed = True

    def disable_writes(self):
        self.write_allowed = False

    def insert_stop(self, stop_data):
        if not self.write_allowed:
            raise PermissionError("GTFS tables are read-only outside sync task")
        # ... insert logic

# Oracle: Better pattern? Database-level constraints?
```

### 3. Monitoring & Observability

**Question:** Design simple, actionable monitoring for cost metrics.

**Oracle Provide:**

**A) Cost Dashboard (Supabase SQL View)**
```sql
-- Create view for monitoring dashboard
CREATE VIEW cost_monitoring AS
SELECT
    -- Database size
    pg_database_size(current_database()) / 1024 / 1024 AS db_size_mb,
    500 AS db_limit_mb,
    (pg_database_size(current_database()) / 1024.0 / 1024.0 / 500.0 * 100) AS db_percent_used,

    -- Monthly Active Users (last 30 days)
    (SELECT COUNT(DISTINCT user_id) FROM auth.users WHERE last_sign_in_at > NOW() - INTERVAL '30 days') AS mau,
    50000 AS mau_limit,

    -- Storage usage (Supabase Storage API - Oracle: how to query this?)
    ... AS storage_mb,
    1024 AS storage_limit_mb,

    -- Daily API calls (tracked in custom table)
    (SELECT COUNT(*) FROM nsw_api_call_log WHERE called_at > NOW() - INTERVAL '1 day') AS api_calls_today,
    60000 AS api_limit_day;

-- Oracle: Complete this query, add more metrics
```

**B) API Call Tracking**
```python
# Log every NSW API call (for quota monitoring)
def fetch_nsw_api(endpoint):
    response = requests.get(...)

    # Log to Supabase
    supabase.table('nsw_api_call_log').insert({
        'endpoint': endpoint,
        'status_code': response.status_code,
        'called_at': datetime.utcnow().isoformat()
    }).execute()

    # Daily counter (Redis)
    redis.incr('nsw_api_calls:' + datetime.today().strftime('%Y-%m-%d'))
    redis.expire('nsw_api_calls:' + datetime.today().strftime('%Y-%m-%d'), 86400 * 2)  # Keep 2 days

    return response

# Oracle: Is logging every call too expensive? Sampling strategy?
```

**C) Alerting System (Simple Email)**
```python
# Check limits hourly (Celery Beat schedule)
@app.task
def check_cost_limits():
    alerts = []

    # Check Supabase DB size
    db_size = get_db_size_mb()
    if db_size > 400:  # 80% of 500MB
        alerts.append(f"⚠️ Database size: {db_size}MB (80% of free tier)")

    # Check NSW API calls today
    api_calls = redis.get('nsw_api_calls:' + datetime.today().strftime('%Y-%m-%d'))
    if int(api_calls or 0) > 48000:  # 80% of 60K
        alerts.append(f"⚠️ NSW API calls today: {api_calls} (80% of quota)")

    # Check Redis memory
    redis_memory = get_redis_memory_mb()
    if redis_memory > 410:  # 80% of 512MB
        alerts.append(f"⚠️ Redis memory: {redis_memory}MB (80% of limit)")

    # Send email if any alerts
    if alerts:
        send_email(
            to="developer@example.com",
            subject="⚠️ Cost Alert - Review Limits",
            body="\n".join(alerts)
        )

# Oracle: Expand this, add more checks
```

### 4. Cost Projection & Scaling Triggers

**Question:** Provide cost projections and clear triggers for when to upgrade.

**Oracle Provide:**

**Cost Projection Table:**
```
| Users | Concurrent (Peak) | Supabase | Redis | Hosting | Total/Month | $/User |
|-------|-------------------|----------|-------|---------|-------------|--------|
| 100   | 10                | Free     | Free  | $5      | $5          | $0.05  |
| 1K    | 100               | Free     | Free  | $10     | $10         | $0.01  |
| 5K    | 500               | Free*    | $10   | $25     | $35         | $0.007 |
| 10K   | 1K                | $25      | $20   | $50     | $95         | $0.0095|
| 50K   | 5K                | $100     | $50   | $200    | $350        | $0.007 |

*Assumes optimized schema keeps DB <450MB
```

**Scaling Triggers (Metric-Driven):**
```yaml
# Upgrade Supabase (Free → Pro $25/month):
triggers:
  - condition: DB size >450MB sustained for 24 hours
  - condition: MAU >45K (90% of 50K limit)
  - condition: Storage >900MB (90% of 1GB)
  action: Upgrade to Pro plan ($25/month)
  budget_impact: +$25/month

# Upgrade Redis (Free → 512MB $10/month):
triggers:
  - condition: Daily requests >9K (90% of 10K Upstash limit)
  - condition: Memory usage >230MB (90% of 256MB)
  action: Migrate to Railway Redis 512MB
  budget_impact: +$10/month

# Add Redis Replica:
triggers:
  - condition: Read throughput >10K req/s
  - condition: Cache hit rate <60% (too many misses)
  action: Add read replica
  budget_impact: +$10-20/month

# Scale Backend (1 → 2 instances):
triggers:
  - condition: CPU >70% sustained for 1 hour
  - condition: Response time p95 >500ms
  action: Add second instance (load balancer)
  budget_impact: +$20-30/month
```

### 5. Graceful Degradation (When Limits Hit)

**Question:** What happens when we hit limits? Design fallback behavior.

**Oracle Provide:**

**Scenario: Supabase DB at 500MB (Limit Reached)**
```python
# Temporary measure (before upgrading):
# 1. Drop non-critical indexes (save ~50MB, degrade query performance)
# 2. Truncate old calendar_dates (holiday exceptions >6 months old)
# 3. Remove shapes for bus routes (keep trains/metro only)

# Automatic fallback:
if get_db_size_mb() > 490:
    logger.critical("Database approaching limit, applying emergency optimizations")
    drop_non_essential_indexes()
    truncate_old_calendar_dates()
    send_alert("Database at 98% capacity - upgrade to Pro plan ASAP")

# Oracle: Design safe emergency optimizations
```

**Scenario: NSW API Quota Exhausted (60K calls/day)**
```python
# Fallback: Serve cached data, mark as stale
if nsw_api_quota_exceeded():
    logger.warning("NSW API quota exceeded, serving stale cache")

    # Return cached data with staleness indicator
    cached_departures = redis.get('departures:' + stop_id)
    cached_at = redis.get('departures:' + stop_id + ':cached_at')

    return {
        'departures': cached_departures,
        'stale': True,
        'cached_at': cached_at,
        'message': 'Real-time data temporarily unavailable, showing cached data'
    }

# iOS app shows banner: "⚠️ Showing cached data (updated 15 min ago)"
```

### 6. Cost-Saving Optimizations

**Question:** What optimizations provide best ROI for cost reduction?

**Oracle Research & Recommend:**

**Optimization Priority Matrix:**
```
Optimization                      | Cost Saved | Complexity | ROI  | Priority
----------------------------------|------------|------------|------|----------
Aggressive Redis caching (30s TTL)| 70%        | Low        | High | P0
CloudFlare CDN for GTFS files     | 60%        | Low        | High | P0
Optimized database schema         | 40%        | Medium     | High | P0
Off-peak polling (adaptive)       | 20%        | Medium     | Med  | P1
Compress API responses (gzip)     | 15%        | Low        | Med  | P1
Database connection pooling       | 10%        | Low        | Low  | P2
Read replicas (scale horizontally)| Enables    | High       | Low  | P3

Oracle: Fill in estimates, prioritize for MVP
```

---

## Research Mandate (Oracle's Superpower)

### Required Research Activities

1. **Cost Optimization Patterns:**
   - Search: "Startup infrastructure cost optimization strategies"
   - Search: "PostgreSQL free tier optimization techniques"
   - Search: "Redis memory optimization patterns"
   - **Goal:** Find proven cost-saving techniques

2. **Monitoring Best Practices:**
   - Search: "Solo developer infrastructure monitoring setup"
   - Search: "Cost alert threshold recommendations"
   - Search: "Simple database monitoring queries"
   - **Goal:** Lightweight monitoring for solo dev

3. **Safeguard Patterns:**
   - Search: "Celery task timeout best practices"
   - Search: "Redis eviction policy recommendations"
   - Search: "API rate limiting implementation patterns"
   - **Goal:** Proven safeguards against cost explosions

4. **Case Studies:**
   - Search: "Startup stayed on free tier with X users"
   - Search: "Transit app infrastructure cost breakdown"
   - **Goal:** Real-world examples of frugal architectures

---

## Expected Output Format

### 1. Cost Safeguard Implementation Guide

**Complete Python/SQL code:**
```python
# Celery task timeouts
@app.task(time_limit=..., soft_time_limit=...)  # Oracle decides values

# Redis eviction policy
CONFIG SET maxmemory ...
CONFIG SET maxmemory-policy ...

# Rate limiter implementation
class RateLimiter: ...

# Oracle: Provide production-ready code for all safeguards
```

### 2. Monitoring Dashboard SQL

```sql
-- Complete cost_monitoring view
CREATE VIEW cost_monitoring AS ...;

-- Alerting queries
SELECT ... WHERE db_size_mb > 400;  -- 80% threshold

-- Oracle: Complete monitoring queries
```

### 3. Cost Projection & Triggers

**Detailed table with thresholds:**
```yaml
scaling_triggers:
  supabase_upgrade:
    metric: database_size_mb
    threshold: 450
    action: Upgrade to Pro ($25/month)
    budget_impact: +$25/month

  # Oracle: Complete all triggers
```

### 4. Emergency Runbook

**Step-by-step procedures:**
```markdown
## Emergency: Database at 98% Capacity

1. Immediate actions (buy time):
   - Run: DROP INDEX idx_stop_times_combined;  # Saves ~30MB
   - Run: DELETE FROM calendar_dates WHERE date < CURRENT_DATE - 180;  # Saves ~10MB

2. Upgrade plan:
   - Supabase dashboard → Upgrade to Pro ($25/month)

3. Long-term fix:
   - Implement schema optimizations from 03_database_schema.md Oracle solution

Oracle: Provide runbooks for all disaster scenarios
```

---

## Success Criteria

Oracle's solution is successful if:

✅ **Cost-Effective:** Stays <$25/month at 1K users
✅ **Safe:** Safeguards prevent all 5 disaster scenarios
✅ **Monitored:** Dashboard shows real-time cost metrics
✅ **Alerts:** Developer notified at 80% thresholds
✅ **Scalable:** Clear triggers for when to upgrade (metric-driven)
✅ **Research-Backed:** Cites 3+ cost optimization case studies
✅ **Actionable:** Solo developer can implement in 1 week

---

## Submission Instructions

1. **Attach:** `SYSTEM_OVERVIEW.md`
2. **Paste:** This prompt
3. **Request:** "Design cost optimization architecture with safeguards"
4. **Expect:** 2-3 hour turnaround

---

**Prompt Version:** 1.0
**Created:** 2025-11-12
**Status:** Ready for Oracle submission
