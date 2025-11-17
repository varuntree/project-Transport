# AI Agent Workflow System

Complete guide to the AI agent workflow system for Sydney Transit App development.

---

## Overview

This project uses a composable AI agent system with **autonomous orchestration** for efficient software development lifecycle management.

**Core Principle:** Small, reusable command units that compose into complete workflows.

---

## Core Commands (Composable Units)

### 1. `/plan` - General Planning
**Purpose:** Create checkpoint-driven implementation plan for any task

**Usage:**
```
/plan "task description"
/plan "add caching layer for GTFS patterns"
/plan "optimize iOS route list performance"
```

**Output:**
- Plan file: `specs/{plan-name}-plan.md`
- Exploration report: `.workflow-logs/custom/{plan-name}/exploration-report.json`
- iOS research (if needed): `.workflow-logs/custom/{plan-name}/ios-research-*.md`

**Workflow:**
1. Exploration subagent (compress context)
2. Research subagent (iOS patterns if needed)
3. User questions (max 3 if ambiguous)
4. Create checkpoint-driven plan

---

### 2. `/implement` - General Implementation
**Purpose:** Execute any plan through orchestrator-subagent pattern

**Usage:**
```
/implement {plan-name}
/implement redis-caching-route-patterns
/implement ios-route-performance
```

**Output:**
- Code changes + commits
- Checkpoint results: `.workflow-logs/custom/{plan-name}/checkpoint-{N}-result.json`
- Completion report: `.workflow-logs/custom/{plan-name}/completion-report.json`

**Workflow:**
1. Load plan + exploration context
2. Design all checkpoints upfront
3. Execute checkpoints (delegate to subagents)
4. Validate independently
5. Commit atomically per checkpoint

---

### 3. `/test` - Testing Workflow
**Purpose:** Run tests to validate implementation

**Usage:**
```
/test backend      # Backend unit tests only
/test validation   # Validation commands from plan
/test all          # Both
```

**Output:**
- Test report: `.workflow-logs/tests/{timestamp}/REPORT.md`
- Backend results: `.workflow-logs/tests/{timestamp}/backend-results.json`
- Validation results: `.workflow-logs/tests/{timestamp}/validation-results.json`

**Workflow:**
1. Detect changed files (git diff)
2. Run appropriate tests (pytest backend, validation commands)
3. Generate pass/fail report

---

### 4. `/workflow` - Autonomous Orchestrator ⭐
**Purpose:** Intelligent task router that executes end-to-end workflows autonomously

**Usage:**
```
/workflow "task description"
/workflow "celery alert matcher uses too much memory"
/workflow "add caching for route patterns"
/workflow "implement phase 2"
```

**Intelligence:**
1. **Understands intent** - Reconstructs unclear input
2. **Analyzes requirements** - Classifies type, scope, complexity
3. **Routes automatically** - Selects appropriate workflow
4. **Executes end-to-end** - Runs commands without asking (unless ambiguous)

**Example Flow:**
```
User: "celery alert matcher uses too much memory"

Workflow analysis:
→ Reconstructed: "Fix memory leak in Celery alert matcher task"
→ Type: BUG_FIX (confidence: 0.95)
→ Scope: 3 backend files
→ Complexity: medium (5/10)

Autonomous execution:
→ /bug "Fix memory leak in Celery alert matcher task"
  → 4-stage diagnosis → Fix → Commit

✅ Complete (12 minutes)
```

---

## Specialized Commands (Phase Work)

### 5. `/plan-phase N` - Phase-Specific Planning
**Purpose:** Plan structured phase from roadmap

**Usage:**
```
/plan-phase 2
/plan-phase 0
```

**Output:**
- Plan file: `specs/phase-{N}-implementation-plan.md`
- Logs: `.workflow-logs/phases/phase-{N}/`

**Reads:** `oracle/phases/PHASE_{N}_*.md`

---

### 6. `/implement-phase N` - Phase-Specific Implementation
**Purpose:** Execute phase plan with roadmap compliance

**Usage:**
```
/implement-phase 2
```

**Output:**
- Code + commits per checkpoint
- Phase completion: `.workflow-logs/phases/phase-{N}/phase-completion.json`

---

### 7. `/bug` - Bug Diagnosis & Fix
**Purpose:** Investigate and fix user-reported bugs (4-stage analysis)

**Usage:**
```
/bug "description of bug"
/bug "iOS map view not showing annotations"
```

