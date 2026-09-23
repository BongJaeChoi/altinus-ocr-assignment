#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
  printf 'ERROR: expected a commit message file.\n' >&2
  exit 64
fi

message_file="$1"
subject="$(head -n 1 "$message_file")"
subject_pattern='^(feat|fix|test|refactor|perf|build|ci|docs|chore|revert)(\([a-z0-9._/-]+\))?(!)?: [^[:space:]].+$'

if ! [[ "$subject" =~ $subject_pattern ]]; then
  printf 'ERROR: commit subject must follow Conventional Commits.\n' >&2
  printf 'Example: feat(camera): add permission recovery\n' >&2
  exit 1
fi

if ! awk '
  /^What:[[:space:]]*$/ { section="what"; next }
  /^Why:[[:space:]]*$/ { section="why"; next }
  /^[A-Z][A-Za-z -]*:[[:space:]]*$/ { section=""; next }
  /[^[:space:]]/ {
    if (section == "what") what_content=1
    if (section == "why") why_content=1
  }
  END { exit !(what_content && why_content) }
' "$message_file"; then
  printf 'ERROR: commit body requires non-empty What: and Why: sections.\n' >&2
  exit 1
fi
