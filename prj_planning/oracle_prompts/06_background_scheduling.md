# ORACLE PROMPT: Background Job Scheduling Strategy

**Consultation ID:** 06_background_scheduling
**Context Document:** Attach `SYSTEM_OVERVIEW.md` + `BACKEND_SPECIFICATION.md`
**Priority:** HIGH - Directly impacts cost and reliability
**Expected Consultation Time:** 1-3 hours (with research)

---

## Context Summary

**App:** Sydney transit app - iOS + FastAPI backend
**Users:** 0 initially → 1K (6 months) → 10K (12 months)
**Developer:** Solo, no team, no 24/7 monitoring
**Budget:** $25/month MVP → scale with users

---

## Fixed Tech Stack (DO NOT CHANGE)

- **Backend:** FastAPI (Python 3.11+) + Celery Beat scheduler
- **Message Broker:** Redis (Railway or Upstash)
- **Time Zone:** Australia/Sydney (UTC+10, UTC+11 during DST)
- **Hosting:** Railway or Fly.io

**NO new external services allowed.**

---

## Problem Statement

Design optimal Celery Beat schedule that:

1. **Prevents overlapping runs** - Long tasks don't pile up
2. **Avoids bill explosion** - No runaway schedules, clear frequency limits
3. **Handles time zones** - DST transitions (Sydney observes DST)
4. **Self-heals** - Missed schedules recover gracefully
5. **Solo-dev friendly** - Easy to monitor, debug at 3am

---

## Current Schedule (Needs Oracle Validation)

```python
# app/celerybeat_schedule.py
from celery.schedules import crontab
import pytz

SYDNEY_TZ = pytz.timezone('Australia/Sydney')

CELERYBEAT_SCHEDULE = {
    # GTFS Static Sync (daily at 3am Sydney time)
    'gtfs-static-sync': {
        'task': 'app.workers.gtfs_static_sync.run',
        'schedule': crontab(hour=3, minute=0),  # ⚠️ Does this handle DST correctly?
        'options': {'expires': 7200},            # Expire if not run within 2h
    },

    # GTFS-RT Polling (every 15s, adaptive logic inside task)
    'gtfs-rt-poll': {
        'task': 'app.workers.gtfs_rt_poller.poll_gtfs_rt_feeds',
        'schedule': 15.0,  # seconds
        'options': {'expires': 30},  # Expire if not run within 30s
    },

    # Alert Matching (every 2 min during peak, every 5 min off-peak)
    'alert-matcher-peak': {
        'task': 'app.workers.alert_matcher.match_delays_to_favorites',
        'schedule': crontab(minute='*/2', hour='7-9,17-19'),  # Peak hours
    },
    'alert-matcher-offpeak': {
        'task': 'app.workers.alert_matcher.match_delays_to_favorites',
        'schedule': crontab(minute='*/5', hour='0-6,10-16,20-23'),  # Off-peak
    },

    # Cost Monitoring (hourly)
    'cost-check': {
        'task': 'app.workers.cost_monitor.check_cost_limits',
        'schedule': crontab(minute=10),  # Every hour at :10
    },

    # Usage Rollup (hourly)
    'usage-rollup': {
        'task': 'app.workers.usage.rollup_usage_hourly',
        'schedule': crontab(minute=5),  # Every hour at :05
    },

    # Storage Cleanup (weekly, Sunday 2am)
    'storage-cleanup': {
        'task': 'app.workers.cleanup.cleanup_old_gtfs_files',
        'schedule': crontab(hour=2, minute=0, day_of_week=0),
    },

    # MV Refresh (daily at 3:30am, after GTFS sync completes)
    'refresh-materialized-views': {
        'task': 'app.workers.db_maintenance.refresh_mvs',
        'schedule': crontab(hour=3, minute=30),
    },
}
```

---

## Questions for Oracle

### 1. Time Zone Handling

**Question:** How to handle Sydney DST transitions in Celery Beat?

**Context:**
- Sydney observes DST: UTC+11 (Oct-Apr), UTC+10 (Apr-Oct)
- DST starts: First Sunday in October at 2am → 3am (spring forward)
- DST ends: First Sunday in April at 3am → 2am (fall back)

