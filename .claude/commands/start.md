---
description: New-product wizard — detach from boilerplate, fill in spec.md, optionally create GitHub repo, run /kickoff
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent, AskUserQuestion
---

# /start

You are running the **new-product wizard**. The user just cloned `engineering-workflow` into a fresh directory and ran Claude here. Your job is to walk them from "empty boilerplate" to "first feature ready to build" without them touching files.

Be conversational. Ask one (or at most two related) questions per turn. The user is likely not a power user — don't dump JSON in their face; summarize.

---

## Step 1 — Detect state

Run these checks silently before asking anything:

```bash
pwd
git rev-parse --is-inside-work-tree 2>/dev/null && echo "git: yes" || echo "git: no"
git remote get-url origin 2>/dev/null || echo "no remote"
git log --oneline -3 2>/dev/null || echo "no commits"
test -f harness/features.json && jq '.features | length' harness/features.json || echo "no features"
test -f docs/spec.md && wc -l docs/spec.md || echo "no spec"
```

Classify into one of:

- **A. Fresh clone of boilerplate** — `.git` exists, `origin` is `…cvsubs74/engineering-workflow…`, `features.json` has 0 features. **Most common case.** Proceed.
- **B. Already kicked off** — `features.json` has ≥1 feature. **Stop the wizard.** Tell the user:
  > This project is already kicked off (N features in the backlog). Use `/status` to see them, `/next` to build the next one, or edit `docs/spec.md` and re-run `/kickoff` if scope changed.
- **C. Wizard already ran but no kickoff** — `docs/spec.md` differs from the template (has user-written content) AND no features. Ask: "It looks like spec.md is already filled in. Want to (1) review & confirm and skip to kickoff, (2) restart the wizard, or (3) cancel?"
- **D. No git at all** — `.git` missing entirely. Skip step 2's "detach" question; just plan to `git init` later in step 6.

Print a single-sentence state summary to the user before any questions. Example:

> Fresh clone detected. I'll help you set this up as a new product — should take 3–5 minutes.

---

## Step 2 — Detach from the boilerplate (only for state A)

If `origin` points at the engineering-workflow repo, ask:

> This directory still tracks the boilerplate repo as `origin`. I'll detach git so your work isn't tied to it. OK to run `rm -rf .git && git init -b main`?

If yes:
```bash
rm -rf .git
git init -b main
```

If no: stop and tell the user to detach manually before re-running `/start`.

---

## Step 3 — Spec wizard (conversational Q&A)

Tell the user:

> I'll ask 8 short questions to draft `docs/spec.md`. Skip any with "skip" — we can fill them in later.

Ask these **one or two at a time**, conversationally, not as a numbered form. Adapt phrasing to the conversation. Hold answers in your context — don't write to disk until step 4.

1. **Product name** — short, lowercase, kebab-case preferred. (Example: `expense-wise`, `interrogator`.)
2. **One-line pitch** — what it does and for whom. (Example: "A web app that helps freelancers track time and bill clients in under 30 seconds.")
3. **Why does this exist?** What pain or opportunity? 1–3 sentences.
4. **Who are the primary users?** 1–3 sentences. If multiple user types, list them.
5. **Top 3–7 user flows.** What does someone do with this product? Step-by-step bullets are fine.
6. **MVP must-haves.** Bulleted list of capabilities. Push back gently if the list is huge — MVPs ship faster with 5–10 items, not 30.
7. **Nice-to-haves and out-of-scope.** What can wait? What are you explicitly NOT building? Helpful to capture both.
8. **Stack preferences and constraints?** (Optional.) Language, framework, hosting target, performance/compliance constraints. If they don't care, say "no preference" — the architect agent will pick on `/kickoff`.

After the answers, ask:
> One last thing — what does success look like for the MVP? (e.g. "5 friends actively using it", "first paying customer", "personal use working end-to-end")

---

