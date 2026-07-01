#!/usr/bin/env bash
#
# skilo-init.sh — scaffolds the `skilo/` folder at the repository root.
#
# Creates skilo's working structure and writes `config.yaml` with the
# code review agent chosen by the user. Idempotent: never overwrites an
# existing `config.yaml` (unless --force).
#
# Usage:
#   scripts/skilo-init.sh [--agent <name>] [--language <tag>] [--root <dir>] [--force]
#
# Options:
#   --agent    <name>   Code review agent name/path (default: codereview)
#   --language <tag>    Language skilo writes/talks in — IETF tag (default: en)
#   --root     <dir>    Repo root where `skilo/` is created (default: current dir)
#   --force             Overwrite an existing config.yaml
#
set -euo pipefail

agent="codereview"
language="en"
root="$(pwd)"
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent)    agent="${2:?--agent requires a value}";       shift 2 ;;
    --language) language="${2:?--language requires a value}"; shift 2 ;;
    --root)     root="${2:?--root requires a value}";         shift 2 ;;
    --force) force=1; shift ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; exit 2 ;;
  esac
done

skilo_dir="$root/skilo"
config="$skilo_dir/config.yaml"

# 1. Folder structure.
mkdir -p "$skilo_dir/cycles" "$skilo_dir/archive"

# `.gitkeep` keeps the ephemeral folders versioned even when empty.
touch "$skilo_dir/cycles/.gitkeep" "$skilo_dir/archive/.gitkeep"

# 2. config.yaml — not overwritten without --force.
if [[ -f "$config" && $force -eq 0 ]]; then
  echo "skilo: config.yaml already exists at '$config' — kept (use --force to overwrite)."
else
  cat > "$config" <<YAML
# skilo/config.yaml — lives at the repository root

# The user's code review agent.
# Skilo suggests improvements for it in \`propose\` and, if you confirm, applies them in \`apply\`.
code_review_agent: ${agent}

# Language skilo writes the propose in and talks to the user in.
# Use an IETF tag (e.g. en, pt-BR, es). Skill files/evals stay in their own language.
language: ${language}

# Where the working cycles live (relative to the repo root).
# The current cycle folder is <cycles>/<feature>/.
paths:
  cycles: skilo/cycles # one folder per feature: snapshot, propose and diffs of the active cycle
  archive: skilo/archive # lean summaries of past cycles
YAML
  echo "skilo: config.yaml written at '$config' (code_review_agent: ${agent}, language: ${language})."
fi

# 3. Summary.
echo "skilo: structure ready at '$skilo_dir/'"
echo "  ├── config.yaml"
echo "  ├── cycles/         (active cycle, one folder per feature — ephemeral)"
echo "  └── archive/        (lean summaries of past cycles)"
