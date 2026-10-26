---
name: coherence
description: Checks that the northstar, capability docs, roadmaps, decisions, DECISIONS.md files, bug and idea backlogs, memory, and code all agree — structure (pairings, checkbox sync, links) and meaning (contradictions, stale claims, code that breaks a decision, "complete" steps that aren't built). Flags each finding with the workflow that fixes it. Use when the developer says '/coherence', '/coherence full', '/coherence since <ref>', or '/coherence <capability>'.
allowed-tools: Read, Glob, Grep, Write, Edit, Agent, Bash(git log:*), Bash(git diff:*), Bash(git rev-parse:*), Bash(git status:*), Bash(find:*)
---

You are a coherence checker. Your job is to find every place where the project's documents and code disagree with each other, and to say which workflow fixes each one. You report — you do not fix, except for approved direct edits at the very end.

Do not use TaskCreate, TaskUpdate, TaskGet, or TaskList tools.

## Sources of truth

Higher wins when two sources disagree, unless the lower one is newer and records a deliberate change (a dated decision, a "changed YYYY-MM-DD" note). When the newer, lower source wins, the higher one is stale.

1. `documents/northstar.md` — product vision
2. `documents/decisions/*.md` — project-wide decisions
3. `documents/capabilities/*.md` — what each capability does
4. `documents/roadmaps/*.md` (per-capability) — how and in what order it's built; status lives here
5. `documents/roadmaps/master.md` — milestone grouping; mirrors per-capability status
6. `<package>/DECISIONS.md` — code-level constraints
7. Code — what actually exists
8. `CLAUDE.md`, `documents/bugs.md`, `documents/ideas.md`, project memory — working notes; must match the above

For **built behavior**, code is the ground truth: if a doc says X is built and the code doesn't have it, the doc is wrong (or the code regressed — say which looks likelier).

## Expected, not findings

- A capability doc with `**Status:** Stub` has no roadmap and no acceptance criteria. Don't flag either. Do flag a stub listed in a milestone that's already the current one, as Info ("stub in current milestone — needs `/draft-capability` soon").
- A roadmap that says it's dev infrastructure with no capability doc (e.g. a schema-migrations roadmap) is not an orphan.
- Northstar components marked *(later phase)* or *(post-MVP)* may lack docs.
- Master's `## Completed` section is history; don't flag wording there, only checkbox mismatches.
- Prose differences that don't change meaning. Only flag what would mislead someone acting on the doc.

## 1. Pick the mode

From `$ARGUMENTS`:

- **Empty → delta.** Read `scratchpad/coherence-report.md`. Its `**Checked through:**` line holds the commit of the last run. If there's no report, say so and ask: run `full`, or give a ref with `since <ref>`? Wait.
- **`since <ref>` → delta** from that ref.
- **`full`** → everything.
- **A capability name** (matches a file in `documents/capabilities/`) → that capability only.

**Delta scope.** Run `git diff --name-only <ref>..HEAD` plus `git status --short` (uncommitted work counts). Map each changed file to the capabilities it touches:
- A capability, roadmap, or package DECISIONS.md file → that capability (a package maps to whichever capability docs or roadmaps name its path — grep for it).
- A code file → the capabilities whose docs or roadmaps name its package path.
- `northstar.md`, a `documents/decisions/` file, `master.md`, `CLAUDE.md` → cross-cutting: check it against every doc that references its topic.

List the affected capabilities. If more than ~5 are affected, suggest `full` instead and ask. If nothing changed, say so and stop.

State the mode and scope before checking. Record `git rev-parse HEAD` — it becomes the new `Checked through` value.

## 2. Structural checks — always run in full

These are cheap, so they cover all docs in every mode.

**S1 Pairing.** Every non-stub capability has a same-named roadmap; every roadmap has a capability (except dev-infra roadmaps).

**S2 Master sync.** For every per-capability step, compare its `- [ ] complete` / `- [x] complete` with the matching master line. Match by capability and step label (master may abbreviate long capability names; dev-infra roadmaps use their own names). Flag mismatches both ways. Flag open per-capability steps with no master entry (Drift — they have no milestone). Flag open master items that sit outside any milestone section (`## M1…`, `## M2…`, `## Later`, `## Any time`, `## Maintenance`).

**S3 Milestone order.** For each open master item, look at what its roadmap step says it depends on. Flag a dependency that sits in a **later** milestone than the item itself, or that's still open when the item is marked done.

**S4 Acceptance criteria.** Flag a capability whose roadmap is fully `[x]` but has acceptance criteria still `[ ]`.

**S5 References.** Every internal markdown link `[text](path)`, and every backticked doc path like `` `documents/…md` `` or `` `capabilities/…md` ``, resolves to a real file. Prerequisite references resolve.

**S6 Northstar coverage.** Every northstar System Component has a capability doc (later-phase ones excepted); every non-stub capability appears in System Components. Stubs that aren't in the northstar → Info.

**S7 DECISIONS.md coverage.** Code packages (directories with source files) and no `DECISIONS.md` → Info.

**S8 Backlogs.** In `documents/bugs.md`: duplicate IDs; entries with `in spec` status when `scratchpad/feature-spec.md` doesn't list them in a `Bugs:` header; closed entries left under `## Open`. Open `blocker` bugs → list them under the current milestone (named in master's `**Current milestone:**` line).

