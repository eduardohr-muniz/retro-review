---
name: "/retro-review:apply"
description: Applies the proposals, validates with evals, archives a lean summary and cleans up the cycle
category: Workflow
tags: [workflow, retro-review, skills]
---

Applies only what remains in `proposals.md`, validates each adjustment with an eval that proves both sides (fail before → pass after), archives a lean summary and **cleans up the cycle**.

**Input**: none. Requires a `retro-review/cycles/<feature>/proposals.md` refined by `/retro-review:finish`.

**Steps**

0. **Check the proposals**

   If `retro-review/cycles/<feature>/proposals.md` doesn't exist or is empty, there's nothing to apply. Ask to run `/retro-review:finish` first and STOP.

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

3. **Apply the adjustment — lean, subtract before you add**

   Copy the skill to an editable location if it's read-only (`/tmp/<skill>/`), preserving name and structure. Apply the rule diff — but keep it the **smallest edit that makes the eval pass**:

   - **Prefer editing an existing line** over adding a new one. If the skill already touches this case, sharpen the wording — don't append a parallel rule.
   - **At most ONE example per rule**, and only when the rule is ambiguous without it. Never a second example of the same point, never a code block that already appears elsewhere in the skill.
   - **No padding**: no preamble, no restating the rationale, no "for instance / as an example" filler. State the rule imperatively and stop.
   - **After applying, re-read the surrounding section** and cut any redundancy the new rule introduced. A skill that grew longer than the value it gained got polluted — trim it back.

4. **Prove it passes**

   Run the eval again — now it must **pass**.
   - Content mistake → `<target-skill>/evals/evals.json`.
   - Triggering mistake → `<target-skill>/evals/trigger_evals.json` + a `description` optimization loop via `skill-creator`.

   Delegate running the evals to `skill-creator`.

5. **Close the cycle** (always in this order)

   1. **Validate.** If any eval doesn't close the loop (fail before → pass after), **don't leave the adjustment standing** — report and go back to refinement. **Don't archive or clean up** while there's a pending proposal.
   2. **Optional code review agent adjustment.** For each proposal that carried a "Suggestion for the code review agent", **ask the user** whether to apply that check to the `code_review_agent` (from `config.yaml`). Only if they accept, edit the agent leanly (without duplicating an existing check).
   3. **Archive a lean summary** in `retro-review/archive/<feature>-<date>.md` (date as `dd-mm-yy`) — one line per adjustment, no diff, no code, no Given/When/Then:
      ```markdown
      # <feature> — <date>

      **Utilization:** <raw>% raw · <adjusted>% quality-adjusted

      - **<target skill>:** <rule adjusted in one line> — <cause: missing|ignored> — eval ✔
      - **code-review (<agent>):** <check added, if any> ✔
      ```

      Carry the utilization from `finish` into the header so the trend across cycles stays visible.
   4. **Clean up the cycle:**
      ```bash
      rm -rf retro-review/cycles/<feature>
      ```
      `cycles/` is left ready for the next `/retro-review:start`.

**Output (success)**

```
## Adjustments applied

**Cycle:** <feature>
**Utilization:** <raw>% raw · <adjusted>% quality-adjusted

- **<skill-a>:** <rule> — eval fail-before ✔ / pass-after ✔ — <skill-a>/evals/evals.json
- **<skill-b>:** <rule> — eval fail-before ✔ / pass-after ✔ — <skill-b>/evals/trigger_evals.json

Summary archived at `retro-review/archive/<feature>-<date>.md`.
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
- **Lean skill — subtract before you add.** Smallest edit that passes the eval; sharpen existing lines over adding new ones; one example max, only when needed; no padding. If the skill grew longer than the value it gained, trim it back.