**Workflow:**
1. Map Subagent (which phase/system?)
2. Explore Subagent (find ALL relevant code)
3. Diagnose Subagent (first-principles root cause)
4. Fix Subagent (minimal correct fix)

**Output:**
- Bug report: `.workflow-logs/bugs/{timestamp}-{slug}/REPORT.md`
- Diagnosis: `.workflow-logs/bugs/{timestamp}-{slug}/diagnosis-result.json`
- Fix: Code changes + commit

---

### 8. `/fix-bug` - Checkpoint Validation Fix
**Purpose:** Fix checkpoint validation failures (called by orchestrator)

**Usage:**
```
/fix-bug custom {plan-name} {checkpoint} validation_failed
/fix-bug phase {phase-number} {checkpoint} validation_failed
```

**Internal use:** Orchestrator invokes when validation fails

---

## Workflow Types & Decision Tree

### Type 1: Bug Fix
**Trigger:** Keywords: fix, bug, broken, failing, error, leak
**Workflow:** `/bug` (4-stage diagnosis)
**Example:** "celery task crashes on empty data"

### Type 2: Feature Addition
**Trigger:** Keywords: add, implement, create, new, feature
**Workflow:** `/plan` → `/implement` → `/test`
**Example:** "add caching for route patterns"

### Type 3: Optimization
**Trigger:** Keywords: optimize, improve, faster, reduce
**Workflow:** `/plan` → `/implement` → `/test`
**Example:** "optimize iOS map rendering performance"

### Type 4: Refactoring
**Trigger:** Keywords: refactor, cleanup, restructure
**Workflow:** `/plan` → `/implement` → `/test`
**Example:** "refactor stop search to use repository pattern"

### Type 5: Phase Work
**Trigger:** "phase N" or numeric input
**Workflow:** `/plan-phase N` → `/implement-phase N` → `/test`
**Example:** "implement phase 2"

### Type 6: Testing
**Trigger:** Keywords: test, verify, validate
**Workflow:** `/test all`
**Example:** "test backend routes"

---

## Artifact Structure

```
.workflow-logs/
├── phases/
│   └── phase-{N}/
│       ├── exploration-report.json
│       ├── ios-research-summary.json
│       ├── ios-research-{topic}.md
│       ├── checkpoint-{N}-design.md
│       ├── checkpoint-{N}-result.json
│       ├── orchestrator-state.json
│       └── phase-completion.json
│
├── custom/
│   └── {plan-name}/
│       ├── exploration-report.json
│       ├── ios-research-summary.json (if iOS work)
│       ├── checkpoint-{N}-design.md
│       ├── checkpoint-{N}-result.json
│       ├── orchestrator-state.json
│       └── completion-report.json
│
├── bugs/
│   └── {timestamp}-{slug}/
│       ├── bug-context.json
│       ├── map-result.json
│       ├── explore-result.json
│       ├── diagnosis-result.json
│       ├── fix-result.json
│       └── REPORT.md
│
└── tests/
    └── {timestamp}/
        ├── test-context.json
        ├── backend-results.json
        ├── validation-results.json
        └── REPORT.md
```

**Note:** All `.workflow-logs/` artifacts are in `.gitignore` (local only)

---

## Standards & Guidelines

### Confidence Thresholds
**Location:** `oracle/standards/CONFIDENCE_THRESHOLDS.md`

**Key Rules:**
- iOS patterns: **0.90 minimum** (MUST research Apple docs if below)
- External services: **0.80 minimum** (verify official docs)
- Architecture decisions: **0.85 minimum** (align with specs)
- General implementation: **0.80 minimum**

**Research Sources:**
1. iOS: SOSUMI MCP (Apple docs) → create `ios-research-*.md`
2. Backend: DEVELOPMENT_STANDARDS.md + architecture specs
3. External: WebFetch official documentation

**Never hallucinate:** Return blocker > guess

---

### Development Standards
**Location:** `oracle/DEVELOPMENT_STANDARDS.md`

**Critical Patterns:**
- Logging: Structlog JSON, no PII, event-based
- Error handling: API envelope, specific error codes
- Database: Singleton clients (get_supabase via Depends)
- Repository pattern: Protocol-based, async/await
- Testing: pytest for backend, validation commands in plans

---

## Autonomous Execution

### When `/workflow` Executes Automatically

**No user confirmation needed:**
- Clear task with confidence >0.70
- Non-destructive operation
- Complexity: simple or medium
- Known workflow path

