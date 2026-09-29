# Task 5 Report — Android Evidence Signing and App Check

## Status

`DONE_WITH_CONCERNS` as of 2026-09-29 09:13 KST.

All Task 5 code, signing, Firebase SHA-256, and Android Play Integrity provider requirements succeeded. Firebase AI Logic enforcement is not configurable yet because the Firebase Console reports that Firebase AI Logic has not been started for this project. Billing and unrelated services remain unchanged. Live token/cloud proof remains Task 7 because no Android device is connected.

## Implemented policy

- `android/app/build.gradle.kts` conditionally loads ignored `android/key.properties`.
- The release variant uses `registeredRelease` only when `storeFile`, `storePassword`, `keyAlias`, and `keyPassword` are all present; otherwise ordinary evaluator release/debug builds retain the existing debug-signing fallback.
- Flutter's comma-separated Base64 `dart-defines` are decoded at Gradle configuration time.
- Any build containing `ARTINUS_CLOUD_EVIDENCE=true` fails configuration unless the registered release signing properties are complete, with:

  `ARTINUS cloud evidence requires the registered release signing identity`

- No flavor, target, scheme, entry point, package name, or application ID was added or changed.

## Signing identity and Firebase evidence

- Package: `dev.bongjae.artinusocr`
- Firebase Android app ID: `1:867285305627:android:b00b0c0a36bcd8780f6bbe`
- Alias: `artinus-ocr-upload`
- Key: RSA 4096, 10,000-day validity
- Public certificate SHA-256: `B9:61:41:1C:0F:D0:2D:24:ED:94:CD:8A:06:A2:D2:C5:5B:19:58:6C:AD:6F:F2:4C:4E:8A:89:8E:4F:6F:E5:26`
- Initial Firebase SHA list: empty
- Final Firebase SHA list: one `SHA_256` entry matching the public certificate
- Gradle release signing report: `registeredRelease`, exact SHA-256 match
- `apksigner verify --verbose --print-certs`: `Verifies`; APK digest matches the keystore and Firebase

The keystore and password file were generated outside the repository in a narrowly scoped mode-0700 directory; both files are mode 0600. Local `android/key.properties` is mode 0600 and ignored. No private material is included in this report or Git.

## App Check Console result

- Authenticated Firebase Console access succeeded for project `artinus-ocr-bongjae-202609`.
- Android `ARTINUS OCR Android` / `dev.bongjae.artinusocr`: Play Integrity registered, with the registered SHA-256 prefilled by Firebase.
- iOS app: unchanged and unregistered.
- Billing: unchanged; console still shows Spark (`$0/month`).
- App Check API table, Firebase AI Logic row: `Firebase AI Logic 사용을 시작하여 앱 체크를 사용 설정하세요.` No enforcement toggle is exposed until that API is started.

## Verification record

| Check | Result |
| --- | --- |
| Pre-change cloud-enabled no-key release | Built, proving the missing policy (RED) |
| Post-change no-key cloud release | Rejected at Gradle configuration with exact stable message |
| Fresh ASCII clean clone default debug APK | Pass |
| Owner cloud-enabled release APK | Pass, 86.1 MB |
| Gradle `app:signingReport` | Pass; release uses `registeredRelease` |
| `apksigner verify --verbose --print-certs` | Pass; APK/keystore/Firebase SHA-256 match |
| ASCII `./gradlew app:testDebugUnitTest app:lintDebug` | Pass (`BUILD SUCCESSFUL`) |
| ASCII `flutter analyze` | Pass, no issues |
| ASCII `flutter test` | Pass, 222 tests |
| `scripts/check_context_budget.sh` | Pass |

Aggregate `./gradlew test` in the Korean-character worktree is not a clean app-only signal: it executes the dependency's `camera_android_camerax` Robolectric suite and reports 55 failures out of 180 dependency tests from malformed non-ASCII asset paths plus Java 17/SDK 36 incompatibility. The app-owned JVM tests and lint pass in the ASCII clone. The original-path `flutter analyze` likewise reproduces the already documented Flutter 3.47.5 LSP framing failure; the identical source passes analysis in the ASCII clone.

## Secret/material review

- `android/key.properties` is ignored and absent from `git status`.
- No `*.jks`, `*.keystore`, password file, App Check debug token, or environment dump is tracked.
- The committed diff contains only build policy and sanitized task/progress/evidence documentation.
- No APK was uploaded or published; no Play Console app, billing link, iOS/Apple state, remote Git state, or job-application state was changed.

