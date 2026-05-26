---
description: Merge a worktree feature back into main and clean up
allowed-tools: Bash, Read, Edit
argument-hint: <feature-id>
---

# /ship $ARGUMENTS

Merge the worktree for `$ARGUMENTS` back into `main`, verify the result, and clean up.

## Preconditions

- You are running this from inside the worktree for `$ARGUMENTS` (i.e. branch `feat/$ARGUMENTS`).
- The feature has `passes: true` in `harness/features.json`.
- `git status` is clean.
- `bash harness/verify.sh` exits 0 in the worktree.

If any precondition fails, stop and print the failing one.

## Steps

1. Confirm preconditions above.
2. Run `bash scripts/merge-worktree.sh $ARGUMENTS`. This will:
   - Switch to the main repo path.
   - Fetch and rebase the feature branch onto `main`.
   - Merge with `--no-ff` (preserves the feature commit boundary).
   - Run `bash harness/verify.sh` on `main`. If it fails, abort the merge (`git reset --merge HEAD~1`) and surface the failure.
   - Remove the worktree and delete the branch.
   - Clear the `worktree` field on the feature in `harness/features.json`.
3. Append to `harness/progress.md` on `main`:

```
## <YYYY-MM-DD HH:MM> — shipped F<NNN>
- Merged from worktree, verify green on main
```

4. Commit and print the new `git log --oneline -5`.

## Failure handling

- If verify fails on main post-merge, the script aborts the merge automatically. You'll get the verify output. Diagnose, fix in the worktree (which still exists if abort succeeded), and retry `/ship`.
- If merge conflicts, do NOT auto-resolve. Print the conflicted files and ask the user.
