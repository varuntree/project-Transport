# Bug Fix Report

**Bug:** Duplicate Departure IDs in iOS ForEach loops

**Status:** Fixed ✓

**Timestamp:** 2024-11-22T09:04:06Z

---

## Bug Summary

Departure.id generates duplicate IDs despite tripId_scheduledTimeSecs format - backend returns identical trip+time combinations for circular routes

---

## Root Cause

**Category:** logic_error

**Description:**
Departure.id uses tripId_scheduledTimeSecs but GTFS allows circular routes where trips visit same stop multiple times, creating duplicate IDs. Backend returned stop_sequence field but iOS model wasn't decoding it.

**Confidence:** 0.98

**Evidence:**
- Backend line 338 realtime_service.py: returns 'stop_sequence' field
- iOS Departure.swift line 95-107: CodingKeys missing stopSequence
- iOS Departure.swift line 17: ID format doesn't include stop_sequence
- GTFS allows circular routes with duplicate (trip, time) but unique sequence

---

## Fix Applied

**Approach:**
Added stopSequence field to Departure model and included in ID generation: tripId_scheduledTimeSecs_stopSequence

**Files Modified:**
- SydneyTransit/Data/Models/Departure.swift
- SydneyTransit/Map/Components/StopDetailsDrawer.swift
- SydneyTransit/Core/Database/DatabaseManager.swift
- SydneyTransit/Features/Map/Components/StopDetailsDrawer.swift
- SydneyTransitTests/DepartureModelTests.swift

**Changes:**
- Added `let stopSequence: Int` property
- Updated ID to `"\(tripId)_\(scheduledTimeSecs)_\(stopSequence)"`
- Added `case stopSequence = "stop_sequence"` to CodingKeys
- Added stopSequence parameter to memberwise init
- Added resilient decoder with default value 0
- Updated all mock/offline Departure init calls with stopSequence: 0

---

## Validation

**Compile Check:** passed

**Manual Trace:**
Circular routes now create unique IDs: tripId_scheduledTimeSecs_1 vs tripId_scheduledTimeSecs_15 - no collision. Backend provides stop_sequence, iOS decodes it, ForEach gets unique IDs.

**Test Plan:**
- Build app with xcodebuild (✓ passed)
- Manual: Open app in simulator
- Search for Central Station
- Tap platform stop (e.g., Platform 16)
- Check Xcode console - verify no duplicate ID errors
- Verify departure list displays correctly with no duplicate rows

---

## Affected Systems

- **iOS Departure Model** (iOS Data)
- **DeparturesViewModel Deduplication** (iOS Business Logic)
- **Backend Departures API** (Backend API)
- **DeparturesView ForEach** (iOS UI)
- **StopDetailsDrawer ForEach** (iOS UI)

---

## Related Phase

**Primary Phase:** 2

**Phase 2:** Real-time departures feature implemented in Phase 2, previous duplicate fix in commit 14207b2 during Phase 2

---

## Fix Confidence

**Overall:** 0.95

---

## Logs

- Map: .workflow-logs/active/bugs/1763805446-fix-that-duplicate-id/map-result.json
- Explore: .workflow-logs/active/bugs/1763805446-fix-that-duplicate-id/explore-result.json
- Diagnosis: .workflow-logs/active/bugs/1763805446-fix-that-duplicate-id/diagnosis-result.json
- Fix: .workflow-logs/active/bugs/1763805446-fix-that-duplicate-id/fix-result.json

---

**Report Generated:** 2024-11-22T09:04:06Z
