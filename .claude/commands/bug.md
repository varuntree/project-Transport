# Bug Fix

Investigate and fix user-reported bugs through orchestrator-subagent pattern with 4-stage analysis: Map → Explore → Diagnose → Fix.

## Variables

bug_description: $1 (required: user description of bug)

## Instructions

**IMPORTANT: Think hard. Use reasoning mode for all diagnosis decisions.**

---

## Architecture

**Orchestrator (Main Agent):**
- Maintains bug context (~3K tokens, constant)
- Delegates to 4 specialized subagents
- Validates findings, coordinates fix
- Commits atomically
- Never drowns in codebase details

**4 Specialized Subagents:**
1. **Map Subagent:** Maps bug to phases/systems
2. **Explore Subagent:** Finds ALL relevant code across layers
3. **Diagnose Subagent:** First-principles root cause analysis
4. **Fix Subagent:** Minimal correct fix implementation

---

## Stage 1: Bug Intake & Mapping

**Orchestrator creates bug context:**

```bash
# Create bug log folder
timestamp=$(date +%s)
bug_slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr -s ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-40)
bug_folder=".bug-logs/${timestamp}-${bug_slug}"
mkdir -p "${bug_folder}"

# Save bug context
echo "{
  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
  \"bug_description\": \"$1\",
  \"bug_slug\": \"${bug_slug}\",
  \"reported_by\": \"user\"
}" > "${bug_folder}/bug-context.json"
```

### 1.1 Deploy Map Subagent

**Orchestrator delegates mapping:**

```
Task tool:
- subagent_type: "Explore"
- model: "sonnet"
- description: "Map bug to implementation phases"
- prompt: "
TASK: Map Bug to Implementation Phases/Systems

BUG DESCRIPTION:
$1

JOB:
Map this bug to:
1. Which phase(s) implemented the buggy feature
2. Which systems/layers are affected (Backend, iOS, GTFS data, Real-time polling, etc.)
3. Which files are likely involved

ACTIONS:

1. **Read Phase Completion Reports:**
   Find which phase(s) implemented related functionality:
   ```bash
   # Check all phase completion reports
   cat .phase-logs/phase-*/phase-completion.json 2>/dev/null || echo 'No phase logs found'

   # List phase implementation plans
   ls -la specs/phase-*-implementation-plan.md 2>/dev/null || echo 'No phase plans found'
   ```

2. **Search Codebase for Keywords:**
   Extract keywords from bug description, search codebase:
   ```bash
   # Search backend
   grep -r '<keyword>' backend/app/ --files-with-matches 2>/dev/null | head -20

   # Search iOS
   grep -r '<keyword>' SydneyTransit/ --files-with-matches 2>/dev/null | head -20
   ```

3. **Identify Affected Layers:**
   Based on bug description, determine:
   - iOS UI layer? (Views, ViewModels)
   - iOS Data layer? (Repositories, GRDB)
   - Backend API layer? (Routes, Services)
   - Backend Tasks layer? (Celery workers)
   - Data layer? (GTFS, GTFS-RT, Redis cache)

4. **Determine Primary Phase:**
   Based on findings, identify which phase is PRIMARY owner of buggy feature

RETURN FORMAT (JSON):
Save to: ${bug_folder}/map-result.json

{
  \"bug_summary\": \"1-sentence technical summary of bug\",
  \"affected_phases\": [
    {
      \"phase\": 2,
      \"confidence\": 0.9,
      \"reason\": \"Real-time departures implemented in Phase 2\"
    }
  ],
  \"affected_systems\": [
    {
      \"system\": \"iOS DeparturesView\",
      \"layer\": \"iOS UI\",
      \"files\": [\"SydneyTransit/Features/Departures/DeparturesView.swift\"]
    },
    {
      \"system\": \"Backend realtime API\",
      \"layer\": \"Backend API\",
      \"files\": [\"backend/app/api/v1/realtime.py\"]
    }
  ],
  \"keywords\": [\"departures\", \"refresh\", \"real-time\"],
  \"primary_phase\": 2,
  \"search_summary\": \"Found 12 files matching keywords, narrowed to 4 critical files\"
}

DO NOT:
- Diagnose root cause (that's Stage 3)
- Read full file contents (just map files)
- Make assumptions (if unclear, list multiple possibilities)

CONFIDENCE:
- If <80% confident on primary_phase, list affected_phases with confidence scores
- If keywords don't match any files, expand search or report blocker
"
```

