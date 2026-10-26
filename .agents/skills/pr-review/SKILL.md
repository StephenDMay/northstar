---
name: pr-review
description: >-
  Full PR gate — runs the build, linters, and the entire unit /
  integration / E2E test suite, then reviews the diff for correctness, code
  smells, and convention adherence. Use when the developer says '/pr-review',
  '/pr-review <PR#>', or '/pr-review <branch>'. Differs from the `code-review`
  skill: code-review is a static diff read; pr-review additionally executes
  the project's test suites and reports pass/fail before reviewing code.
---

You are a PR gatekeeper. Your job is to prove the PR actually works — not just read it — then review it for quality. A change that looks clean but breaks the test suite is a fail; report it as one.

Do not use TaskCreate, TaskUpdate, TaskGet, or TaskList tools. Do not edit source files — this skill reviews and reports, it does not fix. If a Blocker has an obvious one-line correction, you may propose it in the report, but leave applying it to the developer (or a follow-up `/imp` / manual edit).

## Efficiency

This skill runs a lot of commands with naturally verbose output (full diffs, test runners, stack traces). Keep it lean:

- **Detect each toolchain once.** Check `go version` (or `golangci-lint --version`, etc.) with a single command in one shell. If it's not found, mark that tool unavailable immediately and move on — do not retry the same check in a different shell or search the filesystem for the binary. One miss is a gap, not a puzzle to solve.
- **Don't load the same content twice.** Section 4 requires reading changed files in full via `Read` — so section 1 only needs the changed-file *list* (`git diff --stat` / `gh pr diff --name-only`), not the full unified diff text. Loading both the raw diff and the full file contents doubles context for no benefit.
- **Cap verbose command output.** Test/build tool output can run to thousands of lines on failure (full DOM trees, stack traces). Don't dump raw output into context — filter for the summary line and failure headlines first (e.g. `grep -E "FAIL|PASS|Tests |Test Files|error:"` / `Select-String -Pattern "..."`), and only pull the full detail for a specific failing test when you need the exact assertion to write up a Blocker.
- **Scope the pre-existing-failure check.** If failures show up in files the PR didn't touch, verify cheaply: spin up a throwaway worktree on the base branch and re-run *only those specific failing test files* (not the whole suite) with a minimal reporter. Remove the worktree immediately after. Re-running the full suite a second time to prove a handful of failures predate the PR is the single most expensive thing this skill can do for the least information.
- **Batch independent commands.** Parallelize tool calls that don't depend on each other (already the default per your general operating instructions) rather than round-tripping one at a time.
- Keep every user-facing message terse per your standing token-efficiency preference — this skill produces a lot of raw material, but what reaches the developer should be the distilled findings, not the transcripts that produced them.

## 1. Determine the review target

Parse `$ARGUMENTS`:

- **A PR number** (e.g. `42`, `#42`) — this is a GitHub PR review.
- **A branch name** — diff that branch against the repo default branch.
- **Empty** — review the current branch against the repo default branch.

Run in parallel:
```bash
git status
git rev-parse --abbrev-ref HEAD
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```
`BASE` = default branch from `gh repo view`, falling back to `main` then `master`.

If reviewing uncommitted work (`git status` shows changes) and the target is the current branch, include those changes in scope and say so explicitly — tests will reflect working-tree state, not just committed history.

**If a PR number was given:**
```bash
gh pr view <num> --json title,body,author,baseRefName,headRefName,url
gh pr diff <num> --name-only
```
State the PR title, author, and base/head branches. To run the test suite against the PR's actual code, you need it checked out locally:
- If the current worktree's branch already matches `headRefName`, proceed in place.
- Otherwise, tell the developer this skill needs to check out the PR branch (`gh pr checkout <num>`) to run tests, and confirm before doing it — checking out a branch changes what's on disk and could discard context if there's uncommitted work. If they decline, fall back to a diff-only review (skip section 3, note in the report that tests were not run).

**If a branch or the current branch was given:**
```bash
git merge-base HEAD origin/${BASE}   # or the target branch's merge-base
git diff <merge-base>...<target> --stat
```

List the changed files. This file list is the scope for section 4 (code review) — but section 3 (test suites) always runs full, unscoped, because a change in package A can break package B's tests. Don't also pull the full unified diff into context here — section 4 reads each changed file in full, which supersedes it (see Efficiency above).

## 2. Detect the stack and available tooling

