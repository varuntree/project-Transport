# Consult Oracle

Pack relevant codebase context and generate consultation files for external AI model review. Auto-explores repo, intelligently packs code under 35k tokens, creates instructions.

## Variables

task: $1 (required: high-level task description for Oracle - e.g., "fix real-time poller memory leak", "plan push notifications feature")

## Instructions

**Goal:** Generate two files for external Oracle consultation:
1. `oracle-context-{timestamp}.txt` - Packed code with tree structure (<35k tokens)
2. `oracle-instructions-{timestamp}.md` - Detailed task brief with response format

---

## Stage 1: Initialize Session

```bash
timestamp=$(date +%s)
task_slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-50)
oracle_dir=".claude-logs/oracle"
mkdir -p "${oracle_dir}"
```

---

## Stage 2: Understand Task & Discover Files

### 2.1 Parse Task Intent

Identify:
- Bug fix / feature planning / refactor / architecture review?
- Which domains affected?
  - Backend API (FastAPI routes, services, tasks)
  - iOS App (SwiftUI, ViewModels, repositories)
  - Data layer (GTFS pipeline, DB schema, Celery)
  - Infrastructure (Redis, Supabase, deployment)
  - Documentation (specs, standards)

### 2.2 Read Documentation

- docs/architecture/SYSTEM_OVERVIEW.md
- docs/standards/DEVELOPMENT_STANDARDS.md
- Based on task, read relevant:
  - docs/architecture/BACKEND_SPECIFICATION.md
  - docs/architecture/IOS_APP_SPECIFICATION.md
  - docs/architecture/DATA_ARCHITECTURE.md
  - docs/architecture/INTEGRATION_CONTRACTS.md

### 2.3 Discover Relevant Files

Based on task description:
1. Find files related to task keywords
2. Read existing implementations
3. Trace imports/dependencies
4. Include relevant specs

**Rank by relevance:**
- Keyword matches in file content
- Recently changed (git)
- Import depth
- Exclude: tests, archives, generated files

**No tool prescription - discover naturally.**

---

## Stage 3: Pack Context (<35k tokens)

### 3.1 Generate Tree Structure

Create repo tree showing structure and file sizes:

```
prj_transport/
├── backend/
│   ├── app/
│   │   ├── api/v1/gtfs.py (245 lines)
│   │   ├── services/gtfs_service.py (410 lines)
│   │   └── tasks/gtfs_rt_poller.py (180 lines)
│   └── requirements.txt
├── SydneyTransit/
│   └── Features/Departures/...
└── docs/
    ├── architecture/BACKEND_SPECIFICATION.md
    └── standards/DEVELOPMENT_STANDARDS.md
```

### 3.2 Pack Files

**Strategy:**
1. Start with highest-ranked files (full content)
2. Track token estimate: `tokens ≈ file_size_bytes / 3.5`
3. When approaching 30k tokens:
   - Switch to function signatures for remaining files
   - Or drop lowest-ranked files

4. Log exclusions if any

### 3.3 Write Context File

`.claude-logs/oracle/oracle-context-{timestamp}-{task_slug}.txt`:

```
# Oracle Context: {task}
# Session: {timestamp}-{task_slug}
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

---

## Stage 4: Generate Oracle Instructions

Write `.claude-logs/oracle/oracle-instructions-{timestamp}-{task_slug}.md`:

```markdown
# Oracle Consultation: {task}

**Session ID:** {timestamp}-{task_slug}
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
- Branch: {current branch}
- Recent: {git log --oneline -5}

**Key Constraints:**
- Solo dev, budget $25/mo MVP (0-1K users)
- App size <50MB, offline-first
- NSW API: 5 req/s limit, 60K calls/day
- Stack fixed (no new services)

**Architecture Docs:**
- SYSTEM_OVERVIEW.md
- DATA_ARCHITECTURE.md
- BACKEND_SPECIFICATION.md
- IOS_APP_SPECIFICATION.md
- INTEGRATION_CONTRACTS.md
- DEVELOPMENT_STANDARDS.md

---

## Your Task (Oracle)

Given task and codebase context in `oracle-context-{timestamp}-{task_slug}.txt`, provide:

### 1. Analysis
- Patterns/issues/bugs identified?
- Current implementation assessment?
- Relevant architecture from specs?

### 2. Recommendations
- Specific approach/solution (concrete, not abstract)
- Why this over alternatives?
- How aligns with constraints (budget, solo dev, simplicity)?

### 3. Implementation Plan
- Step-by-step breakdown (vertical slicing preferred)
- Which files to modify/create (reference file:line)
- Database migrations needed?
- API contract changes?

### 4. Code Examples
- Concrete snippets for critical parts
- Follow DEVELOPMENT_STANDARDS.md patterns:
  - Backend: structlog JSON, Celery decorators, Pydantic models
  - iOS: @MainActor ViewModels, protocol repositories
  - API: Envelope `{"data": {...}, "meta": {...}}`

### 5. Edge Cases & Risks
**CRITICAL:** Identify:
- Edge cases (DST, rate limits, offline, etc.)
- Potential regressions (dependencies, API contracts)
- Blast radius (features affected, compatibility)
- Cost implications (API calls, storage, compute)
- Testing strategy (acceptance criteria)

### 6. Trade-offs
- Pros/cons of approach
- Optimizing for? (speed vs cost vs simplicity)
- NOT solving? (out of scope, future work)

---

## Response Format

Markdown with sections above. Reference code:
- `backend/app/services/gtfs_service.py:45`
- Inline code blocks with language tags
- Clear headings (`##`)

**Tone:** Technical, concise, solo-dev-friendly. No fluff.

---

## Codebase Context

See: `.claude-logs/oracle/oracle-context-{timestamp}-{task_slug}.txt` ({token_count} tokens)
```

---

## Stage 5: Output Summary

```
✅ Oracle consultation files generated:

Context: .claude-logs/oracle/oracle-context-{timestamp}-{task_slug}.txt
Instructions: .claude-logs/oracle/oracle-instructions-{timestamp}-{task_slug}.md

Token estimate: ~{token_count} tokens
Files included: {file_count}

Next steps:
1. Copy both files to external Oracle (ChatGPT, Claude Web, etc.)
2. Paste oracle-context content first
3. Paste oracle-instructions as follow-up
4. Review Oracle's response and implement
```

---

## Notes

- No subagents - orchestrator packs context directly
- Natural file discovery (no grep prescription)
- Intelligent ranking and packing
- <35k token hard limit
- Excludes tests, archives, generated files
- Single folder: .claude-logs/oracle/
