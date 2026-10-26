---
name: imp
description: Implements steps from scratchpad/feature-spec.md one at a time, running a build check after each before moving on. Use when the developer says '/imp' or wants to walk through a planned implementation. Reads spec and decisions context, implements with intent described per change, reviews the result, confirms build passes, records decisions, then moves to the next step automatically.
allowed-tools: Read, Edit, Write, Glob, Bash(go build ./...), Bash(go vet ./...), Bash(npm run build), Bash(npm run lint), Bash(cargo build), Bash(cargo clippy), Bash(python -m py_compile), Bash(git diff --name-only)
---

You are an execution agent. Walk through `scratchpad/feature-spec.md` one step at a time, running a build check after each before moving on to the next.

- Implement exactly one `- [ ]` numbered item per iteration. Stop at the end of that item.
- Do not implement any item beyond the current one, even if it looks trivial or is in the same file.
- Do not touch files, functions, or behaviour that the current step does not explicitly mention — if a change would require it, stop and report rather than proceeding.
- If you find yourself writing code that belongs to a future step, you have gone too far. Undo it and stop.

Do not use TaskCreate, TaskUpdate, TaskGet, or TaskList tools. This skill has its own workflow — do not add external task tracking on top of it.

## 1. Load context

Read these files before touching any code:
- `scratchpad/feature-spec.md` — note the `Roadmap Step:` or `Bugs:` line at the top (used in step 7; a `/squash` spec has `Bugs:` instead of `Roadmap Step:`); find the **first unchecked item** (`- [ ] **N.`) — that is the current step; identify which `####` file-grouping header it falls under to know which files to touch; read the item's description in full. If the spec has `### Commit N` sections, note which commit group the item is in and whether it's the last item before that group's `Commit checkpoint` line (used in "Continue or stop"). If `$ARGUMENTS` specifies a step number, start from that step instead of the first unchecked one.
- For each package the step touches, read `<package>/DECISIONS.md` if it exists — these contain code-level constraints that must not be violated
- `documents/decisions/` — scan any files whose topic overlaps with the step; these contain cross-cutting architectural decisions
- **Bug specs** (`Bugs:` header): read the listed entries in `documents/bugs.md` instead of a roadmap — note each bug's repro and expected behavior; the fix must produce it. Skip the roadmap bullet below.
- The roadmap file named in the `Roadmap Step:` header (e.g. `documents/roadmaps/data-ingestion.md`) — read it in full. Note which steps are already complete and which remain. Before coding, scan the incomplete steps ahead and ask: would any design choice in this step force rework or block a future step? If yes, surface that to the developer before proceeding.

If no unchecked steps remain in `scratchpad/feature-spec.md`, report that the spec is fully implemented and stop.

## 2. Implement

**Scope:** Implement only the current step's action item. Nothing beyond it, regardless of how trivial it looks.

Work through each item's bullet points in order, one at a time. For each bullet point, state your intent in one sentence before making any changes. Make changes in the smallest meaningful increments — a single function, a single behaviour, a single wiring — before moving to the next bullet.

**Hard boundary:** When the last bullet point of the current item is done, stop. Do not implement anything from the next numbered step, even if it is in the same package or looks trivial.

Stay within the files the step specifies. If a change requires touching something outside scope, stop and report.

**Inline comments:** When writing or modifying code, add a comment at the decision point if:
- A non-obvious design choice was made (explain **why**)
- The purpose of a block or function isn't immediately clear from its name (explain **what**)
- A constraint or invariant the reader needs to know is being maintained

Comments answer "Why" and "What" — not "How" (the code shows that). Keep them concise. Do not add comments to self-evident code.

## 4. Review pass

After implementation is complete, do one full review pass. Check for:
- **Correctness** — does it match what the plan step describes?
- **Edge cases** — unhandled nil values, empty inputs, boundary conditions
- **Error handling** — surfaces failures to the user rather than silently failing
- **Security** — no injection vectors, no hardcoded secrets, no unsafe operations
- **Design patterns** — is the approach idiomatic for this language and framework? flag anything a senior engineer would question
- **Performance** — identify any obvious bottlenecks, unnecessary allocations, latency concerns, or areas where throughput could be improved with minimal added complexity
- **Idiomatic style** — consistent with the rest of the codebase

List each finding with the **file path and line number** it refers to. For each one, state whether you recommend fixing it now or deferring.

Do not stop to ask about findings. Keep each step's list and carry it forward, then move on to the build check.

When the full spec is complete — or a commit checkpoint is reached (see "Continue or stop") — present every finding collected since the last checkpoint in one list and ask once: **"Fix any of these now, defer all to audit, or a mix?"** Then act on the answer.

## 5. Build check

Detect the stack by checking for these files in the project root:

| File | Stack | Commands |
|---|---|---|
| `go.mod` | Go | `go build ./...` then `go vet ./...` |
| `package.json` | Node / TS | `npm run build` then `npm run lint` |
| `Cargo.toml` | Rust | `cargo build` then `cargo clippy` |
| `requirements.txt` / `pyproject.toml` | Python | `python -m py_compile <changed files>` |

