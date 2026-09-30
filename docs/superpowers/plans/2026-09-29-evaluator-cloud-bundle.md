# Evaluator Cloud Bundle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a clean checkout run the cloud-first ARTINUS OCR flow with one `flutter run` command by tracking only dedicated, revocable assignment credentials, while preserving local OCR recovery and preventing the iOS debug token from entering release output.

**Architecture:** Keep the existing Android app, iOS Runner scheme, and Dart entry point. Change the existing Firebase bootstrap from opt-in to cloud-first by default, select Play Integrity on Android and a committed debug token on iOS debug builds, and retain `ARTINUS_CLOUD_EVIDENCE=false` as the explicit local-only escape hatch. Package only the already-registered Android assignment keystore and a new iOS debug token; enable Firebase AI Logic on Spark, then prove the behavior through focused tests, signed artifacts, clean-clone builds, and physical devices.

**Tech Stack:** Flutter `3.47.5`, Dart `3.13.4`, `firebase_core 4.6.0`, `firebase_ai 3.10.0`, `firebase_app_check 0.4.2`, Android Play Integrity, Apple App Check debug provider, Firebase AI Logic Gemini Developer API, `gemini-3.8-flash`, bundled Google ML Kit Korean OCR.

## Global Constraints

- Keep one Android application, one iOS Runner scheme, one Dart entry point, and no flavor.
- `flutter run -d <device>` is cloud-first without a Dart define; `--dart-define=ARTINUS_CLOUD_EVIDENCE=false` is the explicit local-only path.
- Cloud behavior remains maximum two attempts, a choice at 10 seconds, a cumulative 60-second deadline, stale-result rejection, and sequential local fallback.
- Android uses only the dedicated `artinus-ocr-upload` assignment key whose SHA-256 is already registered for `dev.bongjae.artinusocr`.
- Android App Check must support distribution outside Google Play: `PLAY_RECOGNIZED` and `LICENSED` are not required; device integrity is required.
- iOS uses `AppleDebugProvider` only in debug mode. A release build must neither activate nor contain the registered debug token.
- Track no Gemini Developer API key, service-account JSON, Firebase CLI token, Apple credential/session, `.p12`, provisioning profile, production signing key, billing account, or former-employer asset.
- Firebase project remains `artinus-ocr-bongjae-202609` on Spark with no billing account.
- User-facing failures remain nontechnical and never expose vendor names, exceptions, HTTP status, tokens, or error codes.
- Never print a keystore password or App Check debug token in a command, report, test failure, log, or review response.
- Registering the iOS debug token and enabling Firebase AI Logic are external mutations. Immediately before each final console submit, report the exact project/app/action and obtain action-time user confirmation.
- Do not push, publish, create a public repository, email, or submit the assignment.

---

## File Map

- `lib/bootstrap/evaluator_credentials.dart` — one committed, assignment-only iOS App Check debug token; no other credential class.
- `lib/bootstrap/firebase_cloud_bootstrap.dart` — default-cloud switch and platform/debug-release App Check policy.
- `test/bootstrap/firebase_cloud_bootstrap_test.dart` — default mode, provider selection, blank-token, release guard, ordering, and redaction tests.
- `test/app_smoke_test.dart` — production composition expectation changes from pending-local to cloud-first.
- `integration_test/live_cloud_smoke_test.dart` — uses the production bootstrap so live evidence includes App Check.
- `android/key.properties` — committed assignment-only Gradle signing configuration.
- `android/evaluator-signing/artinus-ocr-upload.jks` — committed assignment-only keystore.
- `.gitignore`, `android/.gitignore` — narrow allowlist exceptions for those exact two Android files only.
- `android/app/build.gradle.kts` — cloud-first default and registered signing for every default evaluator build type.
- `README.md`, `docs/CONTEXT.md`, `docs/AI_PROMPT_LOG.md`, `.superpowers/sdd/progress.md`, `.superpowers/sdd/firebase-cloud-evidence-report.md` — concise evaluator instructions, decision trace, and observed evidence.

---

### Task 1: Make Bootstrap Cloud-First and Guard the Apple Debug Provider

**Files:**
- Create: `lib/bootstrap/evaluator_credentials.dart`
- Modify: `lib/bootstrap/firebase_cloud_bootstrap.dart:1-59`
- Modify: `test/bootstrap/firebase_cloud_bootstrap_test.dart:1-115`
- Modify: `test/app_smoke_test.dart`
- Modify: `integration_test/live_cloud_smoke_test.dart`

