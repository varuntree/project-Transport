# Oracle Consultation: Refactor 3-Layer Architecture to Restore Decoupling

**Session ID:** 1763793313-refactor-decouple-3layer-architecture
**Generated:** 2025-11-22T08:35:13Z
**Project:** Sydney Transit App (iOS + FastAPI Backend)

---

## Task Description

**Current State:**
We have implemented a 3-layer offline-first architecture for our transit app, but the implementation has **critical coupling violations** that prevent any layer from functioning:

1. **Layer 1 (iOS GRDB):** Primary offline data source - Bundled 74MB SQLite with 59K stops. Should show offline data always, no network required.
2. **Layer 2 (Backend Supabase):** Secondary cloud database - Should provide static GTFS schedules enriched from Supabase PostgreSQL.
3. **Layer 3 (Backend Redis RT):** Tertiary real-time overlays - Should merge GTFS-RT updates (delays, platforms, occupancy) from Redis cache.

**Architectural Intent (from specs):**
Each layer should work **independently**. Graceful degradation:
- Layer 1 fails → try Layer 2
- Layer 2 fails → try Layer 3 (RT-only mode)
- All layers should be **decoupled** - no layer blocks another

**Critical Failures Observed:**
1. ❌ **Layer 2 blocks Layer 3:** Backend checks Supabase `stops` table BEFORE querying Redis RT. Returns 404 if Supabase empty → real-time data never consulted.
2. ❌ **Layer 1 incomplete fallback:** iOS repository throws exception if GRDB fails, instead of graceful degradation to empty state.
3. ❌ **Layer 3 requires Layer 2 data:** Backend RT merge logic returns `[]` if no Supabase `pattern_stops` data, even when Redis has RT updates.

**Impact:**
- Redis has **1506 vehicle positions + 3580 trip updates** (verified working) but app shows "Network error: Could not connect to the server"
- GRDB has **59K stops in 74MB bundled database** (verified working) but iOS shows network error instead of offline data
- Supabase tables **EMPTY** (Phase 1 GTFS import never ran) → blocks all data flow

**Root Cause:**
Architecture design is **sound**, but implementation **violated decoupling principles**. Layers are tightly coupled instead of independent. Built Phase 2 (Real-time) on incomplete Phase 1 (Static data), violating quality gates.

**Need:**
1. **Refactoring plan** to restore decoupled 3-layer architecture as originally designed
2. **Validation strategy** to verify each layer works independently
3. **Phase gate enforcement** to prevent future coupling violations

---

## Project Context

**Tech Stack:**
- **Backend:** FastAPI (Python 3.13) + Celery (3 queues: critical/normal/batch), Supabase PostgreSQL (500MB free tier), Redis (Railway, GTFS-RT cache)
- **iOS:** Swift/SwiftUI (iOS 16+), GRDB (15-20MB bundled GTFS SQLite), Supabase Auth
- **Data:** NSW Transport GTFS (227MB static updated daily, GTFS-RT polled every 30s)

**Current Git Status:**
- Branch: `main`
- Recent commits:
  ```
  bc15753 fix: Add offline fallback to fetchDeparturesPage()
  ece23d6 fix: Add Redis startup check to start_all.sh script
  8b9ac66 fix: P0 bugs - API path double-prefix + SQL injection
  ```
- Phase status: Phase 2.2 (RT feature completion) marked complete, but Phase 1 acceptance criteria NOT met

**Key Constraints:**
- **Solo dev:** Simplicity > optimization, self-healing systems
- **Budget:** $25/mo MVP (0-1K users), maximize free tiers
- **Stack fixed:** No new services allowed (use Supabase + Redis + FastAPI + SwiftUI only)
- **App size:** <50MB download (GRDB bundled data compressed)
- **Offline-first:** Must work without network (Layer 1 primary data source)
- **NSW API limits:** 5 req/s, 60K calls/day (real-time polling uses ~16.6K calls/day)

