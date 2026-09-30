# PRD — Altinus Camera OCR Assignment

## 1. Objective

Deliver a small Flutter 3.47.5 / Dart 3.13.4 application that demonstrates reliable mobile camera capture and OCR across iOS and Android. The result display is display-only; editing and copying are out of scope.

## 2. Source requirements

The assignment repository README at pinned commit `cb7c0d5323e9c0f347253cf52c09594e18342ced` requires:

1. Show a camera preview.
2. Capture a still image.
3. Run OCR on the captured image.
4. Display the recognized text.
5. Provide the same core behavior on iOS and Android.
6. Preview the app on a real device.
7. Avoid blocking the UI thread.
8. Handle bad input, permission problems, and OCR errors.
9. Document technical choices, tradeoffs, tests, tested devices, and AI usage, including what AI suggestions were adopted, modified, or rejected.

Submission context from the document-pass email: GitHub repository URL due by `2026-09-30 23:59 KST` to `recruit@artinus.dev`. This is context only; no push or submission is authorized by this PRD.

## 3. Primary user flow

1. User opens the app.
2. App requests or explains camera permission.
3. A responsive camera preview appears.
4. User captures a still image once.
5. UI immediately communicates processing state without freezing interaction/rendering.
6. OCR finishes and recognized text is displayed in a readable, non-editable form.
7. User can retry capture/OCR after success or failure.

## 4. Functional acceptance criteria

### Camera and permissions

- First-run permission request has clear rationale and outcome states.
- `denied`, `restricted`, or `permanentlyDenied` permission produces a recoverable UI; settings guidance is shown when appropriate.
- No-camera/unavailable-camera and initialization failure are visible and retryable.
- Preview obeys orientation/aspect ratio and does not stretch or obscure critical controls.
- Capture is debounced so repeated taps cannot create overlapping OCR jobs.

### OCR pipeline

- OCR runs only after a successful still capture.
- Processing is asynchronous; expensive decode/preprocess/OCR work is not performed synchronously on the UI thread.
- Empty recognition is distinct from engine failure.
- Rotated, blurred, dark, oversized, or unsupported input has defined handling.
- Stale results cannot overwrite a newer capture result.
- Temporary image files/resources are released according to lifecycle rules.

### Result and recovery

- Loading, success, empty, and error states are visually distinct.
- Recognized text is displayed read-only; editing and copying are not required.
- Retry does not require force-closing the app.
- Background/foreground transitions do not leave the camera or UI in a broken state.

### Platform parity

- The same primary flow and recovery paths are verified on iOS and Android.
- Platform-specific permission declarations and runtime behavior are tested separately.
- Any intentional platform difference is documented with rationale.

## 5. Quality acceptance criteria

- Static analysis passes with no new warnings.
- Unit tests cover state transitions, stale-result protection, and error mapping.
- Widget/component tests cover loading, result, permission-denied, empty, and OCR-error UI.
- Integration tests cover the flow with deterministic fakes; actual camera/OCR validation is recorded separately on real devices.
- README records architecture, dependency choices, tradeoffs, test commands/results, device/OS matrix, known limitations, and AI-use decisions.
- No claimed metric or device result lacks reproducible evidence.

## 6. Non-goals

- Any cloud account beyond the dedicated evaluation Firebase project, and any
  Authentication, database/storage backend, production deployment, billing
  attachment, or unrelated analytics. The approved Firebase AI monitoring
  aggregate is limited to non-sensitive evaluation evidence.
- Advanced document scanning, multi-page history, translation, or handwriting guarantees unless core criteria are already complete.
- Visual polish that delays reliability, platform parity, or verification.
- Any external submission or recruiter communication without explicit user authorization.

## 7. Delivery strategy

1. Prove camera permission/preview/capture on one platform with a thin vertical slice.
2. Separate camera, OCR, and presentation behind testable interfaces.
3. Add deterministic state tests before native E2E.
4. Port and verify platform configuration early, not at the end.
5. Record Android evidence in its owner session; no physical iPhone is available. The user chose maximum feasible simulator verification and explicit disclosure of unverified iPhone hardware/performance criteria, without changing the original assignment requirements.
6. Complete README from recorded decisions and results, never from memory.

## 8. Highest risks

- Samsung SM-S911N now has physical local capture/OCR/retry 10/10, recovery and short profile evidence (see docs/ANDROID_VERIFICATION_2026-09-30.md). Some Android physical failure/lifecycle/offline scenarios and long-term stability remain unverified; iPhone real-device acceptance and physical parity remain unverified without hardware.
- Camera/OCR plugins may differ by OS version, architecture, lifecycle, and permission behavior.
- OCR latency and image memory pressure can cause jank or termination if processing is not bounded.
- Simulator/emulator and mocked tests can hide real camera orientation, permission, and resource-lifecycle defects.
- Documentation can drift from implementation; the prompt/decision log and coupled-doc rule mitigate this.