**Wait for subagent completion.**

**Save result:**
```bash
# Map subagent returns JSON
# Validate it saved to ${bug_folder}/map-result.json
cat ${bug_folder}/map-result.json
```

---

## Stage 2: Deep Exploration

**Orchestrator loads map result:**

```bash
# Read primary phase and affected systems
primary_phase=$(cat ${bug_folder}/map-result.json | jq -r '.primary_phase')
affected_systems=$(cat ${bug_folder}/map-result.json | jq -c '.affected_systems')
```

### 2.1 Deploy Explore Subagent

**Orchestrator delegates exploration:**

```
Task tool:
- subagent_type: "Explore"
- model: "sonnet"
- description: "Deep exploration for bug fix"
- prompt: "
TASK: Find ALL Relevant Code Across Layers

BUG DESCRIPTION:
$1

MAP RESULT:
$(cat ${bug_folder}/map-result.json)

JOB:
Find ALL code relevant to this bug by tracing data flow across layers.

THOROUGHNESS: very thorough

ACTIONS:

1. **Read Affected Files (from map result):**
   For each file in affected_systems:
   - Read full file content
   - Identify key functions/components related to bug
   - Note line ranges for critical sections

2. **Trace Data Flow:**

   **For iOS bugs:**
   - UI Layer: Which View displays the bug?
   - ViewModel Layer: Which ViewModel manages state?
   - Repository Layer: Which Repository fetches data?
   - Network Layer: Which APIClient method calls backend?
   - Model Layer: Which data models are involved?

   **For Backend bugs:**
   - API Route: Which endpoint is called?
   - Service Layer: Which service handles business logic?
   - Database/Cache: Which DB/Redis queries run?
   - Celery Tasks: Which background tasks involved?
   - External APIs: Which NSW API calls made?

   **Trace both directions:**
   - Downstream: From user action → backend → data
   - Upstream: From data → backend → iOS → UI

3. **Search for Dependencies:**
   For each critical file/function:
   - Find imports/references
   - Find callers (who calls this function?)
   - Find callees (what does this function call?)
   - Search for related error handling

4. **Load Phase Artifacts (if applicable):**
   If primary_phase identified:
   ```bash
   # Read phase exploration report
   cat .phase-logs/phase-${primary_phase}/exploration-report.json

   # Check checkpoint designs (if available)
   ls -la .phase-logs/phase-${primary_phase}/checkpoint-*-design.md

   # Read relevant iOS research (if available)
   ls -la .phase-logs/phase-${primary_phase}/ios-research-*.md
   ```

5. **Identify Related Patterns:**
   Check DEVELOPMENT_STANDARDS.md for patterns used in affected code:
   - Logging patterns
   - Error handling patterns
   - State management patterns
   - Repository patterns
   - API envelope patterns

RETURN FORMAT (JSON):
Save to: ${bug_folder}/explore-result.json

{
  \"data_flow\": [
    {
      \"layer\": \"iOS UI\",
      \"component\": \"DeparturesView\",
      \"file\": \"SydneyTransit/Features/Departures/DeparturesView.swift\",
      \"line_range\": \"50-120\",
      \"purpose\": \"Displays departure list with pull-to-refresh\"
    },
    {
      \"layer\": \"iOS ViewModel\",
      \"component\": \"DeparturesViewModel.loadDepartures()\",
      \"file\": \"SydneyTransit/Features/Departures/DeparturesViewModel.swift\",
      \"line_range\": \"65-95\",
      \"purpose\": \"Fetches departures from repository, updates @Published state\"
    }
  ],
  \"relevant_files\": [
    {
      \"path\": \"SydneyTransit/Features/Departures/DeparturesView.swift\",
      \"reason\": \"UI displaying buggy behavior\",
      \"critical_sections\": [\"L50-80: refresh logic\", \"L100-120: list rendering\"]
    }
  ],
  \"related_patterns\": [
    {
      \"pattern\": \"Repository protocol pattern\",
      \"reference\": \"DEVELOPMENT_STANDARDS.md:Section 4\",
      \"used_in\": \"DeparturesViewModel uses RealtimeRepository protocol\"
    }
  ],
  \"phase_artifacts\": [
    {
      \"phase\": 2,
      \"checkpoint\": 3,
      \"design\": \".phase-logs/phase-2/checkpoint-3-design.md\",
      \"result\": \".phase-logs/phase-2/checkpoint-3-result.json\",
      \"relevant_sections\": \"Checkpoint 3 implemented real-time departures\"
    }
  ],
  \"exploration_summary\": \"Traced bug through 6 layers: iOS View → ViewModel → Repository → APIClient → Backend Route → Redis Cache. Found 8 relevant files.\"
}

DO NOT:
- Diagnose root cause yet (that's Stage 3)
- Make fixes (that's Stage 4)
- Skip layers (trace complete flow)

CONFIDENCE:
- If data flow incomplete, note gaps in exploration_summary
- If unsure about file relevance, include with confidence note
"
```

