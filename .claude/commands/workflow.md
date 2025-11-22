# Workflow Orchestrator

Autonomous task router that analyzes user intent, classifies task type, and automatically routes to appropriate workflow commands.

**⚠️ CRITICAL: This command is ORCHESTRATOR ONLY**

**Your role:** Analyze task → Route to appropriate command → **INVOKE** using `SlashCommand` tool

**You do NOT:** Execute planning, implementation, testing, or bug fixing yourself

**You MUST:** Use `SlashCommand` tool to invoke other commands

---

## Usage

```
/workflow "add caching for patterns"
/workflow "iOS map view not showing annotations"
/workflow "implement better error handling for GTFS parsing"
```

## Variables

task_input: $1 (required: raw user description - can be rough/unclear)

## Instructions

**IMPORTANT: Think hard. Activate reasoning mode for understanding intent.**

---

## Stage 1: Understand Intent

### 1.1 Parse User Input

Analyze raw input:
- What is user trying to accomplish?
- Bug fix, feature, optimization, refactor?
- Which systems mentioned?
- Underlying problem or goal?

### 1.2 Reconstruct Clear Task

Fix grammar, expand abbreviations, make intent explicit:

**Examples:**
```
"celery thing broken memory"
→ "Fix memory leak in Celery task worker"

"add cache for patterns"
→ "Implement caching layer for GTFS pattern queries"

"map not work"
→ "Debug iOS MapKit view not displaying annotations"
```

### 1.3 Classify Task Type

**Keyword patterns:**

**BUG/FIX:**
- fix, bug, broken, failing, error, crash, leak, issue
- not working, doesn't work, stopped working
→ Classification: BUG_FIX

**FEATURE:**
- add, implement, create, new, build
- feature, functionality, capability
- support for, enable
→ Classification: FEATURE

**OPTIMIZATION:**
- optimize, improve, faster, performance
- reduce, decrease (memory/latency/size)
- cache, index, batch
→ Classification: OPTIMIZATION

**REFACTOR:**
- refactor, cleanup, reorganize, restructure
- extract, consolidate, simplify
→ Classification: REFACTOR

---

## Stage 2: Determine Scope & Complexity

### 2.1 Identify Affected Systems

From task keywords, determine:
- Backend API?
- iOS App?
- Data layer?
- Documentation?

### 2.2 Estimate Complexity

**Factors:**
- Number of systems affected
- Number of files likely changed
- New patterns required?

**Complexity:**
- Simple: 1 system, <5 files, existing patterns
- Medium: 2 systems, 5-10 files, minor new patterns
- Complex: 3+ systems, >10 files, major architecture

### 2.3 Check Existing Work

Look for existing plan:
```bash
plan_slug=$(echo "{reconstructed_task}" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-60)

if [ -f ".claude-logs/plans/${plan_slug}/plan.md" ]; then
  existing_plan=true
fi
```

---

## Stage 3: Route to Workflow

### 3.1 Decision Logic

```
IF task_type == "BUG_FIX":
  workflow = "bug"
  commands = ["/bug \"{reconstructed_task}\""]

ELSE IF existing_plan:
  workflow = "implement_existing"
  commands = ["/implement {plan_slug}"]

ELSE IF task_type IN ["FEATURE", "OPTIMIZATION", "REFACTOR"]:
  workflow = "plan_implement_review"
  commands = [
    "/plan \"{reconstructed_task}\"",
    "/implement {plan_slug}",
    "/review {plan_slug}"
  ]

ELSE:
  workflow = "unknown"
  # Ask user for clarification
```

### 3.2 Confidence Check

Ask user if:
- Confidence <70% on task understanding
- Destructive operation (schema changes, deletions)
- Multiple valid interpretations
- Cannot determine workflow

**Destructive indicators:**
- delete, drop, remove, truncate (on DB/tables)
- schema change, breaking change
- large-scale refactor/migration

---

## Stage 4: Execute Workflow

**CRITICAL: Use SlashCommand tool to invoke each command.**

### 4.1 If Confident (No User Confirmation Needed)

```
Task Analysis:
- Input: {raw input}
- Reconstructed: {reconstructed_task}
- Type: {task_type}
- Scope: {systems affected}
- Complexity: {simple|medium|complex}

Workflow: {workflow}
- Commands: {list commands}
- Reasoning: {why this workflow}

Executing automatically...

---

FOR EACH command IN commands:

  Report: "→ Running: {command}"

  # INVOKE USING SlashCommand TOOL
  SlashCommand tool:
  - command: "{command}"

  # Wait for completion

  IF command failed:
    Report: "❌ Command failed: {command}

    Error: {details}

    Stopping workflow.

    Recommendation: {how to fix}"

    STOP

  ELSE:
    Report: "✅ Command completed: {command}

    Result: {summary}"

    Continue

# After all complete:
Report: "✅ Workflow Complete

Commands executed:
{list with checkmarks}

Result: {aggregate summary}

Next: {next steps}"
```

