# ORACLE PROMPT: Celery Worker Task Design

**Consultation ID:** 05_celery_tasks
**Context Document:** Attach `SYSTEM_OVERVIEW.md` + `BACKEND_SPECIFICATION.md`
**Priority:** CRITICAL - Directly impacts reliability, cost, and performance
**Expected Consultation Time:** 2-4 hours (with research)

---

## Context Summary

**App:** Sydney transit app - iOS + FastAPI backend
**Users:** 0 initially → 1K (6 months) → 10K (12 months)
**Developer:** Solo, no team, no 24/7 monitoring
**Budget:** $25/month MVP → scale with users

---

## Fixed Tech Stack (DO NOT CHANGE)

- **Backend:** FastAPI (Python 3.11+) + Celery workers
- **Message Broker:** Redis (Railway or Upstash)
- **Database:** Supabase (PostgreSQL + Auth + Storage)
- **Hosting:** Railway or Fly.io
- **Data Source:** NSW Transport GTFS (static + real-time)

**NO new external services allowed.**

---

## Problem Statement

Design optimal Celery worker architecture for 4 background task types that:

1. **Ensures reliability** - Tasks complete successfully, self-heal on failures
2. **Prevents bill explosion** - Runaway tasks killed automatically, memory leaks prevented
3. **Scales gracefully** - Clear triggers for when to add workers
4. **Solo-dev friendly** - Easy to debug, self-healing, minimal manual intervention

---

## Task Types & Current Understanding

### Task 1: gtfs_static_sync
**Purpose:** Daily GTFS download + parsing + loading to Supabase
**Frequency:** Once daily (3am Sydney time)
**Duration:** 20-30 minutes typical
**Worst case:** 60 minutes (network slow, large data)
**Criticality:** High (app depends on fresh schedule data)
**Error scenarios:**
- NSW API timeout (download fails)
- Parsing error (malformed GTFS)
- Supabase connection error (load fails)
- Out of memory (227MB + processing overhead)

### Task 2: gtfs_rt_poller
**Purpose:** Poll NSW GTFS-RT feeds, parse, write to Redis cache
**Frequency:** Every 15s (adaptive 30s/60s inside task)
**Duration:** <5 seconds typical
**Worst case:** 15 seconds (NSW API slow)
**Criticality:** VERY HIGH (users expect real-time data)
**Error scenarios:**
- NSW API 503 (temporary outage)
- NSW API 429 (rate limit, shouldn't happen but...)
- Redis connection lost
- Protocol buffer parse error

### Task 3: alert_matcher
**Purpose:** Match real-time delays to user favorites, queue APNs
**Frequency:** Every 2 minutes
**Duration:** <10 seconds typical
**Worst case:** 30 seconds (many users, complex matching)
**Criticality:** Medium (users want alerts, but not critical)
**Error scenarios:**
- Redis read failure (can't get delays)
- Supabase query timeout (can't fetch favorites)
- Logic error (infinite loop in matching)

### Task 4: apns_worker
**Purpose:** Send push notifications to iOS devices
**Frequency:** On-demand (queued by alert_matcher)
**Duration:** <2 seconds per batch
**Worst case:** 10 seconds (APNs throttling)
**Criticality:** Medium (nice-to-have, not mission-critical)
**Error scenarios:**
- APNs HTTP/2 connection failure
- Invalid device token (user uninstalled app)
- Apple rate limiting

---

## Questions for Oracle

### 1. Task Priorities & Queue Architecture

**Question:** Should we use multiple queues or single queue with priorities?

**Options:**
- A) Single queue, all tasks equal priority (simplest)
- B) Two queues: `high` (gtfs_rt_poller) + `low` (everything else)
- C) Three queues: `critical` (gtfs_rt_poller) + `normal` (alert_matcher, apns_worker) + `batch` (gtfs_static_sync)
- D) Per-task queues (4 separate queues, dedicated workers per type)

**Considerations:**
- `gtfs_rt_poller` must not be blocked by long `gtfs_static_sync`
- APNs should be responsive (<5s delivery) but not critical
- Solo dev wants simplicity (fewer moving parts)

**Recommend:** Queue architecture with worker assignment strategy

---

### 2. Task Timeouts & Limits

**Question:** Optimal soft/hard time limits per task type?

