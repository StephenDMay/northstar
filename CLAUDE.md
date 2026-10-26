# [Project Name]

[One sentence describing what this project does.]

## Stack

<!-- Add your stack and project-specific conventions here. Example:
- **Backend:** Go — Chi router
- **Frontend:** React + Vite + Tailwind CSS
- **Database:** PostgreSQL
-->

## Document Structure

- `documents/northstar.md` — product vision, target users, non-negotiables, capability map
- `documents/capabilities/` — one file per system capability; functional requirements, data model, acceptance criteria
- `documents/roadmaps/` — implementation roadmaps for each capability
- `documents/roadmaps/master.md` — milestones; the order to work through roadmap steps across capabilities
- `documents/decisions/` — cross-cutting and architectural decisions that apply project-wide
- `documents/ideas.md` — parked feature ideas; add with `/ideas`
- `documents/bugs.md` — bug backlog; add with `/bug-report`, fix with `/squash` → `/imp` (see `documents/decisions/dev-workflow.md`)

Read the relevant capability doc before working on a feature. If there is no capability doc yet, check the northstar for alignment.

## Decision Tracking

Decisions are recorded in two places depending on scope:

**Per-package** (`<package>/DECISIONS.md`): Code-level choices — why a library was chosen, why a function is structured a specific way, constraints the next person touching this package must know. Create this file when the first meaningful decision is made for that package.

**Project-wide** (`documents/decisions/<topic>.md`): Cross-cutting or architectural choices — API conventions, module naming, tooling choices, patterns that apply across the whole codebase.

Write a decision when:
- A non-obvious choice was made between real alternatives
- A constraint exists that future code must not violate
- A conversation drove toward a specific approach that could easily be undone by the next agent

If a conversation produces a key decision, record it before the conversation ends — do not rely on a future step to capture it.

## Action items file

Whenever you propose a list of action items for the developer to do or process, also write it to `scratchpad/action-items.md`. Read the file first. If every item is checked off (or the file is missing/empty), overwrite it with the new list. If any items are still open, don't overwrite — show the developer the open items and ask whether to replace them, merge the new list in, or keep the old one. Use numbered checkboxes (`- [ ] 1. ...`) so items are easy to reference by number. Still show the list in chat as usual; the file is so the developer can track it without scrolling back.

## Conventions

<!-- Add project-specific conventions here. Example:
- Module path: `myproject/internal/...`
- DB driver: `pgx/v5`
-->