**Architecture Documentation:**
Available in context file:
- `IOS_APP_SPECIFICATION.md` - Section 8 (Offline-First), Section 9 (Repository Pattern)
- `BACKEND_SPECIFICATION.md` - Section 3.2 (Real-time departures endpoint spec)
- `DEVELOPMENT_STANDARDS.md` - Section 4 (Repository pattern with offline fallback example)
- `ROOT_CAUSE_ANALYSIS.md` - Complete architectural violation analysis

---

## Your Task (Oracle)

Given the codebase context in `oracle-context-1763793313-refactor-decouple-3layer-architecture.txt`, provide:

### 1. Analysis

**Architectural Review:**
- Validate root cause analysis findings (3 coupling violations identified)
- Are layers correctly decoupled in spec but coupled in implementation?
- Is "RT-only mode" (Layer 3 without Layer 2) architecturally sound?
- Should iOS try GRDB **first** (before API) or **second** (after API fails)?

**Current Implementation Assessment:**
- `backend/app/api/v1/stops.py` lines 220-232: Supabase check blocks RT query - is this correct pattern?
- `backend/app/services/realtime_service.py` lines 181-184: RT merge returns `[]` if no `static_deps` - should RT work standalone?
- iOS `DeparturesRepository.swift` lines 118-154: Offline fallback throws on GRDB error - should return empty instead?

**Reference Architecture Specs:**
- What does `IOS_APP_SPECIFICATION.md` Section 8 say about offline-first priority?
- What does `BACKEND_SPECIFICATION.md` Section 3.2 say about graceful degradation?
- What does `DEVELOPMENT_STANDARDS.md` Section 4 say about repository fallback pattern?

### 2. Recommendations

**Decoupling Strategy:**
- How should backend serve RT data when Supabase empty? (RT-only mode design)
- Should backend check Supabase `stops` table at all? Or allow any `stop_id` if Redis has RT data?
- How should iOS handle **all 3 layers failing**? (API fails + GRDB fails → show what?)

**Layer Independence Design:**
- Layer 1 (iOS GRDB): Should it be tried first (proactive) or second (fallback after API)?
- Layer 2 (Backend Supabase): Should it be optional enrichment or required validation?
- Layer 3 (Backend Redis RT): Should it work standalone or always require Layer 2 static schedule?

**Alignment with Constraints:**
- Solo dev: Simplest refactoring approach (minimal code changes, maximum reliability)
- Budget: No cost impact (avoid new API calls, keep free tier usage)
- Offline-first: Ensure GRDB primary, API secondary (correct priority order)

### 3. Refactoring Plan

**Step-by-step breakdown** (vertical slicing preferred):

**Phase 1: Decouple Backend Layers (Backend fixes)**
1. **Fix Layer 2 → Layer 3 coupling** (`backend/app/api/v1/stops.py`)
   - Remove Supabase `stops` table check OR
   - Make check optional (skip in dev mode) OR
   - Check Redis for `stop_id` existence as alternative
   - File to modify: `stops.py:220-232`
   - Expected behavior: Backend returns RT data even if Supabase empty

2. **Enable RT-only mode** (`backend/app/services/realtime_service.py`)
   - Allow RT merge to work without `static_deps` from Supabase
   - Return RT-only departures if no static schedule available
   - File to modify: `realtime_service.py:181-203`
   - Expected behavior: Redis RT data served standalone

**Phase 2: Complete iOS Offline Fallback (iOS fixes)**
3. **Add iOS double-fallback** (`SydneyTransit/Data/Repositories/DeparturesRepository.swift`)
   - Wrap GRDB call in nested `do-catch`
   - Return empty `DeparturesPage` if both API + GRDB fail (not throw exception)
   - File to modify: `DeparturesRepository.swift:118-154`
   - Expected behavior: "Network error" → "No departures" graceful message

