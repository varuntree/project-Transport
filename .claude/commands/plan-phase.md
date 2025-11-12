# Plan Phase Implementation

Create a comprehensive implementation plan for the specified phase of the Sydney Transit App. This command integrates exploration, research, and detailed planning into a single workflow while preserving context through strategic use of subagents.

## Variables

phase_number: $1

## Instructions

**IMPORTANT: Think hard. Activate reasoning mode for all planning decisions.**

### Phase 1: Initial Context Gathering

**Read Required Documentation:**
- MUST READ: `oracle/phases/PHASE_{phase_number}_*.md` - The phase specification
- MUST READ: `oracle/DEVELOPMENT_STANDARDS.md` - Coding patterns and conventions
- MUST READ: `oracle/IMPLEMENTATION_ROADMAP.md` - Overall project timeline and phase dependencies
- MUST READ: Relevant architecture specifications based on phase:
  - `oracle/specs/SYSTEM_OVERVIEW.md` - Always read for project context
  - `oracle/specs/DATA_ARCHITECTURE.md` - If phase involves GTFS data, database, or caching (Phases 1-2)
  - `oracle/specs/BACKEND_SPECIFICATION.md` - If phase involves FastAPI, Celery, or backend (Phases 0-2, 5-7)
  - `oracle/specs/IOS_APP_SPECIFICATION.md` - If phase involves iOS UI (Phases 0-1, 3-4)
  - `oracle/specs/INTEGRATION_CONTRACTS.md` - If phase involves API contracts or auth (Phases 3, 5-6)

### Phase 2: High-Level Summary & User Questions

After reading all documentation:

1. **Provide High-Level Summary (3-5 sentences):**
   - What will be implemented in this phase
   - Key deliverables (backend, iOS, integration)
   - Major technical challenges or decisions
   - Dependencies on previous phases

2. **Ask Concise Questions (Maximum 3):**
   - ONLY ask if clarification is truly needed
   - Keep questions short and specific
   - Focus on ambiguous requirements or implementation choices
   - Examples:
     - "Phase plan mentions optional feature X - implement or defer?"
     - "NSW API key: use staging or production endpoint for testing?"
     - "Supabase: create new project or use existing?"
   - If everything is clear from documentation, say: "No questions - ready to proceed"

3. **Wait for User Response:**
   - User will answer questions or say "proceed"
   - Do NOT continue until user responds

### Phase 3: Exploration (Using Subagents - Preserve Main Context)

**IMPORTANT: Use Task tool with Explore subagent to preserve your context window.**

**Why Subagents for Exploration:**
- Main agent context is limited, valuable for planning logic
- Subagents offload file reading/searching to separate context
- Enables off-device, parallel exploration
- Returns only relevant summary (not full file contents)

#### 3.1 Identify Relevant Files

Before exploration, determine which files are critical for this phase:
- Backend files (from BACKEND_SPECIFICATION.md)
- iOS files (from IOS_APP_SPECIFICATION.md)
- Database schemas (if data layer changes)
- API contracts (if backend-iOS integration)

#### 3.2 Explore Previous Phase Implementation (if phase_number > 0)

Launch Explore subagent to understand what was built in previous phase(s):

```
Task tool:
- subagent_type: "Explore"
- description: "Explore Phase {phase_number - 1} implementation"
- prompt: "
  Your task: Understand the implementation state from Phase {phase_number - 1}.

  Thoroughness: medium

  Steps:
  1. Read specs/phase-{phase_number - 1}-implementation-plan.md (if exists)
  2. Check git log for phase-{phase_number - 1} commits (git log --grep='phase {phase_number - 1}' --oneline -20)
  3. Identify what files were created/modified in previous phase:
     - Backend: backend/app/**
     - iOS: SydneyTransit/**
     - Database: backend/schemas/migrations/**
  4. Review key implementation decisions from previous phase
  5. Identify any incomplete items or blockers

  Return summary:
  - What was implemented (backend, iOS, integration)
  - Key files created/modified
  - Current state of application (can it run? what works?)
  - Any issues or incomplete items
  - Anything Phase {phase_number} depends on
"
```

**What to look for from Explore agent:**
- Files that exist (backend structure, iOS structure, database schema)
- What functionality works (can test? can run app? APIs working?)
- Previous phase deliverables completed or not
- Technical debt or shortcuts taken

#### 3.3 Explore Current Codebase State (Always)

Launch Explore subagent to understand current project structure:

```
Task tool:
- subagent_type: "Explore"
- description: "Explore current codebase structure"
- prompt: "
  Your task: Understand current project structure and what exists.

  Thoroughness: quick

  Steps:
  1. Run: git ls-files | head -100
  2. Check backend structure: ls -R backend/app/ (if exists)
  3. Check iOS structure: ls -R SydneyTransit/ (if exists)
  4. Check if servers are running: lsof -i :8000 (backend), lsof -i :5173 (if applicable)
  5. Check git status for uncommitted changes

  Return summary:
  - Project structure (what folders exist)
  - Backend state (FastAPI app exists? Celery tasks? Database migrations?)
  - iOS state (Xcode project exists? Views? ViewModels?)
  - Any uncommitted changes or dirty state
"
```

### Phase 4: Research (Using Subagents When Needed)

**IMPORTANT: Only launch research subagents if phase involves complex integrations or unfamiliar technologies.**

#### 4.1 External Service Research (If Applicable)

**Trigger Research If Phase Involves:**
- Supabase setup, auth, RLS policies
- Railway deployment, Redis configuration
- Celery workers, Beat scheduling
- APNs certificates, push notifications
- NSW Transport API integration
- GTFS data parsing (gtfs-kit library)
- PostGIS geospatial queries

**How to Research:**
```
Task tool:
- subagent_type: "general-purpose"
- description: "Research {service/technology} best practices"
- prompt: "
  Your task: Research production patterns and best practices for {service/technology} in the context of our Sydney Transit App.

  Context:
  - We are implementing Phase {phase_number}: {brief description}
  - We need to integrate {specific service/technology}
  - Our constraints: solo developer, <$25/month budget, 0 users initially

  Research:
  1. Official documentation for {service/technology}
  2. Production patterns from similar transit apps or mobile apps
  3. Common pitfalls and how to avoid them
  4. Cost optimization strategies (if applicable)
  5. Security best practices (if handling auth/data)

  Return:
  - Quick start guide (key steps to integrate)
  - Code examples (if available)
  - Configuration recommendations for our constraints
  - Gotchas to watch out for
  - Relevant documentation links
"
```

**Examples:**
- Phase 0: Research Supabase project setup, Railway Redis provisioning
- Phase 3: Research Apple Sign-In OAuth flow, Supabase Auth integration
- Phase 6: Research APNs certificate generation, PyAPNs2 library usage

#### 4.2 iOS Documentation Research (If Applicable)

**Trigger iOS Research If Phase Involves:**
- SwiftUI views, navigation, state management
- GRDB database queries, migrations
- MapKit integration, annotations
- URLSession networking, async/await
- Keychain storage for tokens
- APNs registration, notification handling
- Core Location for nearby stops

**How to Research iOS:**

IMPORTANT: Use MCP tools to read iOS documentation. Check available MCP tools first, then use appropriate one for documentation lookup.

If MCP documentation tool is available (check for mcp__* tools related to docs/search):
```
Use MCP tool to search/read iOS documentation for:
- SwiftUI: {specific component or pattern}
- GRDB: {specific query or migration pattern}
- MapKit: {specific feature like annotations or overlays}
- URLSession: {async/await patterns}
- Keychain: {secure storage patterns}
- UserNotifications: {APNs registration and handling}

Return:
- Official Apple documentation summary
- Code examples
- Best practices for our use case
- SwiftUI-specific patterns (not UIKit)
```

If no MCP tool available, use WebSearch:
```
Search for: "SwiftUI {feature} iOS 16 best practices site:apple.com OR site:swiftbysundell.com"
```

**Examples:**
- Phase 1: Research GRDB WITHOUT ROWID tables, FTS5 search indexes
- Phase 2: Research SwiftUI List auto-refresh patterns, Timer publishers
- Phase 3: Research Sign in with Apple SwiftUI integration, Keychain storage
- Phase 4: Research MapKit SwiftUI polylines, coordinate regions

### Phase 5: Create Implementation Plan

**Now synthesize everything into a detailed plan.**

**Plan Storage:**
- Create file: `specs/phase-{phase_number}-implementation-plan.md`
- Use the exact `Plan Format` template below
- Replace ALL <placeholders> with detailed content
- Add as much detail as needed - this plan will be executed by another agent

