---
name: "SKILO: Propose"
description: Detects your fixes, separates mistake from preference and writes Given/When/Then proposals
category: Workflow
tags: [workflow, skilo, skills]
---

Detects what **you** changed after `explore`, separates a real model mistake from your own preference, and writes the skill-adjustment proposals in **Given/When/Then** format. Nothing is applied here.

**Input**: none. Requires a snapshot frozen by `/skilo-explore` in `skilo/cycles/<feature>/`.

**Steps**

0. **Check the snapshot**

   If `skilo/cycles/<feature>/.snapshot-explore.diff` doesn't exist, there's no open cycle. Ask to run `/skilo-explore` first and STOP.

1. **Isolate the changes**

   ```bash
   git add -N .
   git diff HEAD > skilo/cycles/<feature>/.snapshot-propose.diff
   diff skilo/cycles/<feature>/.snapshot-explore.diff skilo/cycles/<feature>/.snapshot-propose.diff
   ```

   What changed between explore and propose is your fix — a candidate for a model mistake.

2. **Triage per block (mistake vs. preference)**

   For each change block, ask the user (use the **AskUserQuestion tool** when it fits):

   > Is this adjustment a **fix for a model mistake** or **your preference** (rename, move, style)?

   Only what's marked as a mistake moves on. Preferences are discarded — they don't become rules.

3. **Classify the cause** (for each confirmed mistake)
   - **Missing rule** — the skill doesn't cover this case → becomes an adjustment.
   - **Ignored rule** — the rule exists but didn't stick → an emphasis/triggering problem, not a content one.
   - **Non-systematic slip** — the model knew, slipped once → **don't touch the skill**, just note it.

   Before classifying, check `archive/` (via Grep) to see if this kind of mistake **has appeared before**. If it has and the rule already existed, the action isn't "add it again" — it's reinforce the example/emphasis or treat it as triggering.

4. **Write `skilo-propose.md`**

   Only for "missing rule" and "ignored rule". Each proposal:

   ```markdown
   ## Proposal N — <short title>

   **Target skill:** cortex | art-front | <other>
   **Cause:** missing rule | ignored rule
   **Recurrence:** first time | already appeared in <ref>

   ### Spec (Given/When/Then)

   - **Given** <the context the model was in>
   - **When** <the decision/code it produced>
   - **Then** <what the skill should have made it do>

   ### Evidence

   - Model did (wrong): <snippet + file>
   - You left (correct): <snippet>

   ### Skill adjustment (before → after)

   <rule diff>

   ### Eval

   - Location: `<target-skill>/evals/evals.json` (content) or `.../trigger_evals.json` (triggering)
   - Must **fail** on the current skill and **pass** on the adjusted one.
   ```

5. **Refine together**

   `skilo-propose.md` is the living draft. Refine it with the user — cut, rewrite the rule, improve the example. Nothing is applied yet.

**Output**

```
## Proposals written

**Cycle:** <feature>
**Confirmed mistakes:** N (M missing, K ignored)
**Discarded:** P preferences, Q slips

Draft in `skilo/cycles/<feature>/skilo-propose.md`.
Shall we refine before applying? When ready, run `/skilo-apply`.
```

**Guardrails**

- **A preference doesn't become a rule** — the triage exists for that.
- **A non-systematic slip doesn't touch the skill** — just note it.
- Check recurrence in `archive/` before proposing a "new" rule.
- One mistake → one verifiable rule. If you can't write an eval that fails before and passes after, the rule is too vague.
- **Nothing is applied** in this phase.
