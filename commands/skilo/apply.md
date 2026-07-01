---
name: "SKILO: Apply"
description: Applies the proposals, validates with evals, archives a lean summary and cleans up the cycle
category: Workflow
tags: [workflow, skilo, skills]
---

Applies only what remains in `skilo-propose.md`, validates each adjustment with an eval that proves both sides (fail before → pass after), archives a lean summary and **cleans up the cycle**.

**Input**: none. Requires a `skilo/cycles/<feature>/skilo-propose.md` refined by `/skilo-propose`.

**Steps**

0. **Check the proposals**

   If `skilo/cycles/<feature>/skilo-propose.md` doesn't exist or is empty, there's nothing to apply. Ask to run `/skilo-propose` first and STOP.

1. **Normalize the target skill**

   For each target skill, ensure the pattern:
   ```
   <skill>/
   ├── SKILL.md
   ├── template.md
   ├── evals/          (evals.json, trigger_evals.json)
   └── references/
   ```
   If something is missing, create what's missing (empty folder/file) before touching the content.

2. **Write the eval and prove it fails**

   Write the eval in the target skill's `evals/` and run it against the **CURRENT** skill (without the adjustment). It must **fail** — proving it captures the mistake. If it already passes, the eval tests nothing; back to refinement.

3. **Apply the adjustment**

   Copy the skill to an editable location if it's read-only (`/tmp/<skill>/`), preserving name and structure. Apply the rule diff.

4. **Prove it passes**

   Run the eval again — now it must **pass**.
   - Content mistake → `<target-skill>/evals/evals.json`.
   - Triggering mistake → `<target-skill>/evals/trigger_evals.json` + a `description` optimization loop via `skill-creator`.

   Delegate running the evals to `skill-creator`.

5. **Close the cycle** (always in this order)

   1. **Validate.** If any eval doesn't close the loop (fail before → pass after), **don't leave the adjustment standing** — report and go back to refinement. **Don't archive or clean up** while there's a pending proposal.
   2. **Optional code review agent adjustment.** For each proposal that carried a "Suggestion for the code review agent", **ask the user** whether to apply that check to the `code_review_agent` (from `config.yaml`). Only if they accept, edit the agent leanly (without duplicating an existing check).
   3. **Archive a lean summary** in `skilo/archive/<feature>-<date>.md` (date as `dd-mm-yy`) — one line per adjustment, no diff, no code, no Given/When/Then:
      ```markdown
      # <feature> — <date>

      - **<target skill>:** <rule adjusted in one line> — <cause: missing|ignored> — eval ✔
      - **code-review (<agent>):** <check added, if any> ✔
      ```
   4. **Clean up the cycle:**
      ```bash
      rm -rf skilo/cycles/<feature>
      ```
      `cycles/` is left ready for the next `/skilo-explore`.

**Output (success)**

```
## Adjustments applied

**Cycle:** <feature>

- **cortex:** <rule> — eval fail-before ✔ / pass-after ✔ — cortex/evals/evals.json
- **art-front:** <rule> — eval fail-before ✔ / pass-after ✔ — art-front/evals/trigger_evals.json

Summary archived at `skilo/archive/<feature>-<date>.md`.
Cycle cleaned — `cycles/<feature>/` removed.
```

**Output (eval didn't close)**

```
## Apply paused

**Cycle:** <feature>

Proposal N didn't close the loop:
- Eval: <failed before? / passed after?>

Didn't archive or clean up. Back to refining this proposal.
```

**Guardrails**
- **An eval without "fail before" is invalid** — it must prove it captures the mistake.
- **Don't archive or clean up** while there's a pending proposal.
- **The cycle folder is ephemeral** — `apply` always removes it at the end of a valid cycle.
- **Lean summary** — one line per adjustment; the detailed evidence dies with the cycle folder.
- **Preserve the original skill's name and structure**; normalize before editing.
- **Lean skill** — if the rule already exists, reinforce the existing one instead of duplicating.
