---
name: draft-spec
description: Draft a function-scoped feature spec through guided conversation. Use when the developer says '/draft-spec' or wants to clarify, scope, and document a feature before implementation. Writes to scratchpad/feature-spec.md.
allowed-tools: Read, Write, Glob, Grep, AskUserQuestion, Bash(git diff --name-only)
---

## Purpose
A concise, repeatable workflow to clarify feature requests, restate understanding, map data flow, list impacted files and functions, edge cases, and produce function-scoped action items — without implementing any code. Always writes to `scratchpad/feature-spec.md` (single living file, overwritten each run).

One spec covers exactly one roadmap step. This is a hard rule — the spec header records which roadmap step it corresponds to, and `/imp` uses that to update progress tracking when complete.

## Workflow

1. **Input & Initial Read** — Ingest the feature request. Read relevant files to understand context.

2. **Identify Capability and Roadmap Step** — List all capability files from `documents/capabilities/` with numbers. Ask: "Is this request related to an existing capability? Type the number, or 'no' if not related." **Wait for response before proceeding.**

   If the user selects a capability: read that capability doc and its matching roadmap from `documents/roadmaps/` in full. Then scan the capability doc for any related or dependent capabilities it mentions (e.g. in dependencies, technical requirements, or integration sections) and read those capability docs from `documents/capabilities/` as well — they define contracts and scope boundaries this spec must not violate. Then scan `documents/decisions/` — read any file whose topic is relevant to the feature (e.g. touches the same package, API layer, or data source). For each package the selected roadmap step targets, also read `<package>/DECISIONS.md` if it exists. Briefly state what you loaded ("Read: data-ingestion.md, user-accounts.md, internal/ingestion/DECISIONS.md") before continuing.

   Show the roadmap steps with completion status (✓ for `[x] complete`, open for `[ ] complete`). Ask: "Which roadmap step are you speccing? Type the step number." **Wait for response before proceeding.**

   Once a step is selected, actively compare the loaded decisions against the selected roadmap step. Look for: constraints that contradict the step's stated approach or architectural rules that change the target files. If any conflicts exist, surface them now, described by behavior or design (e.g. "the roadmap says results get cached, but the analytics decision says they're always computed fresh") — before the scope check and before any clarifying questions — and resolve them with the developer before continuing.

   Also scan the incomplete steps ahead in the roadmap. Ask: would any design choice in this spec foreclose or force rework on a future step? If yes, surface that before asking any clarifying questions so the spec accounts for it from the start.

   If no capability is selected, still scan `documents/decisions/` for relevant files and load any that apply. Skip roadmap step selection — the spec header will have no Roadmap Step line.

3. **Scope Check** — Before asking any clarifying questions, assess whether the selected roadmap step is appropriately sized for a single spec. Sketch the action items the step likely needs and weight each with the point scale below. A step is too large if the sketch totals more than **13 points**, or its description covers separable phases of work that could ship independently.

   **Point scale** (one action item = one function, weighted by complexity):

   | Pts | Meaning | Examples |
   |---|---|---|
   | 1 | Trivial | add a struct field, edit prompt text, add a constant, one-line wiring |
   | 2 | Standard | change an existing function's logic, add a simple handler or prop |
   | 3 | New logic | new function or component with real branching, parsing, or state |
   | 5 | Risky | schema change, concurrency, new external API, cross-package contract change |

   When an item sits between two weights, take the higher one. 13 is a suggested max, not a hard limit.

   If the step is too large, show the sketch with its points and total (describe each item by what it does; function names are fine here as a short tag, not the lead). Then recommend a fix based on how far over it is:

   | Total | Recommend | Why |
   |---|---|---|
   | 14–26 pts | **Commit groups** — one spec, split into 2–3 commits | Still one coherent change; commits keep each review chunk small |
   | 27+ pts, or separable phases that could ship on their own | **Split the roadmap step** — each sub-step gets its own spec | Too big for one branch to review well |

   Give the developer three choices — **commit groups**, **split the step**, or **proceed** as one plain spec — with your recommendation first. If they proceed, continue to clarifying questions.

   For commit groups:
   - Propose the groups: name each by what it delivers, with its rough points. Aim for ~13 pts or less per group
   - Each group must leave the build passing on its own. Order them so later groups build on earlier ones (e.g. schema and types first, then logic, then wiring)
   - **Wait for confirmation**, then continue to clarifying questions. The groups shape the action items in step 7 and the spec layout (see template)

   To split the step:
   - Propose a concrete split: name each sub-step by what it delivers, with the packages it touches in a short trailing note
   - Ask the developer to confirm or adjust the breakdown
   - **Wait for confirmation before proceeding**
   - Rewrite the roadmap file in-place: replace the original step with the confirmed sub-steps, using letter suffixes (e.g. Step 4 → Step 4a and Step 4b). Preserve all other steps and their completion status unchanged
   - State which sub-step this spec will cover, then continue

   If the step is appropriately scoped, proceed directly to clarifying questions.

