# Camera Lifecycle Reconciliation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make permission-time camera initialization and later lifecycle transitions deterministic without repeated permission prompts, inactive camera ownership, or stale resume work.

**Architecture:** `OcrScreen` forwards Flutter lifecycle categories without inspecting OCR state. `OcrFlowController` owns a private lifecycle phase and generation alongside its existing camera operation identity, defers teardown only while a transient inactive event overlaps an actual initialization, releases a granted session that finishes while inactive, and resumes only from a current lifecycle generation.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, Riverpod `Notifier`, official `camera 0.12.1`, `flutter_test`, `fake_async`.

## Global Constraints

- Do not add a permission package, native permission bridge, or second camera lifecycle owner.
- Keep `CameraRepository` free of Flutter lifecycle types and permission-prompt guesses.
- Use RED-GREEN-REFACTOR for every production behavior change.
- Preserve one physical initialization and one physical teardown at most.
- Preserve the current permission-denied recovery UI and never automatically request permission a second time.
- Treat `hidden`, `paused`, and `detached` as background transitions that force camera release.
- Do not claim physical Android or iPhone evidence from widget, simulator, or emulator tests.
- Do not push, submit, email, or create a remote.

---

## File map

- `lib/features/ocr/application/ocr_flow_controller.dart`: owns lifecycle phase, generation, deferred initialization, camera suspension, and guarded resume.
- `lib/features/ocr/presentation/ocr_screen.dart`: translates `AppLifecycleState` into controller events only.
- `test/features/ocr/application/ocr_flow_controller_test.dart`: proves controller behavior and async race rejection.
- `test/features/camera/camera_lifecycle_test.dart`: proves widget-to-controller routing and visible recovery behavior.
- `docs/AI_PROMPT_LOG.md`: records the implemented decision and fresh verification evidence.
- `docs/CONTEXT.md`: binds the lifecycle fix to an executable commit while leaving physical-device gates open.

### Task 1: Defer only a genuinely pending initialization

**Files:**
- Modify: `test/features/ocr/application/ocr_flow_controller_test.dart:1008`
- Modify: `lib/features/ocr/application/ocr_flow_controller.dart:15-65,379-473`

**Interfaces:**
- Consumes: `onInactive()`, `onResumed()`, `CameraRepository.initialize()`, and `CameraRepository.dispose()`.
- Produces: private `_CameraLifecyclePhase`, `_cameraLifecycleGeneration`, `_initializingCameraOperationId`, and `_initializationDeferredByInactive`.

- [ ] **Step 1: Write the RED test**

Add inside `group('cleanup and lifecycle', ...)`:

```dart
test('resume before deferred initialization settles reuses that request', () {
  fakeAsync((async) {
    final harness = _Harness(async);
    harness.camera.holdInitialize = true;
    unawaited(harness.controller.start());
    async.flushMicrotasks();

    unawaited(harness.controller.onInactive());
    unawaited(harness.controller.onResumed());
    async.flushMicrotasks();

    expect(harness.camera.disposeCount, 0);
    expect(harness.camera.initializeCount, 1);
    harness.camera.completeInitialize(0);
    async.flushMicrotasks();

    expect(harness.state, isA<PreviewReady>());
    expect(harness.camera.maxConcurrentInitializationCount, 1);
    harness.dispose(async);
  });
});
```

- [ ] **Step 2: Verify RED**

```bash
flutter test test/features/ocr/application/ocr_flow_controller_test.dart \
  --plain-name 'resume before deferred initialization settles reuses that request'
```

Expected: FAIL because current `onInactive()` disposes the pending initialization and resume starts another.

- [ ] **Step 3: Implement the minimum deferred-initialization state**

Add outside the controller:

```dart
enum _CameraLifecyclePhase { active, inactive, backgrounded }
```

Add beside the camera fields:

```dart
_CameraLifecyclePhase _cameraLifecyclePhase = _CameraLifecyclePhase.active;
int _cameraLifecycleGeneration = 0;
int? _initializingCameraOperationId;
bool _initializationDeferredByInactive = false;
```

Replace the public inactive entry with:

```dart
Future<void> onInactive() async {
  if (_cameraLifecyclePhase != _CameraLifecyclePhase.active) {
    return;
  }
  _cameraLifecyclePhase = _CameraLifecyclePhase.inactive;
  _cameraLifecycleGeneration += 1;
  if (state is CameraInitializing) {
    _needsPreviewOnResume = true;
    if (_initializingCameraOperationId != null &&
        _cameraTeardownFuture == null) {
      _initializationDeferredByInactive = true;
    }
    return;
  }
  await _suspendCamera();
}
```

Move the old `onInactive()` body unchanged into `_suspendCamera()`, except preserve existing resume needs:

```dart
_needsBootOnResume = _needsBootOnResume || needsBoot;
_needsPreviewOnResume = _needsPreviewOnResume || needsPreview;
```

Immediately after creating `operationId` in `_initializeCamera()`, assign the owner:

```dart
final operationId = ++_cameraOperationId;
_initializingCameraOperationId = operationId;
state = const CameraInitializing();
_cameraNeedsDispose = true;
```

Replace the closing brace of the method's existing `catch` block with this `finally` continuation:

```dart
} finally {
  if (_initializingCameraOperationId == operationId) {
    _initializingCameraOperationId = null;
  }
}
```

Prepend `onResumed()` with:

```dart
if (_cameraLifecyclePhase == _CameraLifecyclePhase.active) {
  return;
}
_cameraLifecyclePhase = _CameraLifecyclePhase.active;
_cameraLifecycleGeneration += 1;
if (_initializationDeferredByInactive &&
    state is CameraInitializing &&
    _initializingCameraOperationId != null &&
    _cameraTeardownFuture == null) {
  _initializationDeferredByInactive = false;
  _needsPreviewOnResume = false;
  return;
}
_initializationDeferredByInactive = false;
```

- [ ] **Step 4: Verify GREEN and regressions**

```bash
flutter test test/features/ocr/application/ocr_flow_controller_test.dart
```

Expected: all controller tests PASS; the new case has one initialization and zero teardown.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ocr/application/ocr_flow_controller.dart \
  test/features/ocr/application/ocr_flow_controller_test.dart
git commit -m 'fix(camera): defer transient initialization teardown' \
  -m $'What:\n- Preserve an in-flight camera permission/initialization across transient inactive and resumed.\n- Add a regression proving there is no duplicate initialization.\n\nWhy:\n- Camera permission is requested inside initialization, so immediate teardown can cancel and repeat the request.'
