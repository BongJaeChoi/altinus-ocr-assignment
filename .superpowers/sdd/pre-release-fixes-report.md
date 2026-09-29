# Pre-release Important Fixes Report

## Status

DONE_WITH_EXTERNAL_GATES. No Firebase project, credential, App Check setting, physical device, remote, push, or submission was changed.

## Delivered

1. The default unconfigured Firebase gateway now advertises an explicit pending capability. Its typed configuration failure continues automatically to local OCR; configured gateway configuration/service failures retain the existing recovery policy.
2. The Dart Pigeon adapter maps exact `PlatformException.code` values without reading messages and rejects `noReadableText` replies unless `text` is null. Native codes remain internal.
3. Android app configurations use generated Gradle dependency locking. Runner project/workspace SwiftPM resolutions are committed alongside the existing CocoaPods lock.
4. README and design/context records now explain the evaluator flow, selection rationale, privacy/latency/binary/native-maintenance costs, cancellation and temporary-file limits, physical-evidence gap, and current `com.example`/debug-signing state.

Implementation commits:

- `e930239` — behavior and TDD coverage
- `11169d6` — generated Gradle/SwiftPM locks
- `7ac0e93` — evaluator documentation and decision alignment

## RED to GREEN evidence

The regression tests first demonstrated the old pending-configuration recovery screen, coarse bridge mapping for all platform failures, and acceptance of an empty contradictory `noReadableText` reply. The initial generated Gradle lock also failed a fresh `flutter build apk --debug` because Flutter assemble resolved `kotlin-stdlib-common:2.4.0` outside the recorded runtime lock state.

After implementation:

| Scope | Result |
| --- | --- |
| Focused controller/widget/data tests | PASS — 155 |
| App smoke | PASS — 3 |
| Fake integration flow | PASS — 2, including pending config → local result without a tap |
| Full Flutter suite in final clean clone | PASS — 213 |

Configured `configuration` and `service` failures remain recoverable, and the tests assert that technical codes/details do not render in UI.

## Lock generation and reproducibility

### Android

- `dependencyLocking { lockAllConfigurations() }` is scoped to the app project.
- Flutter assemble exposes Kotlin's common runtime module later than a plain dependency report. Declaring the matching module as `runtimeOnly` makes debug/profile/release runtime configurations visible to Gradle lock generation.
- Generated with Java 17 and:

```bash
./android/gradlew -p android \
  -Ptarget-platform=android-arm,android-arm64,android-x64 \
  :app:dependencies --write-locks
```

- `android/app/gradle.lockfile` SHA-256 before and after clean-clone regeneration: `dc93b92fae0976f297e6978f1c8392a326bd5b21eef205817c6274d37e4115ec`.
- The official all-resolvable-configurations sample was also tested but was not committed: AGP exposes `debugAndroidTestCompileClasspath` as resolvable while its Flutter plugin project variants are ambiguous in this graph. No configuration was silently skipped, no lenient mode was enabled, and the lockfile was not hand-edited.

### iOS

- Xcode generated both tracked files; their contents are identical:
  - `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
  - `ios/Runner.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Both remained SHA-256 `300c9e8c5be6d6b31b633179f945c82f9406b1865344c3952fb591b971b52438` after `xcodebuild -resolvePackageDependencies -workspace ios/Runner.xcworkspace -scheme Runner`.
- `firebase_ai 3.10.0` still reports no Flutter SwiftPM support, so its native graph remains CocoaPods-locked while FlutterFire-supported packages use SwiftPM. The README does not claim a SwiftPM-only graph.

## Final ASCII clean-clone verification

Clone source: `7ac0e93046bbbf61f12e4b13237547053873aa73` at `/tmp/artinus-pre-release-final.l0YMtG/artinus-ocr` (ephemeral evidence path).

| Command/check | Result |
| --- | --- |
| `flutter pub get` | PASS |
| Pigeon 29.0.4 regeneration and generated-file diff | PASS — byte-stable |
| `flutter analyze` | PASS — no issues, 4.4s |
| `flutter test` | PASS — 213 |
| `flutter test -d flutter-tester integration_test/fake_flow_test.dart` | PASS — 2 |
| `flutter build apk --debug` | PASS with strict Gradle lock |
| `:app:testDebugUnitTest :app:lintDebug` | PASS — 421 tasks |
| `flutter build ios --debug --no-codesign` | PASS |
| Xcode package resolve and both SwiftPM hashes | PASS — unchanged and identical |
| Gradle lock regeneration/hash | PASS — unchanged |
| `git diff --exit-code` after generation/build/resolve | PASS — tracked tree clean |
| handwritten Dart format, scoped handwritten `git diff --check`, context budget | PASS |

Pigeon 29.0.4 currently emits trailing spaces in four Dart constructor parameter lines. They are generated-only, regeneration is byte-stable, and they were not hand-edited. A full-range whitespace claim would therefore be misleading; the recorded whitespace gate covers handwritten source only.

## Remaining release gates

1. An authorized Firebase project, mobile app configuration, model/quota/location, and live cloud run; App Check remains intentionally absent from the evaluation build.
2. Separate Android and iPhone physical evidence for camera, permission/settings, native Korean text/glyphs, lifecycle/orientation, bad input, rapid taps, repeated captures, flash, and profile-mode frame/memory/CPU/heat behavior.
3. Production bundle identifiers, Android release signing, Apple signing/provisioning, and a release-owner decision on unproven flash UI.
4. A future `firebase_ai` update is needed before Flutter makes its legacy Kotlin-plugin/SwiftPM warnings hard errors.

## Hiring-persona review

Overall score: **84/100**. HR / recruiter: **82/100**. Hiring manager / development lead: **88/100**.

| Category | Score | Evidence |
| --- | ---: | --- |
| Target-role fit and positioning | 14/15 | Mobile frontend state, native bridge, privacy, and recovery are directly demonstrated. |
| ATS / requirements match | 13/15 | Assignment requirements are mapped clearly; physical-device completion is still pending. |
| Measurable business impact | 8/15 | Reliability is measured by tests/builds, but no user or production outcome can honestly be claimed. |
| Technical depth and problem solving | 14/15 | Typed failures, transaction identity, native taxonomy, and tool-generated locks show strong depth. |
| Team productivity and collaboration | 7/10 | Decision logs, generated-code boundaries, and reproducible commands aid handoff; no team adoption metric exists. |
| Evidence quality and credibility | 9/10 | Fresh clean-clone commands, hashes, RED/GREEN coverage, and explicit gates are reproducible. |
| Clarity, skimmability, and structure | 9/10 | README leads with evaluator behavior and separates verified facts from gates. |
| ATS-safe formatting and hygiene | 5/5 | Plain Markdown and direct terminology are easy to scan. |
| Authenticity and risk control | 5/5 | No cloud/device/submission overclaim and no fabricated metric. |

Highest-leverage next fixes:

1. Produce authorized live Firebase and two-platform physical evidence.
2. Replace example identifiers/debug signing with approved production identity and provisioning.
3. Capture a short, reproducible demo/evidence bundle that links the README claims to device artifacts.

Missing evidence question: Which exact Android device and iPhone can be reserved first for the required dated physical verification matrix?
