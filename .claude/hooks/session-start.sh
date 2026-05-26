#!/usr/bin/env bash
# Session-start banner: orient any new Claude session.
# Output goes to additionalContext for the model.

set -u

cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "=== engineering-workflow harness ==="
echo "cwd: $(pwd)"
echo

if [ -d .git ]; then
  echo "--- last 5 commits ---"
  git log --oneline -5 2>/dev/null || echo "(no commits yet)"
  echo
  echo "--- branch ---"
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(detached)"
  echo
fi

if [ -f harness/features.json ]; then
  if command -v jq >/dev/null 2>&1; then
    total=$(jq '.features | length' harness/features.json 2>/dev/null || echo "?")
    open=$(jq '[.features[] | select(.passes == false)] | length' harness/features.json 2>/dev/null || echo "?")
    echo "--- features ---"
    echo "open: $open / total: $total"
    echo
    echo "--- next 5 open ---"
    jq -r '.features[] | select(.passes == false) | "  [\(.priority // "P?")] \(.id): \(.title)"' harness/features.json 2>/dev/null | head -5
    echo
  else
    echo "(jq not installed; install for full banner)"
  fi
else
  echo "--- features.json not found ---"
  echo "Run /kickoff to seed the backlog."
  echo
fi

if [ -f harness/progress.md ]; then
  echo "--- last progress entry ---"
  tail -n 20 harness/progress.md
  echo
fi

echo "Next: read CLAUDE.md and run /next (or /kickoff if this is the first session)."
