# Implement Custom Plan

Execute implementation through orchestrator-subagent pattern for any custom plan (not phase-specific). Orchestrator designs and delegates checkpoints, subagents execute with fresh context.

## Variables

plan_name: $1 (required: name of plan from /plan command)

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for orchestration decisions.**

---

## Architecture

**Orchestrator (Main Agent):**
- Maintains plan-level context (~5K tokens, constant)
- Creates detailed designs for ALL checkpoints
- Delegates execution to implementation subagents
- Validates results, commits to git
- Never drowns in implementation details

**Implementation Subagents (Per Checkpoint):**
- Fresh context window per checkpoint
- Receives focused task package
- Implements, self-validates, returns structured result
- No git commits (orchestrator handles)

---

## Stage 1: Load Plan Context

**Orchestrator loads (lightweight):**

1. **Plan file:**
   ```bash
   cat specs/{plan_name}-plan.md
   ```
   (~2K tokens - checkpoint structure)

2. **Exploration report:**
   ```bash
   cat .workflow-logs/custom/{plan_name}/exploration-report.json
   ```
   (~2K tokens - compressed reference)

3. **iOS research (if exists):**
   ```bash
   # Check research summary
   cat .workflow-logs/custom/{plan_name}/ios-research-summary.json 2>/dev/null || echo "No iOS research"

   # Load research files referenced in checkpoints (on-demand)
   # Do NOT load all at once - load per checkpoint as needed
   ```

**Total orchestrator context: ~5K tokens (stays constant throughout)**

**Log state:**
```bash
echo '{"stage":"context_loaded","plan_name":"'{plan_name}'","exploration_tokens":2000,"plan_tokens":2000}' > .workflow-logs/custom/{plan_name}/orchestrator-state.json
```

---

## Stage 2: Verify Prerequisites

**Orchestrator checks:**

1. **User blockers resolved:**
   - Read `user_blockers` from plan file
   - Verify external services configured
   - If incomplete: STOP, report blocker

2. **Clean git state:**
   ```bash
   git status
   # If dirty: commit or stash
   git checkout -b {plan_name}-implementation
   ```

**If any prerequisite fails:** Report blocker to user, do NOT continue.

---

## Stage 3: Create Detailed Designs (All Checkpoints)

**Orchestrator designs BEFORE delegating:**

For each checkpoint from implementation plan:

### Design Template

Create `.workflow-logs/custom/{plan_name}/checkpoint-{N}-design.md`:

```markdown
# Checkpoint {N}: <Name>

## Goal
<From plan: specific success criteria>

## Approach
<Orchestrator decides technical approach>

### Backend Implementation
- Use <library/pattern> for <functionality>
- Files to create: <list with purposes>
- Files to modify: <list with changes>
- Critical pattern: <from exploration report critical_patterns>

### iOS Implementation
- Use <SwiftUI/GRDB pattern> for <functionality>
- Files to create: <list with purposes>
- Files to modify: <list with changes>
- Reference iOS research: <path to research file>

## Design Constraints
<From plan + orchestrator additions>
- Follow DEVELOPMENT_STANDARDS.md Section X for <pattern>
- Achieve <performance/size target>
- Handle errors: <specific approach>

## Risks
- <Potential issue 1>
  - Mitigation: <How to avoid>
- <Potential issue 2>
  - Mitigation: <How to avoid>

## Validation
```bash
<Command to verify checkpoint success>
# Expected output: <specific result>
```

## References for Subagent
- Exploration report: `critical_patterns` → <specific pattern>
- iOS research: `.workflow-logs/custom/{plan_name}/ios-research-<topic>.md`
- Standards: DEVELOPMENT_STANDARDS.md:Section X
- Architecture: <spec file>:Section Y
- Previous checkpoint: <if depends on previous checkpoint result>

## Estimated Complexity
<simple|moderate|complex> - <reasoning>
```

**Orchestrator creates designs for ALL checkpoints before starting execution.**

**Why design first:**
- See full plan picture (can optimize handoffs)
- Identify cross-checkpoint dependencies
- Catch design flaws before implementation

