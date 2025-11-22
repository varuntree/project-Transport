# Plan Phase Implementation

Create checkpoint-driven implementation plan through exploration, research, and strategic design. Uses subagents to compress context and maintain focus.

## Usage

**For phase planning:**
```
/plan-phase 2
/plan-phase 0
```
Creates plan for specified phase from docs/phases/PHASE_N_*.md

**For custom/ad-hoc planning:**
```
/plan-phase "celery alert matcher fixes"
/plan-phase route-caching optimization
/plan-phase "iOS route list performance"
```
Creates plan for intermediary work not covered in phase specs

## Variables

phase_or_description: $1
additional_context: $2 (optional)

## Instructions

**SETUP: Determine Plan Type**

Detect if $1 is phase number or custom plan:

```
If $1 matches pattern "^\d+$" (e.g., "0", "2", "5"):
  - Plan type: PHASE
  - Phase number: $1
  - Plan name: "phase-{$1}"
  - Output: plans/phase-{$1}-implementation-plan.md
  - Logs: .workflow-logs/active/phases/phase-{$1}/

Else:
  - Plan type: CUSTOM
  - Plan name: sanitized($1) (lowercase, hyphens, no spaces)
  - Description: "$1 $2" (combined args)
  - Output: plans/{plan_name}-plan.md
  - Logs: .workflow-logs/active/custom/{plan_name}/
```

**Detection Examples:**
- `/plan-phase 2` → PHASE (reads docs/phases/PHASE_2_*.md)
- `/plan-phase "celery alert matcher fixes"` → CUSTOM (explores codebase for celery/alert)
- `/plan-phase route-caching optimization` → CUSTOM (searches for route caching code)

---

**IMPORTANT: Think hard. Activate reasoning mode for all planning decisions.**

---

## Stage 1: Comprehensive Exploration (Subagent Context Compression)

**Purpose:** Offload heavy document reading to exploration subagent, return compressed reference document for planning.

**Create logging folder:**
```bash
# PHASE plan:
mkdir -p .workflow-logs/active/phases/phase-{phase_number}

# CUSTOM plan:
mkdir -p .workflow-logs/active/custom/{plan_name}
```

### 1.1 Deploy Deep Exploration Subagent

Launch comprehensive exploration subagent to read ALL documentation and produce structured reference:

**For PHASE plans:**
```
Task tool:
- subagent_type: "Explore"
- model: "sonnet"
- description: "Deep exploration for Phase {phase_number}"
- prompt: "
Your task: Read all relevant documentation for Phase {phase_number} and produce a structured JSON reference report.

Thoroughness: very thorough

Read these documents:
1. docs/phases/PHASE_{phase_number}_*.md (phase specification)
2. docs/standards/DEVELOPMENT_STANDARDS.md (coding patterns)
3. docs/IMPLEMENTATION_ROADMAP.md (phase dependencies)
4. Relevant architecture specs:
   - docs/architecture/SYSTEM_OVERVIEW.md (always)
   - docs/architecture/DATA_ARCHITECTURE.md (if Phases 1-2)
   - docs/architecture/BACKEND_SPECIFICATION.md (if backend work)
   - docs/architecture/IOS_APP_SPECIFICATION.md (if iOS work)
   - docs/architecture/INTEGRATION_CONTRACTS.md (if API/auth work)
5. Previous phase artifacts (if phase > 0):
   - .workflow-logs/active/phases/phase-{phase_number - 1}/*.json
   - Git log: git log --grep='phase {phase_number - 1}' --oneline -20
   - Implementation files (backend/app/**, SydneyTransit/**)
6. Current codebase state:
   - git status
   - Project structure (ls -R backend/ SydneyTransit/ 2>/dev/null)

Return structured JSON (save to .workflow-logs/active/phases/phase-{phase_number}/exploration-report.json):
{
  \"plan_type\": \"PHASE\",
  \"phase_number\": {phase_number},
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
echo '<subagent_json_output>' > .workflow-logs/active/phases/phase-{phase_number}/exploration-report.json
```

---

