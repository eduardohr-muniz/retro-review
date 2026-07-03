#!/usr/bin/env bash
#
# retro-snapshot.sh — fast, multi-repo aggregated worktree snapshot for monorepos.
#
# Auto-discovers nested git repos under --root and writes ONE aggregated unified
# diff to --out, with each repo's section delimited by a marker line:
#
#     diff --retro-repo <repo-slug>
#     <that repo's combined tracked+untracked diff>
#
# On stdout it prints a TAB-separated manifest, one line per repo with changes:
#     <repo-slug>\t<repo-path>\t<branch>\t<short-head>\t<files-changed>
# start-review uses it to build snapshot.md's "Repos e HEAD" table.
#
# Why it's fast:
#   - No `git add -N .` (which stats the whole worktree and dirties the index).
#     Untracked files are found with `git ls-files --others --exclude-standard`
#     (index-cached, gitignore-aware); content is captured with `git diff --no-index`.
#   - Discovery prunes heavy dirs (node_modules, build, .dart_tool, ...) and is
#     depth-limited, so it never walks vendored trees.
#   - Repos are captured in parallel — wall time is the slowest repo, not the sum.
#   - A clean repo (empty `git status --porcelain`) is skipped entirely.
#
# Usage:
#   retro-snapshot.sh --label start|finish --out <file> [--root <dir>]
#                     [--exclude <path>] [--prune <name>]... [--maxdepth <n>] [--jobs <n>]
#
# Options:
#   --label    <name>   Snapshot label: `start` (baseline) or `finish` (after fixes). Required.
#   --out      <file>   Aggregated diff file to write. Required.
#   --root     <dir>    Where to auto-discover repos (default: current dir).
#   --exclude  <path>   Path (relative to each repo) to keep out of the diff
#                       (default: retro-review — the working folder itself).
#   --prune    <name>   Extra directory name to skip during discovery (repeatable).
#   --maxdepth <n>      How deep to look for nested repos (default: 4).
#   --jobs     <n>      Max repos captured in parallel (default: 8).
#
set -euo pipefail
shopt -s nullglob

label=""
out=""
root="$(pwd)"
exclude="retro-review"
maxdepth=4
jobs=8
prune_names=(node_modules .dart_tool build dist .next .nuxt .venv venv vendor target .gradle Pods .terraform .cache coverage .turbo)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)    label="${2:?--label requires a value}";     shift 2 ;;
    --out)      out="${2:?--out requires a value}";          shift 2 ;;
    --root)     root="${2:?--root requires a value}";        shift 2 ;;
    --exclude)  exclude="${2:?--exclude requires a value}";  shift 2 ;;
    --prune)    prune_names+=("${2:?--prune requires a value}"); shift 2 ;;
    --maxdepth) maxdepth="${2:?--maxdepth requires a value}"; shift 2 ;;
    --jobs)     jobs="${2:?--jobs requires a value}";        shift 2 ;;
    -h|--help)  grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; exit 2 ;;
  esac
done

[[ -n "$label" ]] || { echo "error: --label required (start|finish)" >&2; exit 2; }
[[ -n "$out"   ]] || { echo "error: --out required"   >&2; exit 2; }

root="$(cd "$root" && pwd)"
mkdir -p "$(dirname "$out")"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Build the find -prune expression from the heavy-dir names.
prune_expr=()
for n in "${prune_names[@]}"; do
  prune_expr+=( -name "$n" -o )
done
unset 'prune_expr[${#prune_expr[@]}-1]'   # drop trailing -o

# Discover repos: any dir holding a `.git` (dir OR file → submodule/worktree safe),
# pruning heavy dirs and capping depth so we never descend vendored trees.
repos=()
while IFS= read -r line; do
  [[ -n "$line" ]] && repos+=("$line")
done < <(
  find "$root" -maxdepth "$maxdepth" \( "${prune_expr[@]}" \) -prune -o -name .git -print 2>/dev/null \
    | sed 's:/\.git$::' | sort -u
)

# repo path -> stable filename slug (root repo becomes "root").
slug() {
  local rel="${1#"$root"}"
  rel="${rel#/}"
  [[ -z "$rel" ]] && { printf 'root'; return; }
  printf '%s' "$rel" | sed 's:[/ ]:-:g'
}

capture() {
  local repo="$1" slugged
  slugged="$(slug "$repo")"

  # Fast skip: nothing changed in this repo.
  [[ -z "$(git -C "$repo" status --porcelain 2>/dev/null)" ]] && return 0

  {
    # Tracked changes, excluding the working folder itself.
    git -C "$repo" diff HEAD -- . ":(exclude)${exclude}" ":(exclude)${exclude}/**"
    # Untracked files (gitignore-aware, index-cached) — content included, no index write.
    git -C "$repo" ls-files --others --exclude-standard -z \
      | while IFS= read -r -d '' u; do
          [[ "$u" == "$exclude" || "$u" == "$exclude/"* ]] && continue
          git -C "$repo" diff --no-index --binary -- /dev/null "$repo/$u" 2>/dev/null || true
        done
  } > "$tmp/$slugged.diff"

  local branch head n
  branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  head="$(git -C "$repo" rev-parse --short HEAD 2>/dev/null || echo '?')"
  n="$(git -C "$repo" diff HEAD --name-only -- . ":(exclude)${exclude}" 2>/dev/null | grep -c . || true)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$slugged" "$repo" "$branch" "$head" "$n" > "$tmp/$slugged.meta"
}

# Bounded parallel fan-out across repos.
i=0
for r in "${repos[@]}"; do
  [[ -e "$r/.git" ]] || continue
  capture "$r" &
  (( ++i % jobs == 0 )) && wait
done
wait

# Assemble the aggregated diff in a stable (alphabetical) repo order.
: > "$out"
for meta in "$tmp"/*.meta; do
  slugged="$(cut -f1 "$meta")"
  {
    echo "diff --retro-repo ${slugged}"
    cat "$tmp/${slugged}.diff"
    echo
  } >> "$out"
done

# Manifest to stdout (sorted), for the caller to build snapshot.md.
cat "$tmp"/*.meta 2>/dev/null | sort || true

echo "retro-snapshot: label='${label}' repos-with-changes=$(printf '%s\n' "$tmp"/*.meta | grep -c . || true) out='${out}'" >&2
