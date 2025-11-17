# Plan Custom Implementation

Create checkpoint-driven implementation plan for any task (features, fixes, refactors, optimizations) not covered by phase specs. Uses subagents to compress context and maintain focus.

## Usage

**For any non-phase task:**
```
/plan "celery alert matcher fixes"
/plan "iOS route list performance optimization"
/plan "add caching layer for GTFS patterns"
/plan "refactor stop search to use FTS5"
```

## Variables

task_description: $1 (required: description of what needs to be implemented/fixed)
additional_context: $2 (optional: constraints, requirements, background)

## Instructions

**IMPORTANT: Think hard. Activate reasoning mode for all planning decisions.**

---

## SETUP: Determine Plan Name

Create plan name from task description:

```
plan_name = sanitize($1)
  - Lowercase
  - Replace spaces with hyphens
  - Remove special characters (keep alphanumeric + hyphens)
  - Max 60 characters
  - Example: "celery alert matcher fixes" → "celery-alert-matcher-fixes"

Plan outputs:
  - Plan file: specs/{plan_name}-plan.md
  - Logs folder: .workflow-logs/custom/{plan_name}/
```

---

## Stage 1: Comprehensive Exploration (Subagent Context Compression)

**Purpose:** Offload heavy codebase reading to exploration subagent, return compressed reference document for planning.

**Create logging folder:**
```bash
mkdir -p .workflow-logs/custom/{plan_name}
```

### 1.1 Deploy Deep Exploration Subagent

Launch comprehensive exploration subagent to read ALL relevant code and produce structured reference:

```
Task tool:
- subagent_type: "Explore"
- model: "sonnet"
- description: "Deep exploration for {plan_name}"
- prompt: "
Your task: Read all relevant code for custom plan '{task_description}' and produce a structured JSON reference report.

Thoroughness: very thorough

PLAN CONTEXT:
- Plan name: {plan_name}
- Description: {task_description}
- Additional context: {additional_context or 'None'}
- Purpose: Ad-hoc planning for work not covered in phase specs

Read these documents:
1. oracle/DEVELOPMENT_STANDARDS.md (coding patterns - always)
2. Relevant architecture specs based on task description:
   - oracle/specs/SYSTEM_OVERVIEW.md (if unclear what task touches)
   - oracle/specs/DATA_ARCHITECTURE.md (if mentions: GTFS, database, caching, Redis, patterns)
   - oracle/specs/BACKEND_SPECIFICATION.md (if mentions: API, Celery, tasks, backend, routes)
   - oracle/specs/IOS_APP_SPECIFICATION.md (if mentions: iOS, Swift, UI, app, SwiftUI)
   - oracle/specs/INTEGRATION_CONTRACTS.md (if mentions: API contracts, auth, APNs, sync)
3. Current implementation state:
   - git status
   - git log --oneline -20 (recent commits for context)
   - Search codebase for files related to task description:
     * grep -r '<keywords from description>' backend/ --files-with-matches
     * grep -r '<keywords from description>' SydneyTransit/ --files-with-matches (if iOS work)
     * Find relevant files (stop when you have comprehensive coverage)
4. Existing artifacts (if relevant):
   - .workflow-logs/phases/phase-*/exploration-report.json (check recent phases)
   - .workflow-logs/custom/*/exploration-report.json (check related custom work)
   - specs/phase-*-implementation-plan.md (check if related work was planned)
   - specs/*-plan.md (check other custom plans)

ANALYSIS FOCUS:
- What does task description ask to solve/implement?
- What existing code/systems are affected?
- What architecture specs/patterns apply?
- What's missing from current implementation?
- What are the constraints (technical, cost, performance)?
- Is this fixing a bug, adding a feature, refactoring, or optimizing?

Return structured JSON (save to .workflow-logs/custom/{plan_name}/exploration-report.json):
{
  \"plan_type\": \"CUSTOM\",
  \"plan_name\": \"{plan_name}\",
  \"task_description\": \"{task_description}\",
  \"context_summary\": \"3-sentence overview: what problem this solves, current state, why needed\",
  \"task_type\": \"bug_fix|feature|refactor|optimization|other\",
  \"affected_systems\": [
    {
      \"system\": \"System name (e.g., Celery alert matcher, iOS route cache, GTFS parser)\",
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
      \"pattern\": \"Pattern name (e.g., Singleton DB client, Repository pattern)\",
      \"example_location\": \"backend/app/db/supabase_client.py:L10-25\",
      \"reference\": \"DEVELOPMENT_STANDARDS.md:Section 2\"
    }
  ],
  \"ios_research_needed\": [
    \"Topic 1\", \"Topic 2\"
  ] or [],
  \"external_services_research\": [
    \"Service pattern 1\", \"Service pattern 2\"
  ] or [],
  \"user_blockers\": [
    \"Blocker 1\"
  ] or [],
  \"acceptance_criteria\": [
    \"Custom criterion 1 (derived from task description)\",
    \"Custom criterion 2\"
  ],
  \"related_phases\": [
    {
      \"phase\": \"Phase 2\",
      \"relation\": \"This fixes bugs introduced in Phase 2 GTFS-RT polling\"
    }
  ] or [],
  \"estimated_complexity\": \"simple|medium|complex\",
  \"estimated_duration\": \"X hours or Y days\"
}

Token budget: Return concise JSON (~2000 tokens max). Main planner will reference this throughout.
"
```

