---
description: Spawn a git worktree for parallel work on a feature
allowed-tools: Bash, Read, Edit
argument-hint: <feature-id>
---

# /parallel $ARGUMENTS

Create an isolated git worktree so another Claude session can build feature `$ARGUMENTS` in parallel without conflicting with the current session.

## Steps

1. Confirm `$ARGUMENTS` is a valid feature id in `harness/features.json` with `passes: false`.
2. Confirm it has no `worktree` already assigned. If it does, print the existing path and stop.
3. Run `bash scripts/new-worktree.sh $ARGUMENTS`. This will:
   - Create `../<repo-name>-wt-$ARGUMENTS` as a git worktree on a new branch `feat/$ARGUMENTS`.
   - Update `harness/features.json` to set `worktree` to the new path.
   - Commit the features.json update on `main`.
4. Print the worktree path and instruct the user:

```
Worktree ready at <path>. Open a new terminal and run:

  cd <path>
  claude
  > /next

That session will pick up $ARGUMENTS automatically (it's the only feature owned by this branch).

When done, run /ship $ARGUMENTS from the worktree to merge back.
```

## Notes

- Don't enter the worktree from this session. The point is a fresh Claude session per worktree so contexts don't tangle.
- If `scripts/new-worktree.sh` fails, do not partially commit; print the error.
