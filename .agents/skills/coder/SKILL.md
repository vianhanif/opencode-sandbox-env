---
name: coder
description: Implement code changes incrementally per task documentation. Trigger whenever the user indicates coding intent — "start coding", "implement", "fix", "add", "build", "make changes", "let's code", or similar. Also triggers for any @coder task via the delegate skill. Inherits from AGENTS.md coder rules.
disable-model-invocation: true
---

# Coder Mode

**Implement code changes incrementally per task documentation.**

## Intake

Collect at session start:
1. **Task documentation** — plan, ticket, or changelog entry describing what to implement
2. **Step** — which specific step or subtask to focus on (if task has multiple steps)
3. **Repo** — absolute path to the target repository
4. **Branch** — base branch and target branch (e.g. `main` → `feature/PROJ-123`)
5. **Worktree** — worktree path if using isolated worktree (format: `.worktrees/{ticket-id}-{short-desc}/`)

If no task documentation is provided → ask for it, STOP.
If no step is defined → summarize context, propose first step, ask for confirmation before proceeding.

## Phases

### Phase 1 — Setup

- Resolve project root: `git rev-parse --show-toplevel`
- If worktree required: confirm path with user, create via `git worktree add` (requires approval)
- Checkout target branch; create if needed (requires approval)
- Confirm lint/test commands from project tooling (package.json scripts, Makefile, etc.)

### Phase 2 — Implement

- Read task documentation and confirmed step
- Use lean-ctx ctx_compose to understand the affected code paths before editing
- Implement ONLY the confirmed step — no scope expansion
- Keep output minimal: diff or snippet only
- Run lint/typecheck after each change (requires approval if state-changing)

### Phase 3 — Verify

- If CI pipeline is available and green → trust CI, skip local tests
- If CI is unavailable or results ambiguous → run relevant tests locally (requires approval)
- If tests fail → fix the implementation, not the test scripts

### Phase 4 — Report

- Summarize: what changed, what files, what branch
- Note any skipped tests or lints and why
- Confirm next step or signal completion

## Worktree Isolation (MANDATORY for multi-agent workflows)

If working alongside other agents in the same repo:
- Each agent MUST use its own worktree: `.worktrees/{ticket-id}-{short-desc}/`
- Confirm path with user before creating
- Never work on the main checkout or default branch
- On completion: report worktree path for cleanup

## Rules

1. Implement ONLY the confirmed step — no redesign or scope expansion
2. **Approval before edits.** Every file edit, branch creation, worktree creation, or state-changing command requires explicit user approval. Present the exact diff or command and wait.
3. **Trust CI — static validation only.** Run tests locally only when CI is unavailable or results are ambiguous.
4. Always work incrementally — confirm each step before the next
5. Do not assume missing requirements — stop and ask if anything is unclear
6. If conversation becomes long or inconsistent → suggest a fresh session with a context summary
7. Run lint/typecheck after each change; fix errors before proceeding
8. Never modify test scripts to make a failing test pass — fix the source code instead
- Provide a short context summary for restart
