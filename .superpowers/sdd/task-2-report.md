# Task 2 report — Scaffold Flutter and lock shared dependencies

## Status

- All required Task 2 gates are complete when verified from an ASCII-path checkout.
- Scope: Flutter mobile scaffold only (`android`, `ios`); no desktop or web target was generated.
- Package: `altinus_ocr`.
- Direct dependencies exactly pinned as required; Dio was not added.
- Platform floors: Android `minSdk = 24`; iOS project and Podfile `15.5`.
- Camera permission text: `카메라로 문서를 촬영하여 텍스트를 인식합니다.`
- App composition: `ProviderScope` → `AltinusOcrApp` → `MaterialApp` → `ocr-shell`.

## TDD evidence

### RED — `flutter pub get && flutter test test/app_smoke_test.dart`

```text
test/app_smoke_test.dart:1:8: Error: Error when reading 'lib/app.dart': No such file or directory
import 'package:altinus_ocr/app.dart';
       ^
test/app_smoke_test.dart:7:35: Error: Couldn't find constructor 'AltinusOcrApp'.
    await tester.pumpWidget(const AltinusOcrApp());
                                  ^^^^^^^^^^^^^
00:00 +0 -1: Some tests failed.
```

This is the expected failure: the requested app type and its source file did not yet exist.

### GREEN — `flutter test test/app_smoke_test.dart`

```text
00:00 +0: loading .../test/app_smoke_test.dart
00:00 +0: boots the assignment shell
00:00 +1: All tests passed!
```

The same focused test was rerun after the final configuration changes with the same all-passing result.

## Verification

| Command | Result | Evidence |
| --- | --- | --- |
| `flutter pub get` | PASS | `Got dependencies!` |
| `flutter test test/app_smoke_test.dart` | PASS | `00:00 +1: All tests passed!` |
| `flutter analyze` | PASS | Controller independently ran it from an ASCII-path detached worktree: `No issues found! (ran in 3.6s)`. |
| Flutter SDK Dart `dart analyze` | PASS | `No issues found!` |
| Flutter SDK Dart `dart format --set-exit-if-changed lib test` | PASS | `Formatted 3 files (0 changed)` |
| `flutter build apk --debug` | PASS | `✓ Built build/app/outputs/flutter-apk/app-debug.apk` |
| `flutter build ios --debug --no-codesign` | PASS | Controller independently ran it from an ASCII-path detached worktree: `Xcode build done. 45.7s`, `✓ Built build/ios/iphoneos/Runner.app`. |
| `git diff --check` | PASS | Exit 0, no output. |
| `scripts/check_context_budget.sh` | PASS | `AGENTS.md` and `docs/PRD.md` are both below 10 KiB. |

### Original-path environment caveat (reproduced with `flutter analyze -v`)

```text
dart language-server --dart-sdk /opt/homebrew/Caskroom/flutter/3.32.0/flutter/bin/cache/dart-sdk ...
==> {"jsonrpc":"2.0","id":1,"method":"initialize", ... "rootUri":"file:///Users/bongjae/Documents/%EC%B7%A8..." ...}
Unhandled exception:
FormatException: Unterminated string (at character 559)
...es/altinus-ocr-implementation/"}],"capabilities":{"window":{"workDoneProgre
                                                                              ^
analysis server exited with code 255
```

`flutter doctor -v` reports Flutter 3.47.5 / Dart 3.13.4 at this SDK path, while the spawned tool cache path remains named `.../flutter/3.32.0/...`. The analyzer fails while parsing its own LSP initialization payload for this Korean-parent-path worktree, before inspecting Dart source. Directly invoking that same SDK's Dart analyzer succeeded; controller verification from an ASCII-path detached worktree also confirmed `flutter analyze` passes, so this is not a source blocker.

### Original-path iOS environment caveat (reproduced after setting the 15.5 target)

```text
Warning: Building for device with codesigning disabled. You will have to manually codesign before deploying to device.
Xcode failed to resolve Swift Package Manager dependencies:
xcodebuild: error: Could not resolve package dependencies:
main/Package.swift:73: Fatal error: Failed to load configuration: fileNotFound("Error loading or parsing pubspec.yaml: Error Domain=NSCocoaErrorDomain Code=260 \"The file “pubspec.yaml” couldn’t be opened because there is no such file.\" UserInfo={NSFilePath=/Users/bongjae/Documents/%E1%84%8E%E1%85%B1.../ios/Flutter/ephemeral/Packages/.packages/firebase_app_check-0.4.2/../../pubspec.yaml ...}")
```

The generated Swift Package path percent-encodes the Korean parent directory and resolves the Firebase package path incorrectly. This occurs before compilation and remains after `flutter pub get`; no iOS target or deployment floor was weakened. Controller verification from an ASCII-path detached worktree passed the exact iOS command, including `✓ Built build/ios/iphoneos/Runner.app`, confirming this is a path-specific environment caveat rather than a source or target configuration failure.

### Android note

The first Android compile failed because generated Flutter 3.47 configuration set `android.builtInKotlin=false`, while pinned `firebase_ai 3.10.0` assumes AGP 9 built-in Kotlin and therefore did not compile `FirebaseAIPlugin`. Setting the generated template flag to `true` is the minimal platform configuration correction; the required APK build then passed. The Flutter warning that `firebase_ai` applies KGP remains informational and is caused by the required pinned plugin.

## Files changed

- `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`
- `lib/main.dart`, `lib/app.dart`, `test/app_smoke_test.dart`
- generated `android/` project, including API 24 and built-in Kotlin configuration
- generated `ios/` project, including Podfile/project deployment target and camera-use description

## Self-review

- Reviewed staged paths: only requested manifests, source/test, and Android/iOS generated projects are intended for commit.
- Removed the unplanned Flutter-generated root `README.md` and `.metadata`; no web, macOS, Windows, or Linux targets were created.
- Existing docs, scripts, and `.gitignore` rules were preserved.
- Direct dependency versions in `pubspec.yaml` match the task brief exactly; lockfile is present; Dio is absent.

## Concerns / follow-up

1. The original Korean-parent-path checkout still reproduces Flutter analyzer and Xcode Swift Package path failures; use an ASCII-path checkout for local verification until the installed Flutter/Xcode tooling is repaired.
2. Android APK succeeds, but Firebase's KGP warning should be revisited only when the required plugin pin can change in a later task.