**Current guess (needs validation):**
```python
task_time_limits = {
    "gtfs_static_sync": {
        "soft_time_limit": 1800,  # 30 min soft (log warning)
        "time_limit": 3600,       # 60 min hard (SIGKILL)
    },
    "gtfs_rt_poller": {
        "soft_time_limit": 10,    # 10s soft
        "time_limit": 15,         # 15s hard
    },
    "alert_matcher": {
        "soft_time_limit": 25,    # 25s soft
        "time_limit": 30,         # 30s hard
    },
    "apns_worker": {
        "soft_time_limit": 8,     # 8s soft
        "time_limit": 10,         # 10s hard
    },
}
```

**Questions:**
- Are these reasonable? Too aggressive? Too lenient?
- Should soft limit trigger retry or just log?
- Should we kill current run if new one starts (prevent overlap)?

---

### 3. Retry Strategy

**Question:** When to retry vs fail permanently?

**Scenarios:**
- **Temporary network error** (NSW 503, Redis timeout) → Retry
- **Permanent error** (malformed GTFS, logic bug) → Fail permanently
- **Rate limit** (NSW 429, APNs throttle) → Backoff + retry

**Retry policies (per task type):**
```python
# Example for gtfs_rt_poller
@app.task(
    bind=True,
    autoretry_for=(requests.Timeout, redis.ConnectionError),
    retry_backoff=True,        # Exponential backoff
    retry_backoff_max=600,     # Max 10 min wait
    retry_jitter=True,         # Add randomness
    max_retries=3              # Fail after 3 attempts
)
def gtfs_rt_poller_task(self):
    ...
```

**Questions:**
- Max retries per task type?
- Exponential backoff parameters (base, max)?
- Should we use Celery's built-in retry or custom circuit breaker (pybreaker)?
- Dead letter queue for permanently failed tasks?

---

### 4. Worker Pool Sizing

**Question:** How many worker processes at different scales?

**Current guess:**
```python
# MVP (0-1K users)
workers = {
    "total_processes": 2,       # 2 worker processes
    "concurrency": 2,           # 2 threads per process = 4 total
    "queue_assignment": "all",  # All workers handle all queues
}

# Growth (1K-10K users)
workers = {
    "total_processes": 4,
    "concurrency": 2,           # = 8 total capacity
    "queue_assignment": {
        "worker1-2": ["critical", "normal"],  # Prioritize RT
        "worker3-4": ["batch", "normal"],     # Handle sync + overflow
    },
}
```

**Questions:**
- Optimal workers for MVP? (1 too few? 4 too many?)
- When to scale horizontally (add more workers)?
- Metrics to watch: queue depth? CPU? Memory?
- Should we use `--autoscale` (Celery built-in)?

---

### 5. Memory Management & Recycling

**Question:** How to prevent memory leaks in long-running workers?

**Current config:**
```python
app.conf.update(
    worker_max_tasks_per_child=100,       # Recycle after 100 tasks
    worker_max_memory_per_child=200_000,  # ~200MB, recycle if exceeded
)
```

**Questions:**
- Are these thresholds reasonable?
- Should we recycle more aggressively (every 50 tasks)?
- Monitor memory usage per worker (Prometheus metric)?
- Alert if worker memory >150MB sustained?

---

### 6. Task Deduplication & Idempotency

**Question:** How to prevent duplicate tasks?

**Scenarios:**
- Celery Beat misfires (schedules task twice)
- Worker dies mid-task, restarted, task re-queued
- Manual task invocation (developer triggers sync)

**Patterns to consider:**
- Redis SETNX lock (task acquires lock before running)
- Task ID based on content hash (e.g., `gtfs_sync_{date}`)
- `acks_late=True` + idempotent task logic

**Example:**
```python
@app.task(bind=True)
def gtfs_static_sync(self):
    lock_key = f"lock:gtfs_sync:{date.today()}"
    lock_acquired = redis.set(lock_key, "locked", nx=True, ex=7200)  # 2h TTL

    if not lock_acquired:
        logger.info("Sync already running, skipping")
        return

    try:
        # Do work
        download_and_parse_gtfs()
    finally:
        redis.delete(lock_key)
```

**Questions:**
- Best pattern for task deduplication?
- Should all tasks use locks or only long-running ones?
- Lock TTL: 2x expected duration reasonable?

