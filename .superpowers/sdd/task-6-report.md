# Task 6 report — official camera adapter, preview, and lifecycle ownership

## Status

Implemented, reviewed, and verified. `CameraPluginRepository` is the production `camera 0.12.1` adapter; `CameraPreviewSurface` is the only widget that imports and constructs `CameraPreview`. The OCR application/domain layers expose no plugin type.

## RED → GREEN

- Initial RED: camera tests failed to compile because the adapter, pure facade, failure kinds, and preview surface did not exist.
- Adapter GREEN: facade-backed tests cover rear-only selection, high resolution, audio disabled, JPEG still configuration, no rear/no cameras, all three permission codes, initialization/capture errors, duplicate capture, flash probing, held initialization disposal, and late capture rejection.
- Lifecycle RED: tests failed because `OcrScreen` was not an observer and did not embed an isolated preview.
- Lifecycle GREEN: repeated inactive is deduplicated, resume reinitializes, observer removal prevents post-dispose callbacks, and fake repositories render a neutral placeholder.
- Review RED: regressions exposed lost ownership after failed teardown, stale JPEG cleanup loss, racing failed-init/public disposal, and unreachable flash controls.
- Review GREEN: teardown is single-flight per session; a native teardown failure is terminal and permanently retains unproven ownership, while repositories that can prove a later release remain controller-retryable. Failed stale deletion hands `cleanupPath` to controller-owned cleanup; supported auto/off controls are visible, unsupported controls fail closed, and resume restores auto.
- Re-review RED: a production-semantics fake showed that the second raw dispose was accepted as release after the first native failure; interrupted `Booting` performed only one start attempt; hidden/paused mount never established owned resume intent.
- Re-review GREEN: the adapter makes one native teardown call and permanently blocks replacement work after failure; successful teardown still permits reinitialization. Boot resume creates a new guarded start generation for both held orphan cleanup and held disclosure read, and initial hidden/paused state defers all startup until resume.

## Plugin/domain mapping

| Source condition | Camera boundary result | OCR domain result |
| --- | --- | --- |
| `CameraAccessDenied` | `CameraPermissionState.denied` | `PermissionDenied(denied)` |
| `CameraAccessDeniedWithoutPrompt` | `restrictedOrNoPrompt` | `PermissionDenied(restrictedOrNoPrompt)` |
| `CameraAccessRestricted` | `restrictedOrNoPrompt` | `PermissionDenied(restrictedOrNoPrompt)` |
| no camera or no rear lens | `CameraFailureKind.unavailable` | `OcrFailureKind.cameraUnavailable` |
| unknown enumeration/session initialization error | `initialization` | `cameraInitialization` |
| still capture error or duplicate adapter capture | `capture` / `captureInProgress` | `cameraCapture` |
| disposed generation, failed teardown, or stale callback | `interrupted` | `cameraInterrupted` |
| unproven/failed flash | hidden and `flashUnsupported` | fail closed; `cameraInitialization` if surfaced |

No mapping parses exception descriptions.

## Lifecycle and cancellation proof

- Every initialization receives a generation and a cancellation completer. Disposal increments the generation, settles enumeration waits, and awaits the session's disposal/initialization boundary before returning.
- All callers share one per-session teardown future. A native failure is latched for that concrete session: later disposal attempts rethrow `interrupted` without calling the already-disposed `CameraController`, the session remains retained, and initialization/capture stay blocked. Only process/app restart can safely recover when physical release is unproven. The controller may retry a different repository implementation only when that implementation can prove release.
- Capture is synchronously debounced. A late path is deleted before interruption is reported; if direct deletion fails, the path is attached to `CameraFailure` and adopted by the controller's retryable owned-file cleanup.
- Inactive forwarding is once per inactive/hidden/paused/resumed cycle. Resume reinitializes an interrupted preview or starts a new owned boot generation after an interrupted `Booting` cleanup/disclosure read; stale boot completions cannot overwrite it. A screen mounted while hidden/paused defers boot until resume, and the observer is removed before widget disposal.
- `CameraPreviewSurface` accepts the domain repository, downcasts only inside the plugin-isolated widget, and renders a stable neutral fallback for provider overrides.
- One stable live-region wrapper from Task 5 remains around every screen state.

## Official API evidence

- Pinned `camera 0.12.1` constructs `CameraController` with `ResolutionPreset.high` and `enableAudio: false`; `takePicture()` supplies the still path and `CameraController.dispose()` waits for its initialize future.
- Pinned CameraX `ImageCaptureProxyApi.java` uses `.jpg`; pinned AVFoundation `DefaultCamera.swift` initializes `fileFormat` to JPEG. Real-device output/orientation remains a later gate.

## Verification

- Format: `dart format --output=none --set-exit-if-changed lib test` — 26 files checked, zero changes.
- Focused camera/controller/presentation suite — 115 tests passed.
- Full suite: `flutter test` — 122 tests passed.
- ASCII worktree `/tmp/altinus-task6-review.RkvcB6`: `flutter analyze lib/features/camera lib/features/ocr` — no issues.
- Android from the ASCII worktree: `flutter build apk --debug` — built `app-debug.apk`.
- iOS from the ASCII worktree: `flutter build ios --debug --no-codesign` — built `Runner.app`.
- `git diff --cached --check` and plugin-leak scans passed.
- Review corrections and final diff/context self-review: no remaining blocker found.

## Hiring-persona reviews

### HR / recruiter persona — 94/100

- Role fit and clarity: strong Flutter/mobile ownership story with camera permissions, native lifecycle, accessible recovery, and user-visible flash behavior.
- Evidence and credibility: explicit RED/GREEN cases, exact test/build gates, and no claim of simulator/device parity.
- Risk: the complete OCR app is not composed until later tasks, and physical Android/iPhone camera evidence is intentionally deferred.
- Improvement: present the later device matrix and captured evidence beside this adapter work.

### Hiring manager / development lead persona — 97/100

- Technical depth: pure facade testing avoids method-channel mocks while generation guards, single-flight teardown, terminal native-failure ownership, and stale-file handoff cover hard async failures.
- Maintainability: plugin types are confined to two camera files; the controller consumes only domain contracts and explicit failure kinds.
- Evidence and credibility: failure injection covers disposal during initialization, duplicate operations, late completion, failed deletion, and concurrent teardown.
- Risk: JPEG and flash parity still depend on native devices despite pinned-source evidence.
- Improvement: execute the planned repeated-capture, lifecycle, orientation, and flash gates on both platforms.

## Concerns

- Native preview, flash firing, JPEG metadata/orientation, and repeated lifecycle behavior are not claimed until Task 12 real-device runs.
- Builds emit upstream future-compatibility warnings for `firebase_ai` Swift Package Manager/Kotlin plugin migration; both current debug targets build successfully.
