---
name: utest
description: Interactive unit test workflow — diffs the current branch, gets developer approval on a test plan, then writes and runs each test in sequence. Use when the developer says '/utest'.
---

## Rules (always on)
- Work from the branch diff before proposing any tests.
- Developer approval happens once, at the test plan — not per test. After the plan is approved, implement candidates one at a time, running each immediately after writing it, without stopping to ask.
- Target only impacted behaviors — no bulk generation or unrelated scaffolding.
- Keep tests isolated and deterministic: mock collaborators, avoid external I/O.
- Use clear naming and AAA style (Arrange / Act / Assert); prefer public APIs over reflection.
- **Write tests to files — never output test code only in chat.**
- **Run tests immediately after writing and report results.**
- **Surface any failures before moving to the next test.**

## Workflow

1. **Detect the stack** — Check for these files in the project root:

   | File | Stack | Test command |
   |---|---|---|
   | `go.mod` | Go | `go test ./...` |
   | `package.json` | Node / TS | `npm test` |
   | `Cargo.toml` | Rust | `cargo test` |
   | `requirements.txt` / `pyproject.toml` | Python | `pytest` |

   State the detected stack and test command before proceeding.

2. **Read the spec** — If `scratchpad/feature-spec.md` exists, read it for feature context and intended changes. Note which functions and files are in scope.

3. **Gather changes** — Detect the base branch dynamically, then capture the full diff:
   ```
   gh repo view --json defaultBranchRef -q .defaultBranchRef.name   # get base branch (fall back to main, then master)
   git merge-base HEAD <base>
   git diff <merge-base>...HEAD
   git diff --cached
   git status
   ```
   Skim the key hunks to understand what code was added or changed.

4. **Create test plan** — Propose a comprehensive unit test strategy. Write it to `scratchpad/test-plan.md` containing:
   - Test strategy overview
   - All test candidates with coverage areas (happy path, edge cases, error paths)
   - Status column for each: `pending` / `created` / `passed` / `failed`

5. **Present test plan** — Show the plan and wait for developer approval before writing any tests. This is the one checkpoint: the developer removes, edits, or adds candidates here, not per-test later.

6. **Implement the next candidate** — Once the plan is approved, work through candidates in order without asking again. For each: write only that test to the appropriate test file, keeping the diff minimal. Follow stack conventions:
   - **Go**: standard `testing` package; `testify/assert` if already a dependency; table-driven tests where appropriate
   - **TS**: match the existing test framework (Jest, Vitest, etc.)
   - **Rust**: `#[cfg(test)]` module with `#[test]` functions
   - **Python**: `pytest` with fixtures; `unittest.mock` for collaborators

7. **Update test plan** — Mark the test as `created` in `scratchpad/test-plan.md`.

8. **Run the test** — Execute the test command scoped to the new test if possible; otherwise run the full suite. Report results immediately.

9. **Update status** — Mark `passed` or `failed` in the test plan. If failed, surface the failure details, propose a fix, and continue — no need to pause for approval unless the fix requires a design choice only the developer can make.

10. **Iterate** — Repeat steps 6–9 for the next candidate. When all candidates are done, provide a final summary of the test plan status.

## Output
- `scratchpad/test-plan.md` — strategy and per-test status tracking
- Test files written to the appropriate test directories in the codebase
- Pass/fail result reported after each test is written
- Any bugs found during test execution surfaced immediately

## Error Handling
- If test creation fails, report the specific error and retry with an adjusted approach.
- If the test command is not in allowed tools for the detected stack, note it and ask the developer to run it manually.
- If no existing test structure is found, suggest where to create it before proceeding.
