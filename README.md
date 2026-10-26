# Harness

A Claude Code SDLC workflow system — skills and document conventions for building software with AI agents.

## Philosophy

### Augment, don't automate

The agent is a collaborator, not an autonomous executor. Every step in the workflow produces something the developer reviews before the next step begins — a capability doc before a roadmap, a spec before any code, findings before any fixes. The developer stays the decision-maker; the agent handles the mechanical work of drafting, searching, and writing.

### Keep cognitive debt low

A codebase accumulates cognitive debt when decisions are made implicitly, spread across conversations, or never written down. Harness externalizes that debt into documents: capability docs capture *what* the system should do, roadmaps capture *in what order*, and DECISIONS.md files capture *why* the code is shaped the way it is. The agent reads these documents before touching anything, so each session starts from a known state rather than reconstructing it from scratch.

### Small, focused changes

Every implementation step is scoped to a single roadmap entry — at most two files, roughly eight functions. A step that's larger gets split before speccing begins. This keeps diffs reviewable, keeps the blast radius of a bad decision small, and makes it easy to stop and course-correct without untangling accumulated work.

### Document alignment as a forcing function

Documents aren't just reference material — they're a consistency check. When a spec contradicts a capability doc, or a decision contradicts the northstar, the workflow surfaces the conflict before any code is written. The agent is instructed to flag these conflicts rather than silently resolve them, keeping the developer in the loop on anything that would change the direction of the work.

---

## Document structure

The skills read and write a shared document convention:

- `documents/northstar.md` — product vision, target users, non-negotiables, capability map
- `documents/capabilities/` — one file per capability; functional requirements, data model, acceptance criteria
- `documents/roadmaps/` — step-by-step implementation plans per capability; each step has a `- [ ] complete` checkbox the skills flip when done
- `documents/roadmaps/master.md` — milestones that order steps across capabilities; mirrors per-capability status
- `documents/bugs.md` — bug backlog (`B-NNN` entries); broken behavior only
- `documents/ideas.md` — parked feature ideas
- `documents/decisions/` — cross-cutting architectural decisions that apply project-wide
- `<package>/DECISIONS.md` — code-level decisions local to a package: why a library was chosen, what constraints future code must not violate

Write a decision when a non-obvious choice was made between real alternatives, when a constraint exists that future code must not violate, or when a conversation drove toward a specific approach that could easily be undone by the next agent. If a conversation produces a key decision, record it before the session ends.

---

## Agent support

Skills are authored once in `.claude/skills/<name>/SKILL.md` (the canonical source — includes Claude Code's `allowed-tools` permission scoping) and mirrored to `.agents/skills/<name>/SKILL.md` for Codex and other tools that follow the same emerging convention (frontmatter trimmed to `name`/`description`; body identical). `CLAUDE.md` and `AGENTS.md` carry the same project instructions for their respective tools.

If you edit a skill, update both copies — `.claude/skills` is the source of truth; `.agents/skills` drops the `allowed-tools` line and points any `.claude/skills/` paths at `.agents/skills/`.

Gemini CLI uses a different convention (`.gemini/commands/*.toml`) and isn't supported yet.

## Skills

Slash commands that run structured workflows in Claude Code (also available to Codex-style agents via `.agents/skills/`):

| Skill | Trigger | Purpose |
|---|---|---|
| `draft-northstar` | `/draft-northstar` | Define or refine the project vision document |
| `draft-capability` | `/draft-capability` | Document a capability and generate its implementation roadmap |
| `draft-foundation` | `/draft-foundation` | Drive the architectural design conversation before any code is written |
| `draft-spec` | `/draft-spec` | Produce a function-scoped feature spec from a roadmap step |
| `imp` | `/imp [step N]` | Implement the next unchecked spec step (or a given one) with review and progress tracking |
| `audit` | `/audit` | Review recently changed code for correctness, conventions, and security |
| `utest` | `/utest` | Propose and write unit tests one at a time with developer approval |
| `pr-create` | `/pr-create` | Open a GitHub PR from the current branch with a structured description |
| `pr-review` | `/pr-review [PR#\|branch]` | Run the build, linters, and full test suite, then review the diff |
| `bug-report` | `/bug-report <what broke>` | Log a bug to `documents/bugs.md` fast — capture only |
| `squash` | `/squash [N\|IDs\|capability]` | Triage open bugs and write one point-budgeted fix spec for `/imp` |
| `ideas` | `/ideas` | Talk through feature ideas; route approved ones to roadmaps or park them |
| `coherence` | `/coherence [full\|since <ref>\|capability]` | Check that docs, decisions, roadmaps, and code all agree |
| `catchup` | `/catchup` | Summarize merged PRs over a time range into a quick catch-up report |

---

## Workflow

Each phase feeds the next. Nothing is implemented without a spec; nothing is specced without a capability doc; nothing is merged without a review.

```
/draft-northstar        → documents/northstar.md
/draft-capability       → documents/capabilities/<name>.md
                          documents/roadmaps/<name>.md
/draft-foundation       → <package>/DECISIONS.md
/draft-spec step N      → scratchpad/feature-spec.md
/imp                    → code + updated roadmap + DECISIONS.md
/audit                  → scratchpad/audit-report.md
/utest                  → scratchpad/test-plan.md + test files
/pr-create              → GitHub PR
/pr-review              → scratchpad/pr-review-report.md
```

Side loops:

```
/bug-report             → documents/bugs.md
/squash                 → scratchpad/feature-spec.md (bug spec) → /imp
/ideas                  → roadmap steps, capability stubs, or documents/ideas.md
/coherence              → scratchpad/coherence-report.md
/catchup                → scratchpad/catchup-report.md
```

Specs are sized in points (1 trivial, 2 standard, 3 new logic, 5 risky); the suggested max is 13 per spec. `/imp` works through a spec one unchecked item at a time. See `documents/decisions/dev-workflow.md`.

---

## Setup

1. Copy `.claude/` (and, if you use Codex or another `.agents/skills`-compatible tool, `.agents/`) plus `documents/` into your project root.
2. Fill in `CLAUDE.md` (and `AGENTS.md`, if used) with your stack and project-specific conventions.
3. Run `/draft-northstar` to create your vision document.
4. Run `/draft-capability` to document a capability and generate its roadmap.
5. Set the current milestone in `documents/roadmaps/master.md`.
6. Work through the roadmap: `/draft-foundation` → `/draft-spec` → `/imp` → `/audit` → `/utest` → `/pr-create`.

---

## scratchpad/

Working files (`feature-spec.md`, `audit-report.md`, `test-plan.md`, `action-items.md`, and the other skill reports) live here during active work and are excluded from git. They are per-session artifacts, not permanent records — the permanent record is the code and the documents.