**Problem scenarios:**
- Task scheduled for 2:30am on DST start day: What happens? (2:30am doesn't exist)
- Task scheduled for 2:30am on DST end day: Runs twice? (2am-3am repeats)

**Current approach:**
```python
# Option A: Use timezone-aware crontab
schedule = crontab(hour=3, minute=0, tz=pytz.timezone('Australia/Sydney'))

# Option B: Run Beat in Sydney TZ (set container TZ)
# In Dockerfile: ENV TZ=Australia/Sydney

# Option C: Run Beat in UTC, calculate Sydney offsets manually
# (Too complex, error-prone)
```

**Questions:**
- Best practice for timezone-aware Celery Beat?
- Does `tz=SYDNEY_TZ` in crontab handle DST correctly?
- Should we avoid scheduling tasks between 2-3am (DST danger zone)?
- How to test DST transitions without waiting a year?

---

### 2. Task Overlap Prevention

**Question:** How to prevent long-running tasks from overlapping?

**Scenario:**
- `gtfs_static_sync` scheduled daily at 3am
- Normally completes in 20-30 min
- One day, takes 90 min (network slow, large data)
- Next day at 3am: New run starts while previous still running → waste resources, race conditions

**Patterns to consider:**

**Pattern A: Redis lock (manual)**
```python
@app.task
def gtfs_static_sync():
    lock_key = f"lock:gtfs_sync:{date.today()}"
    if not redis.set(lock_key, "locked", nx=True, ex=7200):
        logger.info("Sync already running, skipping")
        return
    try:
        do_sync()
    finally:
        redis.delete(lock_key)
```

**Pattern B: Celery's `task_id` + state check**
```python
from celery.result import AsyncResult

@app.task
def gtfs_static_sync():
    # Check if previous run still active
    previous_id = redis.get("last_sync_task_id")
    if previous_id:
        result = AsyncResult(previous_id)
        if result.state in ["PENDING", "STARTED"]:
            logger.info("Previous sync still running")
            return
    # Run sync
    ...
```

**Pattern C: Single-instance queue**
```python
# In Beat schedule
'gtfs-static-sync': {
    'task': '...',
    'schedule': crontab(...),
    'options': {
        'queue': 'gtfs_sync_singleton',  # Dedicated queue
        'expires': 3600,                  # Expire if not picked up in 1h
    },
}

# Worker config: Only 1 worker for this queue, concurrency=1
# celery -A app worker -Q gtfs_sync_singleton --concurrency=1
```

**Questions:**
- Which pattern is most reliable?
- Should we use combination (lock + single queue)?
- How to alert if task runs longer than expected (>60 min)?

---

### 3. Peak vs Off-Peak Scheduling

**Question:** Should we reduce task frequency at night to save costs?

**Current thinking:**
- **Peak (7-9am, 5-7pm):** Users active, need fresh data
  - GTFS-RT polling: Every 30s
  - Alert matching: Every 2 min
- **Off-peak (midnight-5am):** Few users, can be lazy
  - GTFS-RT polling: Every 60-90s
  - Alert matching: Every 5-10 min (or skip entirely?)

**Implementation options:**

**Option A: Multiple schedules (current approach)**
```python
'alert-matcher-peak': {
    'schedule': crontab(minute='*/2', hour='7-9,17-19'),
},
'alert-matcher-offpeak': {
    'schedule': crontab(minute='*/5', hour='0-6,10-16,20-23'),
},
```
*Pro:* Simple, declarative
*Con:* Two schedule entries for same task

**Option B: Single schedule, conditional logic in task**
```python
'alert-matcher': {
    'schedule': crontab(minute='*/2'),  # Always run every 2 min
},

# Inside task
@app.task
def match_delays():
    now = datetime.now(SYDNEY_TZ)
    if now.hour not in {7,8,9,17,18,19}:
        # Off-peak: skip or run light version
        logger.info("Off-peak, skipping alert matching")
        return
    # Peak: run full matching
    ...
```
*Pro:* Single schedule entry
*Con:* Task runs unnecessarily (scheduled but exits early)

**Option C: Dynamic schedule (Celery redbeat)**
```python
# Use celery-redbeat to store schedule in Redis
# Modify schedule at runtime based on time of day
# (More complex, requires external library)
```

**Questions:**
- Best pattern for peak/off-peak scheduling?
- Is it worth the complexity? (Cost savings minimal for 15s → 60s change)
- Should we just run all tasks at same frequency (simpler)?

---

### 4. Failure Recovery

**Question:** How to handle missed schedules (Beat crashes, restarts)?

**Scenarios:**
- Beat process crashes at 2:50am, restarts at 3:10am
  - `gtfs_static_sync` (scheduled 3am) missed → Run immediately? Skip?
- Beat misses 4 consecutive `gtfs_rt_poll` runs (1 min gap)
  - Catch up (run 4 times immediately)? Skip missed runs?

**Celery Beat behavior (default):**
- Missed tasks are **NOT** run retroactively
- Beat only schedules future runs based on current time
- No built-in "catch-up" mechanism

**Patterns to handle:**

**Pattern A: Health check task (detect Beat failures)**
```python
'beat-heartbeat': {
    'task': 'app.workers.monitoring.beat_heartbeat',
    'schedule': 60.0,  # Every minute
},

# Task writes timestamp to Redis
@app.task
def beat_heartbeat():
    redis.set("beat:last_heartbeat", int(time.time()), ex=300)

# Separate monitoring checks this
def check_beat_health():
    last = int(redis.get("beat:last_heartbeat") or 0)
    if time.time() - last > 180:  # 3 min without heartbeat
        alert("Celery Beat is down!")
```

**Pattern B: Idempotent tasks + "last run" tracking**
```python
@app.task
def gtfs_static_sync():
    last_run = redis.get("gtfs:last_sync_date")
    if last_run == date.today().isoformat():
        logger.info("Sync already completed today")
        return
    # Run sync
    do_sync()
    redis.set("gtfs:last_sync_date", date.today().isoformat())
```
*If Beat misses 3am run but recovers at 4am, task can be manually triggered and will run once.*

**Questions:**
- How important is missed-run recovery for our tasks?
- `gtfs_static_sync` missing a day: Critical? (Users see stale schedule)
- `gtfs_rt_poll` missing 1 min: Acceptable? (Cache serves stale for 60s anyway)
- Should we alert on missed runs or rely on health checks?

---

### 5. Task Chaining & Dependencies

**Question:** Should related tasks be chained or independent?

**Current independent tasks:**
```python
# These run independently at different times
3:00am → gtfs_static_sync (download + parse + load to DB)
3:30am → refresh_materialized_views (depends on sync completing)
         generate_ios_sqlite (depends on DB refresh)
4:00am → upload_to_cdn (depends on SQLite generation)
```

**Problem:** If `gtfs_static_sync` takes 45 min (slow day), `refresh_mvs` at 3:30am runs on stale data.

**Option A: Celery Canvas (chain tasks)**
```python
from celery import chain

'gtfs-pipeline': {
    'schedule': crontab(hour=3, minute=0),
    'task': 'app.workers.run_gtfs_pipeline',
},

@app.task
def run_gtfs_pipeline():
    # Chain: sync → refresh_mvs → generate_sqlite → upload_cdn
    workflow = chain(
        gtfs_static_sync.s(),
        refresh_materialized_views.s(),
        generate_ios_sqlite.s(),
        upload_to_cdn.s()
    )
    workflow.apply_async()
```
*Pro:* Guarantees order, handles dependencies
*Con:* More complex, single failure breaks entire chain

**Option B: Keep independent, add delays/dependencies**
```python
'gtfs-static-sync': {
    'schedule': crontab(hour=3, minute=0),
},
'refresh-mvs': {
    'schedule': crontab(hour=4, minute=0),  # 1h buffer
},
# If sync takes <60 min, MVs run on fresh data
# If sync takes >60 min, MVs wait (or skip if overlap detected)
```

**Questions:**
- Best pattern for task dependencies in Celery Beat?
- Should we chain or keep independent?
- How to handle failure in middle of chain (retry entire chain? Resume from failure?)?

---

### 6. Bill Explosion Safeguards

**Question:** How to prevent runaway schedules from exploding costs?

**Nightmare scenarios:**
- Developer typo: `schedule=0.1` instead of `schedule=10.0` → 10 tasks/second → millions/day
- Bug in task: Infinite loop, never completes, new tasks keep queuing
- Beat misconfiguration: Schedules task every second instead of every hour

**Safeguards needed:**

**Safeguard A: Schedule validation**
```python
# Validate schedule config on startup
def validate_schedule(schedule_config):
    for name, config in schedule_config.items():
        sched = config['schedule']
        if isinstance(sched, (int, float)):
            assert sched >= 10, f"{name}: Schedule too frequent (min 10s)"
        # Add more validations...
```

**Safeguard B: Task invocation limits**
```python
# Track task invocations, alert if excessive
@app.task
def monitored_task():
    key = f"invocations:{self.name}:{datetime.utcnow():%Y%m%d%H}"
    count = redis.incr(key)
    redis.expire(key, 3600)

    if count > 1000:  # Max 1000 invocations/hour
        alert(f"Task {self.name} invoked {count} times in 1 hour!")
        raise Exception("Task invocation limit exceeded")

    do_work()
```

**Safeguard C: Beat health monitoring**
```python
# Monitor Beat's schedule file for changes
# Alert if schedule modified (manual change or deploy issue)
```

**Questions:**
- Which safeguards are essential vs paranoid?
- Should we implement rate limiting on Beat itself?
- How to test these safeguards (simulate runaway schedule)?

---

## Expected Output Format

### 1. Validated Schedule Configuration

```python
# Provide complete, production-ready schedule with:
# - Correct timezone handling
# - Overlap prevention
# - Peak/off-peak optimization
# - Failure recovery patterns

CELERYBEAT_SCHEDULE = {
    'gtfs-static-sync': {
        'task': '...',
        'schedule': ...,
        'options': {...},
    },
    # ... (all tasks)
}
```

---

### 2. DST Transition Handling Guide

**Table of edge cases:**

| Scenario                      | Date                | Time      | Expected Behavior |
|-------------------------------|---------------------|-----------|-------------------|
| DST starts (spring forward)   | Oct 6, 2025         | 2am→3am   | ?                 |
| Task at 2:30am on DST start   | Oct 6, 2025, 2:30am | (missing) | Skip? Run at 3:30am? |
| DST ends (fall back)          | Apr 6, 2025         | 3am→2am   | ?                 |
| Task at 2:30am on DST end     | Apr 6, 2025, 2:30am | (repeats) | Run once? Twice?  |

---

### 3. Overlap Prevention Recommendation

**Recommended pattern** (with code example):
```python
# Best practice for preventing overlaps
```

---

### 4. Monitoring & Alerting

**Metrics to track:**
- `beat_schedule_runs_total` (counter, by task)
- `beat_schedule_miss_total` (counter, by task)
- `beat_task_overlap_detected` (counter, by task)

**Alerts:**
- Beat heartbeat missing >3 min
- Task overlaps detected (same task running twice)
- Task invocations >1000/hour

---

### 5. Cost Projection

| Schedule Frequency         | Tasks/Hour | Tasks/Day | Tasks/Month | Worker Hours/Month | Cost/Month |
|----------------------------|------------|-----------|-------------|-------------------|------------|
| Current (all tasks)        | ~250       | ~6,000    | ~180,000    | ~15h              | $15        |
| Peak-optimized             | ~200       | ~4,800    | ~144,000    | ~12h              | $12        |
| Aggressive (not recommended)| ~400       | ~9,600    | ~288,000    | ~24h              | $25        |

---

## Research Mandate

### Required Research

1. **Celery Beat timezone handling:**
   - Search: "Celery Beat timezone DST transitions"
   - Search: "Celery crontab tz parameter DST"
   - **Goal:** Definitive guide on DST handling

2. **Task overlap prevention:**
   - Search: "Celery prevent task overlap concurrent runs"
   - Search: "Celery task deduplication Redis lock"
   - **Goal:** Production patterns for singleton tasks

3. **Schedule reliability:**
   - Search: "Celery Beat failure recovery missed schedules"
   - Search: "Monitor Celery Beat health"
   - **Goal:** How production systems handle Beat failures

### Citation Format

```
Recommendation: Use `tz=pytz.timezone('Australia/Sydney')` in crontab

Rationale: Celery's crontab scheduler with tz parameter correctly handles
DST transitions per official docs [1]. Production deployments at [Company X]
use this pattern successfully [2].

Sources:
[1] https://docs.celeryproject.org/en/stable/userguide/periodic-tasks.html
[2] https://blog.company.com/celery-timezone-handling
```

---

## Success Criteria

✅ **Reliable:** Schedules run on time, missed runs handled gracefully
✅ **Cost-Safe:** No runaway schedules, clear frequency limits
✅ **DST-Safe:** Handles Sydney DST transitions correctly
✅ **Simple:** Solo dev can understand schedule config
✅ **Monitorable:** Clear alerts when schedules fail
✅ **Complete:** Production-ready config with safeguards

---

**Prompt Version:** 1.0
**Created:** 2025-11-12
**Status:** Ready for Oracle submission
