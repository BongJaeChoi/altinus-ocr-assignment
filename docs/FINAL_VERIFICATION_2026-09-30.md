# iOS simulator handoff — 2026-09-30 KST

## Scope and source

The user has no physical iPhone and requested maximum simulator verification. Another session owns Android and common OCR production/controller tests; this session adds generated-input and simulator recovery tests and maintains the README. Physical iPhone acceptance and full platform parity remain unverified.

The isolated ASCII checkout is `/tmp/altinus-finalize-56bxcev7/app`; native runs use `/tmp/altinus-audit-osf7e36z/ios`. Logs are local under `/tmp/altinus-finalize-56bxcev7/evidence`. These temporary paths are an evidence locator on the preparation machine, not artifacts available to a remote evaluator. Reproduction commands and source tests are committed.

Root documentation baseline: `c463550`; build source started from `a2a6254` with an explicitly recorded working diff. `common-snapshot-manifest.json` identifies the first common-source snapshot. A later read-only refresh is recorded in `common-final-snapshot-manifest.json`. The final source snapshot was later committed by the owning session as `d81d731`; all hashed lib/controller-test files match that commit. Its push status is verified separately at handoff.

Controller SHA-256 (source file, no credential values):

- First snapshot: `d92b7b51125dc9db29f2f25a0f52827d10fdd57e6aaea9fe20ec22de7c706785`.
- Final read-only snapshot: `6d35c323782fb39d19eba2f30f4f936e57dc3b1bcbbaf570670ed5306056cc72`.

`dart run pigeon --input pigeons/platform_apis.dart` regeneration left the generated Dart/Kotlin/Swift unchanged; context budgets and `git diff --check` passed.

The final refresh adds cleanup rechecks after asynchronous native reads/producers settle. Controller tests and full Flutter tests were rerun on that refresh.

## Recorded runs

Results identify the tested source explicitly; later concurrent edits require separate revalidation.

| Command / scenario | Observed result | Source and limit |
| --- | --- | --- |
| `flutter test integration_test/simulator_camera_recovery_test.dart -d <simulator-id> --dart-define=RUN_SIMULATOR_CAMERA_CHECK=true` | 1 passed | final common snapshot (`d81d731`), real camera plugin discovery; fresh CameraInitializing → cameraUnavailable after retry |
| `flutter test integration_test/native_ocr_smoke_test.dart -d <simulator-id>` | 4 passed | final fixture/Pigeon service source; common controller first snapshot is not exercised by this direct-service test |
| `flutter test integration_test/fake_flow_test.dart -d <simulator-id>` | 2 passed | common controller first snapshot; final-refresh host fake flow separately passes above |
| iOS fake flow (final common refresh) | 2 passed | `ios-latest-fake.log`, compiled controller equivalent to `d81d731` |
| Normal local-only simulator build and `simctl install` | exit 0 for both | `ios-final-normal-simulator.log`; restored actual app target, not integration-test listener |
| `flutter analyze` (final refresh) | 0 issues | `common-final-analyze.log` |
| `flutter test` (final refresh) | 262 passed | `common-final-tests.log` |
| host fake flow (final refresh) | 2 passed | `common-final-fake.log` |
| `flutter analyze` | 0 issues (first snapshot) | `common-snapshot-analyze.log` |
| `flutter test` | 261 passed (first snapshot) | `common-snapshot-tests.log`; local read-only common-source snapshot plus fixture tests |
| `flutter test -d flutter-tester integration_test/fake_flow_test.dart` | 2 passed (first snapshot) | deterministic adapters, not camera proof |
| `flutter build ios --debug --no-codesign` | exit 0 | dependency bootstrap / device compilation, no signing or install claim |
| `flutter build ios --simulator --debug` | exit 0 | common-source first snapshot |
| RunnerTests `xcodebuild` below | 9 passed, 0 failed/skipped | xcresult dated 2026-09-30 22:43:18 KST; x86_64/iOS 18.5 |
| `flutter build ios --release --no-codesign` | exit 0, rerun on final common source | `ios-latest-release.log`, equivalent to `d81d731`; no physical installation |
| Release containment scanner | PASS, rerun after final release build | iOS Runner SHA-256 `5937f24d9cf5739217d60dcadffa301043a84c891a6084c438e2c8f7e62f8279`; exact debug token and source identifier absent |
| Live primary generated-input cloud smoke | 1 passed, nonblank result | `gemini-3.8-flash`, iOS 18.5 simulator |
| Live fallback generated-input cloud smoke | 1 passed, nonblank result | `gemini-3.5-flash-lite`, iOS 18.5 simulator |

Cloud smokes were run before the common-source refresh, with metadata `a2a6254+single-flight-diff`. They exercise unchanged Firebase bootstrap/service paths directly, not the discarded controller experiment. They prove access for non-sensitive generated fixtures, not physical App Check, camera-to-cloud flow, comparative accuracy or production release cloud configuration.

