# Consult Oracle

Pack relevant codebase context and generate consultation files for external AI model review. Auto-explores repo, intelligently packs code under 35k tokens, creates instructions.

## Variables

task: $1 (required: high-level task description for Oracle - e.g., "fix real-time poller memory leak", "re-architect GTFS pipeline for better compression", "plan push notifications feature")

## Instructions

**Goal:** Generate two files in `.workflow-logs/exports/` for external Oracle consultation:
1. `oracle-context-{timestamp}.txt` - Packed code with tree structure (<35k tokens)
2. `oracle-instructions-{timestamp}.md` - Detailed task brief with response format

**Key principles:**
- Auto-detect relevant files via task analysis (no manual scope needed)
- Smart ranking: keyword relevance + git status + file size
- Compress intelligently: function signatures for large files if needed
- Never include test files, archives, or generated assets
- Ask Oracle about edge cases, regressions, dependencies, blast radius

---

## Execution Flow

### Step 1: Initialize Session

```bash
# Create timestamped session
timestamp=$(date +%s)
task_slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-50)
session_id="${timestamp}-${task_slug}"
output_dir="docs/oracle"
mkdir -p "${output_dir}"

echo "🔮 Oracle Consultation Session: ${session_id}"
echo "📋 Task: $1"
echo ""
```

### Step 2: Analyze Task & Discover Files

**Spawn Explore agent to:**
1. Parse task intent (bug fix / feature planning / refactor / architecture review)
2. Identify relevant domains:
   - Backend API (FastAPI routes, services, tasks)
   - iOS App (SwiftUI, ViewModels, repositories)
   - Data layer (GTFS pipeline, DB schema, Celery)
   - Infrastructure (Redis, Supabase, deployment)
   - Documentation (oracle specs, phase plans, standards)

3. Discover files via parallel search:
   - **Keyword grep**: Extract nouns/verbs from task (e.g., "real-time poller" → grep "poll", "gtfs_rt", "celery")
   - **Git context**: Include modified/staged files from `git status`
   - **Import graph**: For Python/Swift, trace imports of discovered files
   - **Specs**: Auto-include relevant `docs/architecture/*.md` if architecture-related

4. **Rank files by relevance score:**
   ```
   score = (keyword_matches * 3) + (recent_git_change * 2) + (import_depth_weight) - (file_size_penalty)
   ```
   - Exclude: `*test*.py`, `*Tests.swift`, `archive/`, `*.db`, `venv/`, `node_modules/`

### Step 3: Intelligent Code Packing (Target: <35k tokens)

**Strategy:**
1. **Generate tree structure** (repomix-style):
   ```
   prj_transport/
   ├── backend/
   │   ├── app/
   │   │   ├── api/v1/gtfs.py (245 lines)
   │   │   ├── services/gtfs_service.py (410 lines)
   │   │   └── tasks/gtfs_rt_poller.py (180 lines)
   │   └── requirements.txt
   ├── ios/
   │   └── SydneyTransit/Features/Departures/...
   └── oracle/
       ├── specs/BACKEND_SPECIFICATION.md
       └── DEVELOPMENT_STANDARDS.md
   ```

2. **Pack files in ranked order:**
   - Start with top-ranked files (full content)
   - Track token count using rough estimate: `tokens ≈ file_size_bytes / 3.5`
   - When approaching 30k tokens:
     - Switch to **function signature mode** for remaining files:
       ```python
       # Original large file
       def complex_function(params):
           # 150 lines of implementation
           pass

       # Compressed version
       def complex_function(params):
           """Docstring preserved"""
           ... # impl omitted, 150 lines
       ```
   - If still over 35k: Drop lowest-ranked files, log exclusions

3. **Write context file:**
   ```
   # Oracle Context: {task}
   # Session: {session_id}
   # Generated: {ISO timestamp}
   # Token estimate: {token_count}

   ## Repository Structure
   {tree_structure}

   ## File Contents

   ──────────────────────────────────────
   File: backend/app/services/gtfs_service.py
   ──────────────────────────────────────
   {file_content}

   ──────────────────────────────────────
   File: docs/architecture/BACKEND_SPECIFICATION.md
   ──────────────────────────────────────
   {file_content}

   [... more files ...]

   ## Excluded Files (if any)
   - path/to/file.py (reason: over token limit, rank #45)
   ```

### Step 4: Generate Oracle Instructions

**Create structured brief:**

