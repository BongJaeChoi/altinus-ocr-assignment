# Firebase Signed Cloud Evidence Implementation Plan

> Historical status: Tasks 1–5 were completed. The user approved evaluator-delivery option B on 2026-09-29, so the obsolete Apple App Attest/private-bundle Tasks 6–7 are superseded by `2026-09-29-evaluator-cloud-bundle.md` and must not be executed.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the dedicated ARTINUS Firebase project and mobile app registrations, commit reviewable Firebase options, and add one-target opt-in cloud composition whose live evidence uses the registered signing identity and App Check while a clean checkout still runs local OCR with `flutter run`.

**Architecture:** Keep the existing single Android app and iOS Runner scheme. A tested bootstrap returns the pending gateway unless `ARTINUS_CLOUD_EVIDENCE=true`; the enabled path initializes the committed `DefaultFirebaseOptions`, activates production App Check, and only then returns `FirebaseSdkModelGateway`. Firebase identifiers are committed public configuration, while keystores, passwords, certificates, provisioning profiles, and debug tokens remain outside Git.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, `firebase_core 4.6.0`, `firebase_ai 3.10.0`, direct `firebase_app_check 0.4.2`, FlutterFire CLI 1.3.2, Firebase CLI 15.16.0, Android Play Integrity, Apple App Attest with DeviceCheck fallback.

## Global Constraints

- Firebase project ID is exactly `artinus-ocr-bongjae-202609`; if unavailable, stop before creating a suffixed substitute.
- Firebase display name is `ARTINUS OCR Assignment`.
- Android application ID and Apple bundle ID are exactly `dev.bongjae.artinusocr`.
- Keep one evaluator-facing build target; do not add Android flavors, Xcode schemes, or alternate Dart entry points.
- `flutter run` without defines must not initialize Firebase, activate App Check, prepare a cloud derivative, start the 10/60-second cloud budget, or dispatch a cloud request.
- `ARTINUS_CLOUD_EVIDENCE=true` is the only production composition switch. It initializes Firebase, then App Check, then the SDK gateway in that order.
- Android cloud evidence uses a dedicated keystore whose SHA-256 fingerprint is registered with Firebase/Play Integrity. Never commit the keystore, passwords, `key.properties`, or command output containing them.
- Apple cloud evidence uses the exact bundle ID, an authorized Apple Team ID, matching signing certificate/profile, and App Attest with DeviceCheck fallback. Do not reuse the `dealert` provisioning profile.
- `firebase_options.dart`, `.firebaserc`, `google-services.json`, and `GoogleService-Info.plist` contain public Firebase identifiers and may be committed; no Gemini Developer API secret is embedded.
- Do not enable billing, push a remote, publish an artifact, create a public repository, or submit/email the assignment.
- Use TDD for Dart behavior changes and regenerate Pigeon output only from `pigeons/platform_apis.dart`.

---

## File Map

- `.firebaserc` — pins Firebase CLI commands to the dedicated assignment project.
- `lib/firebase_options.dart` — FlutterFire-generated Android/iOS public options.
- `android/app/google-services.json` — generated Android Firebase app association.
- `ios/Runner/GoogleService-Info.plist` — generated Apple Firebase app association.
- `lib/bootstrap/firebase_cloud_bootstrap.dart` — the single responsibility boundary for mode selection, Firebase initialization, App Check activation, and gateway construction.
- `lib/main.dart` — obtains the bootstrap result and overrides `firebaseModelGatewayProvider` before mounting the app.
- `lib/features/ocr/data/firebase_ai_ocr_service.dart` — adds a configured-but-unavailable gateway used when enabled bootstrap fails.
- `test/bootstrap/firebase_cloud_bootstrap_test.dart` — verifies disabled, success, initialization-failure, App-Check-failure, order, and redaction behavior.
- `test/app_smoke_test.dart` — verifies production provider composition for the default evaluator path.
- `android/app/build.gradle.kts` and `android/key.properties` — application ID and conditional owner-only release signing; `key.properties` stays ignored.
- `pigeons/platform_apis.dart`, `android/app/src/{main,test}/kotlin/dev/bongjae/artinusocr/**` — authoritative Kotlin package and generated/native files.
- `ios/Runner.xcodeproj/project.pbxproj` — Runner and RunnerTests bundle identifiers.
- `README.md`, `docs/CONTEXT.md`, `docs/AI_PROMPT_LOG.md`, `.superpowers/sdd/progress.md` — evaluator commands, decisions, and verified evidence only.

