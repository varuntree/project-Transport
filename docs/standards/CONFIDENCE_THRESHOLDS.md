# Confidence Thresholds for AI Agents

This document defines confidence scoring guidelines for AI agents implementing features, fixing bugs, and making architectural decisions in the Sydney Transit App project.

---

## Confidence Score Definition

**Confidence = Probability you can implement correctly WITHOUT additional research**

Scale: 0.00 - 1.00 (0% - 100%)

---

## Scoring Guidelines

### 0.00-0.59: Very Low Confidence ❌

**Indicators:**
- Never seen this pattern/API/library before
- No examples in codebase or training data
- Multiple critical unknowns about how it works
- Would be guessing at implementation details
- No clear path from documentation to working code

**Required Action:** **STOP immediately, return blocker**

**Example:**
```
Task: "Implement custom MapKit clustering algorithm"
Confidence: 0.50

Blocker: "Custom clustering requires deep MapKit knowledge not in training data.

Options:
1. Use built-in MKClusterAnnotation (research Apple docs)
2. Find reference implementation (search GitHub/documentation)
3. User provides algorithm specification or reference

Cannot proceed without additional information."
```

---

### 0.60-0.79: Low Confidence ⚠️

**Indicators:**
- Vague familiarity but unclear on specifics
- Seen similar patterns but not this exact use case
- 1-2 critical unknowns remain
- Could implement with research
- Uncertain about edge cases or gotchas

**Required Action:** **Research required before proceeding**

