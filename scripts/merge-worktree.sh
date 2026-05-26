#!/usr/bin/env bash
# merge-worktree.sh <feature-id>
# Merges feat/<id> into main, verifies, removes the worktree, clears
# the worktree field in harness/features.json. Run from inside the worktree.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <feature-id>" >&2
  exit 2
fi

FID="$1"

WT_ROOT="$(git rev-parse --show-toplevel)"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
EXPECTED_BRANCH="feat/${FID}"

if [ "$BRANCH" != "$EXPECTED_BRANCH" ]; then
  echo "error: not on $EXPECTED_BRANCH (currently on $BRANCH)" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required" >&2
  exit 1
fi

if [ -n "$(git status --porcelain)" ]; then
  echo "error: working tree not clean" >&2
  exit 1
fi

# Find the main repo path (the worktree this branch was created from)
MAIN_ROOT="$(git worktree list --porcelain | awk '$1=="worktree"{p=$2} $1=="bare"{p=""} $1=="branch" && $2 ~ /^refs\/heads\/main$|^refs\/heads\/master$/ {print p; exit}')"

if [ -z "$MAIN_ROOT" ] || [ ! -d "$MAIN_ROOT" ]; then
  echo "error: could not locate main worktree" >&2
  exit 1
fi

# Confirm passes=true on main's view of features.json
PASSES=$(jq -r --arg id "$FID" '.features[] | select(.id == $id) | .passes' "$MAIN_ROOT/harness/features.json")
if [ "$PASSES" != "true" ]; then
  echo "error: feature $FID is not passes=true. Tester must flip the flag first." >&2
  exit 1
fi

# verify in the worktree
echo "Running verify.sh in worktree..."
bash harness/verify.sh

# Push branch state to main (we're a local worktree, so no remote step needed yet)
cd "$MAIN_ROOT"
MAIN_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "Merging $EXPECTED_BRANCH into $MAIN_BRANCH..."
if ! git merge --no-ff "$EXPECTED_BRANCH" -m "Merge $EXPECTED_BRANCH"; then
  echo "error: merge conflict. Resolve manually then rerun /ship." >&2
  exit 1
fi

echo "Running verify.sh on $MAIN_BRANCH..."
if ! bash harness/verify.sh; then
  echo "error: verify failed on main after merge. Reverting." >&2
  git reset --merge HEAD~1
  exit 1
fi

# Clear worktree field in features.json
jq --arg id "$FID" \
  '(.features[] | select(.id == $id) | .worktree) = null' \
  harness/features.json > harness/features.json.tmp \
  && mv harness/features.json.tmp harness/features.json

git add harness/features.json
git commit -m "Shipped $FID; worktree removed"

# Remove the worktree
git worktree remove "$WT_ROOT"
git branch -d "$EXPECTED_BRANCH" || true

echo
echo "Shipped $FID. Recent log:"
git log --oneline -5
