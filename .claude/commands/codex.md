# Delegate to Codex CLI (Executive Mode)

Delegate tasks to Codex CLI (`codex exec`) for autonomous, non-interactive execution. Packages context, invokes Codex with full automation, captures results.

## ⚠️ IMPORTANT: Pre-Execution Reminders for Claude

**Before executing this command, remember:**
1. ✅ **Codex CLI is already installed** on this system - do NOT ask the user about installation
2. ✅ **Always run in background** - Codex exec will complete on its own, no timeout monitoring needed
3. ✅ **Continuous logs are captured** - outputs to `.workflow-logs/active/codex/{session}/live-log.jsonl` in real-time
4. ✅ **Format is JSONL** - newline-delimited JSON events with syntax highlighting for readability
5. ✅ **Let it finish** - Codex will exit when done, you can monitor with BashOutput tool

## Usage

```
/codex "run review command for recent changes"
/codex "implement fix from bug diagnosis report"
/codex "update BACKEND_SPECIFICATION with new endpoints"
/codex --yolo "run full test suite and fix failures"
```

## Variables

task: $1 (required: task description for Codex to execute)
flags: $2+ (optional: --yolo, --json, --sandbox, etc.)

## Instructions

**IMPORTANT: Think hard. Package complete context for autonomous execution.**

---

## Stage 1: Parse Task & Gather Context

### 1.1 Initialize Session

```bash
timestamp=$(date +%s)
task_slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-50)
codex_session_id="${timestamp}-${task_slug}"
codex_dir=".workflow-logs/active/codex/${codex_session_id}"
mkdir -p "${codex_dir}"

echo "🤖 Codex CLI Delegation Session: ${codex_session_id}"
echo "📋 Task: $1"
echo ""

# Parse flags
use_yolo=false
use_json=false
sandbox_mode="workspace-write"

for arg in "$@"; do
  case "$arg" in
    --yolo|--dangerously-bypass-approvals-and-sandbox)
      use_yolo=true
      ;;
    --json)
      use_json=true
      ;;
    --sandbox)
      shift
      sandbox_mode="$1"
      ;;
  esac
done
```

### 1.2 Auto-Detect Relevant Context

**Analyze task keywords to determine what context to include:**

```bash
# Extract keywords from task
task_lower=$(echo "$1" | tr '[:upper:]' '[:lower:]')

# Determine context needs
include_review_cmd=false
include_implement_cmd=false
include_test_cmd=false
include_bug_cmd=false
include_plan_cmd=false

if [[ "$task_lower" =~ review ]]; then
  include_review_cmd=true
fi

if [[ "$task_lower" =~ implement|implementation ]]; then
  include_implement_cmd=true
fi

if [[ "$task_lower" =~ test|testing ]]; then
  include_test_cmd=true
fi

if [[ "$task_lower" =~ bug|fix|diagnosis ]]; then
  include_bug_cmd=true
fi

if [[ "$task_lower" =~ plan|planning ]]; then
  include_plan_cmd=true
fi
```

### 1.3 Gather Files

**Collect relevant context based on task analysis:**

```bash
# Always include
context_files=(
  "CLAUDE.md"
  "STRUCTURE.md"
  "docs/standards/DEVELOPMENT_STANDARDS.md"
  "docs/architecture/SYSTEM_OVERVIEW.md"
)

# Add architecture specs based on keywords
if [[ "$task_lower" =~ backend|api|celery|task ]]; then
  context_files+=("docs/architecture/BACKEND_SPECIFICATION.md")
fi

if [[ "$task_lower" =~ ios|swift|swiftui|app ]]; then
  context_files+=("docs/architecture/IOS_APP_SPECIFICATION.md")
fi

if [[ "$task_lower" =~ gtfs|data|database|pattern ]]; then
  context_files+=("docs/architecture/DATA_ARCHITECTURE.md")
fi

if [[ "$task_lower" =~ api.*contract|auth|apns|push ]]; then
  context_files+=("docs/architecture/INTEGRATION_CONTRACTS.md")
fi

# Add slash command docs if task mentions them
if [ "$include_review_cmd" = true ]; then
  context_files+=(".claude/commands/review.md")
fi

if [ "$include_implement_cmd" = true ]; then
  context_files+=(".claude/commands/implement.md")
  context_files+=(".claude/commands/implement-phase.md")
fi

if [ "$include_test_cmd" = true ]; then
  context_files+=(".claude/commands/test.md")
fi

if [ "$include_bug_cmd" = true ]; then
  context_files+=(".claude/commands/bug.md")
  context_files+=(".claude/commands/fix-bug.md")
fi

if [ "$include_plan_cmd" = true ]; then
  context_files+=(".claude/commands/plan.md")
  context_files+=(".claude/commands/plan-phase.md")
fi

# Add recent changes
git_status=$(git status --short)
recent_commits=$(git log --oneline -5)

# Add task-specific files (if mentioned)
# Example: "fix bug in backend/app/api/v1/stops.py"
if [[ "$task_lower" =~ (backend|ios|specs)/[a-zA-Z0-9/_.-]+ ]]; then
  # Extract file path from task description
  mentioned_files=$(echo "$task_lower" | grep -oE '(backend|SydneyTransit|specs)/[a-zA-Z0-9/_.-]+')
  for file in $mentioned_files; do
    if [ -f "$file" ]; then
      context_files+=("$file")
    fi
  done
fi
```

