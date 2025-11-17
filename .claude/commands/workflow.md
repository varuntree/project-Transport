# Workflow Orchestrator

Autonomous task router that understands user intent, reconstructs task description, analyzes requirements, and automatically executes the appropriate workflow.

**⚠️ CRITICAL: This command is an ORCHESTRATOR ONLY**

**Your role:** Analyze task → Route to appropriate command → **INVOKE** that command using `SlashCommand` tool

**You do NOT:** Execute planning, implementation, testing, or bug fixing yourself

**You MUST:** Use `SlashCommand` tool to invoke `/plan`, `/implement`, `/test`, `/bug`, etc.

**Example:**
```
User: "add caching for patterns"

✅ CORRECT:
1. Analyze: Feature addition, medium complexity
2. Route: /plan → /implement → /test
3. Invoke: SlashCommand tool with "/plan \"Implement caching for patterns\""
4. Wait for /plan to complete
5. Invoke: SlashCommand tool with "/implement {plan-name}"
6. Wait for /implement to complete
7. Invoke: SlashCommand tool with "/test all"

❌ WRONG:
1. Analyze task
2. Read codebase yourself
3. Create plan yourself
4. Write code yourself
(This defeats the purpose of composable commands)
```

---

## Usage

```
/workflow "celery alert matcher uses too much memory"
/workflow "add caching for route patterns"
/workflow "iOS map view not showing annotations"
/workflow "implement phase 3"
```

## Variables

task_input: $1 (required: raw user description of task - can be rough/unclear)

## Instructions

**IMPORTANT: Think hard. Activate reasoning mode for understanding user intent and routing decisions.**

---

## Stage 1: Understand & Reconstruct Task

**Purpose:** Extract true user intent, fix unclear phrasing, reconstruct as clear task description.

### 1.1 Parse User Input

**Analyze raw input:**

```
Raw input: "$1"

Questions to answer:
1. What is the user trying to accomplish?
2. Is this a bug fix, feature addition, optimization, refactor, or phase work?
3. Are there ambiguous terms or unclear requirements?
4. What systems/components are mentioned?
5. What is the underlying problem or goal?
```

### 1.2 Reconstruct Task Description

**Create clear, unambiguous task description:**

```
Reconstruction rules:
- Fix grammar/spelling
- Expand abbreviations/slang
- Make implicit intent explicit
- Add missing context (infer from keywords)
- Remove unnecessary details
- Keep technical terms precise

Examples:
Input: "celery thing broken memory"
→ Reconstructed: "Fix memory leak in Celery task worker"

Input: "add cache thing for patterns"
→ Reconstructed: "Implement caching layer for GTFS pattern queries"

Input: "map not work"
→ Reconstructed: "Debug iOS MapKit view not displaying annotations"

Input: "do phase 3"
→ Reconstructed: "Implement Phase 3 from implementation roadmap"
```

**Save reconstructed task:**
```bash
reconstructed_task="<reconstructed description>"
echo "User input: $1" > /tmp/workflow-analysis.txt
echo "Reconstructed: $reconstructed_task" >> /tmp/workflow-analysis.txt
```

---

## Stage 2: Analyze & Classify

**Purpose:** Determine task type, scope, complexity, and route to appropriate workflow.

### 2.1 Keyword Analysis

**Extract keywords and classify:**

```
Keyword patterns:

BUG/FIX INDICATORS:
- fix, bug, broken, failing, error, crash, leak, issue
- not working, doesn't work, stopped working
- regression, broke after
→ Classification: BUG_FIX

FEATURE INDICATORS:
- add, implement, create, new, build
- feature, functionality, capability
- support for, enable
→ Classification: FEATURE

OPTIMIZATION INDICATORS:
- optimize, improve, faster, performance
- reduce, decrease (memory/latency/size)
- cache, index, batch
→ Classification: OPTIMIZATION

REFACTOR INDICATORS:
- refactor, cleanup, reorganize, restructure
- extract, consolidate, simplify
- technical debt, code quality
→ Classification: REFACTOR

PHASE INDICATORS:
- phase <number>, phase-<number>
- implement phase, phase work
- roadmap phase
→ Classification: PHASE_WORK

TEST INDICATORS:
- test, verify, validate, check
- ensure, confirm
→ Classification: TEST
```

**Determine primary classification:**
```
task_type = <highest confidence classification>
confidence = 0.0-1.0
```

### 2.2 Scope Detection

**Search codebase for affected systems:**