**Interfaces:**
- Consumes: committed Firebase options, `AndroidPlayIntegrityProvider`, `AppleDebugProvider`, `FirebaseSdkModelGateway`.
- Produces: `artinusCloudEvidenceEnabled` defaulting to `true`, `selectEvaluatorAppleProvider(...)`, and a live smoke that initializes Firebase/App Check through `createFirebaseModelGateway(...)`.

- [ ] **Step 1: Generate one token without displaying it**

Create a mode-0600 temporary file, write a lowercase UUID with `uuidgen`, and validate it with the UUID regular expression. Do not echo or include the value in captured output. The same exact value is consumed by Step 3 and registered in Task 3.

Expected: one nonblank UUID exists only in the protected temporary file; Firebase has not been mutated.

- [ ] **Step 2: Write RED bootstrap tests**

Add tests equivalent to:

```dart
test('evaluation build is cloud-first by default', () {
  expect(artinusCloudEvidenceEnabled, isTrue);
});

test('iOS debug selects the explicit registered debug token', () {
  final provider = selectEvaluatorAppleProvider(
    isReleaseMode: false,
    debugToken: '11111111-1111-1111-1111-111111111111',
  );
  expect(provider, isA<AppleDebugProvider>());
  expect((provider as AppleDebugProvider).debugToken,
      '11111111-1111-1111-1111-111111111111');
});

test('iOS debug rejects a blank token without exposing it', () {
  expect(
    () => selectEvaluatorAppleProvider(
      isReleaseMode: false,
      debugToken: '   ',
    ),
    throwsA(isA<StateError>()),
  );
});

test('iOS release rejects the debug provider', () {
  expect(
    () => selectEvaluatorAppleProvider(
      isReleaseMode: true,
      debugToken: '11111111-1111-1111-1111-111111111111',
    ),
    throwsA(isA<StateError>()),
  );
});
```

Keep the existing explicit-disabled test and exact initialize → App Check → gateway ordering tests.

Replace the app-smoke composition assertion with:

```dart
test('default production composition is cloud-first', () async {
  final runtime = _RecordingFirebaseCloudRuntime();
  final gateway = await createFirebaseModelGateway(runtime: runtime);
  expect(runtime.calls, <String>[
    'firebase.initialize',
    'appCheck.activate',
    'gateway.create',
  ]);
  expect(gateway, isA<FirebaseSdkModelGateway>());
  expect(gateway.configurationPending, isFalse);
});
```

Run:

```bash
flutter test test/bootstrap/firebase_cloud_bootstrap_test.dart
flutter test test/app_smoke_test.dart
```

Expected: fail because the default is still local-only and the Apple selector does not exist.

- [ ] **Step 3: Add the assignment-only token source**

Using `apply_patch`, create `lib/bootstrap/evaluator_credentials.dart` with one library constant. During execution, substitute the protected Step 1 value into the patch in memory; do not place a placeholder in the file or terminal output:

```dart
// Evaluation-only, revocable Firebase App Check debug credential.
// This is intentionally tracked for take-home build convenience and must not
// be copied into production projects.
const evaluatorIosAppCheckDebugToken = '<value read privately from Step 1>';
```

The angle-bracket expression above describes the patch-time substitution and must not remain in the created Dart file. Validate the resulting literal as a UUID without printing it.

No Firebase, Gemini, Apple, or signing credential may appear in this file.

- [ ] **Step 4: Implement the minimal provider policy**

In `firebase_cloud_bootstrap.dart`, import `package:flutter/foundation.dart` and the credential file. Change the compile-time switch to:

```dart
const artinusCloudEvidenceEnabled = bool.fromEnvironment(
  'ARTINUS_CLOUD_EVIDENCE',
  defaultValue: true,
);
```

Add the pure selector:

```dart
AppleAppCheckProvider selectEvaluatorAppleProvider({
  required bool isReleaseMode,
  required String debugToken,
}) {
  if (isReleaseMode || debugToken.trim().isEmpty) {
    throw StateError('Apple cloud evaluation is unavailable');
  }
  return AppleDebugProvider(debugToken: debugToken);
}
```

Update `activateAppCheck()` to use the nondeprecated provider-class API and branch by platform:

```dart
if (Platform.isAndroid) {
  await FirebaseAppCheck.instance.activate(
    providerAndroid: const AndroidPlayIntegrityProvider(),
  );
  return;
}
if (Platform.isIOS) {
  await FirebaseAppCheck.instance.activate(
    providerApple: selectEvaluatorAppleProvider(
      isReleaseMode: kReleaseMode,
      debugToken: evaluatorIosAppCheckDebugToken,
    ),
  );
}
```

The existing bootstrap catch converts selector/activation failures into `FirebaseConfigurationFailedGateway`; do not log the caught object.

- [ ] **Step 5: Make live smoke exercise the real bootstrap**

Replace direct `Firebase.initializeApp()` plus direct gateway construction in `integration_test/live_cloud_smoke_test.dart` with:

```dart
final gateway = await createFirebaseModelGateway(cloudEvidenceEnabled: true);
expect(gateway.configurationPending, isFalse);

final result = await FirebaseAiOcrService(gateway: gateway).recognize(
  fixture.path,
);
```

Delete the obsolete direct-initialization helper use. Keep metadata-only output and the `RUN_LIVE_OCR` opt-in gate.

- [ ] **Step 6: Make focused tests GREEN**

Run:

```bash
dart format lib/bootstrap test/bootstrap integration_test/live_cloud_smoke_test.dart
flutter test test/bootstrap/firebase_cloud_bootstrap_test.dart
flutter test test/app_smoke_test.dart
flutter test test/features/ocr/application/ocr_flow_controller_test.dart
flutter test -d flutter-tester integration_test/fake_flow_test.dart
```

Expected: all pass; explicit `false` remains direct-local and default composition is cloud-first.

- [ ] **Step 7: Verify no accidental disclosure and commit**

Check that only the intended credential file contains the UUID and no test failure/report/log contains it. Then commit:

```bash
git add lib/bootstrap test integration_test
git commit -m "feat(firebase): default evaluator to cloud App Check" \
  -m "What:
Make the single evaluator target cloud-first, select Play Integrity on Android and the registered debug provider only for iOS debug, and route live smoke through production bootstrap.

Why:
Let reviewers exercise the required cloud OCR flow with one command while preserving an explicit local-only path and fail-closed release behavior."
```

---

### Task 2: Package the Dedicated Android Evaluation Identity

**Files:**
- Modify: `.gitignore`
- Modify: `android/.gitignore`
- Create: `android/key.properties`
- Create: `android/evaluator-signing/artinus-ocr-upload.jks`
- Modify: `android/app/build.gradle.kts:13-120`

**Interfaces:**
- Consumes: the existing external dedicated keystore/password and the registered Firebase SHA-256.
- Produces: default debug/profile/release artifacts signed by the same assignment certificate and `ARTINUS_CLOUD_EVIDENCE=false` as the explicit standard-debug-signed local development escape hatch when credentials are deliberately removed.

- [ ] **Step 1: Resolve and validate the existing key without printing secrets**

Read the ignored `android/key.properties` only inside shell variables, resolve its existing external store, and verify:

- alias is exactly `artinus-ocr-upload`;
- keytool reports RSA 4096;
- the certificate SHA-256 equals the sole registered Firebase Android SHA-256;
- source files are regular files with owner-only permissions.

Expected: all assertions pass and output contains only the public SHA-256, never a password or keystore path outside the repository.

- [ ] **Step 2: Write RED Gradle configuration checks**

In an ASCII-only temporary clone, prove before the change that:

```text
default flutter build apk --debug
```

uses the Android debug certificate, while:

```text
flutter build apk --debug --dart-define=ARTINUS_CLOUD_EVIDENCE=false
```

remains a valid local-only build. Retain the existing partial properties, wrong alias, missing store, and malformed Base64 rejection cases.

Expected: the default-certificate assertion fails RED; local-only succeeds.

- [ ] **Step 3: Copy only the assignment identity and narrow the ignore rules**

Copy the existing dedicated binary key to `android/evaluator-signing/artinus-ocr-upload.jks` without changing it. Recreate `android/key.properties` so `storeFile` is the repository-relative `../evaluator-signing/artinus-ocr-upload.jks`, with the existing assignment password and exact alias.

Append narrow exceptions after the broad ignores:

```gitignore
!android/key.properties
!android/evaluator-signing/
!android/evaluator-signing/artinus-ocr-upload.jks
```

and in `android/.gitignore`:

```gitignore
!key.properties
!evaluator-signing/
!evaluator-signing/artinus-ocr-upload.jks
```

Do not relax ignores for any other `*.jks`, `*.keystore`, `.p12`, or provisioning file.

- [ ] **Step 4: Align Gradle with the Dart default**

Replace the opt-in check with an explicit opt-out default:

```kotlin
val cloudEvidenceValues =
    dartDefines
        .filter { it.startsWith("ARTINUS_CLOUD_EVIDENCE=") }
        .map { it.substringAfter('=') }
if (cloudEvidenceValues.size > 1 ||
    cloudEvidenceValues.any { it != "true" && it != "false" }
) {
    throw GradleException("ARTINUS cloud configuration is invalid")
}
val cloudEvidenceEnabled = cloudEvidenceValues.singleOrNull() != "false"
```

Keep the existing fail-closed property, alias, regular-file, and malformed-Base64 checks. The existing `configureEach` then assigns `registeredRelease` to every default cloud build type.

- [ ] **Step 5: Verify default and local-only artifacts**

In a fresh ASCII-only clone, run:

```bash
flutter pub get
flutter build apk --debug
flutter build apk --release
flutter build apk --debug --dart-define=ARTINUS_CLOUD_EVIDENCE=false
./android/gradlew -p android :app:testDebugUnitTest :app:lintDebug
```

Use `apksigner verify --verbose --print-certs` on default debug and release APKs. Expected: both match the registered public SHA-256. The explicit local-only build succeeds. Re-run invalid-config fixtures and expect the same sanitized failures.

- [ ] **Step 6: Verify tracked credential scope and commit**

Assert that tracked sensitive filenames are exactly the two approved Android files plus `lib/bootstrap/evaluator_credentials.dart`; scan for forbidden private-key/service-account/Firebase-login/Apple-profile material without printing approved values. Commit:

```bash
git add -f .gitignore android/.gitignore android/key.properties \
  android/evaluator-signing/artinus-ocr-upload.jks android/app/build.gradle.kts
git commit -m "build(android): bundle assignment signing identity" \
  -m "What:
Track the dedicated ARTINUS evaluation keystore and signing properties and make default Android evaluator artifacts use its registered Play Integrity identity.

Why:
Remove a separate secret handoff so reviewers can build the cloud-first assignment immediately while containing the exception to a revocable no-billing project."
```

---

### Task 3: Register App Check and Enable Firebase AI Logic

**Files:**
- No source change before remote verification.
- Evidence is added only in Task 4 after the remote state and live behavior are observed.

**Interfaces:**
- Consumes: Firebase project `artinus-ocr-bongjae-202609`, Android app ID `1:867285305627:android:b00b0c0a36bcd8780f6bbe`, iOS app ID `1:867285305627:ios:f03ea9c48ae6ee7a0f6bbe`, the Android registered SHA-256, and the Task 1 UUID.
- Produces: outside-Play Android App Check policy, one registered iOS debug token, enabled Firebase AI Logic through Gemini Developer API on Spark, and enforced App Check for the AI service.

- [ ] **Step 1: Reconfirm safe remote state read-only**

Verify immediately before mutation:

- exact Firebase project/app IDs and package/bundle IDs;
- billing plan remains Spark and no billing account is attached;
- Android Play Integrity is registered with the expected SHA-256;
- iOS has no production provider registration that would be overwritten;
- Firebase AI Logic has not yet been started.

Expected: exact dedicated assignment project only. Stop on any mismatch.

- [ ] **Step 2: Obtain action-time confirmation for the iOS token registration**

Report: “Register one debug token for iOS app `dev.bongjae.artinusocr` in project `artinus-ocr-bongjae-202609`; this grants unverified debug builds App Check access until revoked.” Wait for explicit confirmation immediately before the console submit.

- [ ] **Step 3: Register the exact Task 1 token**

In Firebase Console → App Check → Apps → iOS app → Manage debug tokens, add the exact UUID from the protected file with a label identifying it as the ARTINUS evaluator token. Do not paste it into chat, screenshots, logs, or reports.

Expected: exactly one evaluator debug token is listed; the token value is not displayed in evidence.