**For CUSTOM plans:**
```
Task tool:
- subagent_type: "Explore"
- model: "sonnet"
- description: "Deep exploration for {plan_name}"
- prompt: "
Your task: Read all relevant documentation for custom plan '{description}' and produce a structured JSON reference report.

Thoroughness: medium (focus on relevant areas only)

PLAN CONTEXT:
- Plan name: {plan_name}
- Description: {description}
- Purpose: Ad-hoc planning for intermediary work not covered in phase specs

Read these documents:
1. docs/standards/DEVELOPMENT_STANDARDS.md (coding patterns - always)
2. Relevant architecture specs based on plan description:
   - docs/architecture/SYSTEM_OVERVIEW.md (if unclear what plan touches)
   - docs/architecture/DATA_ARCHITECTURE.md (if mentions: GTFS, database, caching, Redis)
   - docs/architecture/BACKEND_SPECIFICATION.md (if mentions: API, Celery, tasks, backend)
   - docs/architecture/IOS_APP_SPECIFICATION.md (if mentions: iOS, Swift, UI, app)
   - docs/architecture/INTEGRATION_CONTRACTS.md (if mentions: API contracts, auth, APNs)
3. Current implementation state:
   - git status
   - git log --oneline -20 (recent commits for context)
   - Search codebase for files related to plan description:
     * grep -r '<keywords from description>' backend/ SydneyTransit/ --files-with-matches
     * ls -la relevant directories
4. Existing phase artifacts (if relevant):
   - .workflow-logs/active/phases/phase-*/exploration-report.json (check recent phases)
   - plans/phase-*-implementation-plan.md (check if related work was planned)

ANALYSIS FOCUS:
- What does plan description ask to solve?
- What existing code/systems are affected?
- What architecture specs/patterns apply?
- What's missing from current implementation?
- What are the constraints (technical, cost, performance)?

Return structured JSON (save to .workflow-logs/active/custom/{plan_name}/exploration-report.json):
{
  \"plan_type\": \"CUSTOM\",
  \"plan_name\": \"{plan_name}\",
  \"description\": \"{description}\",
  \"context_summary\": \"3-sentence overview: what problem this solves, current state, why needed\",
  \"affected_systems\": [
    {
      \"system\": \"System name (e.g., Celery alert matcher, iOS route cache)\",
      \"current_state\": \"What exists today\",
      \"gap\": \"What's missing or broken\",
      \"files_affected\": [\"path/to/file1.py\", \"path/to/file2.swift\"]
    }
  ],
  \"key_decisions\": [
    {
      \"decision\": \"Technical decision name\",
      \"rationale\": \"Why this approach\",
      \"reference\": \"FILE.md:LINE_RANGE or Section number\",
      \"critical_constraint\": \"Must-follow rule\"
    }
  ],
  \"checkpoints\": [
    {
      \"name\": \"Checkpoint 1 name\",
      \"goal\": \"Specific success criteria\",
      \"backend_work\": [\"Task 1\", \"Task 2\"] or [],
      \"ios_work\": [\"Task 1\", \"Task 2\"] or [],
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
    \"Topic 1\", \"Topic 2\" or []
  ],
  \"external_services_research\": [
    \"Service pattern 1\", \"Service pattern 2\" or []
  ],
  \"user_blockers\": [
    \"Blocker 1\" or []
  ],
  \"acceptance_criteria\": [
    \"Custom criterion 1 (derived from plan description)\",
    \"Custom criterion 2\"
  ],
  \"related_phases\": [
    {
      \"phase\": \"Phase 2\",
      \"relation\": \"This fixes bugs introduced in Phase 2 GTFS-RT polling\"
    }
  ]
}

Token budget: Return concise JSON (~2000 tokens max). Main planner will reference this throughout.
"
```

**Save exploration output:**
```bash
# Subagent will return JSON - save it
echo '<subagent_json_output>' > .workflow-logs/active/custom/{plan_name}/exploration-report.json
```

---

## Stage 2: Mandatory iOS Research (If Applicable)

**CRITICAL: iOS training data gaps require upfront research. Do NOT skip.**

If exploration report shows `ios_research_needed` items, delegate research to subagent NOW (not during implementation):

### 2.1 Deploy iOS Documentation Research Subagent