**Wait for subagent completion.**

**Save result:**
```bash
# Explore subagent returns JSON
# Validate it saved to ${bug_folder}/explore-result.json
cat ${bug_folder}/explore-result.json
```

---

## Stage 3: Root Cause Diagnosis

**Orchestrator loads explore result:**

```bash
# Read data flow and relevant files
cat ${bug_folder}/explore-result.json | jq '.data_flow'
```

### 3.1 Deploy Diagnose Subagent

**Orchestrator delegates diagnosis:**

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"  # CRITICAL: Must use Sonnet with reasoning
- description: "Diagnose bug root cause"
- prompt: "
TASK: First-Principles Root Cause Analysis

BUG DESCRIPTION:
$1

MAP RESULT:
$(cat ${bug_folder}/map-result.json)

EXPLORE RESULT:
$(cat ${bug_folder}/explore-result.json)

JOB:
Use first-principles thinking to identify root cause of bug.

**CRITICAL: Activate reasoning mode. Think deeply.**

ACTIONS:

1. **Read Implementation Files:**
   For each file in explore_result.relevant_files:
   - Read critical sections (line ranges from explore result)
   - Read surrounding context (understand full function/class)
   - Note actual implementation patterns

2. **Compare vs Specifications:**

   **Check Phase Artifacts (if available):**
   - Read checkpoint design (what was SUPPOSED to be implemented)
   - Read checkpoint result (what was CLAIMED to be implemented)
   - Compare actual code vs design

   **Check Development Standards:**
   - Read relevant sections from DEVELOPMENT_STANDARDS.md
   - Verify pattern compliance (from explore_result.related_patterns)

   **Check Architecture Specs:**
   - Backend bugs: oracle/specs/BACKEND_SPECIFICATION.md
   - iOS bugs: oracle/specs/IOS_APP_SPECIFICATION.md
   - Data bugs: oracle/specs/DATA_ARCHITECTURE.md

3. **Analyze Bug Behavior:**

   **Reproduce Bug Mentally:**
   - Trace execution path based on bug description
   - Follow data flow from explore result
   - Identify where behavior diverges from expected

   **Categorize Bug:**
   - logic_error: Wrong algorithm/condition
   - pattern_violation: Violates DEVELOPMENT_STANDARDS pattern
   - race_condition: Timing/concurrency issue
   - state_management: State not reset/updated correctly
   - error_handling_gap: Missing error handling
   - design_flaw: Original design flawed
   - external_issue: Third-party service/API issue

4. **Identify Root Cause:**

   **Use First Principles:**
   - What is the FUNDAMENTAL cause (not symptom)?
   - Why does this cause produce observed behavior?
   - What assumptions were violated?
   - Where is the single point of failure?

   **Provide Evidence:**
   - Specific line numbers
   - Actual vs expected behavior
   - Pattern violations
   - Missing logic