---

### Task 1: Create the Dedicated Firebase Project and Mobile Apps

**Files:**
- Create: `.firebaserc`
- Evidence later: `docs/AI_PROMPT_LOG.md`

**Interfaces:**
- Consumes: approved project ID `artinus-ocr-bongjae-202609` and mobile ID `dev.bongjae.artinusocr`.
- Produces: Firebase project number, Android Firebase app ID, and Apple Firebase app ID for Tasks 3, 5, and 6.

- [ ] **Step 1: Prove the exact project ID is absent**

Run:

```bash
firebase projects:list --json
```

Expected: success; no result has `projectId == "artinus-ocr-bongjae-202609"`. If it already exists, inspect ownership and reuse it only if its display name and purpose already match; do not create a second project.

- [ ] **Step 2: Create the project without billing mutation**

Run:

```bash
firebase projects:create artinus-ocr-bongjae-202609 \
  --display-name "ARTINUS OCR Assignment"
```

Expected: success with the exact project ID. Do not open or change billing during this command.

- [ ] **Step 3: Register Android and Apple apps**

Run:

```bash
firebase --project artinus-ocr-bongjae-202609 apps:create ANDROID \
  "ARTINUS OCR Android" --package-name dev.bongjae.artinusocr

firebase --project artinus-ocr-bongjae-202609 apps:create IOS \
  "ARTINUS OCR iOS" --bundle-id dev.bongjae.artinusocr
```

Expected: one Android and one iOS app. Record only their non-secret Firebase app IDs; do not print access tokens.

- [ ] **Step 4: Verify remote state before touching source identifiers**

Run:

```bash
firebase --project artinus-ocr-bongjae-202609 apps:list --json
```

Expected: exactly two mobile apps with the approved platform identifiers.

- [ ] **Step 5: Add the repository project alias and commit with Task 2**

Create `.firebaserc` with:

```json
{
  "projects": {
    "default": "artinus-ocr-bongjae-202609"
  }
}
```

Do not make a documentation-only commit; Task 2 commits this association together with the matching source identifiers.

---

### Task 2: Replace Example Mobile Identifiers and Regenerate Pigeon

**Files:**
- Modify: `android/app/build.gradle.kts`
- Modify: `pigeons/platform_apis.dart`
- Move/modify: `android/app/src/main/kotlin/com/example/altinus_ocr/**` → `android/app/src/main/kotlin/dev/bongjae/artinusocr/**`
- Move/modify: `android/app/src/test/kotlin/com/example/altinus_ocr/**` → `android/app/src/test/kotlin/dev/bongjae/artinusocr/**`
- Modify: `ios/Runner.xcodeproj/project.pbxproj`
- Regenerate: `lib/src/generated/platform_apis.g.dart`, `android/app/src/main/kotlin/dev/bongjae/artinusocr/PlatformApis.g.kt`, `ios/Runner/PlatformApis.g.swift`
- Test: Android app JVM tests and Flutter Pigeon adapter tests

**Interfaces:**
- Consumes: remote app registrations from Task 1.
- Produces: native binaries whose application/bundle IDs match Firebase and future App Check registration.

- [ ] **Step 1: Write identifier assertions before changing production files**

Add a shell verification to the task report command set:

```bash
rg -n 'com\.example\.altinus|com/example/altinus' android ios pigeons
```

Expected before implementation: matches current namespace, application ID, bundle IDs, Pigeon output, and Kotlin packages.