- [ ] **Step 4: Obtain action-time confirmation and configure Android for outside-Play evaluation**

Report the exact Android advanced-setting change and wait for confirmation immediately before the console save.

In the Android Play Integrity advanced settings, set:

```text
PLAY_RECOGNIZED: not required
LICENSED: not required
minimum device integrity: device integrity
```

Expected: an APK installed outside Google Play can attest on a compatible physical Android device while emulator/untrusted-device access remains rejected.

- [ ] **Step 5: Obtain action-time confirmation and enable Firebase AI Logic**

Report the exact mutation: start Firebase AI Logic for the dedicated project using Gemini Developer API free tier, keep Spark/no billing, and accept automatic App Check enforcement. Wait for explicit confirmation immediately before the final setup action.

Choose Gemini Developer API, do not link billing, do not create or expose a Gemini API key, and do not enable AI monitoring if it introduces unrelated observability/billing scope.

- [ ] **Step 6: Verify model, authorization, enforcement, and billing**

Confirm from official current UI/docs and the project console:

- `gemini-3.8-flash` is supported and billing is not required;
- Firebase AI Logic uses the Firebase-managed authorization path rather than a client Gemini key;
- App Check is enforced for Firebase AI Logic;
- project remains Spark with no billing account;
- no unrelated API, database, authentication, storage, analytics, or App Store resource was enabled.

Expected: all pass. If the model or free tier differs, stop and return to design rather than silently substituting another model or adding billing.

---

### Task 4: Prove Live Cloud, Fallback, and Release Containment

**Files:**
- Modify only if a test defect is found: `integration_test/live_cloud_smoke_test.dart`
- Modify: `README.md`
- Modify: `docs/CONTEXT.md`
- Modify: `docs/AI_PROMPT_LOG.md`
- Modify: `.superpowers/sdd/progress.md`
- Create: `.superpowers/sdd/firebase-cloud-evidence-report.md`

**Interfaces:**
- Consumes: Tasks 1–3 and available physical Android/iPhone devices.
- Produces: reproducible one-command evaluator instructions and truthful platform/cloud evidence.

- [ ] **Step 1: Run the full automated regression**

In an ASCII-only clone at the task HEAD:

```bash
flutter pub get
dart run pigeon --input pigeons/platform_apis.dart
git diff --exit-code
flutter analyze
flutter test
flutter test -d flutter-tester integration_test/fake_flow_test.dart
flutter build apk --debug
./android/gradlew -p android :app:testDebugUnitTest :app:lintDebug
flutter build apk --release
flutter build ios --debug --no-codesign
flutter build ios --release --no-codesign
./scripts/check_context_budget.sh
```

Expected: all pass; generated Pigeon output and tracked dependency locks remain unchanged.

- [ ] **Step 2: Prove release token absence**

Search the iOS release `Runner` executable/app bundle and Android release artifacts for the exact Task 1 UUID without printing it. Also search for the source identifier `evaluatorIosAppCheckDebugToken` where meaningful.

Expected: UUID absent from iOS release output. If present, stop: move token injection to an Apple Debug-only build setting before any delivery claim.

- [ ] **Step 3: Run Android live cloud evidence**

On a compatible physical Android device, run the normal command with no cloud define:

```bash
flutter run -d <android-device-id>
```

Verify preview → capture → cloud Korean/Latin result, explicit no-readable-text, one transient retry, `1/2` and `2/2`, 10-second `기기에서 인식`/`조금 더 기다리기`, 60-second terminal recovery, manual local fallback, offline local recognition, permission/settings, background/resume, rotation, rapid taps, flash gate, bad input, and ten capture cycles. Record only commit, model, device, OS, build mode, domain outcome, timings, memory/frame/heat observations, and artifact paths.

Run the live smoke through the production bootstrap:

```bash
flutter test integration_test/live_cloud_smoke_test.dart -d <android-device-id> \
  --dart-define=RUN_LIVE_OCR=true \
  --dart-define=OCR_DEVICE=<public-device-model> \
  --dart-define=OCR_GIT_COMMIT=$(git rev-parse HEAD)
```

Expected: App Check token accepted and nonblank OCR result; no image, text, path, raw response, or credential in output.

- [ ] **Step 4: Run iPhone debug evidence**

