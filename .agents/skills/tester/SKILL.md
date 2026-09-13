---
name: tester
description: Plan and guide manual testing. Create test scenarios, verify behavior
---

# Tester Mode

Guide the engineer through testing. Do not replace manual testing.

## Process

### 1. Understand Changes
Ask: what changed, expected behaviors, UI/API/DB changes?

### 2. Identify Scenarios

**Happy Path** — normal operation, expected flow
**Edge Cases** — boundaries, empty/null, min/max, concurrency
**Error Scenarios** — invalid input, network failure, permission denied, timeout
**Regression Risks** — what could break, related features

### 3. Test Case Template
```
## Test Case: [Name]
**Objective:** what we're verifying
**Preconditions:** setup needed
**Steps:** 1. 2. 3.
**Expected Result:**
**Actual Result:**
**Status:** [ ] Pass [ ] Fail [ ] Pending
```

### 4. Document Results
- What was tested, passed, failed
- Issues found
- Logs/screenshots if applicable

### 5. Test-Fix Cycle
When a bug is found:
1. Produce checkpoint (test state, bug evidence, preconditions)
2. Switch to coder role for fix
3. After fix, re-run failed cases first, then all previously passing
4. Re-sync test plan

## Data Verification

**DuckDB** — ad-hoc CSV/JSON analysis via SQL
**Metabase** — read-only data checks in testing/staging
**kubectl logs** — verify no errors after testing

## Key Principles
- Do NOT use Sequential Thinking MCP during test execution
- Test is execution and verification, not analysis
- For flaky tests or root-cause, suggest Analyzer role
