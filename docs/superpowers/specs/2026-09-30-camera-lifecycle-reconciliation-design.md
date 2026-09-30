# Camera Lifecycle Reconciliation Design

Date: 2026-09-30  
Status: approved for planning  
Scope: camera initialization interrupted by Flutter lifecycle changes

## Problem

`CameraInitializing` covers both the native permission request and the remaining
camera-session initialization. Flutter's `inactive` state does not identify why
focus was lost: it may be a permission sheet, another system dialog, the
notification shade, a call, or an app transition.

Forwarding every initialization-time `inactive` event to camera teardown can
interrupt the permission request and repeat it. Ignoring every such event can
instead leave a session that completed while inactive owned until a later
transition. A resume operation can also race with a newer inactive/background
event and reopen the camera at the wrong time.

## Decision

The application controller owns lifecycle phase and camera reconciliation. The
widget only translates Flutter lifecycle notifications into controller events;
it does not infer whether a permission prompt is active from OCR state.

No permission package, native permission bridge, or second camera lifecycle
owner is added. The official `camera` adapter remains the single platform
boundary.

## Components

### `OcrScreen`

- Forward `inactive`, `hidden`/`paused`/`detached`, and `resumed` distinctly.
- Keep no permission-specific lifecycle policy.
- Do not start camera work while the initial binding state is not resumed.

### `OcrFlowController`

- Track a private lifecycle phase: active, transiently inactive, or
  backgrounded.
- Track a monotonically increasing lifecycle generation so an older async
  resume cannot reopen the camera after a newer transition.
- Continue owning camera operation identity, single-flight teardown, stale
  callback rejection, and resume eligibility.

### `CameraRepository`

- Keep its existing serialized initialization/disposal contract.
- Do not expose Flutter lifecycle types or permission-prompt guesses.

## State transitions

```text
active + CameraInitializing
  -- inactive --> transientlyInactive; allow the pending permission/init result

pending result while transientlyInactive
  -- denied/error --> existing recovery state; no automatic retry
  -- granted --> dispose the completed session; mark preview needed on resume

transientlyInactive
  -- resumed before init settles --> keep the same pending initialization
  -- hidden/paused/detached --> backgrounded; force teardown/cancellation

inactive/backgrounded + camera teardown
  -- resumed --> await teardown, then initialize only if generation is current
                 and lifecycle is still active
```

An initialization that reaches a usable session while the app is still
inactive must not publish `PreviewReady`. It first releases that session. If the
app has already resumed when the result is processed, the same initialization
may publish the preview without an extra restart.

## Concurrency invariants

1. At most one repository initialization and one repository teardown are
   physically active.
2. A permission result is allowed to settle after transient `inactive`; a true
   background transition may invalidate it.
3. A camera session is not retained after initialization completes while the
   lifecycle remains inactive or backgrounded.
4. A resume continuation checks both lifecycle phase and generation after each
   await before initializing.
5. Permission denial never triggers an automatic second permission request.
6. OCR-owned states do not reopen the camera merely because the app resumed.

## Verification contract

Add RED tests before production changes for:

1. permission/init granted after `inactive` but before `resumed`;
2. `resumed` arriving before the held initialization completes;
3. permission denial after transient `inactive`, with no reinitialization;
4. `inactive -> hidden/paused -> late completion -> resumed`;
5. a newer `inactive` arriving while resume waits for teardown;
6. repeated lifecycle notifications retaining a maximum initialization
   concurrency of one;
7. widget-to-controller routing for transient inactive versus background.

Run focused controller/widget lifecycle tests, the full Flutter suite, static
analysis from an ASCII-only path, and the repository context-budget check.
Physical Android and iPhone runs remain a separate user-owned final gate.

## Tradeoff

If permission is granted and native initialization finishes before Flutter
reports `resumed`, the completed session is released and opened once more after
resume. This bounded extra initialization is preferred to retaining camera
ownership while inactive or guessing that every inactive event is a permission
sheet. The physical-device pass must check that the first permission grant
still reaches preview naturally without another prompt.

## Sources

- Flutter `AppLifecycleState`:
  <https://api.flutter.dev/flutter/dart-ui/AppLifecycleState.html>
- Official camera lifecycle guidance:
  <https://pub.dev/packages/camera#handling-lifecycle-states>
- `camera 0.12.1` controller implementation:
  <https://github.com/flutter/packages/blob/camera-v0.12.1/packages/camera/camera/lib/src/camera_controller.dart>
- Android CameraX `0.7.5` permission path:
  <https://github.com/flutter/packages/blob/camera_android_camerax-v0.7.5/packages/camera/camera_android_camerax/lib/src/android_camera_camerax.dart>
- iOS AVFoundation `0.10.3+1` permission path:
  <https://github.com/flutter/packages/blob/camera_avfoundation-v0.10.3%2B1/packages/camera/camera_avfoundation/darwin/camera_avfoundation/Sources/camera_avfoundation/CameraPlugin.swift>
