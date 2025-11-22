# Fix Bug

Delegate bug investigation and fixing to fresh Sonnet subagent to avoid polluting orchestrator/implementation context.

## Variables

phase_number: $1
checkpoint_number: $2
bug_type: $3 (optional: validation_failed|compile_error|runtime_error, default: validation_failed)

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for diagnosis.**

---

## Stage 1: Load Bug Context

**Orchestrator loads:**

1. **Checkpoint design:**
   ```bash
   cat .workflow-logs/active/phases/phase-{phase_number}/checkpoint-{checkpoint_number}-design.md
   ```

2. **Checkpoint result (if exists):**
   ```bash
   cat .workflow-logs/active/phases/phase-{phase_number}/checkpoint-{checkpoint_number}-result.json
   ```

3. **Validation failure context:**
   ```bash
   cat .workflow-logs/active/phases/phase-{phase_number}/checkpoint-{checkpoint_number}-validation-failure.json
   ```
   (Created by orchestrator when validation fails)

4. **Exploration report (lightweight):**
   ```bash
   cat .workflow-logs/active/phases/phase-{phase_number}/exploration-report.json
   # Load only: critical_patterns array
   ```

5. **Current codebase state:**
   ```bash
   # Files created/modified in checkpoint
   git diff HEAD~1 -- $(cat .workflow-logs/active/phases/phase-{phase_number}/checkpoint-{checkpoint_number}-result.json | jq -r '.files_created[],.files_modified[]')
   ```

**Total context: ~2K tokens**

---

## Stage 2: Package Bugfix Task

**Orchestrator prepares task package:**

```markdown
TASK: Fix Bug in Checkpoint {checkpoint_number}

PHASE CONTEXT:
- Phase: {phase_number} - <Name from exploration>
- Checkpoint: {checkpoint_number} - <Name from design>
- Overall goal: <From exploration phase_summary>

CHECKPOINT DESIGN (Original Specification):
<Paste full checkpoint-{N}-design.md>

IMPLEMENTATION RESULT:
<Paste checkpoint-{N}-result.json>

BUG CONTEXT:
- Bug Type: {bug_type}
- Validation Command: <From checkpoint design validation section>
- Validation Output:
  ```
  <Actual output from validation-failure.json>
  ```
- Expected Output: <From checkpoint design>
- Files Affected: <From result.json or git diff analysis>

CRITICAL PATTERNS (from Exploration):
<Extract relevant patterns from exploration-report.json critical_patterns array>
Example:
- Singleton DB clients: get_supabase() via Depends(), never instantiate directly
- Structured logging: JSON format, no PII, event-based (logger.info('event', key=value))
- API envelope: All responses wrapped in {"data": {...}, "meta": {...}}

CONSTRAINTS:
- MUST NOT change checkpoint design/goals
- MUST follow DEVELOPMENT_STANDARDS.md patterns
- MUST preserve existing functionality
- Max 2 fix attempts
- Run validation after each fix

BUGFIX WORKFLOW:

1. **Diagnose Root Cause:**
   - Read actual implementation files
   - Compare vs checkpoint design
   - Check pattern compliance (critical_patterns from exploration)
   - Analyze validation output/stack trace
   - Categorize bug: syntax_error|logic_error|pattern_violation|design_flaw|external_issue

2. **Apply Minimal Fix:**
   - Edit only affected files
   - Follow exact same patterns as design
   - Add missing error handling (if needed)
   - Fix imports/syntax/logic
   - Preserve all other functionality

3. **Self-Validate:**
   - Run validation command from design
   - Compare output to expected
   - If failed: Retry fix (max 2 attempts)
   - If still failed: Return blocked status

4. **Return Structured Result** (see format below)

CONFIDENCE CHECK:
- iOS bug? → Check .workflow-logs/active/phases/phase-{phase_number}/ios-research-*.md
- External service? → Research docs (WebFetch)
- Pattern unclear? → Read DEVELOPMENT_STANDARDS.md section
- If confidence <80%: Return blocker, DON'T guess

DO NOT:
- Redesign checkpoint (that's orchestrator's job)
- Commit to git
- Implement new features
- Skip validation
- Make unrelated changes

REFERENCES (Read if needed):
- Standards: DEVELOPMENT_STANDARDS.md
- iOS Research: .workflow-logs/active/phases/phase-{phase_number}/ios-research-summary.json (see which files exist)
- Architecture: <specs from checkpoint design references>

RETURN FORMAT (JSON):
{
  "status": "fixed|blocked|needs_redesign",
  "checkpoint": {checkpoint_number},
  "bug_diagnosis": {
    "root_cause": "1-2 sentence explanation",
    "affected_files": ["path/to/file.py"],
    "pattern_violated": "DEVELOPMENT_STANDARDS section or null",
    "bug_category": "syntax_error|logic_error|pattern_violation|design_flaw|external_issue"
  },
  "fix_applied": {
    "approach": "1-2 sentence description",
    "files_modified": ["path/to/file.py"],
    "lines_changed": "+X -Y",
    "diff_summary": "Brief description of changes"
  },
  "validation": {
    "passed": true|false,
    "command": "<validation command run>",
    "output": "<actual output>",
    "comparison": "Expected: X, Got: Y"
  },
  "blockers": [
    {
      "type": "error|uncertainty|design_flaw|external_issue",
      "description": "Detailed explanation",
      "requires": "redesign|research|user_input|service_fix",
      "attempted_fixes": ["Fix 1", "Fix 2"],
      "documentation_checked": ["file.md"]
    }
  ],
  "fix_confidence": 0.0-1.0,
  "recommendations": ["Consider X for future"]
}
```

