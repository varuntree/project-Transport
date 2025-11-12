# Implement Phase

Execute the implementation plan for the specified phase. Follow the plan step-by-step, adhere to development standards, and verify completion through testing.

## Variables

phase_number: $1

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for implementation decisions.**

### Step 1: Load Implementation Plan

- MUST READ: `specs/phase-{phase_number}-implementation-plan.md`
- MUST READ: `oracle/DEVELOPMENT_STANDARDS.md` (keep as reference throughout)
- Read relevant architecture specs mentioned in plan

### Step 2: Verify Prerequisites

Before starting implementation:

1. **Check User Setup Completed:**
   - Review "Prerequisites → User Setup Required" section in plan
   - Verify external services configured (accounts, API keys, etc.)
   - If user setup incomplete, STOP and report blocker

2. **Check Previous Phase Complete:**
   - If phase_number > 0, verify previous phase deliverables exist
   - Run environment checks from plan (backend running, Supabase connected, etc.)
   - If prerequisites missing, STOP and report blocker

3. **Check Clean Git State:**
   - Run: `git status`
   - If uncommitted changes exist, commit or stash first
   - Create branch: `git checkout -b phase-{phase_number}-implementation`

### Step 3: Execute Implementation Steps

**CRITICAL: Execute EVERY step in the plan in exact order (top to bottom).**

For each step in plan:

1. **Read Step Carefully:**
   - Understand purpose, files to create/modify, tasks
   - Review referenced architecture specs and standards
   - If anything unclear, re-read or ask user

2. **Implement Step:**
   - Follow DEVELOPMENT_STANDARDS.md patterns exactly
   - Create files with correct structure (see Standards Section 1)
   - Use proper naming conventions (see Standards Section 9)
   - Add structured logging (see Standards Section 4)
   - Implement error handling (see Standards Section 10)

3. **Validate Step:**
   - Run validation command from step (if provided)
   - Verify files created/modified correctly
   - Check for syntax errors (Python: `python -m py_compile file.py`, Swift: Cmd+B in Xcode)
   - **Self-Validation Loop:** If validation fails:
     - Analyze error output
     - Fix issue immediately
     - Re-run validation (max 2 auto-fix attempts)
     - If still failing after 2 attempts, report blocker to user

4. **Commit Progress (Atomic Commits):**
   - Commit after EACH logical step completion (not batch commits)
   - Each commit = trail of working state
   - Commit message format: `feat(phase-{phase_number}): <description>` (see Standards Section 9)
   - Example: `feat(phase-1): add GTFS parser service`
   - Keep commits small, focused, compilable

5. **Log Progress:**
   - Use structured logging to track progress
   - Example: `logger.info("step_complete", step="create_supabase_schema", files_created=5)`

### Step 4: Implementation Guidelines

**Code Quality:**
- NO hardcoded values (use config, env variables)
- NO duplicate code (extract to functions/classes)
- NO skipping error handling (always try-except/Result types)
- NO ignoring Standards (reference specific sections)

**When Implementing Backend:**
- Singleton pattern for DB clients (Standards Section 2)
- FastAPI Depends() for dependency injection (Standards Section 3)
- Structured logging with JSON output (Standards Section 4)
- Celery task naming: `verb_noun` (Standards Section 5)
- Request/response envelopes (Standards Section 3)

**When Implementing iOS:**
- MVVM + Repository + Coordinator pattern (Standards Section 6)
- Protocol-based repositories (for testability)
- @MainActor for ViewModels
- Keychain for sensitive data (not UserDefaults)
- swift-log for logging (Standards Section 4)

**When Integrating:**
- API contracts match INTEGRATION_CONTRACTS.md
- Backend URL in iOS Config.plist
- Auth token in Authorization header
- Error handling on both sides (Standards Section 10)

**If Blocked:**
- If a step cannot be completed (missing dependency, error, unclear requirement):
  1. Document the blocker clearly
  2. STOP implementation
  3. Report blocker to user with:
     - Which step blocked
     - What is needed to unblock
     - Attempted solutions (if any)
- DO NOT skip steps or implement workarounds without user approval

### Step 5: Testing & Validation

After all implementation steps complete:

1. **Run Acceptance Criteria Tests:**
   - Execute every test in "Testing Strategy" section
   - Follow "Manual Testing Checklist" step-by-step
   - Document pass/fail for each criterion

2. **Backend Validation (if applicable):**
   ```bash
   # Syntax check
   cd backend && python -m py_compile app/**/*.py

   # Start server
   uvicorn app.main:app --reload

   # Health check
   curl http://localhost:8000/health

   # Test specific endpoints (from plan)
   <run cURL commands from plan>
   ```

3. **iOS Validation (if applicable):**
   ```bash
   # Build check
   # Open Xcode, Cmd+B

   # Run in simulator
   # Cmd+R

   # Manual test steps (from plan)
   # Follow checklist in simulator
   ```

4. **Integration Validation:**
   - Backend running + iOS app running
   - Test user flows end-to-end
   - Verify data syncs between backend and iOS

