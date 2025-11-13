# Oracle Prompt: Complete NSW Transport API Reference Documentation

## Mission

Create **comprehensive, implementation-ready API reference** for all NSW Transport GTFS/GTFS-RT endpoints needed for Sydney Transit App MVP (Phases 0-7). Output must be **copy-paste ready** for backend/iOS implementation with zero ambiguity.

---

## Context: What We've Done So Far

### Successfully Tested Authentication
- **Portal:** https://opendata.transport.nsw.gov.au/
- **API Token:** JWT format from "API Tokens" tab
- **Auth Header:** `Authorization: apikey <JWT_TOKEN>`
- **Auth Status:** ✅ Working (confirmed with 15+ endpoint tests)

### Current Test Results (2025-11-13)

**✅ WORKING (HTTP 200):**
- Static GTFS complete bundle
- Buses: vehicle positions (v1), trip updates (v1)
- Light Rail: vehicle positions (v1)
- NSW TrainLink: vehicle positions (v1), trip updates (v1)
- Sydney Trains: vehicle positions (v2), trip updates (v2)
- Metro: vehicle positions (v2), trip updates (v2)
- Alerts: all modes (v2), buses (v2), Sydney trains (v2), metro (v2)

**❌ FAILING (HTTP 404):**
- Ferries: vehicle positions `/v1/gtfs/vehiclepos/ferries` → 404
- Ferries: trip updates `/v1/gtfs/realtime/ferries` → 404

**⚠️ KNOWN DEPRECATED:**
- v1 alerts (all modes) - deprecated June 2022, replaced by v2

---

## Critical Issues to Research

### Issue 1: Ferries 404 Mystery
**Problem:**
- Documentation says ferries endpoints exist at `/v1/gtfs/vehiclepos/ferries` and `/v1/gtfs/realtime/ferries`
- Both return 404 with our working API token
- Buses/trains/metro work fine with same auth

**Questions:**
1. Are ferry endpoints moved/renamed? (e.g., `/sydneyferries` suffix like Medium article showed?)
2. Do ferries require separate dataset subscription in portal?
3. Are ferries deprecated/consolidated into another feed?
4. Is there a v2 ferry endpoint we're missing?