---

## Stage 3: Delegate to Bugfix Subagent

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"  # CRITICAL: Must use Sonnet
- description: "Fix bug in Checkpoint {checkpoint_number}"
- prompt: <Full task package from Stage 2>
```

**Wait for subagent completion.**

---

## Stage 4: Process Bugfix Result

**Orchestrator validates result:**

### If status: "fixed"

1. **Save bugfix result:**
   ```bash
   echo '<bugfix_json>' > .workflow-logs/active/phases/phase-{phase_number}/checkpoint-{checkpoint_number}-bugfix-result.json
   ```

2. **Re-run orchestrator validation:**
   ```bash
   # Run validation command from checkpoint design
   <validation_command>
   ```

3. **If validation passes:**
   ```bash
   # Commit fix
   git add <files from bugfix result files_modified>
   git add .workflow-logs/active/phases/phase-{phase_number}/checkpoint-{checkpoint_number}-bugfix-result.json

   # Amend checkpoint commit (if not pushed) OR create fix commit
   git commit -m "fix(phase-{phase_number}): checkpoint {checkpoint_number} - <fix description>

   Root cause: <from bugfix bug_diagnosis.root_cause>
   Files: <files_modified>

   Validation: Passed
   Fix confidence: <from bugfix fix_confidence>"

   # Tag
   git tag phase-{phase_number}-checkpoint-{checkpoint_number}-fixed
   ```

4. **Report to orchestrator:**
   ```
   Bug fixed successfully
   - Root cause: <diagnosis>
   - Fix: <approach>
   - Validation: Passed
   - Ready to continue to next checkpoint
   ```

### If status: "blocked"

1. **Save result:**
   ```bash
   echo '<bugfix_json>' > .workflow-logs/active/phases/phase-{phase_number}/checkpoint-{checkpoint_number}-bugfix-blocked.json
   ```

2. **Report to user (orchestrator pauses):**
   ```markdown
   Checkpoint {checkpoint_number} BLOCKED

   Bug Diagnosis:
   - Root cause: <from bug_diagnosis>
   - Bug category: <from bug_diagnosis>
   - Files affected: <from bug_diagnosis>

   Blocker:
   - Type: <from blockers[0].type>
   - Description: <from blockers[0].description>
   - Requires: <from blockers[0].requires>
   - Attempted fixes: <from blockers[0].attempted_fixes>

   Options:
   1. Provide missing information (if requires: user_input)
   2. Approve redesign (if requires: redesign)
   3. Wait for service fix (if requires: service_fix)
   4. Manual investigation (run /fix-bug again with additional context)

   Orchestrator paused. Awaiting user decision.
   ```

3. **Wait for user action.**

### If status: "needs_redesign"

1. **Save result:**
   ```bash
   echo '<bugfix_json>' > .workflow-logs/active/phases/phase-{phase_number}/checkpoint-{checkpoint_number}-bugfix-redesign-needed.json
   ```

2. **Orchestrator redesigns checkpoint:**
   ```markdown
   Checkpoint {checkpoint_number} requires redesign

   Original design flaw: <from bug_diagnosis>

   Creating revised design: checkpoint-{checkpoint_number}-design-v2.md
   - Address: <root cause>
   - Approach: <revised approach>
   - Maintain: <original goal>
   ```

3. **Re-invoke implementation subagent with v2 design**

4. **Validate again (back to implement-phase Stage 4.3)**

---

## Stage 5: Update Orchestrator State

```bash
# Log bugfix attempt
echo '{
  "checkpoint": {checkpoint_number},
  "bugfix_status": "<fixed|blocked|needs_redesign>",
  "fix_confidence": <from result>,
  "timestamp": "<ISO 8601>"
}' >> .workflow-logs/active/phases/phase-{phase_number}/orchestrator-state.json
```

---

## Notes

**Context Management:**
- Bugfix subagent: ~12K tokens (checkpoint design + diagnosis + fix)
- Orchestrator: No context pollution (subagent returns JSON, orchestrator validates independently)
- Fresh context per bugfix (no accumulation)

**Max Attempts:**
- Automatic bugfix: 1 attempt
- Manual bugfix: User can retry with additional context
- Total: 2 attempts max before escalation

**Integration Points:**
- Called from: implement-phase.md Stage 4.3 (orchestrator validation)
- Can be called: Manually by user
- Returns to: Orchestrator (processes result, commits or escalates)

**Success Criteria:**
- Validation command passes
- No new bugs introduced
- Pattern compliance maintained
- Confidence ≥0.80

**Token Budget:**
- Context: ~2K
- Diagnosis: ~5K
- Fix: ~5K
- Total: ~12K per bugfix
