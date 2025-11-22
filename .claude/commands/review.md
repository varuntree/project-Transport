# Review Implementation

Post-implementation quality gate using 5-panel review. Orchestrator reviews all aspects directly: Product Alignment, Technical Standards, Edge Cases, Regression Risks, Documentation Sync.

## Usage

```
/review                    # Review recent changes (auto-detect)
/review {plan-name}        # Review specific plan
```

## Variables

scope: $1 (optional: auto-detects recent changes if omitted)

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for triage and prioritization.**

---

## Stage 1: Detect Scope

### 1.1 Create Review Session

```bash
timestamp=$(date +%s)
review_dir=".claude-logs/reviews/${timestamp}"
mkdir -p "${review_dir}"
```

### 1.2 Determine What to Review

If scope provided:
- Check for plan: `.claude-logs/plans/${scope}/plan.md`
- Check for implementation: `.claude-logs/implement/${scope}/`
- Get changed files: `git diff main..${scope}-implementation --name-only`

If no scope:
- Find most recent implementation in `.claude-logs/implement/`
- OR use recent git changes: `git diff --name-only HEAD~5..HEAD`

---

## Stage 2: Read Context

### 2.1 Read Plan (if available)

If reviewing a plan implementation:
- Read `.claude-logs/plans/{scope}/plan.md`
- Read `.claude-logs/implement/{scope}/REPORT.md`

### 2.2 Read Changed Files

```bash
git diff --name-only {base}..HEAD
```

Read all changed files to understand:
- What was implemented
- How it was implemented
- What patterns used

### 2.3 Read Specifications

- docs/architecture/SYSTEM_OVERVIEW.md
- docs/standards/DEVELOPMENT_STANDARDS.md
- Based on changes:
  - Backend? → docs/architecture/BACKEND_SPECIFICATION.md
  - iOS? → docs/architecture/IOS_APP_SPECIFICATION.md
  - Data? → docs/architecture/DATA_ARCHITECTURE.md
  - API? → docs/architecture/INTEGRATION_CONTRACTS.md

---

## Stage 3: Five-Panel Review

**Orchestrator reviews all 5 aspects sequentially:**

### Panel 1: Product Alignment

**Evaluate if implementation serves product vision:**

Questions:
- Solves real user need from SYSTEM_OVERVIEW?
- Complete vertical slice (working end-to-end)?
- Advances product roadmap?
- Missing capabilities?
- Aligns with positioning (TripView reliability + Transit features)?

**Vision drift detection:**
- Building features not in specs?
- Over-engineering for 0 users?
- Ignoring constraints (budget, offline-first, solo dev)?

**Score:** 0-100% alignment

**Findings:** Note any vision drift, incomplete features, missing capabilities

---

### Panel 2: Technical Implementation

**Verify follows standards and patterns:**

Check DEVELOPMENT_STANDARDS.md compliance:

**Backend:**
- Structured logging (JSON, event-based, no PII)
- API envelope: `{"data": {...}, "meta": {...}}`
- Singleton clients via Depends()
- Celery tasks: proper decorators
- Pydantic models for validation
- Error handling with logging

**iOS:**
- @MainActor on ViewModels
- Protocol-based repositories
- async/await for network
- GRDB patterns
- No force unwraps
- SwiftUI state (@Published, @State)

**API Contracts:**
- New endpoints in INTEGRATION_CONTRACTS.md?
- Breaking changes flagged?
- Backward compatibility?

**Score:** 0-100% compliance

**Findings:** Note standards violations, pattern deviations, code smells

---

### Panel 3: Edge Cases & Robustness

**Identify unhandled edge cases:**

**Input validation:**
- Null/empty handling?
- Invalid IDs?
- Large payloads?

**External dependencies:**
- NSW API rate limits?
- Timeout handling?
- Network offline (iOS)?
- Service failures?

**Data edge cases:**
- GTFS-RT missing data?
- Stop IDs not in static data?
- NULL route names?
- Empty results?

**Timing:**
- DST transitions?
- Timezone handling?
- Race conditions?

**Resources:**
- Memory leaks?
- Cache limits?
- App size limits?

**Score:** 0-100% robustness

**Findings:** Note missing validations, unhandled errors, edge cases

---

### Panel 4: Regression Risk

**Identify potential regressions:**

**Map dependencies:**
- Who imports changed files?
- What calls these functions?
- Which APIs consume this?

**Breaking changes:**
- Schema changes?
- Endpoint signature changes?
- Model field changes?
- Task signature changes?

**Assess blast radius:**
- How many features affected?
- iOS + backend both?
- Data migration needed?
- User-facing regression?

**Backward compatibility:**
- Old iOS versions work?
- Can deploy backend without iOS?
- Migration safe?

**Risk score:** 0-100 (0=safe, 100=high risk)

**Findings:** Note breaking changes, compatibility issues, migration risks

---

### Panel 5: Documentation Sync

**Ensure docs reflect reality:**

**Check architecture specs:**
- New endpoints in BACKEND_SPECIFICATION.md?
- New screens in IOS_APP_SPECIFICATION.md?
- New tasks documented?
- New tables in DATA_ARCHITECTURE.md?

**Check outdated docs:**
- Specs describe old implementation?
- CLAUDE.md current?
- Tech stack changed?

**Check deviations:**
- Implementation differs from plan?
- Architecture decisions changed?

**Sync score:** 0-100%

**Findings:** Note missing docs, outdated specs, deviations not logged

