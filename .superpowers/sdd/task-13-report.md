# Task 13 Report — Evaluator README and clean-clone proof

## Status

DONE_WITH_GATES. No external delivery action was performed.

## Delivered

- Created evaluator-focused `README.md` from the pinned assignment, code, lockfiles, task reports, and fresh command evidence only.
- Appended the Task 13 decision and verification record to `docs/AI_PROMPT_LOG.md` without credentials, image bytes, recognized text, raw model responses, or local image paths.
- Clearly states that the default checkout uses `FirebaseConfigurationPendingGateway`; cloud OCR is neither configured nor live verified.
- Preserves flash code and marks it unproven. Task 13 does not remove flash; the root release decision must decide hide/remove after actual two-platform evidence.

## Fresh verification evidence

### Original Korean-parent worktree

At source `2aff05253de75ffd55b7bf418419527efd176feb`:

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

`git clone . /private/tmp/altinus-task13-clone.hTu5St/altinus-ocr` checked out committed branch `0bb87c62312c0398753831775e372c1acf171a1a`.

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

The fresh clone's tracked tree was clean (`git diff --check` and `git diff --exit-code` passed). `git status --porcelain --untracked-files=all` showed two untracked `Package.resolved` files below Xcode-created SwiftPM workspace metadata directories after the iOS build; no tracked file changed. The observed directory/APK sizes are not archive/store sizes, and debug/release outputs are intentionally reported separately.

## Root-review follow-up

- Evaluator-visible identity now consistently uses `ARTINUS OCR`: README, Flutter app bar copy, Android application label, and iOS display name. Internal package/class/bundle identifiers intentionally remain `altinus_ocr`/`AltinusOcrApp` to avoid unrelated integration churn.
- Added a widget assertion for the visible title. It first failed while the app rendered `Altinus OCR`, then passed after the copy change.
- README now states the intentional unconfigured evaluator flow: capture → typed configuration recovery → `기기에서 인식`; it does not present cloud success as expected until Firebase is authorized and configured.
- README temporary-file wording now matches the controller: canonical input may remain at a cloud result for local re-recognition; recapture and controller disposal clean owned transaction files; startup sweep is limited to prefixed derivatives in the cache root and never sweeps camera root.
- Task 12 Android/iPhone live commands now require `RUN_LIVE_OCR=true`, exact `OCR_DEVICE`, and `OCR_GIT_COMMIT` values from `git rev-parse HEAD`.
- AI-use labels now explicitly state Used as-is: none, and separately document the verified fixed-clock and `TextPainter.dispose()` corrections.

Fresh follow-up verification: the title test RED showed no `ARTINUS OCR` widget; focused `flutter test test/app_smoke_test.dart` passed 3 tests after the change; full `flutter test` passed 200 tests. Pigeon regeneration stayed stable. Android debug build passed in the original worktree. In an ASCII-path copy, `flutter analyze` passed with no issues and iOS debug no-codesign built `Runner.app`. The final review range is `2aff052..HEAD`; Task 13 commits are `0bb87c6`, `cf1fe3d`, `caca759`, and the commits represented by that final range.

## Remaining gates

1. User must authorize one exact existing Firebase project before `flutterfire configure`, generated mobile configuration, Firebase initialization, or live `gemini-3.8-flash` verification.
2. Android and iPhone hardware still must separately prove native Korean OCR/glyph rendering, camera, permissions/settings, bad inputs, lifecycle, orientation, rapid taps, 10 cycles, 10s/60s flow, frames, memory, CPU, and heat.
3. Flash support/firing/lifecycle/parity is not proven; root release owner must decide whether to hide/remove it before delivery.

## Scope and safety

No remote, push, email, submission, Firebase project/app creation, billing, App Check change, credential, or real-device claim was made.
