#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mapfile_support=0
if type mapfile >/dev/null 2>&1; then
  mapfile_support=1
fi

if (( mapfile_support )); then
  mapfile -t staged < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACMR)
else
  staged=()
  while IFS= read -r path; do
    staged+=("$path")
  done < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACMR)
fi

if (( ${#staged[@]} == 0 )); then
  exit 0
fi

docs_only=1
for path in "${staged[@]}"; do
  case "$path" in
    *.md|docs/*|.agents/*|.gitmessage)
      ;;
    *)
      docs_only=0
      break
      ;;
  esac
done

if (( docs_only == 0 )); then
  exit 0
fi

if [[ "${ALLOW_DOCS_ONLY:-}" == "1" && -n "${DOCS_ONLY_REASON:-}" ]]; then
  printf 'Docs-only exception accepted: %s\n' "$DOCS_ONLY_REASON"
  exit 0
fi

printf 'ERROR: documentation-only staged changes are blocked.\n' >&2
printf 'Couple docs to code/tests/verified evidence, or use an explicit reviewed exception:\n' >&2
printf 'ALLOW_DOCS_ONLY=1 DOCS_ONLY_REASON="specific reason" git commit ...\n' >&2
exit 1