**Phase 3: Validate Layer Independence (Testing)**
4. **Test each layer in isolation:**
   - Layer 1 only: Backend stopped → iOS shows GRDB data
   - Layer 2 only: Redis stopped → iOS shows Supabase static schedule (if populated)
   - Layer 3 only: Supabase empty → Backend serves Redis RT-only data
   - All layers fail → iOS shows empty state with user-friendly message

**Database migrations needed:** None (schema unchanged)

**API contract changes:** None (response format unchanged, behavior more resilient)

### 4. Code Examples

Provide **concrete snippets** for critical parts, following `DEVELOPMENT_STANDARDS.md` patterns:

**Backend:**
- Structlog JSON logging for RT-only mode fallback
- FastAPI `HTTPException` vs graceful `[]` return (when to use each)
- Example: RT-only mode check (if `static_deps` empty, construct departures from Redis RT data alone)

**iOS:**
- `@MainActor` ViewModel error handling (double-fallback pattern)
- Protocol-based repository with graceful degradation (try API → try GRDB → return empty)
- Example: Nested `do-catch` for GRDB fallback

**API Envelope:**
- Response format: `{"data": {...}, "meta": {...}}` (must maintain)
- Empty state: `{"data": {"departures": [], "count": 0}, "meta": {...}}`

### 5. Edge Cases & Risks

**CRITICAL - Identify:**

**Edge Cases to Handle:**
1. **Supabase partially populated:** Some stops in table, others missing (should backend 404 missing stops or check Redis first?)
2. **Redis RT stale:** RT data expired (TTL 90s) but poller not running (should backend return stale or skip RT merge?)
3. **GRDB corrupted:** iOS bundled database unreadable (should app show error or re-download from backend?)
4. **Phase 1 never completed:** Supabase empty indefinitely (is RT-only mode sustainable long-term?)
5. **Network flaky:** API times out mid-request (should iOS retry or fallback to GRDB immediately?)

**Potential Regressions:**
1. **Dependency breaks:** If backend skips Supabase check, will other endpoints relying on `stops` table validation break?
2. **API contract changes:** Does RT-only mode response format differ from static+RT merge? (must maintain envelope)
3. **iOS state management:** Does double-fallback introduce race conditions in ViewModel? (@Published state updates)
4. **GRDB queries:** Does iOS call GRDB queries on main thread (blocking UI)? Should be async
5. **Celery tasks:** Does RT poller depend on Supabase tables being populated? (check task dependencies)

**Blast Radius:**
- **Backend:** Which endpoints use Supabase validation pattern? (routes.py, trips.py - need same fix?)
- **iOS:** Which ViewModels use `fetchDeparturesPage()`? (DeparturesView, TripDetailsView - need retesting)
- **Data flow:** Does removing Supabase check affect favorite stops sync? (favorites stored in Supabase)

**Cost Implications:**
- RT-only mode: Same API call rate (no change)
- GRDB fallback: Zero cost (local queries)
- Backend validation removal: Saves Supabase read queries (tiny cost reduction)

**Testing Strategy (Acceptance Criteria):**
1. **Layer 1 isolation:** Backend stopped → iOS shows GRDB departures (no network error)
2. **Layer 3 isolation:** Supabase empty, Redis populated → Backend returns RT departures
3. **All layers fail:** Backend stopped, GRDB corrupted → iOS shows "No departures" (not crash)
4. **Layer priority:** API slow (>5s timeout) → iOS shows GRDB data first (offline-first)
5. **Phase gate:** Phase 1 acceptance criteria verified before Phase 2 implementation

### 6. Trade-offs

**Pros/Cons of Refactoring Approach:**

**Option A: Remove Supabase check entirely**
- ✅ Pros: Simplest fix, allows RT-only mode, unblocks development
- ❌ Cons: No stop_id validation (invalid stops return empty, not 404)
- ⚖️ Trade-off: Lose validation for flexibility