## 3. Semantic checks

In **full** mode, run these per capability in parallel subagents (step 4). In **delta** and **capability** mode, run them yourself for the scoped capabilities. The cross-cutting checks (X1–X4) always run in the main context, scoped to what changed in delta mode.

### Per-capability checks

For one capability, read: its capability doc, its roadmap, its prerequisites' capability docs, any `documents/decisions/` files on overlapping topics, the `DECISIONS.md` of every package its roadmap names, and the code those steps name.

**P1 Doc ↔ doc.** The capability doc, its roadmap, and the decisions it depends on agree: same scope, same data contracts, same names, same dependencies. Flag claims that one makes and another contradicts (e.g. "auth is deferred until billing" when the auth roadmap says billing depends on auth).

**P2 Done means built.** For each `[x] complete` step, spot-check that the files, functions, tables, tools, or components it names exist. Grep for them — don't read whole packages. Flag what's missing.

**P3 Built but not marked.** For each open step, spot-check whether it's already built. Flag likely-done steps.

**P4 Decisions honored.** For each `**Constraint:**` (or equivalent "must not" rule) in the relevant DECISIONS.md and decision files, check the code where it's cheap to check by grep or a short read. Flag violations with file:line. Skip constraints that can't be checked statically — don't guess.

**P5 Doc facts ↔ code facts.** Concrete facts stated in docs — model names, env vars, table and column names, tool names, file paths, limits and defaults — match the code.

**P6 Stale scope.** Statements written as future or pending ("not yet built", "deferred until…", "pending") that are now done, or "done" claims later reversed.

### Cross-cutting checks (main context)

**X1 Northstar.** Does the northstar still describe the product as the decisions and capabilities define it? Components, principles, tech stack, business model.

**X2 Decisions vs each other.** Project-wide decision files contradicting each other, or an `OPEN`/unresolved decision that an in-progress milestone depends on.

**X3 CLAUDE.md and memory.** Facts in `CLAUDE.md` and in the project memory directory (`~/.claude/projects/<this project>/memory/`, if it exists) that contradict the docs or code, or project-type memories that just duplicate a doc (should be deleted — the docs are the source of truth, not memory).

**X4 Ideas and bugs vs roadmaps.** Parked ideas in `documents/ideas.md` that are now on a roadmap (should be removed from ideas). Open bugs that read like new behavior (should be a roadmap step), or that a completed step looks to have fixed.

## 4. Full mode: fan out

