# Decision: Development Workflow

These come with Northstar. Change them here if your project works differently, and update the skills to match.

## Bugs live in `documents/bugs.md`, not an issue tracker

Bugs go in one backlog file, `documents/bugs.md`, with IDs (`B-NNN`), severity, and status.

- `/bug-report` — fast capture while using the app. No investigation.
- `/squash` — triages open bugs one at a time (root cause → include / defer / won't fix / feature), then writes one spec to `scratchpad/feature-spec.md` with a `**Bugs:**` header instead of `**Roadmap Step:**`.
- `/imp` — runs a bug spec like any other; closes each bug in `bugs.md` once all its tagged items are done.

**Why:** Keeps everything readable by the same skills that read the rest of `documents/`. An issue tracker would split the source of truth.

**Constraint:** Three buckets stay separate. Broken behavior → `bugs.md`. Working-but-wrong code → master.md Maintenance (tech debt). New behavior → a roadmap step. `/squash` reroutes feature-shaped bugs to a roadmap rather than fixing them in a bug spec.

## Feature ideas go through `/ideas`, parked ones live in `documents/ideas.md`

`/ideas` splits a ramble into ideas, gut-checks each against the northstar, decisions, cost, and roadmaps, then routes approved ones: a roadmap step (plus a master entry), a capability scope change, or a stub capability doc for `/draft-capability`. Parked ideas go in `documents/ideas.md`. Dropped ideas aren't written down.

**Why:** Ideas left in chat or agent memory are invisible to planning sessions and other skills.

**Constraint:** No edits without approval of the exact text. `/ideas` never writes a full capability doc — only a stub.

## `/coherence` checks that docs and code agree

One skill checks that the northstar, decisions, capabilities, roadmaps, DECISIONS.md files, backlogs, memory, and code agree — both structure (pairings, checkbox sync, links) and meaning (contradictions, "done" steps that aren't built, code that breaks a decision). Modes: delta since the last run (default), `since <ref>`, `full` (one subagent per capability), or one capability. Each finding names the workflow that fixes it.

**Why:** Drift is mostly in meaning, not structure — a doc claiming something is deferred after it was built.

**Constraint:** Report-only. It writes `scratchpad/coherence-report.md` before presenting, and only applies direct edits the developer approves. Every other fix goes through its own workflow. The last-run marker lives in that report, which is local (scratchpad is gitignored) — a fresh clone starts with `full` or `since <ref>`.

## Spec size is measured in points, not function count

Each spec action item gets a weight: 1 trivial, 2 standard, 3 new logic, 5 risky (schema, concurrency, external API, cross-package contract). Suggested max is **13 points** per spec. `/draft-spec` and `/squash` both flag specs over the max and offer a split, but the developer can proceed anyway.

**Why:** A function count treats a one-line field add the same as a schema migration. Points track how dense a spec actually is.

**Constraint:** The scale is defined once, in `.claude/skills/draft-spec/SKILL.md` step 3. `/squash` references it — change it there, not in copies.

## Parallel roadmap work runs through `/fleet`

**Decided:** 2026-11-05 (from ptcg-coach, where it started 2026-10-29)

`/fleet` runs in a "hub" session. It picks open steps from the current milestone that don't share files, and starts one worker session per step — each in its own git worktree off `main`, in auto mode. Each worker runs the normal `/draft-spec` → `/imp` → `/pr-review` → `/pr-create` pipeline. `/fleet status` gives one table of all workers.

**Why:** Running several steps by hand meant juggling branches and the shared `scratchpad/feature-spec.md`. Worktrees give each step its own folder, branch, and scratchpad, so they can't step on each other.

**Constraints:**
- At most 4 workers at once.
- No two workers touch the same files. Shared hot spots (stores, router, migrations, agent tool registry) count as overlap.
- Workers flip their own checkboxes (spec, capability roadmap, `master.md`) and commit them with the code. The hub checks the flips and the merge state before it lets a worker open its PR.
- The hub merges the PRs, not the workers. Once every worker has a PR up and CI is green, it asks once whether to merge, then merges them one at a time. If a PR conflicts after the one before it lands, the hub merges `origin/main` into it in a throwaway worktree, keeps the `[x]` on checkbox-only conflicts, pushes, waits for CI, and merges. Any other conflict skips that PR and goes to the developer.
- The hub symlinks the main checkout's `.env` and `.claude/settings.local.json` into each worktree at launch. Both are gitignored, so worktrees don't get them. Symlink, not copy, so there's one file of secrets. They must be linked before the worker starts, so on CLI the hub makes the worktree itself instead of `claude --bg -w`.
- Design passes and capability drafts are not fleet work — they're conversations.
- The hub picks a launcher at the start: desktop session tools, then herdr if the hub is inside herdr (`HERDR_ENV=1`), then plain CLI background sessions. Plan, the PR gate, and status work the same in all three; only launch, watching, and status differ.