- [ ] **Step 2: Change authoritative identifiers**

Set in `android/app/build.gradle.kts`:

```kotlin
namespace = "dev.bongjae.artinusocr"
applicationId = "dev.bongjae.artinusocr"
```

Set in `pigeons/platform_apis.dart`:

```dart
kotlinOut:
    'android/app/src/main/kotlin/dev/bongjae/artinusocr/PlatformApis.g.kt',
kotlinOptions: KotlinOptions(package: 'dev.bongjae.artinusocr'),
```

Change all app Kotlin package declarations to:

```kotlin
package dev.bongjae.artinusocr
```

Set Runner bundle IDs to `dev.bongjae.artinusocr` and RunnerTests bundle IDs to `dev.bongjae.artinusocr.RunnerTests` in every Xcode build configuration.

- [ ] **Step 3: Regenerate, never hand-edit, Pigeon output**

Run:

```bash
dart run pigeon --input pigeons/platform_apis.dart
dart run pigeon --input pigeons/platform_apis.dart
git diff --exit-code -- lib/src/generated/platform_apis.g.dart \
  android/app/src/main/kotlin/dev/bongjae/artinusocr/PlatformApis.g.kt \
  ios/Runner/PlatformApis.g.swift
```

Expected: the second generation is byte-stable.

- [ ] **Step 4: Run focused native and Dart tests**

Run:

```bash
flutter test test/features/ocr/data/pigeon_adapters_test.dart
./android/gradlew -p android :app:testDebugUnitTest
```

Expected: all focused tests pass under the new package.

- [ ] **Step 5: Commit the identifier boundary**

```bash
git add .firebaserc android ios/Runner.xcodeproj/project.pbxproj \
  lib/src/generated pigeons
git commit -m "refactor(identity): align mobile apps with Firebase" \
  -m "What: Replace example Android and Apple identifiers and regenerate Pigeon under the approved package. Why: Firebase registration, native dispatch, signing, and App Check must share one durable app identity."
```

---

### Task 3: Generate and Pin Firebase Configuration

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`
- Create: `lib/firebase_options.dart`
- Create: `android/app/google-services.json`
- Create: `ios/Runner/GoogleService-Info.plist`
- Modify as generated: Android/iOS Firebase plugin integration files
- Modify: `android/app/gradle.lockfile`, iOS lockfiles when dependency resolution changes
- Test: `test/firebase_options_test.dart`

**Interfaces:**
- Consumes: exact Firebase app registrations and source identifiers.
- Produces: `DefaultFirebaseOptions.currentPlatform` and direct `firebase_app_check` API for Task 4.

- [ ] **Step 1: Add a direct App Check dependency**

Set in `pubspec.yaml`:

```yaml
firebase_ai: 3.10.0
firebase_app_check: 0.4.2
firebase_core: 4.6.0
```

Run `flutter pub get`. Expected: `firebase_app_check 0.4.2` remains pinned and no unrelated package upgrade occurs.

- [ ] **Step 2: Generate all Firebase files from the approved project**

Run:

```bash
flutterfire configure \
  --project=artinus-ocr-bongjae-202609 \
  --platforms=android,ios \
  --android-package-name=dev.bongjae.artinusocr \
  --ios-bundle-id=dev.bongjae.artinusocr \
  --out=lib/firebase_options.dart \
  --android-out=android/app/google-services.json \
  --ios-out=ios/Runner/GoogleService-Info.plist \
  --overwrite-firebase-options \
  --yes
```

Expected: generated options refer only to the dedicated project and two approved app IDs.

- [ ] **Step 3: Write and run configuration-integrity tests**

Create `test/firebase_options_test.dart` with assertions equivalent to:

```dart
test('generated mobile options belong to the dedicated project', () {
  expect(DefaultFirebaseOptions.android.projectId,
      'artinus-ocr-bongjae-202609');
  expect(DefaultFirebaseOptions.android.appId, isNotEmpty);
  expect(DefaultFirebaseOptions.ios.projectId,
      'artinus-ocr-bongjae-202609');
  expect(DefaultFirebaseOptions.ios.iosBundleId,
      'dev.bongjae.artinusocr');
});
```

Run `flutter test test/firebase_options_test.dart`. Expected: pass without printing API keys.

- [ ] **Step 4: Refresh native lock state using supported generators**

Run:

```bash
./android/gradlew -p android \
  -Ptarget-platform=android-arm,android-arm64,android-x64 \
  :app:dependencies --write-locks
