# Altinus Camera OCR Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and verify a Flutter Android/iOS app that captures a still image, performs Firebase AI OCR with official on-device ML Kit fallback, and displays a truthful, recoverable result without blocking the UI.

**Architecture:** A manual Riverpod `NotifierProvider` owns one OCR transaction and immutable UI state. Camera, cloud OCR, image preparation, disclosure persistence, temporary-file cleanup, settings navigation, and Pigeon-backed local OCR sit behind focused ports. Automated tests establish state/UI behavior; separate Android and iPhone profile-mode runs establish native camera, bridge, performance, memory, and heat evidence.

**Tech Stack:** Flutter `3.47.5`, Dart `3.13.4`, `camera 0.12.1`, `flutter_riverpod 3.4.3`, `firebase_core 4.6.0`, `firebase_ai 3.10.0`, Pigeon `29.0.4`, Android ML Kit Korean `16.0.1`, iOS `GoogleMLKit/TextRecognitionKorean 8.0.0`, Flutter test/integration_test, Google ARTEMIS, Flutter DevTools.

## Global Constraints

- Support Android API 24+ and iOS 15.5+; leave Xcode at `26.1.1`.
- Use official camera, Firebase AI Logic, and native ML Kit SDKs; no community Flutter ML Kit wrapper.
- Do not wire or enforce App Check in the evaluation build; document this as a production abuse-protection trade-off.
- Use manual Riverpod providers; no Riverpod annotations or `build_runner`.
- Do not add Dio while there is no direct endpoint; never implement raw `dart:io HttpClient` networking.
- Rear camera only. Ship auto/off flash only after both-platform real-device proof; otherwise remove it.
- One active transaction, at most two cloud attempts, a 10-second choice, and one cumulative 60-second budget starting before image preparation.
- Never parse exception messages to infer status. Never log images, OCR text, raw model responses, credentials, or local image paths.
- Result display only; no edit, copy, gallery, history, translation, authentication, analytics, or custom backend.
- Keep `AGENTS.md` and `docs/PRD.md` below 10 KB. Android evidence never substitutes for iOS evidence.
- Before each Dart-bearing commit, run `dart format` on changed Dart files and rerun the focused tests shown in that task.
- Never create a remote, push, email, or submit without a fresh user request and action-time safety checks.
- Every commit uses Conventional Commits with meaningful `What:` and `Why:` sections.

## Files and ownership

```text
lib/main.dart, lib/app.dart, pubspec.yaml         main agent shared ownership
lib/features/ocr/domain/                         SDK-free contracts
lib/features/ocr/application/                    state/controller/providers
lib/features/ocr/data/                           Firebase, preparation, files, Pigeon adapters
lib/features/ocr/presentation/                   state-driven screens and copy
lib/features/camera/                             camera port, adapter, preview surface
lib/features/disclosure/                         first-run persistence
pigeons/platform_apis.dart                        generator source and output configuration
lib/src/generated/platform_apis.g.dart            generated; never hand-edit
android/.../PlatformApis.g.kt                      generated; never hand-edit
ios/Runner/PlatformApis.g.swift                    generated; never hand-edit
test/                                             unit/widget tests mirroring lib
integration_test/                                 fake-flow and real bridge smoke tests
docs/evidence/                                    created only from verified runs
```

Dependency order: Task 1 → Task 2 → Task 3 → Task 4. After Task 3, Tasks 6, 7, and 8 may use disjoint files in parallel; Task 5 waits for Task 4. Tasks 9 and 10 wait for Task 8 and may run in parallel worktrees. Tasks 11–13 are sequential integration gates.

---

### Task 1: Reconcile stale execution context (D0)

**Files:**
- Modify: `docs/PRD.md`, `docs/CONTEXT.md`, `docs/E2E_TESTING.md`, `docs/AI_PROMPT_LOG.md`
- Inspect; modify only on confirmed drift: `AGENTS.md`, `.agents/catalog.yaml`

**Interfaces:**
- Consumes: approved design spec.
- Produces: one current execution context for every worker.

- [ ] **Step 1: Capture the expected drift**

```bash
rg -n 'Flutter or React Native|selectable/copyable|3\.41\.6|3\.11\.4|implementation stack is not yet committed|Decisions still required' docs/PRD.md docs/CONTEXT.md
```

Expected: matches proving superseded assumptions remain.

- [ ] **Step 2: Reconcile only approved facts**

Update the existing files in place with this exact ledger:

```text
Flutter 3.47.5 / Dart 3.13.4; result display only
firebase_ai cloud first; official Korean ML Kit through Pigeon fallback
manual Riverpod NotifierProvider; no code generation
10-second choice; cumulative 60-second cloud budget; at most two attempts
Android iterative device; borrowed iPhone required for final real-device proof
clean clone, fixed inputs, cloud/local, Pigeon, frames, memory, and heat evidence
```

Correct Android permission wording to the states exposed by the official camera package. Preserve source priority and append-only AI history.

- [ ] **Step 3: Run the D0 gates**

```bash
scripts/check_context_budget.sh
ruby -e "require 'yaml'; c=YAML.load_file('.agents/catalog.yaml'); a=c.fetch('agents'); abort unless %w[file_finder solution_planner flutter_task_executor].all? { |k| a.key?(k) }; abort if a.key?('flutter_implementer')"
! rg -n 'selectable/copyable|3\.41\.6|3\.11\.4|implementation stack is not yet committed' docs/PRD.md docs/CONTEXT.md
git diff --check
```

