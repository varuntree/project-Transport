# Bug Fix

Investigate and fix user-reported bugs through 4-stage analysis: Map → Explore → Diagnose → Fix. Orchestrator performs all stages directly.

## Variables

bug_description: $1 (required: user description of bug)

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for all diagnosis decisions.**

---

## Stage 1: Setup & Map Bug

### 1.1 Create Bug Session

```bash
timestamp=$(date +%s)
bug_slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-40)
bug_dir=".claude-logs/bugs/${timestamp}-${bug_slug}"
mkdir -p "${bug_dir}"
```

### 1.2 Read Documentation

Understand project context:
- docs/architecture/SYSTEM_OVERVIEW.md
- docs/standards/DEVELOPMENT_STANDARDS.md
- Based on bug keywords, read relevant specs:
  - Backend bug? → docs/architecture/BACKEND_SPECIFICATION.md
  - iOS bug? → docs/architecture/IOS_APP_SPECIFICATION.md
  - Data bug? → docs/architecture/DATA_ARCHITECTURE.md

### 1.3 Map Bug to Systems

From bug description, identify:
- Which systems affected? (Backend API, iOS UI, Data layer, etc.)
- Which layers? (UI, ViewModel, Repository, API, Database, etc.)
- Keywords to search for?

---

## Stage 2: Deep Exploration

### 2.1 Find Relevant Code

Based on bug description and systems identified:
1. Find files related to buggy functionality
2. Read implementations
3. Trace data flow:
   - iOS: View → ViewModel → Repository → APIClient → Backend
   - Backend: Route → Service → Database/Cache → External API
4. Identify dependencies and callers

### 2.2 Understand Current Behavior

- What does the code actually do?
- Where could the bug manifest?
- What patterns are used?
- Error handling present?

**No tool prescription - explore naturally.**

---

## Stage 3: Root Cause Diagnosis

**CRITICAL: Activate reasoning mode. Think deeply.**

### 3.1 Analyze Bug Behavior

**Reproduce mentally:**
- Trace execution based on bug description
- Follow data flow
- Where does behavior diverge from expected?

**Categorize bug:**
- logic_error: Wrong algorithm/condition
- pattern_violation: Violates DEVELOPMENT_STANDARDS
- race_condition: Timing/concurrency issue
- state_management: State not reset/updated correctly
- error_handling_gap: Missing error handling
- external_issue: Third-party service problem

### 3.2 Identify Root Cause

**Use first principles:**
- What is FUNDAMENTAL cause (not symptom)?
- Why does this cause observed behavior?
- What assumptions were violated?
- Single point of failure?

**Provide evidence:**
- Specific file:line numbers
- Actual vs expected behavior
- Pattern violations
- Missing logic

### 3.3 Design Fix

**Minimal fix approach:**
- Smallest change to fix root cause?
- Which files must be modified?
- Risks introduced?
- How to validate fix?

**Confidence check:**
- 80%+ confident on diagnosis?
- iOS work? Research Apple docs if needed
- External service? Check documentation
- If <80% confidence: Stop and report blocker

---

## Stage 4: Implement Fix

### 4.1 Apply Fix

**Following diagnosis:**
- Read files to modify
- Make minimal, correct changes
- Follow DEVELOPMENT_STANDARDS.md patterns
- Include error handling if missing
- Add logging if needed

### 4.2 Validate Fix

**Compile check:**
- Backend: `python -m py_compile {files}`
- iOS: Build in Xcode (if available)

**Manual trace:**
- Trace execution with fix applied
- Verify addresses root cause
- Check no new bugs introduced

### 4.3 Commit Fix

```bash
git add .

git commit -m "fix: ${bug_slug}

Root cause: {description}

Fix: {approach}

Affected: {systems/layers}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git tag bug-fix-${timestamp}
```

---

## Stage 5: Create Bug Report

Write `.claude-logs/bugs/${timestamp}-${bug_slug}/REPORT.md`:

```markdown
# Bug Fix Report

**Bug:** {bug_description}
**Status:** Fixed
**Date:** {date}

---

## Bug Summary

{1-2 sentence technical summary}

---

## Root Cause

**Category:** {category}

**Description:**
{Root cause explanation}

**Evidence:**
- {file:line - what's wrong}
- {Actual vs expected behavior}

---

## Fix Applied

**Approach:**
{How we fixed it}

**Files Modified:**
- {file1}
- {file2}

**Changes:**
{Brief diff summary}

---

## Validation

**Compile Check:** Passed

**Manual Trace:**
{How fix addresses root cause}

**Test Plan:**
1. {Reproduction step 1}
2. {Reproduction step 2}
3. {Verify fix works}

---

## Affected Systems

- {System 1} ({layer})
- {System 2} ({layer})

---

## Commit

**Hash:** {git rev-parse HEAD}
**Tag:** bug-fix-${timestamp}

---

**Report Generated:** {timestamp}
```

---

## Report to User

```
Bug Fixed: {bug_slug}

Root Cause:
- Category: {category}
- {brief description}

Fix Applied:
- {approach}
- Files: {count} modified

Affected: {systems}

Validation: Passed

Test Plan:
{steps to verify}

Report: .claude-logs/bugs/${timestamp}-${bug_slug}/REPORT.md
Commit: {hash}

Next: Test manually, then merge
```

---

## Notes

- No subagents - orchestrator does all 4 stages
- No grep prescription - natural exploration
- Thinking mode for diagnosis (critical)
- Markdown only (no JSON)
- Minimal fix approach
- Single folder: .claude-logs/bugs/{timestamp}-{slug}/
