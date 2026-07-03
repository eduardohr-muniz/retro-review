---
name: "retro-review:optimize-skills"
description: Diagnoses each skill's shape and optimizes it — trims text, extracts detail into references, or splits a multi-layer skill into per-layer skills — with evals guaranteeing behavior didn't change
category: Workflow
tags: [workflow, retro-review, skills, maintenance, architecture]
---

Sweeps one or more skills and optimizes them — but first **diagnoses the shape of the problem**, because a giant skill is almost never fixed by editing the prose inside it. There are three moves, and the diagnosis picks which one:

- **Trim** — text-level: cut redundancy and padding, surface conflicting rules, drop stale references, merge overlap. For a skill that's the right size but wordy.
- **Extract to references** — an oversized `SKILL.md`: move detail, long examples and edge-cases into `references/*.md`, leaving the always-loaded `SKILL.md` as lean rules + pointers (progressive disclosure). For a single-concern skill that simply carries too much detail inline.
- **Split by layer** — a skill that mixes **multiple architectural layers/concerns**: carve the off-layer part into its **own dedicated skill** — one skill per layer, the same lens as `/retro-review:skill-warmup`. For the "giant skill" that quietly became two.

The invariant across all three: the **set of rules is preserved** — nothing added, nothing removed. Optimization changes *where a rule lives and how it reads*, never *which rules exist*. Each affected skill's **evals prove it** (green before, green after). Housekeeping, not part of the `start → finish → apply` cycle.

**Input**: an optional target — a skill name, a path, or a glob (e.g. `data`, `.claude/skills/*`). Default: discover every skill under the repo root.

Write every message to the user in `config.language` from `retro-review/config.yaml` (default `en`). Skill files, eval JSON, code and file/skill names stay as they are.

**Steps**

0. **Resolve the targets**

   If a target was given, resolve it to skill folders. Otherwise discover all skills (a `SKILL.md` marks a skill root). If none are found, say so and STOP. List what will be audited and the size of each `SKILL.md` (lines) — size is the first signal of which move applies.

1. **Establish the safety net (per skill)**

   Run the skill's existing evals to get a **green baseline** (delegate running evals to `skill-creator`). Every optimization must keep these passing — they are the behavior contract, and when a rule moves to a new skill, its eval moves with it and must stay green there.
   - A skill **with no evals** has no safety net: flag it, and be conservative — trim only, ask before any structural move.

2. **Diagnose the shape (per skill) — this is the key step**

   Decide which move the skill needs before touching a line. Classify it:
   - **Already lean** — sharp rules, right size → leave it.
   - **Wordy, single concern, reasonable size** → **trim**.
   - **Single concern but oversized** — one architectural layer, but the `SKILL.md` is long because detail, multi-line examples and edge-cases are inline → **extract to references**. The rules stay in `SKILL.md`; the *detail* moves out.
   - **Multiple layers/concerns in one skill** — rules for two different layers (e.g. data access *and* UI state), or several unrelated trigger contexts, living together → **split by layer** into separate skills.

   Signals to read: `SKILL.md` length, how many distinct concerns/trigger contexts it covers, and the ratio of *rule* to *reference-detail*. **Don't default to trim** — if a 500-line skill spans two layers, sharpening its wording leaves it a 480-line skill spanning two layers. Name the diagnosis per skill and confirm it with the user before applying a structural move.

3. **Audit / plan per the diagnosis**

   - **Trim** — find redundancy (same point twice, a second example of a shown rule, a duplicated code block, restated rationale), padding (preamble, filler, three sentences for one imperative rule), conflict (two rules that contradict — **surface, never resolve silently**), and stale references (a path/file/skill/flag that no longer exists — verify with Grep/Glob first). Before flagging an example as redundant, check `archive/` (via Grep): an example kept for a **recurring** mistake is deliberate emphasis — don't cut it.
   - **Extract** — pick the blocks that are detail rather than rule (long examples, tables, edge-case walkthroughs, background) and plan a `references/<topic>.md` for each cluster, leaving a one-line pointer where the block was.
   - **Split** — identify the off-layer rules, name the new skill after its layer, and plan what moves: its rules, its examples, **and its evals**.

4. **Propose**

   Present the plan per skill — a before→after for trims, the new `references/` files for extractions, the new skill tree for splits — each with its reason. Nothing is applied yet.
   - **Ask before any structural move** (a split, or a large extraction) and before **removing** any whole rule/section/example.
   - Conflicts are **questions**: present both rules and let the user pick the winner.