---

## Stage 2: Build Codex Prompt

### 2.1 Generate Prompt

```bash
prompt_file="${codex_dir}/prompt.md"

cat > "${prompt_file}" << 'PROMPT_EOF'
# Task: {task description}

## Project Context

**Project:** Sydney Transit App (iOS + FastAPI Backend)

**Tech Stack:**
- Backend: FastAPI + Celery (3 queues: critical/normal/batch), Supabase PostgreSQL, Redis (GTFS-RT cache)
- iOS: Swift/SwiftUI (iOS 16+), GRDB (15-20MB bundled GTFS), Supabase Auth
- Data: NSW Transport GTFS (227MB static, GTFS-RT 30s polling)

**Key Constraints:**
- Solo dev, budget $25/mo MVP (0-1K users), maximize free tiers
- App size <50MB download, offline-first
- NSW API: 5 req/s limit, 60K calls/day
- Stack fixed (no new services beyond planned)

**Current Status:**
- Branch: {current_branch}
- Recent commits:
{recent_commits}

- Changed files:
{git_status}

---

## Available Slash Commands

You have access to these orchestrator commands (invoke via shell):

**Planning:**
- `.claude/commands/plan-phase` {N} - Create phase implementation plan
- `.claude/commands/plan` "{task}" - Create custom task plan

**Execution:**
- `.claude/commands/implement-phase` {N} - Execute phase via checkpoints
- `.claude/commands/implement` {plan-name} - Execute custom plan

**Quality:**
- `.claude/commands/review` [scope] - Multi-panel review (5 specialized agents)
- `.claude/commands/test` {backend|validation|all} - Run test suites

**Bug Handling:**
- `.claude/commands/bug` "{description}" - 4-stage diagnosis + fix
- `.claude/commands/fix-bug` {phase} {checkpoint} {type} - Fix validation failures

**Orchestration:**
- `.claude/commands/workflow` "{task}" - Auto-route to appropriate workflow

**NOTE:** These are the actual file paths where slash commands are defined. When instructing Codex to invoke them, use these full paths.

{if any slash commands included in context}
## Slash Command Documentation

{include full .claude/commands/*.md files for commands mentioned in task}

{end if}

---

## Repository Structure

{tree output - condensed to 2 levels}

---

## Relevant Files

{include content of context_files array}

---

## Standards & Patterns

**From docs/standards/DEVELOPMENT_STANDARDS.md:**

{include key sections: Logging (structlog JSON), Error Handling, API Envelope, Celery patterns, iOS patterns}

---

## Your Task

{user's task description - verbatim}

**Execution Guidelines:**

1. You are running in **Codex CLI executive mode** (non-interactive, autonomous)
2. You can:
   - Use any slash commands via FULL PATHS: `.claude/commands/review`, `.claude/commands/test`, etc.
   - Slash commands are markdown files, NOT executables - use full relative paths
   - Read/write files as needed
   - Run git commands (status, diff, log - but **NEVER commit/push**)
   - Execute tests, validations
   - Make decisions without asking (you're autonomous)

3. You MUST follow:
   - docs/standards/DEVELOPMENT_STANDARDS.md patterns (logging, error handling, naming)
   - Architecture specs (read relevant specs from context above)
   - Project constraints (budget, offline-first, solo dev)

4. You MUST NOT:
   - Commit to git (orchestrator handles)
   - Push to remote
   - Install new services/dependencies (stack is fixed)
   - Skip validation/testing
   - Use `/review` syntax - use `.claude/commands/review` instead

**Expected Output:**

Return structured report in your final message:

```markdown
# Codex Execution Report: {task}