**Plan Creation Guidelines:**
1. **Be Specific:** Don't say "implement API endpoint" - say "Create FastAPI endpoint GET /api/v1/stops/nearby with lat/lon query params, PostGIS ST_DWithin query, returns JSON array of stops"
2. **Reference Standards:** Cite DEVELOPMENT_STANDARDS.md sections (e.g., "Follow Section 2: Database Access Patterns for Supabase singleton client")
3. **Include Code Structure:** Specify file paths, class names, function signatures (not full implementation, just structure)
4. **Order Matters:** Backend foundation → iOS models → iOS UI → Integration → Testing
5. **Break Down Large Tasks:** If a task has >5 steps, break into sub-tasks
6. **Validation At End:** Always end with running acceptance criteria from phase plan

**What NOT to Include:**
- Don't write full code implementations (that's for implement-phase)
- Don't include "explore codebase" steps (already done)
- Don't add features not in phase plan (stick to scope)

### Phase 6: Final Checks Before Reporting

1. **Validate Plan Completeness:**
   - All phase deliverables covered?
   - User setup instructions included (if needed)?
   - Testing checklist matches phase acceptance criteria?
   - No missing prerequisites?

2. **Check Against Phase Plan:**
   - Re-read `oracle/phases/PHASE_{phase_number}_*.md`
   - Ensure every item in Implementation Checklist is in your plan
   - Verify acceptance criteria are testable

3. **Estimate Complexity:**
   - Simple: <1 week, <10 files, no external services
   - Medium: 1-2 weeks, 10-20 files, 1-2 external services
   - Complex: >2 weeks, >20 files, >2 external services, unfamiliar tech

## Plan Format

Use this exact template for `specs/phase-{phase_number}-implementation-plan.md`:

```md
# Phase {phase_number} Implementation Plan

**Phase Name:** <from phase plan, e.g., "Foundation", "Static Data + Basic UI">
**Duration:** <from phase plan, e.g., "1-2 weeks">
**Complexity:** <simple|medium|complex>

---

## Phase Overview

### Problem Statement
<what problem does this phase solve? why is it needed?>

### Solution Approach
<how will this phase solve the problem? key technical approach>

### User Story
**As a** <user type>
**I want** <capability>
**So that** <benefit>

### Goals
<high-level goals from phase plan, 2-3 sentences>

### Deliverables
**Backend:**
<list key backend deliverables>

**iOS:**
<list key iOS deliverables>

**Integration:**
<list integration points between backend and iOS>

### Success Criteria
<from phase plan acceptance criteria, summarize in 3-5 bullet points>

---

## Prerequisites

### Completed from Previous Phase
<if phase_number > 0, list what must be done from previous phase>
<if phase_number == 0, say "N/A - First phase">

### User Setup Required (Complete Before Implementation)
<from phase plan "User Instructions" section>
<list external tasks user must complete: accounts, API keys, downloads, etc.>
<if none, say "No user setup required for this phase">

### Environment Checks
<commands to verify prerequisites met, e.g.:>
- Backend running: `curl http://localhost:8000/health` returns 200
- Supabase connected: Check `.env` has SUPABASE_URL and keys
- Redis connected: `redis-cli -u $REDIS_URL PING` returns PONG
- iOS builds: Open Xcode, Cmd+B succeeds

---

## Implementation Steps

### Step 1: <First Major Task - Usually Backend Foundation>

**Purpose:** <why this step>

**Files to Create:**
- `path/to/file1.py` - <purpose>
- `path/to/file2.swift` - <purpose>

**Files to Modify:**
- `path/to/existing.py` - <what changes>

**Tasks:**
1. <Specific task with details>
   - Follow DEVELOPMENT_STANDARDS.md Section X
   - Example structure: <code outline if helpful>
2. <Next specific task>
3. <Test this step>
   - Command: <how to verify>
   - Expected: <what should happen>

**Reference:**
- Architecture Spec: <which section of DATA_ARCHITECTURE.md or BACKEND_SPECIFICATION.md>
- Standards: <which section of DEVELOPMENT_STANDARDS.md>

**Validation:**
Execute these commands to verify step completion:
```bash
<command 1>  # Expected output: <specific result>
<command 2>  # Expected output: <specific result>
```

---

### Step 2: <Second Major Task>

<repeat format from Step 1>

---

<continue with as many steps as needed to complete phase>

---

### Step N: Testing & Validation

**Purpose:** Verify all acceptance criteria met

**Backend Testing:**
1. <test command>
   - Expected: <result>
2. <test command>
   - Expected: <result>

**iOS Testing:**
1. <manual test step in simulator>
   - Expected: <result>
2. <manual test step>
   - Expected: <result>

**Integration Testing:**
1. <test that backend + iOS work together>
   - Expected: <result>

**Acceptance Criteria Checklist:**
<copy exact checklist from phase plan, convert to markdown checkboxes>
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] ...