Expected: budget lines print `OK`; remaining commands exit 0.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md .agents/catalog.yaml docs/PRD.md docs/CONTEXT.md docs/E2E_TESTING.md docs/AI_PROMPT_LOG.md
ALLOW_DOCS_ONLY=1 DOCS_ONLY_REASON='Align execution context with the approved OCR design before implementation' git commit -m 'docs(context): align OCR execution rules' -m 'What:
- Reconcile stack, flow, timing, result scope, and evidence guidance.
- Verify agent roles and context budgets.

Why:
- Prevent stale bootstrap assumptions from driving contradictory implementation.'
```

### Task 2: Scaffold Flutter and lock shared dependencies

**Files:**
- Create/modify: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `lib/main.dart`, `lib/app.dart`, `test/app_smoke_test.dart`
- Create/modify: generated `android/` and `ios/` projects

**Interfaces:**
- Produces: package `altinus_ocr`, Android API 24/iOS 15.5 targets, dependency lock, and `AltinusOcrApp`.

- [ ] **Step 1: Generate only mobile targets**

```bash
flutter create --empty --platforms=android,ios --org com.example --project-name altinus_ocr .
```

- [ ] **Step 2: Pin direct dependencies; do not add Dio**

```yaml
environment:
  sdk: ^3.13.0
dependencies:
  flutter: {sdk: flutter}
  camera: 0.12.1
  firebase_ai: 3.10.0
  firebase_core: 4.6.0
  flutter_riverpod: 3.4.3
  image: 4.10.1
  path: 1.9.1
  path_provider: 2.1.6
  shared_preferences: 2.5.5
dev_dependencies:
  flutter_test: {sdk: flutter}
  integration_test: {sdk: flutter}
  fake_async: 1.3.3
  flutter_lints: 6.0.0
  pigeon: 29.0.4
```

Set Android `minSdk = 24`, Podfile/iOS deployment target `15.5`, and Korean `NSCameraUsageDescription`.

- [ ] **Step 3: Write and observe the failing smoke test**

```dart
import 'package:altinus_ocr/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('boots the assignment shell', (tester) async {
    await tester.pumpWidget(const AltinusOcrApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byKey(const ValueKey('ocr-shell')), findsOneWidget);
  });
}
```

Run `flutter test test/app_smoke_test.dart`; expect missing `AltinusOcrApp`.

- [ ] **Step 4: Add minimum composition**

```dart
// lib/main.dart
import 'package:altinus_ocr/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() => runApp(const ProviderScope(child: AltinusOcrApp()));
```

```dart
// lib/app.dart
import 'package:flutter/material.dart';

class AltinusOcrApp extends StatelessWidget {
  const AltinusOcrApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: SizedBox.expand(key: ValueKey('ocr-shell'))),
  );
}
```

- [ ] **Step 5: Verify and commit**

```bash
flutter pub get
flutter test test/app_smoke_test.dart
flutter analyze
flutter build apk --debug
flutter build ios --debug --no-codesign
git diff --check
git add pubspec.yaml pubspec.lock analysis_options.yaml lib test android ios .gitignore
git commit -m 'build(app): scaffold mobile OCR targets' -m 'What:
- Create pinned Flutter Android/iOS foundations and a ProviderScope app shell.
- Set platform floors and camera permission text.

Why:
- Establish a reproducible build before behavior or plugin integration.'
```

### Task 3: Define SDK-free contracts and immutable states

**Files:**
- Create: `lib/features/ocr/domain/{ocr_engine,ocr_result,ocr_failure,ocr_ports}.dart`
- Create: `lib/features/camera/{camera_models,camera_repository}.dart`
- Create: `lib/features/disclosure/disclosure_store.dart`
- Create: `lib/features/ocr/application/ocr_flow_state.dart`
- Test: `test/features/ocr/domain/ocr_result_test.dart`, `test/features/ocr/application/ocr_flow_state_test.dart`

**Interfaces:**
- Produces: OCR/camera/storage/settings ports and exhaustive flow states with no SDK types.

- [ ] **Step 1: Write failing invariant tests**

```dart
test('text result rejects blank text', () {
  expect(() => OcrResult.textDetected('  \n'), throwsArgumentError);
});
test('only explicit transport failure retries', () {
  expect(OcrFailure.transportTransient().isRetryable, isTrue);
  expect(OcrFailure.quota().isRetryable, isFalse);
  expect(OcrFailure.invalidResponse().isRetryable, isFalse);
});
```

Run the test and expect missing-type failures.

- [ ] **Step 2: Add result/failure contracts**

```dart
enum OcrEngine { cloud, local }
sealed class OcrResult {
  const OcrResult();
  factory OcrResult.textDetected(String text) {
    if (text.trim().isEmpty) throw ArgumentError.value(text, 'text');
    return TextDetected(text);
  }
  const factory OcrResult.noReadableText() = NoReadableText;
}
final class TextDetected extends OcrResult { const TextDetected(this.text); final String text; }
final class NoReadableText extends OcrResult { const NoReadableText(); }

