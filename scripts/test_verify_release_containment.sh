#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_ROOT="$(mktemp -d /tmp/artinus-containment-test.XXXXXX)"
trap 'rm -rf -- "$FIXTURE_ROOT"' EXIT

FAKE_TOKEN='11111111-1111-1111-1111-111111111111'
CREDENTIAL_SOURCE="$FIXTURE_ROOT/evaluator_credentials.dart"
IOS_APP="$FIXTURE_ROOT/Runner.app"
ANDROID_CONTENTS="$FIXTURE_ROOT/android-contents"
ANDROID_APK="$FIXTURE_ROOT/app-release.apk"

mkdir -p "$IOS_APP" "$ANDROID_CONTENTS"
printf "const evaluatorIosAppCheckDebugToken = '%s';\n" "$FAKE_TOKEN" \
  > "$CREDENTIAL_SOURCE"
printf 'clean ios executable\n' > "$IOS_APP/Runner"
printf 'clean android artifact\n' > "$ANDROID_CONTENTS/classes.dex"
(cd "$ANDROID_CONTENTS" && zip -q "$ANDROID_APK" classes.dex)

run_check() {
  ARTINUS_CREDENTIAL_SOURCE_PATH="$CREDENTIAL_SOURCE" \
  ARTINUS_IOS_RELEASE_APP_PATH="$IOS_APP" \
  ARTINUS_ANDROID_RELEASE_APK_PATH="$ANDROID_APK" \
    "$ROOT/scripts/verify_release_containment.sh" 2>&1
}

output="$(run_check)"
[[ "$output" == *'release_token_containment=PASS'* ]]
[[ "$output" != *"$FAKE_TOKEN"* ]]

printf '%s\n' "$FAKE_TOKEN" >> "$IOS_APP/Runner"
if output="$(run_check)"; then
  printf 'expected iOS token fixture to fail\n' >&2
  exit 1
fi
[[ "$output" == *'release_token_containment=FAIL'* ]]
[[ "$output" != *"$FAKE_TOKEN"* ]]

printf 'clean ios executable\n' > "$IOS_APP/Runner"
printf 'evaluatorIosAppCheckDebugToken\n' > "$ANDROID_CONTENTS/classes.dex"
ANDROID_APK="$FIXTURE_ROOT/app-release-identifier.apk"
(cd "$ANDROID_CONTENTS" && zip -q "$ANDROID_APK" classes.dex)
if output="$(run_check)"; then
  printf 'expected Android identifier fixture to fail\n' >&2
  exit 1
fi
[[ "$output" == *'release_token_containment=FAIL'* ]]
[[ "$output" != *"$FAKE_TOKEN"* ]]

printf 'verify_release_containment_test=PASS\n'
