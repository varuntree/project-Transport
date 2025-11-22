# Implement Plan

Execute implementation through direct checkpoint-by-checkpoint pattern. Orchestrator implements all checkpoints with full context continuity.

## Variables

plan_name: $1 (required: name of plan from /plan command)

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for implementation decisions.**

---

## Stage 1: Load Plan

```bash
plan_name="$1"
plan_file=".claude-logs/plans/${plan_name}/plan.md"
implement_dir=".claude-logs/implement/${plan_name}"
mkdir -p "${implement_dir}"
```

### 1.1 Read Plan

Read plan file and understand:
- Problem statement
- Affected systems
- Key technical decisions
- All checkpoints
- Acceptance criteria

### 1.2 Check Prerequisites

- Clean git state (commit or stash changes)
- Create implementation branch:
  ```bash
  git checkout -b ${plan_name}-implementation
  ```

---

## Stage 2: Execute Checkpoints

For each checkpoint in plan:

### 2.1 Understand Checkpoint

Read from plan:
- Goal and success criteria
- Backend work
- iOS work
- Design constraints
- Validation command
- References

Load any iOS research files referenced.

### 2.2 Implement Checkpoint

**Direct implementation with full context:**

1. **Confidence Check:**
   - 80%+ confident on approach?
   - iOS work? Read referenced ios-research files
   - External service? Research if needed
   - NEVER hallucinate - research if uncertain

2. **Create/Modify Files:**
   - Follow DEVELOPMENT_STANDARDS.md patterns
   - Implement all work specified in checkpoint
   - Backend + iOS together
   - Include logging, error handling, validation

3. **Self-Validate:**
   - Does this match checkpoint goal?
   - Edge cases handled?
   - Standards followed?

### 2.3 Validate Implementation

1. **Verify files exist:**
   ```bash
   ls -la {files created/modified}
   ```

2. **Run validation command from plan:**
   ```bash
   {validation command}
   # Compare to expected output
   ```

3. **Compile check:**
   - Backend: `cd backend && python -m py_compile {files}`
   - iOS: Build in Xcode (if available)

**If validation fails:** Fix directly (max 1 retry), then stop if still failing.

### 2.4 Commit Checkpoint

```bash
git add .

git commit -m "feat(${plan_name}): checkpoint {N} - {name}

{Brief description}

Validation: {result}

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git tag ${plan_name}-checkpoint-{N}
```

**Repeat for all checkpoints.**

---

## Stage 3: Final Validation

After all checkpoints complete:

### 3.1 Run Acceptance Criteria

From plan, verify all acceptance criteria:
- Backend endpoints working?
- iOS features working?
- Integration complete?

### 3.2 Final Commit

```bash
git add .
git commit -m "feat(${plan_name}): complete implementation

All checkpoints: {N} completed
Files: {count} created, {count} modified

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

git tag ${plan_name}-complete
```

---

## Stage 4: Create Completion Report

Write `.claude-logs/implement/{plan_name}/REPORT.md`:

```markdown
# {Plan Name} Implementation Report

**Status:** Complete
**Checkpoints:** {N} of {N} completed
**Date:** {date}

---

## Implementation Summary

**Task:** {from plan}

**Changes:**
- Backend: {key changes}
- iOS: {key changes}
- Integration: {how they connect}

---

## Checkpoints

### Checkpoint 1: {Name}
- Status: ✅ Complete
- Validation: Passed
- Files: {list}
- Commit: {hash}

{Repeat for all checkpoints}

---

## Acceptance Criteria

- [x] Criterion 1 - Passed
- [x] Criterion 2 - Passed
- [x] Criterion 3 - Passed

**Result:** {X}/{Y} passed

---

## Files Changed

```bash
git diff --stat main..${plan_name}-implementation
```

{Output}

---

## Blockers Encountered

{List blockers + resolutions, or "None"}

---

## Deviations from Plan

{List changes + rationale, or "None - followed plan exactly"}

---

## Ready for Merge

**Status:** {Yes/No}

**Next Steps:**
1. Review: /review
2. Merge: git checkout main && git merge ${plan_name}-implementation
3. Tag: git tag -a ${plan_name}-released

---

**Report Generated:** {timestamp}
**Branch:** ${plan_name}-implementation
**Commits:** {count}
```

---

## Report to User

```
Implementation Complete: {plan_name}

Checkpoints: {N}/{N} completed
Acceptance Criteria: {X}/{Y} passed

Changes:
- Backend: {summary}
- iOS: {summary}

Files: {N} created, {M} modified

Blockers: {None or list}
Deviations: {None or list}

Report: .claude-logs/implement/{plan_name}/REPORT.md
Branch: ${plan_name}-implementation

Ready for Merge: {Yes/No}

Next: /review
```

---

## Notes

- No subagents - direct implementation
- Full context continuity across checkpoints
- Markdown only (no JSON)
- Atomic commits per checkpoint
- Single folder: .claude-logs/implement/{plan_name}/
