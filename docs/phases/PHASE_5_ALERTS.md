# Phase 5: Alerts + Background Jobs
**Duration:** 2-3 weeks | **Timeline:** Week 14-16
**Goal:** Users subscribe to alerts, in-app notifications (no push yet)

---

## Overview
- Alerts API (list active alerts, subscribe)
- Alert matcher task (Celery, every 2-5 min)
- Match logic: user favorites → active alerts
- iOS alerts UI (list, details, subscribe toggle)
- In-app notification banner (not push, just local alert)

---

## Implementation Checklist

### Backend

**1. Alerts Schema (migration 003_alerts.sql)**
```sql
CREATE TABLE alerts (
    alert_id TEXT PRIMARY KEY,
    severity TEXT NOT NULL,  -- 'major', 'minor', 'info'
    header TEXT NOT NULL,
    description TEXT,
    affected_routes TEXT[],  -- Array of route_ids
    affected_stops TEXT[],   -- Array of stop_ids
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE alert_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stop_id TEXT REFERENCES stops(stop_id),
    route_id TEXT REFERENCES routes(route_id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, stop_id, route_id)
);

-- RLS for alert_subscriptions
ALTER TABLE alert_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage their subscriptions" ON alert_subscriptions USING (auth.uid() = user_id);
```

**2. Alert Matcher Task (app/tasks/alert_matcher.py)**
(From INTEGRATION_CONTRACTS.md Section 4)

```python
@celery_app.task(
    name='match_alerts',
    queue='normal',
    time_limit=20,
    soft_time_limit=15
)
def match_alerts():
    """Match active alerts → user subscriptions, queue notifications."""
    supabase = get_supabase()

    # Fetch active alerts
    alerts = supabase.table('alerts').select('*').gte('end_time', 'now()').execute().data

    # For each alert, find subscribed users
    for alert in alerts:
        affected_routes = alert['affected_routes']
        affected_stops = alert['affected_stops']

        # Query subscriptions (SQL: user favorites OR explicit subscriptions)
        query = """
        SELECT DISTINCT user_id FROM (
            SELECT user_id FROM favorites WHERE stop_id = ANY($1)
            UNION
            SELECT user_id FROM alert_subscriptions WHERE stop_id = ANY($1) OR route_id = ANY($2)
        ) AS matched_users;
        """
        users = supabase.rpc('exec_raw_sql', {'query': query, 'params': [affected_stops, affected_routes]}).execute()

        # Queue APNs notifications (Phase 6)
        for user in users.data:
            logger.info("alert_matched", user_id=user['user_id'], alert_id=alert['alert_id'])
            # TODO: Phase 6 - send_push_notification.delay(user_id, alert)
```

**3. Celery Beat Schedule (add to celery_app.py)**
```python
celery_app.conf.beat_schedule['match-alerts'] = {
    'task': 'app.tasks.alert_matcher.match_alerts',
    'schedule': crontab(minute='*/2'),  # Every 2 min (peak) - adaptive in production
    'options': {'queue': 'normal'}
}
```

**4. Alerts API (app/api/v1/alerts.py)**
```python
@router.get("/alerts")
async def list_alerts(supabase = Depends(get_supabase)):
    """List active alerts."""
    result = supabase.table('alerts').select('*').gte('end_time', 'now()').execute()
    return SuccessResponse(data=result.data)

@router.post("/alerts/subscribe")
async def subscribe_to_alert(
    subscription: AlertSubscriptionCreate,
    user = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Subscribe to alerts for stop/route."""
    data = {'user_id': user.id, 'stop_id': subscription.stop_id, 'route_id': subscription.route_id}
    result = supabase.table('alert_subscriptions').insert(data).execute()
    return SuccessResponse(data=result.data[0])
```

---

### iOS

**5. Alerts View (Features/Alerts/AlertsView.swift)**
```swift
struct AlertsView: View {
    @StateObject private var viewModel: AlertsViewModel

    var body: some View {
        List(viewModel.alerts, id: \.alert_id) { alert in
            NavigationLink(value: alert) {
                AlertRow(alert: alert)
            }
        }
        .navigationTitle("Service Alerts")
        .onAppear {
            Task { await viewModel.loadAlerts() }
        }
    }
}

struct AlertRow: View {
    let alert: Alert

    var body: some View {
        HStack {
            Image(systemName: severityIcon(alert.severity))
                .foregroundColor(severityColor(alert.severity))
            VStack(alignment: .leading) {
                Text(alert.header)
                    .font(.headline)
                Text(alert.description ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    func severityIcon(_ severity: String) -> String {
        switch severity {
        case "major": return "exclamationmark.triangle.fill"
        case "minor": return "exclamationmark.circle"
        default: return "info.circle"
        }
    }

    func severityColor(_ severity: String) -> Color {
        switch severity {
        case "major": return .red
        case "minor": return .orange
        default: return .blue
        }
    }
}
```

**6. In-App Notification (local only, no APNs yet)**
```swift
// Show banner when alert matched (Phase 6: integrate with APNs)
struct AlertBannerView: View {
    let alert: Alert

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(alert.header)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.yellow.opacity(0.3))
        .cornerRadius(8)
    }
}
```

---

## Acceptance Criteria

**Backend:**
- [ ] Alert matcher runs every 2 min
- [ ] Alerts API returns active alerts
- [ ] Subscriptions work (RLS enforced)
- [ ] Logs show `alert_matched` events

**iOS:**
- [ ] Alerts list displays active alerts
- [ ] Alert details screen shows full description
- [ ] Subscribe toggle works (favorites auto-subscribed)
- [ ] In-app banner appears (mock for now)

---

## Next Phase: Push Notifications (Week 17-18)

**End of PHASE_5_ALERTS.md**