flutter build ios --debug --no-codesign
```

Use an ASCII-only clean clone for the iOS command if the known Korean-parent-path SwiftPM bug recurs. Expected: generated lock changes are tool-owned and subsequent regeneration is stable.

- [ ] **Step 5: Scan the staged Firebase files for actual secrets**

Run a structured key-name check for private keys, service-account fields, passwords, tokens, and App Check debug secrets. Expected: public Firebase API/config identifiers may exist; `private_key`, `client_email`, keystore passwords, and debug tokens do not.

- [ ] **Step 6: Commit generated configuration and pinned dependency**

```bash
git add pubspec.yaml pubspec.lock lib/firebase_options.dart \
  android/app/google-services.json ios/Runner/GoogleService-Info.plist \
  android ios test/firebase_options_test.dart
git commit -m "build(firebase): add dedicated mobile configuration" \
  -m "What: Add generated Android/iOS Firebase options and direct App Check dependency with refreshed native locks. Why: Make the approved cloud integration reviewable while keeping signing secrets outside Git."
```

---

### Task 4: Implement the Opt-In Firebase and App Check Bootstrap

**Files:**
- Create: `lib/bootstrap/firebase_cloud_bootstrap.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/ocr/data/firebase_ai_ocr_service.dart`
- Create: `test/bootstrap/firebase_cloud_bootstrap_test.dart`
- Modify: `test/app_smoke_test.dart`

**Interfaces:**
- Consumes: `DefaultFirebaseOptions.currentPlatform`, `Firebase.initializeApp`, `FirebaseAppCheck.instance.activate`, `FirebaseSdkModelGateway`.
- Produces: `Future<FirebaseModelGateway> createFirebaseModelGateway({bool cloudEvidenceEnabled = artinusCloudEvidenceEnabled, FirebaseCloudRuntime? runtime})`.

- [ ] **Step 1: Write RED tests for mode and ordering**

Cover these exact behaviors with an injected recording runtime:

```dart
test('disabled mode returns pending without touching Firebase', () async {});
test('enabled mode initializes Firebase then App Check then SDK gateway', () async {});
test('Firebase initialization failure returns configured failure gateway', () async {});
test('App Check activation failure returns configured failure gateway', () async {});
test('bootstrap never includes raw exception text in its public failure', () async {});
```

The enabled success assertion must compare the call order to:

```dart
['firebase.initialize', 'appCheck.activate', 'gateway.create']
```

Run `flutter test test/bootstrap/firebase_cloud_bootstrap_test.dart`. Expected: fail because the bootstrap API does not exist.

- [ ] **Step 2: Add a configured failure gateway**

Add to `firebase_ai_ocr_service.dart`:

```dart
final class FirebaseConfigurationFailedGateway
    implements FirebaseModelGateway {
  const FirebaseConfigurationFailedGateway();

  @override
  bool get configurationPending => false;

  @override
  Future<FirebaseModelResponse> generate(FirebaseModelRequest request) =>
      Future<FirebaseModelResponse>.error(
        OcrFailure.of(OcrFailureKind.configuration),
      );
}
```

This prevents an enabled-but-broken build from being mistaken for the intentional local evaluator composition.

- [ ] **Step 3: Implement the bootstrap boundary**

Use this public shape:

```dart
const artinusCloudEvidenceEnabled = bool.fromEnvironment(
  'ARTINUS_CLOUD_EVIDENCE',
  defaultValue: false,
);

