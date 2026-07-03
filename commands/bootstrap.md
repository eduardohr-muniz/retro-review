---
name: "/retro-review:bootstrap"
description: Bootstraps retro-review — creates the `retro-review/` folder at the root and asks which is your code review agent
category: Workflow
tags: [workflow, retro-review, skills, setup]
---

Prepares the repository for the `start → finish → apply` cycle. Creates the `retro-review/` working structure at the **repository root** and writes `config.yaml` with the user's **code review agent**. Run it once per repo, before the first `/retro-review:start`.

**Input**: none. Asks for the code review agent interactively.

**Steps**

1. **Check if it already exists**

   If `retro-review/config.yaml` already exists at the root, the repo is already bootstrapped. Warn and **ask** whether to reconfigure (overwrite `config.yaml`) or keep the current one. Only overwrite with explicit confirmation.

2. **Ask for the code review agent**

   Use the **AskUserQuestion tool**:

   > Which is your code review agent? Retro Review will suggest improvements for it in `finish` and, if you confirm, apply them in `apply`.

   Accept a name or path (e.g. `codereview`, `code-reviewer`, `frontend/codereview`). This value becomes `code_review_agent` in `config.yaml`.

3. **Ask for the language**

   Use the **AskUserQuestion tool**:

   > Which language should retro-review write the proposals in and talk to you in?

   Accept an IETF tag (e.g. `en`, `pt-BR`, `es`). This becomes `language` in `config.yaml`. Default to `en` if the user doesn't care.

4. **Scaffold**

   Run the script, passing the chosen agent and language:

   ```bash
   "${CLAUDE_PLUGIN_ROOT}"/scripts/retro-init.sh --agent "<chosen-agent>" --language "<chosen-language>"
   ```

   The script creates (idempotent, won't overwrite an existing config without `--force`):

   ```
   retro-review/
   ├── config.yaml         # code_review_agent + language + paths
   ├── cycles/             # active cycle, one folder per feature (ephemeral)
   └── archive/            # summaries of past cycles
   ```

   To reconfigure an already-bootstrapped repo (step 1 confirmed), add `--force`.

5. **Confirm**

   Report the path of the created structure, the `code_review_agent` and the `language` written. Mention that snapshots **auto-discover every nested git repo** under the root — no per-repo config needed for monorepos.

**Output**

```
## Retro Review bootstrapped

**Root:** <repo-root>/retro-review/
**Code review agent:** <agent>
**Language:** <language>

Structure ready:
  ├── config.yaml
  ├── cycles/         (active cycle, one folder per feature — ephemeral)
  └── archive/        (summaries of past cycles)

Snapshots auto-discover every nested git repo under the root.
Start the first cycle with `/retro-review:start`.
```

**Output (already bootstrapped)**

```
## Retro Review already bootstrapped

`retro-review/config.yaml` already exists (code_review_agent: <current>).
Reconfigure (overwrite) or keep the current one?
```

**Guardrails**

- **Doesn't overwrite** an existing `config.yaml` without explicit confirmation (`--force`).
- Runs once per repository — it's setup, not part of the cycle.
- The code review agent is required: without it, `finish`/`apply` don't know whom to suggest improvements to.
- Doesn't commit anything — only creates files.
