---
name: "/retro-review:finish"
description: Detects your fixes, separates mistake from preference and writes Given/When/Then proposals
category: Workflow
tags: [workflow, retro-review, skills]
---

Detects what **you** changed after `start` (your manual review), separates a real model mistake from your own preference, and writes the skill-adjustment proposals in **Given/When/Then** format. Nothing is applied here.

**Input**: none. Requires a baseline frozen by `/retro-review:start` in `retro-review/cycles/<feature>/`.

Write every message to the user and all the prose in `proposals.md` (triage questions, Given/When/Then text) in `config.language` from `retro-review/config.yaml` (default `en`). Code, file/skill names and eval JSON stay as they are.

**Steps**

0. **Check the baseline**

   If `retro-review/cycles/<feature>/.snapshot-start.diff` doesn't exist, there's no open cycle. Ask to run `/retro-review:start` first and STOP.

1. **Isolate the changes (fast, multi-repo)**

   Re-run the same snapshot script with the `finish` label, then diff the two aggregated snapshots:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}"/scripts/retro-snapshot.sh \
     --label finish \
     --out retro-review/cycles/<feature>/.snapshot-finish.diff \
     --root .
   diff retro-review/cycles/<feature>/.snapshot-start.diff \
        retro-review/cycles/<feature>/.snapshot-finish.diff
   ```

   Both diffs carry the same `diff --retro-repo <repo>` markers, so the `diff` between them stays grouped per repo. What changed between start and finish is **your fix** — a candidate for a model mistake. Attribute each block to its repo via the nearest marker.

   Then compute the **utilization** ("aproveitamento") — how much of the model's delivery survived your review:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}"/scripts/retro-stats.sh \
     --start  retro-review/cycles/<feature>/.snapshot-start.diff \
     --finish retro-review/cycles/<feature>/.snapshot-finish.diff \
     --by-repo
   ```

   It prints `delivered / kept / changed / utilization_pct` for the whole cycle and per repo. This is the **raw** number (line churn, before triage). Hold on to it — you'll report it in step 5 next to a **quality-adjusted** version once triage separates real mistakes from mere preferences.

2. **Triage per block (mistake vs. preference)**

   For each change block, ask the user (use the **AskUserQuestion tool** when it fits):

   > Is this adjustment a **fix for a model mistake** or **your preference** (rename, move, style)?

   Only what's marked as a mistake moves on. Preferences are discarded — they don't become rules.

3. **Classify the cause** (for each confirmed mistake)
   - **Missing rule** — the skill doesn't cover this case → becomes an adjustment.
   - **Ignored rule** — the rule exists but didn't stick → an emphasis/triggering problem, not a content one.
   - **Non-systematic slip** — the model knew, slipped once → **don't touch the skill**, just note it.

   Before classifying, check `archive/` (via Grep) to see if this kind of mistake **has appeared before**. If it has and the rule already existed, the action isn't "add it again" — it's reinforce the example/emphasis or treat it as triggering.

4. **Write `proposals.md`**

   Only for "missing rule" and "ignored rule". Each proposal:

   ```markdown
   ## Proposal N — <short title>

   **Repo:** <repo where the fix landed>
   **Target skill:** <target-skill>
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

   ### Suggestion for the code review agent

   One-line concrete check the `code_review_agent` (from `config.yaml`) should have run to catch this — not a generic one.

   ### Eval

   - Location: `<target-skill>/evals/evals.json` (content) or `.../trigger_evals.json` (triggering)
   - Must **fail** on the current skill and **pass** on the adjusted one.
   ```

   **If no skill exists for the layer** where the mistake happened, don't force it into a generic skill — suggest creating **one skill per architectural layer** (e.g. `data`, `domain`, `presentation/ui`) and point out which layer the mistake fell in.

5. **Refine together**

   `proposals.md` is the living draft. Refine it with the user — cut, rewrite the rule, improve the example. Nothing is applied yet.

   Report the **utilization** from step 1, in two flavors:
   - **Raw** — straight from `retro-stats.sh`: `kept / delivered` of the model's added lines (per repo + total).
   - **Quality-adjusted** — only the lines you flagged as **real mistakes** in triage count against the model; preference edits don't lower its score. So `adjusted = (delivered − mistake_lines) / delivered`. A rename you made for taste shouldn't make the model look worse than it was.

**Output**

```
## Proposals written

**Cycle:** <feature>
**Confirmed mistakes:** N (M missing, K ignored)
**Discarded:** P preferences, Q slips

**Utilization of the model's delivery:**
- Raw: <total>%  (kept <kept>/<delivered> lines) — <repoA> <a>% · <repoB> <b>% · …
- Quality-adjusted: <adj>%  (only real mistakes counted against the model)

Draft in `retro-review/cycles/<feature>/proposals.md`.
Shall we refine before applying? When ready, run `/retro-review:apply`.
```

**Guardrails**

- **A preference doesn't become a rule** — the triage exists for that.
- **A non-systematic slip doesn't touch the skill** — just note it.
- Check recurrence in `archive/` before proposing a "new" rule.
- One mistake → one verifiable rule. If you can't write an eval that fails before and passes after, the rule is too vague.
- **Nothing is applied** in this phase.
