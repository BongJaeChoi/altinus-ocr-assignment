# E2E Testing Guide

## Evidence policy

Use deterministic framework integration tests for repeatability and real-device runs for camera truth. Record date, commit, device model, OS, build mode, scenario, result, and artifact path. Never infer iOS success from Android or browser tooling.

## Test layers

1. Unit: state machine, error mapping, stale-result protection, cleanup decisions.
2. Widget/component: permission, preview shell, processing, result, empty, error, retry.
3. Framework integration: full flow with fake camera/OCR adapters.
4. Native real device: actual permissions, preview, capture, OCR, lifecycle, orientation.

## Android — Google ARTEMIS

ARTEMIS is an Android UI automation system with CLI, MCP, and Python SDK surfaces. It does not currently establish native iOS coverage.

Iterate on an Android device during development. Final evidence must include a clean-clone run with fixed inputs, cloud-first and local-fallback paths, Pigeon behavior, frame-time, memory, and heat observations. No physical iPhone is available for this handoff. The user chose maximum feasible simulator checks and disclosure of the physical-device limitation; simulator runs still cannot establish physical iOS proof.

### Local setup

```bash
git clone https://github.com/google/artemis.git
cd artemis
./start.sh
```

Install its MCP configuration only after reviewing the generated command and repository path:

```bash
uv run artemis mcp --generate-config codex
# or install supported editor configurations
uv run artemis mcp --install all
```

### Exploration-first workflow

1. Connect exactly one intended Android device/emulator and confirm with `adb devices -l`.
2. Install a debug build containing no production secrets.
3. Explore the live UI before encoding a scenario; collect semantic labels and stable locators.
4. Prefer dynamic/text/accessibility locators; coordinates are a documented fallback.
5. Use the `flash` profile for routine flows. Escalate to `pro` for plan/checkpoint/ADB-heavy diagnosis.

Example exploratory run:

```bash
uv run artemis run \
  "Open the ARTINUS OCR app, grant camera permission, verify preview, capture printed text, wait for OCR, verify non-empty result, then retry" \
  --profile flash
```

Minimum Android scenarios (the cloud choice appears at 10 seconds, shares a cumulative 60-second budget, and permits at most two cloud attempts):

- permission grant and happy path;
- first denial, permanent denial/settings recovery;
- repeated capture taps while processing;
- empty/unreadable text and injected OCR failure;
- background/foreground during preview and processing;
- portrait/landscape behavior if rotation is supported;
- retry after each recoverable failure.

On ARTEMIS/tool failure, preserve the command, device state, logs, screenshot, and diagnosis. Do not turn a tool failure into an app pass/fail claim.

### Verified Play Store AVD

`AltinusPlayStore33` (Pixel 7 profile, Android 13/API 33,
`google_apis_playstore/arm64-v8a`) was installed and boot-verified on the Apple
Silicon test host. This host required the AVD's `hw.gpu.mode` to be
`swiftshader_indirect`; the reliable headless launch is:

```bash
$ANDROID_SDK_ROOT/emulator/emulator \
  -avd AltinusPlayStore33 -no-window -no-snapshot-load -no-audio
```

`adb devices -l`, `sys.boot_completed=1`, and the `com.android.vending`
package were verified. Native OCR and fake-flow integration tests pass on this
AVD. A sideloaded debug build still receives App Check `403 App attestation
failed` before the model request, so this AVD is not physical Play Integrity
evidence and the live Android cloud gate remains blocked.

## Chrome DevTools MCP

Chrome DevTools MCP controls and inspects Chrome. In this native assignment it is a support tool for Flutter DevTools, optional web harnesses, trace/network/console inspection, and browser-rendered artifacts. It is not a native camera E2E runner.

Suggested Codex MCP server command:

```text
npx -y chrome-devtools-mcp@latest --no-usage-statistics --no-performance-crux
```

Safety and use:

- Launch an isolated Chrome profile; connected clients can read and change browser content.
- Do not open private email, application portals, tokens, or unrelated signed-in sessions.
- Use screenshots, console messages, network requests, and performance traces only for browser/DevTools claims.
- Never cite a Chrome run as proof of native Android/iOS camera permission or capture behavior.

## Python CDP

Use a direct Chrome DevTools Protocol connection only for reproducible browser diagnostics not covered by the MCP workflow.

