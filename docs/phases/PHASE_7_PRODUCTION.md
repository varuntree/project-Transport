# Phase 7: Production Polish & Deployment
**Duration:** 1-2 weeks | **Timeline:** Week 19-20
**Goal:** Deploy to production, monitoring, App Store submission

---

## Overview
- Backend deployment (Railway production)
- Production configs (rate limiting, monitoring)
- iOS TestFlight build
- App Store submission prep
- Monitoring & alerting
- Final polish & bug fixes

---

## User Instructions

### 1. Railway Production Deployment

**Backend:**
1. Railway Dashboard → New Project → "sydney-transit-prod"
2. Add services:
   - FastAPI (connect GitHub repo, auto-deploy on push)
   - Redis (Provision → Redis)
   - Worker A (Celery critical queue)
   - Worker B (Celery service queue)
   - Beat (Celery scheduler)
3. Environment variables (for all services):
   ```
   ENVIRONMENT=production
   LOG_LEVEL=INFO
   SUPABASE_URL=https://...
   SUPABASE_SERVICE_KEY=...
   REDIS_URL=redis://... (Railway internal URL)
   NSW_API_KEY=...
   APNS_* variables
   ```
4. Custom domains:
   - Railway → Settings → Domains → Add `api.yourdomain.com`

**Supabase Production:**
1. Upgrade to paid plan if needed (>500MB data)
2. Enable RLS on all tables
3. Create database indexes (see Phase 1 schema)
4. Backup: Settings → Database → Enable Point-in-Time Recovery

### 2. Cloudflare Setup (Optional)
1. Add domain to Cloudflare
2. DNS: CNAME `api` → `railway.app` (proxied)
3. WAF rule: Rate limit 600 req/min per IP (see BACKEND_SPEC Section 6)