Read the stack from `CLAUDE.md`, then confirm it from marker files (`go.mod`, `package.json`, `Cargo.toml`, `pyproject.toml` / `requirements.txt`). A repo can have more than one — e.g. a Go backend plus a `web/` frontend with its own `package.json`. Then check what's actually runnable — don't assume a tool exists just because the stack does:

| Check | Command | If missing |
|---|---|---|
| Build | marker file present | n/a |
| Linter | e.g. `golangci-lint --version`, a `lint` script in `package.json`, `cargo clippy --version`, `ruff --version` | Note absent; fall back to the built-in check (`go vet`, `tsc`) if there is one |
| Integration tests | e.g. `grep -rl "go:build integration"`, a `test:integration` script, a `tests/integration` dir | Note absent |
| Node scripts | `scripts` block of each `package.json` | Use whatever's defined; don't invent scripts |
| E2E | `playwright.config.*` or `cypress.config.*` | Note absent |
| DB-backed tests | `docker-compose.yml` present + test files that reference a DB connection | See section 3 |

Report this table's results to the developer before running anything, so gaps (no E2E, no lint script, etc.) are visible up front rather than silently skipped.

## 3. Run the full verification suite

Run every suite that exists. Do not stop at the first failure — collect all results, then report together.

| Stack | Commands |
|---|---|
| Go | `go build ./...`, `go vet ./...`, `golangci-lint run` (if available), `go test ./...` |
| Node / TS | `npm run build`, `npm run lint` (if the script exists), `npm test` — run from the directory that holds the `package.json` |
| Rust | `cargo build`, `cargo clippy`, `cargo test` |
| Python | `ruff check .` (if available), `pytest` |

**Integration tests** (only if section 2 found them): if they need a local DB from `docker-compose.yml`, check whether it's up with `docker compose ps`. If not, ask before starting it with `docker compose up -d` — it changes what's running on the developer's machine. Then run the integration command (e.g. `go test ./... -tags=integration`). If the repo has DB-backed code but no integration tests, say so plainly when presenting findings (section 6) rather than skipping silently. Respect any `CLAUDE.md` rules about which databases tests may touch.

**E2E** (only if section 2 found a config): run the project's E2E command (e.g. `npx playwright test`). If none exists, say so plainly when presenting findings. Do not fabricate a result.

For every command, capture: exit code, and on failure, the relevant error output (file:line where possible) — not the raw firehose. `vitest`/`playwright` failures can print full DOM trees or stack traces per assertion; filter to the summary + failing test names first (see Efficiency above) and only expand a specific failure's full output if you need the exact detail for a Blocker/Must-have writeup. A failing build or test is automatically a **Blocker** — it goes in the report even before you start the code review pass.

If a failure lands in a file outside the PR's changed-file list, it may predate the PR — verify per the scoped baseline-check technique in Efficiency above before assuming this PR caused it.

## 4. Code review pass

Scope: the changed files identified in section 1. Read each one in full (not just the diff hunks — surrounding context matters for correctness and consistency).

Before reviewing, load project context:
- `CLAUDE.md` (already in context)
- `<package>/DECISIONS.md` for every touched package — constraints already agreed on that new code must not violate
- `documents/decisions/*.md` whose topic overlaps the change
- The relevant `documents/capabilities/*.md` if the change maps to a tracked capability

Apply these checks:

**Correctness**
- Logic errors, wrong conditions, off-by-one
- Unhandled errors; ignored return values
- Nil/undefined dereferences without a guard
- Shared state mutated without synchronization (goroutines, concurrent map access)
- Race conditions around long-lived connections or streaming responses (WebSockets, SSE, background workers) — check for leaks and unclosed connections on early return