---

### 7. Failure Notification & Monitoring

**Question:** How to alert developer when tasks fail?

**Monitoring needs:**
- Task success/failure rate (per task type)
- Task duration (p50, p95, p99)
- Queue depth (backlog of pending tasks)
- Worker health (alive, memory, CPU)

**Alerting triggers:**
- `gtfs_static_sync` fails → immediate alert (email/APNs to dev)
- `gtfs_rt_poller` fails >5 times in 10 min → alert
- Queue depth >100 sustained for 5 min → alert (workers overwhelmed)
- Worker memory >180MB → warning

**Questions:**
- Use Celery Flower (monitoring UI)? Or custom dashboard?
- Store metrics in Supabase table or Prometheus?
- Alert via APNs to developer's device? (dogfood own system)

---

### 8. Celery Configuration Validation

**Question:** Validate or improve this Celery config:

```python
# app/celery_app.py
from celery import Celery
import os

app = Celery("backend")

app.conf.update(
    # Broker & Backend
    broker_url=os.getenv("REDIS_URL"),
    result_backend=None,                  # No result storage (tasks are ephemeral)

    # Task Execution
    task_acks_late=True,                  # Acknowledge after success (idempotent tasks)
    task_reject_on_worker_lost=True,      # Re-queue if worker dies
    worker_prefetch_multiplier=1,         # Fair scheduling (no task hoarding)

    # Timeouts (global defaults, override per task)
    task_time_limit=300,                  # 5 min hard kill
    task_soft_time_limit=240,             # 4 min soft warn

    # Worker Recycling
    worker_max_tasks_per_child=100,       # Recycle after 100 tasks
    worker_max_memory_per_child=200_000,  # ~200MB, recycle if exceeded

    # Broker Transport
    broker_transport_options={
        "visibility_timeout": 3600,        # 1h for long tasks (gtfs_static_sync)
        "fanout_prefix": True,
        "fanout_patterns": True,
    },

    # Serialization
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",

    # Time Zone
    timezone="Australia/Sydney",
    enable_utc=False,
)
```

