# Bug Fix Report

**Bug:** No departures showing in iOS simulator despite backend running

**Status:** Fixed

**Timestamp:** 2025-11-22T08:28:22Z

---

## Bug Summary

iOS showing "no upcoming departures" despite expecting GRDB offline data minimum - API URL mismatch causes 404, offline fallback returns empty

---

## Root Cause

**Category:** configuration_error

**Description:**
Config.plist API_BASE_URL missing /api/v1 prefix, causing iOS to call http://localhost:8000/stops/... instead of http://localhost:8000/api/v1/stops/..., resulting in 404. Offline fallback then returns empty array.

**Confidence:** 0.95

**Evidence:**
- Config.plist L6: API_BASE_URL = http://localhost:8000 (missing /api/v1)
- APIClient.swift L63: Constructs URL as baseURL + path
- APIEndpoint L33: Path = /stops/{id}/departures (no prefix)
- Backend main.py L56-60: Routers registered with prefix="/api/v1"
- Result: iOS calls http://localhost:8000/stops/.../departures → 404 Not Found
- Backend verified working: curl http://localhost:8000/api/v1/stops/220593/departures → returns departures

---

## Fix Applied

**Approach:**
Added /api/v1 prefix to Config.plist API_BASE_URL to match backend routing structure

**Files Modified:**
- SydneyTransit/SydneyTransit/Config.plist

**Changes:**
L6: http://localhost:8000 → http://localhost:8000/api/v1

---

## Validation

**Compile Check:** passed

**Manual Trace:**
iOS APIClient will now construct URLs as http://localhost:8000/api/v1 + /stops/{id}/departures → matches backend router prefix → should return 200 with departures

**Test Plan:**
- Manual: Clean Build Folder in Xcode (Cmd+Shift+K)
- Manual: Rebuild iOS app (Cmd+B)
- Manual: Run in iOS simulator (Cmd+R)
- Manual: Search for stop (e.g., 'Central Station')
- Manual: Tap stop from search results
- Expected: Departures screen shows list of departures with times/route names
- Verify: Check Xcode console for successful API log: http://localhost:8000/api/v1/stops/.../departures
- Offline test: Stop backend (./backend/scripts/stop_all.sh), pull to refresh
- Expected: Offline fallback shows GRDB departures (static schedule)

---

## Affected Systems

- **iOS Configuration** (iOS Config)
- **iOS Network** (iOS Network)
- **Backend API** (Backend API)

---

## Related Phase

**Primary Phase:** 2

**Phase Artifacts:**
- **Phase complete-system-restoration - Checkpoint complete-system-restoration:** Checkpoint 2 - Backend architecture decoupling added DeparturesPage

---

## Fix Confidence

**Overall:** 0.95

---

## Secondary Investigation Notes

**If departures still empty after fix:**
- Investigate DatabaseManager time filtering (2-hour window may exclude GTFS schedules)
- Debug stop_id lookup in dict_stop table (L160)
- Check pattern_stops query (L193-220)

**Offline Fallback Debug Steps:**
- Stop backend services
- Add print statements in DatabaseManager.getDepartures():
  - Print stop_id from dict_stop lookup (verify not nil)
  - Print currentDate value (verify Sydney timezone)
  - Print pattern_stops query result count (before time filtering)
  - Print final result count (after time filtering)

---

## Logs

- Map: .workflow-logs/active/bugs/1732266502-no-departures-showing-in-ios-simulator/map-result.json
- Explore: .workflow-logs/active/bugs/1732266502-no-departures-showing-in-ios-simulator/explore-result.json
- Diagnosis: .workflow-logs/active/bugs/1732266502-no-departures-showing-in-ios-simulator/diagnosis-result.json
- Fix: .workflow-logs/active/bugs/1732266502-no-departures-showing-in-ios-simulator/fix-result.json

---

**Report Generated:** 2025-11-22T08:35:00Z
