# Plan Custom Implementation

Create checkpoint-driven implementation plan for any task (features, fixes, refactors, optimizations).

## Usage

```
/plan "implement caching for GTFS patterns"
/plan "fix iOS route list performance"
/plan "add background refresh for departures"
```

## Variables

task_description: $1 (required: description of what needs to be implemented/fixed)

## Instructions

**IMPORTANT: Think hard. Activate reasoning mode for all planning decisions.**

---

## Stage 1: Understand Task & Codebase

### 1.1 Create Plan Name

```bash
plan_name=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-60)
plan_dir=".claude-logs/plans/${plan_name}"
mkdir -p "${plan_dir}"
```

### 1.2 Read Documentation

Read project documentation to understand context:

1. **Architecture & Standards:**
   - docs/architecture/SYSTEM_OVERVIEW.md
   - docs/standards/DEVELOPMENT_STANDARDS.md
   - Based on task keywords, read relevant specs:
     - Backend work? → docs/architecture/BACKEND_SPECIFICATION.md
     - iOS work? → docs/architecture/IOS_APP_SPECIFICATION.md
     - Data work? → docs/architecture/DATA_ARCHITECTURE.md
     - API contracts? → docs/architecture/INTEGRATION_CONTRACTS.md

2. **Current Status:**
   - CLAUDE.md (project status, tech stack)
   - git status (current changes)
   - git log --oneline -20 (recent commits)

### 1.3 Explore Codebase

Understand what exists and what's needed:

1. Find relevant files related to task description
2. Read existing implementations
3. Identify patterns used
4. Understand data flow
5. Note what's missing or broken

**No tool prescription - explore naturally based on task requirements.**

### 1.4 Identify iOS Research Needs

If task involves iOS work, identify topics needing research:
- SwiftUI patterns?
- GRDB features?
- MapKit APIs?
- Core Location?
- UserNotifications?
- Other iOS frameworks?

---

## Stage 2: iOS Research (If Needed)

**ONLY if iOS work identified in Stage 1.**

Deploy iOS research subagent:

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "iOS documentation research for {plan_name}"
- prompt: "
Research iOS topics for '{task_description}'.

TOPICS TO RESEARCH:
{list topics identified in Stage 1}

FOR EACH TOPIC:
1. Find relevant Apple documentation (use available MCP tools)
2. Extract key patterns and API details
3. Note critical constraints and gotchas
4. Provide code examples

CREATE RESEARCH FILE for each topic:
Save to: .claude-logs/plans/{plan_name}/ios-research-{topic-slug}.md

Format:
# iOS Research: {Topic}

## Key Pattern
{2-3 sentence summary}

## Code Example
```swift
// Minimal working example
```

## Critical Constraints
- {Must-follow rule 1}
- {Must-follow rule 2}

## Common Gotchas
- {Pitfall and how to avoid}

## API Reference
- Apple docs: {URL}

Token budget: Max 500 tokens per file. Focus on actionable patterns.

RETURN:
List of research files created.
"
```

Wait for subagent completion.

---

## Stage 3: Analyze & Design

### 3.1 Determine Affected Systems

Based on exploration, identify:
- Which systems/components affected?
- Backend? iOS? Data layer?
- What files need changes?
- What's the current state vs desired state?

### 3.2 Identify Key Decisions

What technical decisions are needed?
- Which patterns to use? (reference DEVELOPMENT_STANDARDS.md)
- Which libraries/frameworks?
- Performance targets?
- Critical constraints?

### 3.3 Break into Checkpoints

Divide work into independently verifiable milestones:
- Each checkpoint = working feature slice
- Can validate each checkpoint independently
- Clear success criteria
- Backend + iOS work together per checkpoint (not separate)

---

## Stage 4: Create Plan

Write plan file: `.claude-logs/plans/{plan_name}/plan.md`

```markdown
# {Plan Name} Implementation Plan

**Task:** {task_description}
**Complexity:** {simple|medium|complex}

---

## Problem Statement

{3-sentence overview: what problem this solves, current state, why needed}

---

## Affected Systems

**System: {System Name}**
- Current state: {what exists today}
- Gap: {what's missing or broken}
- Files affected: {list key files}

---

## Key Technical Decisions

1. **{Decision Name}**
   - Rationale: {why this approach}
   - Reference: {DEVELOPMENT_STANDARDS.md:Section or architecture doc}
   - Constraint: {must-follow rule}

---

## Implementation Checkpoints

### Checkpoint 1: {Name}

**Goal:** {Specific success criteria}

**Backend Work:**
- {Task 1}
- {Task 2}
(or "N/A")

**iOS Work:**
- {Task 1}
- {Task 2}
(or "N/A")

**Design Constraints:**
- Follow {REFERENCE} for {pattern}
- Use {specific approach}
- Must achieve {target}

**Validation:**
```bash
{Command to verify checkpoint}
# Expected: {specific output}
```

**References:**
- Pattern: {from DEVELOPMENT_STANDARDS.md}
- Architecture: {spec file:section}
- iOS Research: {.claude-logs/plans/{plan_name}/ios-research-{topic}.md}

---

{Repeat for all checkpoints}

---

## Acceptance Criteria

- [ ] {Criterion 1 - derived from task description}
- [ ] {Criterion 2}
- [ ] {Criterion 3}

---

## Research Completed

**iOS Research:**
{List research files if any}

**External Services:**
{Any research needed during implementation - agent will handle on-demand}

---

**Plan Created:** {date}
**Estimated Duration:** {estimate}
```

---

## Stage 5: Validate Plan

Check:
- [ ] All checkpoints have clear goals + validation
- [ ] References point to specific sections (not vague)
- [ ] iOS research completed if needed
- [ ] Acceptance criteria match task description
- [ ] Each checkpoint independently testable

---

## Report

```
Plan Created: .claude-logs/plans/{plan_name}/plan.md

Summary:
- Problem: {1-sentence}
- Affected: {systems}
- Complexity: {level}
- Checkpoints: {N}

iOS Research:
{List topics researched}
(or "No iOS work")

Ready for Implementation: Yes

Next: /implement {plan_name}
```

---

## Notes

- Orchestrator reads docs directly (no exploration subagent)
- Only iOS research uses subagent (needs MCP for Apple docs)
- No grep/tool prescription - natural exploration
- No JSON artifacts - markdown only
- Single folder: .claude-logs/plans/{plan_name}/