5. **Design Recommended Fix:**

   **Minimal Fix Approach:**
   - What's the SMALLEST change to fix root cause?
   - Which files must be modified?
   - What risks does fix introduce?
   - How to validate fix worked?

6. **Consider Alternatives:**

   **Alternative Diagnoses:**
   - List other possible root causes (if any)
   - Explain why you ruled them out
   - Confidence score for primary diagnosis

RETURN FORMAT (JSON):
Save to: ${bug_folder}/diagnosis-result.json

{
  \"root_cause\": {
    \"description\": \"DeparturesViewModel.loadDepartures() appends to departures array without clearing previous data, causing duplicates on refresh\",
    \"category\": \"logic_error\",
    \"confidence\": 0.95,
    \"evidence\": [
      \"Line 67 in DeparturesViewModel.swift: self.departures.append(contentsOf: newDepartures) - no clear before append\",
      \"Line 62: loadDepartures() called by .refreshable modifier, doesn't reset state\",
      \"No deduplication logic anywhere in ViewModel\"
    ],
    \"fundamental_cause\": \"State accumulation instead of state replacement on refresh\"
  },
  \"affected_layers\": [
    {
      \"layer\": \"iOS ViewModel\",
      \"file\": \"SydneyTransit/Features/Departures/DeparturesViewModel.swift\",
      \"lines\": [67, 72],
      \"issue\": \"Appends without clearing previous state\"
    }
  ],
  \"pattern_violations\": [
    {
      \"pattern\": \"State reset before async data load\",
      \"reference\": \".phase-logs/phase-2/ios-research-swiftui-refreshable.md\",
      \"violation\": \"Should clear array before fetch, or replace instead of append\"
    }
  ],
  \"recommended_fix\": {
    \"approach\": \"Add self.departures.removeAll() before fetch, or use assignment instead of append\",
    \"files_to_modify\": [\"SydneyTransit/Features/Departures/DeparturesViewModel.swift\"],
    \"specific_changes\": [
      \"Line 66: Add 'self.departures.removeAll()' before async fetch\",
      \"OR Line 67: Change append to assignment: 'self.departures = newDepartures'\"
    ],
    \"estimated_complexity\": \"simple\",
    \"risks\": [
      \"Must preserve isLoading state during clear to prevent UI flicker\",
      \"Verify no other code depends on append behavior\"
    ]
  },
  \"alternative_diagnoses\": [
    {
      \"theory\": \"Backend API returns duplicate departures\",
      \"confidence\": 0.1,
      \"ruled_out_by\": \"Checked backend/app/api/v1/realtime.py:L45-67, API uses Set for deduplication, returns unique departures\"
    }
  ],
  \"validation_plan\": {
    \"reproduction_steps\": [
      \"Open DeparturesView\",
      \"Pull to refresh\",
      \"Observe list doubles in size\"
    ],
    \"fix_validation\": [
      \"Apply fix\",
      \"Rebuild app\",
      \"Repeat reproduction steps\",
      \"Verify list size stays constant after refresh\"
    ]
  }
}