```

### Task 2: Release initialization that finishes while inactive

**Files:**
- Modify: `test/features/ocr/application/ocr_flow_controller_test.dart:1008`
- Modify: `lib/features/ocr/application/ocr_flow_controller.dart:414-473`

**Interfaces:**
- Consumes: Task 1 lifecycle fields and `_ensureCameraDisposed()`.
- Produces: `_parkInitializedCameraIfInactive(int operationId) -> Future<bool>`.

- [ ] **Step 1: Write the RED test**

```dart
test('granted initialization completed while inactive is parked', () {
  fakeAsync((async) {
    final harness = _Harness(async);
    harness.camera.holdInitialize = true;
    harness.camera.holdDispose = true;
    unawaited(harness.controller.start());
    async.flushMicrotasks();

    unawaited(harness.controller.onInactive());
    async.flushMicrotasks();
    expect(harness.camera.disposeCount, 0);

    harness.camera.completeInitialize(0);
    async.flushMicrotasks();
    expect(harness.camera.disposeCount, 1);
    expect(harness.state, isA<CameraInitializing>());

    harness.camera.completeDispose(0);
    harness.camera.holdInitialize = false;
    async.flushMicrotasks();
    unawaited(harness.controller.onResumed());
    async.flushMicrotasks();

    expect(harness.camera.initializeCount, 2);
    expect(harness.camera.maxConcurrentInitializationCount, 1);
    expect(harness.state, isA<PreviewReady>());
    harness.dispose(async);
  });
});
```

- [ ] **Step 2: Verify RED**

Run the test by its exact name. Expected: FAIL because Task 1 still permits `PreviewReady` while inactive.

- [ ] **Step 3: Implement inactive-result parking**

```dart
Future<bool> _parkInitializedCameraIfInactive(int operationId) async {
  if (_cameraLifecyclePhase == _CameraLifecyclePhase.active) {
    return false;
  }
  _initializationDeferredByInactive = false;
  _needsPreviewOnResume = true;
  _cameraReady = false;
  try {
    await _ensureCameraDisposed();
  } catch (error) {
    if (_ownsCameraOperation(operationId)) {
      state = RecoverableError(failure: _domainFailure(error));
    }
    return true;
  }
  if (_ownsCameraOperation(operationId)) {
    _cameraNeedsDispose = false;
  }
  return true;
}
```

Call this helper immediately after a granted `initialize()` and again after the flash probe, because lifecycle can change across either await:

```dart
if (permission == CameraPermissionState.granted) {
  if (await _parkInitializedCameraIfInactive(operationId)) {
    return;
  }
  var flashSupported = false;
  try {
    flashSupported = await _camera.supportsFlash();
  } catch (_) {
    flashSupported = false;
  }
  if (!_ownsCameraOperation(operationId)) {
    return;
  }
  if (await _parkInitializedCameraIfInactive(operationId)) {
    return;
  }
  _cameraReady = true;
  _flashSupported = flashSupported;
  _flashMode = CameraFlashMode.auto;
  state = PreviewReady(
    flashSupported: flashSupported,
    flashMode: CameraFlashMode.auto,
  );
}
```

On permission denial, clear automatic resume intent but retain the conservative disposal latch:

```dart
_initializationDeferredByInactive = false;
_needsPreviewOnResume = false;
_cameraReady = false;
state = PermissionDenied(permission);
```

In `onResumed()`, clear stale preview intent when the flow no longer needs a preview:

```dart
if (!_needsPreviewOnResume) {
  return;
}
if (!_flowNeedsPreview(state)) {
  _needsPreviewOnResume = false;
  return;
}
```

- [ ] **Step 4: Verify GREEN**

```bash
flutter test test/features/ocr/application/ocr_flow_controller_test.dart
flutter test test/features/camera/camera_repository_test.dart
```

Expected: both files PASS; the new test reports two sequential initializations and maximum concurrency one.

- [ ] **Step 5: Commit**

Commit with subject `fix(camera): park inactive initialized sessions`, a `What:` body naming immediate release and generation-guarded resume, and a `Why:` body naming inactive resource ownership.

### Task 3: Force background teardown and reject stale resume

**Files:**
- Modify: `test/features/ocr/application/ocr_flow_controller_test.dart:1008`
- Modify: `lib/features/ocr/application/ocr_flow_controller.dart:379-455`

**Interfaces:**
- Consumes: `_suspendCamera()`, `_CameraLifecyclePhase`, and Task 2 generation checks.
- Produces: `Future<void> onBackgrounded()` for `hidden`, `paused`, and `detached` events.

- [ ] **Step 1: Write the background RED test**

```dart
test('background cancels a deferred initialization and resumes once', () {
  fakeAsync((async) {
    final harness = _Harness(async);
    harness.camera.holdInitialize = true;
    unawaited(harness.controller.start());
    async.flushMicrotasks();

    unawaited(harness.controller.onInactive());
    unawaited(harness.controller.onBackgrounded());
    async.flushMicrotasks();

    expect(harness.camera.disposeCount, 1);
    expect(harness.camera.wasInitializeCancelled(0), isTrue);

    harness.camera.holdInitialize = false;
    unawaited(harness.controller.onResumed());
    async.flushMicrotasks();

    expect(harness.camera.initializeCount, 2);
    expect(harness.camera.maxConcurrentInitializationCount, 1);
    expect(harness.state, isA<PreviewReady>());
    harness.dispose(async);
  });
});
```

- [ ] **Step 2: Verify RED**

Run the test by its exact name. Expected: compile failure because `onBackgrounded()` is absent.

- [ ] **Step 3: Implement background transition**

```dart
Future<void> onBackgrounded() async {
  if (_cameraLifecyclePhase == _CameraLifecyclePhase.backgrounded) {
    return;
  }
  final inactiveAlreadyStartedTeardown =
      _cameraLifecyclePhase == _CameraLifecyclePhase.inactive &&
      !_initializationDeferredByInactive;
  _cameraLifecyclePhase = _CameraLifecyclePhase.backgrounded;
  _cameraLifecycleGeneration += 1;
  if (inactiveAlreadyStartedTeardown) {
    return;
  }
  _initializationDeferredByInactive = false;
  await _suspendCamera();
}
```

- [ ] **Step 4: Write the stale-resume RED test**

```dart
test('new inactive invalidates resume waiting for parked teardown', () {
  fakeAsync((async) {
    final harness = _Harness(async);
    harness.camera.holdInitialize = true;
    harness.camera.holdDispose = true;
    unawaited(harness.controller.start());
    async.flushMicrotasks();
    unawaited(harness.controller.onInactive());
    harness.camera.completeInitialize(0);
    async.flushMicrotasks();

    unawaited(harness.controller.onResumed());
    unawaited(harness.controller.onInactive());
    harness.camera.completeDispose(0);
    async.flushMicrotasks();
    expect(harness.camera.initializeCount, 1);

    harness.camera.holdInitialize = false;
    unawaited(harness.controller.onResumed());
    async.flushMicrotasks();
    expect(harness.camera.initializeCount, 2);
    expect(harness.state, isA<PreviewReady>());
    harness.dispose(async);
  });
});
```

- [ ] **Step 5: Verify the lifecycle generation guard**

Run the new test before completing the guard. Expected RED: the second inactive event does not need another physical teardown, so the older resume continuation can increment `initializeCount`. Capture the generation immediately after entering the active phase:

```dart
final lifecycleGeneration = _cameraLifecycleGeneration;
```

Add this exact post-teardown condition in `onResumed()`:

```dart
if (!_ownsCameraOperation(operationId) ||
    _cameraLifecyclePhase != _CameraLifecyclePhase.active ||
    lifecycleGeneration != _cameraLifecycleGeneration) {
  return;
}
```

Run the entire controller test file. Expected GREEN: no stale initialization and all previous tests PASS.

- [ ] **Step 6: Commit**

Commit with subject `fix(camera): distinguish background lifecycle teardown` and `What:`/`Why:` bodies describing forced background release and stale-resume rejection.

### Task 4: Make the widget a lifecycle translator

**Files:**
- Modify: `test/features/camera/camera_lifecycle_test.dart:22-119`
- Modify: `lib/features/ocr/presentation/ocr_screen.dart:20-78`

**Interfaces:**
- Consumes: controller `onInactive()`, `onBackgrounded()`, and `onResumed()`.
- Produces: `_forwardLifecycleState(AppLifecycleState state) -> void`; removes widget-owned OCR-state inference.

- [ ] **Step 1: Write the widget RED test**

```dart
testWidgets('inactive granted initialization is parked before resume', (
  tester,
) async {
  final harness = _LifecycleHarness(holdInitialize: true);
  addTearDown(() {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
  await tester.pumpWidget(harness.widget);
  await tester.pump();
  await tester.pump();

  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  await tester.pump();
  expect(harness.camera.disposeCount, 0);

  harness.camera.completeInitialize(0);
  await tester.pump();
  await tester.pump();
  expect(harness.camera.disposeCount, 1);

  harness.camera.holdInitialize = false;
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await tester.pump();
  await tester.pump();

  expect(harness.camera.initializeCount, 2);
  expect(harness.camera.maxConcurrentInitializationCount, 1);
  expect(find.byKey(const ValueKey('capture')), findsOneWidget);
});
```

- [ ] **Step 2: Verify RED**

Run the test by exact name. Expected: FAIL because the current widget skips resumed reconciliation after the held initialization becomes `PreviewReady`.

- [ ] **Step 3: Replace widget policy with translation**

Remove `_inactiveForwarded`, the `CameraInitializing` special case, and `_forwardInactiveOnce()`. Add:

```dart
void _forwardLifecycleState(AppLifecycleState state) {
  if (!mounted) {
    return;
  }
  final controller = ref.read(ocrFlowControllerProvider.notifier);
  switch (state) {
    case AppLifecycleState.resumed:
      unawaited(controller.onResumed());
    case AppLifecycleState.inactive:
      unawaited(controller.onInactive());
    case AppLifecycleState.hidden ||
        AppLifecycleState.paused ||
        AppLifecycleState.detached:
      unawaited(controller.onBackgrounded());
  }
}
```

Make `didChangeAppLifecycleState` call only `_forwardLifecycleState(state)`. In the delayed initial start, forward the exact non-resumed binding state instead of collapsing it to inactive.

- [ ] **Step 4: Extend background routing coverage**

For each of `hidden` and `paused`, start with `holdInitialize: true`, send `inactive` then the background state, assert one dispose/cancel, set `holdInitialize = false`, resume, and assert exactly one replacement initialization. Keep the current permission-denied test unchanged to prove no automatic retry.

- [ ] **Step 5: Verify GREEN**

```bash
flutter test test/features/camera/camera_lifecycle_test.dart
flutter test test/features/ocr/application/ocr_flow_controller_test.dart
```

Expected: both test files PASS, no framework exceptions, and maximum initialization concurrency remains one.

- [ ] **Step 6: Commit**

Commit with subject `refactor(camera): centralize lifecycle ownership`, a `What:` body describing lifecycle translation, and a `Why:` body describing removal of widget permission inference.

### Task 5: Record evidence and run the full gate

**Files:**
- Modify: `docs/AI_PROMPT_LOG.md`
- Modify: `docs/CONTEXT.md`

**Interfaces:**
- Consumes: final executable commit from Tasks 1-4 and fresh command output.
- Produces: evidence-only commit naming that executable commit; no production/test changes.

- [ ] **Step 1: Run full verification from an ASCII-only source copy**

Use the repository's existing temporary ASCII-copy procedure, then run:

```bash
flutter pub get
flutter analyze
flutter test test/features/camera/camera_lifecycle_test.dart
flutter test test/features/ocr/application/ocr_flow_controller_test.dart
flutter test
./scripts/check_context_budget.sh
git diff --check
```

Expected: every command exits 0, analysis reports no issues, and every test summary reports zero failures. Record the exact test count printed by the commands rather than predicting it.

- [ ] **Step 2: Record exact implementation evidence**

Append one `2026-09-30` entry to `docs/AI_PROMPT_LOG.md` with the approved A+ request, the RED failures actually observed, the adopted phase/generation implementation, fresh command results, and the still-open physical Android/iPhone gate.

Update `docs/CONTEXT.md` latest evidence to name the output of `git rev-parse --short HEAD` from the executable commit. State that automated lifecycle races are covered while physical camera behavior remains unclaimed.

- [ ] **Step 3: Self-review**

```bash
git diff --check
git status --short
git diff --stat
rg -n 'T[B]D|T[O]DO|F[I]XME' docs/AI_PROMPT_LOG.md docs/CONTEXT.md
```

Expected: no whitespace errors, unrelated files, or new incomplete markers.

- [ ] **Step 4: Commit the verified evidence**

```bash
git add docs/AI_PROMPT_LOG.md docs/CONTEXT.md
ALLOW_DOCS_ONLY=1 \
DOCS_ONLY_REASON='Bind fresh lifecycle verification to the executable commit.' \
git commit -m 'docs(evidence): bind lifecycle reconciliation verification' \
  -m $'What:\n- Record the executable commit and fresh lifecycle/full-suite results.\n- Keep physical Android and iPhone gates explicitly open.\n\nWhy:\n- Submission evidence must distinguish automated lifecycle coverage from unrun physical-device behavior.'
```

- [ ] **Step 5: Verify final local state**

```bash
git status --short --branch
git log -5 --oneline
```

Expected: clean `feat/altinus-ocr-implementation` worktree and no push or remote mutation.

## Deferred follow-up

After this lifecycle plan, create a separate delivery-hardening plan for the independent README AI disclosure, ASCII-path placement, iPhone signing instructions, optional Flutter `.fvmrc`, and final submission evidence. Keeping it separate prevents documentation/configuration review from obscuring the camera behavior change.