enum OcrFailureKind { transportTransient, quota, configuration, unsupportedLocation, service, safetyOrRecitation, invalidResponse, deadline, bridge, recognizer, invalidInput, preparation, stale }
final class OcrFailure implements Exception {
  const OcrFailure._(this.kind, this.isRetryable);
  final OcrFailureKind kind;
  final bool isRetryable;
  factory OcrFailure.transportTransient() => const OcrFailure._(OcrFailureKind.transportTransient, true);
  factory OcrFailure.quota() => const OcrFailure._(OcrFailureKind.quota, false);
  factory OcrFailure.invalidResponse() => const OcrFailure._(OcrFailureKind.invalidResponse, false);
  factory OcrFailure.of(OcrFailureKind kind) => OcrFailure._(kind, kind == OcrFailureKind.transportTransient);
}
```

- [ ] **Step 3: Add exact port signatures**

```dart
abstract interface class CloudOcrService { Future<OcrResult> recognize(String imagePath); }
abstract interface class LocalOcrService { Future<OcrResult> recognize(String imagePath); }
abstract interface class ImagePreparer { Future<PreparedImage> prepare(String canonicalPath); }
abstract interface class TransactionFiles { Future<void> cleanup(Iterable<String> paths); Future<void> cleanupOrphans(); }
abstract interface class AppSettingsLauncher { Future<bool> open(); }
abstract interface class DisclosureStore { Future<bool> hasAccepted(); Future<void> accept(); }
final class PreparedImage { const PreparedImage({required this.canonicalPath, required this.cloudPath}); final String canonicalPath; final String cloudPath; }
```

```dart
enum CameraPermissionState { granted, denied, restrictedOrNoPrompt }
enum CameraFlashMode { auto, off }
final class CapturedImage { const CapturedImage(this.path); final String path; }
abstract interface class CameraRepository {
  Future<CameraPermissionState> initialize();
  Future<CapturedImage> capture();
  Future<bool> supportsFlash();
  Future<void> setFlash(CameraFlashMode mode);
  Future<void> dispose();
}
```

- [ ] **Step 4: Add exhaustive states**

Implement `Booting`, `DisclosureRequired`, `CameraInitializing`, `PermissionDenied`, `PreviewReady`, `Capturing`, `RecognizingCloud`, `CloudRecovery`, `RecognizingLocal`, `OcrSuccess`, `OcrEmpty`, and `RecoverableError`. `RecognizingCloud` contains `transactionId`, `attempt`, `takingLonger`, and `startedAt`; result states contain `OcrEngine`. Test construction and an exhaustive switch.

- [ ] **Step 5: Verify and commit**

```bash
flutter test test/features/ocr/domain test/features/ocr/application/ocr_flow_state_test.dart
flutter analyze lib/features test/features
git add lib/features test/features
git commit -m 'feat(domain): define OCR flow contracts' -m 'What:
- Add SDK-independent OCR, camera, persistence, settings, and immutable state contracts.
- Enforce nonblank results and conservative retry classification.

Why:
- Give controller and platform adapters one compile-time boundary.'
```

### Task 4: Implement the transaction controller with fake-clock tests

**Files:**
- Create: `lib/features/ocr/application/ocr_flow_controller.dart`, `lib/features/ocr/application/ocr_providers.dart`
- Create: `test/support/ocr_fakes.dart`
- Test: `test/features/ocr/application/ocr_flow_controller_test.dart`

**Interfaces:**
- Consumes: Task 3 ports/states.
- Produces: `ocrFlowControllerProvider` and `start`, `acceptDisclosure`, `capture`, `keepWaiting`, `useLocalOcr`, `recapture`, `openSettings`, `onInactive`, `onResumed`.

- [ ] **Step 1: Create completer-controlled fakes and failing tests**

`test/support/ocr_fakes.dart` provides controllable cloud/local services, a camera with capture count, in-memory disclosure, recording cleanup/settings, and identity preparation. Use `fakeAsync`, `flushMicrotasks`, and an active `ProviderContainer.listen` subscription so the auto-dispose provider remains alive while asserting:

```text
unaccepted -> DisclosureRequired; accepted -> PreviewReady
two rapid captures -> one camera capture
9.999s -> takingLonger false; 10.000s -> true without new attempt
keepWaiting -> same transaction ID/request/attempt
retryable first failure -> attempt 2 after bounded backoff
nonretryable first failure -> CloudRecovery after one call
retry does not reset original 60s deadline
59.999s active; 60.000s invalidated deadline recovery
local selection invalidates cloud; late cloud completion is ignored
recapture/dispose cleans each recorded transaction file once
```

Run `flutter test test/features/ocr/application/ocr_flow_controller_test.dart`; expect a missing controller/provider failure.

- [ ] **Step 2: Add the manual provider and owned transaction fields**

```dart
final ocrFlowControllerProvider =
    NotifierProvider<OcrFlowController, OcrFlowState>(
      OcrFlowController.new,
      isAutoDispose: true,
    );

class OcrFlowController extends Notifier<OcrFlowState> {
  Timer? _slowTimer;
  Timer? _deadlineTimer;
  int _nextTransactionId = 0;
  int? _activeTransactionId;
  final Set<String> _transactionPaths = {};

  @override
  OcrFlowState build() {
    ref.onDispose(_disposeOwnedResources);
    return const Booting();
  }
}
```

Dependencies come from explicit providers overridden by tests. SDK implementations never appear in this file.

- [ ] **Step 3: Implement guarded orchestration**

After capture, allocate one ID, record the canonical path, enter `RecognizingCloud`, start 10/60-second timers before preparation, then prepare/call cloud. Before every state write require the ID to remain active. Retry only `isRetryable` once; backoff recreates neither timer. `keepWaiting` changes no timer, ID, attempt, or request. Local selection invalidates cloud before calling the local port. Cleanup cancels timers, invalidates the ID, and deletes only recorded paths.

- [ ] **Step 4: Verify and commit**

```bash
flutter test test/features/ocr/application/ocr_flow_controller_test.dart
flutter analyze lib/features/ocr/application test/features/ocr/application test/support/ocr_fakes.dart
git add lib/features/ocr/application test/features/ocr/application test/support/ocr_fakes.dart
git commit -m 'feat(flow): orchestrate bounded OCR transactions' -m 'What:
- Add debounce, retry, 10-second choice, 60-second deadline, fallback, cleanup, and stale-result protection.
- Add deterministic timing and concurrency tests.

