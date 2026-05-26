---
description: Append a retrospective entry to progress.md
allowed-tools: Bash, Read, Edit, Write
argument-hint: <feature-id>
---

# /retro $ARGUMENTS

Write a retrospective entry for feature `$ARGUMENTS` (or the last feature touched this session if no id is given) and append it to `harness/progress.md`.

## Steps

1. Identify the feature:
   - If `$ARGUMENTS` given, use it.
   - Otherwise, the last feature whose entry appears in `git log --oneline -10`.
2. Look at the diff for that feature: `git log -p -1 -- harness/features.json` and the corresponding `F<NNN>:` commit.
3. Append to `harness/progress.md`:

```
## <YYYY-MM-DD HH:MM> — retro F<NNN>
- **What worked**: <1-3 bullets>
- **What didn't**: <1-3 bullets, or "nothing notable">
- **Surprises**: <anything the implementer learned mid-build>
- **Follow-ups**: <new feature ids filed, or "none">
- **Memory candidates**: <facts worth saving to user/project memory, or "none">
```

4. Commit:

```bash
git add harness/progress.md
git commit -m "Retro: F<NNN>"
```

## Notes

- Retros are short. Three bullets per section is the cap. The point is to capture lessons, not write essays.
- If the retro surfaces new feature ideas, add them to `harness/features.json` with `priority: P2` and `passes: false`, and reference the new ids in the "Follow-ups" line.
