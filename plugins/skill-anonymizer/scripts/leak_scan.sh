#!/usr/bin/env bash
# leak_scan.sh — comprehensive client-leak audit before publishing/pushing a repo public.
#
# Catches the evasions a naive `grep £[0-9] SKILL.md` misses (real S2026-06-17 incident):
#   1. WHOLE repo — README, docs/, references/, code templates — not just SKILL.md
#   2. currency in FORMAT STRINGS (£{...}, £%{...}, £' + x) that a `£[0-9]` regex skips
#   3. RAW INTEGERS equal to known client figures with the symbol stripped (e.g. 175000),
#      separator-tolerant so "250,000" and "250000" both match
#   4. git HISTORY across ALL commits + reachable refs (tags / stale branches)
#   5. GitHub releases — their source archives are built from the tagged commit
#
# A known-term grep is necessary-NOT-sufficient: it cannot catch open-vocabulary client
# NAMES you didn't think to list. Always pair this with the SEMANTIC scan in SKILL Step 1.
#
# Usage:
#   leak_scan.sh [repo_dir] [--gate] -t terms.txt [-n "250000 175000 90000"] [--remote owner/repo]
#     --gate   low-false-positive mode for an AUTOMATIC pre-push hook: checks ONLY the
#              enumerable signals (known terms + known figures), skips the noisy bare-currency
#              and history/refs sections. Quiet on pass. (Legit illustrative £ won't trip it.)
#     -t  file of known client identifiers (one regex/term per line: names, project IDs, emails)
#     -n  space-separated raw client figures to hunt as bare integers (symbol-stripped)
#     --remote  owner/repo to enumerate remote refs + GitHub releases (needs gh)
# Exits non-zero if any candidate leak is found.
set -uo pipefail
REPO="."; TERMS_FILE=""; NUMS=""; REMOTE=""; GATE=0
# first non-flag arg is the repo dir
[ $# -gt 0 ] && case "$1" in -*) ;; *) REPO="$1"; shift;; esac
while [ $# -gt 0 ]; do case "$1" in
  --gate) GATE=1; shift;;
  -t) TERMS_FILE="$2"; shift 2;;
  -n) NUMS="$2"; shift 2;;
  --remote) REMOTE="$2"; shift 2;;
  *) shift;;
esac; done
cd "$REPO" || { echo "no such dir: $REPO"; exit 2; }
FAIL=0
gx() { grep -v '/\.git/'; }   # drop .git internals

# Build a separator-tolerant alternation from the -n figures: "250000" also matches "250,000".
fig_pat() {
  local out="" n p
  for n in $NUMS; do
    p=$(printf '%s' "$n" | sed 's/[0-9]/&[,. ]?/g; s/\[,\. \]?$//')   # join digits with optional sep
    out="${out:+$out|}$p"
  done
  printf '%s' "$out"
}

scan_terms() {
  [ -n "$TERMS_FILE" ] && [ -f "$TERMS_FILE" ] || { [ "$GATE" -eq 1 ] || echo "  (no -t terms file)"; return; }
  if grep -rnIiEf "$TERMS_FILE" . 2>/dev/null | gx; then FAIL=1; echo "  ^ known client identifier in working tree"; fi
}
scan_figs() {
  [ -n "$NUMS" ] || { [ "$GATE" -eq 1 ] || echo "  (no -n figures)"; return; }
  local pat; pat=$(fig_pat)
  if grep -rnIE "(^|[^0-9])($pat)([^0-9]|\$)" . 2>/dev/null | gx; then
    FAIL=1; echo "  ^ a real client figure appears as a bare integer (e.g. in a JS mockup) — sanitize it too"
  fi
}

if [ "$GATE" -eq 1 ]; then
  # AUTOMATIC GATE: enumerable signals only (low false-positive). No bare-currency, no history.
  scan_terms; scan_figs
  if [ "$FAIL" -ne 0 ]; then
    echo "leak_scan --gate: BLOCKED — known client term/figure present. Sanitize before pushing to a public remote."
  fi
  exit $FAIL
fi

echo "== 1. non-ASCII currency symbols anywhere (catches £{...} / £%{...} format strings) =="
if grep -rnI -e '£' -e '€' -e '¥' . 2>/dev/null | gx; then
  FAIL=1; echo "  ^ currency symbols present — switch to \$/synthetic or confirm non-identifying (incl. code templates)"
fi
echo "== 2. known client terms (whole repo, case-insensitive) =="; scan_terms
echo "== 3. raw client figures as bare integers (currency symbol stripped, separator-tolerant) =="; scan_figs
echo "== 4. git HISTORY — known terms across ALL commits =="
if git rev-parse --git-dir >/dev/null 2>&1 && [ -n "$TERMS_FILE" ] && [ -f "$TERMS_FILE" ]; then
  hits=$(git grep -niEf "$TERMS_FILE" $(git rev-list --all 2>/dev/null) 2>/dev/null | wc -l | tr -d ' ')
  if [ "${hits:-0}" -gt 0 ]; then
    FAIL=1; echo "  ^ $hits hit(s) in git HISTORY — current-file edits are NOT enough."
    echo "    Remediate: orphan-rewrite (clean single root) OR git-filter-repo --replace-text, then force-push."
  else echo "  history clean for known terms"; fi
else echo "  (not a git repo, or no -t terms file — skipping history scan)"; fi
echo "== 5. reachable refs that retain old commits (branches + tags) =="
git ls-remote "${REMOTE:-origin}" 2>/dev/null | grep -E 'refs/(heads|tags)/' || echo "  (no remote / none reachable)"
echo "  ^ every stale merged branch + old tag keeps pre-scrub commits reachable — DELETE them after the rewrite"
if [ -n "$REMOTE" ] && command -v gh >/dev/null 2>&1; then
  echo "== 6. GitHub releases (source archives are generated from the tag's commit) =="
  gh release list --repo "$REMOTE" 2>/dev/null || echo "  (none / gh unavailable)"
  echo "  ^ a release whose tag points at a pre-scrub commit serves the leak as a .zip/.tar.gz — delete + recreate clean"
fi
echo
if [ "$FAIL" -eq 0 ]; then
  echo "RESULT: no candidate leaks found by grep."
  echo "  REMINDER: grep is necessary-not-sufficient. Still SEMANTIC-scan for client NAMES (SKILL Step 1),"
  echo "  and VERIFY on an INDEPENDENT fresh re-clone after the final push (never trust an editing agent's own grep)."
else
  echo "RESULT: CANDIDATE LEAKS FOUND — do NOT publish until clean. See sections above."
fi
exit $FAIL
