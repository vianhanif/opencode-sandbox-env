---
name: review
description: Review code changes for correctness, risk, and consistency. Trigger whenever the user asks to review a diff, MR, PR, or branch. Also triggers when the user says "review", "look at these changes", "check this PR", "review against base/head", or similar. Used in both ad-hoc review and sprint-delegate workflows. Inherits from AGENTS.md reviewer rules.
disable-model-invocation: true
---

# Review Mode

**Do not rewrite production code.** Review and document findings only.

## Intake

Collect at session start:
1. **What to review** — diff, MR/PR URL, branch refs, or file set
2. **Base + head** — which refs define the change boundary (e.g. `main..feature/PROJ-123`)
3. **Context** — what changed and why (ticket, PR description, user summary)
4. **Review surface** — where to post findings: glab, git-review-cli, GitHub PR comment, or chat-only

If no diff or MR URL is provided → ask, STOP.

## Phases

### Phase 1 — Fetch

- Resolve diff from provided context:
  - GitLab MR: `glab mr diff {id}` or `git-review-cli {url} --deep`
  - Git branch: `git diff {base}..{head}`
  - Raw diff: use as provided
  - GitHub PR: `gh pr diff {owner}/{repo}#{number}`
- Confirm base and head refs match the stated intent
- If base/head is ambiguous → ask before proceeding

### Phase 2 — Analyze

- Read the diff only — do not read full files unless context requires it
- Classify each issue: logic bug, side effect, edge case miss, pattern inconsistency, security, performance
- Mark severity: critical / high / medium / low
- Document every assumption (behavior, data, backward compat, scope, environment)
- **Static analysis only — trust CI.** Do not run tests locally if CI is green. Only run tests when CI is unavailable or results are ambiguous.

### Phase 3 — Surface

- Output structured findings (see Output Format below)
- Post to the confirmed review surface (glab, git-review-cli, GitHub PR comment)
- If no surface configured → output to chat only

## Output Format

```markdown
## Review Summary
- **MR / Diff:** {ref or URL}
- **Reviewed by:** {agent}
- **Findings:** {N} issue(s) — {critical} critical, {high} high, {medium} medium, {low} low
- **Risk:** {low / medium / high}
- **Assumptions:** (listed below)
- **Recommendation:** {approve / request-changes / comment-only}

## Findings

### [{severity}] {title}
**File:** `{path:line}`  
**Problem:** {what is wrong or risky}  
**Evidence:** {why — code snippet or logic trace}  
**Fix (concise):** {recommended change}  
**Assumption:** {any implicit assumption made}

## Assumptions
- {list every assumption — behavior, data, backward compat, scope}

## Out of Scope
- {what was NOT reviewed and why}
```

## Rules

1. Review ONLY the given diff — do not rewrite or redesign the codebase
2. **Trust CI — static analysis only.** Do not run tests locally if CI pipeline is green
3. If CI is green → focus on code quality, not regression risk
4. Do NOT introduce new architecture or patterns not already in the codebase
5. If diff boundary is unclear → ask before proceeding
6. Surface findings to the confirmed review surface; do not silently drop output
7. If no code/diff is provided → ask for it, STOP
