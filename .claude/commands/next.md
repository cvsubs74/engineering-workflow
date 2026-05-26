---
description: Build the next highest-priority pending feature, end to end
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Agent
---

# /next

Build **one** feature, sequentially, on the current branch. Use `/parallel <id>` instead if you want to work in a worktree.

## Steps

### 1. Verify baseline

```bash
pwd
git status                  # must be clean
git log --oneline -5
bash harness/init.sh
bash harness/verify.sh      # must exit 0
```

If `verify.sh` fails, **stop**. Fix the baseline as its own commit before picking a feature.

### 2. Pick the feature

```bash
jq -r '.features[] | select(.passes == false and .owner == null) | "\(.priority) \(.id) \(.title)"' harness/features.json \
  | sort | head -1
```

The first line is your feature. Set `owner`:

```bash
SESSION_ID="session-$(date +%s)-$$"
jq --arg id "<feature-id>" --arg owner "$SESSION_ID" \
  '(.features[] | select(.id == $id) | .owner) = $owner' \
  harness/features.json > harness/features.json.tmp \
  && mv harness/features.json.tmp harness/features.json
git add harness/features.json
git commit -m "Claim <feature-id>"
```

### 3. Run the agent pipeline

For the chosen feature, dispatch in order:

1. **product-manager** — re-read the feature's acceptance criteria. Flag ambiguity.
2. **architect** — only if the feature crosses module boundaries or adds dependencies.
3. **implementer** — write the code. Touches app code only, not harness or other features.
4. **tester** — runs `verify.sh` and an end-to-end check that maps directly to acceptance bullets. Flips `passes: true` only with evidence (logs, screenshots, HTTP responses).
5. **reviewer** — reads the diff. Blocks only on real issues.

Each agent's prompt: pass the feature's `id`, `title`, `description`, `acceptance` array, and a pointer to `docs/architecture.md`.

### 4. Commit

```bash
git add -A
git commit -m "F<NNN>: <title>"
```

### 5. Update progress

Append to `harness/progress.md`:

```
## <YYYY-MM-DD HH:MM> — F<NNN> <title>
- Implementer: <one-line summary of approach>
- Tester evidence: <how it was verified>
- Reviewer: <ok | issues>
```

### 6. Release the claim

If `passes: true`, leave `owner` as the session id (records who shipped it).
If you ran out of time and `passes` is still `false`, set `owner: null` so another session can pick it up.

```bash
jq --arg id "<feature-id>" \
  '(.features[] | select(.id == $id) | .owner) = null' \
  harness/features.json > harness/features.json.tmp \
  && mv harness/features.json.tmp harness/features.json
git add harness/features.json
git commit -m "Release <feature-id> for another session"
```

## Hard rules

- **Do not edit `acceptance`** to make a test pass. If acceptance is wrong, surface to user.
- **Do not touch other features** in the same session. If you find a blocker, file a new feature entry and stop.
- **Do not skip `verify.sh`.** It must be green before *and* after.