4. **Clarify Assumptions First** — This is the most important step. The spec is only as solid as the decisions made here. Surface every assumption that could cause a wrong implementation or require rework. Do not proceed until every question is resolved.

   The developer works through the harness and usually doesn't have the code open. Talk at the level of behavior and system design, the way a tech lead talks through a feature. Save code-level detail for the spec file.

   **Sort every open decision into one of two buckets:**

   - **Ask the developer** — anything that changes what the feature does, or is expensive to change later:
     - Behavior and scope: what it does, what it doesn't do, what the user sees
     - Failure behavior: what the user or caller sees when something breaks
     - **Big data contracts**: schema and table changes, API or WebSocket payload shapes, agent tool definitions, cross-package interfaces, anything a future roadmap step will build on
     - Anything where codebase precedent or the decisions docs don't point to a clear answer
   - **Decide yourself** — internal details with an obvious answer from codebase patterns or decisions docs: helper signatures, local types, error wrapping, variable naming, small internal refactors, standard concurrency patterns already used in the package. Don't ask about these. List them under "Calls I made" (below).

   **How to word questions:**
   - Lead with the behavior or design choice, not the code. Say "the order summary the API returns", not "`OrderSummary` in `internal/orders/types.go:42`".
   - Don't cite line numbers or function names in questions. Name a package, table, or type only when the question is about that contract itself, and say in plain words what it is.
   - For a data contract, describe the shape in a short list of fields and what each one means. Don't paste Go structs or TS types.
   - Give 2–3 options and a recommendation with a one-line reason, so most answers can be "yes" or "B".
   - Keep each question to 1–3 sentences.

   Ask questions in bursts of 2–3, grouped by theme. Use `AskUserQuestion` when a question has clear options. **Wait for answers after each burst before asking the next.** If an answer raises a follow-up, ask it in the next burst — do not defer it to the end.

   Work through these themes in order, skipping any that provably do not apply:

   - **What it does, and what it doesn't** — scope, boundaries, adjacent work that's out of scope
   - **What goes in and comes out** — the user-visible result, plus any big data contract (see above)
   - **When things break** — upstream failures, partial data, what the user or caller sees
   - **What gets saved or changed** — stored data, re-run safety, anything that mutates state
   - **How it fits what's coming** — future roadmap steps this choice could help or box in

   Once the themes are covered, post **"Calls I made"**: a short bullet list of the technical decisions you made on your own, each with a few words of why (e.g. "Reusing the existing HTTP retry wrapper — same pattern as the other API clients"). The developer can veto any of them. Fold any vetoes back in, then move to step 5.

5. **Restate Understanding** — Echo the confirmed scope in plain terms: what the feature does, what the user sees, which big contracts change. A few bullets, no function names.

6. **Analyze Data Flow** — Map end-to-end data paths (sources, transformations, calls, responses, side effects). Keep it concise — bullet points showing the request/response journey through the system.

