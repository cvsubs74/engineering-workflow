#!/usr/bin/env bash
# new-worktree.sh <feature-id>
# Creates ../<repo>-wt-<id> as a git worktree on a new branch feat/<id>
# and records the path in harness/features.json.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <feature-id>" >&2
  exit 2
fi

FID="$1"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi

# Validate feature exists and is open
EXISTS=$(jq --arg id "$FID" '[.features[] | select(.id == $id)] | length' harness/features.json)
if [ "$EXISTS" -eq 0 ]; then
  echo "error: feature $FID not found in harness/features.json" >&2
  exit 1
fi

PASSES=$(jq -r --arg id "$FID" '.features[] | select(.id == $id) | .passes' harness/features.json)
if [ "$PASSES" = "true" ]; then
  echo "error: feature $FID already passes; nothing to build" >&2
  exit 1
fi

EXISTING_WT=$(jq -r --arg id "$FID" '.features[] | select(.id == $id) | .worktree // ""' harness/features.json)
if [ -n "$EXISTING_WT" ] && [ "$EXISTING_WT" != "null" ]; then
  echo "error: feature $FID already has a worktree at $EXISTING_WT" >&2
  exit 1
fi

REPO_NAME="$(basename "$ROOT")"
WT_PATH="$(cd .. && pwd)/${REPO_NAME}-wt-${FID}"
BRANCH="feat/${FID}"

if [ -e "$WT_PATH" ]; then
  echo "error: $WT_PATH already exists" >&2
  exit 1
fi

# Create the worktree on a new branch off main
BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git worktree add -b "$BRANCH" "$WT_PATH" "$BASE_BRANCH"

# Update features.json on main
jq --arg id "$FID" --arg wt "$WT_PATH" \
  '(.features[] | select(.id == $id) | .worktree) = $wt' \
  harness/features.json > harness/features.json.tmp \
  && mv harness/features.json.tmp harness/features.json

git add harness/features.json
git commit -m "Worktree for $FID at $(basename "$WT_PATH")"

echo
echo "Worktree ready: $WT_PATH (branch $BRANCH)"
echo
echo "Open a new terminal:"
echo "  cd \"$WT_PATH\""
echo "  claude"
echo "  > /next"