## Remaining gates

- Start/configure Firebase AI Logic before an enforcement toggle can exist; Task 5 did not do so because the requested boundary was provider registration and enforcement-state confirmation without billing changes.
- Task 7 must perform live App Check token/cloud evidence on a connected Android device.

## Review follow-up — 2026-09-29 09:26 KST

### Findings resolved

- A present `android/key.properties` now fails Gradle configuration when any required value is missing or blank. It cannot silently select the debug key for an ordinary release.
- A complete file is accepted only when `keyAlias` is exactly `artinus-ocr-upload` and the resolved `storeFile` exists as a regular file.
- These invalid local states use only stable sanitized diagnostics:
  - `ARTINUS signing configuration is incomplete`
  - `ARTINUS signing configuration is invalid`
- Malformed Base64 in the comma-separated `dart-defines` property is contained as `ARTINUS build configuration contains invalid dart defines`; decoder details are not propagated.
- When `ARTINUS_CLOUD_EVIDENCE=true`, every Android build type is assigned `registeredRelease` through `configureEach`. The enabled signing report shows debug, release, profile, and debugAndroidTest all using the approved alias and public SHA-256.

### RED evidence

An isolated ASCII clean clone at commit `76807d1` used only temporary untracked fixtures. Before the production change:

- partial properties did not produce the required incomplete-configuration failure;
- a wrong alias did not produce the required invalid-configuration failure;
- a nonexistent store file did not produce the required invalid-configuration failure;
- malformed Base64 did not produce the sanitized dart-defines failure; and
- the cloud-enabled signing report still showed debug as `Config: debug`, alias `AndroidDebugKey`.

The fixture harness exited `4`, one failure for each unsafe configuration case, establishing the expected RED behavior without using owner passwords.

### GREEN evidence

| Required check | Fresh result |
| --- | --- |
| Clean checkout, no key, default debug | PASS — `app-debug.apk` built |
| No key, enabled release | PASS — rejected before compilation with registered-identity message |
| No key, enabled debug | PASS — rejected before compilation with the same stable message |
| Present partial properties | PASS — rejected with sanitized incomplete-configuration message |
| Wrong alias | PASS — rejected with sanitized invalid-configuration message |
| Nonexistent store file | PASS — rejected with sanitized invalid-configuration message |
| Malformed Base64 dart defines | PASS — rejected with sanitized dart-defines message |
| Complete owner config, enabled debug | PASS — APK built and `apksigner` verified |
| Complete owner config, enabled release | PASS — 86.1 MB APK built and `apksigner` verified |
| Enabled signing report | PASS — debug/release/profile/debugAndroidTest use `registeredRelease` |
| APK/Firebase identity comparison | PASS — enabled debug and release match the sole Firebase SHA-256 |
| ASCII `app:testDebugUnitTest app:lintDebug` | PASS — `BUILD SUCCESSFUL` |
| ASCII `flutter analyze` | PASS — no issues |
| Focused bootstrap regression | PASS — 5/5 |
| Full Flutter regression | PASS — 222/222 |

Public certificate SHA-256 remained `B9:61:41:1C:0F:D0:2D:24:ED:94:CD:8A:06:A2:D2:C5:5B:19:58:6C:AD:6F:F2:4C:4E:8A:89:8E:4F:6F:E5:26`. The Firebase SHA query was read-only and returned exactly one SHA-256 entry; Firebase/App Check configuration was not mutated.

### Fix self-review

- Failure messages contain no field names, paths, aliases supplied by fixtures, passwords, or decoder exceptions.
- Captured-output negative assertions confirmed that partial configuration prints none of the signing field/path tokens and malformed Base64 prints no decoder exception text.
- Missing `key.properties` still preserves clean-checkout default debug/release behavior, but a present invalid file always fails closed.
- Cloud-enabled configuration fails before Android compilation when the identity is absent; when present, no enabled debug/profile/release artifact can retain debug signing.
- Temporary property/store fixtures stayed outside tracked state. Owner `android/key.properties`, the keystore, password file, APKs, command logs, and environment data remain untracked.
- No Firebase/App Check state, billing, Play Console, Apple state, remote Git state, or application state changed during the follow-up.