Why:
- Prevent asynchronous completions from freezing or corrupting the active flow.'
```

### Task 5: Add disclosure and state-driven UI

**Files:**
- Create: `lib/features/disclosure/shared_preferences_disclosure_store.dart`
- Create: `lib/features/ocr/presentation/ocr_copy.dart`, `lib/features/ocr/presentation/ocr_screen.dart`
- Modify: `lib/app.dart`
- Test: `test/features/disclosure/shared_preferences_disclosure_store_test.dart`, `test/features/ocr/presentation/ocr_screen_test.dart`

**Interfaces:**
- Consumes: Task 4 actions/state.
- Produces: first-run disclosure and an exhaustive state-to-screen/action mapping.

- [ ] **Step 1: Write failing widget tests**

Assert exact behavior for disclosure; permission retry/settings; preview capture; `1/2` and `2/2`; 10-second local/wait actions; cloud result with local alternative; local result without cloud loop; cloud empty with recapture/local; and natural errors containing none of `Firebase`, `Gemini`, `ML Kit`, `Pigeon`, `HTTP`, or numeric error codes.

- [ ] **Step 2: Implement first-run persistence**

Use key `disclosure.camera_cloud.v1`. Missing means false; `accept` writes true. Tests use `SharedPreferences.setMockInitialValues`.

- [ ] **Step 3: Implement one exhaustive UI switch**

`OcrScreen` is a `ConsumerStatefulWidget`; buttons call controller actions only. Add keys `disclosure-accept`, `capture`, `use-local`, `keep-waiting`, `recapture`, and `open-settings`. The disclosure says camera purpose, cloud transfer, and no persistent local image storage. Do not import Firebase, Pigeon, or camera SDK types.

- [ ] **Step 4: Verify and commit**

```bash
flutter test test/features/disclosure test/features/ocr/presentation
flutter analyze lib/features/disclosure lib/features/ocr/presentation lib/app.dart
git add lib/app.dart lib/features/disclosure lib/features/ocr/presentation test/features/disclosure test/features/ocr/presentation
git commit -m 'feat(ui): render recoverable OCR states' -m 'What:
- Add first-run disclosure persistence and state-driven preview, processing, result, empty, and recovery screens.
- Test counters, slow-response choices, and user-safe copy.

Why:
- Expose every required recovery without leaking technical details.'
```

### Task 6: Integrate official camera and lifecycle ownership

**Files:**
- Create: `lib/features/camera/camera_plugin_repository.dart`, `lib/features/camera/camera_preview_surface.dart`
- Modify: `lib/features/ocr/application/ocr_providers.dart`, `lib/features/ocr/presentation/ocr_screen.dart`
- Test: `test/features/camera/camera_plugin_repository_test.dart`, `test/features/camera/camera_lifecycle_test.dart`

**Interfaces:**
- Produces: rear-camera initialization, mapped permission/capture errors, still capture, provisional auto/off flash, preview, dispose/resume.

- [ ] **Step 1: Write failing tests around an injectable camera facade**

Cover rear-camera preference, no camera, `CameraAccessDenied`, iOS no-prompt/restricted codes, capture failure, duplicate capture, flash support, dispose on inactive, and reinitialize on resumed.

- [ ] **Step 2: Implement adapter and isolated preview**

`CameraPluginRepository` is the only repository importing `package:camera`; use `ResolutionPreset.high`, `enableAudio: false`, and JPEG capture. `CameraPreviewSurface` is the only widget importing `CameraPreview`. OCR UI embeds the surface without reading `CameraController`.

- [ ] **Step 3: Connect lifecycle and verify**

Forward inactive/resumed states to the controller. Ignore capture callbacks after ownership is disposed.

```bash
flutter test test/features/camera test/features/ocr/presentation
flutter analyze lib/features/camera lib/features/ocr
flutter build apk --debug
flutter build ios --debug --no-codesign
git add lib/features/camera lib/features/ocr test/features/camera
git commit -m 'feat(camera): add lifecycle-safe still capture' -m 'What:
- Integrate official rear-camera preview/capture behind a tested adapter.
- Own permission mapping, lifecycle, debounce, and provisional flash.

Why:
- Meet native camera requirements without leaking plugin state or resources.'
```

### Task 7: Add bounded preparation and Firebase AI OCR

**Files:**
- Create: `lib/features/ocr/data/image_preparer.dart`, `temp_image_store.dart`, `firebase_ai_ocr_service.dart`
- Modify: `lib/main.dart`, `lib/features/ocr/application/ocr_providers.dart`
- Generate after authorized project selection: `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- Test: `test/features/ocr/data/{image_preparer,temp_image_store,firebase_ai_ocr_service}_test.dart`

**Interfaces:**
- Produces: off-UI-thread preparation, strict structured parsing, public-exception mapping, and prefixed cleanup.

- [ ] **Step 1: Write failing service/file tests**

Inject a `FirebaseModelGateway`. Test nonblank `textDetected`, explicit `noReadableText`, line preservation, blank/missing/unknown/contradictory invalid responses, public quota/config/location/safety/SDK errors, explicit transient transport, generic nonretryable server error, prefixed cleanup, and an over-14-MiB input resized proportionally while preserving the canonical path.

- [ ] **Step 2: Implement strict model configuration**