```markdown
# Oracle Consultation: {task}

**Session ID:** {session_id}
**Generated:** {ISO timestamp}
**Project:** Sydney Transit App (iOS + FastAPI Backend)

---

## Task Description

{task from user input - verbatim}

---

## Project Context

**Tech Stack:**
- Backend: FastAPI + Celery (3 queues), Supabase PostgreSQL, Redis (GTFS-RT cache)
- iOS: Swift/SwiftUI, GRDB (15-20MB bundled GTFS), Supabase Auth
- Data: NSW Transport GTFS (227MB static, GTFS-RT 30s polling)

**Current Status:**
- Implementation Phase: {current git branch or "Phase 0 pending"}
- Recent Changes: {git log --oneline -5}

**Key Constraints:**
- Solo dev, budget $25/mo MVP (0-1K users)
- App size <50MB, offline-first
- NSW API: 5 req/s limit, 60K calls/day
- Stack fixed (no new services)

**Architecture Docs:** `docs/architecture/` (SYSTEM_OVERVIEW, DATA_ARCHITECTURE, BACKEND_SPECIFICATION, IOS_APP_SPECIFICATION, INTEGRATION_CONTRACTS), `docs/standards/DEVELOPMENT_STANDARDS.md`

---

## Your Task (Oracle)

Given the task description and codebase context in `oracle-context-{timestamp}.txt`, provide:

### 1. Analysis
- What patterns/issues/bugs did you identify?
- Current implementation assessment (if applicable)
- Relevant architecture from specs (reference which doc)

### 2. Recommendations
- Specific approach/solution (concrete, not abstract)
- Why this approach over alternatives?
- How does it align with project constraints (budget, solo dev, simplicity)?

### 3. Implementation Plan
- Step-by-step breakdown (vertical slicing preferred)
- Which files to modify/create (reference `file:line` from context)
- Database migrations needed (if applicable)
- API contract changes (if applicable)

### 4. Code Examples
- Concrete snippets for critical parts
- Follow DEVELOPMENT_STANDARDS.md patterns:
  - Backend: structlog JSON logging, Celery task decorators, Pydantic models
  - iOS: @MainActor ViewModels, protocol-based repositories
  - API: Envelope format `{"data": {...}, "meta": {...}}`

### 5. Edge Cases & Risks
**CRITICAL:** Identify:
- Edge cases to handle (DST transitions, rate limits, offline mode, etc.)
- Potential regressions (dependencies broken, API contracts changed)
- Blast radius (which features affected, backward compatibility)
- Cost implications (API calls, storage, compute)
- Testing strategy (acceptance criteria)

### 6. Trade-offs
- Pros/cons of your approach
- What you're optimizing for (speed vs cost vs simplicity)
- What you're NOT solving (out of scope, future work)

---

## Response Format

Markdown file with sections above. Reference code using:
- `backend/app/services/gtfs_service.py:45` (line numbers from context file)
- Inline code blocks with language tags
- Clear headings (use `##` for main sections)

**Tone:** Technical, concise, solo-dev-friendly. No fluff.

---

## Codebase Context

See: `.workflow-logs/exports/oracle-context-{timestamp}.txt` ({token_count} tokens)
```

### Step 5: Output & Summary

```bash
echo ""
echo "✅ Oracle consultation files generated:"
echo ""
echo "📦 Context:      .workflow-logs/exports/oracle-context-${timestamp}-${task_slug}.txt"
echo "📋 Instructions: .workflow-logs/exports/oracle-instructions-${timestamp}-${task_slug}.md"
echo ""
echo "Token estimate:  ~{token_count} tokens"
echo "Files included:  {file_count}"
echo ""
echo "Next steps:"
echo "1. Copy both files to external Oracle model (ChatGPT, Claude Web, etc.)"
echo "2. Paste oracle-context content first"
echo "3. Paste oracle-instructions as follow-up prompt"
echo "4. Review Oracle's response and implement recommendations"
echo ""
```

---

## Implementation Notes

**For the AI implementing this command:**

1. **Use Task tool with Explore agent** for Step 2 (file discovery)
   - Prompt: "Analyze task '{task}' and identify all relevant files in this Sydney Transit codebase. Rank by relevance. Exclude tests, archives, generated files."

2. **Token counting:**
   - Use rough estimate: `tokens = file_size_bytes / 3.5`
   - For accuracy: count actual words in packed content, multiply by 1.3

3. **Function signature extraction** (Python example):
   ```python
   import ast

   def compress_to_signatures(file_content):
       tree = ast.parse(file_content)
       # Extract class/function defs, preserve docstrings, replace bodies with "..."
       # Return compressed version
   ```

4. **Tree generation:**
   - Use `tree` command if available, else build manually from file paths
   - Show file sizes in lines (helps Oracle prioritize reading)

5. **Git context extraction:**
   ```bash
   git status --porcelain  # Modified files
   git log --oneline -5     # Recent commits
   git rev-parse --abbrev-ref HEAD  # Current branch
   ```

6. **Specs inclusion logic:**
   - Task mentions "architecture/design/specs" → include all `docs/architecture/*.md`
   - Task mentions specific domain → include relevant spec:
     - "backend/API/celery/tasks" → BACKEND_SPECIFICATION.md
     - "iOS/SwiftUI/app" → IOS_APP_SPECIFICATION.md
     - "GTFS/data/pipeline" → DATA_ARCHITECTURE.md
     - "push/notifications/APNs" → INTEGRATION_CONTRACTS.md
   - Always include: DEVELOPMENT_STANDARDS.md (patterns), SYSTEM_OVERVIEW.md (context)

7. **Error handling:**
   - If file discovery finds <5 files: Warn user, ask to refine task description
   - If token estimate >40k after compression: Show excluded files, ask user to narrow scope
   - If no git repo: Skip git context, proceed with file discovery only

---

## Example Usage

```bash
# Bug fix
/consult-oracle "Fix memory leak in GTFS-RT poller that causes Celery worker to crash after 6 hours"

# Feature planning
/consult-oracle "Design and plan push notifications system with quiet hours, 3-layer dedup, and SQL alert matching"

# Architecture review
/consult-oracle "Review current GTFS pipeline implementation and suggest optimizations for better compression and faster iOS bundling"

# Refactoring
/consult-oracle "Refactor DeparturesViewModel to handle infinite scroll pagination without race conditions"
```

---

## Success Criteria

- Context file <35k tokens (hard limit)
- All directly relevant files included (ranked top 20)
- Specs/docs included based on task domain
- Instructions file has clear task + response format + edge case requirements
- Output files ready to copy-paste to external model
- No test files, no archives, no generated assets
