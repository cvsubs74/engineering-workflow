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
git clone https://github.com/cvsubs74/engineering-workflow my-product
cd my-product
claude
> /start
```

`/start` is a wizard that:

1. Detaches your new directory from the boilerplate's git history (`rm -rf .git && git init -b main`).
2. Asks 8 conversational questions about what you're building and drafts `docs/spec.md`.
3. Shows you the draft and lets you edit before saving.
4. Optionally creates a GitHub repo for you (private by default; asks for account/visibility).
5. Makes the initial commit and pushes if you set up a remote.
6. Hands off to `/kickoff` — which dispatches the product-manager, architect, and devops agents to seed the feature backlog, choose a stack, and fill in `init.sh`/`verify.sh`/CI.
7. Prints a next-steps banner with `/status`, `/next`, `/parallel`.

After that, every new session is just:

```
> /next                 # build the highest-priority pending feature
# or
> /parallel F004        # build F004 in an isolated git worktree
```

### Power-user path (skip the wizard)

If you'd rather edit `docs/spec.md` by hand:

```bash
git clone https://github.com/cvsubs74/engineering-workflow my-product
cd my-product
rm -rf .git && git init -b main
$EDITOR docs/spec.md
claude
> /kickoff
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