## Summary
{1-2 sentence summary of what you did}

## Actions Taken
1. {Action 1 - be specific}
2. {Action 2}
3. ...

## Commands Executed
```bash
{list all bash/shell commands you ran}
```

## Files Modified
- Created: {list}
- Modified: {list}
- Deleted: {list}

## Validation
{Did you run tests? What was the result?}
{Did you run validation commands? Pass/fail?}

## Findings
{Any issues discovered, recommendations, next steps}

## Ready for Review
{Yes/No - explain why}
```

**Confidence Check:**
- Am I 80%+ confident in this approach?
- For iOS work: Do I have Apple docs references? (Don't hallucinate iOS APIs)
- For external services: Did I check documentation?
- If confidence <80%: Research first using available tools

---

**Context Summary:**
- Architecture specs: {count} files
- Slash commands: {count} files
- Code files: {count} files
- Total context: ~{token_estimate}K tokens

**Execution Mode:** {full-auto|yolo|read-only}

PROMPT_EOF

# Replace placeholders in prompt
sed -i '' "s|{task description}|$1|g" "${prompt_file}"
sed -i '' "s|{current_branch}|$(git rev-parse --abbrev-ref HEAD)|g" "${prompt_file}"
sed -i '' "s|{recent_commits}|${recent_commits}|g" "${prompt_file}"
sed -i '' "s|{git_status}|${git_status}|g" "${prompt_file}"
# ... (additional sed replacements for context files, tree, etc.)
```

---

## Stage 3: Invoke Codex Executive Mode

### 3.1 Construct Command

```bash
# Determine flags
if [ "$use_yolo" = true ]; then
  exec_flags="--yolo"
  exec_mode="yolo"
else
  exec_flags="--full-auto"
  exec_mode="full-auto"
fi

# Always use --json for structured output with syntax highlighting
exec_flags="${exec_flags} --json"

if [ "$sandbox_mode" != "workspace-write" ]; then
  exec_flags="${exec_flags} --sandbox ${sandbox_mode}"
fi

output_file="${codex_dir}/codex-output.md"

echo "🚀 Invoking Codex CLI..."
echo "   Mode: ${exec_mode}"
echo "   Flags: ${exec_flags}"
echo "   Prompt: ${prompt_file}"
echo "   Output: ${output_file}"
echo ""
```

### 3.2 Execute Codex

```bash
# Prepare live log file for continuous streaming (JSONL format)
live_log="${codex_dir}/live-log.jsonl"

# Invoke Codex CLI with continuous log capture
# --json outputs newline-delimited JSON events (JSONL)
# 2>&1 redirects stderr to stdout, | tee captures to file while displaying
codex exec \
  ${exec_flags} \
  --cd /Users/varunprasad/code/prjs/prj_transport \
  --output-last-message "${output_file}" \
  "$(cat ${prompt_file})" \
  2>&1 | tee "${live_log}"

codex_exit_code=${PIPESTATUS[0]}

# Capture session ID if available
# (Codex may print session ID to stderr/stdout)

echo ""
echo "📝 Live log saved to: ${live_log}"
echo "   (JSONL format - newline-delimited JSON with syntax highlighting)"
echo "   Open in code editor for syntax highlighting"
```

---

## Stage 4: Capture & Report Results

### 4.1 Save Metadata

```bash
echo "{
  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"task\": \"$1\",
  \"session_id\": \"${codex_session_id}\",
  \"execution_mode\": \"${exec_mode}\",
  \"flags_used\": \"${exec_flags}\",
  \"exit_code\": ${codex_exit_code},
  \"output_file\": \"${output_file}\",
  \"prompt_file\": \"${prompt_file}\",
  \"live_log\": \"${live_log}\"
}" > "${codex_dir}/metadata.json"
```

### 4.2 Update Workflow Logs Index

```bash
# Add to .workflow-logs/INDEX.json
jq --arg id "${codex_session_id}" \
   --arg task "$1" \
   --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "$( [ ${codex_exit_code} -eq 0 ] && echo 'success' || echo 'failed' )" \
   --arg location "active/codex/${codex_session_id}" \
   '.sessions.codex += [{
     "id": $id,
     "task": $task,
     "timestamp": $timestamp,
     "status": $status,
     "location": $location
   }] | .stats.total_codex_sessions += 1' \
   .workflow-logs/INDEX.json > .workflow-logs/INDEX.json.tmp && \
   mv .workflow-logs/INDEX.json.tmp .workflow-logs/INDEX.json
```

