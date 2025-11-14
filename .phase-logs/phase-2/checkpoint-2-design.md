# Checkpoint 2: GTFS-RT Poller Task (VehiclePositions + TripUpdates)

## Goal
Poll 5 modes × 2 feeds every 30s, parse protobuf, cache gzipped JSON blobs. Redis has 10 keys (vp:* and tu:* for each mode) after 30s.

## Approach

### Backend Implementation
- Create `backend/app/tasks/gtfs_rt_poller.py`
- Task decorator: `@celery_app.task(name='poll_gtfs_rt', queue='critical', bind=True, max_retries=0, time_limit=15, soft_time_limit=10)`
- **Redis SETNX lock:**
  - Try `redis.set('lock:poll_gtfs_rt', 1, nx=True, ex=30)` before execution
  - Skip if lock exists (another worker already running)
  - Release lock after completion (or auto-expires after 30s)
- **Loop modes:**
  ```python
  MODES = ['buses', 'sydneytrains', 'metro', 'ferries', 'lightrail']
  for mode in MODES:
      # Fetch VehiclePositions
      vp_data = fetch_gtfs_rt(mode, 'vehiclepos')
      parsed_vp = parse_vehicle_positions(vp_data)
      cache_blob(redis, f'vp:{mode}:v1', parsed_vp, ttl=75)

      # Fetch TripUpdates
      tu_data = fetch_gtfs_rt(mode, 'realtime')
      parsed_tu = parse_trip_updates(tu_data)
      cache_blob(redis, f'tu:{mode}:v1', parsed_tu, ttl=90)
  ```
- **fetch_gtfs_rt(mode, feed_type):**
  - NSW API: `GET https://api.transport.nsw.gov.au/v1/gtfs/{feed_type}/{mode}`
  - Headers: `{'Authorization': f'apikey {NSW_API_KEY}'}`
  - Timeout: 8s request (NSW API SLA)
  - Handle 429 rate limit (log + skip cycle), 503 NSW downtime (log + skip)
- **parse_vehicle_positions(pb_data):**
  - `from google.transit import gtfs_realtime_pb2`
  - `feed = gtfs_realtime_pb2.FeedMessage(); feed.ParseFromString(pb_data)`
  - Extract: `[{vehicle_id, trip_id, route_id, lat, lon, bearing, speed, timestamp}]`
- **parse_trip_updates(pb_data):**
  - Same protobuf parsing
  - Extract: `[{trip_id, route_id, delay_s, stop_time_updates: [{stop_id, arrival_delay, departure_delay}]}]`
- **cache_blob(redis, key, data, ttl):**
  - `compressed = gzip.compress(json.dumps(data).encode('utf-8'))`
  - `redis.set(key, compressed, ex=ttl)`
- **Logging:**
  - `logger.info('poll_gtfs_rt_started', timestamp=now)`
  - `logger.info('poll_gtfs_rt_complete', modes=MODES, duration_ms=elapsed, vp_count=N, tu_count=M)`

### Critical Pattern
- **Redis SETNX lock:** Idempotency—prevents duplicate polls if worker restarts mid-cycle (PHASE_2_REALTIME.md:L173-178)
- **Gzip compression:** ~70% blob size reduction (DATA_ARCHITECTURE.md:Section 4.5)
- **TTL > poll interval:** 75s/90s TTL > 30s poll ensures no cache misses between cycles

## Design Constraints
- Follow PHASE_2_REALTIME.md:L173-178 for Redis SETNX lock pattern
- Follow PHASE_2_REALTIME.md:L283-287 for gzip blob caching
- NSW API endpoints: NSW_API_REFERENCE.md (GTFS-RT section)
- Must handle protobuf ParseError gracefully (log + skip cycle, don't crash worker)
- Must handle requests.exceptions.Timeout (log + skip mode, continue to next mode)
- Must log structured JSON events (no full protobuf dumps—log counts only)

## Risks
- NSW API 429 rate limit mid-cycle (10 calls/cycle × 2,880 cycles/day = 28.8K calls, within 60K limit)
  - Mitigation: Handle 429 gracefully, log + skip cycle (next cycle in 30s)
- Protobuf schema change breaks parser
  - Mitigation: Catch ParseError, log full error, skip cycle (monitor logs for anomalies)
- Worker timeout (15s hard limit, 10s soft)
  - Mitigation: requests timeout=8s ensures we don't hang, 10 modes × 8s = 80s worst case (TOO LONG)
  - **Design fix:** Parallel fetch with ThreadPoolExecutor (max_workers=5) or sequential with timeout per-mode (skip slow modes)

## Validation
```bash
# Start worker + beat in separate terminals:
# Terminal 1: cd backend && source venv/bin/activate && uvicorn app.main:app --reload
# Terminal 2: cd backend && celery -A app.tasks.celery_app worker -Q critical -c 1 --loglevel=info
# Terminal 3: cd backend && celery -A app.tasks.celery_app beat --loglevel=info

# Wait 30s, then check Redis:
redis-cli KEYS vp:*
# Expected: 5 keys (vp:buses:v1, vp:sydneytrains:v1, vp:metro:v1, vp:ferries:v1, vp:lightrail:v1)

redis-cli KEYS tu:*
# Expected: 5 keys (tu:buses:v1, tu:sydneytrains:v1, tu:metro:v1, tu:ferries:v1, tu:lightrail:v1)

redis-cli GET vp:buses:v1
# Expected: Binary gzipped blob (not human-readable)

redis-cli TTL vp:buses:v1
# Expected: 60-75 seconds remaining

# Check worker logs for structured JSON:
# Expected: poll_gtfs_rt_started, vp_cached, tu_cached, poll_gtfs_rt_complete
```

## References for Subagent
- Exploration patterns: critical_patterns → "Redis SETNX singleton lock", "Gzip blob caching"
- Architecture: BACKEND_SPECIFICATION.md:Section 4.4 (Celery tasks)
- NSW API: NSW_API_REFERENCE.md (GTFS-RT endpoints /gtfs/vehiclepos/{mode}, /gtfs/realtime/{mode})
- Protobuf library: `gtfs-realtime-bindings==1.0.0` (google.transit.gtfs_realtime_pb2)

## Estimated Complexity
**complex** - Protobuf parsing, error handling, Redis lock pattern, NSW API integration, gzip compression
