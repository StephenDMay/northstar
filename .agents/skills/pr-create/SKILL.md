---
name: pr-create
description: >-
  Analyzes all commits on the current branch plus relevant chat context, then
  opens a GitHub pull request with a structured body. Use when the developer
  says '/pr-create' or asks to create a PR automatically.
---

You are a pull-request authoring agent. Analyze the full branch diff and relevant conversation context, draft a review-ready PR, push if needed, and open it on GitHub.

Do not use TaskCreate, TaskUpdate, TaskGet, or TaskList tools.

## Hard rules

- Use `gh` for all GitHub operations. Return the PR URL when done.
- NEVER update git config.
- NEVER run destructive git commands (`reset --hard`, `clean -fdx`, force-push) unless the user explicitly requests them.
- NEVER force-push to `main` or `master`; warn the user if they request it.
- Do not open a duplicate PR — check for an existing PR on the current branch first.
- If there are uncommitted changes, stop and ask whether to commit them first or proceed with only committed work.
- **Keep PR descriptions concise.** Brevity reduces token cost, helps reviewers scan faster, and keeps the PR approachable. Say the minimum needed for a good review — never pad, repeat, or restate what the diff already shows.

## 1. Gather branch state

Run these in parallel:

```bash
git status
git branch -vv
git rev-parse --abbrev-ref HEAD
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```

Set `BASE` to the repo default branch from `gh repo view` (fall back to `main`, then `master` if needed).

Then run in parallel:

```bash
git log ${BASE}...HEAD --oneline
git log ${BASE}...HEAD --format="%h %s%n%b"
git diff ${BASE}...HEAD --stat
git diff ${BASE}...HEAD
```

Read every commit message and the full diff. Do not summarize from the latest commit alone.

## 2. Gather review context

Mine these sources for PR content:

| Source | Use for |
|---|---|
| Current chat | Goals, trade-offs, alternatives discussed, testing notes |
| `scratchpad/feature-spec.md` | Feature intent and acceptance criteria (if present) |
| `documents/capabilities/*.md` | Capability background (if the change maps to one) |
| `<package>/DECISIONS.md` | Architectural constraints worth calling out to reviewers |
| Commit messages | Scope boundaries and rationale the author already documented |

Prefer file paths and links over prose. Only pull context the diff cannot convey.

## 3. Draft the PR

### Conciseness (apply to title and every section)

- **Target length:** ~150–300 words for the full body. Go shorter for small diffs; only exceed ~400 words when the change is genuinely complex.
- **Bullets over paragraphs.** One idea per bullet; skip bullets that add no information.
- **No duplication** across sections — if it fits Change Summary, don't repeat it in Background or Risk.
- **Don't narrate the diff** — reviewers can read the code. Explain *why* and *what to watch for*, not a file-by-file walkthrough.
- **Omit empty noise** — if a section has nothing meaningful, write `None` or one short line instead of filler.
- **Links sparingly** — one or two per section at most; link the entry point, not every touched file.

### Title

≤ 72 chars, states the **outcome**, not the process. Derive from the collective commits and diff.

### Body

Fill every section below. Replace HTML comments with real content; do not leave placeholder comments in the final PR.

```markdown
### Background Context
<!-- What context do you need to share to encourage a good review? This is a good place to link to related code changes. -->

### Change Summary
<!-- Include a high level overview of your implementation, including any alternatives you considered & items you'll address in follow-up PR's. Before & After images / output are strongly encouraged & make it easier to understand your changes. -->

### Steps to test
<!-- Inlcude steps for others to test your changes, including user / browser conditions to replicate, pages to visit, components to interact with, etc. -->

### Risk mitigation
<!-- What have you done to make sure this lands safely in production? What is risky about your change? -->
```

**Background Context** (1–3 bullets) — Why now, and what reviewers should read first. Skip if the title and diff are self-explanatory.

**Change Summary** (2–5 bullets) — What behaves differently. Note non-obvious trade-offs or deferred follow-ups only when relevant. Mention screenshots only if they exist (do not fabricate).

**Steps to test** (3–5 numbered steps) — Prerequisites, action, expected result. Merge trivial steps.

**Risk mitigation** (1–3 bullets) — Real risks and concrete mitigations. Skip generic assurances.

Write the body to `scratchpad/pr-body.md` in the repo root. Use `--body-file` with `gh pr create` so formatting is preserved on all platforms.

## 4. Push and create

Check for an existing PR:

```bash
gh pr list --head "$(git rev-parse --abbrev-ref HEAD)" --json url,number -q '.[0].url'
```

If a PR already exists, show its URL and ask whether to update the description instead of creating a new one.

If the branch is not on the remote, push it:

```bash
git push -u origin HEAD
```

Create the PR:

```bash
gh pr create --title "YOUR TITLE" --body-file scratchpad/pr-body.md
```

Delete the temp body file after a successful create.

## 5. Notify Discord

Post a message to the team Discord channel in this exact format:

```
{FirstName} made a pr:

{brief plain english description}

{url}
```

Get the author from `git config user.name` and use only their first name. `{brief plain english description}` is a plain-language 1–2 sentence summary of what the PR does (not the title verbatim — write it like you're telling a teammate, not labeling a diff).

```bash
FIRST_NAME="$(git config user.name | cut -d' ' -f1)"
scripts/notify-discord.sh "${FIRST_NAME} made a pr:

<1-2 sentence plain-language summary>

${PR_URL}"
```

If `DISCORD_WEBHOOK_URL` isn't set, the script skips silently — don't treat that as a failure.

## 6. Report back

Return:

- PR URL
- One-sentence summary of what the PR contains
- Anything you could not infer (e.g. missing test environment, uncommitted work left out)

Keep the chat response short — the PR body carries the detail.
