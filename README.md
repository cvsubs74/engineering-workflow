# engineering-workflow

A boilerplate for building **any product** with a team of Claude Code agents.

This repo ships a pre-wired **harness** — agent roles, slash commands, hooks, and a feature/progress tracking system — so that long-running agent work survives context resets and many parallel sessions. The design follows the patterns in Anthropic's [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

## What you get

- **Specialized agents** under `.claude/agents/` — product-manager, architect, implementer, tester, reviewer, devops.
- **Slash commands** under `.claude/commands/` — `/kickoff`, `/next`, `/parallel`, `/verify`, `/status`, `/retro`, `/ship`.
- **Hooks** under `.claude/hooks/` — session-start banner, stop-gate that blocks termination on inconsistent state.
- **Harness files** under `harness/` — `init.sh`, `verify.sh`, `features.json`, `progress.md`, `decisions/`.
- **Worktree-based parallelism** so multiple Claude sessions can build independent features concurrently.
- **Stack-agnostic.** `init.sh` and `verify.sh` are templates filled in by the devops agent on first run.

## Quick start

```bash
# 1. Clone this boilerplate as your new product repo
git clone https://github.com/cvsubs74/engineering-workflow my-product
cd my-product
rm -rf .git && git init -b main

# 2. Describe the product
$EDITOR docs/spec.md

# 3. Launch Claude Code and kick off
claude
> /kickoff
```

`/kickoff` will:
1. Run the **product-manager** agent to read `docs/spec.md` and seed `harness/features.json`.
2. Run the **architect** agent to draft `docs/architecture.md`.
3. Run the **devops** agent to fill in `harness/init.sh`, `harness/verify.sh`, and `.github/workflows/ci.yml` for the chosen stack.
4. Commit the seeded state.

After that, every new session is just:

```
> /next                 # build the highest-priority pending feature
# or
> /parallel F004        # build F004 in an isolated git worktree
```

## The loop

Every coding session runs this protocol (enforced by `CLAUDE.md` and the session-start hook):

1. `pwd` and read the last 5 commits.
2. Run `harness/init.sh` to bring up the dev environment.
3. Run `harness/verify.sh` to confirm a green baseline.
4. Read `harness/progress.md` and `harness/features.json`.
5. Pick **one** feature whose `passes` is `false`.
6. Pipeline: **product-manager → architect (if cross-cutting) → implementer → tester → reviewer**.
7. Tester flips `passes: true` only with end-to-end evidence.
8. Append a dated entry to `harness/progress.md`; commit.

The stop hook prevents ending a session with `passes: true` for a feature whose `verify.sh` is failing.

## Parallel work

Independent features can be built concurrently in git worktrees:

```
> /parallel F007
```

This creates `../<repo>-wt-F007`, records the worktree path in `features.json`, and lets you open a second `claude` session inside it. When done:

```
> /ship F007
```

merges the worktree, runs `verify.sh` on `main`, removes the worktree, and updates `progress.md`.

## Layout

```
.
├── CLAUDE.md                       Harness contract every session reads
├── .claude/
│   ├── settings.json               Permissions, hooks, env
│   ├── commands/                   Slash commands
│   ├── agents/                     Specialized subagents
│   └── hooks/                      session-start.sh, stop.sh
├── harness/
│   ├── init.sh                     Bring up dev env
│   ├── verify.sh                   End-to-end smoke test
│   ├── features.json               Backlog (source of truth)
│   ├── progress.md                 Append-only log
│   └── decisions/                  ADRs
├── docs/
│   ├── spec.md                     YOU fill this in
│   ├── architecture.md             Maintained by architect agent
│   └── runbook.md                  Ops notes
├── scripts/                        new-worktree.sh, merge-worktree.sh
└── .github/workflows/ci.yml        Runs verify.sh on PR
```

## Philosophy

- **One feature per session.** Forces clean handoffs.
- **Structured state on disk.** `features.json` and `progress.md` are the only sources of truth across sessions; no chat memory required.
- **Evidence over assertion.** A feature is only `passes: true` after `verify.sh` is green *and* an end-to-end test of the user-visible behavior succeeded.
- **The harness is the contract.** Agents must not edit acceptance criteria or remove tests to make things pass.

## License

MIT — see [LICENSE](./LICENSE).