Use `gemini-3.8-flash`, low thinking, JSON MIME type, and schema fields `status` (`textDetected`/`noReadableText`) and `text`. Prompt for visible transcription with original line breaks; forbid guessing, correction, translation, and summary. Use `InlineDataPart`. Do not use Dio or parse message strings.

- [ ] **Step 3: Implement preparation/cleanup**

Inspect orientation and size off the UI thread. Return the canonical path unchanged when its orientation is already usable and it is at most 14 MiB. Otherwise use `Isolate.run` to bake EXIF orientation and/or proportionally resize and encode a derivative below 14 MiB so transport overhead stays inside the documented 20 MB limit. Use prefix `altinus_ocr_`; preserve canonical capture through retry/fallback and delete only owned files at flow end/startup orphan cleanup.

- [ ] **Step 4: Configure only an authorized Firebase project**

```bash
dart pub global activate flutterfire_cli
flutterfire configure --platforms=android,ios --out=lib/firebase_options.dart
```

If no authorized evaluation project exists, stop and request the user’s choice. Do not create billing or change App Check by assumption. Initialize Firebase with generated options before `runApp`.

Verify that `gemini-3.8-flash` is available to that project on the no-billing/free path before committing. If model or quota access fails, stop and report the exact official/console evidence; do not silently enable billing or substitute a model.

- [ ] **Step 5: Verify and commit**

```bash
flutter test test/features/ocr/data
flutter analyze lib/features/ocr/data lib/main.dart
flutter build apk --debug
flutter build ios --debug --no-codesign
git add lib/main.dart lib/firebase_options.dart lib/features/ocr/data lib/features/ocr/application/ocr_providers.dart test/features/ocr/data android ios pubspec.lock
git commit -m 'feat(ocr): add bounded Firebase recognition' -m 'What:
- Add isolated image preparation, strict Firebase parsing, conservative failure mapping, and cleanup.
- Configure the authorized mobile Firebase project without custom HTTP.

Why:
- Provide cloud OCR while bounding UI, memory, size, privacy, and malformed-response risks.'
```

### Task 8: Generate typed Pigeon contracts

**Files:**
- Create: `pigeons/platform_apis.dart`
- Generate: `lib/src/generated/platform_apis.g.dart`
- Generate: `android/app/src/main/kotlin/com/example/altinus_ocr/PlatformApis.g.kt`
- Generate: `ios/Runner/PlatformApis.g.swift`
- Create: `lib/features/ocr/data/pigeon_local_ocr_service.dart`, `pigeon_app_settings_launcher.dart`
- Test: `test/features/ocr/data/pigeon_adapters_test.dart`

**Interfaces:**
- Produces: async `NativeOcrHostApi.recognizeKorean(String)` on a serial background task queue and platform-thread `AppSettingsHostApi.open()` plus Dart adapters.

- [ ] **Step 1: Define the generator source**

```dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/generated/platform_apis.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/com/example/altinus_ocr/PlatformApis.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.altinus_ocr'),
    swiftOut: 'ios/Runner/PlatformApis.g.swift',
  ),
)
enum NativeOcrStatus { textDetected, noReadableText }
class NativeOcrReply {
  NativeOcrReply({required this.status, this.text});
  NativeOcrStatus status;
  String? text;
}
@HostApi()
abstract class NativeOcrHostApi {
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  @asyncCallback
  NativeOcrReply recognizeKorean(String imagePath);
}
@HostApi()
abstract class AppSettingsHostApi {
  @asyncCallback
  bool open();
}
```

- [ ] **Step 2: Generate and prove stable output**

```bash
dart run pigeon --input pigeons/platform_apis.dart
git add pigeons lib/src/generated/platform_apis.g.dart android/app/src/main/kotlin/com/example/altinus_ocr/PlatformApis.g.kt ios/Runner/PlatformApis.g.swift
dart run pigeon --input pigeons/platform_apis.dart
git diff --exit-code -- lib/src/generated/platform_apis.g.dart android/app/src/main/kotlin/com/example/altinus_ocr/PlatformApis.g.kt ios/Runner/PlatformApis.g.swift
```

Expected: regeneration produces no unstaged diff. Never hand-edit generated output.

- [ ] **Step 3: Test and implement Dart mapping**

Define app-owned `NativeOcrGateway` and `SettingsGateway` interfaces implemented by thin wrappers around generated APIs. Inject fakes for text, empty, blank-text contradiction, bridge error, and settings boolean. Map these to `TextDetected`, `NoReadableText`, `invalidResponse`, `bridge`, and the returned boolean respectively. Task 11 exercises the actual generated channel.

- [ ] **Step 4: Verify and commit**

```bash
flutter test test/features/ocr/data/pigeon_adapters_test.dart
flutter analyze lib/features/ocr/data lib/src/generated test/features/ocr/data
git add pigeons lib/src/generated lib/features/ocr/data/pigeon_local_ocr_service.dart lib/features/ocr/data/pigeon_app_settings_launcher.dart android/app/src/main/kotlin/com/example/altinus_ocr/PlatformApis.g.kt ios/Runner/PlatformApis.g.swift test/features/ocr/data/pigeon_adapters_test.dart
git commit -m 'feat(native): generate typed OCR contracts' -m 'What:
- Generate Pigeon APIs for Korean OCR and settings navigation.
- Add tested Dart mappings for typed native replies.

Why:
- Remove handwritten channel names and make native boundaries reproducible.'
```

### Task 9: Implement Android bundled ML Kit and settings