Start an isolated Chrome instance on macOS:

```bash
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir=/tmp/altinus-cdp-profile \
  about:blank
```

Discovery and connection outline:

```python
import json
import urllib.request

with urllib.request.urlopen("http://127.0.0.1:9222/json/version") as response:
    version = json.load(response)

print(version["webSocketDebuggerUrl"])
```

Connect a reviewed CDP client to that loopback WebSocket, subscribe only to required domains, save bounded artifacts, then close Chrome and remove the isolated temporary profile. Do not expose port 9222 beyond loopback. CDP results do not substitute for native app E2E.

## iOS verification

Because ARTEMIS and Chrome CDP do not cover native iOS camera behavior, use:

- framework integration tests with deterministic adapters;
- XCTest/XCUITest where stable native automation adds value;
- a real iPhone manual run for permission, preview, capture, OCR, lifecycle, rotation, and retry;
- Xcode/device logs and dated screenshots/video as evidence.

If no real iPhone is available, report iOS real-device verification as unverified, not passed. For the current user-approved simulator-only handoff, finish executable simulator checks and list the remaining hardware limitations; do not stop unrelated deliverable work waiting for an unavailable phone.

### iOS simulator-first gate

Run this gate from an ASCII-only checkout. The Korean parent path currently
causes Flutter/Xcode SwiftPM percent-encoding failure before native code starts.

```bash
xcrun simctl boot <simulator-id> || true
xcrun simctl bootstatus <simulator-id> -b
flutter pub get
flutter build ios --debug --no-codesign
flutter test integration_test/native_ocr_smoke_test.dart -d <simulator-id>
flutter test integration_test/fake_flow_test.dart -d <simulator-id>
```

Before direct `xcodebuild`, reset Flutter's generated target. An integration
test temporarily points `Generated.xcconfig` at a disposable test-listener
file, so running XCTest immediately afterward can read a stale path.

```bash
flutter build ios --simulator
xcodebuild -quiet \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination 'platform=iOS Simulator,id=<simulator-id>,arch=x86_64' \
  -only-testing:RunnerTests test \
  CODE_SIGNING_ALLOWED=NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES
```

This proves the typed Pigeon boundary, Swift host behavior, bundled Korean ML
Kit recognition for generated fixtures, deterministic UI recovery, and native
unit policies. It does not prove camera hardware, permission/settings UI,
flash, physical App Check attestation, device orientation, frame time, memory,
heat, or Android parity. The ten-request native OCR check is not a substitute
for ten physical capture cycles.

## Final simulator-only verification additions (2026-09-30)

- Native smoke now exercises dark/blurred/15-degree-tilted fixtures and malformed image bytes, in addition to original native fixtures and ten sequential requests. Poor-image classification permits typed text or no-readable-text; it makes no accuracy claim.
- Check actual iOS camera plugin discovery and repeated unavailable-camera recovery only on a simulator with no cameras:

```bash
flutter test integration_test/simulator_camera_recovery_test.dart \
  -d <simulator-id> --dart-define=RUN_SIMULATOR_CAMERA_CHECK=true
```

Only disclosure persistence is replaced in this test; camera discovery uses the actual plugin. This is absent-hardware recovery, not camera permission or preview proof.

- Use the iOS 18.5/x86_64 simulator for the pinned ML Kit packages. Current Flutter emits an arm64/iOS 26+ simulator warning for ML Kit; do not infer that the untested simulator family or physical device runs pass.
- Reset the normal simulator target before XCTest as above. After device fixture tests, restore a normal general-run APK/app, so the installed final target is not the integration-test listener.
- A native OCR that never settles may keep subsequent local work waiting. The common implementation is owned by another session; document actual cancellation/completion behavior without inventing native cancellation.

## Run record template

```text
Date/time (KST):
Commit:
Platform/device/OS:
Build mode:
Scenario:
Expected:
Observed:
Result: PASS | FAIL | BLOCKED
Artifacts:
Notes/follow-up:
```

## Sources

- [Apple: Running your app on simulated or physical devices](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- [Flutter integration testing](https://docs.flutter.dev/testing/integration-tests)
- [Flutter testing overview](https://docs.flutter.dev/testing/overview)
- [ML Kit text recognition on iOS](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios)