5. **Edge Cases:**
   - Test edge cases from plan
   - Document results

**If Tests Fail:**
- Document which test failed
- Document error message
- Fix issue
- Re-run full test suite
- DO NOT proceed to next phase with failing tests

### Step 6: Final Checks

1. **Code Review (Self):**
   - Review all files changed: `git diff main..phase-{phase_number}-implementation`
   - Check for:
     - Hardcoded values (should use config)
     - Missing error handling
     - Inconsistent naming
     - Missing logging
     - Deviations from Standards

2. **Documentation:**
   - Update README.md if setup steps changed
   - Update .env.example if new variables added
   - Commit documentation changes

3. **Clean Up:**
   - Remove debug code, console.logs, print statements
   - Remove commented-out code
   - Remove unused imports
   - Run linter if available (backend: `ruff check .`, iOS: SwiftLint if configured)

4. **Final Commit:**
   ```bash
   git add .
   git commit -m "feat(phase-{phase_number}): complete phase implementation"
   git tag phase-{phase_number}-complete
   ```

### Step 7: Prepare for Merge

**DO NOT merge to main yet - report completion first.**

User will review and approve before merge.

---

## Report

After implementation complete, provide detailed report.

**Optional JSON Output:** For agent chaining, can output structured JSON:
```json
{
  "phase": {phase_number},
  "status": "complete|blocked|partial",
  "files_changed": <count>,
  "tests_passed": true|false,
  "blockers": [],
  "next_action": "merge|fix|review"
}
```

**Standard Report Format:**

### 1. Implementation Summary
<concise bullet list of what was implemented>
- Backend: <key features/endpoints>
- iOS: <key views/functionality>
- Integration: <how they connect>

### 2. Files Changed
```bash
git diff --stat main..phase-{phase_number}-implementation
```
<paste output showing files changed and line counts>

### 3. Testing Results

**Acceptance Criteria:**
- [ ] Criterion 1: <Pass/Fail> - <brief note>
- [ ] Criterion 2: <Pass/Fail> - <brief note>
- [ ] ...

**Tests Run:**
- Backend tests: <Pass/Fail> - <command run>
- iOS build: <Pass/Fail> - <Xcode result>
- Manual tests: <Pass/Fail> - <checklist results>

**Edge Cases:**
- Edge case 1: <Pass/Fail>
- Edge case 2: <Pass/Fail>

### 4. Blockers Encountered
<list any blockers hit during implementation>
<how they were resolved or if they need user action>

**If None:** No blockers encountered

### 5. Deviations from Plan
<list any intentional deviations from implementation plan>
<explain why deviation was necessary>

**If None:** Implementation followed plan exactly

### 6. Known Issues
<list any known issues or technical debt introduced>
<plan for addressing in future phases>

**If None:** No known issues

### 7. Screenshots (If Applicable for iOS)
<if iOS UI was implemented, describe what screens work>
<note: actual screenshots taken manually by user during testing>

### 8. Next Steps

**Ready for Merge:**
- Yes/No
- If Yes: `git checkout main && git merge phase-{phase_number}-implementation`
- If No: <what needs to be fixed before merge>

**Ready for Next Phase:**
- Yes/No
- If Yes: Next phase is Phase {phase_number + 1}
- If No: <what needs completion or user action>

### 9. Recommendations
<any recommendations for next phase or improvements>

---

## Example Report

```
Implementation Summary:
- Backend: FastAPI hello-world, health check endpoint, Supabase connection
- iOS: Empty SwiftUI app, Config.plist setup, Logger configured
- Integration: iOS can fetch from backend /health endpoint

Files Changed:
 backend/app/main.py           | 45 ++++++++++++++++++++
 backend/app/config.py         | 23 ++++++++++
 backend/app/db/supabase_client.py | 18 ++++++++
 SydneyTransit/SydneyTransitApp.swift | 12 +++++++
 SydneyTransit/Core/Utilities/Logger.swift | 8 ++++
 SydneyTransit/Config.plist    | 15 +++++++
 6 files changed, 121 insertions(+)

Testing Results:
Acceptance Criteria:
- [x] Server starts without errors: Pass
- [x] /health returns 200: Pass - {"status":"healthy"}
- [x] iOS app launches: Pass - No crashes
- [x] Supabase connected: Pass - Can query DB
- [x] Redis connected: Pass - PING → PONG

Tests Run:
- Backend health check: Pass - curl http://localhost:8000/health
- iOS build: Pass - Xcode Cmd+B succeeded
- Manual tests: Pass - All checklist items verified

Edge Cases:
- Missing .env file: Pass - Clear error message shown
- Invalid Supabase URL: Pass - Connection error logged correctly

Blockers Encountered: None

Deviations from Plan: None

Known Issues: None

Screenshots: Home screen shows "Sydney Transit" title (blank otherwise, as expected)

Ready for Merge: Yes
Ready for Next Phase: Yes (Phase 1)

Recommendations:
- Phase 1 will be complex (GTFS parsing) - allocate 2-3 weeks
- Consider breaking Phase 1 into sub-phases if needed
```
