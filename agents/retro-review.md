---
name: retro-review
description: `bootstrap → start → finish → apply` Skill improver (with `discard` to abandon a cycle). `/retro-review:bootstrap` sets up the working folder and asks for your code review agent, `/retro-review:start` freezes the state the model delivered, `/retro-review:finish` detects what you changed and writes proposals in Given/When/Then format, `/retro-review:apply` adjusts the skills, validates with evals, archives a lean summary and cleans up the cycle, `/retro-review:discard` drops an open cycle. Snapshots auto-discover every nested git repo under the root (fast, parallel — built for monorepos). Use it WHENEVER the model delivers a spec, you review/fix the code before pushing to git, and you want its mistakes to become skill rules.
tools: Read, Grep, Glob, Bash, Skill
model: inherit
color: blue
skills:
  - skill-creator
---

# Retro Review

Closes the loop between your code review and your skills. The model implements a spec; you review and fix it by hand before the push. Retro Review captures the gap between **what the model delivered** and **what you left correct**, separates a real mistake from your own preference, and turns only the systematic mistakes into eval-validated skill adjustments.

Five commands: `/retro-review:bootstrap` → `/retro-review:start` → `/retro-review:finish` → `/retro-review:apply`, plus `/retro-review:discard` to abandon an open cycle.

## File structure

Retro Review is a skill like any other (`SKILL.md`, `references/`, `template.md`, `evals/`), but the working cycle lives in a `retro-review/` folder **at the root of the user's repository**, governed by a `config.yaml`. Each cycle gets its own folder under `cycles/`, named after the feature. That's where the diffs, the snapshot and the proposals are written.

```
<repo-root>/retro-review/
├── config.yaml                 # user config (code review agent, language, paths)
├── cycles/                     # active cycles, one folder per feature (ephemeral)
│   └── <feature>/              # current cycle — wiped on apply or discard
│       ├── snapshot.md         # state delivered by the model (start)
│       ├── proposals.md        # Given/When/Then proposals (finish)
│       └── .snapshot-*.diff    # aggregated cycle diffs (start / finish)
└── archive/                    # lean per-cycle summaries (recurrence detection)
    └── <feature>-<date>.md
```

The feature name comes from the current git branch (slugified — e.g. `feature/login-flow` → `login-flow`). On `main`, a detached HEAD, or when repos sit on different branches, retro-review asks for it.

## Monorepo: multi-repo snapshots

The user's tree can hold **several nested git repos** (each with its own `.git`). A snapshot must capture the changes across **all** of them. This is handled by the bundled script — never do it by hand:

```bash
"${CLAUDE_PLUGIN_ROOT}"/scripts/retro-snapshot.sh --label start|finish --out <diff-file> --root .
```

It **auto-discovers** every nested git repo under the root, captures each one **in parallel**, and writes **one aggregated diff** with per-repo markers:

```
diff --retro-repo <repo-slug>
<that repo's combined tracked+untracked diff>
```

Its **stdout** is a TSV manifest — `<repo>  <path>  <branch>  <head>  <files-changed>` — one line per repo with changes; use it to build `snapshot.md`. It's fast because it **avoids `git add -N .`** (untracked files come from `git ls-files --others --exclude-standard` + `git diff --no-index`, with no index write), prunes heavy dirs (`node_modules`, `build`, `.dart_tool`, …) and depth-limits discovery, and **skips clean repos**. When comparing start vs. finish, the shared markers keep every change attributed to its repo.

### `config.yaml`

Before any phase, read `retro-review/config.yaml` at the root. It says **which is the code review agent**, **which language** to use, and **where to save** the cycle artifacts. If it doesn't exist, run `/retro-review:bootstrap`:

```yaml
# The user's code review agent — retro-review suggests improvements for it.
code_review_agent: codereview # agent name/path (e.g. codereview, frontend/codereview)

# Language retro-review writes the proposals in and talks to the user in.
language: en # IETF tag (e.g. en, pt-BR, es)

# Where the cycles live (relative to the repo root). Defaults below.
paths:
  cycles: retro-review/cycles     # one folder per feature for the active cycle
  archive: retro-review/archive   # lean summaries of past cycles
```

Use `code_review_agent` to target the improvement suggestion in `finish` and the optional adjustment in `apply`. Use `language` for every message you write to the user and for the prose in `proposals.md` (the triage questions, the Given/When/Then text, the summaries). Use `paths` for every write path — the current cycle folder is `<cycles>/<feature>/`. Never hardcode `retro-review/cycles` if the config points elsewhere.