**Option B: Check Redis for stop_id existence as alternative**
- ✅ Pros: Maintains validation, allows RT-only mode if stop in Redis
- ❌ Cons: More complex, Redis stop_id index required
- ⚖️ Trade-off: Validation preserved but added complexity

**Option C: Skip Supabase check only in dev/staging**
- ✅ Pros: Safe for production (keeps validation), unblocks dev
- ❌ Cons: Different behavior dev vs prod (risky), temporary workaround
- ⚖️ Trade-off: Quick fix but tech debt

**Recommended Approach:** ???

**What You're Optimizing For:**
- Simplicity (solo dev constraint) vs Robustness (validation)
- Speed (unblock development) vs Long-term design (sustainable architecture)
- Offline-first (GRDB primary) vs API-first (backend validation)

**What You're NOT Solving (Out of Scope):**
- Phase 1 GTFS import completion (separate task - populate Supabase)
- iOS performance optimization (GRDB query speed)
- Backend caching layer (Redis query optimization)
- Push notifications (future Phase 6 work)

---

## Response Format

**Markdown file** with sections above. Reference code using:
- File:line format: `backend/app/api/v1/stops.py:220`
- Inline code blocks with language tags: \`\`\`python, \`\`\`swift
- Clear headings: `##` for main sections, `###` for subsections

**Tone:** Technical, concise, solo-dev-friendly. Focus on **actionable recommendations** (not abstract principles).

**Structure:**
1. Analysis (validate root cause, reference specs)
2. Recommendations (decoupling strategy, layer independence)
3. Refactoring Plan (step-by-step with file:line references)
4. Code Examples (concrete snippets, follow DEVELOPMENT_STANDARDS patterns)
5. Edge Cases & Risks (comprehensive list with mitigations)
6. Trade-offs (pros/cons of approaches, what to optimize for)

**Critical Requirements:**
- Must reference code from context file using file:line format
- Must align recommendations with project constraints (solo dev, $25/mo budget)
- Must provide validation strategy (how to test layer independence)
- Must identify blast radius (which files/features affected by refactoring)

---

## Codebase Context

See: `docs/oracle/oracle-context-1763793313-refactor-decouple-3layer-architecture.txt` (~8544 tokens)

**Key Files in Context:**
1. `.workflow-logs/custom/root-cause-analysis-3layer-failure/ROOT_CAUSE_ANALYSIS.md` - Complete analysis
2. `backend/app/api/v1/stops.py` (lines 185-232) - Layer 2 blocking check
3. `backend/app/services/realtime_service.py` (lines 140-203) - Layer 3 RT merge
4. `backend/app/tasks/gtfs_rt_poller.py` (lines 325-375) - RT poller (working)
5. Architecture specs (sections only): IOS_APP_SPECIFICATION, BACKEND_SPECIFICATION, DEVELOPMENT_STANDARDS

**Missing from Context (Note):**
- iOS `DeparturesRepository.swift` - File not found in project (need iOS repository path correction)
- iOS `DatabaseManager.swift` - File not found in project
- If Oracle needs iOS code: Request from user or infer from architecture specs

---

## Next Steps After Oracle Response

1. **Review Oracle recommendations:** Validate against architecture specs and constraints
2. **Create implementation plan:** Use Oracle's refactoring plan as checkpoint-driven spec
3. **Apply fixes in priority order:** Backend Layer 2/3 decoupling first, then iOS Layer 1 fallback
4. **Validate layer independence:** Run acceptance tests (Layer 1 only, Layer 3 only, all fail scenarios)
5. **Update phase logs:** Document refactoring as custom work, update ROOT_CAUSE_ANALYSIS with resolution
6. **Enforce phase gates:** Add validation checklist to prevent future coupling violations

**Estimated Refactoring Duration (from Oracle):** TBD (Oracle to estimate)

**Risk Level:** Medium (architectural changes but no schema migrations, API contract preserved)

---

**Consultation Complete - Ready for Oracle Review**
