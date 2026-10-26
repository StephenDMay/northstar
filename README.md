# Harness

Harness is a set of Claude Code skills and document conventions for building software with AI agents. It covers the whole loop from product vision to merged PR.

## Philosophy

### Augment, don't automate

The agent works with the developer instead of running on its own. Each step produces something the developer reviews before the next one starts. A capability doc comes before its roadmap, a spec comes before any code, and audit findings come before any fixes. The developer makes the calls, and the agent does the drafting, searching, and writing.

### Keep cognitive debt low

Cognitive debt builds up when decisions are made implicitly, scattered across conversations, or never written down. Harness keeps that knowledge in documents. Capability docs say what the system should do, roadmaps say in what order, and DECISIONS.md files say why the code looks the way it does. The agent reads these before touching anything, so each session starts from what's written down instead of piecing things together again.

### Small, focused changes

Each spec covers a single roadmap step, and its size is measured in points. Every action item in the spec is one function, weighted by how much work it is: 1 for trivial, 2 for standard, 3 for new logic, and 5 for risky work like schema changes, concurrency, external APIs, or contracts between packages. The suggested max is 13 points. A step over that gets split into commit groups, or into separate roadmap steps if it's much larger. The developer can choose to go over.

Points work better than a function count because a one-line field add and a schema migration aren't the same amount of work. Keeping specs small keeps diffs easy to review and makes it easy to stop and change course before too much work piles up.

### Documents keep each other honest

The documents also work as a consistency check. If a spec contradicts a capability doc, or a decision contradicts the northstar, the workflow raises it before any code gets written. The agent is told to flag these conflicts and let the developer decide, instead of quietly picking a side.

## Document structure

The skills read and write these documents:

- `documents/northstar.md`: product vision, target users, non-negotiables, and the capability map
- `documents/capabilities/`: one file per capability, with functional requirements, data model, and acceptance criteria
- `documents/roadmaps/`: step-by-step plans per capability. Each step has a `- [ ] complete` checkbox that the skills flip when it's done.
- `documents/roadmaps/master.md`: milestones that order steps across capabilities. It mirrors the status in the per-capability roadmaps.
- `documents/bugs.md`: the bug backlog, with `B-NNN` entries. Broken behavior only.
- `documents/ideas.md`: feature ideas parked for later
- `documents/decisions/`: architectural decisions that apply to the whole project
- `<package>/DECISIONS.md`: code-level decisions for one package, like why a library was chosen or what future code in it must not do

Write a decision when you chose between real alternatives and the choice isn't obvious, when there's a constraint future code must respect, or when a conversation settled on an approach the next agent could easily undo. Record it before the session ends.

## Agent support

Skills live in `.claude/skills/<name>/SKILL.md`, which is the source of truth and includes Claude Code's `allowed-tools` permissions. They're mirrored to `.agents/skills/<name>/SKILL.md` for Codex and other tools that use that convention. `CLAUDE.md` and `AGENTS.md` hold the same project instructions for each tool.

If you edit a skill, update both copies. The `.agents` copy drops the `allowed-tools` line and points any `.claude/skills/` paths at `.agents/skills/`.

Gemini CLI uses a different format (`.gemini/commands/*.toml`) and isn't supported yet.

## Skills

These run as slash commands in Claude Code. Codex-style agents can use them through `.agents/skills/`.

| Skill | Trigger | Purpose |
|---|---|---|
| `draft-northstar` | `/draft-northstar` | Write or refine the project vision doc |
| `draft-capability` | `/draft-capability` | Write a capability doc and its roadmap |
| `draft-foundation` | `/draft-foundation` | Work through the architecture for a capability before any code |
| `draft-spec` | `/draft-spec` | Turn a roadmap step into a point-sized spec |
| `imp` | `/imp [step N]` | Implement the next unchecked spec item, or a specific one |
| `audit` | `/audit` | Review the branch's changes for correctness, conventions, and security |
| `utest` | `/utest` | Propose and write unit tests one at a time |
| `pr-create` | `/pr-create` | Open a GitHub PR with a structured description |
| `pr-review` | `/pr-review [PR#\|branch]` | Run the build, linters, and tests, then review the diff |
| `bug-report` | `/bug-report <what broke>` | Quickly log a bug to `documents/bugs.md` |
| `squash` | `/squash [N\|IDs\|capability]` | Triage open bugs and write a fix spec for `/imp` |
| `ideas` | `/ideas` | Talk through feature ideas and file them in the right place |
| `coherence` | `/coherence [full\|since <ref>\|capability]` | Check that docs, decisions, roadmaps, and code agree |
| `catchup` | `/catchup` | Summarize recently merged PRs |

## Workflow

The main path, in order:

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

Code gets written from a spec, specs come from a capability doc, and changes get reviewed before they merge.

Other skills you'll use along the way:

```
/bug-report             → documents/bugs.md
/squash                 → scratchpad/feature-spec.md (bug spec), then /imp
/ideas                  → roadmap steps, capability stubs, or documents/ideas.md
/coherence              → scratchpad/coherence-report.md
/catchup                → scratchpad/catchup-report.md
```

`documents/decisions/dev-workflow.md` explains why bugs, ideas, and spec points work the way they do.

## Setup

1. Copy `.claude/` and `documents/` into your project root. If you use Codex or another tool that reads `.agents/skills`, copy `.agents/` too.
2. Fill in `CLAUDE.md` (and `AGENTS.md`, if you use it) with your stack and conventions.
3. Run `/draft-northstar` to write your vision doc.
4. Run `/draft-capability` to write a capability and its roadmap.
5. Set the current milestone in `documents/roadmaps/master.md`.
6. Work through the roadmap with `/draft-foundation`, `/draft-spec`, `/imp`, `/audit`, `/utest`, and `/pr-create`.

## scratchpad/

Working files like `feature-spec.md`, `audit-report.md`, `test-plan.md`, `action-items.md`, and the other skill reports live here and are kept out of git. They only matter while the work is in progress. The code and the documents are the lasting record.