**Research Steps:**
1. **iOS patterns:** Use SOSUMI MCP (Apple docs)
2. **Backend patterns:** Read DEVELOPMENT_STANDARDS.md
3. **External services:** WebFetch official documentation
4. **Architecture:** Review oracle/specs/*.md

**Example:**
```
Task: "Add SwiftUI .refreshable modifier with state reset"
Confidence: 0.70 (unclear on state interaction)

Action:
1. mcp__sosumi__searchAppleDocumentation("refreshable state management")
2. Create ios-research-swiftui-refreshable.md
3. New confidence: 0.92 → Proceed
```

---

### 0.80-0.89: Medium Confidence ✓

**Indicators:**
- Understand the pattern/API/approach
- Minor uncertainties on edge cases or specifics
- Can verify assumptions via documentation
- Know where to find answers if needed
- Familiar with similar implementations

**Required Action:** **Proceed with caution, flag risks**

**Guidelines:**
- Document assumptions explicitly
- Add extra error handling
- Include references to documentation
- Note potential edge cases in comments
- Run validation thoroughly

**Example:**
```
Task: "Implement Redis caching for GTFS patterns"
Confidence: 0.85

Proceeding with caution:
- Pattern: Follows DATA_ARCHITECTURE.md:Section 3
- Risk: TTL selection (will test with monitoring)
- Verification: Will validate with redis-cli GET/TTL
- Edge case: Cache invalidation on GTFS update (handled)
```

---

### 0.90-1.00: High Confidence ✅

**Indicators:**
- Implemented this pattern before (in training or this session)
- Clear examples in codebase following same pattern
- No significant unknowns
- Understand edge cases and error handling
- Can implement without looking up documentation

**Required Action:** **Proceed, minimal validation**

**Guidelines:**
- Follow existing patterns exactly
- Reference example code from codebase
- Standard error handling
- Routine testing

**Example:**
```
Task: "Add new FastAPI endpoint /api/v1/routes/{route_id}"
Confidence: 0.95

Proceeding:
- Pattern: Matches backend/app/api/v1/stops.py:L20-45
- Standards: DEVELOPMENT_STANDARDS.md:Section 2 (API envelope)
- Validation: curl test as per other endpoints
```

---

## Domain-Specific Thresholds

### iOS Patterns (ALWAYS research if confidence <90%)

**Why:** iOS training data is sparse, hallucinations common

**Critical APIs requiring research:**
- SwiftUI state management (@Published, @State, @ObservedObject)
- SwiftUI modifiers (`.refreshable`, `.task`, `.searchable`)
- GRDB query patterns (FTS5, WITHOUT ROWID, migrations)
- MapKit (annotations, clustering, polylines, regions)
- Core Location (authorization, background modes)
- URLSession (async/await, error handling, timeout)
- Keychain (SecItemAdd/Update/Delete, attributes)
- UserNotifications (UNUserNotificationCenter, APNs)

**Research Process:**
1. Check existing research files: `.workflow-logs/*/ios-research-*.md`
2. Search Apple docs: `mcp__sosumi__searchAppleDocumentation`
3. Fetch details: `mcp__sosumi__fetchAppleDocumentation`
4. Create concise research file (<500 tokens)
5. Verify code example compiles

**Threshold:**
- <0.90: **MUST research Apple docs** before implementing
- 0.90-0.95: Proceed, reference existing research files
- >0.95: Proceed if exact pattern exists in codebase

---

### External Services (Research if confidence <80%)

**Why:** APIs change, documentation is source of truth

**Services requiring documentation check:**
- Supabase (Auth, Database, Storage, Realtime)
- Redis (Commands, TTL behavior, data structures)
- NSW Transport API (Endpoints, rate limits, response formats)
- Railway/Fly.io (Deployment, environment variables)
- Cloudflare (WAF rules, rate limiting)

**Research Process:**
1. Check INTEGRATION_CONTRACTS.md or NSW_API_REFERENCE.md
2. Use Supabase MCP if available
3. WebFetch official documentation
4. Verify API signatures match current version

**Threshold:**
- <0.80: **MUST verify with official docs**
- 0.80-0.90: Proceed, document assumptions
- >0.90: Proceed if recently verified

---

### Architecture Decisions (Research if confidence <85%)

**Why:** Wrong architecture = cascading failures

**Critical areas:**
- Database schema changes (new tables, indexes, foreign keys)
- New patterns not in DEVELOPMENT_STANDARDS.md
- Performance-critical code (<120ms preview, <200ms template)
- Security-sensitive code (auth, tokens, PII)
- Breaking changes to APIs (versioning required)

**Research Process:**
1. Review oracle/specs/DATA_ARCHITECTURE.md
2. Review oracle/specs/BACKEND_SPECIFICATION.md
3. Check DEVELOPMENT_STANDARDS.md for existing patterns
4. Consult previous phase artifacts for precedent

**Threshold:**
- <0.85: **MUST align with architecture specs**
- 0.85-0.95: Proceed, document design decisions
- >0.95: Proceed if pattern already established

---

### Refactoring (Research if confidence <90%)

**Why:** Refactors have high blast radius

**High-risk refactors:**
- Large-scale code moves (>5 files)
- Pattern changes affecting multiple layers
- Breaking changes to internal APIs
- Database migrations (schema changes)
- State management restructuring (iOS stores)

**Research Process:**
1. Identify all callers/dependencies
2. Check test coverage
3. Plan rollback strategy
4. Verify no breaking changes to contracts

**Threshold:**
- <0.90: **MUST map all dependencies** before refactoring
- 0.90-0.95: Proceed, test thoroughly
- >0.95: Proceed if isolated change

---

## Research Sources by Context

### iOS Research

**Priority order:**

1. **Local research files (check first):**
   ```bash
   ls .workflow-logs/*/ios-research-*.md
   cat .workflow-logs/phase-2/ios-research-swiftui-refreshable.md
   ```

2. **SOSUMI MCP (Apple Documentation):**
   ```
   mcp__sosumi__searchAppleDocumentation("SwiftUI refreshable modifier")
   mcp__sosumi__fetchAppleDocumentation("swiftui/view/refreshable")
   ```

3. **WebFetch (only if MCP unavailable):**
   ```
   WebFetch("https://developer.apple.com/documentation/swiftui/view/refreshable")
   ```

**Create research file:**
```markdown
.workflow-logs/{plan_name}/ios-research-{topic}.md

Format:
- Key Pattern (2-3 sentences)
- Code Example (minimal, compiles)
- Critical Constraints
- Common Gotchas
- API Reference
- Relevance to Plan
```

---

### Backend Research

**Priority order:**

1. **DEVELOPMENT_STANDARDS.md:**
   ```bash
   cat oracle/DEVELOPMENT_STANDARDS.md
   # Check specific sections
   ```

2. **Architecture Specs:**
   ```bash
   cat oracle/specs/BACKEND_SPECIFICATION.md
   cat oracle/specs/DATA_ARCHITECTURE.md
   ```

3. **Codebase Examples:**
   ```bash
   grep -r "pattern_name" backend/app/ --context=5
   ```

4. **Official Library Docs:**
   ```
   WebFetch("https://fastapi.tiangolo.com/...")
   WebFetch("https://docs.celeryq.dev/...")
   ```

---

### External Services

**Priority order:**

1. **Integration Contracts:**
   ```bash
   cat oracle/specs/INTEGRATION_CONTRACTS.md
   cat oracle/specs/NSW_API_REFERENCE.md
   ```

2. **Supabase MCP (if Supabase-related):**
   ```
   mcp__supabase__search_docs("query")
   mcp__supabase__get_project("project_id")
   ```

3. **Official Documentation:**
   ```
   WebFetch("https://supabase.com/docs/...")
   WebFetch("https://redis.io/docs/...")
   ```

---

## Confidence Checks in Workflows

### Planning Stage

**Exploration Subagent:**
- If <0.80 confident on affected systems → Expand search scope
- If <0.70 confident on task understanding → Return blocker, need clarification

**Research Subagent:**
- If <0.90 confident on iOS patterns → **MUST research** Apple docs
- If no research files exist → Create research files

**Planning Agent:**
- If <0.85 confident on approach → List alternatives, flag decision points
- If <0.70 confident overall → Return blocker with open questions

---

### Implementation Stage

**Before writing ANY code:**

```
1. Check confidence per file/pattern
   - Am I 80%+ confident?
   - Is this iOS-specific? (needs 90%+)
   - Is this new architecture? (needs 85%+)

2. If confidence < threshold:
   - Read DEVELOPMENT_STANDARDS.md section
   - Check ios-research-*.md files
   - WebFetch official docs
   - If still <threshold: Return blocker

3. Never hallucinate:
   - Return blocker > guess
   - Flag uncertainty explicitly
   - Document assumptions
```

**Example Check:**
```python
# Before implementing SwiftUI state binding
if confidence_on_swiftui_state < 0.90:
    # Read ios-research-swiftui-state.md
    # Check Apple docs via SOSUMI
    # Update confidence
    if confidence_still_low:
        return BlockerStatus(
            reason="SwiftUI state management unclear",
            requires="research",
            documentation_needed=["@Published vs @State usage"]
        )
```

---

### Bug Diagnosis Stage

**Map Subagent:**
- If <0.80 on primary phase → List multiple phases with confidence scores
- If <0.60 on affected systems → Expand search, return uncertain mapping

**Diagnose Subagent:**
- If <0.80 on root cause → Return blocker with partial diagnosis
- If <0.70 overall → List alternative diagnoses, flag as uncertain

**Fix Subagent:**
- If <0.80 on fix approach → Return "needs_redesign" status
- If <0.60 on fix → Return blocker, cannot implement safely

---

## Reporting Confidence

### In JSON Returns

**Format:**
```json
{
  "confidence": 0.87,
  "confidence_breakdown": {
    "task_understanding": 0.95,
    "approach_validity": 0.90,
    "implementation_details": 0.75
  },
  "low_confidence_areas": [
    "SwiftUI @Published array updates - exact update semantics unclear"
  ],
  "research_completed": [
    "Read ios-research-swiftui-state.md",
    "Checked DEVELOPMENT_STANDARDS.md Section 4",
    "Verified against backend/app/api/v1/stops.py example"
  ],
  "assumptions": [
    "Assuming @Published triggers update on array mutation (verified in research)"
  ]
}
```

---

### In Text Reports

**Format:**
```markdown
## Confidence Assessment

**Overall:** 0.87 (Medium-High)

**High Confidence (0.90+):**
- Backend API pattern: Matches backend/app/api/v1/stops.py:L20-45
- Database query: Standard PostGIS pattern from DATA_ARCHITECTURE.md
- Error handling: Follows DEVELOPMENT_STANDARDS.md Section 5

**Medium Confidence (0.80-0.89):**
- iOS MapKit clustering: Researched Apple docs → ios-research-mapkit-clustering.md
- Redis caching strategy: Verified against DATA_ARCHITECTURE.md:Section 3
- Celery task timeout: Checked similar tasks in backend/app/tasks/

**Low Confidence (<0.80):**
- None (all uncertainties researched and resolved)

**Research Completed:**
1. Apple docs: MapKit annotation clustering
   - Created: ios-research-mapkit-clustering.md
   - Key finding: Use MKClusterAnnotation protocol
2. Verified Redis TTL pattern: backend/app/db/redis_client.py:L45-67
3. Checked Celery timeout: backend/app/tasks/gtfs_rt_poller.py:L12

**Assumptions:**
- MapKit clustering will use built-in MKClusterAnnotation (not custom algorithm)
- Redis TTL of 300s matches GTFS-RT update frequency (verified in spec)
```

---

## Enforcement Rules

### Automated Checks (Orchestrator)

**When receiving subagent result:**

```
1. Check if confidence field exists and is reported
2. If confidence < threshold for task type:
   - Check if research was completed
   - If no research: REJECT result, require research
   - If research done: Verify research files exist
3. If high-risk area (iOS, security, performance):
   - Require confidence ≥0.90
   - Verify research documentation
4. If blocker returned:
   - Check if valid reason provided
   - Verify alternatives explored
   - Escalate to user with diagnosis
```

---

### Review Checklist (For Orchestrator Validation)

**Before accepting subagent work:**

- [ ] Subagent reported confidence score?
- [ ] Confidence meets threshold for task type?
  - iOS work: ≥0.90
  - External service: ≥0.80
  - Architecture: ≥0.85
  - Refactor: ≥0.90
  - General: ≥0.80
- [ ] If <threshold, was research completed?
- [ ] Research files created (if applicable)?
- [ ] Low confidence areas documented?
- [ ] Assumptions stated explicitly?
- [ ] Alternative approaches considered (if uncertainty)?

---

## Examples

### ❌ Bad (Hallucination)

```
Agent: "Implementing SwiftUI .refreshable with custom binding"
Confidence: 0.65 (never seen custom binding with .refreshable)
Research: None
Action: Implemented anyway

Result: Bug - refresh breaks state management

Why Bad:
- Confidence <0.90 for iOS work
- No research despite uncertainty
- Hallucinated API usage pattern
```

---

### ✅ Good (Research)

```
Agent: "Need SwiftUI .refreshable modifier with state reset"
Confidence: 0.70 (unclear on state interaction)
Research:
  1. mcp__sosumi__searchAppleDocumentation("refreshable")
  2. Created ios-research-swiftui-refreshable.md
  3. Found standard pattern in Apple docs
New Confidence: 0.92
Action: Proceed with documented pattern

Result: Implementation correct, state resets properly

Why Good:
- Recognized low confidence (<0.90)
- Researched before implementing
- Documented findings for future reference
- Raised confidence above threshold
```

---

### ✅ Good (Blocker)

```
Agent: "Need custom MapKit clustering algorithm"
Confidence: 0.50 (no training data, no codebase examples)
Research: Searched Apple docs, found only built-in clustering
Action: Return blocker

Blocker:
  "Custom clustering requires deep MapKit knowledge.

  Options:
  1. Use built-in MKClusterAnnotation (recommended)
  2. Find reference implementation (GitHub/documentation)
  3. User provides algorithm specification

  Cannot proceed safely without additional information."

Result: User chose Option 1 (built-in), implementation succeeded

Why Good:
- Recognized very low confidence (<0.60)
- Researched but still uncertain
- Returned blocker instead of guessing
- Provided clear alternatives
```

---

## Summary

**Key Principles:**

1. **Honesty over speed:** Return blocker > hallucinate
2. **Research is required:** iOS <0.90, External <0.80, Architecture <0.85
3. **Document confidence:** Always report score + breakdown
4. **Verify before proceeding:** Check threshold before implementing
5. **No excuses:** If uncertain, research or return blocker

**Thresholds Quick Reference:**

| Task Type | Minimum Confidence | Research Required If Below |
|-----------|-------------------|---------------------------|
| iOS Patterns | 0.90 | Yes (Apple docs via SOSUMI) |
| External Services | 0.80 | Yes (Official docs via WebFetch) |
| Architecture | 0.85 | Yes (Oracle specs) |
| Refactoring | 0.90 | Yes (Dependency mapping) |
| General Implementation | 0.80 | Yes (Standards + examples) |

**When in doubt:** Research or return blocker. Never guess.
