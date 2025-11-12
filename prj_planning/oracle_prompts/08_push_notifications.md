# ORACLE PROMPT 08: Push Notification Architecture (APNs)

**Consultation ID:** 08
**Topic:** APNs Worker Design & Alert Matching Strategy
**Priority:** Medium (Phase 1 feature, but non-blocking for MVP launch)
**Estimated Complexity:** Medium
**Expected Output:** Production-ready APNs architecture with alert matching logic

---

## Context Summary

**App:** Sydney transit app - TripView reliability + Transit features + iOS polish
**Users:** 0 initially → 1K (6mo) → 10K (12mo)
**Developer:** Solo, no team
**Budget:** $25/month MVP → scale with users

## Fixed Tech Stack (DO NOT CHANGE)

- **Backend:** FastAPI (Python) + Celery workers
- **Database:** Supabase (PostgreSQL + Auth + Storage, 500MB free tier)
- **Cache:** Redis (Railway managed)
- **iOS:** Swift/SwiftUI, iOS 16+, MVVM
- **Hosting:** Railway/Fly.io (backend), Vercel (marketing site)
- **Push:** Apple Push Notification service (APNs) - no FCM, no third-party services

## Constraints (CRITICAL - Oracle must respect these)

1. **Simplicity First:** 0 users initially, avoid premature optimization
2. **No New Services:** Use only planned stack (Supabase, Redis, Railway/Fly.io, APNs)
3. **Cost Conscious:** Maximize free tiers, provide early warnings before cost spikes
4. **Solo Developer:** Easy to maintain, self-healing systems preferred
5. **Modular:** Must support future scaling without full rewrite

---

## Problem Statement

**Goal:** Design reliable, efficient push notification system for transit service alerts

**Use Case:**
1. User favorites stops/routes in iOS app
2. NSW GTFS-RT feed reports delay/cancellation affecting favorited stop/route
3. Backend matches alert to user's favorites
4. Backend sends push notification to user's device
5. User taps notification → iOS app opens to alert details

