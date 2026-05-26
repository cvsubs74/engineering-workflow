---
description: First-session bootstrap — seed features.json, architecture.md, init.sh from docs/spec.md
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

# /kickoff

You are running the **first session** of a new product built on the engineering-workflow harness. Your job is to bootstrap the project from `docs/spec.md` so every future session has the state it needs.

## Preconditions

1. Confirm `docs/spec.md` exists and is non-empty. If empty, stop and ask the user to fill it in.
2. Confirm `harness/features.json` either does not exist or contains an empty features array. If it already has features, ask the user whether to abort or re-kickoff (destructive).

## Steps

Run these subagents in order. Each receives a focused prompt; do not collapse them into one call.

### 1. product-manager — seed the backlog

Dispatch the `product-manager` agent with this brief:

> Read `docs/spec.md`. Break the product into 15-50 atomic features. Each feature must have:
> - `id` (F001, F002, …)
> - `title` (imperative, ≤ 70 chars)
> - `description` (1-3 sentences)
> - `acceptance` (array of testable bullets — what makes this pass)
> - `priority` (P0 must-have for MVP, P1 important, P2 nice-to-have)
> - `passes: false`
> - `owner: null`
> - `worktree: null`
>
> Write the result to `harness/features.json` in the schema:
> `{ "features": [ ... ] }`
>
> Aim for features that are independent (can ship without each other) and that one agent session can finish.

### 2. architect — draft architecture

Dispatch the `architect` agent:

> Read `docs/spec.md` and `harness/features.json`. Draft `docs/architecture.md` covering:
> - Stack choice (with rationale, recorded as an ADR in `harness/decisions/0001-stack.md`)
> - Module/service boundaries
> - Data model sketch
> - External dependencies
> - Cross-cutting concerns (auth, logging, config)
>
> Keep it under 800 words. This is a living doc; later features will update it.

### 3. devops — fill in init.sh and verify.sh

Dispatch the `devops` agent:

> Read `docs/architecture.md` for the stack choice. Fill in `harness/init.sh` so it installs deps and starts the dev server idempotently. Fill in `harness/verify.sh` so it runs a real end-to-end smoke test (HTTP probe, CLI invocation, or browser check — whatever matches the stack).
>
> Also write `.github/workflows/ci.yml` to run `harness/verify.sh` on every PR.
>
> Both scripts must exit 0 on success and non-zero on failure.

### 4. Initialize progress.md

Append the kickoff entry to `harness/progress.md`:

```
## <YYYY-MM-DD HH:MM> — kickoff
- Spec read from docs/spec.md
- features.json seeded with <N> features (P0: <a>, P1: <b>, P2: <c>)
- Architecture: <one-line summary of stack choice>
- init.sh / verify.sh ready
```

### 5. Commit

```
git add -A
git commit -m "Kickoff: seed features, architecture, harness scripts"
```

### 6. Report

Print a short report to the user:
- N features seeded, broken down by priority
- Chosen stack
- Suggested next command (`/next` to start the first P0)

## Failure handling

- If any subagent fails, do **not** partially commit. Roll back with `git restore .` and surface the error.
- If the user's spec is too vague to break into features, ask one focused question; if no answer in auto mode, write what you can and flag gaps in `docs/spec.md` as `<!-- GAP: ... -->` comments.
