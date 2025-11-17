# Test Implementation

Run tests to validate implementation correctness. Supports backend unit tests and validation commands from plans.

## Usage

```
/test backend        # Run backend unit tests only
/test validation     # Run validation commands from plan
/test all           # Run both backend + validation
```

## Variables

scope: $1 (required: backend|validation|all)

## Instructions

**IMPORTANT: Think hard. Verify all tests thoroughly.**

---

## Stage 1: Detect Context

**Determine what was recently implemented:**

1. **Check git for changed files:**
   ```bash
   # Get changed files since last tag or main
   git diff --name-only main...HEAD 2>/dev/null || git diff --name-only HEAD~5...HEAD
   ```

2. **Find most recent plan:**
   ```bash
   # Check for active custom plan
   most_recent_custom=$(ls -t .workflow-logs/custom/*/completion-report.json 2>/dev/null | head -1)
   plan_name_custom=$(echo $most_recent_custom | cut -d'/' -f3)

   # Check for active phase plan
   most_recent_phase=$(ls -t .workflow-logs/phases/phase-*/phase-completion.json 2>/dev/null | head -1)
   phase_number=$(echo $most_recent_phase | grep -oP 'phase-\K\d+')

   # Determine which is more recent
   if [ -n "$most_recent_custom" ] && [ "$most_recent_custom" -nt "$most_recent_phase" ]; then
     plan_type="custom"
     plan_ref="$plan_name_custom"
     plan_file="specs/${plan_name_custom}-plan.md"
   elif [ -n "$most_recent_phase" ]; then
     plan_type="phase"
     plan_ref="phase-${phase_number}"
     plan_file="specs/phase-${phase_number}-implementation-plan.md"
   else
     plan_type="none"
     plan_ref="unknown"
     plan_file=""
   fi
   ```

3. **Create test context:**
   ```bash
   timestamp=$(date +%s)
   test_log_dir=".workflow-logs/tests/${timestamp}"
   mkdir -p "${test_log_dir}"

   echo "{
     \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
     \"scope\": \"$1\",
     \"plan_type\": \"${plan_type}\",
     \"plan_ref\": \"${plan_ref}\",
     \"changed_files\": []
   }" > "${test_log_dir}/test-context.json"
   ```

---

## Stage 2: Run Tests by Scope

### If scope = "backend"

**Run backend unit tests for changed files:**

1. **Identify backend test files:**
   ```bash
   # Get changed backend files
   changed_backend=$(git diff --name-only main...HEAD | grep '^backend/' || echo "")

   if [ -z "$changed_backend" ]; then
     echo "No backend files changed - skipping backend tests"
   else
     # Map files to test files
     test_files=""
     for file in $changed_backend; do
       # Extract module name (e.g., backend/app/api/v1/stops.py → test_stops.py)
       basename=$(basename "$file" .py)
       if [ "$basename" != "__init__" ]; then
         test_file="backend/tests/test_${basename}.py"
         if [ -f "$test_file" ]; then
           test_files="$test_files $test_file"
         fi
       fi
     done
   fi
   ```

2. **Run pytest:**
   ```bash
   cd backend
   source venv/bin/activate

   if [ -n "$test_files" ]; then
     pytest $test_files -v --tb=short --json-report --json-report-file="../${test_log_dir}/backend-results.json" 2>&1 | tee "../${test_log_dir}/backend-output.txt"
   else
     # No specific test files, run all tests
     pytest tests/ -v --tb=short --json-report --json-report-file="../${test_log_dir}/backend-results.json" 2>&1 | tee "../${test_log_dir}/backend-output.txt"
   fi

   backend_exit_code=$?
   cd ..
   ```

3. **Save results:**
   ```bash
   echo "{
     \"status\": \"$([ $backend_exit_code -eq 0 ] && echo 'passed' || echo 'failed')\",
     \"exit_code\": $backend_exit_code,
     \"test_files\": \"$test_files\",
     \"output_file\": \"${test_log_dir}/backend-output.txt\"
   }" > "${test_log_dir}/backend-summary.json"
   ```