```bash
# Extract technical keywords (ignore common words)
keywords=$(echo "$reconstructed_task" | grep -oE '\b[A-Za-z]{4,}\b' | tr '[:upper:]' '[:lower:]' | sort -u)

# Search backend
backend_matches=$(echo "$keywords" | xargs -I {} grep -r -l {} backend/app/ 2>/dev/null | wc -l)

# Search iOS (if applicable)
ios_matches=$(echo "$keywords" | xargs -I {} grep -r -l {} SydneyTransit/ 2>/dev/null | wc -l)

# Determine layers
if [ $backend_matches -gt 0 ] && [ $ios_matches -gt 0 ]; then
  layers="backend,ios"
elif [ $backend_matches -gt 0 ]; then
  layers="backend"
elif [ $ios_matches -gt 0 ]; then
  layers="ios"
else
  layers="unknown"
fi

# Count affected files
total_files=$((backend_matches + ios_matches))
```

### 2.3 Complexity Scoring

**Calculate complexity score (1-10):**

```
Factors:
1. Number of affected files:
   - <3 files: +1
   - 3-8 files: +3
   - >8 files: +5

2. Number of layers:
   - 1 layer: +1
   - 2 layers: +3
   - 3+ layers: +5

3. Task type complexity:
   - BUG_FIX: +1
   - OPTIMIZATION: +2
   - FEATURE: +3
   - REFACTOR: +4

4. New patterns required:
   - Existing patterns only: +0
   - Minor new patterns: +2
   - Major new architecture: +4

Complexity score = sum of factors
Complexity level:
- 1-3: simple
- 4-6: medium
- 7-10: complex
```

### 2.4 Check Existing Artifacts

**Look for existing plans/work:**

```bash
# Check for existing custom plan with similar name
plan_slug=$(echo "$reconstructed_task" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-60)

if [ -f "specs/${plan_slug}-plan.md" ]; then
  existing_plan="specs/${plan_slug}-plan.md"
  plan_status="exists"
else
  existing_plan=""
  plan_status="none"
fi

# Check for phase work
if [[ "$reconstructed_task" =~ [Pp]hase[[:space:]]+([0-9]+) ]]; then
  phase_number="${BASH_REMATCH[1]}"
  if [ -f "oracle/phases/PHASE_${phase_number}_*.md" ]; then
    phase_spec="exists"
  else
    phase_spec="missing"
  fi
else
  phase_number=""
  phase_spec="n/a"
fi
```

---

## Stage 3: Route to Workflow

**Purpose:** Determine which command(s) to execute automatically.

### 3.1 Decision Tree

```
IF task_type == "PHASE_WORK" AND phase_spec == "exists":
  workflow = "phase"
  commands = ["/plan-phase ${phase_number}", "/implement-phase ${phase_number}", "/test all"]

ELSE IF task_type == "BUG_FIX":
  workflow = "bug"
  commands = ["/bug \"${reconstructed_task}\""]

ELSE IF task_type == "TEST":
  workflow = "test"
  commands = ["/test all"]

ELSE IF existing_plan AND plan_status == "exists":
  workflow = "implement_existing"
  commands = ["/implement ${plan_slug}", "/test validation"]

ELSE IF task_type IN ["FEATURE", "OPTIMIZATION", "REFACTOR"]:
  workflow = "plan_implement"
  commands = ["/plan \"${reconstructed_task}\"", "/implement ${plan_slug}", "/test all"]

ELSE:
  workflow = "unknown"
  # Ask user for clarification
```

### 3.2 Ambiguity Check

**Determine if user confirmation needed:**

```
ask_user = false

IF confidence < 0.70:
  ask_user = true
  reason = "Low confidence in task understanding"

IF complexity_level == "complex" AND destructive_potential:
  ask_user = true
  reason = "High-risk operation requires confirmation"

IF workflow == "unknown":
  ask_user = true
  reason = "Cannot determine appropriate workflow"

IF multiple_valid_interpretations:
  ask_user = true
  reason = "Task description ambiguous, multiple interpretations possible"
```

**Destructive potential check:**
```
Destructive indicators:
- delete, drop, remove, truncate (on database/tables)
- refactor, migrate (large scale)
- schema change, breaking change
```

---

## Stage 4: Execute Workflow (Autonomous)

**Purpose:** Automatically invoke appropriate commands without asking user (unless ambiguous).

### 4.1 If User Confirmation Not Needed

**Execute workflow automatically:**

**Step 1: Report analysis to user:**
```
Task Analysis:
- Input: {raw input}
- Reconstructed: {reconstructed_task}
- Type: {task_type}
- Scope: {total_files} files across {layers}
- Complexity: {complexity_level} ({complexity_score}/10)

Workflow Selected: {workflow}
- Commands: {commands to execute}
- Reasoning: {why this workflow}

Executing automatically...
```

