---
name: fleet
description: Runs several roadmap steps at once, each in its own Claude session and git worktree, and gives one overview of all of them. Use when the developer says '/fleet' (pick and launch steps) or '/fleet status' (overview of running steps). Works in the desktop app (session tools), the CLI inside herdr, or the plain CLI (background sessions).
---

You are the **hub**. You never write feature code here. You pick work, launch one worker session per roadmap step, and walk each one through the dev workflow. Each worker runs the normal pipeline (`/draft-spec` → `/imp` → `/pr-review` → `/pr-create`) on its own branch, and flips its own checkboxes — spec, capability roadmap, and `master.md` — so every PR goes up fully checked off. The hub checks those flips before it lets a worker open its PR. When every worker has a PR up, the hub asks once whether to merge them, then merges them one at a time (see **Merging**).

Modes, from `$ARGUMENTS`:
- empty or `plan` → **Plan and launch**
- `status` → **Status**

Hard limits:
- **At most 4 workers running at once.** More than that and the developer can't keep up with their questions and reviews.
- **No two workers touch the same files.** That's the whole safety model. When in doubt, don't run them together.
- **No worker opens a PR until the hub passes its PR gate** (see **PR gate**). That's how the checkboxes stay right.
- **The hub merges only after the developer says yes** to the merge question. Workers never merge.

## Pick the launcher

Check once, at the start of any mode, and use that launcher's commands everywhere below:

- **desktop**: the `start_session` / `list_sessions` tools exist. Use them.
- **herdr**: no session tools, and `test "${HERDR_ENV:-}" = 1` passes. Use `herdr` commands. They return JSON; read ids from the output, don't guess them.
- **cli**: neither. Use `claude --bg` background sessions and `claude agents`.

If the developer is in the CLI but not in herdr, tell them in one line that herdr gives a live sidebar of every worker (`herdr`, then `claude` in a pane, then `/fleet`), then carry on with **cli** unless they want to switch.

## Plan and launch