DO NOT:
- Implement fix yet (that's Stage 4)
- Guess if confidence <80% (return blocker status)
- Skip evidence (must cite specific lines)
- Make unrelated changes

CONFIDENCE CHECK:
- iOS bug + no iOS research files? Use Apple docs MCP (mcp__sosumi__searchAppleDocumentation)
- External service issue? Use WebFetch for official docs
- Pattern unclear? Read full DEVELOPMENT_STANDARDS.md section
- If confidence <80%: Return blocker status with research needed

BLOCKERS (if diagnosis confidence <80%):
{
  \"status\": \"blocked\",
  \"blocker\": {
    \"type\": \"uncertainty|missing_context|external_dependency\",
    \"description\": \"Cannot determine root cause with confidence\",
    \"requires\": \"research|user_input|service_investigation\",
    \"attempted_analysis\": [\"Checked X, Y, Z\"],
    \"missing_information\": [\"Need to know...\"]
  }
}
"
```

**Wait for subagent completion.**

**Save result:**
```bash
# Diagnose subagent returns JSON
# Validate it saved to ${bug_folder}/diagnosis-result.json
cat ${bug_folder}/diagnosis-result.json
```

**Orchestrator validates diagnosis:**

```bash
# Check confidence threshold
confidence=$(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.confidence // 0')

if (( $(echo "$confidence < 0.80" | bc -l) )); then
  echo "DIAGNOSIS CONFIDENCE TOO LOW: $confidence"
  echo "Review diagnosis-result.json for blockers"
  # STOP - report to user
  exit 1
fi
```

---

## Stage 4: Fix Implementation

**Orchestrator loads diagnosis:**

```bash
# Diagnosis passed confidence check
cat ${bug_folder}/diagnosis-result.json | jq '.recommended_fix'
```

### 4.1 Deploy Fix Subagent

**Orchestrator delegates fix:**

```
Task tool:
- subagent_type: "general-purpose"
- model: "sonnet"
- description: "Implement bug fix"
- prompt: "
TASK: Implement Minimal Bug Fix

BUG DESCRIPTION:
$1

DIAGNOSIS:
$(cat ${bug_folder}/diagnosis-result.json)

JOB:
Implement the minimal, correct fix based on diagnosis.

ACTIONS:

1. **Read Affected Files:**
   - Read files from diagnosis.files_to_modify
   - Understand current implementation
   - Locate exact lines to modify

2. **Apply Fix:**

   **Follow Recommended Approach:**
   - Use diagnosis.recommended_fix.approach as guide
   - Make ONLY changes specified in diagnosis.recommended_fix.specific_changes
   - Preserve all existing functionality

   **Follow Development Standards:**
   - Read relevant DEVELOPMENT_STANDARDS.md sections
   - Maintain existing patterns (logging, error handling, naming)
   - Add error handling if missing (only if related to fix)

   **iOS Fixes:**
   - If iOS research files mentioned in diagnosis, read them
   - Follow Apple patterns (SwiftUI, GRDB, etc.)
   - Maintain existing architecture (MVVM, Repository pattern)

   **Backend Fixes:**
   - Maintain API envelope pattern
   - Use structured logging
   - Follow DB/Redis client patterns

3. **Self-Validate:**

   **Compile Check:**
   - iOS: Would this compile? (check syntax, types, imports)
   - Backend: Would this pass Python syntax check?

   **Manual Trace:**
   - Trace execution with fix applied
   - Verify fix addresses root cause
   - Check no new bugs introduced

   **Risk Mitigation:**
   - Address risks from diagnosis.recommended_fix.risks
   - Verify assumptions hold

4. **Test Plan:**
   - Follow diagnosis.validation_plan.fix_validation
   - Add any additional manual test steps

RETURN FORMAT (JSON):
Save to: ${bug_folder}/fix-result.json

{
  \"status\": \"fixed|blocked|needs_more_research\",
  \"fix_applied\": {
    \"approach\": \"Added self.departures.removeAll() at line 66 before async fetch\",
    \"files_modified\": [\"SydneyTransit/Features/Departures/DeparturesViewModel.swift\"],
    \"diff_summary\": \"+1 line at L66: 'self.departures.removeAll()'\",
    \"patterns_followed\": [\"DEVELOPMENT_STANDARDS.md:Section 4 - State reset pattern\"]
  },
  \"validation\": {
    \"compile_check\": \"passed\",
    \"manual_trace\": \"Refresh now clears departures array, fetches fresh data from repository, assigns to self.departures - no duplicates\",
    \"risks_mitigated\": [
      \"isLoading state preserved (set before removeAll, cleared after fetch)\",
      \"Checked all callers of loadDepartures() - only refreshable and onAppear, both expect array replacement\"
    ],
    \"test_plan\": [
      \"Manual: Open DeparturesView in simulator\",
      \"Pull to refresh 3 times\",
      \"Verify departure count stays constant (no duplicates)\",
      \"Verify loading spinner shows during refresh\",
      \"Verify error handling still works (test with network off)\"
    ]
  },
  \"confidence\": 0.90,
  \"blockers\": []
}

