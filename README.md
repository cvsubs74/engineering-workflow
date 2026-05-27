# engineering-workflow

A boilerplate for building **any product** with a team of Claude Code agents, where **GitHub is the visible center of gravity for all work**.

This repo ships a pre-wired **harness** — agent roles, slash commands, hooks, scripts, and GitHub provisioning — so that long-running agent work survives context resets and many parallel sessions, with every meaningful project state visible on github.com. The design follows the patterns in Anthropic's [Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents).

## What you get

- **GitHub-first state.** Backlog lives as GitHub Issues. Epics → stories link via the sub-issues API. Status, Estimate, Iteration, and worktree paths live on a Projects v2 board. Priority and area are labels. There is **no `features.json`** — `gh` is the source of truth.
- **Specialized agents** under `.claude/agents/` — product-manager, architect, implementer, tester, reviewer, devops.
- **Slash commands** under `.claude/commands/` — `/start`, `/kickoff`, `/next`, `/parallel`, `/verify`, `/status`, `/retro`, `/ship`.
- **Hooks** under `.claude/hooks/` — session-start banner pulled from `gh`; stop-gate that blocks termination on inconsistent state.
- **Provisioning scripts** under `scripts/` — `gh-bootstrap.sh`, `gh-sub-issue.sh`, `gh-project.sh`, `gh-next-issue.sh`, plus worktree helpers.
- **GitHub assets** under `.github/` — issue forms (epic, story, bug, spike), PR template, CODEOWNERS, labels.json, CI workflow.
- **Worktree-based parallelism** so multiple Claude sessions can build independent issues concurrently.
- **Stack-agnostic.** `init.sh` and `verify.sh` are templates the devops agent fills in on first kickoff.

## Prerequisites

- **`gh` CLI ≥ 2.49** — sub-issues REST API is GA from January 2025. Install via `brew install gh` (macOS) or your platform equivalent.
- **`gh auth login` completed** with scopes including `repo`, `read:org`, and `project`. If you forgot `project`, run `gh auth refresh -s project,read:org`.
- **`jq`** — already required for label sync, project lookups, etc.

## Quick start

```bash
git clone https://github.com/cvsubs74/engineering-workflow my-product
cd my-product
claude
> /start
```

`/start` is a wizard that:

1. Preflights `gh` (version + auth scopes); errors out with install/refresh hints if missing.
2. Detaches your new directory from the boilerplate's git history (`rm -rf .git && git init -b main`).
3. Asks ~8 conversational questions about what you're building and drafts `docs/spec.md`.
4. Shows you the draft and lets you edit before saving.
5. **Creates a GitHub repo** (private by default; asks for account/visibility).
6. Personalizes `.github/CODEOWNERS` with your GitHub login.
7. Pushes the initial commit.
8. Runs `scripts/gh-bootstrap.sh` to sync labels, create the `v0.1` milestone, and provision a Projects v2 board with Status / Estimate / Iteration / Worktree fields.
9. Hands off to `/kickoff` — which dispatches the product-manager (files issues + sub-issue links), architect (drafts architecture, files ADR-0001 as a closed spike issue), and devops (fills `init.sh`/`verify.sh`/CI). Then it watches the first CI run and enables branch protection on `main` requiring the `verify` check.
10. Prints a next-steps banner with the project board URL, issue counts, and `/status`, `/next`, `/parallel`.

After that, every new session is just:

```
> /next                    # pick the top P0 issue, create branch, run pipeline, open PR
# or
> /parallel 42             # build issue #42 in an isolated worktree
```

### What you'll see on GitHub after `/start` + `/kickoff`

- A new repo, private (or public if you chose).
- Labels synced from `.github/labels.json` — `type:*`, `priority:*`, `area:*`, `meta:*`.
- A `v0.1` milestone.
- A Projects v2 board (titled after your repo) with custom fields Status, Estimate, Iteration, Worktree.
- 3-6 epic issues + 15-30 story issues, organized as sub-issues under their parent epic, all on the project board with Status=Todo.
- 4 closed `meta:bootstrap` issues forming the audit trail for what kickoff did (init.sh, verify.sh, CI, ADR-0001).
- `main` is protected: the `verify` CI check must pass before any PR can merge. Squash-merge with auto-delete-branch is the default.

### Power-user path (skip the wizard)

If you'd rather edit `docs/spec.md` by hand and create the GitHub repo yourself:

```bash
git clone https://github.com/cvsubs74/engineering-workflow my-product
cd my-product
rm -rf .git && git init -b main
$EDITOR docs/spec.md
# create + push to GitHub manually, then:
sed -i.bak "s/PLACEHOLDER_GITHUB_USER/$(gh api user --jq .login)/" .github/CODEOWNERS && rm -f .github/CODEOWNERS.bak
bash scripts/gh-bootstrap.sh
claude
> /kickoff
```

## The loop

Every coding session runs this protocol (enforced by `CLAUDE.md` and the session-start hook):

1. `pwd` and read the last 5 commits.
2. Run `harness/init.sh`.
3. Run `harness/verify.sh` — must be green.
4. Check GitHub: `gh issue list --assignee @me`, `gh pr list`.
5. Read `harness/progress.md` (personal log, not authoritative).
6. Pick **one** open issue (P0 first), no assignee, not an epic.
7. `gh issue edit <n> --add-assignee @me`, `git checkout -b issue-<n>-<slug>`.
8. Pipeline: **product-manager → architect (if cross-cutting) → implementer → tester → reviewer**.
9. Tester ticks `### Acceptance criteria` checkboxes via `gh issue edit`, posts evidence as a comment.
10. Push branch, `gh pr create --body "Closes #<n>"`, reviewer approves.
11. `/ship` squash-merges, closes the issue, moves board card to Done.
12. Append a dated entry to `harness/progress.md`; push.

The stop hook prevents ending a session while the branch's `verify.sh` is failing or uncommitted changes exist with no open PR.

## Parallel work

Independent issues can be built concurrently in git worktrees:

```
> /parallel 42
```

This validates issue #42 is open + unassigned + not an epic, creates `../<repo>-wt-issue-42` on branch `issue-42-<slug>`, and posts a comment on the issue announcing the worktree. Open a second `claude` session inside it.

When done, from the worktree:

```
> /ship
```

Pushes the branch, opens the PR if missing (with `Closes #42`), and once CI is green and review is approved, squash-merges into `main`.

## Layout

```
.
├── CLAUDE.md                       Harness contract every session reads
├── .claude/
│   ├── settings.json               Permissions, hooks, env
│   ├── commands/                   /start, /kickoff, /next, /parallel, /ship, /status, /retro, /verify
│   ├── agents/                     product-manager, architect, implementer, tester, reviewer, devops
│   └── hooks/                      session-start.sh (gh-driven banner), stop.sh
├── harness/
│   ├── init.sh                     Bring up dev env (filled at /kickoff by devops)
│   ├── verify.sh                   End-to-end smoke test (filled at /kickoff)
│   ├── progress.md                 Personal append-only session log (informational)
│   └── decisions/                  ADRs — each significant one is also a closed type:spike issue
├── docs/
│   ├── spec.md                     YOU fill this in (via /start wizard, or by hand)
│   ├── architecture.md             Maintained by architect agent
│   └── runbook.md                  Ops notes
├── scripts/
│   ├── gh-bootstrap.sh             Sync labels, milestone, Projects v2 board
│   ├── gh-sub-issue.sh             Link child issue under parent epic (REST sub-issues)
│   ├── gh-project.sh               add-item / set-status / set-field on Projects v2
│   ├── gh-next-issue.sh            Print next P0→P1→P2 open unassigned issue number
│   ├── new-worktree.sh             Create worktree on issue-<n>-<slug>
│   └── merge-worktree.sh           Push branch + open PR from worktree
└── .github/
    ├── ISSUE_TEMPLATE/             epic.yml, story.yml, bug.yml, spike.yml, config.yml
    ├── PULL_REQUEST_TEMPLATE.md    Closes #, evidence, checklist
    ├── CODEOWNERS                  Wildcard ownership; expandable for teams
    ├── labels.json                 Declarative label set, synced by gh-bootstrap.sh
    └── workflows/ci.yml            Runs verify.sh — job name `verify` is load-bearing for branch protection
```

## Philosophy

- **GitHub is THE place.** Backlog, status, audit trail, decisions, and discussion are visible on github.com. Local files are scaffolding; remote state is truth.
- **One issue per session.** Forces clean handoffs.
- **Structured state on remote.** GitHub Issues + Projects v2 + Labels carry everything across sessions — no chat memory required.
- **Evidence over assertion.** A PR may only merge after `verify.sh` is green AND tester evidence is posted AND `### Acceptance criteria` checkboxes are ticked.
- **The harness is the contract.** Agents must not edit acceptance criteria or remove tests to make things pass.

## License

MIT — see [LICENSE](./LICENSE).
