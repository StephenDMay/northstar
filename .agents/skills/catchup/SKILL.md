---
name: catchup
description: >-
  Compiles a skimmable progress report from merged PR descriptions over a
  chosen time range, so a teammate returning after time away can catch up
  fast. Use when the developer says '/catchup' or asks what they missed,
  what's changed recently, or for a summary of recent progress.
---

You are a progress-digest agent. Your job is to turn merged PR descriptions into a short report a teammate can skim in a minute or two to catch up on what happened while they were away.

Do not use TaskCreate, TaskUpdate, TaskGet, or TaskList tools.

## 1. Ask how far back to go

Ask the developer with `AskUserQuestion` before fetching anything:

- **Last 7 days**
- **Last 30 days**
- **Since a specific date** (free text, e.g. "since Sept 1" or "since the auth launch")
- **Last N merged PRs** (free text, pick a count)

If the developer already gave a range in their message (a date, "since last week", a PR count), skip the question and use that.

## 2. Gather merged PRs in range

```bash
git rev-parse --abbrev-ref HEAD
gh repo view --json defaultBranchRef -q .defaultBranchRef.name
```

Set `BASE` to the default branch (fall back to `main`, then `master`).

Fetch merged PRs against `BASE`:

```bash
gh pr list --state merged --base "$BASE" --limit 200 \
  --json number,title,url,mergedAt,author,body
```

Filter client-side to the requested range (by `mergedAt` date, or take the first N by merge date if the developer asked for a PR count). If nothing merged in range, say so and stop — don't pad the report.

## 3. Extract the signal from each PR

Each PR body follows the `pr-create` template with these sections: `Background Context`, `Change Summary`, `Steps to test`, `Risk mitigation`.

For each PR, pull:
- **What changed** — from `Change Summary` (fall back to the PR title if the section is empty or missing). Don't just copy the title or bullet points verbatim — read them and restate in one plain-English sentence, like you're telling a teammate what happened, not quoting a log.
- **Who** — from `author.login`.
- **Risk/follow-up callouts** — from `Risk mitigation`, only if it flags something non-generic (a real risk, a deferred follow-up, a known limitation).

Ignore `Steps to test` entirely — it's not useful for a catch-up digest.

If a PR predates the template (plain body or empty), summarize from the title and any body text that exists.

## 4. Group and write the report

Group PRs by theme, not strict PR-by-PR listing — infer theme from touched capability (titles, package names, `documents/capabilities/` references) when it's obvious; otherwise group by week. Within a group, order oldest to newest so it reads as a story of progress, not a changelog.

Write `scratchpad/catchup-report.md`:

```markdown
# Catch-up: <range description>

<N> PRs merged into `<BASE>` since <start> — <end, usually "today">.

## <Theme or week label>

<One short lead-in sentence for the theme, if it helps orient the reader.>

- <Plain-English sentence on what was built/fixed/changed>, by <author> (#<number>)
- ...

## <Next theme>

...

## Worth knowing

- <risk/follow-up in plain English>, from <author>'s #<number>
- ...
```

Rules:
- **Write like you're catching up a teammate over coffee, not filing a report.** Natural sentences, not title fragments. "Sam added tags to orders so they can be filtered by status" beats "order tags (#145)".
- **One line per change**, PR number and author folded into the sentence or parenthetical — don't give each PR its own heading or sub-block.
- **Skip "Worth knowing" entirely** if nothing substantive surfaced — don't force filler.
- Keep group labels short and specific (e.g. "Order tagging", not "Misc changes").
- Target brevity: a reader should be able to skim the whole thing in under two minutes.

## 5. Present it

Do **not** print the report's contents in chat. Just confirm it's ready and give a brief, friendly summary — 2-3 sentences covering roughly how much happened and the main themes (e.g. "14 PRs since Sept 1, mostly order tagging and job-system fixes — Sam did most of it with a couple of PRs from [other author]."). Point to `scratchpad/catchup-report.md` for the full read.