---

## Stage 4: Execute Checkpoints (Delegation Loop)

**For each checkpoint:**

### 4.1 Package Checkpoint Task

Orchestrator prepares task package:

```markdown
TASK: Implement Checkpoint {N}: <Name>

PLAN CONTEXT:
- Plan: {plan_name}
- Task type: {task_type from exploration}
- Overall goal: {context_summary from exploration}
- Your checkpoint: <Specific goal>

CHECKPOINT DESIGN:
<Paste full design from .workflow-logs/custom/{plan_name}/checkpoint-{N}-design.md>

PREVIOUS CHECKPOINT RESULT (if N > 1):
<From previous subagent JSON return>
{
  "status": "complete",
  "files_created": ["..."],
  "validation_passed": true,
  "next_checkpoint_context": "Critical info for handoff"
}

REFERENCES (Read if needed):
- Exploration patterns: .workflow-logs/custom/{plan_name}/exploration-report.json → critical_patterns
- iOS research: .workflow-logs/custom/{plan_name}/ios-research-summary.json (see which files exist)
  - Load specific research file: .workflow-logs/custom/{plan_name}/ios-research-<topic>.md (only if checkpoint needs it)
- Standards: DEVELOPMENT_STANDARDS.md (specific sections in design)
- Architecture specs: <From design references>
- Example code: <From exploration report example_location>

EXECUTION GUIDELINES:
1. Implement all files specified in design
2. Follow DEVELOPMENT_STANDARDS.md patterns (logging, error handling, naming)
3. Self-validate:
   - Compile check (Python: python -m py_compile file.py, Swift: Cmd+B)
   - Run validation command from design
   - Fix errors (max 2 retry loops)
   - If still failing after 2 retries: return blocker status
4. Return structured JSON (format below)

CONFIDENCE CHECK (CRITICAL):
Before implementing any pattern/library/API:
- Am I 80%+ confident this is correct?
- Is this iOS-specific? → MUST have iOS research reference
- Is this external service? → Check documentation if uncertain
- NEVER hallucinate - if confidence <80%, READ the reference docs

If uncertain:
- iOS patterns → Check .workflow-logs/custom/{plan_name}/ios-research-summary.json for relevant topic, then read that specific research file
- Backend patterns → Read DEVELOPMENT_STANDARDS.md section
- External service → Use WebFetch or search for official docs
- Return "blocked" status if truly stuck (don't guess, NEVER hallucinate iOS APIs)

DO NOT:
- Commit to git (orchestrator handles)
- Move to next checkpoint (you only do this one)
- Read unrelated files (stay focused)
- Implement features not in design
- Skip error handling or logging

RETURN FORMAT (JSON):
{
  "status": "complete|blocked|partial",
  "checkpoint": {checkpoint_number},
  "files_created": ["path/to/file.py", "path/to/file.swift"],
  "files_modified": ["path/to/existing.py"],
  "validation": {
    "passed": true|false,
    "command": "<validation command run>",
    "output": "<actual output>",
    "issues": []
  },
  "blockers": [
    {"type": "error|uncertainty|missing", "description": "...", "attempted_fixes": ["..."]}
  ],
  "next_checkpoint_context": "Critical info for next checkpoint (e.g., 'Generated 487 patterns in patterns table, use pattern_id foreign key')",
  "confidence_checks": {
    "ios_research_consulted": true|false,
    "standards_followed": ["Section 2", "Section 4"],
    "uncertainties_researched": ["Topic 1 - researched Apple docs"]
  }
}
```