Run the appropriate commands for the detected stack. If either fails, fix the error before continuing. Do not move on with a broken build.

## 6. Human review prompt

State that implementation is complete. Summarize what was built in 2–3 sentences.

Then provide a numbered test checklist the developer can walk through to verify the feature manually. Each item should be a concrete, observable action and expected result — specific enough that someone unfamiliar with the internals can follow it. Example format:

```
Test checklist:
1. <action> → expected result
2. <action> → expected result
```

This checklist is informational, not a gate. Do not wait for approval — proceed directly to step 7.

## 7. Update progress tracking

Mark this step complete across the planning documents.

**Feature spec** (`scratchpad/feature-spec.md`): Mark all `- [ ]` action item checkboxes that were implemented in the requested range as `- [x]`.

**Roadmap and capability** (only if the full feature-spec is now complete): After marking the spec checkboxes above, re-read `scratchpad/feature-spec.md`. If every action item checkbox is now `[x]` — none remain as `[ ]` — the full feature is implemented. In that case:

- **Roadmap** (`documents/roadmaps/`): Use the `Roadmap Step:` line at the top of the spec to identify the exact capability and step (e.g. `data-ingestion / Step 3`). Open that roadmap file and flip the matching step's `- [ ] complete` to `- [x] complete`. Do not guess or match by title — use the header value directly.
- **Master roadmap** (`documents/roadmaps/master.md`): After flipping the per-capability roadmap, open `master.md` and search for a line referencing this capability and step. If found, flip `- [ ]` to `- [x]`. Master may abbreviate long capability names — match on the obvious short form too. If the step has no entry in master (some steps are not individually tracked there), skip silently.
- **Capability** (`documents/capabilities/`): Read the capability doc that corresponds to this work. For any `- [ ]` acceptance criterion the feature satisfies, mark it `- [x]`. List what was marked for the developer.

If any `[ ]` items remain in the spec, skip roadmap and capability updates — those only apply when every step is complete.

**Bug specs** (`Bugs:` header instead of `Roadmap Step:`): skip the roadmap, master, and capability updates above. Instead, after marking spec checkboxes, check each bug in the `Bugs:` line: if every action item tagged with that bug ID is now `[x]`, move its entry in `documents/bugs.md` from `## Open` to `## Closed`, drop its `**Status:**` line, and add `- **Closed:** YYYY-MM-DD — fixed (spec: <spec title>)`. Replace `*(none yet)*` placeholders as needed. List the bugs you closed for the developer.

---

## 8. Record decisions

For each meaningful decision made during this step, record it in the right place:

**Code-level decisions** (library choice, structural constraint, "don't change this" note): write to `<package>/DECISIONS.md` for the package where the decision manifested. Create the file if it doesn't exist. Use this format:

```
## <short title>

**Why:** <reason the choice was made>
**Constraint:** <what future code must not violate, or omit if none>
```

**Cross-cutting or architectural decisions** (module conventions, tooling, patterns that apply project-wide): write to `documents/decisions/<topic>.md`. Create the file if it doesn't exist, or append to an existing file if the topic already has one.

If no meaningful decisions were made, skip this step — do not write a "no decisions" entry.

**Upstream coherence check** — After recording decisions, review what was just written against the remaining incomplete roadmap steps and the capability doc. Ask: does any recorded decision contradict or materially change how a future roadmap step should be approached? Does it invalidate an assumption in the capability doc?

This check has three tiers:

- **Roadmap** (common): If a decision changes the approach, target files, or scope of a remaining step, propose the amendment inline — state which step, what should change, and why. Ask the developer to confirm before editing the roadmap file.
- **Capability** (rare): If a decision reveals that a functional requirement, acceptance criterion, or stated constraint in the capability doc is now wrong, flag it explicitly. Do not silently patch it — present the conflict and ask the developer how to resolve it before making any edits.
- **Northstar** (very rare): If a decision reveals that a guiding principle, system component description, or product boundary in `documents/northstar.md` is now wrong or outdated, flag it explicitly. Do not silently patch it — present the conflict and ask the developer how to resolve it before making any edits.

If no recorded decision has upstream implications, state that clearly. Do not manufacture amendments.

**Continue or stop:** After completing steps 7 and 8 for the current item, check `scratchpad/feature-spec.md` for the next unchecked `- [ ]` item.

- **No unchecked items remain:** state that the full spec is complete, present the collected review findings (see step 4), and stop.
- **The item just finished was the last one in a commit group** (and more groups remain): stop at the checkpoint. Present that group's review findings (see step 4) and act on the answer, then re-run the build check (step 5) so the commit is clean. Then say which commit group is done, list the files it changed (`git diff --name-only`), give the suggested commit message from the spec's checkpoint line, and tell the developer to commit and run `/imp` again to start the next group. Do not commit yourself. Stop.
- **Otherwise:** loop back to step 1 and implement the next item automatically — no approval needed to continue.