abstract interface class FirebaseCloudRuntime {
  Future<void> initialize();
  Future<void> activateAppCheck();
  FirebaseModelGateway createGateway();
}

Future<FirebaseModelGateway> createFirebaseModelGateway({
  bool cloudEvidenceEnabled = artinusCloudEvidenceEnabled,
  FirebaseCloudRuntime? runtime,
}) async {
  if (!cloudEvidenceEnabled) {
    return const FirebaseConfigurationPendingGateway();
  }
  final selected = runtime ?? ProductionFirebaseCloudRuntime();
  try {
    await selected.initialize();
    await selected.activateAppCheck();
    return selected.createGateway();
  } catch (_) {
    return const FirebaseConfigurationFailedGateway();
  }
}
```

`ProductionFirebaseCloudRuntime.initialize()` calls `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`. `activateAppCheck()` uses `AndroidProvider.playIntegrity` and `AppleProvider.appAttestWithDeviceCheckFallback` and runs only on Android/iOS.

- [ ] **Step 4: Compose the gateway before `runApp`**

In `main.dart`, create the disclosure store and Firebase gateway, then override both providers:

```dart
final disclosureStore = await SharedPreferencesDisclosureStore.create();
final firebaseGateway = await createFirebaseModelGateway();
runApp(
  ProviderScope(
    overrides: [
      disclosureStoreProvider.overrideWithValue(disclosureStore),
      firebaseModelGatewayProvider.overrideWithValue(firebaseGateway),
    ],
    child: const AltinusOcrApp(),
  ),
);
```

Do not log caught initialization exceptions or credentials.

- [ ] **Step 5: Make focused tests GREEN and prove the default path remains local**

Run:

```bash
flutter test test/bootstrap/firebase_cloud_bootstrap_test.dart
flutter test test/app_smoke_test.dart
flutter test test/features/ocr/application/ocr_flow_controller_test.dart
flutter test -d flutter-tester integration_test/fake_flow_test.dart
```

Expected: all pass; the default smoke/fake flow records no Firebase or cloud-image preparation call.

- [ ] **Step 6: Commit bootstrap behavior**

```bash
git add lib/main.dart lib/bootstrap lib/features/ocr/data/firebase_ai_ocr_service.dart test integration_test
git commit -m "feat(firebase): gate signed cloud bootstrap" \
  -m "What: Initialize Firebase and production App Check only for the explicit cloud-evidence build and expose typed configured failures. Why: Keep evaluator startup one-command and local while ensuring live cloud proof cannot bypass attestation."
```

---

### Task 5: Create and Register the Android Evidence Signing Identity

**Files:**
- Modify: `android/app/build.gradle.kts`
- Local ignored: `android/key.properties`
- Local external: dedicated `artinus-ocr-upload.jks`
- Test/evidence: Gradle signing report and Firebase SHA list

**Interfaces:**
- Consumes: Android Firebase app ID from Task 1.
- Produces: owner-only signed Android cloud-evidence APK and registered SHA-256 fingerprint.

- [ ] **Step 1: Generate a dedicated key without exposing passwords**

Create the keystore in a mode-0700 external directory, generate a random password into a mode-0600 local secret file, and invoke `keytool` with environment/file-backed password input. Never echo the password or pass it in a captured command line. Use alias `artinus-ocr-upload`, RSA 2048 or stronger, and validity 10,000 days.

- [ ] **Step 2: Add conditional release signing**

Load ignored `android/key.properties` only when it exists. Configure the release signing config from its four standard fields. Preserve the current debug signing fallback when the file is absent so a clean evaluator checkout can still build. Decode Flutter's comma-separated Base64 `dart-defines` Gradle property and fail configuration when it contains `ARTINUS_CLOUD_EVIDENCE=true` but the release key properties are absent:

```kotlin
val dartDefines = providers.gradleProperty("dart-defines").orNull
    ?.split(',')
    ?.filter(String::isNotBlank)
    ?.map { String(java.util.Base64.getDecoder().decode(it)) }
    .orEmpty()
