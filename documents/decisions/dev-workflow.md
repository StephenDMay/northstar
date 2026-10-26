# Decision: Development Workflow

These come with the harness. Change them here if your project works differently, and update the skills to match.

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
