---
name: "retro-review:optimize-skills"
description: Audits skills for redundant, conflicting or stale content and trims them lean — behavior guaranteed by their own evals
category: Workflow
tags: [workflow, retro-review, skills, maintenance]
---

Sweeps one or more skills and **optimizes their content**: cuts redundancy and padding, surfaces conflicting rules, drops stale references, and merges overlap — while their **evals prove behavior didn't change** (green before, green after). This is housekeeping, not part of the `start → finish → apply` cycle — run it whenever a skill has grown into a pile of examples instead of a set of sharp rules.

**Input**: an optional target — a skill name, a path, or a glob (e.g. `data`, `.claude/skills/*`). Default: discover every skill under the repo root.

Write every message to the user in `config.language` from `retro-review/config.yaml` (default `en`). Skill files, eval JSON, code and file/skill names stay as they are.

**Steps**

0. **Resolve the targets**

   If a target was given, resolve it to skill folders. Otherwise discover all skills (a `SKILL.md` marks a skill root). If none are found, say so and STOP. List what will be audited and its size (lines of `SKILL.md`) so the user sees the starting point.

1. **Establish the safety net (per skill)**

   Run the skill's existing evals to get a **green baseline** (delegate running evals to `skill-creator`). Optimization must keep every one of these passing — they are the behavior contract.
   - A skill **with no evals** has no safety net: flag it, and be conservative (form-only edits, ask before cutting any rule).

2. **Audit — what to cut, per skill**

   Read `SKILL.md` (and its references) and look for:
   - **Redundancy** — the same point stated twice, a second example of a rule already shown, a code block duplicated elsewhere, restated rationale ("as mentioned above…").
   - **Padding** — preamble, filler ("for instance / it's worth noting"), a rule explained across three sentences that could be one imperative line.
   - **Conflict** — two rules that contradict each other, or an example that violates a rule stated elsewhere. **Never resolve silently** — surface it and ask which one wins.
   - **Stale references** — a path, file, skill or flag the skill points to that no longer exists (verify with a quick Grep/Glob before flagging).
   - **Overlap across skills** — the same rule living in two skills. Propose keeping it in the most specific one and referencing it from the other, not copy-pasting.

   Before flagging an example as "redundant", check `archive/` (via Grep): an example kept for a **recurring** mistake is deliberate emphasis — don't cut it.

3. **Propose the optimizations**

   Group findings by skill and by type, each as a **before → after** with a one-line reason and its line delta. Nothing is applied yet.
   - **Ask before any removal of a whole rule, section or example** — a "redundant" line may be intentional emphasis.
   - Conflicts are **questions**, not edits: present both rules and let the user pick the winner.

4. **Apply — form only, smallest edit**

   Apply only what the user confirmed, and keep behavior identical:
   - **Sharpen an existing line** rather than deleting and rewriting. Merge duplicates into the strongest single statement.
   - **Cut, don't add** — the goal is fewer tokens for the same rules. If an edit makes the skill longer, it's not an optimization.
   - **Preserve the skill's name and structure** — folders, `evals/`, `references/` stay in place.
   - Never touch a line an eval depends on in a way that changes what it asserts.

5. **Prove behavior held**

   Re-run every eval from step 1 — all must **stay green**. If any eval that was passing now fails, the optimization changed behavior: **revert that edit** and report it. A red eval after optimization is a failed optimization, not an accepted trade-off.

6. **Report**

**Output**

```
## Skills optimized

**Audited:** <n> skills
**Trimmed:** <total> lines removed across <k> skills · evals green before ✔ / after ✔

- **<skill-a>:** <before> → <after> lines — <cut: 2 dup examples, 1 padding block>
- **<skill-b>:** <before> → <after> lines — 1 stale reference removed
- **<skill-c>:** no change — already lean

**Surfaced (needs your call):**
- **<skill-b>:** conflict between rule X and rule Y — which wins?

Nothing that changed a rule was applied; behavior is eval-guaranteed unchanged.
```

**Output (a skill has no evals)**

```
## <skill> has no safety net

No evals in `<skill>/evals/` — I can't prove an optimization keeps behavior.
Applied only form-only cuts (padding, duplicate prose). Left every rule untouched.
Consider adding an eval so future optimizations can go further safely.
```

**Guardrails**

- **Evals are the contract** — green before, green after. A red eval after an edit means revert, not accept.
- **Form only, never behavior** — cut how a rule is written, never which rules exist. Removing a rule is a `finish`/`apply` decision, not an optimization.
- **Conflicts are surfaced, not resolved** — always ask which rule wins.
- **Check recurrence before cutting an example** — a repeated mistake's example is deliberate emphasis.
- **Ask before removing** any whole rule, section or example.
- **Preserve the skill's name and structure**; smallest edit that keeps the evals green.
- **A longer skill is a failed optimization** — if the edit didn't subtract, drop it.
