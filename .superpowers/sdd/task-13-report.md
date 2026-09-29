# Task 13 Report — Evaluator README and clean-clone proof

## Status

DONE_WITH_GATES. No external delivery action was performed.

## Delivered

- Created evaluator-focused `README.md` from the pinned assignment, code, lockfiles, task reports, and fresh command evidence only.
- Appended the Task 13 decision and verification record to `docs/AI_PROMPT_LOG.md` without credentials, image bytes, recognized text, raw model responses, or local paths.
- Clearly states that the default checkout uses `FirebaseConfigurationPendingGateway`; cloud OCR is neither configured nor live verified.
- Preserves flash code and marks it unproven. Task 13 does not remove flash; the root release decision must decide hide/remove after actual two-platform evidence.

## Fresh verification evidence

### Original Korean-parent worktree

At source `be032cf5b80b9362638fd08a9da7c8e76afdce19`:

| Command | Result |
| --- | --- |
| `flutter pub get` | PASS |
| `dart run pigeon --input pigeons/platform_apis.dart` then generated-file diff | PASS; no generated diff |
| `dart format --output=none --set-exit-if-changed lib test integration_test pigeons` | PASS |
| `flutter test` | PASS — 200 tests |
| `flutter build apk --release` | PASS — universal APK reported as 84.5MB |
| `flutter analyze` | BLOCKED/FAIL before diagnostics: Korean-parent LSP `FormatException: Unterminated string` |
| `flutter build ios --release --no-codesign` | BLOCKED/FAIL before compilation: SwiftPM percent-encoded Firebase package path cannot find `pubspec.yaml` |

The original-path failures reproduce the documented tooling defect, not a code waiver. No source, generated Pigeon output, or Xcode project workaround was applied.

### Committed ASCII clean clone

`git clone . /private/tmp/altinus-task13-clone.hTu5St/altinus-ocr` checked out committed branch `766f8adcec2c4d8811c23a333cc68962afaa0d1e`.

| Command | Result |
| --- | --- |
| `flutter pub get` | PASS |
| `dart run pigeon --input pigeons/platform_apis.dart` then `git diff --exit-code` | PASS; generated outputs stable |
| `flutter analyze` | PASS — No issues found (4.3s) |
| `flutter test` | PASS — 200 tests |
| `flutter build apk --debug` | PASS — universal debug APK observed 189M |
| `flutter build ios --debug --no-codesign` | PASS — observed `Runner.app` directory 171M |
| `flutter build apk --release` | PASS — universal release APK reported 84.5MB |
| `flutter build ios --release --no-codesign` | PASS — `Runner.app` reported 68.8MB |
| `scripts/check_context_budget.sh`, `git diff --check`, `git diff --exit-code` | PASS |

Xcode created two untracked SwiftPM workspace metadata directories after the iOS build; no tracked file changed. The observed directory/APK sizes are not archive/store sizes, and debug/release outputs are intentionally reported separately.

## Remaining gates

1. User must authorize one exact existing Firebase project before `flutterfire configure`, generated mobile configuration, Firebase initialization, or live `gemini-3.8-flash` verification.
2. Android and iPhone hardware still must separately prove native Korean OCR/glyph rendering, camera, permissions/settings, bad inputs, lifecycle, orientation, rapid taps, 10 cycles, 10s/60s flow, frames, memory, CPU, and heat.
3. Flash support/firing/lifecycle/parity is not proven; root release owner must decide whether to hide/remove it before delivery.

## Scope and safety

No remote, push, email, submission, Firebase project/app creation, billing, App Check change, credential, or real-device claim was made.
