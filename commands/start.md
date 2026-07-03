---
name: "/retro-review:start"
description: Freezes the state the model delivered, before your manual review/fix — the baseline the cycle measures against
category: Workflow
tags: [workflow, retro-review, skills]
---

Freezes the worktree snapshot — what the model just delivered, **before** you review and fix it by hand. It's the zero mark against which `finish` will measure your fixes. Works across a whole monorepo: it **auto-discovers every nested git repo** under the root and freezes them all in one aggregated diff, in parallel.

**Input**: none. Operates on the current git state under the repository root.

**Steps**

1. **Resolve the feature name**

   Derive `<feature>` from the current branch, slugified (e.g. `feature/login-flow` → `login-flow`). On `main`/detached HEAD, or when repos are on different branches, ask the user for it. The cycle folder is `retro-review/cycles/<feature>/`.

2. **Check for an open cycle**

   If `retro-review/cycles/` already holds a folder with content (`snapshot.md` or `.snapshot-start.diff`), that's an unfinished cycle. **Don't overwrite it** — warn and tell the user to finish it with `/retro-review:finish` or drop it with `/retro-review:discard`. One cycle at a time.

3. **Freeze the delivered state (fast, multi-repo)**

   Run the snapshot script — it auto-discovers every nested git repo under the root, skips clean/vendored trees, and writes ONE aggregated diff with per-repo markers (`diff --retro-repo <repo>`):

   ```bash
   "${CLAUDE_PLUGIN_ROOT}"/scripts/retro-snapshot.sh \
     --label start \
     --out retro-review/cycles/<feature>/.snapshot-start.diff \
     --root .
   ```

   The script's **stdout** is a TSV manifest — one line per repo with changes: `<repo>  <path>  <branch>  <head>  <files-changed>`. Capture it to build the table in step 4. Don't run `git add -N .` or per-repo diffs by hand — the script already captures tracked **and** untracked content without touching the index. If the changes are stashed in a single repo, fall back to `git stash show -p stash@{0}`.

4. **Write the snapshot doc**

   Write `retro-review/cycles/<feature>/snapshot.md` from the manifest — this is the human-readable record of the baseline:

   ```markdown
   # Snapshot — <feature>

   **Timestamp:** <date>
   **Type:** multi-repo (<N> git repos) | single-repo
   **Frozen diff:** `.snapshot-start.diff` (aggregated across the repos, delimited by `diff --retro-repo <repo>` markers)

   ## Context

   <one short paragraph: what the model delivered for this change — the zero mark, BEFORE the manual review>

   ## Repos and HEAD

   | Repo | Branch | HEAD |
   |---|---|---|
   | `<repo>` | <branch> | `<head>` |

   ## Files touched (<total>)

   ### <repo> (<n>)
   - `<path>` <one-line note if useful>

   ## Note

   <anything worth flagging — e.g. the state already includes the code review agent's adjustments; the manual review from here is what `/retro-review:finish` will measure>
   ```

   Group "Files touched" per repo (derive the file list from the aggregated diff's per-repo sections). Write all prose in `config.language` (default `en`); keep paths, branches and hashes verbatim.

5. **Confirm**

   Announce that the snapshot is frozen and the user can now review/fix the code by hand.

**Output**

```
## Snapshot frozen

**Feature:** <feature>
**Repos:** <N> (<repoA>, <repoB>, ...)
**Files:** <total> touched

Review and fix the code by hand. When done, run `/retro-review:finish`.
(To abandon this cycle without proposing, run `/retro-review:discard`.)
```

**Output (open cycle)**

```
## Cycle already in progress

There's already a cycle folder for an unfinished cycle (<feature>).
Finish it with `/retro-review:finish`, or drop it with `/retro-review:discard`.
```

**Guardrails**

- **Nothing is analyzed here** — it only freezes.
- **Auto-discovery is the default** — every nested git repo with changes is captured; clean and vendored (`node_modules`, `build`, …) trees are skipped.
- Don't overwrite an open cycle folder — finish or discard it first.
- One cycle at a time.
- Don't commit and don't run `git add -N .`; the script captures untracked files without dirtying any index.