**Challenges:**
- Alert matching at scale (what if 1,000 users favorite same stop?)
- APNs rate limits & best practices
- Deduplication (don't spam user with 5 notifications for same delay)
- Battery efficiency (don't wake device unnecessarily)
- Delivery guarantees (critical alerts must arrive)

---

## Current Architecture (Needs Oracle Validation)

### Data Model (Supabase PostgreSQL)

```sql
-- User devices (iOS APNs tokens)
CREATE TABLE user_devices (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  apns_token TEXT NOT NULL UNIQUE,
  device_id TEXT NOT NULL,  -- iOS vendor identifier
  platform TEXT NOT NULL DEFAULT 'ios',
  app_version TEXT NOT NULL,
  os_version TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_active_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_user_devices_user ON user_devices(user_id) WHERE is_active = TRUE;
CREATE INDEX idx_user_devices_token ON user_devices(apns_token) WHERE is_active = TRUE;

-- User favorites (stops/routes they care about)
CREATE TABLE favorites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  stop_id TEXT,  -- GTFS stop_id
  route_id TEXT,  -- GTFS route_id (optional, can favorite entire route)
  label TEXT,  -- User-defined name ("Home", "Work")
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sort_order INT NOT NULL DEFAULT 0,
  CONSTRAINT favorite_target CHECK (stop_id IS NOT NULL OR route_id IS NOT NULL)
);

CREATE INDEX idx_favorites_user ON favorites(user_id);
CREATE INDEX idx_favorites_stop ON favorites(stop_id) WHERE stop_id IS NOT NULL;
CREATE INDEX idx_favorites_route ON favorites(route_id) WHERE route_id IS NOT NULL;

-- Notification history (track what we've sent, prevent dupes)
CREATE TABLE notification_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alert_id TEXT NOT NULL,  -- GTFS alert ID
  route_id TEXT,
  stop_id TEXT,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  apns_id UUID,  -- APNs notification identifier (for tracking)
  delivery_status TEXT,  -- 'sent', 'failed', 'token_invalid'
  UNIQUE(user_id, alert_id)  -- Prevent duplicate notifications for same alert
);

CREATE INDEX idx_notif_history_user_sent ON notification_history(user_id, sent_at DESC);
CREATE INDEX idx_notif_history_alert ON notification_history(alert_id);
```

### Celery Task Flow (Current Draft)

```python
# app/workers/alert_matcher.py
from celery import shared_task
from app.services.nsw_gateway import call_nsw_fast
from app.db import get_supabase

@shared_task(queue="normal", soft_time_limit=20, time_limit=30)
def match_alerts_to_favorites():
    """
    Run every 2-5 min (peak/off-peak) by Celery Beat.
    Matches GTFS-RT alerts to user favorites and enqueues APNs tasks.
    """
    # 1. Fetch active alerts from NSW GTFS-RT (cached in Redis)
    alerts = get_active_alerts_from_cache()  # Redis key: "alerts:active"

    # 2. For each alert, find affected users
    for alert in alerts:
        affected_routes = alert.get("informed_entity", [])
        affected_stops = [e["stop_id"] for e in affected_routes if "stop_id" in e]
        affected_route_ids = [e["route_id"] for e in affected_routes if "route_id" in e]

        # Query Supabase: users who favorited affected stops/routes
        supabase = get_supabase()
        users = supabase.table("favorites") \
            .select("user_id") \
            .or_(f"stop_id.in.({','.join(affected_stops)}),route_id.in.({','.join(affected_route_ids)})") \
            .execute()

        user_ids = {row["user_id"] for row in users.data}

        # 3. Check notification_history to avoid dupes
        for user_id in user_ids:
            already_sent = supabase.table("notification_history") \
                .select("id") \
                .eq("user_id", user_id) \
                .eq("alert_id", alert["id"]) \
                .execute()

            if already_sent.data:
                continue  # Skip, already notified

            # 4. Enqueue APNs task
            send_alert_notification.delay(
                user_id=user_id,
                alert_id=alert["id"],
                alert_data=alert
            )


@shared_task(queue="normal", soft_time_limit=8, time_limit=12, max_retries=3)
def send_alert_notification(user_id: str, alert_id: str, alert_data: dict):
    """
    Send push notification to user's device(s).
    """
    supabase = get_supabase()

    # 1. Get user's active devices
    devices = supabase.table("user_devices") \
        .select("apns_token") \
        .eq("user_id", user_id) \
        .eq("is_active", True) \
        .execute()

    if not devices.data:
        return  # User has no active devices

    # 2. Build APNs payload
    payload = {
        "aps": {
            "alert": {
                "title": alert_data["header_text"]["translation"][0]["text"],
                "body": alert_data["description_text"]["translation"][0]["text"]
            },
            "sound": "default",
            "badge": 1,
            "category": "SERVICE_ALERT",
            "thread-id": alert_data["id"]  # Group notifications by alert
        },
        "alert_id": alert_id,
        "route_id": alert_data.get("informed_entity", [{}])[0].get("route_id"),
        "deep_link": f"transitapp://alerts/{alert_id}"
    }

    # 3. Send to APNs
    for device in devices.data:
        try:
            response = send_to_apns(
                token=device["apns_token"],
                payload=payload,
                apns_id=str(uuid.uuid4()),
                collapse_id=alert_id  # Collapse multiple notifs for same alert
            )

            # 4. Record in notification_history
            supabase.table("notification_history").insert({
                "user_id": user_id,
                "alert_id": alert_id,
                "route_id": payload.get("route_id"),
                "apns_id": response.get("apns-id"),
                "delivery_status": "sent"
            }).execute()

        except APNsInvalidTokenError:
            # Mark device as inactive
            supabase.table("user_devices") \
                .update({"is_active": False}) \
                .eq("apns_token", device["apns_token"]) \
                .execute()
```

---

## Questions for Oracle

### 1. Alert Matching Strategy

**Current approach:** Query Supabase `favorites` table for each alert

**Concerns:**
- If 500 users favorite "Central Station" and there's a delay → 500 individual APNs tasks?
- Query performance at scale (10K users, hundreds of favorites)?
- Should we cache favorites in Redis (per-stop/route reverse index)?

**Options:**
- **A) Database query per alert** (current, simple but potentially slow)
- **B) Redis reverse index** (`stop:200060:users` → set of user IDs)
- **C) Materialized view** (precomputed `alert_entity` → `user_ids`)
- **D) Event-driven** (Redis pub/sub, subscribe users to stop/route channels)

**Oracle: Which pattern is best for our scale (0→10K users) and constraints?**

### 2. APNs Worker Design

**Current approach:** One Celery task per user

