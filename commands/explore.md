---
name: "SKILO: Explore"
description: Freezes the state the model delivered, before the manual fix
category: Workflow
tags: [workflow, skilo, skills]
---

Freezes the worktree snapshot — what the model just delivered, **before** you fix it by hand. It's the zero mark against which `propose` will measure your fixes.

**Input**: none. Operates on the current git state in the feature's directory.

**Steps**

1. **Resolve the feature name**

   Derive `<feature>` from the current branch, slugified (e.g. `feature/login-flow` → `login-flow`). On `main` or a detached HEAD, ask the user for it. The cycle folder is `skilo/cycles/<feature>/`.

2. **Check for an open cycle**

   If `skilo/cycles/` already holds a folder with content (`snapshot.md` or `.snapshot-explore.diff`), that's an unfinished cycle. **Don't overwrite it** — warn and ask whether to discard it before proceeding. One cycle at a time.

3. **Isolate the delivered state**

   ```bash
   git add -N .
   git diff HEAD > skilo/cycles/<feature>/.snapshot-explore.diff
   git diff HEAD --stat
   ```

   `git add -N` makes new (untracked) files show up in the diff without committing. If the changes are stashed, use `git stash show -p stash@{0}` as the source.

4. **Write the snapshot**

   Write `skilo/cycles/<feature>/snapshot.md` with:
   - Branch, HEAD (`git rev-parse --short HEAD`), timestamp.
   - List of files touched (from `--stat`).
   - Reference to `.snapshot-explore.diff`.

5. **Confirm**

   Announce that the snapshot is frozen and the user can now fix the code by hand.

**Output**

```
## Snapshot frozen

**Feature:** <feature>
**Branch:** <branch>
**HEAD:** <short-hash>
**Files:** N touched

Fix the code by hand. When done, run `/skilo:propose`.
```

**Output (open cycle)**

```
## Cycle already in progress

There's already a cycle folder for an unfinished cycle (<feature>).
Discard it and start over, or finish the current one first with `/skilo:propose`?
```

**Guardrails**

- **Nothing is analyzed here** — it only freezes.
- Don't overwrite an open cycle folder without explicit confirmation.
- One cycle at a time.
- Don't commit; use `git add -N` to capture untracked files without dirtying the index.
