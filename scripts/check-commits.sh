#!/usr/bin/env bash
# Reads commit subjects (one per line) on stdin; fails if any isn't a
# Conventional Commits header. Usage:
#   git log --no-merges --format=%s BASE..HEAD | scripts/check-commits.sh
#
# Only the header is checked — `!` in the header marks a breaking change;
# a `BREAKING CHANGE:` footer lives in the body and needs no validation here.
# Git's default `Revert "..."` subject is allowed as-is.
set -uo pipefail

pattern='^((feat|fix|perf|refactor|docs|style|test|build|ci|chore|revert)(\([^()]+\))?!?: .+|Revert ".+")$'
bad=0

while IFS= read -r subject || [ -n "$subject" ]; do
  [ -z "$subject" ] && continue
  if [[ "$subject" =~ $pattern ]]; then
    echo "ok:   $subject"
  else
    echo "FAIL: $subject"
    bad=1
  fi
done

if [ "$bad" -ne 0 ]; then
  echo
  echo "Commits must follow Conventional Commits: <type>[(scope)][!]: <description>"
  echo "Types: feat fix perf refactor docs style test build ci chore revert"
fi
exit "$bad"
