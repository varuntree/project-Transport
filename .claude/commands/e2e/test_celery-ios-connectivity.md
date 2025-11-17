# E2E Test: Celery & iOS Backend Connectivity (Phase 2)

Test Celery task registration, backend health, and iOS app connectivity to FastAPI backend.

## User Story

As a developer
I want Celery tasks registered without errors and iOS connecting to backend
So that Phase 2 real-time features can function properly

## Test Steps

### Backend: Celery Task Registration

1. Navigate to backend directory: `cd backend && source venv/bin/activate`
2. Start Celery worker in background: `celery -A app.tasks.celery_app worker -Q critical,normal,batch -l info` (run in background, save process ID)
3. **Verify** worker logs show no "unregistered task" errors within first 30 seconds
4. **Verify** worker logs contain "alert_matcher" and "apns_worker" in registered tasks output
5. Run `celery -A app.tasks.celery_app inspect registered` and capture output
6. **Verify** output contains `app.tasks.alert_matcher.match_delays_to_favorites` and `app.tasks.apns_worker.send_push_notifications`
7. Start Celery beat: `celery -A app.tasks.celery_app beat -l info` (run in background)
8. Wait 5 minutes and monitor beat/worker logs
9. **Verify** no "Received unregistered task" errors appear in worker logs
10. **Verify** alert matcher stub logs appear with "stub_noop" status during scheduled runs
11. Stop Celery worker and beat processes

### Backend: Health Endpoint

12. Start FastAPI server in background: `uvicorn app.main:app --reload`
13. Wait for server startup (check for "Application startup complete")
14. Run `curl -i http://localhost:8000/health` and capture output
15. **Verify** HTTP status is 200
16. **Verify** response contains `"status": "healthy"` and Redis/Supabase connectivity checks
17. Run `curl -i http://localhost:8000/api/v1/stops/200060/departures` and capture output
18. **Verify** HTTP status is 200 or 404 (404 acceptable if stop not in GTFS-RT cache yet)
19. **Verify** no double `/api/v1/api/v1` in request logs

### iOS: GRDB Routes Loading

20. Open `SydneyTransit.xcodeproj` in Xcode
21. Build and run app in iPhone 15 simulator (or available device)
22. Wait for app launch and Home screen to render
23. **Verify** Home screen displays "Phase 2: Real-time Departures" label
24. **Verify** Backend status shows "Sydney Transit API" (green) or "Backend unreachable" is visible
25. Navigate to "All Routes" screen
26. **Verify** routes list renders without GRDB "row encoding error 1"
27. **Verify** routes are grouped by type (Train, Bus, Ferry, etc.)
28. **Verify** routes with NULL `route_short_name` display "Unknown Route" or fallback name
29. Tap on any route row
30. **Verify** no crash or decoding errors occur

### iOS: Stop Search & Departures

31. Return to Home and navigate to "Search Stops"
32. Search for "Central" (or any known stop name)
33. **Verify** search results appear without GRDB errors
34. Tap on first stop result
35. **Verify** Stop details/departures screen loads
36. Check Xcode console/network logs for request URL
37. **Verify** request URL is `http://localhost:8000/api/v1/stops/<id>/departures` (single `/api/v1` prefix)
38. **Verify** no double `/api/v1/api/v1` appears in any network request
39. If backend returns departures, verify realtime badge appears only when `realtime=true`

## Success Criteria

- Celery worker registers all 4 tasks (gtfs_rt_poller, alert_matcher, apns_worker, gtfs_static_sync)
- No "unregistered task" errors in Celery logs during 5 min beat schedule
- Alert matcher/APNs stubs log invocations without crashing
- Backend `/health` returns 200 with healthy status
- iOS Config.plist has correct base URL (`http://localhost:8000`, no `/api/v1` suffix)
- iOS APIClient logs show single `/api/v1` prefix in request URLs
- All Routes screen loads without GRDB row encoding errors
- Routes with NULL names display fallback text
- Stop search and departures load successfully
- No crashes or assertion failures in Xcode console

## Output Format

```json
{
  "test_name": "Celery & iOS Backend Connectivity (Phase 2)",
  "status": "passed|failed",
  "backend_health": "healthy|unhealthy",
  "celery_tasks_registered": ["task1", "task2", ...],
  "ios_routes_loaded": true|false,
  "ios_api_url_correct": true|false,
  "grdb_errors": 0,
  "error": null
}
```
