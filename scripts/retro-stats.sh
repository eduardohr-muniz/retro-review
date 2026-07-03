#!/usr/bin/env bash
#
# retro-stats.sh — "aproveitamento" (utilization) of the model's delivery.
#
# Compares the added lines of the START snapshot (what the model wrote) against
# the FINISH snapshot (what you kept after your review) and reports how much of
# the model's code survived untouched.
#
#   utilization % = kept / delivered
#     delivered = distinct added content lines in the start snapshot (the model's work)
#     kept      = those same lines still present in the finish snapshot
#
# Line-based and whitespace/order-insensitive: a reformat or a moved line doesn't
# count against the model — only real content changes do. It's a churn proxy, not
# a semantic judge; report it as such.
#
# Usage:
#   retro-stats.sh --start <start.diff> --finish <finish.diff> [--by-repo]
#
# Options:
#   --start   <file>   The `start` aggregated diff (baseline the model delivered). Required.
#   --finish  <file>   The `finish` aggregated diff (after your fixes). Required.
#   --by-repo          Also break the number down per `diff --retro-repo <repo>` section.
#
# Output (stdout): a summary line, plus one line per repo with --by-repo:
#   delivered=<n> kept=<n> changed=<n> utilization_pct=<0-100>
#
set -euo pipefail

start=""
finish=""
by_repo=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --start)   start="${2:?--start requires a value}";   shift 2 ;;
    --finish)  finish="${2:?--finish requires a value}"; shift 2 ;;
    --by-repo) by_repo=1; shift ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "error: unknown option '$1'" >&2; exit 2 ;;
  esac
done

[[ -f "$start"  ]] || { echo "error: --start file not found: '$start'"   >&2; exit 2; }
[[ -f "$finish" ]] || { echo "error: --finish file not found: '$finish'" >&2; exit 2; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Added content lines from a diff: strip the leading '+', drop '+++' headers,
# trim trailing whitespace, drop blank lines. (A section filter can be piped in.)
added_lines() {
  grep '^+' "$1" 2>/dev/null \
    | grep -v '^+++' \
    | sed 's/^+//; s/[[:space:]]*$//' \
    | grep -v '^[[:space:]]*$' || true
}

# Compute delivered/kept/changed/pct for a start-file and finish-file pair.
compute() {
  local s="$1" f="$2"
  added_lines "$s" | sort > "$tmp/model"
  added_lines "$f" | sort > "$tmp/you"

  local delivered kept changed pct
  delivered="$(grep -c . "$tmp/model" || true)"
  kept="$(comm -12 "$tmp/model" "$tmp/you" | grep -c . || true)"
  changed=$(( delivered - kept ))

  if [[ "$delivered" -eq 0 ]]; then
    pct="n/a"
  else
    pct=$(( kept * 100 / delivered ))
  fi
  printf 'delivered=%s kept=%s changed=%s utilization_pct=%s\n' "$delivered" "$kept" "$changed" "$pct"
}

# Extract one repo's section (between its marker and the next) from an aggregated diff.
section() {
  awk -v repo="$1" '
    /^diff --retro-repo / { on = ($3 == repo); next }
    on { print }
  ' "$2"
}

if [[ "$by_repo" -eq 1 ]]; then
  # Every repo that appears in either snapshot.
  repos="$(grep -h '^diff --retro-repo ' "$start" "$finish" 2>/dev/null | awk '{print $3}' | sort -u)"
  for r in $repos; do
    section "$r" "$start"  > "$tmp/s"
    section "$r" "$finish" > "$tmp/f"
    printf '%s\t%s\n' "$r" "$(compute "$tmp/s" "$tmp/f")"
  done
fi

# Aggregate (whole cycle).
printf 'TOTAL\t%s\n' "$(compute "$start" "$finish")"
