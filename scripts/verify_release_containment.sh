#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREDENTIAL_SOURCE="${ARTINUS_CREDENTIAL_SOURCE_PATH:-$ROOT/lib/bootstrap/evaluator_credentials.dart}"
IOS_APP="${ARTINUS_IOS_RELEASE_APP_PATH:-$ROOT/build/ios/iphoneos/Runner.app}"
ANDROID_APK="${ARTINUS_ANDROID_RELEASE_APK_PATH:-$ROOT/build/app/outputs/flutter-apk/app-release.apk}"
IDENTIFIER='evaluatorIosAppCheckDebugToken'

fail() {
  printf 'release_token_containment=FAIL\n' >&2
  exit 1
}

[[ -f "$CREDENTIAL_SOURCE" && -d "$IOS_APP" && -f "$IOS_APP/Runner" ]] || fail
[[ -f "$ANDROID_APK" ]] || fail
command -v rg >/dev/null 2>&1 || fail
command -v unzip >/dev/null 2>&1 || fail
command -v shasum >/dev/null 2>&1 || fail

TOKEN="$({ sed -n "s/^const evaluatorIosAppCheckDebugToken = '\(.*\)';$/\1/p" \
  "$CREDENTIAL_SOURCE" || true; })"
[[ -n "$TOKEN" && "$TOKEN" != *$'\n'* ]] || fail

SCAN_ROOT="$(mktemp -d /tmp/artinus-release-scan.XXXXXX)"
trap 'rm -rf -- "$SCAN_ROOT"' EXIT
unzip -oq "$ANDROID_APK" -d "$SCAN_ROOT" || fail

assert_absent() {
  local needle="$1"
  shift
  if rg -a -F -q -- "$needle" "$@"; then
    fail
  else
    local status=$?
    [[ "$status" -eq 1 ]] || fail
  fi
}

assert_absent "$TOKEN" "$IOS_APP" "$SCAN_ROOT"
assert_absent "$IDENTIFIER" "$IOS_APP" "$SCAN_ROOT"

COMMIT="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf 'unknown')"
ANDROID_SHA="$(shasum -a 256 "$ANDROID_APK" | awk '{print $1}')"
IOS_SHA="$(shasum -a 256 "$IOS_APP/Runner" | awk '{print $1}')"

printf 'commit=%s\n' "$COMMIT"
printf 'android_release_apk_sha256=%s\n' "$ANDROID_SHA"
printf 'ios_release_runner_sha256=%s\n' "$IOS_SHA"
printf 'release_token_containment=PASS\n'