**Save exploration output:**
```bash
# Subagent will return JSON - save it
echo '<subagent_json_output>' > .workflow-logs/custom/{plan_name}/exploration-report.json
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
- description: "iOS documentation research for {plan_name}"
- prompt: "
Your task: Research iOS topics for custom plan '{plan_name}' using Apple Documentation (SOSUMI MCP tools) and produce concise research files.

CONTEXT:
1. **Exploration Report:**
   Read .workflow-logs/custom/{plan_name}/exploration-report.json
   - Focus on `ios_research_needed` array (topics requiring research)
   - Reference `checkpoints` to understand where iOS patterns will be used

2. **Task Description:**
   {task_description}
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
   Save to: .workflow-logs/custom/{plan_name}/ios-research-<topic-slug>.md

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
- All files saved to .workflow-logs/custom/{plan_name}/

RETURN FORMAT (JSON):
{
  \"topics_researched\": [
    {
      \"topic\": \"SwiftUI refreshable modifier\",
      \"file\": \".workflow-logs/custom/{plan_name}/ios-research-swiftui-refreshable.md\",
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
echo '<subagent_json_output>' > .workflow-logs/custom/{plan_name}/ios-research-summary.json
```

---

## Stage 3: Ask User Questions (Max 3)

Review exploration report and identify ambiguities:

1. **Check user blockers:**
   - From exploration report `user_blockers` array
   - Ask if setup is complete (e.g., "Service credentials configured?")

2. **Clarify task ambiguity:**
   - If task description is vague, ask for specifics
   - Example: "Add caching" → "Cache at API level or database query level?"

3. **Verify assumptions:**
   - If exploration found conflicting patterns, ask for clarification
   - If high-risk operation (destructive changes, schema migrations), confirm intent

**If everything clear:** Say "No questions - ready to plan" and proceed.

**If questions exist:** Wait for user response before continuing.

---

## Stage 4: Create Checkpoint-Driven Plan

**Plan File:** `specs/{plan_name}-plan.md`

**Guidelines:**
- Use checkpoints (not step-by-step instructions)
- Each checkpoint = independently verifiable milestone
- Include references (not full specs)
- Design constraints (not implementation details)
- Backend + iOS work within each checkpoint

### Plan Template

