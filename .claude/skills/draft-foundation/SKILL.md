---
name: draft-foundation
description: Drive the architectural design conversation for a capability foundation step. Use when the developer says '/draft-foundation' or wants to execute a Step 1 foundation step from a capability roadmap. Asks targeted questions about framework choices, patterns, and constraints, then writes the package DECISIONS.md before any code is written.
allowed-tools: Read, Write, Glob
---

# Draft Foundation Workflow

This workflow establishes the architectural foundation for a capability before any implementation begins. Its output is a package DECISIONS.md that captures the patterns and constraints all subsequent `/draft-spec` steps must build on.

## When to use

When a capability roadmap has a Step 1 marked as a foundation step. The dev runs `/draft-foundation [capability-name]` before reaching for `/draft-spec` on Step 2.

## Steps

### 1. Identify the capability and scope

If a capability name was provided as an argument, read its capability doc from `documents/capabilities/[capability-name].md` and its roadmap from `documents/roadmaps/[capability-name].md`. Confirm the Step 1 description aligns with what the developer wants to establish.

If no argument was provided, list the capabilities that have foundation steps in their roadmaps (scan `documents/roadmaps/` for steps marked as foundation steps) and ask which one to work on.

State what you read before continuing.

### 2. Load decisions context

Scan `documents/decisions/` and read any files relevant to the capability. Check whether a DECISIONS.md already exists for the target package — if so, read it. Briefly state what was loaded ("Read: tech-stack.md") before continuing.

### 3. Ask if there are supporting notes

Ask if there are any notes, references, or prior discussions to factor in. If provided as file paths, read them. If provided as pasted text, work from that directly.

### 4. Drive the architectural conversation

Ask questions in conversational bursts of 2–3, grouped by theme. **Wait for answers after each burst before asking the next.** If an answer raises a follow-up, ask it in the next burst.

Work through these areas, skipping any that provably do not apply to this capability:

**Package boundaries**
- What does this package own? What is explicitly not its responsibility?
- Where does this package's boundary sit relative to adjacent capabilities?

**Framework and library choices**
- Are there framework or library choices to make? What are the real alternatives?
- Are there existing project conventions that constrain the choice (check decisions context)?

**State management and data flow**
- How does data flow through this layer? What owns state, what observes it?
- What are the mutation points — where can state change, and who can trigger it?

**Key patterns**
- What patterns will all subsequent steps follow because of decisions made here?
- Are there any naming conventions, file structure choices, or interface shapes to establish now?

**Constraints**
- What must future steps never violate in this layer?
- Are there performance, security, or correctness invariants to lock in now?

Keep going until every area relevant to this foundation has been covered and nothing is unresolved.

### 5. Confirm decisions

Echo back the decisions as a numbered list. Ask: **"Does this capture everything? Anything missing or worth adjusting before I write the file?"** Iterate until confirmed.

### 6. Determine the package path

Ask: "What is the package path for this layer?" (e.g. `web/src/components`, `internal/agent`). This determines where the DECISIONS.md is written.

### 7. Write the package DECISIONS.md

Write to `[package-path]/DECISIONS.md`. Use this format for each decision:

```
## <short title>

**Why:** <reason the choice was made>
**Constraint:** <what future code must not violate — omit if none>
```

Group related decisions under a shared heading if appropriate. Keep each entry tight — one decision, one why, one constraint.

Present the file and ask: **"Does this look right? Say 'done' when ready, or let me know what to change."** Iterate until confirmed.

### 8. Flag cross-cutting decisions

Review the decisions just written. If any both apply beyond this package AND constrain how future code must be written project-wide — a module naming convention, a shared integration pattern, a tooling choice that other packages must follow — flag them explicitly: "These decisions may warrant an entry in `documents/decisions/` since they constrain code outside this package: [list]."

Apply the same bar as everywhere else: scope alone is not enough. Only flag it if the next developer in a different package would make a wrong choice without knowing it.

Ask if the developer wants to write them there now. If yes, append to the relevant existing file or create a new one.

### 9. Upstream coherence check

Review the decisions just written. Ask: does anything decided here contradict or update what the capability doc or northstar claims?

- **Capability doc** (occasional): If a design decision changes a functional requirement, component boundary, or stated behavior in `documents/capabilities/[capability-name].md`, flag it explicitly — don't silently align the foundation to an incorrect capability doc. Present the conflict and ask the developer whether to update the capability doc or adjust the decision before making any edits.
- **Northstar** (rare): If a decision reveals that a guiding principle, system component description, or product boundary in `documents/northstar.md` is now wrong or outdated, flag it explicitly. Do not silently patch it — present the conflict and ask the developer how to resolve it before making any edits.

If nothing conflicts, state that clearly. Do not manufacture amendments.

### 10. Update the roadmap

In `documents/roadmaps/[capability-name].md`, find the `## Foundation` step and flip its `- [ ] complete` to `- [x] complete`.

Then open `documents/roadmaps/master.md` and search for a line referencing "[Capability Name] Foundation". If found, flip `- [ ]` to `- [x]`. Master may abbreviate long capability names — match on the obvious short form too. If no matching line exists, skip silently.

## Output

`[package-path]/DECISIONS.md` — architectural decisions, patterns, and constraints for the new package. Written before any code exists. Every subsequent `/draft-spec` step for this capability reads this file as part of its context load.

Optionally: new entries in `documents/decisions/` for any cross-cutting choices.
