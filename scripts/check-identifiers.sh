#!/usr/bin/env bash
# Fails if employer/client identifiers appear in files that would be committed.
# Patterns are built from concatenated fragments so this file never contains a
# raw identifier itself (it must survive identifier-scrubbing rewrites).
set -u
cd "$(git rev-parse --show-toplevel)" || exit 1

patterns=(
  'and\.global'
  'looms''\.cloud'
  'aeon''finance'
  'and''solutions\.net'
  'andsystems\.tech'
  'zerotech\.mn'
  'alpha-''ptf'
  '\balpha-[a-z0-9-]+'
  'af''s-'
  'AF''S-'
  'relation''Store'
  'e2e-''performance-tests'
  'state-''machine'
  'flow-''generator'
  'global''Sim'
  '\bgSim'
  '\bgsim'
  'Code/''and/'
  'Code/''gSim'
  '192\.168\.1''\.233'
  # repo named "middleware": anchored to path/table contexts only — the bare
  # word is generic English (Express/Redux docs) and must not fail the check.
  'formio/middle''ware|back-end/middle''ware|\| `middle''ware`'
)

# tracked + staged + untracked-not-ignored; anything living under a secret* path
# is the sanctioned container for these identifiers and is skipped. This script
# is excluded too — it necessarily contains the patterns it checks for.
files=$(git ls-files -cmo --exclude-standard | grep -Ev '(^|/)secret|check-identifiers\.sh$' || true)
[ -z "$files" ] && exit 0

combined=$(IFS='|'; echo "${patterns[*]}")
hits=$(grep -inE "$combined" $files 2>/dev/null || true)
if [ -n "$hits" ]; then
  echo "ERROR: employer/client identifiers found — move to a secret* file or an env var:" >&2
  echo "$hits" >&2
  exit 1
fi
exit 0