**Concerns:**
- Apple recommends batching/pipelining over HTTP/2
- Rate limits? (Apple doesn't publish hard limits but recommends "reasonable" rates)
- Should we batch notifications (e.g., 100 users per task)?

**Questions:**
- **Batch size:** Send 1 notification per task, or batch (e.g., 50-100)?
- **Connection pooling:** Reuse HTTP/2 connection across tasks?
- **Error handling:** 400/410 (invalid token) → mark device inactive; 429/5xx → retry with backoff?
- **Retry strategy:** How many retries? Exponential backoff + jitter?

**Oracle: What's the production-proven APNs worker pattern for Python + Celery?**

### 3. Deduplication & Collapse

**Current approach:**
- `notification_history` table with `UNIQUE(user_id, alert_id)`
- `collapse_id` in APNs payload (groups notifications on device)

**Concerns:**
- User favorites 3 stops on same route → 1 alert affects all 3 → send 1 notification or 3?
- `collapse_id` only works if notifications arrive while device locked; if user reads first, collapse doesn't help

**Questions:**
- **Grouping logic:** Collapse by `alert_id` (current) or by `route_id` or by `stop_id`?
- **Window:** Don't send another notification for same alert within X minutes?
- **User control:** Let user choose notification frequency (immediate, hourly digest, daily)?

**Oracle: What's the best deduplication strategy for transit alerts?**

### 4. Delivery Guarantees & Tracking

**Current approach:** Fire-and-forget (send to APNs, record in history)

**Concerns:**
- APNs doesn't guarantee delivery (device offline, etc.)
- Should we track delivery status? (APNs provides feedback but async)
- Critical vs non-critical alerts (cancellation vs minor delay)?

**Questions:**
- **Delivery tracking:** Should we poll APNs feedback service? Or ignore (too complex for MVP)?
- **Priority:** Use `apns-priority` header (5=immediate, 10=background)?
  - Cancellations → priority 10 (immediate)?
  - Minor delays → priority 5 (battery-conserving)?
- **Expiry:** Use `apns-expiration` (discard if not delivered by time)?

**Oracle: For transit alerts, what's the right balance between reliability and complexity?**

### 5. Payload Design & Deep Links

**Current payload:**

```json
{
  "aps": {
    "alert": {
      "title": "Delay on T1 Line",
      "body": "10 min delay due to signal failure"
    },
    "sound": "default",
    "badge": 1,
    "category": "SERVICE_ALERT",
    "thread-id": "alert_12345"
  },
  "alert_id": "alert_12345",
  "route_id": "T1",
  "deep_link": "transitapp://alerts/alert_12345"
}
```

**Questions:**
- **Badge management:** Increment badge on each notification? Or set to total unread alerts?
- **Actions:** Add notification actions ("View Route", "Dismiss")?
- **Localization:** Include localized strings (for iOS to render without waking app)?
- **Rich notifications:** Attachments (route map image)? Or too complex for MVP?

**Oracle: Is this payload structure optimal? Any improvements?**

### 6. User Preferences & Quiet Hours

**Questions:**
- **Quiet hours:** Don't send notifications 10pm-7am? Or let user configure?
- **Per-favorite settings:** User can enable/disable notifications per favorite?
- **Severity filter:** User only wants critical alerts (cancellations), not minor delays?

**Oracle: What's the minimal viable notification preferences system?**

### 7. Scaling Triggers

**When to add resources?**
- More APNs workers when ??? (queue depth? latency?)
- Switch from Celery to dedicated APNs service when ??? (user count? notification volume?)

**Oracle: Define clear metrics-based scaling triggers**

---

## Expected Output

1. **Alert Matching Architecture**
   - SQL queries or Redis patterns
   - Performance at 10K users, 500 alerts/day
   - Code examples (Python/SQL)

2. **APNs Worker Implementation**
   - Celery task structure
   - Batch size, connection pooling, error handling
   - Production-ready code snippet

3. **Deduplication Strategy**
   - Database schema updates (if needed)
   - Collapse ID logic
   - Time-window rules

4. **Delivery Tracking (if needed)**
   - Simple tracking approach (no over-engineering)
   - Priority & expiry header usage

5. **Payload Specification**
   - Final JSON structure
   - Badge management strategy
   - Deep link format

6. **User Preferences Schema**
   - Minimal MVP fields (quiet hours, severity filter, etc.)
   - Supabase table structure

7. **Scaling Triggers**
   - Clear metrics (e.g., "add worker when queue depth > 100 for 5min")

8. **Cited Sources**
   - Apple APNs best practices
   - Production examples (if available)
   - Python APNs libraries comparison

---

## Research Mandate (Oracle's Superpower)

- **Find:** Production APNs architectures from transit apps, ride-sharing, or similar real-time services
- **Search:** Apple APNs best practices, HTTP/2 connection pooling, batch sending patterns
- **Compare:** Python APNs libraries (`apns2`, `aioapns`, `PyAPNs2`) - which for Celery + async?
- **Cite:** Every major decision with source
- **Justify:** Why this pattern works for our constraints (0 users, $25/month, solo dev)
- **Avoid:** Novel/untested approaches, over-engineering, additional services

---

## Success Criteria

Solution is successful if:
- ✅ Works within fixed tech stack (APNs, Supabase, Celery, Redis)
- ✅ Optimized for 0 users initially, scales to 10K
- ✅ Stays under $25/month at launch (no APNs costs, just infrastructure)
- ✅ Solo developer can implement & maintain
- ✅ Backed by research/production patterns
- ✅ Provides clear scaling triggers (when to add resources)
- ✅ Handles APNs errors gracefully (invalid tokens, rate limits)
- ✅ Prevents notification spam (deduplication works)

---

## Validation Checklist (Before Integrating Oracle Solution)

```
□ Uses only planned tech stack (no new services)
□ Alert matching performant at 10K users
□ APNs worker handles errors correctly (400/410/429/5xx)
□ Deduplication prevents spam
□ Simple enough for solo dev to debug at 3am
□ Backed by cited research/sources
□ Provides clear scaling triggers
□ Doesn't over-engineer (MVP-appropriate)
```

---

**Ready for Oracle to design production-ready APNs architecture**