```markdown
# {Plan Name} Implementation Plan

**Type:** Custom Plan (Ad-hoc)
**Context:** {task_description}
**Complexity:** {estimated_complexity from exploration}

---

## Problem Statement

{context_summary from exploration report}

---

## Affected Systems

{From exploration report affected_systems array}

**System: {system_name}**
- Current state: {what exists}
- Gap: {what's missing or broken}
- Files affected: {list files}

---

## Key Technical Decisions

{From exploration report key_decisions array}

1. **Decision name**
   - Rationale: {Why}
   - Reference: {FILE:LINE or Section}
   - Critical constraint: {Must-follow rule}

---

## Implementation Checkpoints

### Checkpoint 1: {Name}

**Goal:** {Specific success criteria}

**Backend Work:**
- {Task 1}
- {Task 2}
(or "N/A" if no backend work)

**iOS Work:**
- {Task 1}
- {Task 2}
(or "N/A" if no iOS work)

**Design Constraints:**
- Follow {REFERENCE} for {pattern}
- Use {specific library/approach}
- Must achieve {performance/size target}

**Validation:**
```bash
{Command to verify checkpoint complete}
# Expected: {specific output}
```

**References:**
- Pattern: {from exploration report critical_patterns}
- Architecture: {spec file:section}
- iOS Research: `.workflow-logs/custom/{plan_name}/ios-research-{topic}.md` (if applicable)

---

### Checkpoint 2: {Name}

{Repeat format}

---

## Acceptance Criteria

{From exploration report acceptance_criteria}

- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

---

## User Blockers (Complete Before Implementation)

{From exploration report user_blockers}

- [ ] Blocker 1
(or "None")

---

## Research Notes

**iOS Research Completed:**
{List topics researched in Stage 2}
(or "No iOS work")

**On-Demand Research (During Implementation):**
{From exploration report external_services_research}
- Agent will research these when implementing relevant checkpoint
- Confidence check: If <80% confident, agent MUST research

---

## Related Phases

{From exploration report related_phases}

**Phase {N}:** {relation explanation}
(or "Independent work")

---

## Exploration Report

Attached: `.workflow-logs/custom/{plan_name}/exploration-report.json`

---

**Plan Created:** {current date}
**Estimated Duration:** {estimated_duration from exploration}
```

---

## Stage 5: Validate Plan

**Checklist:**
- [ ] All checkpoints have clear goals + validation commands
- [ ] References point to specific files/sections (not vague)
- [ ] iOS research completed for all iOS work
- [ ] User blockers clearly listed
- [ ] Acceptance criteria derived from task description
- [ ] Each checkpoint independently testable

**Cross-check:**
- Verify all affected_systems from exploration report are addressed
- Ensure checkpoints solve the problem statement
- Verify no scope creep beyond task description provided

---

## Report

Provide concise report:

```
Plan Created: specs/{plan_name}-plan.md

Summary:
- Problem: {1-sentence problem statement}
- Affected: {systems affected}
- Key decision: {technical decision}
- Complexity: {estimated_complexity}

Exploration:
- Searched codebase for: {keywords}
- Found: {N files affected}
- Checkpoints: {N checkpoints defined}

iOS Research:
- {Topic 1} researched → .workflow-logs/custom/{plan_name}/ios-research-{topic}.md
- {Or "No iOS work"}

Related Phases:
- {Phase N}: {relation}
- {Or "Independent work"}

User Blockers:
- {Blocker 1}
- {Or "None - ready to implement"}

Ready for Implementation: Yes/No
{If No, explain what's missing}

Next: Run /implement {plan_name}
```

---

## Notes

**Context Management:**
- Main planner never reads full specs (exploration subagent does)
- Exploration JSON (~2K tokens) referenced throughout planning
- iOS research saved to files (loaded during implementation)
- Checkpoint structure enables progressive loading in implementation

**Token Savings:**
- Before: 10K+ tokens (full specs + codebase) → Main planner context
- After: 2K tokens (exploration JSON) → Main planner context
- Savings: ~80% context reduction while maintaining quality

**Plan Type:**
- Custom plans: Ad-hoc work not covered in phase specs
- Focused codebase exploration (keywords from task description)
- Checkpoint-driven approach (same as phase plans)
- Independent from phase roadmap
