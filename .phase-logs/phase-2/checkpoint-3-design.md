# Checkpoint 3: Worker Startup Scripts

## Goal
Create bash scripts to start Worker A (critical queue), Worker B (normal+batch queues), Beat scheduler. Scripts executable, start without errors.

## Approach

### Backend Implementation
- Create `backend/scripts/` directory
- Create `backend/scripts/start_worker_critical.sh`:
  ```bash
  #!/bin/bash
  cd "$(dirname "$0")/.."
  celery -A app.tasks.celery_app worker -Q critical -c 1 --loglevel=info
  ```
- Create `backend/scripts/start_worker_service.sh`:
  ```bash
  #!/bin/bash
  cd "$(dirname "$0")/.."
  celery -A app.tasks.celery_app worker -Q normal,batch -c 2 --autoscale=3,1 --loglevel=info
  ```
- Create `backend/scripts/start_beat.sh`:
  ```bash
  #!/bin/bash
  cd "$(dirname "$0")/.."
  celery -A app.tasks.celery_app beat --loglevel=info
  ```
- Make executable: `chmod +x backend/scripts/*.sh`

### Critical Pattern
- **Worker A (-Q critical -c 1):** Singleton concurrency ensures only 1 RT poller runs at a time (no parallel polls)
- **Worker B (-Q normal,batch -c 2 --autoscale=3,1):** Starts with 2 workers, scales to 3 under load (future alerts + APNs)
- **cd to backend/ before celery command:** Ensures imports work (app.tasks.celery_app resolves correctly)

## Design Constraints
- Follow PHASE_2_REALTIME.md:L100-138 for worker configuration
- Worker A: 1 concurrency (singleton RT poller, no parallelism)
- Worker B: 2-3 concurrency (autoscale for normal/batch queue, future alerts + APNs)
- Must cd to backend/ directory (not scripts/) before running celery commands

## Risks
- Script runs from wrong directory → import errors
  - Mitigation: `cd "$(dirname "$0")/.."` changes to backend/ regardless of where script is called
- Missing shebang → not executable
  - Mitigation: Add `#!/bin/bash` to all scripts

## Validation
```bash
cd backend
bash scripts/start_worker_critical.sh
# Expected: Starts without errors, logs show "celery@hostname ready" with queues=[critical]

# Ctrl+C to stop, then test Worker B:
bash scripts/start_worker_service.sh
# Expected: Starts without errors, logs show autoscale config, queues=[normal, batch]

# Ctrl+C to stop, then test Beat:
bash scripts/start_beat.sh
# Expected: Starts without errors, logs show beat scheduler running, lists scheduled tasks (poll_gtfs_rt, sync_gtfs_static)
```

## References for Subagent
- Architecture: BACKEND_SPECIFICATION.md:Section 4.2 (Celery queues)
- Pattern: PHASE_2_REALTIME.md:L100-138 (worker config)

## Estimated Complexity
**simple** - Bash scripts with fixed commands, minimal logic