---

### If scope = "validation"

**Run validation commands from plan checkpoints:**

1. **Extract validation commands from plan:**
   ```bash
   if [ -f "$plan_file" ]; then
     # Parse markdown to extract validation commands from each checkpoint
     # Look for ```bash blocks under "**Validation:**" sections

     validation_commands=()
     checkpoint_num=0

     # This is a simplified extraction - in practice, parse markdown properly
     while IFS= read -r line; do
       if [[ "$line" =~ ^\#\#\#\ Checkpoint\ ([0-9]+): ]]; then
         checkpoint_num="${BASH_REMATCH[1]}"
       elif [[ "$line" == "**Validation:**" ]]; then
         in_validation=true
       elif [[ "$in_validation" == true ]] && [[ "$line" =~ ^\`\`\`bash ]]; then
         in_code_block=true
       elif [[ "$in_code_block" == true ]] && [[ "$line" =~ ^\`\`\` ]]; then
         in_code_block=false
         in_validation=false
       elif [[ "$in_code_block" == true ]]; then
         # Extract command (skip comments starting with #)
         if [[ ! "$line" =~ ^# ]]; then
           validation_commands+=("$checkpoint_num|$line")
         fi
       fi
     done < "$plan_file"
   else
     echo "No plan file found - cannot run validation tests"
     validation_commands=()
   fi
   ```

2. **Execute each validation command:**
   ```bash
   validation_results=()

   for cmd_entry in "${validation_commands[@]}"; do
     checkpoint=$(echo "$cmd_entry" | cut -d'|' -f1)
     cmd=$(echo "$cmd_entry" | cut -d'|' -f2-)

     echo "Running Checkpoint $checkpoint validation: $cmd"

     # Execute command and capture output
     output=$(eval "$cmd" 2>&1)
     exit_code=$?

     validation_results+=("{
       \"checkpoint\": $checkpoint,
       \"command\": \"$cmd\",
       \"exit_code\": $exit_code,
       \"status\": \"$([ $exit_code -eq 0 ] && echo 'passed' || echo 'failed')\",
       \"output\": \"$(echo "$output" | head -c 500)\"
     }")
   done
   ```

3. **Save validation results:**
   ```bash
   echo "{
     \"plan_file\": \"$plan_file\",
     \"total_validations\": ${#validation_commands[@]},
     \"results\": [$(IFS=,; echo "${validation_results[*]}")]
   }" > "${test_log_dir}/validation-results.json"

   # Calculate pass/fail
   passed_count=$(echo "${validation_results[@]}" | grep -o '"passed"' | wc -l)
   failed_count=$(echo "${validation_results[@]}" | grep -o '"failed"' | wc -l)
   ```

---

### If scope = "all"

**Run both backend and validation tests:**

1. Execute backend tests (as above)
2. Execute validation tests (as above)
3. Combine results

---

## Stage 3: Generate Report

**Create comprehensive test report:**

`.workflow-logs/tests/{timestamp}/REPORT.md`:

```markdown
# Test Report

**Timestamp:** {current timestamp}
**Scope:** {scope}
**Plan:** {plan_ref} ({plan_type})

---

## Context

**Changed Files:**
{list changed files from git diff}

**Plan Reference:**
- Type: {plan_type}
- Plan: {plan_ref}
- File: {plan_file}

---

## Backend Tests

{If scope includes backend}

**Status:** ✅ Passed | ❌ Failed

**Test Files Run:**
{list test files}

**Results:**
- Total: {total_tests}
- Passed: {passed_count} ({percentage}%)
- Failed: {failed_count} ({percentage}%)
- Duration: {duration}s

### Passed Tests ({passed_count}):
- test_file.py::test_name ✅ (0.15s)
- test_file.py::test_name2 ✅ (0.23s)
...

### Failed Tests ({failed_count}):
- test_file.py::test_name ❌ (0.45s)
  ```
  AssertionError: Expected X, got Y
  File: test_file.py:67
  ```
...

**Full Output:** `{test_log_dir}/backend-output.txt`

{If scope does not include backend}
**Skipped** - Not requested

---

## Validation Tests

{If scope includes validation}

**Status:** ✅ Passed | ❌ Failed

**Checkpoints Validated:** {checkpoint_count}

### Checkpoint 1 Validation:
**Command:**
```bash
curl http://localhost:8000/api/v1/stops/200060
```

**Expected:** Response with stop data
**Status:** ✅ Pass
**Output:**
```json
{"data": {"stop_id": "200060", ...}}
```

### Checkpoint 2 Validation:
**Command:**
```bash
curl http://localhost:8000/api/v1/departures?stop_id=200060
```

**Expected:** Departures list
**Status:** ❌ Fail
**Output:**
```json
{"error": {"code": "STOP_NOT_FOUND", ...}}
```

{If scope does not include validation}
**Skipped** - Not requested

---

## Summary

**Overall Status:** {✅ PASSED | ❌ FAILED}

**Backend:**
- Tests: {passed}/{total} passed
- Status: {✅|❌}

**Validation:**
- Commands: {passed}/{total} passed
- Status: {✅|❌}

**Total Duration:** {duration}s

---

## Next Steps

{If all passed}
✅ All tests passed - Ready for merge

{If any failed}
❌ {failed_count} test(s) failed - Must fix before merge

**Failed items:**
1. {test/validation that failed}
2. {test/validation that failed}

**Recommended actions:**
1. Fix failing tests
2. Re-run: `/test {scope}`
3. Once all pass, proceed with merge

---

**Report Location:** `.workflow-logs/tests/{timestamp}/REPORT.md`
**Test Context:** `.workflow-logs/tests/{timestamp}/test-context.json`
**Backend Results:** `.workflow-logs/tests/{timestamp}/backend-results.json`
**Validation Results:** `.workflow-logs/tests/{timestamp}/validation-results.json`
```

---

## Stage 4: Report to User

**Provide concise summary:**

```
Test Report: {timestamp}

Scope: {scope}
Plan: {plan_ref}

{If backend tests run}
Backend Tests:
- Status: {✅ Passed | ❌ Failed}
- Results: {passed}/{total} passed ({percentage}%)
- Duration: {duration}s
{If failed}
- Failed: {list failed test names}

{If validation tests run}
Validation Tests:
- Status: {✅ Passed | ❌ Failed}
- Results: {passed}/{total} checkpoints validated
{If failed}
- Failed checkpoints: {list checkpoint numbers}

Overall Status: {✅ PASSED | ❌ FAILED}

{If passed}
✅ All tests passed - Ready for merge

{If failed}
❌ {total_failed} test(s) failed

Next Steps:
1. Review failures in: .workflow-logs/tests/{timestamp}/REPORT.md
2. Fix failing tests/validations
3. Re-run: /test {scope}

Full Report: .workflow-logs/tests/{timestamp}/REPORT.md
```

---

## Notes

**Scope Options:**
- `backend`: Backend unit tests only (pytest)
- `validation`: Validation commands from plan checkpoints
- `all`: Both backend + validation

**Test Discovery:**
- Changed files detected via git diff
- Test files mapped from implementation files
- Validation commands extracted from plan markdown

**Integration with Plans:**
- Reads validation commands from checkpoint specifications
- Executes commands in order
- Compares actual vs expected output

**When to Run:**
- After `/implement` completes
- Before merging to main
- After fixing bugs (verify fix worked)
- Before creating pull request

**Test Artifacts:**
- All results saved to `.workflow-logs/tests/{timestamp}/`
- JSON format for programmatic access
- Markdown report for human review
- Raw output files for debugging
