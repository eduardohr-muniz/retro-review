<div align="center">

# 🧠 skilo

**Turn your code reviews into skill rules that stick.**

`init` → `explore` → `propose` → `apply`

*The model implements a spec. You fix it by hand. Skilo captures the gap — and makes sure the same mistake never ships twice.*

</div>

---

## The problem

You ask a model to implement a spec. It gets you 90% there. Then you review the diff and fix the last 10% by hand before pushing — a datasource that threw instead of returning a result, a widget missing a loading state, a DTO with the wrong nullability.

Those fixes are **gold**. They're the exact difference between what the model produces and what your codebase actually accepts. But they vanish into a git commit, and next week the model makes the *same* mistake again.

**Skilo closes that loop.** It captures the gap between what the model delivered and what you left correct, separates a real mistake from your own preference, and turns only the systematic mistakes into skill rules — each one validated by an eval that proves it would have caught the bug.

---

## How it works

Four commands, one cycle per feature:

```
/skilo-init      ── one-time setup: scaffold skilo/, pick your code review agent
      │
      ▼
/skilo-explore   ── freeze what the model delivered (before you touch it)
      │
      │   … you review and fix the code by hand …
      │
      ▼
/skilo-propose   ── diff your fixes, separate mistake from preference,
      │              write Given/When/Then proposals
      │
      │   … you refine the proposals together with skilo …
      │
      ▼
/skilo-apply     ── validate each rule with an eval (fail-before → pass-after),
                     archive a lean summary, wipe the cycle
```

### 1. `/skilo-init` — bootstrap

Run once per repo. Scaffolds the `skilo/` working folder and asks **which is your code review agent** — the agent skilo will later suggest checks for.

### 2. `/skilo-explore` — freeze the delivery

Snapshots the worktree exactly as the model handed it to you, using `git add -N` so even untracked files show up in the diff without committing. This is the zero mark. **Nothing is analyzed here** — you're just marking the "before".

### 3. `/skilo-propose` — capture the gap

After you've fixed the code by hand, skilo diffs your fixes against the frozen snapshot and, block by block, asks the crucial question:

> Is this a **fix for a model mistake**, or **your preference** (rename, move, style)?

Only real mistakes move on. Each one is classified — **missing rule**, **ignored rule**, or **non-systematic slip** — and checked against past cycles for recurrence. The output is a living `skilo-propose.md` draft in **Given/When/Then** format that you refine together.

### 4. `/skilo-apply` — make it stick

For each surviving proposal, skilo writes an **eval that must fail on the current skill** (proving it captures the bug), applies the rule, then proves the eval **passes**. No fail-before, no rule. Finally it archives a one-line summary for recurrence detection and wipes the cycle folder.

---

## File structure

Skilo's working cycle lives in a `skilo/` folder at the **root of your repository**, governed by a `config.yaml`:

```
<repo-root>/skilo/
├── config.yaml                 # your code review agent + paths
├── cycles/                     # active cycles, one folder per feature (ephemeral)
│   └── <feature>/              # current cycle — wiped on apply
│       ├── snapshot.md         # what the model delivered (explore)
│       ├── skilo-propose.md    # Given/When/Then proposals (propose)
│       └── .snapshot-*.diff    # cycle diffs
└── archive/                    # lean per-cycle summaries (recurrence detection)
    └── <feature>-<date>.md
```

The feature name is derived from your current git branch (`feature/login-flow` → `login-flow`); on `main` or a detached HEAD, skilo asks for it.

The evals skilo creates don't live here — **they go to the target skill**, because each skill carries the cases that test it (`<skill>/evals/evals.json` and `.../trigger_evals.json`).

### `config.yaml`

```yaml
# The user's code review agent — skilo suggests improvements for it.
code_review_agent: cortex-code-reviewer

# Language skilo writes the propose in and talks to you in (IETF tag: en, pt-BR, es…).
language: en

# Where the working cycles live (relative to the repo root).
# The current cycle folder is <cycles>/<feature>/.
paths:
  cycles: skilo/cycles     # one folder per feature for the active cycle
  archive: skilo/archive   # lean summaries of past cycles
```

`language` controls only skilo's **prose** — the proposals and its conversation with you. Your code, skill files, git branches and eval JSON stay in whatever language they're already in.

---

## Quick start

```bash
# 1. Bootstrap the repo (asks for your code review agent + language)
scripts/skilo-init.sh --agent cortex-code-reviewer --language pt-BR
# … or run the /skilo-init command, which asks interactively.

# 2. Model delivered a spec? Freeze it:
/skilo-explore

# 3. Fix the code by hand, then capture the gap:
/skilo-propose

# 4. Refine the proposals, then apply + validate:
/skilo-apply
```

### The `skilo-init.sh` script

```
scripts/skilo-init.sh [--agent <name>] [--language <tag>] [--root <dir>] [--force]

  --agent    <name>   Code review agent name/path (default: codereview)
  --language <tag>    Language skilo writes/talks in — IETF tag (default: en)
  --root     <dir>    Repo root where skilo/ is created (default: current dir)
  --force             Overwrite an existing config.yaml
```

Idempotent — it never overwrites an existing `config.yaml` unless you pass `--force`.

---

## Core principles

| Principle | Why |
|---|---|
| **One mistake → one verifiable rule** | If you can't write an eval that fails before and passes after, the rule is too vague. |
| **A preference never becomes a rule** | Renames, moves and style choices are yours — they don't belong in a skill. |
| **A non-systematic slip doesn't touch the skill** | The model knew and slipped once; don't inflate the skill with noise. |
| **Recurrence changes the action** | A repeated mistake calls for a better example or triggering fix — not the same rule again. |
| **An eval without "fail before" is invalid** | It has to prove it would have caught the bug. |
| **Every mistake is also a review failure** | Each proposal suggests a concrete check for your `code_review_agent` — applied only if you confirm. |
| **No skill for the layer? Suggest one per layer** | Don't force a rule into a generic skill or build a monolith — propose a skill per architectural layer (`data`, `infra`, `domain`, `presentation/ui`, …). |
| **The cycle folder is ephemeral** | One cycle at a time; `apply` archives a lean summary and wipes it. |

---

## Layout

```
skilo/
├── agents/skilo.md              # the skilo agent (full spec)
├── commands/skilo/
│   ├── init.md                  # /skilo-init
│   ├── explore.md               # /skilo-explore
│   ├── propose.md               # /skilo-propose
│   └── apply.md                 # /skilo-apply
├── scripts/skilo-init.sh        # scaffolding script
└── skilo/                       # per-repo working folder (created by init)
    ├── config.yaml
    ├── cycles/
    └── archive/
```

---

<div align="center">

*Every mistake the model makes is a rule your skills are missing — and a check your reviewer forgot. Skilo makes both permanent.*

</div>