## Step 4 — Draft and confirm `docs/spec.md`

Write `docs/spec.md` filling in the template at the existing path, mapping wizard answers to sections:

```markdown
# <product-name>

> <one-line pitch>

## What we're building
<expanded from pitch + flows>

## Why
<from Q3>

## Primary users
<from Q4>

## Core user flows
1. <flow 1>
2. <flow 2>
…

## Must-have features (MVP)
- <capability>
- <capability>

## Should-have features
- <capability>

## Out of scope (for now)
- <thing>

## Constraints
- <constraint, or "No specific stack preference — architect to decide.">

## Success criteria
- <metric>
```

Then **show the user the rendered spec** (read the file back and quote it inline). Ask:

> Here's `docs/spec.md`. Does this capture it? You can say:
> - "looks good" → I'll proceed
> - "edit X to say Y" → I'll patch and re-show
> - "restart" → I'll re-run the wizard
> - "save and stop" → I'll save as-is and you can edit by hand later

Loop on edits until the user approves or says "save and stop".

---

## Step 5 — GitHub repo (optional)

Ask:

> Want me to create a GitHub repo for this now? (yes / no — you can do it later)

If no, skip to step 6.

If yes, gather details. Use AskUserQuestion for the visibility choice (it's a real choice that matters). Free-text answers (org, repo name) — just ask in chat with defaults.

1. **Account/org**: default to `gh api user --jq .login`. Ask:
   > Create under your account `<default>` or a different org? (press enter for default)
2. **Repo name**: default to `$(basename "$PWD")`. Ask if they want a different name.
3. **Visibility**: ask via AskUserQuestion with two options — Private (recommended for new work) and Public. **Do not** default to Public; that's destructive to recall.

Create it:
```bash
gh repo create <owner>/<name> --<visibility> --source=. --remote=origin --description "<one-line pitch>"
```

Do NOT push yet — first commit comes in step 6.

If `gh` errors, surface the error and ask whether to retry, skip, or abort.

---

## Step 6 — Initial commit (+ push)

Stage and commit:
```bash
git add -A
git commit -m "Initial commit: <product-name> from engineering-workflow boilerplate"
```

If a remote was set up in step 5:
```bash
git push -u origin main
```

---

## Step 7 — Hand off to `/kickoff`

Tell the user:

> Spec saved. Running `/kickoff` now — this dispatches the product-manager (to seed the backlog), the architect (to pick the stack and draft architecture), and the devops agent (to fill in init.sh / verify.sh / CI). Takes 2–4 minutes.

Then execute the `/kickoff` flow described in `.claude/commands/kickoff.md`. Do not re-implement it — invoke its steps in order. When kickoff commits, push if a remote exists:

```bash
git push 2>/dev/null || true
```

---

## Step 8 — Next-steps banner

Print exactly this format (filling in actuals):

```
✓ Project bootstrapped: <product-name>
  Stack: <chosen stack>
  Features seeded: <N> total (P0: <a>, P1: <b>, P2: <c>)
  GitHub: <url or "not connected">

What's next:
  /status                 see the backlog
  /next                   build the highest-priority P0 feature
  /parallel <feature-id>  spin off concurrent work in a git worktree
  /verify                 sanity-check the dev environment any time

When in doubt, read CLAUDE.md — it's the contract every session follows.
```

---

## Hard rules for the wizard

- **Don't write `docs/spec.md` until step 4** — keep answers in chat until you've shown the user the draft and they approved.
- **Don't create the GitHub repo as public by default.** Always ask via AskUserQuestion. The default in your prompt should be Private.
- **Don't push before the user confirmed the spec.**
- **Don't skip `/kickoff`.** If the user says they want to do kickoff later, that's fine — but tell them clearly the project isn't usable until kickoff runs.
- **Don't be chatty.** Two sentences per turn, max, between questions.
- **If interrupted**, the user can re-run `/start` — step 1's state detection will pick up where things left off.