val cloudEvidenceEnabled =
    dartDefines.contains("ARTINUS_CLOUD_EVIDENCE=true")
if (cloudEvidenceEnabled && !keystorePropertiesFile.exists()) {
    throw GradleException(
        "ARTINUS cloud evidence requires the registered release signing identity",
    )
}
```

- [ ] **Step 3: Obtain and register the SHA-256 fingerprint**

Run `keytool -list -v` without printing passwords and capture only the SHA-256 fingerprint and the exact Android Firebase app ID:

```bash
task_android_app_id=$(firebase --project artinus-ocr-bongjae-202609 \
  apps:list --json | jq -er \
  '.result[] | select(.platform == "ANDROID" and .packageName == "dev.bongjae.artinusocr") | .appId')
task_sha256=$(keytool -list -v -keystore "$ARTINUS_KEYSTORE_PATH" \
  -alias artinus-ocr-upload -storepass:env ARTINUS_STORE_PASSWORD |
  sed -n 's/^[[:space:]]*SHA256: //p')
test -n "$task_android_app_id" && test -n "$task_sha256"
firebase --project artinus-ocr-bongjae-202609 \
  apps:android:sha:create "$task_android_app_id" "$task_sha256"
```

- [ ] **Step 4: Verify signing identity and App Check provider registration**

Run the Gradle signing report and `firebase apps:android:sha:list`. Expected: the release variant and Firebase list show the same SHA-256. In Firebase Console, register the Android app for Play Integrity and confirm Firebase AI Logic enforcement without changing billing.

- [ ] **Step 5: Build both evaluator and owner evidence variants**

Run:

```bash
flutter build apk --debug
flutter build apk --release \
  --dart-define=ARTINUS_CLOUD_EVIDENCE=true
```

Expected: default debug build succeeds without private signing files; enabled release build is signed by the registered key. Verify the APK certificate with `apksigner verify --print-certs` and compare SHA-256.

- [ ] **Step 6: Commit only build logic and tests**

```bash
git add android/app/build.gradle.kts android/app/gradle.lockfile test
git commit -m "build(android): require registered cloud signing" \
  -m "What: Add owner-only release signing and fail enabled cloud builds that use the debug identity. Why: Play Integrity validates the registered SHA-256 certificate, while clean evaluator builds must remain simple."
```

---

### Task 6: Establish the Apple Signing and App Check Gate

**Files:**
- Modify: `ios/Runner.xcodeproj/project.pbxproj` only with authorized team/signing settings
- External: Apple Developer App ID and provisioning profile
- External: Firebase Apple App Check registration

**Interfaces:**
- Consumes: Apple Firebase app ID and bundle ID `dev.bongjae.artinusocr`.
- Produces: an authorized iPhone build whose Team ID/bundle ID match App Attest registration.

- [ ] **Step 1: Verify the available Apple signing identity without mutating the account**

Run `security find-identity -v -p codesigning` and inspect installed profiles. Expected current evidence: the only profile is app-specific to `com.dealert.app.shimfactory` and must not be reused.

- [ ] **Step 2: Obtain action-time authorization for the Apple Team**

Before creating an App ID or provisioning profile, report the exact Team ID and account ownership visible in Xcode/Apple Developer. Continue only after the user confirms that this team may be used for the assignment. This is an external account mutation gate, not a code placeholder.

- [ ] **Step 3: Create the dedicated App ID and provisioning profile**

Create explicit App ID `dev.bongjae.artinusocr`, enable App Attest/DeviceCheck capabilities required by the provider, and create a development or Ad Hoc profile for the actual iPhone and installed certificate. Do not create an App Store record because submission/distribution is out of scope.

- [ ] **Step 4: Register Apple App Check**

In Firebase Console, register the iOS app with the authorized Team ID and App Attest provider; keep DeviceCheck fallback in the Flutter client. Confirm Firebase AI Logic enforcement without enabling billing.

- [ ] **Step 5: Verify clean and signed builds separately**

Run in an ASCII-only clone:

```bash
flutter build ios --debug --no-codesign
flutter build ios --release \
  --dart-define=ARTINUS_CLOUD_EVIDENCE=true
