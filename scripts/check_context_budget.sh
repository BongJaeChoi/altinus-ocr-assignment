#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIMIT=10240

for relative_path in AGENTS.md docs/PRD.md; do
  path="$ROOT/$relative_path"
  if [[ ! -f "$path" ]]; then
    printf 'ERROR: required context file is missing: %s\n' "$relative_path" >&2
    exit 1
  fi
  bytes="$(wc -c < "$path" | tr -d '[:space:]')"
  if (( bytes >= LIMIT )); then
    printf 'ERROR: %s is %s bytes; it must remain below %s bytes.\n' "$relative_path" "$bytes" "$LIMIT" >&2
    exit 1
  fi
  printf 'OK: %s is %s bytes (< %s).\n' "$relative_path" "$bytes" "$LIMIT"
done