Launch general-purpose subagent to research ALL iOS topics and produce concise findings:

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "iOS documentation research for {plan_name or Phase phase_number}"
- prompt: "
Your task: Research iOS topics for {plan_name or Phase phase_number} using Apple Documentation (SOSUMI MCP tools) and produce concise research files.

CONTEXT:
1. **Exploration Report:**
   Read .workflow-logs/active/{plan_folder}/exploration-report.json
   (plan_folder = phase-{phase_number} for PHASE plans, {plan_name} for CUSTOM plans)
   - Focus on `ios_research_needed` array (topics requiring research)
   - Reference `checkpoints` to understand where iOS patterns will be used

2. **Specification:**
   For PHASE plans: Read docs/phases/PHASE_{phase_number}_*.md
   For CUSTOM plans: Use exploration report context_summary and affected_systems
   - Understand iOS implementation requirements
   - Identify specific iOS frameworks/APIs needed

RESEARCH INSTRUCTIONS:

For each topic in `ios_research_needed` array:

1. **Search Apple Documentation:**
   - Use mcp__sosumi__searchAppleDocumentation with specific query
   - Find most relevant documentation URL (prioritize: documentation > videos > general)

2. **Fetch Detailed Documentation:**
   - Use mcp__sosumi__fetchAppleDocumentation with path from search results
   - Extract: Key patterns, code examples, API signatures, gotchas

3. **Create Concise Research File:**
   Save to: .workflow-logs/active/{plan_folder}/ios-research-<topic-slug>.md

   Format:
   ```markdown
   # iOS Research: <Topic>

   ## Key Pattern
   <2-3 sentence summary of the pattern/API>

   ## Code Example
   ```swift
   // Minimal working example from Apple docs
   // Include: imports, key API calls, error handling
   ```

   ## Critical Constraints
   - <Must-follow rule 1>
   - <Must-follow rule 2>
   - <Performance/compatibility consideration>

   ## Common Gotchas
   - <Pitfall 1 and how to avoid>
   - <Pitfall 2 and how to avoid>

   ## API Reference
   - Apple docs: <URL or path>
   - Related APIs: <List if relevant>

   ## Relevance to Plan
   <1-2 sentences explaining where this will be used in checkpoints>
   ```

4. **Token Budget per Research File:**
   - Max 500 tokens per file
   - Focus on actionable patterns (not comprehensive docs)
   - Prioritize code examples and gotchas

RESEARCH TOPICS (from exploration report):
<You will read these from exploration-report.json ios_research_needed array>

Common topics you may encounter:
- SwiftUI: Views, navigation, state management (@Published, @State, @ObservedObject), List/LazyVStack, .refreshable modifier
- GRDB: FTS5 full-text search, WITHOUT ROWID optimization, database migrations, query patterns
- MapKit: MKMapView, annotations, polylines, coordinate regions, user location
- URLSession: async/await data tasks, error handling, timeout configuration, URLError types
- Keychain: SecItemAdd/Update/Delete, kSecClass attributes, secure token storage
- UserNotifications: UNUserNotificationCenter, APNs registration, notification handling
- Core Location: CLLocationManager, authorization, nearby queries, background location

VALIDATION:
- Each research file must have: Key Pattern, Code Example, Critical Constraints, Common Gotchas, API Reference
- Code examples must compile (check Swift syntax)
- All files saved to .workflow-logs/active/{plan_folder}/

RETURN FORMAT (JSON):
{
  \"topics_researched\": [
    {
      \"topic\": \"SwiftUI refreshable modifier\",
      \"file\": \".workflow-logs/{plan_folder}/ios-research-swiftui-refreshable.md\",
      \"key_finding\": \"1-sentence summary of critical pattern\",
      \"apple_docs_url\": \"https://developer.apple.com/documentation/...\"
    }
  ],
  \"research_complete\": true,
  \"blockers\": []
}

DO NOT:
- Write generic tutorials (focus on specific patterns needed)
- Copy full Apple documentation (extract essentials)
- Research topics not in ios_research_needed array
- Hallucinate API patterns (always use SOSUMI tools)
"
```

**Wait for subagent completion.**

**Save research summary:**
```bash
echo '<subagent_json_output>' > .workflow-logs/active/{plan_folder}/ios-research-summary.json
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