**Step 2: Execute commands sequentially using SlashCommand tool:**

**CRITICAL: You MUST use the SlashCommand tool to invoke each command. Do NOT execute the work yourself.**

```
FOR EACH command IN commands:

  Report to user: "→ Running: {command}"

  # INVOKE THE COMMAND USING SlashCommand TOOL
  SlashCommand tool:
  - command: "{command}"

  # Wait for command to complete and return result
  # The command will do all the work (planning, implementation, testing, etc.)

  # Check if command succeeded
  IF command returned error or failure status:
    Report to user:
    "❌ Command failed: {command}

    Error: {error details}

    Stopping workflow execution.

    Recommendation: {how to fix or next steps}"

    STOP execution (do not continue to next command)

  ELSE:
    Report to user:
    "✅ Command completed: {command}

    Result: {brief summary of what command did}"

    Continue to next command

ENDFOR

# After all commands complete successfully:
Report to user:
"✅ Workflow Complete

Commands executed:
{list all commands with checkmarks}

Overall result:
{aggregate summary of what was accomplished}

Next steps:
{if all passed: 'Ready to merge to main'}
{if any issues: 'Review outputs and address issues'}"
```

**Examples of correct SlashCommand invocation:**

```
# Example 1: Bug workflow
SlashCommand tool:
- command: "/bug \"Fix memory leak in Celery alert matcher task\""

# Example 2: Plan + Implement + Test workflow
# Command 1:
SlashCommand tool:
- command: "/plan \"Implement Redis caching layer for GTFS patterns\""

# (wait for /plan to complete, then:)
# Command 2:
SlashCommand tool:
- command: "/implement redis-caching-gtfs-patterns"

# (wait for /implement to complete, then:)
# Command 3:
SlashCommand tool:
- command: "/test all"

# Example 3: Phase workflow
SlashCommand tool:
- command: "/plan-phase 2"

# (wait for completion, then:)
SlashCommand tool:
- command: "/implement-phase 2"

# (wait for completion, then:)
SlashCommand tool:
- command: "/test all"
```

### 4.2 If User Confirmation Needed

**Ask user before executing:**

```
Report to user:
---
Task Analysis:
- Input: {raw input}
- Reconstructed: {reconstructed_task}
- Type: {task_type}
- Scope: {total_files} files across {layers}
- Complexity: {complexity_level} ({complexity_score}/10)

⚠️ Confirmation Required
Reason: {reason for asking}

Recommended Workflow: {workflow}
- Commands: {commands to execute}
- Reasoning: {why this workflow}

Alternative Options:
1. {alternative workflow 1 if applicable}
2. {alternative workflow 2 if applicable}
3. Manual workflow (you specify commands)
4. Refine task description

Please confirm:
- Execute recommended workflow? (yes/no)
- OR specify alternative/manual commands
- OR provide clarification
---

Wait for user response

IF user confirms:
  # Execute workflow using SlashCommand tool (same as 4.1)
  # Invoke each command in sequence using SlashCommand tool

ELSE IF user specifies alternative commands:
  # Execute user-specified commands using SlashCommand tool
  FOR EACH command IN user_specified_commands:
    SlashCommand tool:
    - command: "{command}"

ELSE IF user provides clarification:
  # Re-run Stage 1-3 with clarified input
  # Start over from task understanding with new information

ELSE:
  STOP, wait for further instructions
```

**CRITICAL REMINDER: When user confirms or specifies commands, you MUST use SlashCommand tool to invoke them. Do NOT do the work yourself.**

---

## Stage 5: Report Completion

**Provide comprehensive summary:**

```markdown
# Workflow Execution Report

**Task:** {reconstructed_task}
**Original Input:** {raw input}

---

## Analysis

**Classification:**
- Type: {task_type}
- Complexity: {complexity_level} ({complexity_score}/10)
- Scope: {total_files} files, {layers} layers
- Confidence: {confidence}

**Workflow Selected:** {workflow}

**Commands Executed:**
{list commands with timestamps}

---

## Results

### Command 1: {command}
- Status: {✅ Success | ❌ Failed}
- Duration: {duration}
- Output: {summary}
- Details: {link to detailed output}

### Command 2: {command}
- Status: {✅ Success | ❌ Failed}
- Duration: {duration}
- Output: {summary}
- Details: {link to detailed output}

---

## Overall Status

{✅ Workflow completed successfully}
{❌ Workflow failed at: {command}}

**Artifacts Created:**
- Plans: {list plan files}
- Commits: {list git commits}
- Test reports: {list test reports}
- Other: {list other artifacts}

---

## Next Steps

{If success}
✅ Implementation complete
- Review commits: {git log commands}
- Merge to main: git merge {branch}
- Close task

{If failure}
❌ Workflow incomplete
- Failed at: {command}
- Error: {error description}
- Recommendation: {how to fix}
- Retry: /workflow "{task}" (after fixing blocker)

---

**Total Duration:** {duration}
**Workflow Log:** /tmp/workflow-analysis.txt
```

