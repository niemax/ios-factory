#!/usr/bin/env bash
# Self-check for check-commits.sh. Run: scripts/test-check-commits.sh
set -u
cd "$(dirname "$0")"
fails=0

expect() { # expect <exit code> <subject>
  printf '%s\n' "$2" | ./check-commits.sh >/dev/null
  local got=$?
  if [ "$got" -ne "$1" ]; then echo "expected $1, got $got: $2"; fails=1; fi
}

expect 0 "feat: add thing"
expect 0 "fix(ui): button tap"
expect 0 "feat!: drop iOS 16"
expect 0 "refactor(api)!: rename endpoint"
expect 0 'Revert "feat: add thing"'
expect 1 "add thing"
expect 1 "feat add thing"
expect 1 "feat:"
expect 1 "Feat: add thing"
expect 1 "feature: add thing"
expect 1 "fix(): empty scope"

# One bad commit among good ones fails the batch.
printf 'feat: a\nwip\nfix: b\n' | ./check-commits.sh >/dev/null && { echo "batch with bad commit passed"; fails=1; }

[ "$fails" -eq 0 ] && echo "all passed"
exit "$fails"