**Plan File:**
- PHASE plans: `plans/phase-{phase_number}-implementation-plan.md`
- CUSTOM plans: `plans/{plan_name}-plan.md`

**Guidelines:**
- Use checkpoints (not step-by-step instructions)
- Each checkpoint = independently verifiable milestone
- Include references (not full specs)
- Design constraints (not implementation details)
- Backend + iOS work within each checkpoint

### Plan Template (Lightweight)

**For PHASE plans:**
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
- iOS Research: `.workflow-logs/active/phases/phase-{phase_number}/ios-research-<topic>.md`

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

Attached: `.workflow-logs/active/phases/phase-{phase_number}/exploration-report.json`

---

**Plan Created:** <date>
**Estimated Duration:** <X weeks>
```

---

**For CUSTOM plans:**
```markdown
# {Plan Name} Implementation Plan

**Type:** Custom Plan (Ad-hoc)
**Context:** <From exploration report description>
**Complexity:** <simple|medium|complex>

---

## Problem Statement

<From exploration report context_summary>

---

## Affected Systems

<From exploration report affected_systems array>

**System: {system_name}**
- Current state: <what exists>
- Gap: <what's missing or broken>
- Files affected: <list files>

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
(or "N/A" if no backend work)

**iOS Work:**
- <Task 1>
- <Task 2>
(or "N/A" if no iOS work)

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
- iOS Research: `.workflow-logs/active/custom/{plan_name}/ios-research-<topic>.md` (if applicable)

---

### Checkpoint 2: <Name>

<Repeat format>

---

## Acceptance Criteria

<From exploration report acceptance_criteria>

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

---

## User Blockers (Complete Before Implementation)

<From exploration report user_blockers>

- [ ] Blocker 1
(or "None")

---

## Research Notes

**iOS Research Completed:**
<List topics researched in Stage 2>
(or "No iOS work")

**On-Demand Research (During Implementation):**
<From exploration report external_services_research>
- Agent will research these when implementing relevant checkpoint
- Confidence check: If <80% confident, agent MUST research

---

## Related Phases

<From exploration report related_phases>

**Phase {N}:** <relation explanation>

---

## Exploration Report

Attached: `.workflow-logs/active/custom/{plan_name}/exploration-report.json`

---

**Plan Created:** <date>
**Estimated Duration:** <X days/weeks>
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
For PHASE plans:
- Re-read `docs/phases/PHASE_{phase_number}_*.md`
- Ensure every deliverable from phase spec appears in checkpoints
- Verify no scope creep (only what's in phase spec)

For CUSTOM plans:
- Verify all affected_systems from exploration report are addressed
- Ensure checkpoints solve the problem statement
- Verify no scope creep beyond description provided

---

## Report

Provide concise report:

**For PHASE plans:**
```
Plan Created: plans/phase-{phase_number}-implementation-plan.md

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
- <Topic 1> researched → .workflow-logs/active/phases/phase-{phase_number}/ios-research-<topic>.md
- <Topic 2> researched
- <Or "No iOS work in this phase">

User Blockers:
- <Blocker 1> - User must complete before /implement-phase
- <Or "None - ready to implement">

Ready for Implementation: Yes/No
<If No, explain what's missing>

Next: Run /implement-phase {phase_number}
```

**For CUSTOM plans:**
```
Plan Created: plans/{plan_name}-plan.md

Summary:
- Problem: <1-sentence problem statement>
- Affected: <systems affected>
- Key decision: <technical decision>
- Complexity: <simple|medium|complex>

Exploration:
- Searched codebase for: <keywords>
- Found: <N files affected>
- Checkpoints: <N checkpoints defined>

iOS Research:
- <Topic 1> researched → .workflow-logs/active/custom/{plan_name}/ios-research-<topic>.md
- <Or "No iOS work">

Related Phases:
- <Phase N>: <relation>
- <Or "Independent work">

User Blockers:
- <Blocker 1>
- <Or "None - ready to implement">

Ready for Implementation: Yes/No
<If No, explain what's missing>

Next: Implement using plan as guide
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

**Plan Types:**
- PHASE plans: Structured phases from oracle/phases/*.md, full roadmap context
- CUSTOM plans: Ad-hoc intermediary work, focused codebase exploration
- Both use same checkpoint-driven approach, different exploration scope
