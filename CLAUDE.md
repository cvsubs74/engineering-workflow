# Harness contract for this project

You are working inside a repository that uses the **engineering-workflow** harness. This file is the contract every Claude session in this repo must follow.

## The protocol (every session, every time)

1. Run `pwd` and confirm you are at the project root.
2. Read the last 5 git commits: `git log --oneline -5`.
3. Run `harness/init.sh` to bring up the dev environment.
4. Run `harness/verify.sh` to confirm a green baseline. If it fails, **stop and fix the baseline before anything else.**
5. Read `harness/progress.md` (full file).
6. Read `harness/features.json`.
7. Pick **exactly one** feature where `passes` is `false` and `owner` is null or matches the current session.
8. Build that feature using the agent pipeline below.
9. Append a dated entry to `harness/progress.md` and commit.

## Agent pipeline for one feature

For each feature, dispatch agents in this order. Each agent is under `.claude/agents/`.

1. **product-manager** — re-read the feature's acceptance criteria. If they are ambiguous, refine them in `features.json` *only after* the user confirms (or, in auto mode, choose the most reasonable interpretation and document it in `harness/decisions/`).
2. **architect** — invoked only if the feature crosses module boundaries or introduces new dependencies. Updates `docs/architecture.md` if needed.
3. **implementer** — writes the code. Touches application code, not the harness.
4. **tester** — runs `harness/verify.sh` plus an end-to-end check matching the acceptance criteria. Flips `passes: true` only with evidence.
5. **reviewer** — reads the diff, blocks the commit on real issues only (correctness, security, obvious smell). Does not nitpick.

After all five pass, commit with a message in the form: `F<NNN>: <title>`.

## Hard rules

- **Do not edit acceptance criteria or remove tests** to make a feature "pass". The harness exists to prevent this. If acceptance is wrong, surface it to the user.
- **One feature per session.** Even if you have time. Long sessions on multiple features lead to merge pain and bad handoffs.
- **`features.json` is the source of truth** for what is and isn't done. Chat memory is not.
- **Append, never rewrite** `harness/progress.md`. History is load-bearing.
- **Never `--no-verify` a commit.** If a hook fails, fix the cause.
- **Worktrees only via `/parallel`.** Don't hand-roll `git worktree add` — the script keeps `features.json` consistent.

## Picking the next feature

When `/next` is invoked (or no feature is specified):

1. Filter `features.json` to entries with `passes: false` and `owner: null`.
2. Sort by `priority` ascending (P0 first), then by `id` ascending.
3. Pick the top entry. Set `owner` to the current session id and commit that change *before* starting work.

## Parallel feature work

If invoked via `/parallel <id>`:

1. Run `scripts/new-worktree.sh <id>` — creates `../<repo>-wt-<id>` and updates `features.json`.
2. The user opens a new `claude` session inside that worktree. *That* session executes the protocol above.
3. When the feature passes, the user runs `/ship <id>` from the worktree, which merges back into `main`.

## When you are blocked

- Missing acceptance detail → ask the user once; if no answer and auto mode, pick the simplest interpretation and write an ADR under `harness/decisions/`.
- Verify failing for unrelated reasons → fix the baseline first, commit that as its own change, then resume the feature.
- Stack not initialized (`init.sh` is still a template) → invoke the **devops** agent to fill it in.

## What lives where

| Concern | File |
|---|---|
| Product vision and requirements | `docs/spec.md` |
| Cross-cutting technical design | `docs/architecture.md` |
| Operational runbook | `docs/runbook.md` |
| Feature backlog (source of truth) | `harness/features.json` |
| Cross-session activity log | `harness/progress.md` |
| One-off decisions and tradeoffs | `harness/decisions/NNNN-<topic>.md` |
| Bring up dev environment | `harness/init.sh` |
| End-to-end smoke test | `harness/verify.sh` |
| Slash commands | `.claude/commands/` |
| Specialized agents | `.claude/agents/` |
| Hooks | `.claude/hooks/` |

## Entry points

| Command | When to use |
|---|---|
| `/start` | First session after cloning. Wizard that drafts `docs/spec.md`, optionally creates a GitHub repo, then runs `/kickoff`. |
| `/kickoff` | Power-user alternative: you already wrote `docs/spec.md` by hand. Seeds features, architecture, init/verify scripts. |
| `/next` | Every subsequent session. Builds the next P0 feature. |
| `/parallel <id>` | Spin off concurrent work in a git worktree. |
| `/status` | See backlog + recent activity. |
| `/verify` | Read-only sanity check of the dev environment. |
| `/retro <id>` | Post-feature reflection appended to `progress.md`. |
| `/ship <id>` | Merge a worktree feature back into main. |

## Session-end checklist

Before stopping, confirm:

- [ ] `harness/verify.sh` exits 0.
- [ ] If you flipped `passes: true`, you have evidence (test output, screenshot, curl response) recorded in `harness/progress.md`.
- [ ] `harness/progress.md` has a new entry for this session.
- [ ] `git status` is clean (everything committed).
- [ ] `owner` on the feature you worked on is cleared (set back to `null`) if the feature is not yet done.

The `stop.sh` hook will block termination if any of these are violated.