5. **Apply per the diagnosis**

   Keep the set of rules identical; only relocate and sharpen.
   - **Trim** — sharpen an existing line rather than delete-and-rewrite; merge duplicates into the single strongest statement; cut, don't add. Never touch a line an eval depends on in a way that changes what it asserts.
   - **Extract** — move each detail block into `references/<topic>.md`; replace it in `SKILL.md` with a one-line pointer to the reference. The rule stays; the detail loads on demand.
   - **Split** — create the new per-layer skill via `skill-creator`, following the pattern (`SKILL.md` + `template.md` + `evals/` + `references/`). Move the off-layer rules **and their evals** into it, scope its `description` to the layer so it triggers there, and leave a pointer in the original if the two still relate. Delegate the creation to `skill-creator`.
   - **Preserve names and structure** for whatever stays; the always-loaded `SKILL.md` must come out **leaner** in every case. Any skill touched (or created) must follow the canonical pattern — `SKILL.md` + `template.md` + `evals/` (`evals.json`, `trigger_evals.json`) + `references/`; normalize a skill that doesn't before optimizing it.
   - **Genericize examples as you move them** — when extracting to `references/` or splitting into a new skill, replace any real domain name in the example code (`ProductModel`, `CheckoutService`) with a generic placeholder (`MyModel`, `MyService`, `foo`, `bar`). This is a rewrite of the *illustration*, not the *rule* — it doesn't touch what any eval asserts. A skill teaches a pattern, not a feature.

6. **Prove behavior held**

   Re-run the evals for **every affected skill — the original and any new one**. All must be **green**. A rule that moved to a new skill must pass its content eval *and* its triggering eval in the new home. If any eval that was passing now fails, the optimization changed behavior: **revert that move** and report it. A red eval after optimization is a failed optimization, not an accepted trade-off.

7. **Report**

**Output**

```
## Skills optimized

**Audited:** <n> skills · evals green before ✔ / after ✔

- **<skill-a>** — trimmed: <before> → <after> lines (2 dup examples, 1 padding block)
- **<skill-b>** — extracted: <before> → <after> lines in SKILL.md; detail moved to `references/mapping.md`, `references/errors.md`
- **<skill-c>** — split: UI-state rules carved into new skill `presentation-state` (rules + evals migrated); `<skill-c>` now single-layer
- **<skill-d>** — no change, already lean

**Surfaced (needs your call):**
- **<skill-b>:** conflict between rule X and rule Y — which wins?

Set of rules unchanged across every skill; behavior is eval-guaranteed.
```

**Output (structural move suggested)**

```
## <skill> is two skills in one

`<skill>/SKILL.md` is <N> lines covering **<layer-a>** and **<layer-b>** — trimming the prose
won't fix that. I recommend splitting the <layer-b> rules into a new `<layer-b>` skill
(rules + evals migrated), leaving `<skill>` single-layer. Apply the split?
```

**Output (a skill has no evals)**

```
## <skill> has no safety net

No evals in `<skill>/evals/` — I can't prove a move keeps behavior.
Trimmed only the safe prose (padding, duplicates) and left every rule and the structure untouched.
Add an eval so a future run can extract to references or split it safely.
```

**Guardrails**

- **Diagnose the shape first** — a giant skill is usually a *structure* problem (references or split), not a text one. Never answer an oversized skill with prose trimming alone.
- **The set of rules is the invariant** — extract and split relocate rules, they never add or remove them. Removing a rule is a `finish`/`apply` decision, not an optimization.
- **One skill per layer** — same lens as `skill-warmup`. If a skill spans two layers, the fix is a new skill, not sharper wording.
- **Evals move with the rules** — a split migrates each rule's content *and* triggering evals to the new skill; green before, green after in the new home.
- **Progressive disclosure** — `SKILL.md` holds the rules; `references/` holds the detail the model reads on demand. The always-loaded `SKILL.md` must get leaner every time.
- **Conflicts are surfaced, not resolved** — always ask which rule wins.
- **Examples stay generic** — placeholder names (`MyModel`, `foo`, `bar`), never a real domain name from the codebase. Genericizing an example rewrites the illustration, not the rule — no eval changes.
- **Check recurrence before cutting an example** — a repeated mistake's example is deliberate emphasis.
- **Ask before any structural move or removal**; a skill with no evals gets trim-only.
- **A red eval after a move means revert** — a failed optimization, never an accepted trade-off.