With the evaluator/borrowed iPhone signed by an authorized Personal Team, run the same matrix and live smoke in debug mode. Do not reuse or select the former-employer team/profile. Record the Personal Team only as “Personal Team” unless the user explicitly approves exposing its identifier.

Expected: registered debug token accepted, cloud and bundled local OCR both work, and platform parity claims are limited to observed cases. If no iPhone is available, mark this gate blocked rather than inferring from Android or simulator results.

- [ ] **Step 5: Verify the explicit local-only escape hatch**

Run on at least Android:

```bash
flutter run -d <android-device-id> \
  --dart-define=ARTINUS_CLOUD_EVIDENCE=false
```

Expected: no Firebase initialization, App Check activation, cloud preparation, timer, or cloud request; capture proceeds directly to bundled local OCR.

- [ ] **Step 6: Reconcile evaluator documentation**

Update README first-run text to lead with:

```bash
flutter pub get
flutter run -d <android-or-ios-device>
```

Immediately state that the repository intentionally includes revocable assignment-only Android signing material and an iOS debug App Check token solely to reduce take-home build setup. State that this is not production credential handling, iOS release excludes the token, the Firebase project is Spark/no-billing, and credentials are revoked after evaluation.

Remove obsolete claims that Firebase is unconfigured, identifiers remain `com.example`, or default flow is local-only. Preserve exact unverified device gates. Update `docs/CONTEXT.md` without exceeding 10 KB and append only observed decisions/evidence to `docs/AI_PROMPT_LOG.md`.

- [ ] **Step 7: Run independent two-persona review**

Review the final range as:

- HR/recruiter: setup friction, immediate assignment behavior, concise trade-off explanation, credibility, and red flags;
- hiring manager/development lead: secret scope, App Check enforcement, release-token absence, one-target architecture, fallback correctness, tests, and reproducibility.

Record overall, HR, and hiring-manager scores out of 100 plus the top three fixes. Fix all Critical/Important findings and rerun affected gates.

- [ ] **Step 8: Commit verified handoff evidence**

```bash
git add AGENTS.md README.md docs integration_test scripts
git add -u .superpowers/sdd
git add -f .superpowers/sdd/firebase-cloud-evidence-report.md
ALLOW_DOCS_ONLY=1 \
DOCS_ONLY_REASON='Record verified evaluator cloud and release evidence' \
git commit -m "docs(evidence): verify evaluator cloud bundle" \
  -m "What:
Document the one-command cloud build, assignment-only credential exception, App Check and Firebase AI Logic state, clean-clone checks, live device results, release containment, and remaining gates.

Why:
Give reviewers a reproducible handoff while keeping every security and platform claim tied to observed evidence."
```

Do not push or submit. Credential revocation happens after the evaluation window, not before reviewers can run the project.

## Hiring-Perspective Plan Review

Overall plan-readiness score: **92/100**.

- **HR / recruiter: 91/100.** The plan prioritizes a one-command reviewer experience, exposes the credential exception honestly, and preserves a usable local fallback. The remaining presentation risk is overexplaining security mechanics in the final README; Task 4 must keep the evaluator summary concise.
- **Hiring manager / development lead: 93/100.** The plan has explicit TDD boundaries, provider and build-mode separation, clean-clone proof, release-token scanning, App Check enforcement checks, and truthful device gates. The principal red flag is the intentionally tracked signing/debug material; approval depends on proving dedicated scope, Spark/no-billing, release containment, and post-evaluation revocation.

Highest-leverage checks:

1. Prove the iOS token is absent from release output rather than relying on source-level `kReleaseMode` reasoning.
2. Prove default Android artifacts use the registered certificate and work outside Google Play on a physical device.
3. Keep every live/cloud claim tied to a dated device/build result and mark unavailable iPhone evidence as blocked.

## Sources

- [Firebase App Check debug provider for Flutter](https://firebase.google.com/docs/app-check/flutter/debug-provider)
- [Firebase App Check Play Integrity for apps distributed outside Google Play](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [Firebase AI Logic Flutter getting started](https://firebase.google.com/docs/ai-logic/get-started?api=dev&platform=flutter)
- [Firebase AI Logic supported models](https://firebase.google.com/docs/ai-logic/models)
- [Firebase AI Logic pricing and Spark free tier](https://firebase.google.com/docs/ai-logic/pricing)
- [Firebase API-key guidance](https://firebase.google.com/docs/projects/api-keys)