1. **Sync.** Run `git fetch origin` then `git branch -f main origin/main` only if `main` is not the checked-out branch (it's a fast-forward of a local ref, nothing else changes). If `main` is checked out and behind, stop and tell the developer to pull first. Workers branch from `main`, so it must be current.

2. **Count what's running.** Running workers count against the 4 limit. Note which files they own (from their brief). Workers whose PR is merged don't count.
   - desktop: `list_sessions` with `{"linked": true}` plus `{"group": "Fleet"}`.
   - herdr: `herdr agent list`. Workers are the agents whose `name` matches a `feature/<name>` branch.
   - cli: `claude agents --json`. Workers are the sessions named after their step slug.

3. **Find candidates.** Read `documents/roadmaps/master.md`. Take the current milestone's open steps (`- [ ]`). For each, open its capability roadmap and read the step: what it depends on, which packages and files it names. Drop a step when:
   - a step it depends on is open or running in another worker,
   - it's a design pass or capability draft (`/draft-capability`, "design pass") — those are conversations, run them yourself in a normal session,
   - it's not a roadmap step (bug squash, "light agent tuning").

4. **Check for file overlap.** For each candidate, list the files and directories it will likely touch (use the roadmap text, then `Grep`/`Glob` to confirm the real paths). Treat files many features touch as shared hot spots — state stores, the API router, the migration list, an agent's tool registry or system prompt, plus any `CLAUDE.md` or `documents/decisions/` name. Two steps that both hit a hot spot can't run together. Pick the largest set of candidates with no overlap with each other or with running workers.

5. **Show the developer a table** — step, roadmap file, files it owns, how much it will need them (`low`: mostly code / `high`: lots of design questions) — and why each excluded step was excluded. Ask with `AskUserQuestion` (multiSelect) which to launch. Wait.

6. **Launch** each picked step. Every launcher uses the same values:
   - `slug`: short slug of the step (e.g. `order-summary-api`). Branch is `feature/<slug>`.
   - `title`: the roadmap step name.
   - `brief`: the **worker brief** below, filled in.
   - `background`: one paragraph — the milestone and its exit test, that other workers are running in parallel on other files, and the step's dependencies that are already done.

   **desktop:**
   - `list_groups`; reuse a group named `Fleet` or create it.
   - `start_session` with `initiation: "user_asked"`, `context: "fresh"`, `use_worktree: true`, `source_branch: "main"`, `permission_mode: "auto"`, `name: <slug>`, `branch_name: feature/<slug>`, `title`, `prompt: <brief>`, `background`.
   - `move_sessions` all new session ids into the `Fleet` group.

   **herdr** (per step):
   1. `herdr worktree create --branch feature/<slug> --base main --label <slug>`. Keep `.result.workspace.workspace_id` and `.result.root_pane.pane_id`.
   2. `herdr agent start <slug> --kind claude --pane <pane_id> -- --permission-mode auto -n <slug>`.
   3. `herdr agent prompt <slug> "<background>\n\n<brief>"`. Don't add `--wait`; the worker runs for a long time.

   If step 2 returns `agent_not_ready`, the worker is stuck on a startup prompt (often "trust this folder?"). Tell the developer to answer it in that workspace, then run `herdr agent wait <slug> --until idle` before step 3.

   **cli** (per step):
   1. `git worktree add -b feature/<slug> .claude/worktrees/<slug> main`. Make the worktree yourself so step 7 can link files in before the worker starts.
   2. Link the files (step 7).
   3. From that worktree: `cd .claude/worktrees/<slug> && claude --bg -n <slug> --permission-mode auto "<background>\n\n<brief>"`. Keep the printed id.

7. **Link `.env` and `.claude/settings.local.json`** into every new worktree. Both are gitignored, so worktrees start without them. Workers need `.env` for the app's secrets and the Discord ping in `/pr-create`. They need `settings.local.json` for your saved permissions and MCP approvals. For each worker, find its worktree path in `git worktree list --porcelain` (the entry whose branch is `feature/<slug>`), then from the hub run:
   ```
   ln -sfn "$(git rev-parse --show-toplevel)/.env" <worktree>/.env
   mkdir -p <worktree>/.claude && ln -sfn "$(git rev-parse --show-toplevel)/.claude/settings.local.json" <worktree>/.claude/settings.local.json
   ```
   Run that from the main checkout, not a worktree, or the links point at the wrong files. Symlinks, not copies, so editing the main files reaches every worker.
   - herdr and cli: link before the worker starts. Claude reads settings and MCP approvals at startup only.
   - desktop: Claude makes the worktree, so it may not show up for a few seconds. Link once it does. If the session started first, it won't see `settings.local.json` until restarted.
   - If the main checkout is missing either file, skip that link and launch anyway. Tell the developer in one line.

8. Tell the developer what started, and how to watch them (see **Watching**). On desktop, link each session as `[title](#local_<id>)`. On herdr, name each workspace by its label. On cli, list each `<slug>` and its id.

### Worker brief

```
You are a fleet worker for ONE roadmap step: <Capability> Step <N> — <name> (`documents/roadmaps/<file>.md`).

Pipeline, in order:
1. /draft-spec for exactly this step. Ask the developer the design questions it needs — they'll answer here.
2. /imp until the spec is done.
3. /pr-review. Fix what it finds.
4. Stop and wait for the hub. End your turn with exactly `READY FOR PR` on its own line. The hub checks your checkbox flips and replies `go` or tells you what to fix.
5. After `go`: /pr-create. Then stop and report the PR link.

Checkboxes are yours to flip, at the time /imp normally flips them:
- spec items as each one is done,
- once the whole spec is done: your step in `documents/roadmaps/<file>.md`, its line in `documents/roadmaps/master.md` (if it has one), and the capability doc, exactly as /imp says.
Commit the flips with the code so they're in the PR.

Files you own: <list>, plus your step's lines in the two roadmaps above. Other workers are editing other parts of the repo at the same time.
- Don't edit files outside your list unless the step truly needs it. If it does, say so in your report and in the PR body under "Shared files touched".
- Other workers also flip lines in `master.md`, so your PR may conflict there with theirs. Leave it — the hub sorts those out when it merges.
- Don't merge your PR, rebase onto other branches, merge main into your branch, or push to main.
- If you get blocked on a decision only the developer can make, ask and wait. Don't guess on design.

Your final message: PR link, one-line summary, any shared files touched, anything unverified.
```

## PR gate

Run this each time a worker ends a turn with `READY FOR PR`.

1. Find its worktree: `git worktree list --porcelain`, the entry whose branch is `feature/<slug>`. Read files from that path.
2. Check, in that worktree:
   - `scratchpad/feature-spec.md`: `Roadmap Step:` names the step this worker was given, and every action item is `- [x]`.
   - the capability roadmap: that step is `- [x] complete`.
   - `documents/roadmaps/master.md`: the step's line is `- [x]`, if it has one. No other line changed.
   - `git -C <worktree> status --porcelain` is clean and `git -C <worktree> diff --stat main...HEAD` includes the roadmap files. Flips sitting uncommitted won't reach the PR.
   - `git -C <worktree> merge-tree --write-tree origin/main HEAD` has no conflicts (run `git fetch origin` first). Checkbox-only conflicts in roadmap files are fine; the hub fixes them at merge time. Any other conflict goes back to the worker to fix.
3. All good → send the worker `go`. Anything off → send it a short list of what to fix and to say `READY FOR PR` again when done. Tell the developer in one line either way.

Send messages the same way as in **Watching** (desktop and cli: `SendMessage`; herdr: `herdr agent prompt <slug> "<message>"`).

## Watching

Tell the developer once, after the first launch.

**desktop:**
- The sidebar's **Fleet** group shows every worker and whether it's working or waiting on them.
- Drag up to 2–3 workers into split view to answer their questions side by side (or ask the hub to open them with `open_session_in`).
- The hub gets a note each time a worker finishes a turn. If it ends in `READY FOR PR`, run the **PR gate**. If it ends with a PR link, check whether to ask the merge question (see **Merging**). Run `/fleet status` here any time for the table.

**herdr:**
- Herdr's sidebar shows each worker's workspace as **working**, **blocked** (waiting on you), or **done**. Click a workspace to answer its questions, then come back to the hub.
- If the sidebar doesn't change state, the Claude hook is likely outdated. Tell the developer to run `herdr integration install claude`.
- The hub also watches: for each worker, run `herdr agent wait <slug> --until blocked --until done` with `run_in_background`. When it returns, check its last output (`herdr agent read <slug> --source recent-unwrapped --lines 60`). If it ends in `READY FOR PR`, run the **PR gate**. If it ends with a PR link, check whether to ask the merge question (see **Merging**). Otherwise run `herdr notification show "<slug> needs you" --body "<one line: question waiting / turn finished>" --sound request` and tell the developer in one line. Start the wait again if the worker isn't finished.
- Run `/fleet status` here any time for the table.

**cli:**
- `claude agents` shows every session and whether it's working or waiting. `claude attach <slug>` to answer a worker's questions; detach to come back.
- The hub watches with `SendMessage` to `<slug>` with `notify_when_idle: true` (no message). When the idle notice arrives, check `claude logs <slug>`. If it ends in `READY FOR PR`, run the **PR gate**; if it ends with a PR link, check whether to ask the merge question (see **Merging**); otherwise tell the developer in one line what it wants. Subscribe again if it isn't finished.
- Run `/fleet status` here any time for the table.

## Status

Give one compact overview, nothing else.

1. List the workers:
   - desktop: `list_sessions` with `{"group": "Fleet"}` (fall back to `{"linked": true}`).
   - herdr: `herdr agent list`. Use `agent_status` for state. For the last report, `herdr agent read <slug> --source recent-unwrapped --lines 60`.
   - cli: `claude agents --json`. For the last report, `claude logs <slug>`.
2. For each worker, read its state, branch, and PR (`gh pr list --head feature/<slug> --json number,url`). If it has a PR, run `gh pr view <n> --json state,mergeable,statusCheckRollup,reviewDecision` for checks and merge state.
3. Print one table, sorted so the ones that need the developer come first:

| Step | Session | Stage | Needs you? | PR / CI |

   Stage is a best guess from the session's state and last report: `speccing`, `implementing`, `reviewing`, `PR gate`, `PR open`, `merged`, `stuck`. "Needs you?" is yes when it's waiting on a question (herdr `blocked`), failed, or has a PR ready to review. A worker sitting at `READY FOR PR` that hasn't been gated yet: run the **PR gate** now.
4. One line after the table: what to do next (answer X, review PR Y, launch more — there are N free slots). If every worker has a PR up, ask the merge question (see **Merging**).

## Merging

**When to ask.** Each time a worker reports its PR link, check the fleet. Once every worker in it has an open PR (none still speccing, implementing, or at the PR gate), wait for CI on all of them (`gh pr checks <n> --watch` with `run_in_background`), then ask once with `AskUserQuestion`:

> All N fleet PRs are up and CI is green. Shall I merge them?

Before the question, print the PRs in chat so the developer can click through and review — one line each, from `gh pr view <n> --json number,title,url,statusCheckRollup`:

```
- [#<n> <title>](<url>) — <step> · CI <passing/failing>
```

Options: merge all / let me pick / not yet. A PR with failing CI isn't offered — say why, and tell its worker to fix it. "Not yet" means don't ask again until the developer brings it up or another PR lands.

**Merge, one at a time**, oldest first (unless one builds on another):

1. `git fetch origin`, then `gh pr view <n> --json mergeable,headRefName`. Retry for a few seconds while it's `UNKNOWN` — GitHub recomputes after each merge.
2. `MERGEABLE` → go to step 4.
3. `CONFLICTING` → fix it in a throwaway worktree in your scratchpad, not the worker's (its branch is checked out there):
   - `git worktree add --detach <dir> origin/<branch>`, then `git -C <dir> merge --no-edit origin/main`.
   - Look at every conflict. If each one is the same line with `[ ]` on one side and `[x]` on the other, keep the `[x]` — that's the only thing you fix. Commit and `git -C <dir> push origin HEAD:<branch>`.
   - Anything else (a real code or text conflict): `git -C <dir> merge --abort`, skip this PR, and tell the developer which file. Keep going with the rest.
   - Remove the worktree either way. If you pushed, wait for CI: `gh pr checks <n> --watch --fail-fast`. Failed → skip this PR and say so.
4. `gh pr merge <n> --merge`. Don't pass `--delete-branch`; the worker still has it checked out.
5. Next PR.

**After the last one:**
- Check `origin/main`: each merged step is `[x]` in its capability roadmap and in `master.md` (if it has a line). If one isn't, tell the developer.
- Tell any workers still running (no PR yet) to merge `origin/main` into their branch.
- Ask once to clean up the merged workers. desktop: archive the session. herdr: `herdr worktree remove --workspace <workspace_id>`. cli: `claude rm <slug>`. Then `git branch -D feature/<slug>` and `git push origin --delete feature/<slug>`.
- One line: merged N, skipped M (why), N free slots. Offer **Plan and launch** if slots opened.
