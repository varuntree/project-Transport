# Checkpoint 11: Offline Mode Validation

## Goal
Verify iOS app works completely offline (no network access). Search, stop details, route list all functional with bundled GRDB. No API calls, no URLError logs.

## Approach

### iOS Implementation
- No code changes (validation only)
- Verify bundled GRDB provides all data
- Confirm no network calls in Phase 1 scope

### Validation Details

**Test Scenario:**
1. Disable Mac Wi-Fi completely (System Settings → Wi-Fi → Off)
2. Relaunch iOS app in simulator (Cmd+R)
3. Test all Phase 1 features:
   - Search stops
   - View stop details
   - Browse routes
   - Navigate between screens
4. Verify no network errors in logs
5. Re-enable Wi-Fi

**Expected Behavior:**
- ✅ App launches normally (no crash)
- ✅ Search "circular" returns results (<200ms)
- ✅ Tap stop → StopDetailsView shows details
- ✅ Map loads (may show blank tiles = expected offline, but marker shows)
- ✅ Browse routes → RouteListView shows all 400-1200 routes
- ✅ No URLError in Xcode console
- ✅ No "Network connection lost" alerts

**Known Offline Limitations (Acceptable for Phase 1):**
- Map tiles: May not load (blank map OK, marker still shows)
- Share sheet: Works offline (local share, no cloud sync)
- No real-time data: Expected (Phase 2 adds GTFS-RT)

**Logs to Check:**
```
# Good logs (expected offline):
database_loaded: path=...gtfs.db
search_complete: query="circular", result_count=5
stop_details_viewed: stop_id=1
route_list_loaded: count=800

# Bad logs (fail validation):
URLError: The Internet connection appears to be offline
network_request_failed: ...
connection_timeout: ...
```

**Future Network Integration (Phase 2+):**
- Phase 2: GTFS-RT API calls (with offline fallback to schedules)
- Phase 3: User favorites sync (Supabase API)
- Phase 6: APNs registration (push notifications)

## Design Constraints
- Phase 1 scope: 100% offline (no API calls)
- GRDB bundled data: Complete for static GTFS (stops, routes, schedules)
- Map tiles: Optional (nice-to-have, not critical for Phase 1)
- Future: Graceful degradation (online features fail → fallback to offline)

## Risks
- **Hidden network calls:** Unintentional API usage
  - Mitigation: Careful code review, no APIClient usage in Phase 1
- **Map tiles required:** User expects functional map
  - Mitigation: Map marker shows location even without tiles
- **ShareLink network dependency:** Requires cloud
  - Mitigation: ShareLink works offline (local share)

## Validation
```bash
# Step 1: Disable Wi-Fi
# Mac → System Settings → Wi-Fi → Off

# Step 2: Launch app
open -a Simulator
cd SydneyTransit
xcodebuild -scheme SydneyTransit -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15' clean build
# OR: Xcode → Cmd+R

# Step 3: Test features
# HomeView → Search Stops
# Type "circular" → Results appear
# Tap "Circular Quay Station" → Details show
# Back → Browse Routes → List shows ~800 routes
# Navigate around → No crashes

# Step 4: Check Xcode Console
# Verify NO URLError lines
# Verify search/load logs present

# Step 5: Re-enable Wi-Fi
# Mac → System Settings → Wi-Fi → On

# Validation passes if:
# - All features work
# - No network error logs
# - No crashes
```

## References for Subagent
- Architecture: IOS_APP_SPECIFICATION.md:Section 4.2 (offline-first design)
- Phase 2 preview: PHASE_2:L45-67 (network fallback strategy)
- Existing views: Checkpoints 8-10 (no APIClient usage)

## Estimated Complexity
**simple** - Validation only, no implementation. Manual testing, log verification.