7. **Create Action Items** — One action item per function. Each item must be independently reviewable — the developer should be able to form an opinion on it in under a minute without needing to hold another item in their head. For each function, mark **[Add]**, **[Change]**, or **[Remove]** and describe intent in a single sentence. If you can't describe a function's purpose in one sentence, it should be two functions. Never group multiple functions into one item. Include new functions if needed.

   Give each item a point weight from the scale in step 3, and total them. If the final total is over 13 and the developer didn't already pick commit groups or proceed at the scope check, flag it now: show the total and offer the same choices as step 3, using its table to pick the recommendation. Splitting the roadmap step at this point means rewriting the roadmap as in step 3 and trimming the spec to the first sub-step.

   If using commit groups, assign every item to a group. Item numbers keep counting across groups (don't restart at 1) so `/imp` step N stays unique. Re-check that each group leaves the build passing; move items between groups if not.

8. **Edge Cases** — List notable edge cases, failure modes, and validation needs (nil/empty, timeouts, permissions, config).

9. **Write Spec** — Create or overwrite `scratchpad/feature-spec.md` using the template below. Keep wording scannable. **Only write after all questions are answered.**

10. **Upstream coherence check** — After writing the spec, review the assumptions resolved in step 4 and the final spec. Ask: does anything decided here contradict or update what the capability doc or northstar claims?

    - **Capability doc** (occasional): If a scoping decision, data contract, or stated behavior in the spec differs from the capability doc, flag it — don't silently align the spec to incorrect docs. Present the conflict and ask the developer whether to update the capability doc or adjust the spec.
    - **Northstar** (rare): If a decision reveals that a guiding principle, system component description, or product boundary in `documents/northstar.md` is now wrong or outdated, flag it explicitly. Do not silently patch it — present the conflict and ask the developer how to resolve it before closing.

    If nothing conflicts, state that clearly. Do not manufacture amendments.

## Output Location
Always write/update: `scratchpad/feature-spec.md` (single living file per run).

## `feature-spec.md` Template

```markdown
# [Feature Name]

**Roadmap Step:** [capability-name] / Step N — [Step title from roadmap]
**Points:** [total] / 13

---

## Quick Start (TL;DR)

1. **[Action 1]** → `path/to/file` - Brief description
2. **[Action 2]** → `path/to/file:line` - Brief description
3. **[Action 3]** → `path/to/file` - Brief description
4. **Test**: `[test command]`

---

## Feature Summary

[2-3 sentences describing the goal, scope, and purpose]

---

## Action Items (Function-Scoped)

#### `path/to/file` **[Add/Change/Remove]**

- [ ] **1. `FunctionName`** (line XX) · 2 pts
  - **What**: Brief description of the change
  - **Why**: Reason for the change
  - **Input**: Parameters or data received
  - **Output**: Return type or data produced

- [ ] **2. `AnotherFunction`** (line YY) · 1 pt
  - **What**: Brief description
  - **Why**: Reason
  - **Input**: Parameters
  - **Output**: Return type

#### `path/to/another/file` **[Change]**

- [ ] **3. `MethodName`** (line ZZ) · 3 pts
  - **What**: Specific change needed
  - **Why**: Impact or reason
  - **Input**: Parameters
  - **Output**: Return type

[Repeat for each file, continuing the function count...]

<!-- If using commit groups: wrap the file sections in one block per group, in commit order.
     Numbering continues across groups. Drop these headings for a plain spec.

### Commit 1 — [What this commit delivers] · [N] pts

#### `path/to/file` **[Add]**
- [ ] **1. ...**
- [ ] **2. ...**

> **Commit checkpoint:** build passes. Commit message: `[short message]`

### Commit 2 — [What this commit delivers] · [N] pts

#### `path/to/file` **[Change]**
- [ ] **3. ...**

> **Commit checkpoint:** build passes. Commit message: `[short message]`
-->

---

## Data Flow

**Request Path:**
1. Client → [Entry point] - [What happens]
2. [Component A] → [Component B] - [Data transformation]
3. [Component B] → [External System] - [Side effect]
4. [External System] → [Component B] - [Response]
5. [Component B] → Client - [Final output]

**Key Types:**
- `TypeName1`: [Purpose and key fields]
- `TypeName2`: [Purpose and key fields]

**Side Effects:**
- Database writes to [table]
- Cache updates in [layer]
- External API calls to [service]

---

## Edge Cases

- **[Scenario 1]**: [What could go wrong] → [How to handle]
- **[Scenario 2]**: [Validation concern] → [Expected behavior]
- **[Scenario 3]**: [Error condition] → [Fallback strategy]
- **[Scenario 4]**: [Performance concern] → [Mitigation]

---

## Open Questions

- **Q1**: [Unclear requirement or blocker]
- **Q2**: [Decision needed before implementation]
- **Q3**: [Dependency or configuration question]

---
```

## Notes
- Spec only — no implementation.
- Conversation vs. file: the conversation stays at behavior and design level; the spec file keeps full code detail (functions, lines, points) because `/imp` depends on it.
- Unit tests are out of scope unless specifically requested.
- Keep concise and scannable (bullets, short sentences).
- If requirements are incomplete, surface blockers in Open Questions and seek clarification before writing the spec.
- Action item granularity: one function per item, independently reviewable. A function that can't be described in one sentence of intent is a design problem — split the function, not just the spec item.
- Spec size is measured in points (step 3's scale), not function count. Suggested max is 13; the developer can choose to go over. Over 13, recommend commit groups (14–26) or a roadmap split (27+ or separable phases).
- Commit groups stay in the one spec file and one roadmap step. When a spec has them, the header `**Points:**` line shows the total plus each group, e.g. `**Points:** 21 / 13 — Commit 1: 12, Commit 2: 9`.
- One spec = one roadmap step. The `Roadmap Step:` header line is not optional — `/imp` uses it to flip the correct roadmap checkbox when the spec is complete.