The release scanner expanded an earlier completed Android APK (SHA-256 `4e5dd1b86e8de07ac32abc256c445ec2e297a8de45dc07a9d74594ebb4eb583d`) and the iOS release app above. No Android build/device operation was run after the user assigned Android elsewhere. This scan is credential containment evidence; the Android artifact does not establish the other session's final Android source/matrix.

## Reproduce iOS-only checks

Use an ASCII checkout, Flutter 3.47.5 / Dart 3.13.4, Xcode 26.1.1, CocoaPods 1.16.2 and the pinned lockfiles. Tested simulator: iPhone 16 Pro, iOS 18.5 build 22F77, x86_64, ID `FFF554F8-BC1E-43B0-A727-6BBFCD99EE21`.

```bash
flutter pub get
flutter analyze
flutter test
flutter test -d flutter-tester integration_test/fake_flow_test.dart
flutter build ios --debug --no-codesign
flutter test integration_test/native_ocr_smoke_test.dart -d <simulator-id>
flutter test integration_test/fake_flow_test.dart -d <simulator-id>
flutter test integration_test/simulator_camera_recovery_test.dart \
  -d <simulator-id> --dart-define=RUN_SIMULATOR_CAMERA_CHECK=true
flutter build ios --simulator --debug --dart-define=ARTINUS_CLOUD_EVIDENCE=false
xcodebuild -quiet -workspace ios/Runner.xcworkspace -scheme Runner \
  -sdk iphonesimulator -configuration Debug \
  -destination 'platform=iOS Simulator,id=<simulator-id>,arch=x86_64' \
  -only-testing:RunnerTests test \
  CODE_SIGNING_ALLOWED=NO ARCHS=x86_64 ONLY_ACTIVE_ARCH=YES
flutter build ios --release --no-codesign
scripts/check_context_budget.sh
```

Live-cloud commands used generated, non-sensitive inputs (both return one successful test):

```bash
flutter test integration_test/live_cloud_smoke_test.dart -d <simulator-id> \
  --dart-define=RUN_LIVE_OCR=true \
  --dart-define=OCR_DEVICE=iPhone16Pro-simulator-iOS18.5 \
  --dart-define=OCR_GIT_COMMIT=a2a6254+single-flight-diff \
  --dart-define=OCR_CLOUD_ATTEMPT=primary
# Repeat with --dart-define=OCR_CLOUD_ATTEMPT=fallback.
```

Release scan uses explicit completed artifact paths through `ARTINUS_IOS_RELEASE_APP_PATH` and `ARTINUS_ANDROID_RELEASE_APK_PATH`; it inspects files only and does not build Android.

See the existing live-cloud smoke's required opt-in flags and sanitized metadata in `integration_test/live_cloud_smoke_test.dart`; live service availability/quota can change. Do not run the explicitly enabled absent-camera test on an actual iPhone.

## Experiments and limitations

- Fixture TDD: adding blur/15-degree tilt expectation first failed with 5 distinct PNGs versus 7 expected. Factory expansion then passed with seven distinct valid 1200×800 encodings. Poor-input OCR permits either typed text or empty outcome; it does not guarantee accuracy or automatic restoration.
- The current native smoke includes malformed bytes, dark/blur/tilt, Korean/Latin, multiline, 90-degree rotation, no-text, missing input and ten sequential native recognitions. Ten generated-input calls do not prove ten physical capture cycles.
- An earlier service busy-guard implementation was removed after the user assigned common OCR elsewhere. Its tests/builds are historical experiments and do not certify the final root controller.
- The first final native rerun could not find the target simulator because it had shut down. The log `ios-final-native-device-offline.log` is an environment failure, not an app failure or pass. The selected simulator was booted again; subsequent results are recorded separately.
- The first camera-recovery assertion read `Booting`: frame settling did not await asynchronous startup. The test now waits for the controller state with a deadline, and subscribes to a fresh initialization/recovery transition after retry. An intermediate reconnect stalled before test output and was stopped; its log is `ios-camera-recovery-connection-stall.log`. Neither failed attempt is reported as a pass.
- The pinned ML Kit dependencies warn about arm64/iOS 26+ simulator support. This record is specific to the working x86_64/iOS 18.5 environment.
- No physical iPhone camera preview/capture, permission/settings timing, flash, orientation, frame-time, memory, heat or native platform parity is claimed. The user-approved simulator fallback does not change the original real-device requirement.

## Public handoff

The user explicitly requested PUBLIC visibility with the approved evaluator-only credential bundle disclosed. `gh repo view BongJaeChoi/altinus-ocr-assignment --json url,visibility` confirmed PUBLIC. GitHub upload is separate from employer submission; no recruiter email or application action was performed here.

## Sources

- [Pinned assignment requirements](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)
- [Apple simulator and physical device guidance](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
- [Repository verification procedure](E2E_TESTING.md), [AI decisions](AI_PROMPT_LOG.md)
