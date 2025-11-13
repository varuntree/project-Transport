# Plan Phase Implementation

Create checkpoint-driven implementation plan through exploration, research, and strategic design. Uses subagents to compress context and maintain focus.

## Variables

phase_number: $1

## Instructions

**IMPORTANT: Think hard. Activate reasoning mode for all planning decisions.**

---

## Stage 1: Comprehensive Exploration (Subagent Context Compression)

**Purpose:** Offload heavy document reading to exploration subagent, return compressed reference document for planning.

**Create logging folder:**
```bash
mkdir -p .phase-logs/phase-{phase_number}
```

### 1.1 Deploy Deep Exploration Subagent

Launch comprehensive exploration subagent to read ALL documentation and produce structured reference:

```
Task tool:
- subagent_type: "Explore"
- model: "sonnet"
- description: "Deep exploration for Phase {phase_number}"
- prompt: "
Your task: Read all relevant documentation for Phase {phase_number} and produce a structured JSON reference report.

Thoroughness: very thorough

Read these documents:
1. oracle/phases/PHASE_{phase_number}_*.md (phase specification)
2. oracle/DEVELOPMENT_STANDARDS.md (coding patterns)
3. oracle/IMPLEMENTATION_ROADMAP.md (phase dependencies)
4. Relevant architecture specs:
   - oracle/specs/SYSTEM_OVERVIEW.md (always)
   - oracle/specs/DATA_ARCHITECTURE.md (if Phases 1-2)
   - oracle/specs/BACKEND_SPECIFICATION.md (if backend work)
   - oracle/specs/IOS_APP_SPECIFICATION.md (if iOS work)
   - oracle/specs/INTEGRATION_CONTRACTS.md (if API/auth work)
5. Previous phase artifacts (if phase > 0):
   - .phase-logs/phase-{phase_number - 1}/*.json
   - Git log: git log --grep='phase {phase_number - 1}' --oneline -20
   - Implementation files (backend/app/**, SydneyTransit/**)
6. Current codebase state:
   - git status
   - Project structure (ls -R backend/ SydneyTransit/ 2>/dev/null)

Return structured JSON (save to .phase-logs/phase-{phase_number}/exploration-report.json):
{
  \"phase_summary\": \"3-sentence overview of phase goals\",
  \"key_decisions\": [
    {
      \"decision\": \"Technical decision name\",
      \"rationale\": \"Why this approach\",
      \"reference\": \"FILE.md:LINE_RANGE or Section number\",
      \"critical_constraint\": \"Must-follow rule\"
    }
  ],
  \"previous_phase_state\": {
    \"completed\": [\"Deliverable 1\", \"Deliverable 2\"],
    \"files_created\": [\"path/to/file.py\"],
    \"current_state\": \"Backend running at :8000, iOS builds successfully\",
    \"blockers\": []
  },
  \"checkpoints\": [
    {
      \"name\": \"Checkpoint 1 name\",
      \"goal\": \"Specific success criteria\",
      \"backend_work\": [\"Task 1\", \"Task 2\"],
      \"ios_work\": [\"Task 1\", \"Task 2\"],
      \"validation\": \"Command or test to verify\"
    }
  ],
  \"critical_patterns\": [
    {
      \"pattern\": \"Pattern name (e.g., Singleton DB client)\",
      \"example_location\": \"backend/app/db/supabase_client.py:L10-25\",
      \"reference\": \"DEVELOPMENT_STANDARDS.md:Section 2\"
    }
  ],
  \"ios_research_needed\": [
    \"GRDB FTS5 tokenizer setup\",
    \"SwiftUI List auto-refresh patterns\"
  ],
  \"external_services_research\": [
    \"Supabase RLS policy setup\",
    \"Railway Redis configuration\"
  ],
  \"user_blockers\": [
    \"Must download 227MB GTFS dataset\",
    \"Must configure NSW API key\"
  ],
  \"acceptance_criteria\": [
    \"Criterion 1 from phase spec\",
    \"Criterion 2 from phase spec\"
  ]
}

Token budget: Return concise JSON (~2000 tokens max). Main planner will reference this throughout.
"
```

**Save exploration output:**
```bash
# Subagent will return JSON - save it
echo '<subagent_json_output>' > .phase-logs/phase-{phase_number}/exploration-report.json
```

---

## Stage 2: Mandatory iOS Research (If Applicable)

**CRITICAL: iOS training data gaps require upfront research. Do NOT skip.**

If exploration report shows `ios_research_needed` items, research NOW (not during implementation):

### 2.1 iOS Documentation Research

For each iOS research item from exploration report:

```
Use mcp__sosumi__searchAppleDocumentation or mcp__sosumi__fetchAppleDocumentation:
- Query: "<specific iOS feature from ios_research_needed>"
- Extract: Code examples, best practices, API patterns
- Save findings to: .phase-logs/phase-{phase_number}/ios-research-<topic>.md
```

**Topics requiring mandatory research:**
- SwiftUI: Views, navigation, state management, List/LazyVStack
- GRDB: Queries, FTS5, WITHOUT ROWID, migrations
- MapKit: Annotations, polylines, coordinate regions
- URLSession: async/await patterns, error handling
- Keychain: Secure token storage
- UserNotifications: APNs registration, handling
- Core Location: Permission, nearby queries