**Files:**
- Modify: `android/app/build.gradle.kts`, `android/app/src/main/kotlin/com/example/altinus_ocr/MainActivity.kt`
- Create: `android/app/src/main/kotlin/com/example/altinus_ocr/MlKitNativeOcrHostApi.kt`, `AndroidAppSettingsHostApi.kt`

**Interfaces:**
- Consumes: Task 8 generated Kotlin interfaces.
- Produces: bundled Korean OCR `16.0.1` and app-details settings intent.

- [ ] **Step 1: Pin the native dependency**

```kotlin
dependencies {
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
}
```

- [ ] **Step 2: Implement async OCR exactly at the host boundary**

Reject a missing/non-file path and load `InputImage.fromFilePath` on the generated serial background task queue. Use `KoreanTextRecognizerOptions.Builder().build()` and asynchronous `process`. Blank `Text.text` becomes `NO_READABLE_TEXT`; nonblank text is returned unchanged. Return errors through an exactly-once generated callback, close the recognizer once on completion, and contain callback exceptions. Never log path or text.

- [ ] **Step 3: Implement settings and register hosts**

Open `Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null))`. In `configureFlutterEngine`, register both generated host APIs against `engine.dartExecutor.binaryMessenger`. In `cleanUpFlutterEngine`, unregister both handlers, clear retained host references, and then call `super`.

- [ ] **Step 4: Verify and commit**

The app remains compiled for Java 17 (`sourceCompatibility`, `targetCompatibility`, and Kotlin `jvmTarget`). Run the app-owned unit/lint gate under JDK 17. The unqualified aggregate also executes pinned CameraX Robolectric SDK 36 tests, which require JDK 21; run that gate from a fresh ASCII-only copy with a temporary unpacked JDK 21 selected only through command-local `JAVA_HOME`. Do not install, replace, or reconfigure the system JDK.

```bash
flutter build apk --debug

task9_jdk17_home=$(/usr/libexec/java_home -v 17)
(cd android && JAVA_HOME="$task9_jdk17_home" ./gradlew :app:testDebugUnitTest :app:lintDebug)

# Download and unpack a pinned JDK 21 under /tmp; leave the system JDK unchanged.
task9_jdk21_dir=$(mktemp -d /tmp/altinus-task9-jdk21.XXXXXX)
case "$(uname -m)" in
  arm64) task9_jdk21_arch=aarch64 ;;
  x86_64) task9_jdk21_arch=x64 ;;
  *) echo 'Unsupported macOS architecture' >&2; exit 1 ;;
esac
curl --fail --location \
  "https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_${task9_jdk21_arch}_mac_hotspot_21.0.12.1_1.tar.gz" \
  --output "$task9_jdk21_dir/jdk21.tar.gz"
tar -xzf "$task9_jdk21_dir/jdk21.tar.gz" -C "$task9_jdk21_dir"
task9_jdk21_home=$(find "$task9_jdk21_dir" -type d -path '*/Contents/Home' -print -quit)
test -x "$task9_jdk21_home/bin/java"
"$task9_jdk21_home/bin/java" -version 2>&1 | grep 'version "21'

task9_verify_dir=$(mktemp -d /tmp/altinus-task9-verify.XXXXXX)
rsync -a \
  --exclude='.git' \
  --exclude='.dart_tool' \
  --exclude='build' \
  --exclude='android/.gradle' \
  ./ "$task9_verify_dir/"
(cd "$task9_verify_dir" && flutter pub get)
(cd "$task9_verify_dir/android" && \
  JAVA_HOME="$task9_jdk21_home" ./gradlew testDebugUnitTest lintDebug)

git add android
git commit -m 'feat(android): bridge bundled Korean OCR' -m 'What:
- Implement Pigeon hosts with bundled Korean ML Kit and app settings.
- Register asynchronous hosts and close recognizer resources.

Why:
- Provide immediate offline Android fallback without a community wrapper.'
```

### Task 10: Implement iOS static ML Kit and settings

**Files:**
- Modify: `ios/Podfile`, `ios/Podfile.lock`, `ios/Runner/AppDelegate.swift`, `ios/Runner.xcodeproj/project.pbxproj`
- Create: `ios/Runner/MlKitNativeOcrHostApi.swift`, `IosAppSettingsHostApi.swift`
- Add to Runner target Compile Sources (Task 10 owns this project membership): `ios/Runner/PlatformApis.g.swift`, `ios/Runner/MlKitNativeOcrHostApi.swift`, `ios/Runner/IosAppSettingsHostApi.swift`

**Interfaces:**
- Consumes: Task 8 generated Swift protocols.
- Produces: static Korean OCR `8.0.0` and app settings URL handling.

- [ ] **Step 1: Pin the native pod**

```ruby
pod 'GoogleMLKit/TextRecognitionKorean', '8.0.0'
```

Run `cd ios && pod install`; retain the lockfile.

- [ ] **Step 2: Implement async OCR**

Load `UIImage(contentsOfFile:)`; reject invalid input. Create `VisionImage`, assign the `UIImage.imageOrientation`, and process with `TextRecognizer` plus `KoreanTextRecognizerOptions`. Trim only to decide empty/nonempty; return original nonblank text. Never log path or text.

- [ ] **Step 3: Implement settings and host registration**

Open `UIApplication.openSettingsURLString` only when `canOpenURL` succeeds. The Flutter 3.47.5 template uses `FlutterImplicitEngineDelegate`, so keep host registration in `didInitializeImplicitFlutterEngine(_:)`. Immediately after `GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)`, use the implicit engine's application registrar for both generated setup calls:

```swift
NativeOcrHostApiSetup.setUp(
  binaryMessenger: engineBridge.applicationRegistrar.messenger(),
  api: MlKitNativeOcrHostApi()
)
AppSettingsHostApiSetup.setUp(
  binaryMessenger: engineBridge.applicationRegistrar.messenger(),
  api: IosAppSettingsHostApi()
)
```

Do not use `controller.binaryMessenger`; this AppDelegate owns no explicit Flutter view controller. Task 10 must add the generated `PlatformApis.g.swift` and both handwritten host files to the Runner target's Compile Sources phase exactly once; generating or creating the files does not assign Xcode target membership.

- [ ] **Step 4: Verify and commit**

```bash
flutter build ios --debug --no-codesign
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
git add ios
git commit -m 'feat(ios): bridge static Korean OCR' -m 'What:
- Implement Pigeon hosts with official static Korean ML Kit and app settings.
- Preserve orientation and typed empty/error outcomes.

Why:
- Provide equivalent offline iOS fallback without relying on Android behavior.'
```

### Task 11: Compose adapters and prove full flows

**Files:**
- Modify: `lib/features/ocr/application/ocr_providers.dart`, `lib/app.dart`
- Create: `integration_test/support/fixture_image_factory.dart`
- Create: `integration_test/fake_flow_test.dart`, `native_ocr_smoke_test.dart`, `live_cloud_smoke_test.dart`
- Modify: `test/features/ocr/application/ocr_flow_controller_test.dart`, `test/features/ocr/presentation/ocr_screen_test.dart`

**Interfaces:**
- Consumes: Tasks 4–10.
- Produces: production provider composition, deterministic full flow, and one Dart→Pigeon→native OCR test per platform.

- [ ] **Step 1: Write a failing fake end-to-end test**

Override every external provider. Boot, accept disclosure, reach preview, capture, complete cloud text, verify preserved lines, recapture, produce cloud failure, choose local, and prove a late cloud success cannot replace local output.

- [ ] **Step 2: Wire production providers**

Construct `SharedPreferencesDisclosureStore`, `CameraPluginRepository`, `FirebaseAiOcrService`, isolate preparation, prefixed transaction files, `PigeonLocalOcrService`, and `PigeonAppSettingsLauncher`. Plugin construction stays outside presentation except `CameraPreviewSurface`.

- [ ] **Step 3: Generate deterministic images on device**

Use `PictureRecorder`, `Canvas`, and `TextPainter` to write a temporary PNG containing `안녕하세요 ALTINUS 123`. Generate no-text, dark/low-contrast, rotated, and multiline variants without committing opaque binary fixtures.

- [ ] **Step 4: Add guarded native/live smoke tests**

`native_ocr_smoke_test.dart` calls real Pigeon local OCR and expects nonblank text on each platform. `live_cloud_smoke_test.dart` runs only with `RUN_LIVE_OCR=true`; otherwise it reports skip. A live record includes model, platform, device, OS, and commit, never image/text payloads.

- [ ] **Step 5: Verify and commit**

```bash
flutter test
flutter analyze
flutter build apk --debug
flutter build ios --debug --no-codesign
git add lib test integration_test
git commit -m 'test(flow): verify cloud-to-local recovery' -m 'What:
- Wire production adapters and add deterministic full-flow and native bridge smoke tests.
- Verify fallback, empty input, late results, lifecycle, and recovery.

Why:
- Prove all boundaries compose before relying on device observations.'
```

### Task 12: Run Android and iPhone real-device gates

**Files:**
- Create from observations: `docs/evidence/device-matrix.md`
- Modify only for reproduced failures: owning production/tests
- Append verified outcomes: `docs/AI_PROMPT_LOG.md`

**Interfaces:**
- Produces: commit-bound permission, preview, capture, OCR, bad-input, lifecycle, frame, memory, heat, and flash evidence.

- [ ] **Step 1: Record exact targets and commit**

```bash
flutter devices --machine | jq -r '.[] | [.id,.targetPlatform,.name] | @tsv'
git rev-parse HEAD
```

Record model/OS/ID/commit. With no iPhone, mark iOS real-device proof blocked; do not infer parity.

- [ ] **Step 2: Run Android bridge, live cloud, and profile build**

```bash
ALTINUS_ANDROID_DEVICE_ID="$(flutter devices --machine | jq -r '.[] | select(.targetPlatform | startswith("android")) | .id' | head -1)"
test -n "$ALTINUS_ANDROID_DEVICE_ID"
ARTINUS_LIVE_COMMIT="$(git rev-parse HEAD)"
ARTINUS_ANDROID_LABEL='set the exact Android model/label recorded for this run'
flutter test integration_test/native_ocr_smoke_test.dart -d "$ALTINUS_ANDROID_DEVICE_ID"
flutter test integration_test/live_cloud_smoke_test.dart -d "$ALTINUS_ANDROID_DEVICE_ID" \
  --dart-define=RUN_LIVE_OCR=true \
  --dart-define="OCR_DEVICE=$ARTINUS_ANDROID_LABEL" \
  --dart-define="OCR_GIT_COMMIT=$ARTINUS_LIVE_COMMIT"
flutter run --profile -d "$ALTINUS_ANDROID_DEVICE_ID"
```

Manually/with ARTEMIS verify disclosure, grant/deny/settings, preview, capture, rapid taps, cloud, offline local, no text, low light, blur, tilt, rotation, background/resume, lock/unlock, 10/60 seconds, and ten capture cycles.

- [ ] **Step 3: Repeat independently on iPhone**