### 3. iOS Production Build
1. Xcode → Product → Archive
2. Distribute → App Store Connect
3. TestFlight: Add internal testers
4. App Store submission:
   - Screenshots (6.7", 6.5", 5.5" required)
   - App description
   - Keywords: "Sydney, transit, trains, buses, real-time"
   - Privacy policy URL (host on GitHub Pages)

---

## Implementation Checklist

### Backend Production Hardening

**1. Health Check Endpoint (enhance app/main.py)**
```python
@app.get("/health")
async def health_check():
    """Comprehensive health check for monitoring."""
    checks = {
        'status': 'healthy',
        'services': {}
    }

    # Check Supabase
    try:
        supabase = get_supabase()
        supabase.table('stops').select('id').limit(1).execute()
        checks['services']['database'] = 'connected'
    except Exception as exc:
        checks['services']['database'] = f'error: {exc}'
        checks['status'] = 'unhealthy'

    # Check Redis
    try:
        redis_client = get_redis()
        redis_client.ping()
        checks['services']['cache'] = 'connected'
    except Exception as exc:
        checks['services']['cache'] = f'error: {exc}'
        checks['status'] = 'unhealthy'

    # Check Celery workers (check last poll time)
    try:
        last_poll = redis_client.get('last_gtfs_rt_poll')
        if last_poll:
            age_secs = time.time() - float(last_poll)
            checks['services']['celery'] = 'healthy' if age_secs < 120 else f'stale ({age_secs}s)'
        else:
            checks['services']['celery'] = 'no_data'
    except Exception as exc:
        checks['services']['celery'] = f'error: {exc}'

    status_code = 200 if checks['status'] == 'healthy' else 503
    return JSONResponse(status_code=status_code, content=checks)
```

**2. Metrics Endpoint (app/main.py)**
```python
@app.get("/metrics")
async def metrics():
    """Prometheus-compatible metrics."""
    redis_client = get_redis()
    supabase = get_supabase()

    # API call counters
    api_calls_today = redis_client.get('api_calls_today') or 0

    # Database size
    db_size_result = supabase.rpc('exec_raw_sql', {'query': 'SELECT pg_database_size(current_database());'}).execute()
    db_size_mb = db_size_result.data[0]['pg_database_size'] / 1024 / 1024 if db_size_result.data else 0

    # Redis memory
    redis_info = redis_client.info('memory')
    redis_memory_mb = redis_info['used_memory'] / 1024 / 1024

    metrics_output = f"""
# API Calls
api_calls_today {api_calls_today}

# Database size (MB)
database_size_mb {db_size_mb}

# Redis memory (MB)
redis_memory_mb {redis_memory_mb}
    """

    return Response(content=metrics_output, media_type='text/plain')
```

**3. Rate Limiting (enhance with SlowAPI)**
Add to `requirements.txt`:
```txt
slowapi==0.1.9
```

In `app/main.py`:
```python
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address, storage_uri=settings.REDIS_URL)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Apply to endpoints
@router.get("/stops/nearby")
@limiter.limit("60/minute")  # Anonymous users
async def get_nearby_stops(...):
    pass

@router.post("/trips/plan")
@limiter.limit("10/minute")  # Expensive endpoint
async def plan_trip(...):
    pass
```

**4. Error Tracking (Sentry)**
Add to `requirements.txt`:
```txt
sentry-sdk[fastapi]==1.40.0
```

In `app/main.py`:
```python
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration

if settings.ENVIRONMENT == 'production':
    sentry_sdk.init(
        dsn=settings.SENTRY_DSN,
        integrations=[FastApiIntegration()],
        traces_sample_rate=0.1,  # 10% of requests
        environment='production'
    )
```

**5. Cost Monitoring SQL View (Supabase)**
(From DATA_ARCHITECTURE.md Section 9)

```sql
CREATE VIEW cost_metrics AS
SELECT
    'api_calls_today' AS metric,
    COUNT(*) AS value,
    DATE(created_at) AS date
FROM notification_log
WHERE created_at >= CURRENT_DATE
UNION ALL
SELECT
    'db_size_mb',
    pg_database_size(current_database()) / 1024 / 1024,
    CURRENT_DATE
UNION ALL
SELECT
    'active_users',
    COUNT(DISTINCT user_id),
    CURRENT_DATE
FROM favorites;

-- Alert if approaching limits
CREATE OR REPLACE FUNCTION check_cost_alerts()
RETURNS TABLE(alert_type TEXT, current_value NUMERIC, threshold NUMERIC) AS $$
BEGIN
    -- DB size approaching 500MB (free tier)
    IF (SELECT pg_database_size(current_database()) / 1024 / 1024) > 400 THEN
        RETURN QUERY SELECT 'db_size_warning', (SELECT pg_database_size(current_database()) / 1024 / 1024), 500::NUMERIC;
    END IF;

    -- NSW API calls approaching 60K/day
    IF (SELECT COUNT(*) FROM notification_log WHERE created_at >= CURRENT_DATE) > 48000 THEN
        RETURN QUERY SELECT 'api_calls_warning', (SELECT COUNT(*) FROM notification_log WHERE created_at >= CURRENT_DATE), 60000::NUMERIC;
    END IF;
END;
$$ LANGUAGE plpgsql;
```

---

### iOS Production Build

**6. Release Configuration**
- [ ] Xcode → Edit Scheme → Run → Build Configuration → Release
- [ ] App Icons (all sizes in Assets.xcassets)
- [ ] Launch Screen
- [ ] Privacy Policy URL in Config.plist:
  ```xml
  <key>API_BASE_URL</key>
  <string>https://api.yourdomain.com/api/v1</string>
  ```

**7. App Store Metadata**
- **Name:** Sydney Transit
- **Subtitle:** Real-time trains, buses, ferries
- **Description:**
  ```
  Sydney Transit provides real-time departures for all Sydney public transport modes:
  - Live train, bus, ferry, light rail departures
  - Trip planner with real-time delays
  - Service alerts and push notifications
  - Offline browsing of stops and routes
  - Clean, fast, iOS-native experience

  No ads. No tracking. Just transit data.
  ```
- **Keywords:** sydney,transit,trains,buses,ferry,lightrail,metro,realtime,departures
- **Category:** Navigation
- **Age Rating:** 4+
- **Privacy:** No data collection beyond favorites (synced via iCloud)

**8. TestFlight Build**
```bash
# Archive app
xcodebuild -workspace SydneyTransit.xcworkspace -scheme SydneyTransit -configuration Release archive

# Upload to TestFlight
# (or use Xcode Organizer → Distribute App → App Store Connect)
```

---

## Acceptance Criteria

**Backend:**
- [ ] Deployed to Railway production
- [ ] `/health` returns 200 (all services connected)
- [ ] `/metrics` returns Prometheus format
- [ ] Rate limiting works (429 after limit exceeded)
- [ ] Sentry captures errors
- [ ] Celery workers running (check Railway logs)

**iOS:**
- [ ] TestFlight build available
- [ ] Beta testers can install
- [ ] All features work in production
- [ ] No crashes (check Xcode Organizer → Crashes)

**Monitoring:**
- [ ] Uptime monitor (UptimeRobot or similar) pings `/health` every 5 min
- [ ] Cost alerts configured (SQL view `check_cost_alerts()`)
- [ ] Railway usage <$25/month (check dashboard)

**App Store:**
- [ ] Submitted for review
- [ ] Screenshots uploaded
- [ ] Privacy policy hosted

---

## Post-Launch Checklist

**Week 1:**
- [ ] Monitor Sentry for errors
- [ ] Check Railway costs daily
- [ ] Respond to TestFlight feedback
- [ ] Fix critical bugs (hotfix if needed)

**Week 2:**
- [ ] App Store approval (7-14 days typical)
- [ ] Public launch (share on Reddit /r/sydney)
- [ ] Monitor analytics (App Store Connect)
- [ ] Plan Phase 8 features (widgets, live activities)

---

## Monitoring Dashboards

**Railway:**
- Services → Metrics → CPU, Memory, Network
- Set alerts: CPU >80%, Memory >90%

**Supabase:**
- Database → Usage → Storage, Bandwidth
- Alert at 450MB DB size (90% of free tier)

**App Store Connect:**
- App Analytics → Impressions, Downloads, Retention
- Crashes & Energy → Monitor crash rate (<1% target)

---

## Rollback Plan

**If production issues:**
1. Railway → Deployments → Rollback to previous
2. iOS: Release hotfix build via TestFlight (expedited review: 1-2 days)
3. Disable features via feature flags (add `features` table in DB)

---

## Success Metrics (30 Days Post-Launch)

**Technical:**
- [ ] Uptime >99.5%
- [ ] API p95 latency <500ms
- [ ] Cost <$25/month
- [ ] Crash rate <1%

**Product:**
- [ ] 100+ downloads (organic)
- [ ] 4.0+ stars (App Store)
- [ ] 60% week-1 retention
- [ ] 5+ GitHub stars (if open-sourced)

---

## Next Steps (Post-MVP)

**Phase 8 Ideas:**
- Widgets (Home Screen, Lock Screen)
- Live Activities (Dynamic Island)
- Multi-language (i18n)
- Advanced analytics
- Open-source release

---

**End of PHASE_7_PRODUCTION.md**

---

# 🎉 All Phases Complete!

You now have:
- **DEVELOPMENT_STANDARDS.md** (coding patterns)
- **IMPLEMENTATION_ROADMAP.md** (7-phase overview)
- **8 Phase Plans** (Phase 0-7, detailed instructions)

**Total Deliverable:** Complete working Sydney Transit MVP in 14-20 weeks.

Start with Phase 0 when ready. Good luck! 🚀