**Design**
- Functions do one thing
- No magic numbers/strings — named constants
- Dependency direction correct (e.g. a core package should not reach into the HTTP layer's internals)
- No abstraction built for a single call site
- State stores stay focused — no god-stores accumulating unrelated state

**Comments**
- Explain why, not what
- Non-obvious invariants and workarounds are called out at the point they matter

**Security**
- No hardcoded secrets/tokens/credentials
- External input (HTTP bodies, WebSocket messages, env vars) validated before use
- No SQL injection — check for string-built queries instead of parameterized ones
- No injection via LLM-constructed content rendered back into UI without sanitization

**Performance**
- Unnecessary allocations/copies in hot paths
- Cleanup that can leak on early return (DB connections, WS connections, goroutines)
- Unbounded growth (message history, caches)

Apply only the stack-specific sections for languages the PR touches.

**Stack-specific — Go**
- Exported identifiers have doc comments
- Every `err` is checked, no blank `_` discards
- `fmt.Errorf("...: %w", err)` wrapping, not string concatenation
- `context.Context` first param on I/O paths; honors cancellation
- `defer` placed immediately after resource acquisition
- Library and driver choices match what `documents/decisions/` and `DECISIONS.md` files lock in

**Stack-specific — TypeScript/React**
- No `any` — specific types or `unknown`
- Every promise is awaited or explicitly handled — no floating promises
- State lives where `CLAUDE.md`'s stack conventions say it should (e.g. server state vs. client state libraries) — flag state in the wrong place
- No `console.log` left in committed code
- Effects have correct dependency arrays; no stale closures

**Convention adherence**
- Matches patterns already established in `DECISIONS.md` files for touched packages
- New decisions that should have been recorded but weren't (per `CLAUDE.md`'s Decision Tracking rule) — flag as **Must-have** with a note to write the entry, don't write it yourself unless asked

For every finding, record the exact `file:line`.

## 5. Compile findings

Bucket everything from sections 3 and 4 together:

**Blockers** — failing build/tests/lint, correctness bugs, security issues, broken behavior — anything that must be fixed before this merges
**Must-have** — convention violations, missing error handling, undocumented decisions, design concerns; also any Blocker-tier item the developer chooses (in section 6) to track as follow-up rather than fix now
**Nit picks** — performance, style, optional improvements

Testing/tooling gaps from section 2 (no E2E suite, no lint script, etc.) are surfaced live in section 6, not carried into the written report as their own bucket — fold one in only if it's load-bearing enough to change the verdict (e.g. "tests could not be run at all," which itself becomes a Blocker).

Format each finding:
```
[BLOCKER] internal/agent/stream.go:112 — WS connection not closed on context cancellation
  Detail: If ctx is canceled mid-stream, the function returns without calling conn.Close(),
          leaking the connection.
  Suggestion: defer conn.Close() immediately after the connection is established.

[MUST-HAVE] web/src/hooks/useChat.ts:44 — floating promise on send()
  Detail: send() returns a Promise that's never awaited or .catch()'d; a rejected send
          fails silently.
  Suggestion: await it or attach .catch() to surface the error to the UI.
```

## 6. Present findings

This is a live triage conversation — show the developer everything needed to make a merge call, even though most of it won't carry into the written report:
1. Test/build/lint results (pass/fail per suite, from section 3)
2. Tooling/testing gaps (from section 2)
3. Blockers
4. Must-have
5. Nit picks

Ask which Blocker items actually block merge vs. can be downgraded to Must-have and tracked as follow-up. Do not proceed to section 7 until the developer has responded.

## 7. Write the report

Write to `scratchpad/pr-review-report.md` (overwrite each run). Keep it to findings and the call — no Target/Test Results/Gaps boilerplate; that lived in the section 6 conversation, not the artifact:

```markdown
# PR Review — <PR #/branch> — YYYY-MM-DD

## Verdict
<Ready to merge / Blocked on N item(s) / Blocked on failing tests>

## Blockers
- [ ] `file:line` — summary
  Detail: ...
  Suggestion: ...

## Must-have
- [ ] `file:line` — summary

## Nit picks
- [ ] `file:line` — summary
```

Omit any of the three finding sections entirely when empty rather than writing "None" — an absent section already reads as clean.

## 8. Record decisions (only if warranted)

Same bar as the `audit` skill: findings are not decisions. Only write to `<package>/DECISIONS.md` (or `documents/decisions/<topic>.md` for cross-cutting ones) when a finding reveals a constraint future code must not violate — not for routine bugs or style notes. If nothing rises to that level, skip this step.

## 9. Optional: post to the PR

Only offer this if the target in section 1 was a real GitHub PR. Ask explicitly before posting — this is a visible, shared-state action. If confirmed:
```bash
gh pr comment <num> --body-file scratchpad/pr-review-report.md
```
Never post automatically, and never post if any test command in section 3 could not be run to completion (say so instead of posting a partial result as if it were final).

## 10. Report back

Summarize in chat using the same structure as the report:
- Verdict
- Blockers (or "none")
- Must-have (or "none")
- Nit picks (or "none")
- Path to the full report: `scratchpad/pr-review-report.md`

No Target/Test Results/Gaps recap — that was covered live in section 6. Keep this summary short — the written report carries the detail.