```bash
ALTINUS_IOS_DEVICE_ID="$(flutter devices --machine | jq -r '.[] | select(.targetPlatform | startswith("ios")) | .id' | head -1)"
test -n "$ALTINUS_IOS_DEVICE_ID"
ARTINUS_LIVE_COMMIT="$(git rev-parse HEAD)"
ARTINUS_IOS_LABEL='set the exact iPhone model/label recorded for this run'
flutter test integration_test/native_ocr_smoke_test.dart -d "$ALTINUS_IOS_DEVICE_ID"
flutter test integration_test/live_cloud_smoke_test.dart -d "$ALTINUS_IOS_DEVICE_ID" \
  --dart-define=RUN_LIVE_OCR=true \
  --dart-define="OCR_DEVICE=$ARTINUS_IOS_LABEL" \
  --dart-define="OCR_GIT_COMMIT=$ARTINUS_LIVE_COMMIT"
flutter run --profile -d "$ALTINUS_IOS_DEVICE_ID"
```

Repeat the same matrix; use Xcode/device logs for native failures.

- [ ] **Step 4: Capture performance/memory and decide flash**

Save DevTools profile timelines around preview, preparation, cloud dispatch, and local OCR. Record UI/raster jank plus RSS/external memory before/after ten cycles, CPU, and observed heat with limitations. If auto/off support, firing, lifecycle, or parity fails on either platform, remove flash on both and add a regression test. Chrome CDP is not native evidence.

- [ ] **Step 5: Regress and commit observed facts**

```bash
flutter test
flutter analyze
scripts/check_context_budget.sh
git add docs/evidence docs/AI_PROMPT_LOG.md lib test integration_test android ios
git commit -m 'test(device): record cross-platform OCR evidence' -m 'What:
- Record exact Android/iPhone behavior, performance, memory, heat, and flash results.
- Fix and regress reproduced device-only defects.

Why:
- Real-device parity and responsiveness cannot be established by fakes or simulators.'
```

### Task 13: Create evaluator README and clean-clone proof

**Files:**
- Create: `README.md`
- Append final implementation evidence: `docs/AI_PROMPT_LOG.md`

**Interfaces:**
- Produces: concise evaluator handoff and a local clean clone. No external delivery.

- [ ] **Step 1: Write README only from evidence**

Include setup/run commands, architecture/libraries, hybrid OCR/privacy, trade-offs/limits, test commands/results, exact devices/OS/commit, and AI adopted/modified/rejected examples. Label blocked checks. Do not copy the long spec.

- [ ] **Step 2: Run the complete release gate**

```bash
flutter pub get
dart run pigeon --input pigeons/platform_apis.dart
git diff --exit-code -- lib/src/generated android/app/src/main/kotlin/com/example/altinus_ocr/PlatformApis.g.kt ios/Runner/PlatformApis.g.swift
dart format --output=none --set-exit-if-changed lib test integration_test pigeons
flutter analyze
flutter test
flutter build apk --release
flutter build ios --release --no-codesign
scripts/check_context_budget.sh
git diff --check
```

- [ ] **Step 3: Prove a clean local clone**

```bash
ALTINUS_CLONE_DIR="$(mktemp -d)/altinus-ocr"
git clone . "$ALTINUS_CLONE_DIR"
cd "$ALTINUS_CLONE_DIR"
flutter pub get
dart run pigeon --input pigeons/platform_apis.dart
git diff --exit-code
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Expected: only committed files resolve, regenerate identically, test, and build. Return to the original repository afterward.

- [ ] **Step 4: Commit and stop before external actions**

```bash
git add README.md docs/AI_PROMPT_LOG.md
git commit -m 'docs(readme): add verified evaluator handoff' -m 'What:
- Document architecture, setup, trade-offs, tests, devices, limitations, and AI evidence.
- Record clean-clone commands and observed results.

Why:
- Give evaluators a reproducible build path without overstating verification.'
```

Report the local commit. Do not create a remote, push, email `recruit@artinus.dev`, or submit until freshly authorized.

## Plan self-review and hiring perspectives

Spec coverage: every design section maps to Tasks 1–13; direct HTTP/Dio is intentionally absent. Critical path: domain/controller → adapters → composed flow → both-device evidence → clean clone. Flash and iPhone evidence are release gates, not assumptions.

Overall execution-plan score: **93/100**.

- **HR / recruiter: 90/100.** Strong requirement traceability, honest limitations, AI evidence, and concise final handoff; exact outcomes remain unproven until execution.
- **Hiring manager / development lead: 94/100.** Strong TDD boundaries, generated native contracts, SDK isolation, timing/stale-result defense, and profiling. Highest risks are Firebase project readiness, iOS host compilation, and iPhone access.

Highest-leverage controls: finish Task 4 before broad UI work, prove Pigeon immediately after Tasks 9/10, and remove optional flash rather than spend the deadline on unstable parity.

## Sources used to lock execution details

- [Altinus assignment README](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)
- [Flutter integration tests](https://docs.flutter.dev/testing/integration-tests) and [profile-mode performance guidance](https://docs.flutter.dev/perf/ui-performance)
- [Riverpod automatic disposal](https://riverpod.dev/docs/concepts2/auto_dispose)
- [Pigeon 29.0.4 and async callback generation](https://pub.dev/packages/pigeon)
- [Android ML Kit Korean Text Recognition 16.0.1](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)
- [iOS GoogleMLKit/TextRecognitionKorean 8.0.0](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios)
- [Firebase AI Logic for Flutter](https://firebase.google.com/docs/ai-logic/get-started?api=dev&platform=flutter)
