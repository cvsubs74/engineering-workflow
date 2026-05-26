---
description: Summarize backlog and recent progress
allowed-tools: Bash, Read
---

# /status

Print a concise snapshot of the project state.

## Steps

1. **Backlog** — from `harness/features.json`:
   ```bash
   jq -r '
     .features
     | group_by(.priority)
     | map({priority: .[0].priority, total: length, done: ([.[] | select(.passes)] | length)})
     | .[]
     | "[\(.priority)] \(.done)/\(.total)"
   ' harness/features.json
   ```

2. **In flight** — features with `owner != null` and `passes: false`:
   ```bash
   jq -r '.features[] | select(.owner != null and .passes == false) | "  \(.id) \(.title) — owner: \(.owner) — worktree: \(.worktree // "main")"' harness/features.json
   ```

3. **Worktrees**:
   ```bash
   git worktree list
   ```

4. **Recent commits**:
   ```bash
   git log --oneline -10
   ```

5. **Last progress entry**:
   ```bash
   tail -n 30 harness/progress.md
   ```

6. **Next pick** — what `/next` would choose:
   ```bash
   jq -r '[.features[] | select(.passes == false and .owner == null)] | sort_by(.priority, .id) | .[0] | "  \(.priority) \(.id): \(.title)"' harness/features.json
   ```

Format as a short report. No prose narration.