**User confirmation required:**
- Confidence <0.70 (ambiguous task)
- High-risk operation (DB schema changes, deletes)
- Complexity: very complex (>8 files, 3+ layers)
- Multiple valid interpretations

**Example Automatic:**
```
User: "add Redis caching for patterns"

Analysis:
- Reconstructed: "Implement Redis caching layer for GTFS pattern queries"
- Type: FEATURE (confidence: 0.88)
- Scope: 5 backend files
- Complexity: medium (6/10)

Executes autonomously:
→ /plan "Implement Redis caching layer for GTFS pattern queries"
→ /implement redis-caching-gtfs-patterns
→ /test all

✅ Complete (45 minutes)
```

**Example Confirmation:**
```
User: "make it faster"

Analysis:
- Reconstructed: "Optimize application performance" (unclear)
- Type: OPTIMIZATION (confidence: 0.60)
- Scope: Unknown
- Complexity: Unknown

⚠️ Confirmation required:

Please clarify:
1. What needs optimization?
   - Backend API response times?
   - iOS UI rendering?
   - Database queries?
2. Current performance issue?
3. Target metrics?
```

---

## Complete SDLC Loop

```
User provides task
    ↓
/workflow analyzes + reconstructs
    ↓
┌─────────────────────────────────┐
│ PLANNING                        │
│ /plan "task"                    │
│ → exploration + research        │
│ → Output: plan.md               │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│ IMPLEMENTATION                  │
│ /implement {plan-name}          │
│ → checkpoint execution          │
│ → Output: code + commits        │
└─────────────────────────────────┘
    ↓
┌─────────────────────────────────┐
│ TESTING                         │
│ /test all                       │
│ → backend + validation tests    │
│ → Output: test reports          │
└─────────────────────────────────┘
    ↓
  PASS? ────NO───┐
    │            ↓
   YES   ┌──────────────────┐
    │    │ /bug "failure"   │
    │    │ → diagnose + fix │
    │    └──────────────────┘
    │            ↓
    │        (loop back)
    ↓
 ✅ DONE
```

---

## Quick Reference

### For Users

**I want to add a feature:**
```
/workflow "add feature description"
```

**I found a bug:**
```
/workflow "bug description"
OR
/bug "bug description"
```

**I want to optimize something:**
```
/workflow "optimize X for Y"
```

**I want to implement a phase:**
```
/workflow "implement phase N"
OR
/plan-phase N → /implement-phase N
```

**I want to test my changes:**
```
/test all
```

---

### For Advanced Users

**Create plan only (don't implement yet):**
```
/plan "task description"
```

**Implement existing plan:**
```
/implement {plan-name}
```

**Run specific test scope:**
```
/test backend      # Backend unit tests
/test validation   # Plan validation commands
```

**Fix specific checkpoint:**
```
/fix-bug custom {plan-name} {checkpoint-number} validation_failed
```

---

## Migration Notes

**Old → New:**
- `.phase-logs/` → `.workflow-logs/phases/`
- `.bug-logs/` → `.workflow-logs/bugs/`
- All commands updated to use new structure
- Both paths ignored in `.gitignore` (backward compatibility)

**Backward Compatibility:**
- Commands check for `.phase-logs/` first (legacy)
- Fall back to `.workflow-logs/phases/` (new)
- Gradual migration (no breaking changes)

---

## Best Practices

### 1. Start with `/workflow`
Let the orchestrator analyze and route - it's smarter than manual routing

### 2. Trust the confidence thresholds
If agent says "blocked" due to low confidence - provide clarification

### 3. Review completion reports
Check `.workflow-logs/*/REPORT.md` before merging

### 4. Run tests
Always `/test all` before merge to main

### 5. Read the standards
`oracle/DEVELOPMENT_STANDARDS.md` and `oracle/standards/CONFIDENCE_THRESHOLDS.md`

---

## Troubleshooting

**Q: Agent returned blocker for uncertainty**
**A:** Research needed - provide documentation or clarify requirements

**Q: Tests failing after implementation**
**A:** Run `/bug "test X failing"` - will diagnose and fix

**Q: Agent asking too many questions**
**A:** Provide more specific task description upfront

**Q: Workflow chose wrong command**
**A:** Manually run specific command (e.g., `/plan` instead of `/workflow`)

**Q: Agent hallucinating iOS patterns**
**A:** Check confidence thresholds enforced - should auto-research

---

**System Version:** 1.0
**Created:** 2025-01-17
**Status:** Production Ready
