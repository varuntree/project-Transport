# Implement Custom Plan

Execute implementation through direct orchestrator pattern for any custom plan (not phase-specific). Orchestrator designs and implements all checkpoints end-to-end while maintaining plan context.

## Variables

plan_name: $1 (required: name of plan from /plan command)

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for orchestration decisions.**

---

## Architecture

**Orchestrator (Main Agent - Direct Implementation):**
- Maintains full plan context (grows from ~5K → ~15-25K as checkpoints complete)
- Creates detailed designs for ALL checkpoints upfront
- Implements each checkpoint directly with full context continuity
- Validates implementation, commits to git atomically
- Sees all prior work - builds correctly first time

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
   cat .workflow-logs/active/custom/{plan_name}/exploration-report.json
   ```
   (~2K tokens - compressed reference)

3. **iOS research (if exists):**
   ```bash
   # Check research summary
   cat .workflow-logs/active/custom/{plan_name}/ios-research-summary.json 2>/dev/null || echo "No iOS research"

   # Load research files referenced in checkpoints (on-demand)
   # Do NOT load all at once - load per checkpoint as needed
   ```

**Initial orchestrator context: ~5K tokens (grows as checkpoints complete)**

**Log state:**
```bash
echo '{"stage":"context_loaded","plan_name":"'{plan_name}'","exploration_tokens":2000,"plan_tokens":2000}' > .workflow-logs/active/custom/{plan_name}/orchestrator-state.json
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

**Orchestrator designs BEFORE implementing:**

For each checkpoint from implementation plan:

### Design Template

Create `.workflow-logs/active/custom/{plan_name}/checkpoint-{N}-design.md`:

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

## Implementation References
- Exploration report: `critical_patterns` → <specific pattern>
- iOS research: `.workflow-logs/active/custom/{plan_name}/ios-research-<topic>.md`
- Standards: DEVELOPMENT_STANDARDS.md:Section X
- Architecture: <spec file>:Section Y
- Previous checkpoint: <if depends on previous checkpoint result>
```

**Orchestrator creates designs for ALL checkpoints before starting execution.**

**Why design first:**
- See full plan picture (can optimize handoffs)
- Identify cross-checkpoint dependencies
- Catch design flaws before implementation

---

## Stage 4: Execute Checkpoints (Direct Implementation)

**For each checkpoint:**

### 4.1 Load Checkpoint Design

Read checkpoint design:
```bash
cat .workflow-logs/active/custom/{plan_name}/checkpoint-{N}-design.md
```

Review:
- Goal and approach
- Files to create/modify
- Implementation references
- Validation command
- Previous checkpoint context (if N > 1)

### 4.2 Implement Checkpoint Directly

**Orchestrator implements (with full context):**

1. **Confidence check BEFORE implementing:**
   - Am I 80%+ confident this pattern/API is correct?
   - iOS-specific code? → Read iOS research file from design references
   - External service? → WebFetch/search official docs if uncertain
   - NEVER hallucinate - if confidence <80%, READ the reference docs

2. **Create/modify files per design:**
   - Follow DEVELOPMENT_STANDARDS.md (logging, error handling, naming)
   - Implement all files specified in design
   - Use patterns from exploration report critical_patterns
   - Reference previous checkpoint results for context handoff

3. **Self-validate as you go:**
   - Does this match the design approach?
   - Are all edge cases handled?
   - Is logging/error handling included?

### 4.3 Validate Implementation

**Check correctness:**

1. **Verify files exist:**
   ```bash
   ls -la <files created/modified>
   ```

2. **Run validation command:**
   ```bash
   <validation command from checkpoint design>
   # Compare output to expected result
   ```

3. **Compile check (if applicable):**
   ```bash
   # Backend
   cd backend && python -m py_compile <files>

   # iOS (if Xcode available)
   xcodebuild -scheme SydneyTransit -sdk iphonesimulator build
   ```

**If validation fails:**
- **Option 1:** Fix directly (max 1 retry attempt)
- **Option 2:** Redesign checkpoint (create design-v2.md, re-implement)
- **Option 3:** Escalate to user (true blocker - external dependency, unclear requirement)

**Max 1 retry, then escalate to user.**

### 4.4 Commit Checkpoint (Atomic)

```bash
git add .

# Log checkpoint result
echo '{
  "checkpoint": '{checkpoint_number}',
  "status": "complete",
  "files_created": ["..."],
  "files_modified": ["..."],
  "validation_passed": true,
  "next_checkpoint_context": "Critical info for next checkpoint"
}' > .workflow-logs/active/custom/{plan_name}/checkpoint-{N}-result.json

git add .workflow-logs/active/custom/{plan_name}/

git commit -m "feat({plan_name}): checkpoint {N} - <name>

<Brief description of what was implemented>

Validation: <validation result>
Files: <count> created, <count> modified

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Tag checkpoint
git tag {plan_name}-checkpoint-{N}
```

### 4.5 Update State and Continue

```bash
# Update state for next checkpoint
echo '{
  "checkpoint_completed": '{checkpoint_number}',
  "status": "complete",
  "files_created": '<count>',
  "next_checkpoint_context": "<critical info for next checkpoint>"
}' >> .workflow-logs/active/custom/{plan_name}/orchestrator-state.json
```

**Repeat for next checkpoint** - load next design, implement, validate, commit.

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

`.workflow-logs/active/custom/{plan_name}/completion-report.json`:

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

Save to: `.workflow-logs/active/custom/{plan_name}/REPORT.md`

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

Full Report: .workflow-logs/active/custom/{plan_name}/REPORT.md

Ready for Merge: Yes/No
<If No, explain what needs fixing>

Next: Review report, then merge to main
```

---

## Notes

**Direct Implementation Benefits:**
- Full context continuity (sees all prior checkpoints, builds correctly first time)
- No information loss between checkpoints (understands dependencies implicitly)
- Simpler execution (no task packaging, JSON parsing, or subagent coordination)
- Clean git history (atomic commits per checkpoint with full result logs)
- Higher reliability (no "subagent assumed wrong context" failures)

**Token Management:**
- Orchestrator context: ~5K → ~15-25K total (grows incrementally per checkpoint)
- Growth rate: ~2-4K per checkpoint (design + implementation + result)
- Still manageable for plans with 5-8 checkpoints
- For larger plans (10+ checkpoints): consider splitting into sub-plans

**Cost vs Quality:**
- Single Sonnet session (vs multiple subagent invocations) = lower cost
- Context continuity → fewer mistakes → less rework
- Trade-off: Optimizing for both reliability AND cost efficiency