---

## File Structure

### New Files to Create
```
backend/
  app/
    api/v1/
      <files>.py - <purpose>
    services/
      <files>.py - <purpose>
    tasks/
      <files>.py - <purpose>

SydneyTransit/
  Features/
    <Feature>/
      <files>.swift - <purpose>
  Core/
    <files>.swift - <purpose>
```

### Existing Files to Modify
- `backend/app/main.py` - <what changes>
- `SydneyTransit/SydneyTransitApp.swift` - <what changes>
- <list all files that will be modified>

---

## Technical Decisions

### Architecture Choices
<key architectural decisions made for this phase>
<reference Oracle-reviewed decisions from specs if applicable>

### External Dependencies
**Backend:**
- New packages: <list any new pip packages>
- Reasoning: <why needed>

**iOS:**
- New packages: <list any new Swift Package Manager dependencies>
- Reasoning: <why needed>

### Database Schema Changes
<if applicable, describe schema changes>
<reference migration file path>

### API Contracts
<if new APIs created, summarize endpoints>
<reference INTEGRATION_CONTRACTS.md section>

---

## Testing Strategy

### Unit Tests (If Applicable Post-MVP)
<describe unit tests if phase includes testing>
<for MVP phases, say: "Manual testing only for MVP - automated tests in Phase 8+">

### Manual Testing Checklist
<from phase plan acceptance criteria, make detailed checklist>

**Backend:**
- [ ] <test step with cURL command>
- [ ] <test step with log verification>

**iOS:**
- [ ] <test step in simulator>
- [ ] <test step with specific interaction>

**Integration:**
- [ ] <test step that exercises backend + iOS>

### Edge Cases to Test
<list edge cases from phase plan or identified during planning>

---

## Troubleshooting Guide

### Common Issues (Anticipated)
<from phase plan troubleshooting section>

**Issue:** <description>
- **Solution:** <fix>

**Issue:** <description>
- **Solution:** <fix>

### Validation Commands (Debugging)
<commands to debug if things don't work>

---

## Completion Criteria

### Deliverables Checklist
- [ ] Backend: <key deliverables>
- [ ] iOS: <key deliverables>
- [ ] Integration: <key deliverables>
- [ ] Documentation: README updated (if needed)
- [ ] Git: Changes committed to `phase-{phase_number}-*` branch

### Ready for Next Phase When:
- [ ] All acceptance criteria pass
- [ ] No critical bugs
- [ ] Code follows DEVELOPMENT_STANDARDS.md
- [ ] User can verify app works as expected

---

## Notes

### Implementation Notes
<any additional context helpful for implementation>
<gotchas discovered during planning>
<future considerations>

### Research Findings
<if research subagents were used, summarize key findings>
<link to documentation or patterns discovered>

### Blockers (If Any)
<list potential blockers identified during planning>
<how to resolve or escalate>

---

## Appendix

### Reference Documents
- Phase Specification: `oracle/phases/PHASE_{phase_number}_*.md`
- Development Standards: `oracle/DEVELOPMENT_STANDARDS.md`
- Architecture Specs: <list relevant specs>

### External Resources
<links to documentation referenced during research>

---

**Plan Created:** <date>
**Estimated Implementation Time:** <X days/weeks>
**Next Phase:** Phase {phase_number + 1} (if applicable)
```

---

## Report

After creating the plan, report:

1. **Plan Summary (3-5 bullet points):**
   - What will be implemented
   - Key technical decisions
   - Complexity level

2. **Plan File Path:**
   - Full path to created plan file

3. **Research Summary:**
   - What was researched (if any subagents used)
   - Key findings that influenced plan

4. **Concerns or Blockers:**
   - Any issues identified during planning
   - Missing prerequisites or unclear requirements

5. **Ready for Implementation:**
   - Yes/No
   - If No, what needs resolution before proceeding

**Example Report:**
```
Plan Created: specs/phase-1-implementation-plan.md

Summary:
- Implement GTFS parser with pattern model (8-15× compression)
- Create Supabase schema with PostGIS for geospatial queries
- Generate iOS SQLite (15-20MB) with dictionary coding
- Build iOS offline browsing UI (stops, routes, search)
- Complexity: Complex (GTFS parsing unfamiliar, PostGIS new)

Research Conducted:
- GTFS-RT patterns (found gtfs-kit library)
- PostGIS ST_DWithin queries (found examples)
- GRDB FTS5 search (found documentation)

Blockers: None
Ready for Implementation: Yes

Next: Run /implement-phase 1
```