---

## Stage 4: Triage & Prioritize

**CRITICAL: Activate reasoning mode.**

### 4.1 Aggregate Findings

Collect all findings from 5 panels.

### 4.2 Assign Priorities

For each finding, reason through:

**User impact:**
- Direct user impact?
- Showstopper or inconvenience?
- How many users?

**Solo dev constraints:**
- Time to fix?
- Defer to later?
- Technical debt acceptable?

**Budget/cost:**
- API call costs?
- Storage/compute costs?

**Risk vs reward:**
- High-risk but low-probability?
- Low-effort, high-robustness gain?
- Over-engineering for rare edge case?

**Assign priority:**
- P0: Critical - blocks merge (security, data corruption, breaks core features)
- P1: High - fix before release (user-facing errors, missing docs)
- P2: Medium - fix soon (code smells, minor gaps)
- P3: Low - technical debt (optimizations, rare edge cases)

### 4.3 Calculate Health

```
Overall Health = weighted average:
- Product Alignment: 40%
- Technical Implementation: 25%
- Edge Cases: 20%
- Regression Risk: 10%
- Documentation: 5%

Verdict:
- Green (>85%): No P0, <3 P1 → Ready for merge
- Yellow (70-85%): <2 P0, <8 P1 → Fix P0, then merge
- Red (<70%): ≥2 P0 or ≥8 P1 → Block merge
```

---

## Stage 5: Generate Report

Write `.claude-logs/reviews/${timestamp}/REPORT.md`:

```markdown
# Review Report

**Review ID:** ${timestamp}
**Date:** {date}
**Scope:** {scope}
**Overall Health:** {🟢 Green | 🟡 Yellow | 🔴 Red}

---

## Summary

**Changed Files:** {count}
- Backend: {count}
- iOS: {count}

**Findings:**
- P0 (Critical): {count}
- P1 (High): {count}
- P2 (Medium): {count}
- P3 (Low): {count}

**Panel Scores:**
- Product Alignment: {score}%
- Technical Implementation: {score}%
- Edge Cases & Robustness: {score}%
- Regression Risk: {risk_score}
- Documentation Sync: {score}%

**Merge Decision:** {✅ Ready | ⚠️ Fix P0 first | 🚫 Block}

---

## Critical Issues (P0) - BLOCK MERGE

{If any P0}

### 1. {Title}
**Category:** {category}
**Files:** {files}

**Issue:**
{description}

**Evidence:**
{code or specific example}

**Impact:**
{why this blocks merge}

**Recommendation:**
{specific fix}

---

{If no P0}
✅ No critical issues

---

## High Priority (P1) - Fix Before Release

{List P1 issues}

---

## Medium Priority (P2) - Fix Soon

{List P2 issues}

---

## Low Priority (P3) - Technical Debt

{List P3 issues}

---

## Documentation Updates Needed

{From Panel 5}

### Immediate (P0/P1):
- [ ] Update {doc}:{section} - {what to add}

### Future (P2/P3):
- [ ] {optional update}

---

## Action Plan

{If Green}
✅ **Ready to Merge**

Next steps:
1. Merge to main
2. Address {p1_count} P1 issues later

{If Yellow}
⚠️ **Fix P0 First**

Must fix:
1. {P0 issue} - {file}
   - Action: {fix}
   - Time: {estimate}

After fixes:
1. Re-run: /review
2. Merge to main

{If Red}
🚫 **Block Merge**

Critical issues:
- {p0_count} P0 issues
- {p1_count} P1 issues

Actions:
1. Address all P0 issues
2. Consider P1 issues
3. Re-run: /review

---

## Panel Details

### Panel 1: Product Alignment ({score}%)
**Verdict:** {aligned|drift}

**Strengths:**
{what's done well}

**Findings:** {count} issues

---

### Panel 2: Technical Implementation ({score}%)
**Verdict:** {compliant|violations}

**Strengths:**
{what's done well}

**Findings:** {count} issues

---

### Panel 3: Edge Cases & Robustness ({score}%)
**Verdict:** {robust|gaps}

**Strengths:**
{what's handled well}

**Findings:** {count} issues

---

### Panel 4: Regression Risk ({risk_score})
**Verdict:** {safe|low_risk|moderate_risk|high_risk}

**Backward Compatibility:** {maintained|broken|requires migration}

**Findings:** {count} issues

---

### Panel 5: Documentation Sync ({score}%)
**Verdict:** {in_sync|gaps}

**Findings:** {count} issues

---

**Report Generated:** {timestamp}
**Review ID:** ${timestamp}
```

---

## Report to User

```
Review Complete

Overall Health: {🟢 Green | 🟡 Yellow | 🔴 Red}

Panel Scores:
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

{If Green}
✅ Ready to Merge

Next:
1. Merge to main
2. Address P1 issues later

{If Yellow}
⚠️ Fix P0 Issues First

Critical:
{List P0 issues}

Next:
1. Fix P0 issues
2. Re-run /review
3. Merge

{If Red}
🚫 Block Merge

{p0_count} P0 + {p1_count} P1 issues

Review report for details.

Report: .claude-logs/reviews/${timestamp}/REPORT.md
```

---

## Notes

- No subagents - orchestrator reviews all 5 panels
- Sequential review (not parallel)
- Reasoning mode for prioritization
- Markdown only (no JSON)
- Single folder: .claude-logs/reviews/{timestamp}/
