# System Audit & Refactoring Plan

**Objective:** Centralize logic, fix "partially working" Phase 2 features, and align all layers (Database ↔ Backend ↔ iOS).

---

## 1. Current State & Gap Analysis

### A. Schema & Contracts (The "Partially Working" Root Cause)
The immediate crash was fixed, but a deeper systemic issue exists: **Schema Drift**.
- **Backend (API):** Returns flattened pagination in `data` object (`earliest_time_secs`, `has_more_past`).
- **iOS (Client):** Expects pagination in `meta` object and `count` field (which backend dropped).
- **Database (Supabase):** `stops` table matches backend models, but `departures` are calculated on-the-fly, leading to potential mismatches if logic changes.

### B. Feature Gaps (Phase 2 Realtime)
| Feature | Requirement | Current Status |
| :--- | :--- | :--- |
| **Real-time Delays** | Display delay minutes in list | **Working** (Backend logic exists, iOS has UI). |
| **Service Alerts** | Show alerts for stop | **BROKEN**. API endpoint exists, but `celery_app.py` **missing schedule** to poll alerts. Redis cache empty. |
| **Vehicle Positions** | Show bus/train on map | **Missing**. Backend polls positions (for occupancy), but **no API endpoint** exposes them to iOS. |
| **Occupancy** | Show crowd levels | **Working** (Backend merges it, iOS has UI). |
| **Pagination** | Infinite scroll (past/future) | **Fragile**. Logic duplicated in iOS (`DeparturesViewModel`) and Backend (`realtime_service`). |

### C. Logic Duplication (Violation of Centralization)
1.  **Countdown Logic:** iOS calculates "minutes until" (`Departure.swift`). Backend should send this (standardized server time).
2.  **Pagination Logic:** iOS manages `hasMorePast/Future` state based on local arrays. Backend should be single source of truth for "next page available".
3.  **Formatting:** iOS formats "5 min early". Backend should send status codes/enums, not raw strings, but raw seconds are okay if standardized.

---

## 2. Refactoring Plan

### Phase 2.1: Schema & Contract Alignment (High Priority)
**Goal:** strict, typed contracts between Backend and iOS.

1.  **Backend:** Formalize `DepartureResponse` in `backend/app/models/departures.py`.
    *   Add `minutes_until` (int).
    *   Add `status_text` (string, e.g., "On Time", "Delayed").
    *   Ensure `pagination` is consistently in `meta` or `data` (recommend `meta` for standard API envelope).
2.  **iOS:** Generate/Update `Departure.swift` to match exactly.
    *   Remove computed properties `minutesUntil`.
    *   Use backend-provided values.

### Phase 2.2: Fix Broken Realtime Features
**Goal:** Make "partially working" features fully functional.

1.  **Service Alerts:**
    *   **Fix:** Add `poll_service_alerts` task to `celery_app.py` schedule.
    *   **Verify:** Check Redis keys `sa:{mode}:v1` populate.
    *   **iOS:** Hook up `AlertsView` to `GET /stops/{id}/alerts`.
2.  **Vehicle Positions:**
    *   **New Endpoint:** `GET /stops/{id}/vehicles` (nearby vehicles) or `GET /vehicles?ids=...`
    *   **iOS:** Update `MapView` to poll this endpoint and draw annotation markers.

### Phase 2.3: Logic Centralization
**Goal:** "Dumb" client, "Smart" server.

1.  **Centralize Time:** Backend calculates `minutes_until` based on `time_secs_local`.
2.  **Centralize Status:** Backend determines `status_color` (enum: green, orange, red) and `status_text`.
3.  **Refactor iOS ViewModel:**
    *   Remove local pagination logic (merging arrays).
    *   Trust API `has_more_*` flags.

---

## 3. Execution Steps (Immediate Action)

1.  **Fix Service Alerts Polling:**
    *   Edit `backend/app/tasks/celery_app.py` to add the missing schedule.
2.  **Standardize API Response:**
    *   Edit `backend/app/models/departures.py` to include `minutes_until`.
    *   Edit `backend/app/services/realtime_service.py` to compute it.
3.  **Update iOS Model:**
    *   Edit `SydneyTransit/SydneyTransit/Data/Models/Departure.swift` to use backend values.

---

## 4. Documentation Update
*   Update `docs/architecture/BACKEND_SPECIFICATION.md` with new API response structure.
*   Update `docs/phases/PHASE_2_REALTIME.md` to reflect "Vehicle Positions" as a new requirement if desired.