### 4.2 Delegate to Implementation Subagent

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"  # CRITICAL: Must use Sonnet (not Haiku)
- description: "Implement Checkpoint {N}: <Name>"
- prompt: <Full task package from 4.1>
```

**Wait for subagent completion.**

### 4.3 Validate Subagent Result

**Orchestrator independently verifies:**

1. **Check files exist:**
   ```bash
   ls -la <files from subagent files_created>
   # Verify not hallucinated
   ```

2. **Run validation command:**
   ```bash
   <validation command from checkpoint design>
   # Compare output to expected
   ```

3. **Compile check (if applicable):**
   ```bash
   # Backend
   cd backend && python -m py_compile <files>

   # iOS (if Xcode available)
   xcodebuild -scheme SydneyTransit -sdk iphonesimulator build
   ```

4. **Compare subagent report vs actual state:**
   - If subagent said "complete" but validation fails → Issue detected
   - If files missing → Subagent hallucinated

**If validation fails:**
- **Option 1:** Invoke bugfix subagent (automatic, see 4.3.1)
- **Option 2:** Redesign checkpoint (orchestrator adjusts design)
- **Option 3:** Escalate to user (true blocker)

**Retry once, then escalate.**

### 4.3.1 Invoke Bugfix Subagent

**Orchestrator automatic bugfix workflow:**

1. **Capture bug context:**
   ```bash
   # Save validation failure
   echo '{
     "checkpoint": '{checkpoint_number}',
     "validation_command": "<command>",
     "validation_output": "<output>",
     "expected_output": "<from design>",
     "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
   }' > .workflow-logs/custom/{plan_name}/checkpoint-{N}-validation-failure.json
   ```

2. **Invoke /fix-bug:**
   ```
   SlashCommand: /fix-bug custom {plan_name} {checkpoint_number} validation_failed
   ```

3. **Process bugfix result:**

   **If status: "fixed":**
   - Re-run orchestrator validation (Stage 4.3 checks)
   - If passes → Commit (Stage 4.4)
   - If still fails → Escalate to user

   **If status: "blocked":**
   - Report to user: diagnosis + blocker + required action
   - Pause implementation, wait for user decision

   **If status: "needs_redesign":**
   - Orchestrator redesigns checkpoint (create design-v2.md)
   - Re-invoke implementation subagent with v2 design
   - Validate again

4. **Max 1 automatic attempt. If fails → escalate to user.**

### 4.4 Commit Checkpoint (Atomic)

**Orchestrator commits (not subagent):**

```bash
git add .

# Save subagent result
echo '<subagent_json>' > .workflow-logs/custom/{plan_name}/checkpoint-{N}-result.json

git add .workflow-logs/custom/{plan_name}/

git commit -m "feat({plan_name}): checkpoint {N} - <name>

<Brief description of what was implemented>

Validation: <validation result>
Files: <count> created, <count> modified

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Tag checkpoint
git tag {plan_name}-checkpoint-{N}
```

**Why orchestrator commits:**
- Clean git history (not polluted by subagent)
- Orchestrator control (can rollback if needed)
- Includes checkpoint result JSON (full audit trail)

### 4.5 Update Orchestrator State

```bash
# Update state for next checkpoint
echo '{
  "checkpoint_completed": '{checkpoint_number}',
  "status": "<from subagent>",
  "files_created": '<count>',
  "next_checkpoint_context": "<from subagent result>"
}' >> .workflow-logs/custom/{plan_name}/orchestrator-state.json
```

### 4.6 Repeat for Next Checkpoint

Load next checkpoint design, package task (include previous result), delegate.

---

## Stage 5: Final Validation

**After all checkpoints complete:**

### 5.1 Run Full Acceptance Criteria

From implementation plan acceptance criteria:

```bash
# Backend tests (if applicable)
curl http://localhost:8000/health
curl http://localhost:8000/api/v1/<endpoints from plan>

# iOS tests (if applicable)
# Xcode: Cmd+B (build), Cmd+R (run simulator)
# Manual testing checklist from plan

# Integration tests
# Backend + iOS working together
```

**Document results:**
```json
{
  "acceptance_criteria": [
    {"criterion": "...", "passed": true, "notes": "..."},
    {"criterion": "...", "passed": false, "error": "..."}
  ]
}
```

**If any criterion fails:**
- Identify which checkpoint failed
- Redesign + re-execute that checkpoint
- Re-run full acceptance criteria

**DO NOT proceed if tests fail.**

### 5.2 Final Commit

```bash
git add .
git commit -m "feat({plan_name}): complete implementation