### 4.3 Display Results

```bash
echo ""
echo "─────────────────────────────────────────────────"
echo "Codex Execution Complete"
echo "─────────────────────────────────────────────────"
echo ""

# Show Codex's final message
cat "${output_file}"

echo ""
echo "─────────────────────────────────────────────────"
echo "Session: ${codex_session_id}"
echo "Exit Code: ${codex_exit_code}"
echo ""
echo "📁 Session Files:"
echo "   Prompt: ${prompt_file}"
echo "   Output: ${output_file}"
echo "   Live Log: ${live_log}"
echo "   Metadata: ${codex_dir}/metadata.json"
echo ""

if [ ${codex_exit_code} -eq 0 ]; then
  echo "✅ Codex completed successfully"
else
  echo "❌ Codex failed (exit code: ${codex_exit_code})"
  echo "   Review output above for details"
fi

echo ""
echo "Next Steps:"
echo "1. Review Codex's report above"
echo "2. Verify changes: git diff"
echo "3. Run validation: /test all"
echo "4. If needed: /review to assess quality"
echo ""
```

---

## Resume Support

**To resume a Codex session:**

```bash
# Resume last session
codex exec resume --last

# Resume specific session
codex exec resume {codex-session-id}
```

**Note:** Resume capability depends on Codex CLI session persistence.

---

## Notes

**Safety Tiers:**

```bash
# Tier 1: Safe (default)
/codex "task"
→ Uses --full-auto (workspace-write sandbox, approvals on failure)

# Tier 2: Dangerous (explicit)
/codex --yolo "task"
→ Uses --yolo (no approvals, full access)

# Tier 3: Read-only (analysis)
/codex --sandbox read-only "task"
→ For review/analysis only
```

**Context Packaging:**
- Auto-detects relevant specs from task keywords
- Includes slash command docs if task mentions commands
- Targets <50K tokens (Codex context window)
- Prioritizes task-relevant files

**Continuous Logging:**
- All events captured to `live-log.jsonl` in real-time via `tee` + `--json`
- **JSONL format:** Newline-delimited JSON events (one JSON object per line)
- **Syntax highlighting:** Open in VS Code or any editor with JSON support
- Monitor progress: `tail -f .workflow-logs/active/codex/{session}/live-log.jsonl`
- Includes all commands executed, thinking blocks, file reads, errors as structured events
- Useful for debugging long-running executions with readable, highlighted output

**Integration with Slash Commands:**

Codex can invoke other slash commands using FULL PATHS:
```
/codex "run review and fix all P0 issues"
→ Codex executes: .claude/commands/review
→ Codex parses: review report
→ Codex implements: P0 fixes
→ Codex re-runs: .claude/commands/review to verify
→ Returns: Complete report
```

**IMPORTANT:** Slash commands are NOT executable binaries. They are markdown files in `.claude/commands/`. Codex must be instructed to use FULL PATHS when referencing them.

**Use Cases:**
- Autonomous workflows: `/codex "implement phase 2"`
- Fix + validate loops: `/codex "fix bug X and test"`
- Documentation updates: `/codex "update specs with new endpoints"`
- Full pipelines: `/codex --yolo "plan, implement, test feature X"`

**Risks & Mitigations:**
- **Risk:** Codex runs destructive commands
  - **Mitigation:** Default `--full-auto`, explicit `--yolo` required
  - **Mitigation:** Prompt forbids `git push`, `rm -rf`
- **Risk:** Context too large (>50K tokens)
  - **Mitigation:** Smart filtering based on task keywords
  - **Mitigation:** Compress large files if needed
- **Risk:** Codex hallucinates slash commands
  - **Mitigation:** Include actual command docs in context
  - **Mitigation:** Prompt lists ONLY available commands

**Success Criteria:**
- Context packaged <50K tokens
- Codex executes autonomously (no human intervention)
- Results captured to `.workflow-logs/active/codex/`
- Exit code indicates success/failure
- INDEX.json updated
- Safe by default (`--full-auto`), explicit opt-in for `--yolo`

---

**For full project structure, see `/STRUCTURE.md`**