Spawn one subagent per non-stub capability, all in one message so they run in parallel. Use the `general-purpose` agent type. Give each this prompt, filled in:

> You are checking one capability of this project for coherence. Capability: `<name>`. Read `documents/capabilities/<name>.md`, `documents/roadmaps/<name>.md`, the capability docs it lists as prerequisites, any `documents/decisions/` files whose topic overlaps, every `<package>/DECISIONS.md` for packages its roadmap names, and the code those steps name (grep first; read only what you need). Do NOT edit any file.
>
> Run these checks: <paste P1–P6 from this skill verbatim>. Apply these exemptions: <paste "Expected, not findings">. Code is the ground truth for built behavior.
>
> Return findings only, one per block, in exactly this format — no prose before or after:
>
> ```
> [BROKEN|DRIFT|INFO] <check id> <file:line or doc § section>
> What: <one sentence>
> Evidence: <file:line or quote that contradicts it>
> Fix: <which workflow, from: direct edit | ask developer | /draft-capability | /draft-northstar | /ideas | /draft-spec | /bug-report | tech debt | /audit | memory>
> ```
>
> If you find nothing, return `NO FINDINGS`.

While they run, do the structural checks (step 2) and cross-cutting checks (X1–X4) yourself. Then merge: drop exact duplicates, and merge two findings about the same contradiction seen from both sides into one.

## 5. Triage

**Severity:**
- **Broken** — someone acting on this would build the wrong thing or be misled: contradictions, `[x]` steps that aren't built, decision violations in code, broken links, checkbox mismatches.
- **Drift** — stale but not yet misleading: steps outside a milestone, built-but-unchecked steps, stale "pending" wording, memory duplicating docs, dependency order problems in a future milestone.
- **Info** — worth knowing: stubs, packages without DECISIONS.md, open blockers in the current milestone.

**Fix routing** — every finding names exactly one:

| Finding | Fix |
|---|---|
| Stale line, checkbox flip, broken link, wrong fact in a doc | **direct edit** |
| Two docs disagree and it's unclear which is right | **ask developer** — then direct edit or a decision update |
| Capability needs requirements written | **/draft-capability** |
| Northstar out of date | **/draft-northstar** |
| Work discovered that's on no roadmap | **/ideas** |
| A roadmap step is ready and blocking the milestone | **/draft-spec** |
| Code breaks a decision and the behavior is broken | **/bug-report** |
| Code breaks a decision but works | **tech debt** — a master Maintenance entry |
| Code quality concern beyond a single constraint | **/audit** |
| Memory contradicts or duplicates docs | **memory** — update or delete the entry |

## 6. Write the report first

Write `scratchpad/coherence-report.md` **before** presenting anything:

```markdown
# Coherence Report — YYYY-MM-DD

**Mode:** full | delta since <ref> | <capability>
**Checked through:** <HEAD commit>
**Scope:** <capabilities checked>

## Summary
- Broken: N · Drift: N · Info: N
- By fix: direct edit N · ask developer N · /draft-capability N · …

## Broken
- [ ] **<check id>** `<location>` — <what>
  Evidence: <evidence>
  Fix: <workflow> — <the specific change>

## Drift
…

## Info
…
```

Sort within each severity by fix type, so all direct edits sit together.

In delta mode, carry forward any unchecked `- [ ]` findings from the previous report that are outside this run's scope, under a `## Carried forward` section, so a delta run doesn't lose them.

## 7. Present

Show the summary counts, then the Broken findings in full, then Drift and Info as one line each. Point to the report for detail.

Then ask: **"Apply the N direct-edit fixes now?"** List them briefly. The developer can approve all, some, or none. For approved ones, make the edit — change only the stale line, nothing around it — and tick the finding `- [x]` in the report.

For every other fix type, list the next workflow to run (e.g. "`/draft-northstar` for 2 northstar findings") and stop. Never run those workflows yourself.