**Examples of SlashCommand invocation:**

```
# Bug workflow
SlashCommand tool:
- command: "/bug \"Fix memory leak in Celery alert matcher\""

# Plan + Implement + Review workflow
SlashCommand tool:
- command: "/plan \"Implement Redis caching for GTFS patterns\""

# (wait, then:)
SlashCommand tool:
- command: "/implement redis-caching-gtfs-patterns"

# (wait, then:)
SlashCommand tool:
- command: "/review redis-caching-gtfs-patterns"
```

### 4.2 If Uncertain (User Confirmation Required)

```
Task Analysis:
- Input: {raw input}
- Reconstructed: {reconstructed_task}
- Type: {task_type}
- Scope: {systems}
- Complexity: {level}

⚠️ Confirmation Required
Reason: {why asking}

Recommended Workflow: {workflow}
- Commands: {list}
- Reasoning: {why}

Alternatives:
1. {alternative if applicable}
2. Manual workflow (you specify commands)
3. Refine task description

Confirm:
- Execute recommended? (yes/no)
- OR specify alternative commands
- OR provide clarification

---

Wait for user response

IF user confirms:
  # Execute using SlashCommand tool (same as 4.1)

ELSE IF user specifies commands:
  FOR EACH command IN user_commands:
    SlashCommand tool:
    - command: "{command}"

ELSE IF user clarifies:
  # Re-run from Stage 1 with new info

ELSE:
  STOP, wait for instructions
```

---

## Report Format

After workflow execution:

```markdown
# Workflow Execution Report

**Task:** {reconstructed_task}
**Original Input:** {raw input}

---

## Analysis

**Classification:**
- Type: {task_type}
- Complexity: {level}
- Scope: {systems affected}
- Confidence: {0-100%}

**Workflow:** {workflow}

---

## Commands Executed

1. {command} - {✅ Success | ❌ Failed} ({duration})
   - Result: {summary}
   - Details: {link to output}

2. {command} - {✅ Success | ❌ Failed} ({duration})
   - Result: {summary}

---

## Overall Status

{✅ Workflow completed | ❌ Workflow failed at: {command}}

**Artifacts:**
- Plans: {list}
- Commits: {list}
- Reports: {list}

---

## Next Steps

{If success}
✅ Implementation complete
- Review commits: git log
- Merge: git merge {branch}

{If failure}
❌ Workflow incomplete
- Failed at: {command}
- Error: {description}
- Fix: {recommendation}
- Retry: /workflow "{task}"

---

**Total Duration:** {duration}
```

---

## Examples

### Example 1: Bug (Auto)

```
User: "celery alert matcher uses too much memory"

Analysis:
- Type: BUG_FIX (0.95)
- Scope: Backend
- Complexity: medium

Workflow: bug

→ /bug "Fix memory leak in Celery alert matcher task"
  ✅ Complete (12 min)
  - Root cause: Query loads all rows
  - Fix: Add LIMIT + pagination
  - Commit: abc123

✅ Workflow Complete
```

### Example 2: Feature (Auto)

```
User: "add cache for route patterns"

Analysis:
- Type: FEATURE (0.88)
- Scope: Backend
- Complexity: medium

Workflow: plan_implement_review

→ /plan "Implement Redis caching for GTFS patterns"
  ✅ Complete (5 min)
  - Plan: .claude-logs/plans/redis-caching-gtfs-patterns/plan.md

→ /implement redis-caching-gtfs-patterns
  ✅ Complete (30 min)
  - 3 checkpoints
  - Commits: abc123, def456, ghi789

→ /review redis-caching-gtfs-patterns
  ✅ Complete (3 min)
  - Health: Green
  - 0 P0, 2 P1

✅ Workflow Complete
```

### Example 3: Ambiguous (Ask User)

```
User: "make it faster"

Analysis:
- Type: OPTIMIZATION (0.60)
- Scope: Unknown
- Confidence: LOW

⚠️ Confirmation Required
Reason: Task too vague

"make it faster" unclear.

Clarify:
1. What needs to be faster?
   - Backend API?
   - iOS UI?
   - Database queries?
   - GTFS loading?

2. Current performance issue?
   - Specific slow operation?
   - Measurements?

3. Target performance?
```

---

## Notes

- Autonomous execution (if confident)
- User confirmation for ambiguous/risky
- Uses SlashCommand tool exclusively
- No direct implementation by orchestrator
- Generalizes to any flow (not just bugs)
- Adapts based on task classification
