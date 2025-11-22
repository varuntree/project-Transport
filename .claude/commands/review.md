# Review Implementation

Post-implementation quality gate using multi-panel review system. Validates work against product vision, technical standards, robustness, regression risks, and documentation sync.

## Usage

```
/review                           # Review recent changes (auto-detect scope)
/review phase-2-checkpoint-3      # Review specific checkpoint
/review custom-plan-name          # Review custom plan implementation
/review "last 5 commits"          # Review explicit scope
```

## Variables

scope: $1 (optional: auto-detects recent changes if omitted)

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for triage and prioritization.**

---

## Architecture: 5-Panel Concurrent Review

**Orchestrator:**
- Detects review scope
- Launches 5 review panels in parallel
- Aggregates findings
- Prioritizes issues (P0/P1/P2/P3)
- Generates actionable report

**5 Review Panels (run concurrently):**
1. Product Alignment Reviewer
2. Technical Implementation Reviewer
3. Edge Cases & Robustness Reviewer
4. Regression Risk Analyzer
5. Documentation Sync Reviewer

---

## Stage 1: Detect Review Scope

**Orchestrator identifies what to review:**

### 1.1 Parse Scope Argument

```bash
# Create review session
timestamp=$(date +%s)
review_id="review-${timestamp}"
review_dir=".workflow-logs/reviews/${review_id}"
mkdir -p "${review_dir}"

# Determine scope
if [ -z "$1" ]; then
  # Auto-detect: recent changes
  scope_type="auto"
  scope_ref="recent_changes"
elif [[ "$1" =~ ^phase-([0-9]+)-checkpoint-([0-9]+)$ ]]; then
  # Specific checkpoint
  scope_type="checkpoint"
  phase_number="${BASH_REMATCH[1]}"
  checkpoint_number="${BASH_REMATCH[2]}"
  scope_ref="phase-${phase_number}-checkpoint-${checkpoint_number}"
elif [[ "$1" =~ ^phase-([0-9]+)$ ]]; then
  # Full phase
  scope_type="phase"
  phase_number="${BASH_REMATCH[1]}"
  scope_ref="phase-${phase_number}"
elif [ -f "specs/${1}-plan.md" ]; then
  # Custom plan
  scope_type="custom"
  plan_name="$1"
  scope_ref="${plan_name}"
else
  # Explicit description
  scope_type="explicit"
  scope_ref="$1"
fi
```

### 1.2 Gather Context

**For checkpoint scope:**
```bash
# Load checkpoint artifacts
exploration_report=".workflow-logs/phases/phase-${phase_number}/exploration-report.json"
checkpoint_design=".workflow-logs/phases/phase-${phase_number}/checkpoint-${checkpoint_number}-design.md"
checkpoint_result=".workflow-logs/phases/phase-${phase_number}/checkpoint-${checkpoint_number}-result.json"

# Get changed files from checkpoint result
changed_files=$(cat "${checkpoint_result}" | jq -r '.files_created[],.files_modified[]')

# Get git diff for checkpoint
git diff phase-${phase_number}-checkpoint-$((checkpoint_number-1))..phase-${phase_number}-checkpoint-${checkpoint_number} --name-only
```

**For phase scope:**
```bash
# Load phase artifacts
exploration_report=".workflow-logs/phases/phase-${phase_number}/exploration-report.json"
phase_plan="specs/phase-${phase_number}-implementation-plan.md"
phase_completion=".workflow-logs/phases/phase-${phase_number}/phase-completion.json"

# Get all changed files in phase
git diff main..phase-${phase_number}-implementation --name-only
```

**For custom plan scope:**
```bash
# Load custom plan artifacts
exploration_report=".workflow-logs/custom/${plan_name}/exploration-report.json"
plan_file="specs/${plan_name}-plan.md"
completion_report=".workflow-logs/custom/${plan_name}/completion-report.json"

# Get changed files
git diff main..${plan_name}-implementation --name-only
```

**For auto scope:**
```bash
# Detect most recent work
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "main")
changed_files=$(git diff --name-only ${latest_tag}..HEAD)

# Try to find associated plan/phase
most_recent_artifact=$(ls -t .workflow-logs/{phases/phase-*/phase-completion.json,custom/*/completion-report.json} 2>/dev/null | head -1)
```

### 1.3 Save Review Context

```bash
echo "{
  \"review_id\": \"${review_id}\",
  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"scope_type\": \"${scope_type}\",
  \"scope_ref\": \"${scope_ref}\",
  \"changed_files\": $(echo "${changed_files}" | jq -R . | jq -s .),
  \"git_diff_base\": \"${latest_tag}\",
  \"exploration_report\": \"${exploration_report}\",
  \"plan_file\": \"${plan_file}\"
}" > "${review_dir}/review-context.json"
```

---

