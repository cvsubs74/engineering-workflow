#!/usr/bin/env bash
# Stop-gate: block session termination on inconsistent harness state.
#
# Blocks if:
#   - Any feature has passes=true but verify.sh is currently failing.
#   - Any feature has owner=<current> but passes=false AND uncommitted changes exist.
#   - harness/progress.md was not updated this session (no entry with today's date).

set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# If kickoff hasn't run yet, allow stop.
[ -f harness/features.json ] || exit 0

if ! command -v jq >/dev/null 2>&1; then
  # Can't introspect without jq — fail open with a warning.
  echo "stop.sh: jq not available; skipping consistency checks." >&2
  exit 0
fi

problems=()

# Check: any uncommitted changes alongside an in-progress feature?
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  in_progress=$(jq -r '[.features[] | select(.owner != null and .passes == false)] | length' harness/features.json)
  if [ "$in_progress" -gt 0 ]; then
    problems+=("Uncommitted changes exist while features are owned but not passing. Commit or clear owner.")
  fi
fi

# Check: any feature claiming passes=true while verify.sh fails?
passing_count=$(jq -r '[.features[] | select(.passes == true)] | length' harness/features.json)
if [ "$passing_count" -gt 0 ] && [ -x harness/verify.sh ]; then
  if ! bash harness/verify.sh >/dev/null 2>&1; then
    problems+=("Features marked passes=true but harness/verify.sh is failing. Either fix verify or revert the passes flag.")
  fi
fi

# Check: did this session log to progress.md?
today=$(date +%Y-%m-%d)
if [ -f harness/progress.md ]; then
  if ! grep -q "$today" harness/progress.md 2>/dev/null; then
    problems+=("harness/progress.md has no entry for today ($today). Run /retro or append a note before stopping.")
  fi
fi

if [ ${#problems[@]} -eq 0 ]; then
  exit 0
fi

echo "stop.sh: blocking termination — fix these before ending the session:" >&2
for p in "${problems[@]}"; do
  echo "  - $p" >&2
done
exit 2
