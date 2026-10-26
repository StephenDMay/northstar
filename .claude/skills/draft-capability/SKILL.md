---
name: draft-capability
description: Draft a capability document and implementation roadmap through guided conversation. Use when the developer says '/draft-capability' or wants to define requirements and a roadmap for a specific capability.
allowed-tools: Read, Write, Edit, Glob
---

# Draft Capability Workflow

This workflow defines comprehensive requirements and an implementation roadmap for a capability, building upon the project Northstar.

## Prerequisites

- `documents/northstar.md` should exist. If it doesn't, suggest running `/draft-northstar` first.
- Have a capability in mind to document.

## Steps

1. **Read the Northstar** — Read `documents/northstar.md` to understand the overall vision and context.

2. **Read all existing capabilities** — List all files in `documents/capabilities/` and read each one. This gives you a complete picture of what is already defined so the new capability doesn't duplicate scope, conflicts with existing requirements, or miss obvious integration points. Briefly state which capability docs were loaded before continuing.

3. **Load decisions context** — Scan `documents/decisions/` and read any files relevant to the capability being drafted. Also identify any packages the capability is likely to touch (e.g. `internal/db`, `internal/store`, `internal/ingestion`) and read their `<package>/DECISIONS.md` files if they exist — these contain code-level constraints the capability requirements must not violate. Briefly state what was loaded before continuing.

4. **Collect supporting context** — Ask if there are any supporting notes or documents to reference. If provided as file paths, read them. If provided as pasted text, work from that directly.

5. **Identify the capability** — Ask:
   - What capability do you want to document?
   - What is the high-level goal of this capability?
   - How does this align with the Northstar vision?

6. **Define the user value** — Explore:
   - What user problem does this solve?
   - What is the user story or job-to-be-done?
   - What is the expected user impact?

7. **Gather functional requirements** — Discuss:
   - What are the core functions this capability must deliver?
   - What are the key user workflows or journeys?
   - What data needs to be displayed or managed?

8. **Identify technical considerations** — Cover:
   - Are there specific technical requirements or constraints?
   - What systems or services need to integrate?
   - What are the dependencies on other capabilities or external systems?

9. **Define acceptance criteria** — Clarify:
   - How will we know this capability is complete?
   - What are the must-have vs nice-to-have elements?
   - What are the edge cases or error scenarios to handle?

10. **Explore UX/UI requirements** — Discuss:
   - What are the key screens or interfaces?
   - What is the desired user experience flow?
   - Are there accessibility requirements?

11. **Identify risks and assumptions** — Discuss:
    - What assumptions are we making?
    - What are the known risks or unknowns?
    - What could block or delay this work?

12. **Create the capability document** — Write the capability document to `documents/capabilities/[capability-name].md`. Present it and ask: **"Does this look right? Let me know any changes, or say 'done' to generate the roadmap."** Iterate until the developer confirms it's complete. Do not generate the roadmap until confirmed.

13. **Record any decisions** — If key architectural or design choices emerged during the conversation that aren't already captured, write them to the appropriate file in `documents/decisions/` before proceeding.

14. **Draft the implementation roadmap** — Once the capability doc is confirmed, propose a step breakdown as a short list (do not write the file yet). Before presenting it, assess: does this capability introduce new infrastructure or foundational patterns that don't yet exist in the codebase — a new package, a new architectural layer, a new wiring convention?

   If yes: open with a Foundation step (unnumbered). If no: numbered steps only, starting at Step 1.

   Present the proposed breakdown to the developer and walk through these questions explicitly, one theme at a time — **wait for responses before writing the file:**

   - **Sizing**: Sketch each step's likely action items and weight them with the point scale in `.claude/skills/draft-spec/SKILL.md` (1 trivial, 2 standard, 3 new logic, 5 risky). Does any step touch more than two files or total more than 13 points? Flag those with their totals and propose splitting them now — this is cheaper than splitting later in `/draft-spec`.
   - **Independence**: Can each step be reviewed and merged without the next step being done? If not, explain the dependency and ask whether to merge the steps or reorder them.
   - **Sequencing**: Are there hidden dependencies between steps that aren't reflected in the current order?
   - **Value**: Does each step leave the system in a better, usable state — even if later steps are never done? Steps that only set up for a later step should either be merged with it or explicitly called out as scaffolding.

   Adjust the breakdown based on the developer's responses. Once confirmed, write the roadmap to `documents/roadmaps/[capability-name].md`.

   Every step (including Foundation) must have `- [ ] complete` as the first line under its heading — this is the progress indicator that `/draft-foundation` and `/imp` flip to `- [x] complete` when done.

15. **Add capability to Northstar** — Read `documents/northstar.md`. Add an entry for this capability under the **System Components** section. Place it in the correct position: MVP capabilities before the later-phase entries, later-phase capabilities before post-MVP entries. Format it to match existing entries: bold name, em-dash, one-sentence description, link to the capability doc. Present the proposed entry and ask: **"Does this Northstar entry look right?"** Iterate until confirmed, then write the change.

16. **Merge into master roadmap** — Read `documents/roadmaps/master.md`. Determine where this capability's steps belong. Walk through these questions explicitly with the developer before writing anything:

   - **Phase placement**: Which phase does this capability belong to? Does it depend on anything in the roadmap that must finish first? Does anything already in the roadmap depend on this capability?
   - **Track structure**: Should the steps run in a new track (parallel with existing work in the same phase), extend an existing track, or form a new standalone phase?
   - **Convergence**: Are there any convergence points — steps from this capability that must wait for another track, or vice versa?

   Once placement is confirmed, add the steps to `documents/roadmaps/master.md` using the naming convention already established there (e.g. `[Capability Name] Foundation`, `[Capability Name] Step N`). Do not add status checkboxes to master roadmap entries — the master roadmap uses plain `- [ ]` / `- [x]` list items only (no "complete" sub-lines). Write the update.

## Output

**Phase 1 — capability doc** (`documents/capabilities/[capability-name].md`):
- Capability name and summary
- Northstar alignment
- User value proposition and target users
- Functional requirements and user workflows
- Technical requirements and dependencies
- Acceptance criteria (must-have and nice-to-have)
- UX/UI requirements
- Risks and assumptions
- Out of scope items

Reviewed and confirmed by developer before Phase 2 begins.

**Phase 2 — roadmap** (`documents/roadmaps/[capability-name].md`):
- Proposed as a discussion first; written to file only after the developer confirms the breakdown
- A `## Foundation` step (unnumbered, design conversation → package DECISIONS.md) appears before numbered steps when the capability introduces new infrastructure; otherwise omitted
- Numbered steps start at Step 1 and are each scoped as `/draft-spec` inputs — sized to touch at most two files and ~13 points (see the point scale in `/draft-spec`)
- Steps are sequenced so each one is independently mergeable and leaves the system in a better state
- Every step has `- [ ] complete` as its first line — flipped to `- [x] complete` by `/draft-foundation` or `/imp` on completion

**Phase 3 — Northstar update** (`documents/northstar.md`):
- New entry added under System Components in the correct MVP / later-phase / post-MVP position
- One sentence, bold name, link to capability doc — matches the format of existing entries
- Confirmed by developer before writing

**Phase 4 — master roadmap update** (`documents/roadmaps/master.md`):
- Steps added to the correct phase and track after explicit placement discussion
- Uses the established naming convention (`[Capability Name] Foundation`, `[Capability Name] Step N`)
- Plain `- [ ]` list items only — no `- [ ] complete` sub-lines in the master roadmap
- Confirmed by developer before writing