All checkpoints: <N> completed
Acceptance criteria: <X>/<Y> passed
Files: <count> created, <count> modified

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git tag {plan_name}-complete
```

---

## Stage 6: Create Completion Report

**Orchestrator generates:**

`.workflow-logs/custom/{plan_name}/completion-report.json`:

```json
{
  "plan_name": "{plan_name}",
  "task_description": "{from exploration}",
  "status": "complete|partial|blocked",
  "checkpoints": [
    {
      "number": 1,
      "name": "...",
      "status": "complete",
      "validation_passed": true,
      "files_created": 5,
      "commit": "abc123"
    }
  ],
  "acceptance_criteria": {
    "total": 5,
    "passed": 5,
    "failed": 0,
    "details": [...]
  },
  "files_summary": {
    "created": ["..."],
    "modified": ["..."],
    "total_changes": "+523 -45 lines"
  },
  "blockers_encountered": [],
  "deviations_from_plan": [],
  "ready_for_merge": true,
  "recommendations": ["..."]
}
```

**Human-readable report:**

```markdown
# {Plan Name} Implementation Report

**Status:** Complete
**Duration:** <actual time>
**Checkpoints:** {N} of {N} completed

---

## Implementation Summary

**Task:** {task_description}

**Backend:**
- <Key change 1>
- <Key change 2>

**iOS:**
- <Key change 1>
- <Key change 2>

**Integration:**
- <How they connect>

---

## Checkpoints

### Checkpoint 1: <Name>
- Status: ✅ Complete
- Validation: Passed
- Files: 5 created, 2 modified
- Commit: abc123

<Repeat for all checkpoints>

---

## Acceptance Criteria

- [x] Criterion 1 - Passed
- [x] Criterion 2 - Passed
- [x] Criterion 3 - Passed
- [x] Criterion 4 - Passed
- [x] Criterion 5 - Passed

**Result: 5/5 passed**

---

## Files Changed

```bash
git diff --stat main..{plan_name}-implementation
```

<Output>

---

## Blockers Encountered

<List any blockers + resolutions>
<Or "None">

---

## Deviations from Plan

<List any changes + rationale>
<Or "None - followed plan exactly">

---

## Known Issues

<List technical debt or issues>
<Or "None">

---

## Ready for Merge

**Status:** Yes

**Next Steps:**
1. User reviews report
2. User merges: `git checkout main && git merge {plan_name}-implementation`
3. Ready for next task

---

**Report Generated:** <timestamp>
**Total Implementation Time:** <duration>
```

Save to: `.workflow-logs/custom/{plan_name}/REPORT.md`

---

## Report to User

Provide concise summary:

```
{Plan Name} Implementation: Complete

Checkpoints: {N}/{N} completed
Acceptance Criteria: {X}/{Y} passed

Backend:
- <Key deliverable 1>
- <Key deliverable 2>

iOS:
- <Key deliverable 1>
- <Key deliverable 2>

Integration:
- <How they connect>

Files: <N> created, <M> modified (+<lines> -<lines>)

Blockers: <None or list>
Deviations: <None or list>

Full Report: .workflow-logs/custom/{plan_name}/REPORT.md

Ready for Merge: Yes/No
<If No, explain what needs fixing>

Next: Review report, then merge to main
```

---

## Notes

**Orchestrator Benefits:**
- Maintains plan coherence (never lost in details)
- Clean context per checkpoint (no context rot)
- Independent validation (catches subagent hallucinations)
- Clean git history (atomic commits per checkpoint)

**Subagent Benefits:**
- Fresh context (15K+ tokens for implementation)
- Focused task (one checkpoint, clear goal)
- Self-contained (design + references provided)
- Fail-safe (orchestrator validates independently)

**Token Management:**
- Orchestrator: ~5K constant (never grows)
- Subagent: ~15K per checkpoint (then discarded)
- Total: More tokens used, but higher quality + reliability

**Cost vs Quality:**
- Multiple Sonnet invocations = higher cost
- But: Fewer bugs, no context pollution, reliable output
- Trade-off: Optimizing for reliability over cost
