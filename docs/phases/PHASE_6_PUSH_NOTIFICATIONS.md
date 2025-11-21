# Phase 6: Push Notifications (APNs)
**Duration:** 1.5-2 weeks | **Timeline:** Week 17-18
**Goal:** APNs integration, push alerts to devices

---

## Overview
(From INTEGRATION_CONTRACTS.md Section 4 - Oracle reviewed)

- APNs worker (Celery task, send push)
- Device registration API
- Alert matcher → APNs fan-out
- 3-layer deduplication (DB unique constraint + collapse-id + cooldown)
- iOS APNs registration, push handling

---

## User Instructions

### 1. Generate APNs Certificate
1. Apple Developer Portal → Certificates, IDs & Profiles
2. Keys → "+" → Apple Push Notifications service (APNs)
3. Download `.p8` file
4. Note: Key ID, Team ID

### 2. Configure Backend
Add to `.env`:
```bash
APNS_KEY_ID=ABCD1234
APNS_TEAM_ID=TEAM1234
APNS_BUNDLE_ID=com.sydneytransit.app
APNS_PRIVATE_KEY_PATH=/path/to/apns_key.p8
```

### 3. iOS Entitlements
Xcode → Signing & Capabilities → "+ Capability" → Push Notifications

---

## Implementation Checklist

### Backend

**1. Device Registration Schema (migration 004_devices.sql)**
```sql
CREATE TABLE devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT NOT NULL UNIQUE,
    platform TEXT NOT NULL DEFAULT 'ios',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_devices_user ON devices(user_id);
CREATE INDEX idx_devices_token ON devices(device_token) WHERE is_active = TRUE;

-- RLS
ALTER TABLE devices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage their devices" ON devices USING (auth.uid() = user_id);

-- Notification log (deduplication)
CREATE TABLE notification_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    alert_id TEXT NOT NULL,
    sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(user_id, alert_id)  -- Prevent duplicate alerts to same user
);
CREATE INDEX idx_notification_log_sent_at ON notification_log(sent_at);
```

**2. APNs Worker (app/tasks/apns_worker.py)**
(From INTEGRATION_CONTRACTS.md Section 4.3)

```python
from apns2.client import APNsClient
from apns2.payload import Payload
from app.tasks.celery_app import celery_app

@celery_app.task(
    name='send_push_notification',
    queue='normal',
    bind=True,
    max_retries=3,
    time_limit=12,
    soft_time_limit=8
)
def send_push_notification(self, user_id: str, alert: dict):
    """Send push notification to user's devices."""
    supabase = get_supabase()

    # Check deduplication (30 min cooldown)
    recent = supabase.table('notification_log').select('id').eq('user_id', user_id).eq('alert_id', alert['alert_id']).gte('sent_at', 'now() - interval \'30 minutes\'').execute()
    if recent.data:
        logger.info("notification_deduplicated", user_id=user_id, alert_id=alert['alert_id'])
        return

    # Fetch user's devices
    devices = supabase.table('devices').select('device_token').eq('user_id', user_id).eq('is_active', True).execute()

    if not devices.data:
        logger.info("no_devices", user_id=user_id)
        return

    # APNs client (HTTP/2 connection pooling)
    client = get_apns_client()

    # Build payload
    payload = Payload(
        alert={
            'title': 'Service Alert',
            'body': alert['header'],
            'sound': 'default'
        },
        badge=1,
        custom={
            'alert_id': alert['alert_id'],
            'deep_link': f'sydneytransit://alerts/{alert["alert_id"]}'
        },
        collapse_id=alert['alert_id']  # iOS deduplication
    )

    # Fan-out to devices (batch 100-500 tokens per task in production)
    for device in devices.data:
        try:
            client.send_notification(device['device_token'], payload, topic=settings.APNS_BUNDLE_ID)
            logger.info("apns_sent", user_id=user_id, device_token=device['device_token'][:8])
        except Exception as exc:
            if '410' in str(exc):  # Unregistered
                supabase.table('devices').update({'is_active': False}).eq('device_token', device['device_token']).execute()
            elif '429' in str(exc):  # Rate limit
                raise self.retry(exc=exc, countdown=60)
            logger.error("apns_failed", user_id=user_id, error=str(exc))

    # Log notification
    supabase.table('notification_log').insert({'user_id': user_id, 'alert_id': alert['alert_id']}).execute()


def get_apns_client():
    """Singleton APNs client (HTTP/2 connection reuse)."""
    if not hasattr(get_apns_client, '_client'):
        get_apns_client._client = APNsClient(
            credentials=settings.APNS_PRIVATE_KEY_PATH,
            use_sandbox=settings.ENVIRONMENT == 'development'
        )
    return get_apns_client._client
```

**3. Update Alert Matcher (app/tasks/alert_matcher.py)**
```python
# In match_alerts task, replace TODO with:
for user in users.data:
    send_push_notification.delay(user['user_id'], alert)
```

**4. Device Registration API (app/api/v1/devices.py)**
```python
@router.post("/devices")
async def register_device(
    device: DeviceRegistration,
    user = Depends(get_current_user),
    supabase = Depends(get_supabase)
):
    """Register device for push notifications."""
    data = {
        'user_id': user.id,
        'device_token': device.token,
        'platform': 'ios',
        'is_active': True,
        'last_seen_at': 'now()'
    }
    result = supabase.table('devices').upsert(data, on_conflict='device_token').execute()
    return SuccessResponse(data=result.data[0])
```

---

### iOS

**5. APNs Registration (Core/Push/PushNotificationManager.swift)**
```swift
import UserNotifications

class PushNotificationManager: NSObject, ObservableObject {
    static let shared = PushNotificationManager()
    @Published var isAuthorized = false

    func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            if granted {
                await UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            Logger.app.error("Push auth failed: \(error)")
        }
    }

    func registerDeviceToken(_ token: Data) async {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        Logger.app.info("Device token: \(tokenString)")

        // Send to backend
        let apiClient = APIClient.shared
        do {
            let _: SuccessResponse<Device> = try await apiClient.request(.registerDevice(token: tokenString))
            Logger.app.info("Device registered")
        } catch {
            Logger.app.error("Device registration failed: \(error)")
        }
    }
}
```

**6. App Delegate (SydneyTransitApp.swift)**
```swift
@UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task {
            await PushNotificationManager.shared.registerDeviceToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Logger.app.error("APNs registration failed: \(error)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let alertId = userInfo["alert_id"] as? String {
            // Navigate to alert details
            Logger.app.info("Opening alert: \(alertId)")
        }
        completionHandler()
    }
}
```

**7. Request Permission on First Launch**
```swift
// In HomeView.onAppear
Task {
    await PushNotificationManager.shared.requestAuthorization()
}
```

---

## Acceptance Criteria

**Backend:**
- [ ] Device registration works
- [ ] APNs worker sends push (test with physical device)
- [ ] Deduplication prevents duplicate alerts
- [ ] 410 errors deactivate devices

**iOS:**
- [ ] Permission prompt appears
- [ ] Device token sent to backend
- [ ] Push received (even when app closed)
- [ ] Tap push → opens alert details
- [ ] Foreground push shows banner

**Test:**
```bash
# Manually trigger alert matcher
celery -A app.tasks.celery_app call app.tasks.alert_matcher.match_alerts

# Check notification_log table
SELECT * FROM notification_log ORDER BY sent_at DESC LIMIT 5;
```

---

## Next Phase: Production (Week 19-20)

**End of PHASE_6_PUSH_NOTIFICATIONS.md**