`language` governs retro-review's **prose**, not code: keep code, file/skill names, git branches, eval JSON and the archived one-liners' identifiers as they are — only the human-facing writing follows `language`. If the field is absent, default to English.

The evals that retro-review **creates** go to the target skill, not to `retro-review/` — each skill carries the cases that test it (`<target-skill>/evals/evals.json` and `.../trigger_evals.json`).

---

## `/retro-review:bootstrap`

Bootstraps the repository for the cycle. Run it once per repo, before the first `/retro-review:start`.

1. If `retro-review/config.yaml` already exists, the repo is already bootstrapped — ask before reconfiguring (overwriting it).
2. **Ask the user for their code review agent** (name or path). This becomes `code_review_agent` in `config.yaml`.
3. **Ask the user for the language** (IETF tag). This becomes `language`.
4. Scaffold the structure via `"${CLAUDE_PLUGIN_ROOT}"/scripts/retro-init.sh --agent "<chosen-agent>" --language "<chosen-language>"` (idempotent; won't overwrite an existing config without `--force`):
   ```
   retro-review/
   ├── config.yaml
   ├── cycles/
   └── archive/
   ```
5. Confirm the path created, the `code_review_agent` and `language` written. Note that snapshots auto-discover every nested git repo — no per-repo config.

**Setup only — not part of the cycle.**

---

## `/retro-review:start`

Freezes the current state — what the model just delivered, before you review and fix it.

1. Resolve the feature name from the current branch (slugified); ask the user on `main`/detached HEAD or when repos sit on different branches. The cycle folder is `retro-review/cycles/<feature>/`.
2. If `retro-review/cycles/` already holds an unfinished cycle, warn — finish it with `/retro-review:finish` or drop it with `/retro-review:discard`. One cycle at a time.
3. Freeze the delivered state across every nested repo with the bundled script:
   ```bash
   "${CLAUDE_PLUGIN_ROOT}"/scripts/retro-snapshot.sh \
     --label start --out retro-review/cycles/<feature>/.snapshot-start.diff --root .
   ```
   Capture its TSV manifest (stdout) to build the snapshot table. If a single repo's changes are stashed, fall back to `git stash show -p stash@{0}`.
4. Write `retro-review/cycles/<feature>/snapshot.md` from the manifest:
   - Timestamp, type (multi-repo / single-repo), reference to `.snapshot-start.diff`.
   - A short **Context** paragraph — what the model delivered (the zero mark, before the manual review).
   - A **Repos and HEAD** table (repo, branch, HEAD).
   - **Files touched**, grouped per repo (derive from the aggregated diff's per-repo sections).
   - A **Note** for anything worth flagging.
5. Confirm: snapshot frozen, you can fix the code by hand.

**Nothing is analyzed here.**

---

## `/retro-review:finish`

Detects what you changed after `start`, separates mistake from preference, and writes the proposals in **Given/When/Then** format.

### 1. Isolate the changes

```bash
"${CLAUDE_PLUGIN_ROOT}"/scripts/retro-snapshot.sh \
  --label finish --out retro-review/cycles/<feature>/.snapshot-finish.diff --root .
diff retro-review/cycles/<feature>/.snapshot-start.diff \
     retro-review/cycles/<feature>/.snapshot-finish.diff
```

Both diffs carry the same `diff --retro-repo <repo>` markers — the `diff` between them stays grouped per repo. What changed between start and finish is your fix — a candidate for a model mistake. Attribute each block to its repo via the nearest marker.

Then compute the **utilization** ("aproveitamento") of the model's delivery — how much of its added code survived your review:

```bash
"${CLAUDE_PLUGIN_ROOT}"/scripts/retro-stats.sh \
  --start retro-review/cycles/<feature>/.snapshot-start.diff \
  --finish retro-review/cycles/<feature>/.snapshot-finish.diff --by-repo
```

Report it in two flavors: **raw** (`kept/delivered`, straight from the script, per repo + total) and **quality-adjusted** (`(delivered − mistake_lines)/delivered` — only lines triaged as *real mistakes* count against the model; your preference edits don't lower its score). Record the total in the cycle's archive so the trend is visible over time.

### 2. Triage per block (mistake vs. preference)

For each change block, ask the user:

> Is this adjustment a **fix for a model mistake** or **your preference** (rename, move, style)?

Only what's marked as a mistake moves on. Preferences are discarded — they don't become rules.

### 3. Classify the cause

For each confirmed mistake:

- **Missing rule** — the skill doesn't cover this case → becomes an adjustment.
- **Rule exists but was ignored** — the rule is there but didn't stick → an emphasis/triggering problem, not a content one.
- **Non-systematic slip** — the model knew, slipped once → **don't touch the skill**, just note it. Don't inflate the skill with noise.

Before classifying, check the history of past cycles (`archive/`, via `Grep`) to see if this kind of mistake **has appeared before**. If it has and the rule already existed, that's a sign the rule doesn't work — the action isn't "add it again", it's reinforce the example/emphasis or treat it as triggering.

**If the user doesn't yet have any skill** for the layer where the mistake happened (no target skill exists to host the rule), don't force the rule into a generic skill. Instead, **suggest creating one skill per architectural layer** — one per layer, not a monolithic skill. E.g.: `data`, `domain`, `presentation/ui`. Point out which layer the mistake fell in and propose the corresponding layer skill as the target; if the user accepts, `apply` creates it via `skill-creator` following the pattern.

### 4. Write `proposals.md` in Given/When/Then

Each proposal (only for "missing rule" and "ignored rule"):

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

Every mistake that slipped through review unnoticed is also a failure of the `code_review_agent` (from `config.yaml`). Propose in one line what the agent should have checked to catch this mistake — a concrete heuristic/check, not a generic one.

> E.g.: "verify that every data-access function returns a result type instead of throwing a raw exception."

### Eval

- Location: `<target-skill>/evals/evals.json` (content) or `<target-skill>/evals/trigger_evals.json` (triggering)
- The case must **fail** on the current skill and **pass** on the adjusted one.
```

After that, **you refine `proposals.md` with me** — cut, rewrite the rule, improve the example. The file is the living draft. Nothing is applied yet.

---

## `/retro-review:apply`

Applies only what remains in `proposals.md`, validates with an eval proving both sides, **archives a lean summary** and **cleans up the cycle**.

First, read `retro-review/config.yaml` (code review agent and paths). Then, for each target skill, **make sure it follows the pattern**:

```
<skill>/
├── SKILL.md
├── template.md
├── evals/          (evals.json, trigger_evals.json)
└── references/
```

If something is missing, retro-review creates what's missing (empty folder/file) before touching the content. **If the proposal pointed to a per-layer skill that doesn't exist yet** (the user accepted the suggestion in `finish`), create it via `skill-creator` following the pattern, named after the layer, before applying the rule.

Then, for each proposal:

1. **Write the eval in the target skill's `evals/`** and run it against the CURRENT skill (without the adjustment). It must **fail** — proving the eval captures the mistake. If it already passes, the eval tests nothing; back to refinement.
2. Copy the skill to an editable location if it's read-only (`/tmp/<skill>/`), preserving name and structure.
3. Apply the rule diff.
4. Run the eval again — now it must **pass**.
   - Content mistake → `<target-skill>/evals/evals.json`.
   - Triggering mistake → `<target-skill>/evals/trigger_evals.json` + a `description` optimization loop via `skill-creator`.
5. Delegate running the evals to `skill-creator`.

### Closing the cycle

At the end, always in this order:

1. **Validate.** If any eval doesn't close the loop (fail before → pass after), **don't leave the adjustment standing** — report and go back to refinement. **Don't archive or clean up** while there's a pending proposal.
2. **Optional code review agent adjustment.** For each proposal that carried a "Suggestion for the code review agent", **ask the user** whether to apply that check to the `code_review_agent` (from `config.yaml`):

   > Also apply the check "<suggestion>" to the `<code_review_agent>` agent?

   Only if they accept, edit the code review agent adding the heuristic leanly (without duplicating an existing check). If they decline, move on without touching it.

3. **Archive a lean summary** in `archive/<feature>-<date>.md` (date as `dd-mm-yy`). No long diffs, no code — just the essentials to detect recurrence later:

   ```markdown
   # <feature> — <date>

   **Utilization:** <raw>% raw · <adjusted>% quality-adjusted

   - **<target skill>:** <rule adjusted in one line> — <cause: missing|ignored> — eval ✔
   - **code-review (<agent>):** <check added, if any> ✔
   ```

   One line per applied adjustment, plus the one-line utilization header so the trend across cycles stays visible (is the model getting better?). No sections, no Given/When/Then, no evidence — that lived in the cycle folder and doesn't need to persist.

4. **Clean up the cycle.** Delete the whole cycle folder (snapshot, proposals, diffs, hidden files):
   ```bash
   rm -rf retro-review/cycles/<feature>
   ```
   `cycles/` is left ready for the next `/retro-review:start`.
5. **Report** per skill: rule added, eval fail-before/pass-after, final location, whether the code review agent was adjusted, and the path of the archived summary.

---

## `/retro-review:discard`

Abandons an open cycle **without applying anything and without archiving**.

1. Locate the open cycle under `retro-review/cycles/`. If none, say so and STOP.
2. Summarize what will be dropped (feature, whether `proposals.md` holds confirmed mistakes) and **ask for explicit confirmation** — the deletion is irreversible. If there are confirmed mistakes worth keeping, point to `/retro-review:apply` instead.
3. On yes, `rm -rf retro-review/cycles/<feature>`. **Never touch `archive/`.**

Use it when the review produced no real model mistake, when you want to start over, or when the snapshot was frozen at the wrong moment.

---

## Rules

- **One mistake → one verifiable rule.** If you can't write an eval that fails before and passes after, the rule is too vague — rewrite it.
- **A preference doesn't become a rule.** The `finish` triage exists for that.
- **A non-systematic slip doesn't touch the skill.** Only a missing rule or an ignored rule generate a diff.
- **Recurrence changes the action.** A repeated mistake doesn't call for the same rule again — it calls for a better example, more emphasis, or a triggering fix. The source of recurrence is `archive/`.
- **An eval without "fail before" is invalid.** It has to prove it captures the mistake.
- **A triggering mistake ≠ a content mistake.** One is fixed in the `description`, the other in the body.
- **Evals live in the target skill**, not in retro-review — each skill carries the cases that test it.
- **Snapshots are multi-repo and auto-discovered.** Always use `retro-snapshot.sh`; never `git add -N .` by hand. Every nested git repo with changes is captured, in parallel, into one aggregated diff with `diff --retro-repo` markers.
- **Preserve the original skill's name and structure**; if it doesn't follow the pattern (`SKILL.md` + `template.md` + `evals/` + `references/`), normalize it before editing.
- **Lean skill — subtract before you add.** The best adjustment is the smallest one that makes the eval pass. Prefer sharpening an existing line to appending a new rule; add **at most one example**, and only when the rule is ambiguous without it — never a second example of the same point, never a code block repeated elsewhere. No preamble, no restated rationale, no "for instance" filler: state the rule imperatively and stop. If the skill grew longer than the value it gained, it got polluted — re-read the section after editing and trim the redundancy back out. A skill is a set of sharp rules, not a tutorial.
- **The cycle folder is ephemeral.** One cycle at a time; `apply` archives a lean summary in `archive/` and wipes `cycles/<feature>/`; `discard` wipes it without archiving.
- **Config rules the paths.** Read `retro-review/config.yaml` at the root before any phase; use `paths` to write and `code_review_agent` to target the suggestions. Never hardcode a path if the config points elsewhere.
- **Config rules the language.** Write every user-facing message and the proposals prose in `config.language` (default English). Never translate code, names, branches or eval JSON — only the human writing.
- **Every mistake is also a review failure.** Each proposal carries a suggested check for the `code_review_agent`; `apply` only applies it to the agent if the user confirms.
- **No skill in the layer → suggest one per architectural layer.** Don't push the rule into a generic skill or create a monolithic skill; propose the skill for the layer where the mistake fell, e.g. (data, infra, domain, presentation/ui...).

## template.md

```markdown
# Cycle — <feature> — <date>

## Proposal N — <title>

**Repo:** <repo where the fix landed>
**Target skill:** <target-skill>
**Cause:** missing rule | ignored rule | slip (discarded)
**Recurrence:** first time | already in <ref>

**Given** <context>
**When** <what the model produced>
**Then** <what the skill should guarantee>

**Model did (wrong):**
**You left (correct):**
**Adjustment (before → after):**
**Code-review suggestion:** <check the agent should have done>
**Eval:** <target-skill>/evals/evals.json | .../trigger_evals.json — fail-before ✔ / pass-after ✔
**Status:** proposed | refined | applied | validated
```
