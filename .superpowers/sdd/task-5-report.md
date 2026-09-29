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
