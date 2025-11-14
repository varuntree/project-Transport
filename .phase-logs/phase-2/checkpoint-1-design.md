# Checkpoint 1: Celery App Config + 3 Queues

## Goal
Configure Celery with 3 queues (critical/normal/batch), Beat scheduler, timezone-aware. Worker ready to register tasks (0 tasks initially, no import errors).

## Approach

### Backend Implementation
- Add dependencies to requirements.txt: `celery[redis]==5.3.4`, `redis==5.0.1`, `gtfs-realtime-bindings==1.0.0`
- Create `backend/app/tasks/__init__.py` (mark as package)
- Create `backend/app/tasks/celery_app.py`:
  - Import Celery, settings from app.core.config
  - Configure broker: `broker_url=REDIS_URL` from .env
  - Define `task_routes`: critical queue for RT poller, normal for alerts/APNs, batch for GTFS sync
  - Beat schedule: `poll_gtfs_rt` (30s interval), `sync_gtfs_static` (cron 03:10 Sydney)
  - Config: `task_serializer='json'`, `timezone='Australia/Sydney'`, `enable_utc=False`, `worker_prefetch_multiplier=1`
  - Include tasks: `include=['app.tasks.gtfs_rt_poller']` (will import in Checkpoint 2)

### Critical Pattern
- **Timezone handling:** `enable_utc=False` + `timezone='Australia/Sydney'` ensures DST-safe cron schedules (PHASE_2_REALTIME.md:L133)
- **Prefetch multiplier=1:** Prevents worker A from prefetching multiple critical tasks (singleton pattern requires 1 task at a time)
- **Task routes:** Use dict mapping task names to queues (not routing keys)

## Design Constraints
- Follow BACKEND_SPECIFICATION.md:Section 4.2 for Celery config pattern
- Follow DEVELOPMENT_STANDARDS.md:Section 3 for structlog logging (JSON events)
- Must set `result_backend=None` (we don't store task results, stateless workers)
- Redis URL from .env: `REDIS_URL=redis://localhost:6379/0` (local dev) or Railway connection string

## Risks
- Import error if app.tasks.gtfs_rt_poller doesn't exist yet
  - Mitigation: Use `include=[]` initially, update to `include=['app.tasks.gtfs_rt_poller']` in Checkpoint 2
- Timezone mismatch if enable_utc=True (default)
  - Mitigation: Explicitly set `enable_utc=False` + `timezone='Australia/Sydney'`

## Validation
```bash
# From backend/ directory
celery -A app.tasks.celery_app inspect registered
# Expected: Empty list [] (no tasks registered yet), no import errors

celery -A app.tasks.celery_app inspect scheduled
# Expected: Error (no workers running yet), but celery_app imports successfully
```

## References for Subagent
- Exploration report: `critical_patterns` → "Celery task decorator (time limits, retries, queue routing)"
- Architecture: BACKEND_SPECIFICATION.md:Section 4.2 (Celery config)
- Standards: DEVELOPMENT_STANDARDS.md:Section 3 (structlog JSON logging)
- Example: PHASE_2_REALTIME.md:L161-168 (task decorator example)

## Estimated Complexity
**simple** - Straightforward config file, no business logic