---

## Examples

### Example 1: Bug Fix (Autonomous)

```
User: "celery alert matcher uses too much memory"

Workflow analysis:
- Reconstructed: "Fix memory leak in Celery alert matcher task"
- Type: BUG_FIX (confidence: 0.95)
- Scope: 3 backend files (backend/app/tasks/)
- Complexity: medium (5/10)
- Workflow: bug
- Ambiguity: No

Autonomous execution:
→ /bug "Fix memory leak in Celery alert matcher task"
  → 4-stage diagnosis
  → Root cause: Query loads all rows
  → Fix: Add LIMIT 1000 + pagination
  → Commit: abc123

✅ Complete (12 minutes)
```

### Example 2: Feature (Autonomous)

```
User: "add cache for route patterns"

Workflow analysis:
- Reconstructed: "Implement Redis caching layer for GTFS route pattern queries"
- Type: FEATURE (confidence: 0.88)
- Scope: 5 backend files
- Complexity: medium (6/10)
- Workflow: plan_implement
- Ambiguity: No

Autonomous execution:
→ /plan "Implement Redis caching layer for GTFS route pattern queries"
  → Exploration + planning
  → Plan: specs/redis-caching-route-patterns-plan.md

→ /implement redis-caching-route-patterns
  → 3 checkpoints executed
  → Commits: abc123, def456, ghi789

→ /test all
  → Backend: 12/12 passed
  → Validation: 3/3 passed

✅ Complete (45 minutes)
```

### Example 3: Phase Work (Autonomous)

```
User: "implement phase 2"

Workflow analysis:
- Reconstructed: "Implement Phase 2 from implementation roadmap"
- Type: PHASE_WORK (confidence: 1.0)
- Phase: 2 (oracle/phases/PHASE_2_*.md exists)
- Complexity: complex (8/10)
- Workflow: phase
- Ambiguity: No

Autonomous execution:
→ /plan-phase 2
  → Reads oracle spec
  → Exploration + iOS research
  → Plan: specs/phase-2-implementation-plan.md

→ /implement-phase 2
  → 5 checkpoints executed
  → Commits: abc123, def456, ghi789, jkl012, mno345

→ /test all
  → Backend: 24/24 passed
  → Validation: 5/5 passed

✅ Complete (3 hours)
```

### Example 4: Ambiguous (Ask User)

```
User: "make it faster"

Workflow analysis:
- Reconstructed: "Optimize application performance" (unclear target)
- Type: OPTIMIZATION (confidence: 0.60)
- Scope: Unknown (no specific keywords)
- Complexity: unknown
- Workflow: unknown
- Ambiguity: YES (low confidence + unclear scope)

⚠️ Confirmation required:

Task description "make it faster" is too vague.

Please clarify:
1. What needs to be faster?
   - Backend API response times?
   - iOS app UI rendering?
   - Database query performance?
   - GTFS data loading?

2. Current performance issue?
   - Specific slow operation or page?
   - Performance measurements?

3. Target performance?
   - Response time target?
   - Acceptable latency?

Once clarified, I'll analyze and execute the appropriate workflow.
```

---

## Notes

**Autonomous Execution:**
- Executes automatically unless ambiguous or high-risk
- No user confirmation needed for clear, low-risk tasks
- Reduces friction, increases speed

**User Confirmation Triggers:**
- Confidence <70% on task understanding
- Destructive operations (DB schema changes, deletes)
- Complex tasks with multiple valid interpretations
- Cannot determine workflow

**Workflow Types:**
- `phase`: /plan-phase → /implement-phase → /test
- `bug`: /bug (4-stage diagnosis + fix)
- `plan_implement`: /plan → /implement → /test
- `test`: /test all
- `implement_existing`: /implement (skip planning)

**Intelligence:**
- Reconstructs poor phrasing
- Infers missing context
- Searches codebase for scope
- Calculates complexity
- Routes to optimal workflow
- Executes end-to-end

**Safety:**
- Asks before destructive operations
- Stops on failures
- Provides clear error messages
- Recommends next steps