## Stage 2: Launch Review Panels (Parallel)

**Orchestrator launches 5 subagents concurrently:**

### Panel 1: Product Alignment Reviewer

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Product alignment review for ${scope_ref}"
- prompt: "
TASK: Product Alignment Review

REVIEW SCOPE:
$(cat ${review_dir}/review-context.json)

CHANGED FILES:
$(echo "${changed_files}")

YOUR MISSION:
Evaluate if this implementation serves the long-term product vision and goals.

ACTIONS:

1. **Read Product Specifications:**
   - oracle/specs/SYSTEM_OVERVIEW.md (product positioning, features, user needs)
   - Relevant phase spec (if phase work): oracle/phases/PHASE_${phase_number}_*.md
   - Implementation plan: ${plan_file}

2. **Read Implementation:**
   - Review all changed files
   - Understand what was built
   - Compare actual implementation vs planned functionality

3. **Evaluate Product Alignment:**

   **Questions to answer:**
   - Does this solve a real user need from SYSTEM_OVERVIEW.md?
   - Is this a complete vertical slice (working end-to-end feature)?
   - Does it advance the product roadmap (IMPLEMENTATION_ROADMAP.md)?
   - Are there missing capabilities that make this feature incomplete?
   - Does this align with product positioning (TripView reliability + Transit features)?

   **Vision Drift Detection:**
   - Are we building features not in specs?
   - Are we over-engineering for 0 users?
   - Are we ignoring key constraints (budget, offline-first, solo dev)?

4. **Score Alignment:**
   Calculate 0-100% score:
   - 90-100%: Perfect alignment, advances product vision
   - 70-89%: Good alignment, minor gaps
   - 50-69%: Moderate drift, some misalignment
   - <50%: Significant drift, needs course correction

RETURN FORMAT (JSON):
Save to: ${review_dir}/panel-1-product-alignment.json

{
  \"panel\": \"product_alignment\",
  \"alignment_score\": 0-100,
  \"verdict\": \"aligned|minor_drift|moderate_drift|significant_drift\",
  \"findings\": [
    {
      \"priority\": \"P0|P1|P2|P3\",
      \"category\": \"vision_drift|incomplete_feature|missing_capability|over_engineering\",
      \"title\": \"Brief title\",
      \"description\": \"What's the issue?\",
      \"affected_files\": [\"file1.py\"],
      \"evidence\": \"Specific examples from code/specs\",
      \"recommendation\": \"Specific action to fix\"
    }
  ],
  \"strengths\": [\"What's done well\"],
  \"user_impact\": \"How does this affect end users?\",
  \"product_completeness\": \"Is this a usable feature or partial implementation?\"
}

PRIORITY GUIDELINES:
- P0: Significant vision drift (>30%), building wrong thing
- P1: Incomplete feature (unusable without more work)
- P2: Missing nice-to-have capabilities
- P3: Future enhancements