**Required:** Working ferry vehicle positions + trip updates endpoints (or confirmation they're unavailable).

---

### Issue 2: Dataset Subscription Confusion
**Problem:**
- Oracle's previous response said: *"add 'Public Transport – Realtime – Alerts – v2' to your Open Data Application"*
- We **did NOT** perform this step (only created API token)
- Yet `/v2/gtfs/alerts/*` endpoints return **200 OK** with data

**Questions:**
1. Is dataset subscription still required in 2024-2025 portal?
2. Did TfNSW change to auto-subscribe all open datasets?
3. Do Bronze plan users get all GTFS/GTFS-RT datasets by default now?
4. Are there hidden datasets we're missing because we didn't subscribe?

**Required:** Clarify portal workflow - do we need "Applications → Add Datasets" step or not?

---

### Issue 3: Static GTFS Per-Mode vs Complete Bundle
**Problem:**
- We confirmed `/v1/publictransport/timetables/complete/gtfs` returns 227MB ZIP
- Oracle mentioned `/v1/gtfs/schedule/{mode}` for "Timetables - For Realtime" alignment
- Unclear which modes have separate static feeds vs consolidated

**Questions:**
1. Which modes have separate static GTFS endpoints?
2. Are per-mode static feeds necessary for realtime matching, or is complete bundle sufficient?
3. Do Sydney Trains/Metro require `/v2/gtfs/schedule/*` for realtime alignment?

**Required:** Complete list of static GTFS endpoints (per-mode vs bundle) with use cases.

---

### Issue 4: Light Rail Inner West vs Legacy
**Problem:**
- Oracle mentioned `/v2/gtfs/vehiclepos/lightrail/innerwest` for Inner West Light Rail
- We tested `/v1/gtfs/vehiclepos/lightrail` (works)
- Unclear if v1 covers all light rail or just legacy Newcastle/CBD

**Questions:**
1. What's the difference between v1 lightrail and v2 lightrail/innerwest?
2. Does v1 lightrail include Inner West Light Rail or not?
3. Do we need both v1 and v2 endpoints for complete Sydney light rail coverage?

**Required:** Clarify light rail endpoint strategy for full Sydney coverage.

---

## Required Output Format

### Part 1: Portal Configuration Checklist

**Provide step-by-step:**
```
1. Create account at https://opendata.transport.nsw.gov.au/
2. Verify email activation
3. Navigate to: [exact path]
4. Create API Token: [exact steps]
5. [IF REQUIRED] Subscribe to datasets:
   - Dataset 1: [name] → [how to add to application]
   - Dataset 2: [name] → [how to add to application]
   ...
6. [IF NOT REQUIRED] Confirm: "Dataset subscription no longer needed, token gives access to all open datasets"
```

**Explicitly state:** Are steps beyond "create API token" required or optional in 2024-2025?

---

### Part 2: Complete Endpoint Reference Table

**Format:** Markdown table, copy-paste ready for implementation

**Required columns:**
- **Category** (Static GTFS, Vehicle Positions, Trip Updates, Alerts)
- **Mode** (Buses, Sydney Trains, Metro, Ferries, Light Rail, NSW TrainLink, All)
- **API Version** (v1 or v2)
- **Endpoint Path** (full path, no base URL)
- **Status** (✅ Confirmed Working / ⚠️ Untested / ❌ Deprecated / 🔍 Investigate)
- **Notes** (use cases, caveats, alternatives)

**Example row:**
| Category | Mode | Version | Endpoint | Status | Notes |
|----------|------|---------|----------|--------|-------|
| Vehicle Positions | Buses | v1 | `/v1/gtfs/vehiclepos/buses` | ✅ Confirmed | Tested 2025-11-13, 286KB response |
| Alerts | Buses | v1 | `/v1/gtfs/alerts/buses` | ❌ Deprecated | Use `/v2/gtfs/alerts/buses` instead |
| Vehicle Positions | Ferries | v1 | `/v1/gtfs/vehiclepos/ferries` | 🔍 Returns 404 | See Issue 1 - investigate correct endpoint |

**Must include ALL:**
- Static GTFS (complete bundle + per-mode if applicable)
- Vehicle Positions (all modes: buses, trains, metro, ferries, light rail, regional)
- Trip Updates (all modes)
- Service Alerts (all modes + combined feed)

---

### Part 3: Authentication Reference

**Provide:**
```bash
# Base URL
BASE_URL="https://api.transport.nsw.gov.au"

# Headers (for all endpoints)
Authorization: apikey <YOUR_API_TOKEN>
Accept: application/x-google-protobuf   # For GTFS-RT binary feeds
# OR
Accept: application/zip                  # For static GTFS downloads

# Example curl for each category:
# 1. Static GTFS download
curl -H "Authorization: apikey TOKEN" "${BASE_URL}/v1/publictransport/timetables/complete/gtfs" -o gtfs.zip

# 2. Vehicle positions (protobuf)
curl -H "Authorization: apikey TOKEN" -H "Accept: application/x-google-protobuf" "${BASE_URL}/v1/gtfs/vehiclepos/buses" -o vehicles.pb

# 3. Trip updates (protobuf)
curl -H "Authorization: apikey TOKEN" -H "Accept: application/x-google-protobuf" "${BASE_URL}/v2/gtfs/realtime/sydneytrains" -o trips.pb

# 4. Service alerts (protobuf)
curl -H "Authorization: apikey TOKEN" -H "Accept: application/x-google-protobuf" "${BASE_URL}/v2/gtfs/alerts/all" -o alerts.pb
```

---

### Part 4: Issue Resolutions

**For each issue (1-4 above), provide:**

**Issue 1 (Ferries):**
- ✅ Correct working endpoint: `[path]`
- OR ❌ Ferries unavailable: `[reason + workaround]`
- Evidence: [forum post / doc link / working example]

**Issue 2 (Dataset Subscription):**
- ✅ Required: [exact steps]
- OR ❌ Not required: [confirmation + why alerts work without it]

**Issue 3 (Static GTFS per-mode):**
- List of per-mode endpoints with use cases
- When to use complete bundle vs per-mode

**Issue 4 (Light Rail):**
- Clarify v1 vs v2 coverage
- Recommend single endpoint or both for Sydney

---

### Part 5: Implementation Recommendations

**Provide guidance for Phases 1-2:**

**Phase 1 (Static Data):**
- Recommend: Use complete bundle OR per-mode? Why?
- Download frequency: Daily? Weekly?
- Storage strategy: Full 227MB or filter Sydney-only?

**Phase 2 (Real-time):**
- Polling frequency per endpoint type (vehicle pos, trip updates, alerts)
- Which endpoints to poll together vs separate Celery tasks
- Rate limit strategy: 5 req/s across all endpoints or per-endpoint?

---

### Part 6: Bronze Plan Limitations

**Confirm:**
- Which endpoints included in Bronze (free) plan?
- Any datasets requiring paid upgrade?
- Rate limits: 60K req/day, 5 req/s confirmed account-wide?
- Bandwidth limits or download caps?

---

## Research Mandate

**Primary sources (prioritize recent):**
1. **TfNSW Open Data Hub official docs** (2024-2025 versions)
2. **Developer forum posts** (especially 2023-2025 for v2 migration)
3. **Working GitHub repos** (check actual endpoint usage in code)
4. **Medium/blog posts** (like the 2024 ferry tracking article)

**For ferry issue specifically:**
- Search: "sydney ferries gtfs real-time 2024 2025"
- Look for: Working ferry endpoint examples in recent code
- Check: TfNSW forum threads about ferry data access

**For dataset subscription:**
- Search: "transport nsw add dataset to application 2024"
- Look for: Recent portal UI changes, auto-subscription announcements

**Cite sources:** Every endpoint must have evidence (doc link, forum post, or working repo).

---

## Success Criteria

Output is successful if:
- ✅ Agent in Phase 1-2 can copy-paste endpoint table into code (zero ambiguity)
- ✅ All 4 issues resolved with clear answers (not "maybe" or "depends")
- ✅ Ferry endpoints work OR confirmed unavailable with workaround
- ✅ Portal setup is 1-2-3 step checklist (no guessing required)
- ✅ Every endpoint has status: confirmed working, deprecated, or investigated
- ✅ Code examples are copy-paste ready (bash, Python, Swift snippets)

---

## Constraints

**Do NOT:**
- Suggest new external services (must use NSW Transport API only)
- Recommend alternative data sources (must solve with TfNSW APIs)
- Leave issues unresolved with "contact support" (research until answer found)

**Do:**
- Test claims against our confirmed working endpoints
- Prioritize 2024-2025 sources over older docs
- Provide fallback options if primary endpoint unavailable
- Distinguish between "deprecated but works" vs "returns 404"

---

## Deliverable Summary

**Single markdown document containing:**
1. Portal setup checklist (5-10 steps)
2. Complete endpoint reference table (20-30 rows)
3. Auth examples (bash/Python/Swift)
4. Issue resolutions (ferries, subscriptions, static GTFS, light rail)
5. Implementation recommendations (polling, rate limits, data strategy)
6. Bronze plan confirmation (limits, inclusions)

**Length:** 100-200 lines (concise but complete)
**Format:** Copy-paste ready for `oracle/specs/NSW_API_REFERENCE.md`

---

**This documentation will be the source of truth for Phase 1-7 implementation. Be thorough.**
