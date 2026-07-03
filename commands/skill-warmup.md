---
name: "retro-review:skill-warmup"
description: Reads the project, picks the skill pattern that fits its architecture, and through a conversation scaffolds one skill per layer — then offers to create and wire up a code-review agent
category: Workflow
tags: [workflow, retro-review, skills, setup, architecture]
---

The **phase zero** of retro-review. Instead of waiting for the model to make mistakes before a rule exists, `skill-warmup` reads the project, infers its architecture (Clean Architecture, DDD, hexagonal, layered, feature-first…), and — through a conversation about how **you** like to build — scaffolds **one skill per architectural layer**, seeded with best practices and your tastes. Then it offers to create a **code-review agent** tuned to those layers and wires it into `config.yaml`, so the `start → finish → apply` cycle has both skills to sharpen and a reviewer to improve.

Run it once, early — before the first `/retro-review:start`. It complements (and can stand in for) `/retro-review:bootstrap`: it does the same config setup at the end, plus the skills and the agent.

**Input**: none. Reads the repository. Optionally a hint about the architecture.

If `retro-review/config.yaml` exists, write every message to the user in its `language` (default `en`). Skill files, code and names stay as they are.

**Steps**

1. **Detect the project — don't assume**

   Scan the tree and the manifests to infer language(s), framework(s) and architecture. Read the folder structure and the build files that reveal it (`pubspec.yaml`, `package.json`, `pom.xml`, `go.mod`, `Cargo.toml`, `*.csproj`…) and the naming that signals a pattern:
   - `data/` · `domain/` · `presentation/` → Clean Architecture
   - `application/` · `infrastructure/` · `domain/` (entities, value objects, aggregates) → DDD
   - `ports/` · `adapters/` → hexagonal
   - `features/<x>/…` → feature-first
   - `controllers/` · `models/` · `views/` → MVC

   Report what you found (stack + inferred architecture + the layers you see) and **confirm it with the user** before proposing anything. If the signals are ambiguous, ask which architecture they follow (or want to move toward).

2. **Propose the skill pattern — one skill per layer**

   Map the confirmed layers to proposed skills — **one per layer, never a monolith** (a skill for `data`, one for `domain`, one for `presentation/ui`, …). Present the mapping and let the user add, drop or rename layers. For a monorepo, note that the pattern applies per repo/package if their stacks differ.

3. **Conversation — discover tastes, suggest improvements**

   This is a **chat, not a form**. For each layer, dig into the conventions that would become its rules — use the **AskUserQuestion tool** when the choice is discrete. Cover what matters for that layer, e.g.:
   - **data/infra:** errors as result types vs. raw exceptions, DTO ↔ entity mapping, where I/O is allowed, ret/timeout policy.
   - **domain:** immutability, where business rules live, entities vs. value objects, no framework leakage.
   - **presentation/ui:** state management, what a widget/component may and may not do, side-effect boundaries.
   - **cross-cutting:** naming, dependency direction (does the arrow point inward?), testing style, DI.

   Alongside the questions, **proactively suggest improvements** — where the current structure breaks the architecture's own rules (a dependency pointing the wrong way, business logic in the UI, I/O in the domain). Keep these as suggestions the user accepts or rejects; don't rewrite their code here.

4. **Scaffold the skills — lean seed, not a tutorial**

   For each confirmed layer, create the skill via `skill-creator`, following the pattern:

   ```
   <layer>/
   ├── SKILL.md
   ├── template.md
   ├── evals/          (evals.json, trigger_evals.json)
   └── references/
   ```

   Seed each `SKILL.md` with a **sharp, lean set of rules** drawn from the conversation — the layer's best practices plus the user's tastes, stated imperatively. Same discipline as the rest of retro-review: **subtract before you add** — no padding, at most one example per rule and only when ambiguous, no tutorial prose. Scope each skill's `description` to its layer so it triggers only there. Don't overwrite an existing skill without asking; extend it instead.

5. **Offer the code-review agent — and wire it up**

   Now that the skills exist, propose creating a **code-review agent** that reviews changes against these very layers and rules. **Ask** before creating it. If the user accepts:
   - Create the agent tuned to the detected architecture and the rules just captured — its checks mirror the layer skills (dependency direction, error handling, no leakage across layers…), lean and concrete.
   - **Wire it into retro-review.** Run the init so `config.yaml` points `code_review_agent` at the new agent:
     ```bash
     "${CLAUDE_PLUGIN_ROOT}"/scripts/retro-init.sh --agent "<new-agent>" --language "<language>"
     ```
     If the repo is already bootstrapped, update `code_review_agent` in the existing `config.yaml` (ask before overwriting). This is what lets `finish`/`apply` later suggest checks back to the agent.

   If the user declines the agent, still run the init to set up `config.yaml` (with their chosen or existing agent) so the cycle is ready.

6. **Report**

**Output**

```
## Skills warmed up

**Stack:** <language/framework>
**Architecture:** <Clean Arch | DDD | hexagonal | …> (confirmed)

**Skills created (one per layer):**
- **<data>** — <n> seed rules (result types, mapping, I/O boundary)
- **<domain>** — <n> seed rules (immutability, no framework leakage)
- **<presentation/ui>** — <n> seed rules (state mgmt, side-effect boundary)

**Suggestions you accepted:** <k> structural improvements noted.

**Code-review agent:** <created `<agent>` and wired into config.yaml> | <skipped>
**Config:** `retro-review/config.yaml` ready (code_review_agent: <agent>, language: <lang>).

Start the first cycle with `/retro-review:start`.
```

**Output (architecture unclear)**

```
## Which architecture do you follow?

I read the stack (<stack>) but the layout doesn't clearly signal a pattern.
Which do you follow — or want to move toward? (Clean Arch · DDD · hexagonal · layered · feature-first)
Once you pick, I'll map the layers to skills.
```

**Guardrails**

- **Detect, then confirm** — never scaffold on a guessed architecture; the user confirms the stack, the pattern and the layer mapping first.
- **One skill per layer, never a monolith** — mirrors retro-review's rule; a mistake in any layer already has a home.
- **Lean seed** — sharp imperative rules from the conversation, not a best-practices essay. Subtract before you add.
- **Suggest, don't rewrite** — structural improvements are proposals the user accepts; this command creates skills and (optionally) an agent, it doesn't refactor their code.
- **Don't overwrite** an existing skill or `config.yaml` without asking.
- **The agent is optional but the config isn't** — always leave `config.yaml` ready so `/retro-review:start` can run next.
- **Warmup seeds, the cycle sharpens** — these are starting rules; `finish`/`apply` refine them against real mistakes over time.