```

Expected: no-codesign evaluator build succeeds without private profile material; signed build reports the approved Team ID and bundle ID. Install the signed build on the authorized iPhone before claiming App Attest evidence.

- [ ] **Step 6: Commit only project settings that are safe and portable**

Never commit `.mobileprovision`, `.p12`, private keys, passwords, or debug tokens. Commit portable bundle/capability settings only after a clean clone still completes the no-codesign build.

---

### Task 7: Run Live Cloud, Device, and Final Evidence Gates

**Files:**
- Modify: `integration_test/live_cloud_smoke_test.dart` only if bootstrap reuse requires it
- Modify: `README.md`
- Modify: `docs/CONTEXT.md`, `docs/AI_PROMPT_LOG.md`, `.superpowers/sdd/progress.md`
- Create/update: `.superpowers/sdd/firebase-cloud-evidence-report.md`

**Interfaces:**
- Consumes: configured Firebase project, signed mobile apps, App Check providers, physical Android/iPhone.
- Produces: dated evidence separating clean-checkout evaluator behavior from registered cloud behavior.

- [ ] **Step 1: Enable Firebase AI Logic through the official guided workflow**

Choose Gemini Developer API and the no-billing/free path. Verify model availability for `gemini-3.8-flash`, Firebase AI Logic enforcement, quota, and location. Do not attach a billing account.

- [ ] **Step 2: Run Android live evidence**

On the registered physical Android device, run the signed enabled build. Verify App Check token acceptance, capture → cloud OCR → Korean result, no-text result, one transient retry, 10-second choice, 60-second stale rejection, and manual local fallback. Record only commit, device model, OS, build mode, model, domain outcome, timings, and artifact paths—never image bytes/path, recognized text, raw response, token, or credential.

- [ ] **Step 3: Run iPhone live evidence**

Repeat the same matrix on the authorized physical iPhone with App Attest/DeviceCheck. Android evidence does not substitute for iPhone evidence.

- [ ] **Step 4: Run performance and lifecycle evidence**

In profile mode on each physical platform, capture preview frame behavior, preparation/local OCR UI-thread responsiveness, ten repeated captures, RSS/external memory trend, CPU/heat observation, background/resume, orientation, permission/settings, rapid taps, and flash. If flash is not proven on both platforms, remove or hide it on both before final delivery and add a regression test.

- [ ] **Step 5: Run the complete clean-clone gate**

In a new ASCII-only clone at final HEAD:

```bash
flutter pub get
dart run pigeon --input pigeons/platform_apis.dart
flutter analyze
flutter test
flutter test -d flutter-tester integration_test/fake_flow_test.dart
flutter build apk --debug
flutter build ios --debug --no-codesign
./scripts/check_context_budget.sh
git status --short
```

Expected: all commands pass, Pigeon regeneration is byte-stable, and tracked contents remain clean. The default run must not contact Firebase.

- [ ] **Step 6: Reconcile evaluator documentation with observed evidence**

README must lead with the one-command evaluator path, then clearly mark the owner-only signed cloud command, exact verified devices, App Check/signing relationship, remaining limits, AI use, and rejected suggestions. Remove the obsolete claim that App Check is intentionally inactive. Keep `AGENTS.md` and `docs/PRD.md` below 10 KB.

- [ ] **Step 7: Independent pre-release review and commit**

Request a read-only review over the Firebase base-to-head range. Fix every Critical/Important finding, rerun affected gates, and commit:

```bash
git add README.md docs .superpowers/sdd integration_test
git commit -m "docs(evidence): record signed Firebase verification" \
  -m "What: Record clean-checkout, signed App Check, live cloud, and physical-device evidence with exact limitations. Why: Let evaluators reproduce the simple path and audit cloud claims without exposing private signing material."
```

Do not push or submit; those remain separate user-confirmed actions.