**Format findings concisely:**
```markdown
# iOS Research: <Topic>

## Key Pattern
<2-3 sentence summary>

## Code Example
```swift
// Minimal working example from Apple docs
```

## Gotchas
- Critical constraint 1
- Critical constraint 2

## Reference
- Apple docs: <URL or path>
```

---

## Stage 3: Ask User Questions (Max 3)

Review exploration report and identify ambiguities:

1. **Check user blockers:**
   - From exploration report `user_blockers` array
   - Ask if setup is complete (e.g., "GTFS dataset downloaded?")

2. **Clarify optional features:**
   - If phase spec mentions "optional X", ask: implement or defer?

3. **Verify assumptions:**
   - If exploration found conflicting patterns, ask for clarification

**If everything clear:** Say "No questions - ready to plan" and proceed.

**If questions exist:** Wait for user response before continuing.

---

## Stage 4: Create Checkpoint-Driven Plan

**Plan File:** `specs/phase-{phase_number}-implementation-plan.md`

**Guidelines:**
- Use checkpoints (not step-by-step instructions)
- Each checkpoint = independently verifiable milestone
- Include references (not full specs)
- Design constraints (not implementation details)
- Backend + iOS work within each checkpoint

### Plan Template (Lightweight)

```markdown
# Phase {phase_number} Implementation Plan

**Phase:** <Name from phase spec>
**Duration:** <From roadmap>
**Complexity:** <simple|medium|complex>

---

## Goals

<3-5 bullet points from exploration report phase_summary>

---

## Key Technical Decisions

<From exploration report key_decisions array>

1. **Decision name**
   - Rationale: <Why>
   - Reference: <FILE:LINE or Section>
   - Critical constraint: <Must-follow rule>

---

## Implementation Checkpoints

### Checkpoint 1: <Name>

**Goal:** <Specific success criteria>

**Backend Work:**
- <Task 1>
- <Task 2>

**iOS Work:**
- <Task 1>
- <Task 2>

**Design Constraints:**
- Follow <REFERENCE> for <pattern>
- Use <specific library/approach>
- Must achieve <performance/size target>

**Validation:**
```bash
<Command to verify checkpoint complete>
# Expected: <Specific output>
```

**References:**
- Pattern: <from exploration report critical_patterns>
- Architecture: <spec file:section>
- iOS Research: `.phase-logs/phase-{phase_number}/ios-research-<topic>.md`

---

### Checkpoint 2: <Name>

<Repeat format>

---

## Acceptance Criteria

<Copy from exploration report acceptance_criteria>

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

---

## User Blockers (Complete Before Implementation)

<From exploration report user_blockers>

- [ ] Blocker 1
- [ ] Blocker 2

---

## Research Notes

**iOS Research Completed:**
<List topics researched in Stage 2>

**On-Demand Research (During Implementation):**
<From exploration report external_services_research>
- Agent will research these when implementing relevant checkpoint
- Confidence check: If <80% confident, agent MUST research

---

## Exploration Report

Attached: `.phase-logs/phase-{phase_number}/exploration-report.json`

---

**Plan Created:** <date>
**Estimated Duration:** <X weeks>
```

---

## Stage 5: Validate Plan

**Checklist:**
- [ ] All checkpoints have clear goals + validation commands
- [ ] References point to specific files/sections (not vague)
- [ ] iOS research completed for all iOS work
- [ ] User blockers clearly listed
- [ ] Acceptance criteria match phase spec
- [ ] Each checkpoint independently testable

**Cross-check:**
- Re-read `oracle/phases/PHASE_{phase_number}_*.md`
- Ensure every deliverable from phase spec appears in checkpoints
- Verify no scope creep (only what's in phase spec)

---

## Report

Provide concise report:

```
Plan Created: specs/phase-{phase_number}-implementation-plan.md

Summary:
- <High-level goal 1>
- <High-level goal 2>
- <Key technical decision>
- Complexity: <simple|medium|complex>

Exploration:
- Compressed 10K+ tokens of docs → 2K JSON reference
- Phase state: <current state from exploration>
- Checkpoints: <N checkpoints defined>

iOS Research:
- <Topic 1> researched → .phase-logs/phase-{phase_number}/ios-research-<topic>.md
- <Topic 2> researched
- <Or "No iOS work in this phase">

User Blockers:
- <Blocker 1> - User must complete before /implement-phase
- <Or "None - ready to implement">

Ready for Implementation: Yes/No
<If No, explain what's missing>

Next: Run /implement-phase {phase_number}
```

---

## Notes

**Context Management:**
- Main planner never reads full specs (exploration subagent does)
- Exploration JSON (~2K tokens) referenced throughout planning
- iOS research saved to files (loaded during implementation)
- Checkpoint structure enables progressive loading in implementation

**Token Savings:**
- Before: 10K+ tokens (full specs) → Main planner context
- After: 2K tokens (exploration JSON) → Main planner context
- Savings: ~80% context reduction while maintaining quality