BLOCKERS (if cannot fix):
{
  \"status\": \"blocked\",
  \"blocker\": {
    \"type\": \"implementation_uncertainty|external_dependency|design_flaw\",
    \"description\": \"Why fix cannot be implemented\",
    \"requires\": \"redesign|research|user_input\",
    \"attempted_fixes\": [\"Tried X, failed because Y\"]
  }
}

DO NOT:
- Commit to git (orchestrator handles)
- Make unrelated changes
- Skip validation steps
- Implement features beyond fix
- Change file structure

USE EDIT TOOL:
- Use Edit tool to apply changes
- Preserve exact indentation
- Make minimal edits (only lines needed for fix)
"
```

**Wait for subagent completion.**

**Save result:**
```bash
# Fix subagent returns JSON
# Validate it saved to ${bug_folder}/fix-result.json
cat ${bug_folder}/fix-result.json
```

---

## Stage 5: Orchestrator Validation & Commit

**Orchestrator validates fix:**

### 5.1 Check Fix Status

```bash
fix_status=$(cat ${bug_folder}/fix-result.json | jq -r '.status')

if [ "$fix_status" = "blocked" ]; then
  echo "FIX BLOCKED - Review fix-result.json"
  # Report blocker to user
  exit 1
fi
```

### 5.2 Independent Validation

**Orchestrator runs validation independently:**

```bash
# Backend fix - compile check
if [ -n "$(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.files_modified[] | select(contains("backend"))')" ]; then
  echo "Validating backend fix..."
  cd backend
  python -m py_compile $(cat ../${bug_folder}/fix-result.json | jq -r '.fix_applied.files_modified[] | select(contains("backend"))' | sed 's|backend/||')
  cd ..
fi

# iOS fix - Xcode build (if available)
if [ -n "$(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.files_modified[] | select(contains("SydneyTransit"))')" ]; then
  echo "Validating iOS fix..."
  # Note: Full Xcode build may not be automatable in CLI
  # At minimum, check Swift syntax
  # xcodebuild -scheme SydneyTransit -sdk iphonesimulator build
  echo "Manual: Build in Xcode to verify"
fi
```

### 5.3 Create Comprehensive Report

**Generate human-readable report:**

```bash
cat > ${bug_folder}/REPORT.md << 'REPORT_EOF'
# Bug Fix Report

**Bug:** $1

**Status:** $(cat ${bug_folder}/fix-result.json | jq -r '.status')

**Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

---

## Bug Summary

$(cat ${bug_folder}/map-result.json | jq -r '.bug_summary')

---

## Root Cause

