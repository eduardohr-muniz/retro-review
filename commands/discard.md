---
name: "/retro-review:discard"
description: Drops the open cycle without applying anything — wipes the cycle folder, archives nothing
category: Workflow
tags: [workflow, retro-review, skills]
---

Abandons the current cycle. Deletes the open `retro-review/cycles/<feature>/` folder (snapshot, diffs, proposals) **without applying anything and without archiving**. Use it when the review produced no real model mistake, when you want to start the cycle over, or when the snapshot was frozen at the wrong moment.

**Input**: none. Operates on the open cycle under `retro-review/cycles/`.

**Steps**

1. **Find the open cycle**

   Locate the cycle folder under `retro-review/cycles/` (derive `<feature>` from the branch, or from the single folder present). If there's **no** open cycle, say so and STOP — nothing to discard.

2. **Show what will be dropped and confirm**

   Summarize the cycle before deleting — feature, whether `proposals.md` exists and how many proposals it holds — so the user isn't dropping unsaved work by accident. Then **ask for explicit confirmation** (AskUserQuestion):

   > Discard the cycle `<feature>`? This deletes the snapshot, diffs and proposals — nothing is applied or archived. This can't be undone.

   Only proceed on an explicit yes. If `proposals.md` has confirmed mistakes the user may want to keep, remind them that `/retro-review:apply` would apply them instead.

3. **Wipe the cycle**

   ```bash
   rm -rf retro-review/cycles/<feature>
   ```

   Leave `cycles/` ready for the next `/retro-review:start`. **Never touch `archive/`** — discard doesn't archive and doesn't remove past summaries.

**Output**

```
## Cycle discarded

**Feature:** <feature>

Dropped the snapshot, diffs and proposals. Nothing was applied or archived.
`cycles/` is clean — start over with `/retro-review:start`.
```

**Output (nothing to discard)**

```
## No open cycle

`retro-review/cycles/` has no open cycle. Nothing to discard.
```

**Guardrails**

- **Nothing is applied and nothing is archived** — discard is the opposite of `apply`.
- **Explicit confirmation required** — the cycle folder is deleted irreversibly.
- **Never touches `archive/`** — past summaries stay intact.
- If the user actually wants to keep the confirmed mistakes, point them to `/retro-review:apply` instead.