DO NOT:
- Critique code style (Panel 2's job)
- Check standards compliance (Panel 2's job)
- Analyze edge cases (Panel 3's job)
- Focus ONLY on product/user/vision alignment
"
```

### Panel 2: Technical Implementation Reviewer

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Technical implementation review for ${scope_ref}"
- prompt: "
TASK: Technical Implementation Review

REVIEW SCOPE:
$(cat ${review_dir}/review-context.json)

CHANGED FILES:
$(echo "${changed_files}")

YOUR MISSION:
Verify implementation follows technical standards, patterns, and architecture specs.

ACTIONS:

1. **Read Standards & Architecture:**
   - oracle/DEVELOPMENT_STANDARDS.md (patterns, logging, error handling)
   - oracle/specs/BACKEND_SPECIFICATION.md (if backend changes)
   - oracle/specs/IOS_APP_SPECIFICATION.md (if iOS changes)
   - oracle/specs/INTEGRATION_CONTRACTS.md (if API changes)
   - oracle/specs/DATA_ARCHITECTURE.md (if data model changes)

2. **Read Implementation:**
   - Review all changed files line by line
   - Check imports, function signatures, class structure
   - Verify logging statements
   - Check error handling patterns

3. **Verify Standards Compliance:**

   **Backend (if applicable):**
   - Structured logging: JSON format, event-based, no PII
   - API envelope: All responses wrapped in {\"data\": {...}, \"meta\": {...}}
   - Singleton clients: get_supabase()/get_redis() via Depends()
   - Celery tasks: Proper decorators (queue, retries, time limits)
   - Pydantic models: Request/response validation
   - Error handling: Try/except with structured logging

   **iOS (if applicable):**
   - @MainActor on ViewModels
   - Protocol-based repositories
   - async/await for network calls
   - GRDB queries follow pattern model
   - No force unwraps (use guard/if let)
   - SwiftUI state management (@Published, @State)

   **API Contracts (if applicable):**
   - New endpoints documented in INTEGRATION_CONTRACTS.md?
   - Breaking changes flagged?
   - Backward compatibility maintained?

4. **Identify Violations:**
   - Standards not followed
   - Pattern deviations without justification
   - Code smells (duplicated logic, magic numbers, etc.)
   - Missing error handling
   - Missing logging
   - Inconsistent naming

RETURN FORMAT (JSON):
Save to: ${review_dir}/panel-2-technical-implementation.json

{
  \"panel\": \"technical_implementation\",
  \"compliance_score\": 0-100,
  \"verdict\": \"compliant|minor_violations|moderate_violations|significant_violations\",
  \"findings\": [
    {
      \"priority\": \"P0|P1|P2|P3\",
      \"category\": \"standards_violation|pattern_deviation|code_smell|missing_error_handling|missing_logging\",
      \"title\": \"Brief title\",
      \"description\": \"What's violated?\",
      \"affected_files\": [\"file.py:45-67\"],
      \"standard_reference\": \"DEVELOPMENT_STANDARDS.md:Section 2\",
      \"evidence\": \"Specific code example\",
      \"recommendation\": \"How to fix (cite correct pattern)\"
    }
  ],
  \"strengths\": [\"What's done well\"],
  \"architecture_alignment\": \"Does implementation match architecture specs?\"
}

PRIORITY GUIDELINES:
- P0: Security issues (SQL injection, missing auth), data corruption risks
- P1: Standards violations, missing error handling (user-facing)
- P2: Code smells, minor pattern deviations
- P3: Style issues, optimization opportunities

DO NOT:
- Check product alignment (Panel 1's job)
- Analyze edge cases (Panel 3's job)
- Check regressions (Panel 4's job)
- Focus ONLY on technical correctness
"
```

### Panel 3: Edge Cases & Robustness Reviewer

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Edge cases & robustness review for ${scope_ref}"
- prompt: "
TASK: Edge Cases & Robustness Review

REVIEW SCOPE:
$(cat ${review_dir}/review-context.json)

CHANGED FILES:
$(echo "${changed_files}")

YOUR MISSION:
Identify unhandled edge cases, missing validations, and failure modes.

ACTIONS:

1. **Read Implementation:**
   - Review all changed files
   - Identify user inputs, external dependencies, async operations
   - Map data flow (where can things go wrong?)

2. **Read Constraints:**
   - oracle/specs/SYSTEM_OVERVIEW.md (constraints section)
   - oracle/specs/DATA_ARCHITECTURE.md (data assumptions)
   - NSW API limits (5 req/s, 60K calls/day)
   - Budget constraints ($25/mo)

3. **Analyze Edge Cases:**

   **Input Validation:**
   - SQL injection / XSS vulnerabilities?
   - Null/empty string handling?
   - Invalid IDs, malformed requests?
   - Large payloads (DoS risk)?

   **External Dependencies:**
   - NSW API rate limit exceeded?
   - NSW API timeout/error handling?
   - Supabase connection failure?
   - Redis unavailable?
   - Network offline (iOS)?

   **Data Edge Cases:**
   - GTFS-RT feed missing modalities?
   - Stop IDs not in GTFS static data?
   - Routes with NULL route_short_name?
   - Empty departures list?
   - Duplicate trip IDs?

   **Timing Edge Cases:**
   - DST transitions (2am → 3am, 3am → 2am)?
   - Timezone handling (Sydney vs UTC)?
   - Celery task overlap (concurrent runs)?
   - Race conditions (iOS async state updates)?

   **Resource Limits:**
   - Memory leaks (append without clear)?
   - Celery task memory growth?
   - Redis cache size limits?
   - iOS app size limits (<50MB)?

4. **Identify Missing Robustness:**
   - Circuit breakers for external services?
   - Retry logic with exponential backoff?
   - Graceful degradation (offline mode)?
   - User-facing error messages (vs stack traces)?

RETURN FORMAT (JSON):
Save to: ${review_dir}/panel-3-edge-cases-robustness.json

{
  \"panel\": \"edge_cases_robustness\",
  \"robustness_score\": 0-100,
  \"verdict\": \"robust|minor_gaps|moderate_gaps|significant_gaps\",
  \"findings\": [
    {
      \"priority\": \"P0|P1|P2|P3\",
      \"category\": \"missing_validation|unhandled_error|race_condition|resource_leak|security_gap\",
      \"title\": \"Brief title\",
      \"description\": \"What edge case is unhandled?\",
      \"affected_files\": [\"file.py:45\"],
      \"scenario\": \"Step-by-step reproduction\",
      \"impact\": \"What happens? (crash, data corruption, bad UX)\",
      \"recommendation\": \"Specific fix (add validation, try/except, etc.)\"
    }
  ],
  \"strengths\": [\"What's handled well\"],
  \"failure_modes\": [\"List likely failure scenarios\"]
}

PRIORITY GUIDELINES:
- P0: Security vulnerabilities, data corruption, crashes on common scenarios
- P1: Crashes on uncommon scenarios, bad UX on errors, missing validations
- P2: Missing graceful degradation, suboptimal error messages
- P3: Rare edge cases, optimization opportunities

DO NOT:
- Check standards compliance (Panel 2's job)
- Check product alignment (Panel 1's job)
- Check regressions (Panel 4's job)
- Focus ONLY on robustness and edge cases
"
```

### Panel 4: Regression Risk Analyzer

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Regression risk analysis for ${scope_ref}"
- prompt: "
TASK: Regression Risk Analysis

REVIEW SCOPE:
$(cat ${review_dir}/review-context.json)

CHANGED FILES:
$(echo "${changed_files}")

YOUR MISSION:
Identify potential regressions and assess blast radius of changes.

ACTIONS:

1. **Map Dependencies:**

   **For each changed file:**
   - Who imports this? (backend: grep -r 'from .* import', iOS: grep -r 'import')
   - What calls these functions? (search for function name usage)
   - Which APIs consume this? (iOS calls backend endpoints)
   - Which Celery tasks depend on this? (task imports)

2. **Analyze Changes:**

   **Breaking Changes:**
   - Database schema changes (column renamed/deleted)?
   - API endpoint signature changes (params removed/renamed)?
   - Pydantic model changes (fields removed)?
   - Swift model changes (properties removed)?
   - Celery task signature changes?

   **Data Assumptions:**
   - Changed how GTFS data is interpreted?
   - Changed Redis cache key format?
   - Changed GTFS-RT parsing logic?
   - Changed pattern model queries?

   **Behavioral Changes:**
   - Changed error handling (now throws instead of returns None)?
   - Changed return types?
   - Changed side effects (now writes to DB)?
   - Changed timing (async → sync, sync → async)?

3. **Assess Blast Radius:**

   **For each risky change:**
   - How many features affected?
   - iOS + backend both impacted?
   - Data migration required?
   - User-facing regression (breaks app)?
   - Background task regression (silent failure)?

4. **Check Backward Compatibility:**

   **API Changes:**
   - Old iOS app versions still work?
   - Can deploy backend without iOS deploy?
   - Versioning strategy needed?

   **Database:**
   - Migration safe (no data loss)?
   - Can rollback if needed?

RETURN FORMAT (JSON):
Save to: ${review_dir}/panel-4-regression-risk.json

{
  \"panel\": \"regression_risk\",
  \"risk_score\": 0-100,
  \"verdict\": \"safe|low_risk|moderate_risk|high_risk\",
  \"findings\": [
    {
      \"priority\": \"P0|P1|P2|P3\",
      \"category\": \"breaking_change|backward_incompatible|data_migration_risk|dependency_break\",
      \"title\": \"Brief title\",
      \"description\": \"What could break?\",
      \"affected_files\": [\"file.py:45\"],
      \"affected_features\": [\"Real-time departures\", \"Favorites sync\"],
      \"blast_radius\": \"iOS only|Backend only|iOS + Backend|Full app\",
      \"breaking_change\": true|false,
      \"evidence\": \"Specific code change causing risk\",
      \"recommendation\": \"How to mitigate (add migration, version API, etc.)\"
    }
  ],
  \"dependency_map\": [
    {\"file\": \"file.py\", \"imported_by\": [\"file1.py\", \"file2.py\"]}
  ],
  \"backward_compatibility\": \"Maintained|Broken|Requires migration\"
}

PRIORITY GUIDELINES:
- P0: High-risk regressions (backward incompatible, breaks core features)
- P1: Moderate-risk (requires migration, breaks edge features)
- P2: Low-risk (internal refactor, well-isolated changes)
- P3: No regression risk

DO NOT:
- Check code quality (Panel 2's job)
- Check edge cases (Panel 3's job)
- Check product alignment (Panel 1's job)
- Focus ONLY on regression risks and dependencies
"
```

### Panel 5: Documentation Sync Reviewer

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Documentation sync review for ${scope_ref}"
- prompt: "
TASK: Documentation Sync Review

REVIEW SCOPE:
$(cat ${review_dir}/review-context.json)

CHANGED FILES:
$(echo "${changed_files}")

YOUR MISSION:
Ensure documentation reflects current implementation reality.

ACTIONS:

1. **Read Implementation:**
   - Review all changed files
   - Identify new features, APIs, patterns
   - Note any removed/deprecated functionality

2. **Read Documentation:**

   **Architecture Specs:**
   - oracle/specs/SYSTEM_OVERVIEW.md (product overview, features)
   - oracle/specs/BACKEND_SPECIFICATION.md (API endpoints, Celery tasks)
   - oracle/specs/IOS_APP_SPECIFICATION.md (iOS architecture, patterns)
   - oracle/specs/DATA_ARCHITECTURE.md (GTFS pipeline, DB schema)
   - oracle/specs/INTEGRATION_CONTRACTS.md (API contracts, auth flow)

   **Project Docs:**
   - CLAUDE.md (project status, tech stack, current phase)
   - oracle/IMPLEMENTATION_ROADMAP.md (phase completion status)
   - oracle/DEVELOPMENT_STANDARDS.md (coding patterns)

   **Plans:**
   - ${plan_file} (implementation plan for this work)
   - Checkpoint designs (deviations logged?)

3. **Identify Sync Issues:**

   **New Features Not Documented:**
   - New API endpoints not in BACKEND_SPECIFICATION.md?
   - New iOS screens not in IOS_APP_SPECIFICATION.md?
   - New Celery tasks not documented?
   - New database tables/columns not in DATA_ARCHITECTURE.md?

   **Outdated Documentation:**
   - Specs describe old implementation?
   - CLAUDE.md still says "Phase 0 pending" but we're in Phase 2?
   - Tech stack changed (added library, service)?
   - Constraints changed (budget increased, new limits)?

   **Deviations from Plan:**
   - Implementation differs from checkpoint design?
   - Deviations logged in completion report?
   - Architecture decisions changed mid-implementation?

   **Missing Documentation:**
   - Complex logic without comments?
   - API contracts unclear?
   - Setup instructions outdated?

4. **Generate Update Checklist:**
   - Which docs need updates?
   - What sections to modify?
   - What new content to add?

RETURN FORMAT (JSON):
Save to: ${review_dir}/panel-5-documentation-sync.json

{
  \"panel\": \"documentation_sync\",
  \"sync_score\": 0-100,
  \"verdict\": \"in_sync|minor_gaps|moderate_gaps|significant_gaps\",
  \"findings\": [
    {
      \"priority\": \"P0|P1|P2|P3\",
      \"category\": \"missing_documentation|outdated_documentation|deviation_not_logged|unclear_contract\",
      \"title\": \"Brief title\",
      \"description\": \"What's out of sync?\",
      \"affected_files\": [\"oracle/specs/BACKEND_SPECIFICATION.md:Section 3\"],
      \"current_state\": \"What does doc say now?\",
      \"actual_implementation\": \"What does code actually do?\",
      \"recommendation\": \"Update oracle/specs/BACKEND_SPECIFICATION.md:Section 3 to add...\"
    }
  ],
  \"update_checklist\": [
    {
      \"file\": \"oracle/specs/BACKEND_SPECIFICATION.md\",
      \"section\": \"Section 3: API Endpoints\",
      \"action\": \"Add new /api/v1/stops/{id}/departures endpoint documentation\"
    }
  ],
  \"deviations_logged\": true|false
}

PRIORITY GUIDELINES:
- P0: Critical specs outdated (API contracts wrong, architecture misleading)
- P1: New features undocumented, CLAUDE.md out of sync
- P2: Minor gaps, missing inline comments
- P3: Nice-to-have improvements

DO NOT:
- Check code quality (Panel 2's job)
- Check edge cases (Panel 3's job)
- Focus ONLY on documentation accuracy
"
```

**Wait for all 5 panels to complete.**

---

## Stage 3: Orchestrator Triage & Prioritization

**Orchestrator loads all panel results:**

```bash
# Load panel reports
panel_1=$(cat ${review_dir}/panel-1-product-alignment.json)
panel_2=$(cat ${review_dir}/panel-2-technical-implementation.json)
panel_3=$(cat ${review_dir}/panel-3-edge-cases-robustness.json)
panel_4=$(cat ${review_dir}/panel-4-regression-risk.json)
panel_5=$(cat ${review_dir}/panel-5-documentation-sync.json)
```

### 3.1 Aggregate Findings

**Orchestrator merges findings from all panels:**

```
1. Collect all findings from 5 panels
2. De-duplicate:
   - Same issue found by multiple panels? Merge entries
   - Keep highest priority assignment
3. Validate priorities:
   - Review each P0/P1 finding
   - Ensure justification matches severity
   - Consider solo dev constraints
```

### 3.2 Reason Through Trade-offs

**CRITICAL: Activate reasoning mode.**

**For each finding, consider:**

1. **User Impact:**
   - Does this affect end users directly?
   - Is this a showstopper or inconvenience?
   - How many users affected?

2. **Solo Dev Constraints:**
   - Time to fix? (1 hour vs 1 day vs 1 week)
   - Can we defer to next phase?
   - Is this technical debt we can live with?

3. **Budget/Cost:**
   - Does this affect API call costs?
   - Storage costs?
   - Compute costs?

4. **Risk vs Reward:**
   - High-risk regression but low-probability scenario?
   - Low-effort fix with high robustness gain?
   - Over-engineering for edge case that never happens?

**Re-prioritize based on reasoning:**
```
Example:
- P0 finding: "Missing rate limit handling"
  - User impact: HIGH (app breaks after 60K calls/day)
  - Solo dev: MEDIUM (4 hours to implement circuit breaker)
  - Budget: HIGH (overage costs $$$)
  → KEEP P0 (block merge)

- P1 finding: "Missing error handling for DST edge case"
  - User impact: LOW (affects 1 hour/year, non-critical feature)
  - Solo dev: HIGH (complex logic, 2 days testing)
  - Budget: NONE
  → DOWNGRADE to P2 (defer to next phase)
```

### 3.3 Generate Action Plan

**Immediate (P0 - Block Merge):**
```
1. Fix {issue} in {file}
   - Why: {reasoning}
   - How: {specific approach}
   - Time: {estimate}
   - Blocker: Yes (breaks {feature}, causes {risk})

2. Update {documentation}
   - Why: API contract mismatch causes iOS integration failures
   - How: Add endpoint spec to INTEGRATION_CONTRACTS.md:Section 4
   - Time: 30 min
   - Blocker: Yes (misleading docs)
```

**Near-term (P1 - Fix Before Release):**
```
1. Add {validation} to {file}
   - Why: {reasoning}
   - How: {approach}
   - Time: {estimate}
   - Priority: High (user-facing error)

2. Update {spec doc}
   - Why: New feature not documented
   - How: Add to BACKEND_SPECIFICATION.md
   - Time: 1 hour
   - Priority: High (missing docs)
```

**Backlog (P2/P3 - Defer):**
```
1. {Refactor/optimization}
   - Why: {reasoning}
   - Defer to: Phase {N+1} or technical debt backlog
   - Log to: .workflow-logs/technical-debt.md
```

---

## Stage 4: Generate Review Report

### 4.1 Calculate Overall Health

```
Overall Health Score = weighted average:
- Product Alignment: 40% weight (most important)
- Technical Implementation: 25%
- Edge Cases & Robustness: 20%
- Regression Risk: 10%
- Documentation Sync: 5%

Health Verdict:
- Green (>85%): No P0 issues, <3 P1 issues → Ready for merge
- Yellow (70-85%): <2 P0 issues, <8 P1 issues → Fix P0, merge, address P1 soon
- Red (<70%): ≥2 P0 issues or ≥8 P1 issues → Block merge, fix critical issues
```

### 4.2 Write Human-Readable Report

`.workflow-logs/reviews/{review_id}/REPORT.md`:

```markdown
# Review Report: {scope_ref}

**Review ID:** {review_id}
**Date:** {timestamp}
**Scope:** {scope_type} - {scope_ref}
**Overall Health:** {🟢 Green | 🟡 Yellow | 🔴 Red}

---

## Summary

**Changed Files:** {count}
- Backend: {backend_files_count}
- iOS: {ios_files_count}
- Specs: {specs_files_count}

**Findings:**
- P0 (Critical): {count}
- P1 (High): {count}
- P2 (Medium): {count}
- P3 (Low): {count}

**Panel Scores:**
- Product Alignment: {score}% ({verdict})
- Technical Implementation: {score}% ({verdict})
- Edge Cases & Robustness: {score}% ({verdict})
- Regression Risk: {risk_score} ({verdict})
- Documentation Sync: {score}% ({verdict})

**Merge Decision:** {✅ Ready to merge | ⚠️ Fix P0 first | 🚫 Block merge}

---

## Critical Issues (P0) - BLOCK MERGE

{If any P0 issues}

### 1. {Title}
**Category:** {category}
**Panel:** {panel}
**Files:** {affected_files}

**Issue:**
{description}

**Evidence:**
{evidence or code snippet}

**Impact:**
{why this blocks merge}

**Recommendation:**
{specific fix with file:line references}

**Estimated Time:** {time estimate}

---

{Repeat for all P0 issues}

{If no P0 issues}
✅ No critical issues found

---

## High Priority Issues (P1) - Fix Before Release

{If any P1 issues}

### 1. {Title}
**Category:** {category}
**Panel:** {panel}
**Files:** {affected_files}

**Issue:**
{description}

**Recommendation:**
{specific fix}

**Estimated Time:** {time estimate}

---

{Repeat for all P1 issues}

{If no P1 issues}
✅ No high priority issues found

---

## Medium Priority Issues (P2) - Fix Soon

{If any P2 issues}

### 1. {Title}
**Category:** {category}
**Panel:** {panel}

**Issue:** {brief description}
**Recommendation:** {fix}

---

{Repeat for all P2 issues}

{If no P2 issues}
✅ No medium priority issues found

---

## Low Priority Issues (P3) - Technical Debt

{If any P3 issues}

### 1. {Title}
**Category:** {category}

**Issue:** {brief description}
**Defer to:** {Phase N or technical debt backlog}

---

{Repeat for all P3 issues}

{If no P3 issues}
✅ No technical debt identified

---

## Documentation Updates Needed

{From Panel 5}

### Immediate Updates (P0/P1):
- [ ] Update `oracle/specs/BACKEND_SPECIFICATION.md:Section 3` - Add new /api/v1/departures endpoint
- [ ] Update `CLAUDE.md` - Change status to "Phase 2 complete"
- [ ] Update `oracle/specs/INTEGRATION_CONTRACTS.md:Section 2` - Document new API response format

### Future Updates (P2/P3):
- [ ] Add inline comments to complex GTFS parsing logic in `backend/app/services/gtfs_service.py`
- [ ] Update `oracle/IMPLEMENTATION_ROADMAP.md` - Mark Phase 2 complete

---

## Action Plan

### Immediate (Before Merge):
{If Yellow or Red health}

**Must Fix (P0 issues):**
1. {Issue title} - {file:line}
   - Action: {specific fix}
   - Time: {estimate}
   - Priority: CRITICAL

2. {Documentation update}
   - Action: {specific update}
   - Time: {estimate}
   - Priority: CRITICAL

**Total Time:** {sum of P0 estimates}

**After fixes:**
1. Re-run: `/review` to verify fixes
2. Run: `/test all` to ensure no regressions
3. Merge to main

---

{If Green health}

✅ **Ready to Merge**

**Recommended next steps:**
1. Run: `/test all` (final validation)
2. Merge to main
3. Address P1 issues in next checkpoint/phase

---

### Near-Term (P1 - Next Checkpoint):
1. {Issue title}
   - Action: {fix}
   - Time: {estimate}

2. {Documentation update}
   - Action: {update}
   - Time: {estimate}

**Total Time:** {sum of P1 estimates}

---

### Backlog (P2/P3 - Defer):

**Medium Priority:**
1. {Issue title} - Defer to Phase {N+1}
2. {Issue title} - Log to technical debt

**Low Priority:**
1. {Issue title} - Technical debt backlog

**Backlog logged to:** `.workflow-logs/technical-debt.md`

---

## Panel Details

### Panel 1: Product Alignment
**Score:** {score}%
**Verdict:** {verdict}

**Strengths:**
{strengths from panel}

**Alignment Analysis:**
{product_completeness, user_impact}

**Findings:** {count} issues ({breakdown by priority})

---

### Panel 2: Technical Implementation
**Score:** {score}%
**Verdict:** {verdict}

**Strengths:**
{strengths from panel}

**Compliance Analysis:**
{architecture_alignment}

**Findings:** {count} issues ({breakdown by priority})

---

### Panel 3: Edge Cases & Robustness
**Score:** {score}%
**Verdict:** {verdict}

**Strengths:**
{strengths from panel}

**Failure Modes Identified:**
{failure_modes list}

**Findings:** {count} issues ({breakdown by priority})

---

### Panel 4: Regression Risk
**Risk Score:** {risk_score}
**Verdict:** {verdict}

**Backward Compatibility:** {maintained|broken|requires migration}

**Blast Radius:** {iOS only|Backend only|iOS + Backend|Full app}

**Findings:** {count} issues ({breakdown by priority})

---

### Panel 5: Documentation Sync
**Score:** {score}%
**Verdict:** {verdict}

**Deviations Logged:** {true|false}

**Specs Requiring Updates:** {count}

**Findings:** {count} issues ({breakdown by priority})

---

## Review Context

**Scope Type:** {scope_type}
**Scope Reference:** {scope_ref}
**Git Diff Base:** {latest_tag}
**Changed Files:** {count}

**Plan/Phase Artifacts:**
- Exploration Report: {exploration_report}
- Implementation Plan: {plan_file}
- Completion Report: {completion_report}

**Panel Reports:**
- Panel 1: `.workflow-logs/reviews/{review_id}/panel-1-product-alignment.json`
- Panel 2: `.workflow-logs/reviews/{review_id}/panel-2-technical-implementation.json`
- Panel 3: `.workflow-logs/reviews/{review_id}/panel-3-edge-cases-robustness.json`
- Panel 4: `.workflow-logs/reviews/{review_id}/panel-4-regression-risk.json`
- Panel 5: `.workflow-logs/reviews/{review_id}/panel-5-documentation-sync.json`

---

**Review Generated:** {timestamp}
**Review ID:** {review_id}
```

### 4.3 Write Machine-Readable Summary

`.workflow-logs/reviews/{review_id}/review-summary.json`:

```json
{
  "review_id": "{review_id}",
  "timestamp": "{ISO 8601}",
  "scope_type": "{scope_type}",
  "scope_ref": "{scope_ref}",
  "overall_health": {
    "score": 85,
    "verdict": "green|yellow|red",
    "merge_decision": "ready|fix_p0_first|block"
  },
  "panel_scores": {
    "product_alignment": {"score": 90, "verdict": "aligned"},
    "technical_implementation": {"score": 85, "verdict": "compliant"},
    "edge_cases_robustness": {"score": 80, "verdict": "minor_gaps"},
    "regression_risk": {"score": 20, "verdict": "low_risk"},
    "documentation_sync": {"score": 75, "verdict": "minor_gaps"}
  },
  "findings_summary": {
    "p0": 0,
    "p1": 3,
    "p2": 5,
    "p3": 2,
    "total": 10
  },
  "action_plan": {
    "immediate": [
      {
        "priority": "P0",
        "title": "...",
        "file": "file.py:45",
        "time_estimate": "4 hours"
      }
    ],
    "near_term": [...],
    "backlog": [...]
  },
  "documentation_updates": [
    {
      "file": "oracle/specs/BACKEND_SPECIFICATION.md",
      "section": "Section 3",
      "action": "Add endpoint documentation",
      "priority": "P1"
    }
  ],
  "changed_files": {
    "count": 12,
    "backend": 7,
    "ios": 4,
    "specs": 1
  }
}
```

---

## Stage 5: Report to User

**Provide concise summary:**

```
Review Complete: {scope_ref}

Overall Health: {🟢 Green | 🟡 Yellow | 🔴 Red}
- Product Alignment: {score}%
- Technical Implementation: {score}%
- Edge Cases & Robustness: {score}%
- Regression Risk: {risk_score}
- Documentation Sync: {score}%

Findings:
- P0 (Critical): {count} {if >0: "❌ BLOCKS MERGE"}
- P1 (High): {count}
- P2 (Medium): {count}
- P3 (Low): {count}

{If Green health}
✅ Ready to Merge
No critical issues found.

Recommended next steps:
1. Run: /test all (final validation)
2. Merge to main
3. Address {p1_count} P1 issues in next checkpoint

{If Yellow health}
⚠️ Fix P0 Issues First

Critical issues blocking merge:
1. {P0 issue 1 title} - {file}
2. {P0 issue 2 title} - {file}

Action Required:
1. Fix {p0_count} P0 issues (est. {total_time})
2. Update {doc_count} docs
3. Re-run: /review (verify fixes)
4. Run: /test all
5. Merge to main

{If Red health}
🚫 Block Merge

Multiple critical issues found:
- {p0_count} P0 issues (CRITICAL)
- {p1_count} P1 issues (HIGH)

This implementation needs significant work before merge.

Action Required:
1. Review detailed report: .workflow-logs/reviews/{review_id}/REPORT.md
2. Address all P0 issues
3. Consider addressing P1 issues (or defer with justification)
4. Re-run: /review
5. Do NOT merge until Green or Yellow

---

Full Report: .workflow-logs/reviews/{review_id}/REPORT.md
Review Summary: .workflow-logs/reviews/{review_id}/review-summary.json

Panel Reports:
- Product Alignment: .workflow-logs/reviews/{review_id}/panel-1-product-alignment.json
- Technical Implementation: .workflow-logs/reviews/{review_id}/panel-2-technical-implementation.json
- Edge Cases & Robustness: .workflow-logs/reviews/{review_id}/panel-3-edge-cases-robustness.json
- Regression Risk: .workflow-logs/reviews/{review_id}/panel-4-regression-risk.json
- Documentation Sync: .workflow-logs/reviews/{review_id}/panel-5-documentation-sync.json
```

---

## Notes

**Multi-Panel Benefits:**
- Comprehensive coverage (5 specialized perspectives)
- Parallel execution (faster reviews)
- Clear separation of concerns
- Reduces orchestrator bias (panels vote independently)

**Token Management:**
- Orchestrator: ~3K tokens (context loading)
- Each panel: ~15K tokens (deep analysis)
- Total: ~78K tokens across 5 parallel agents
- Trade-off: Higher cost, higher quality

**Priority Reasoning:**
- Orchestrator applies solo dev constraints
- Not all findings are created equal
- User impact > technical perfection
- Budget/time constraints matter
- Defer low-impact issues to technical debt

**Integration with Workflow:**
```
/plan → /implement → /review → [fix P0] → /test → merge
                        ↓
                    [P1/P2 logged to backlog]
```

**When to Run:**
- After `/implement-phase` completes
- After `/implement` completes
- After `/bug` fixes
- Before merging to main
- Manual: `/review` anytime

**Success Criteria:**
- All 5 panels complete successfully
- Findings aggregated and de-duplicated
- Priorities justified with reasoning
- Action plan is specific and time-estimated
- Documentation updates identified
- Merge decision clear (Green/Yellow/Red)