**Questions:**
- Any dangerous settings here?
- Missing critical settings?
- Should we use `task_track_started=True` (track task state in Redis)?
- Should we set `worker_disable_rate_limits=False` (enable Celery's built-in rate limiting)?

---

## Expected Output Format

### 1. Queue Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│              Celery Beat (Scheduler)             │
│  - Triggers tasks per schedule                  │
│  - Runs as singleton (1 instance only)          │
└────────────────────┬────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────┐
│               Redis (Message Broker)             │
│  ┌──────────────┐  ┌──────────────┐            │
│  │ critical     │  │ normal       │            │
│  │ queue        │  │ queue        │            │
│  └──────────────┘  └──────────────┘            │
└────────────────────┬────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
┌────────────────┐      ┌────────────────┐
│ Worker Pool 1  │      │ Worker Pool 2  │
│ (critical)     │      │ (normal+batch) │
│ - 2 processes  │      │ - 2 processes  │
│ - gtfs_rt_poll │      │ - alert_match  │
│                │      │ - apns_worker  │
│                │      │ - gtfs_sync    │
└────────────────┘      └────────────────┘
```

(Or recommend different architecture)

---

### 2. Task Configuration Table

| Task              | Queue    | Priority | Soft Limit | Hard Limit | Max Retries | Backoff |
|-------------------|----------|----------|------------|------------|-------------|---------|
| gtfs_static_sync  | batch    | Low      | 30m        | 60m        | 3           | Exp     |
| gtfs_rt_poller    | critical | High     | 10s        | 15s        | 3           | Exp     |
| alert_matcher     | normal   | Med      | 25s        | 30s        | 2           | Exp     |
| apns_worker       | normal   | Med      | 8s         | 10s        | 3           | Linear  |

(Populate with Oracle's recommendations)

---

### 3. Worker Sizing Triggers

**Scaling rules:**
- **Add worker** when: Queue depth >50 sustained for 5 min
- **Scale horizontally** when: CPU >70% p95 for 10 min
- **Alert** when: Queue depth >100 (workers overwhelmed)

---

### 4. Implementation Pseudocode

```python
# Example: gtfs_rt_poller with all safeguards
from celery.exceptions import SoftTimeLimitExceeded
from pybreaker import CircuitBreaker

BREAKER = CircuitBreaker(fail_max=5, reset_timeout=60)

@app.task(
    bind=True,
    queue="critical",                         # High priority queue
    autoretry_for=(requests.Timeout,),        # Auto-retry on timeout
    retry_backoff=True,                       # Exponential backoff
    retry_jitter=True,                        # Add randomness
    max_retries=3,                            # Max 3 attempts
    soft_time_limit=10,                       # Soft limit 10s
    time_limit=15,                            # Hard limit 15s
)
def poll_gtfs_rt(self):
    try:
        @BREAKER
        def _fetch():
            return requests.get(url, headers=auth, timeout=(3, 8))

        resp = _fetch()
        resp.raise_for_status()
        parse_and_cache(resp.content)

    except SoftTimeLimitExceeded:
        logger.warning("GTFS RT poller soft limit – exiting gracefully")
    except CircuitBreakerError:
        logger.error("Circuit open for NSW – skipping poll")
    except Exception as e:
        logger.exception("GTFS RT poller error: %s", e)
        raise  # Triggers retry
```

---

### 5. Cost Projection

| User Count | Workers | vCPU | RAM   | Cost/Month |
|-----------:|--------:|-----:|------:|-----------:|
| 1K         | 2       | 0.5  | 512MB | $10        |
| 5K         | 4       | 1.0  | 1GB   | $25        |
| 10K        | 6       | 1.5  | 2GB   | $50        |

---

### 6. Monitoring Metrics

**Essential metrics:**
- `celery_task_success_total` (counter, by task)
- `celery_task_failure_total` (counter, by task)
- `celery_task_duration_seconds` (histogram, by task)
- `celery_queue_depth` (gauge, by queue)
- `celery_worker_memory_mb` (gauge, by worker)

**Dashboards:** Simple Supabase table + SQL queries (no Grafana complexity)

---

## Research Mandate (Oracle's Superpower)

**CRITICAL:** Do NOT guess. Research production Celery patterns.

### Required Research

1. **Production Celery deployments:**
   - Search: "Celery worker configuration best practices production"
   - Search: "Celery task priorities queues architecture"
   - **Goal:** Find 3-5 real production examples

2. **Solo-dev Celery patterns:**
   - Search: "Celery monitoring alerting solo developer"
   - Search: "Celery memory leaks worker recycling"
   - **Goal:** Find strategies for small teams

3. **Task reliability patterns:**
   - Search: "Celery circuit breaker pattern"
   - Search: "Celery task deduplication idempotency"
   - **Goal:** Proven reliability techniques

4. **Cost optimization:**
   - Search: "Celery worker pool sizing"
   - Search: "Railway Celery deployment cost"
   - **Goal:** Cost-saving strategies

### Citation Format

For every major recommendation, cite source:
```
Recommendation: Use 2 queues (critical + normal)

Rationale: Production Celery deployments at [Company X] separate real-time
tasks from batch tasks to prevent blocking [1]. This pattern is also recommended
in Celery's official docs [2] and used by [Open Source Project Y] [3].

Sources:
[1] https://blog.company.com/celery-at-scale
[2] https://docs.celeryproject.org/en/stable/userguide/routing.html
[3] https://github.com/project/celery-config
```

---

## Success Criteria

Oracle's solution is successful if:

✅ **Reliable:** Tasks complete >99% success rate, self-heal on failures
✅ **Cost-Effective:** Stays under $25/month at 1K users
✅ **Scalable:** Works for 10K users without refactor
✅ **Simple:** Solo dev can debug + maintain without deep Celery expertise
✅ **Research-Backed:** Cites 3+ production examples
✅ **Complete:** Includes config, pseudocode, scaling triggers, monitoring

---

## Submission Instructions

1. **Attach:** `SYSTEM_OVERVIEW.md` + `BACKEND_SPECIFICATION.md`
2. **Paste:** This prompt in its entirety
3. **Request:** "Research production Celery architectures and design optimal worker configuration for our constraints"
4. **Expect:** 2-4 hour turnaround
5. **Output:** Detailed specification with cited sources

---

**Prompt Version:** 1.0
**Created:** 2025-11-12
**Status:** Ready for Oracle submission