**Category:** $(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.category')

**Description:**
$(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.description')

**Confidence:** $(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.confidence')

**Evidence:**
$(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.evidence[]' | sed 's/^/- /')

---

## Fix Applied

**Approach:**
$(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.approach')

**Files Modified:**
$(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.files_modified[]' | sed 's/^/- /')

**Changes:**
$(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.diff_summary')

---

## Validation

**Compile Check:** $(cat ${bug_folder}/fix-result.json | jq -r '.validation.compile_check')

**Manual Trace:**
$(cat ${bug_folder}/fix-result.json | jq -r '.validation.manual_trace')

**Test Plan:**
$(cat ${bug_folder}/fix-result.json | jq -r '.validation.test_plan[]' | sed 's/^/- /')

---

## Affected Systems

$(cat ${bug_folder}/map-result.json | jq -r '.affected_systems[] | "- **\(.system)** (\(.layer))"')

---

## Related Phase

**Primary Phase:** $(cat ${bug_folder}/map-result.json | jq -r '.primary_phase')

$(cat ${bug_folder}/explore-result.json | jq -r '.phase_artifacts[]? | "**Phase \(.phase) - Checkpoint \(.checkpoint):** \(.relevant_sections)"' | sed 's/^/- /')

---

## Fix Confidence

**Overall:** $(cat ${bug_folder}/fix-result.json | jq -r '.confidence')

---

## Logs

- Map: ${bug_folder}/map-result.json
- Explore: ${bug_folder}/explore-result.json
- Diagnosis: ${bug_folder}/diagnosis-result.json
- Fix: ${bug_folder}/fix-result.json

---

**Report Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)
REPORT_EOF
```

### 5.4 Commit Fix

**Orchestrator commits atomically:**

```bash
# Add modified files
cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.files_modified[]' | xargs git add

# Add bug logs
git add ${bug_folder}/

# Create commit
bug_summary=$(cat ${bug_folder}/map-result.json | jq -r '.bug_summary')
root_cause=$(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.description' | head -c 200)
fix_approach=$(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.approach' | head -c 200)
files_count=$(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.files_modified | length')

git commit -m "fix: ${bug_summary}

Root cause: ${root_cause}

Fix: ${fix_approach}

Affected: $(cat ${bug_folder}/map-result.json | jq -r '.affected_systems[].layer' | tr '\n' ',' | sed 's/,$//')
Files: ${files_count} modified

Diagnosis confidence: $(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.confidence')
Fix confidence: $(cat ${bug_folder}/fix-result.json | jq -r '.confidence')

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Tag
git tag "bug-fix-${timestamp}"
```

---

## Stage 6: Report to User

**Orchestrator provides concise summary:**

```
Bug Fixed: ${bug_summary}

Root Cause:
- Category: $(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.category')
- $(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.description')
- Confidence: $(cat ${bug_folder}/diagnosis-result.json | jq -r '.root_cause.confidence')

Fix Applied:
- $(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.approach')
- Files: $(cat ${bug_folder}/fix-result.json | jq -r '.fix_applied.files_modified | length') modified
- Confidence: $(cat ${bug_folder}/fix-result.json | jq -r '.confidence')

Affected Systems:
$(cat ${bug_folder}/map-result.json | jq -r '.affected_systems[] | "- \(.system) (\(.layer))"')

Related Phase: $(cat ${bug_folder}/map-result.json | jq -r '.primary_phase')

Validation:
- Compile: $(cat ${bug_folder}/fix-result.json | jq -r '.validation.compile_check')
- Test plan: $(cat ${bug_folder}/fix-result.json | jq -r '.validation.test_plan | length') steps

Test Plan (Manual):
$(cat ${bug_folder}/fix-result.json | jq -r '.validation.test_plan[]' | sed 's/^/  - /')

Full Report: ${bug_folder}/REPORT.md

Commit: $(git rev-parse HEAD | cut -c1-7)
Tag: bug-fix-${timestamp}
```

---

## Notes

**Architecture Benefits:**
- **Orchestrator:** Maintains clean ~3K context throughout
- **Map Subagent:** Finds needle in haystack (which phase/system)
- **Explore Subagent:** Comprehensive codebase traversal
- **Diagnose Subagent:** First-principles reasoning, no context pollution
- **Fix Subagent:** Focused implementation, fresh context

**Token Budget (estimated):**
- Orchestrator: ~3K constant
- Map: ~8K (phase logs + search)
- Explore: ~15K (thorough exploration)
- Diagnose: ~12K (code reading + reasoning)
- Fix: ~8K (implementation)
- **Total: ~46K** (vs single-agent 80K+ with context rot)

**Failure Modes:**
- **Map confidence <80%:** Reports uncertain mapping, user clarifies
- **Diagnosis confidence <80%:** Returns blocker, requires research
- **Fix blocked:** Returns reason, user decides (redesign/research/manual)

**Integration:**
- **Independent from /fix-bug:** That's for checkpoint validation failures
- **This is for:** User-reported bugs in production/testing
- **Can be called:** Anytime, with any bug description

**File Structure:**
```
.bug-logs/{timestamp}-{bug-slug}/
├── bug-context.json          # User input
├── map-result.json           # Stage 1 output
├── explore-result.json       # Stage 2 output
├── diagnosis-result.json     # Stage 3 output
├── fix-result.json           # Stage 4 output
└── REPORT.md                 # Human-readable report
```

**Validation:**
- Each subagent validated by orchestrator
- Independent compile checks
- Manual test plan generated
- Confidence thresholds enforced

**Success Criteria:**
- Map confidence ≥80% on primary phase
- Diagnosis confidence ≥80% on root cause
- Fix confidence ≥80% on implementation
- Compile check passes
- Manual test plan executable
