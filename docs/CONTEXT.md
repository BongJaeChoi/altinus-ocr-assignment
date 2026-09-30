# CONTEXT — Domain Knowledge First

Read this file before browsing code or proposing architecture. It separates authoritative facts from implementation hypotheses so agents do not replace assignment evidence with generic mobile advice.

## Source priority

When sources conflict, use this order:

1. Assignment README pinned at commit `cb7c0d5323e9c0f347253cf52c09594e18342ced`.
2. Altinus document-pass/assignment email record, especially deadline and submission route.
3. `docs/PRD.md` acceptance criteria derived from those sources.
4. Executable tests and current production behavior.
5. Official framework/plugin/platform documentation for the exact installed versions.
6. Repository decisions and experiments recorded in `docs/AI_PROMPT_LOG.md`.
7. General articles or model memory; use only as leads and verify them.

If a fact is missing, label it `Unknown` and plan a check. Do not silently promote an assumption.

## Authoritative task facts

- Target role: Altinus Frontend Engineer assignment.
- Required product: camera preview → still capture → OCR → recognized text display.
- Supported platforms: iOS and Android with the same core behavior.
- Required engineering qualities: real-device preview, non-blocking UI, bad-input handling, permission handling, OCR error handling.
- Required explanation: choices, tradeoffs, tests, tested devices, AI usage, and adopted/modified/rejected AI suggestions.
- Deadline context: `2026-09-30 23:59 KST`.
- External submission is not authorized by repository files.

## Camera/OCR domain model

Treat the experience as an explicit state machine, not a collection of booleans:

```text
booting
  → permissionRequired
  → initializingCamera
  → previewReady
  → capturing
  → recognizing
  → result | emptyResult | recoverableError | terminalError
```

Lifecycle events can interrupt any camera-owned state. Capture jobs need identities/cancellation semantics so a late OCR response cannot replace a newer result.

### Resource boundaries

- Camera controller/session ownership belongs behind a platform-facing adapter.
- OCR engine ownership belongs behind a separate service interface.
- UI consumes immutable state/events and does not know native plugin details.
- Image paths/bytes are short-lived resources. Define cleanup after success, failure, retry, and disposal.
- Only one capture/OCR transaction should be active unless concurrency is deliberately designed and tested.

### Performance model

- UI responsiveness is an observable requirement, not merely use of `async` syntax.
- Capture, image decoding, orientation correction, resizing, OCR, and serialization can each create CPU/memory pressure.
- Bound image resolution and retained buffers where the chosen APIs permit.
- Measure on real devices; simulator speed and unit tests do not establish absence of jank.
- Preserve a visible processing state and prevent duplicate work.

### Error taxonomy

Map low-level failures into user-relevant categories:

- permission: not requested, `denied`, `restricted`, `permanentlyDenied`;
- camera: absent, busy, initialization failed, capture failed, interrupted by lifecycle;
- input: empty, unreadable, unsupported, rotated, oversized, temporary file missing;
- OCR: no text, engine unavailable, timeout/failure;
- concurrency: duplicate capture, stale result, disposed owner callback.

Empty text is a valid OCR outcome and must not be mislabeled as an engine crash.

## Current environment facts

- Flutter `3.47.5` stable and Dart `3.13.4` are the committed implementation versions.
- Xcode `26.1.1`, CocoaPods `1.16.2`, Java 17, and Android SDKs are available.
- Final evaluator-cloud verification found no connected physical Android or
  iPhone. An iOS 18.5 iPhone 16 Pro simulator was available only as
  supplemental cloud evidence.
- Flutter is the committed implementation stack.

Re-check environment/device facts immediately before implementation and E2E; they are time-sensitive.

## Committed implementation decisions

- Default evaluator debug builds initialize the dedicated
  `artinus-ocr-bongjae-202609` Spark project and use `firebase_ai` cloud-first
  OCR with App Check. The AI client must receive the active App Check instance.
- Use official Korean ML Kit through a typed Pigeon fallback. Cloud and local
  recognition are sequential, never speculative parallel work.
- `ARTINUS_CLOUD_EVIDENCE=false` is the explicit local-only escape hatch. It
  routes an owned capture directly to local OCR before Firebase initialization,
  cloud image preparation, timers, or dispatch.
- Use manual Riverpod `NotifierProvider`; do not use code generation.
- Keep Flutter lifecycle translation in `OcrScreen`, but keep camera lifecycle
  policy in `OcrFlowController`: transient inactive may settle a pending
  permission/initialization, a granted inactive session is released, true
  background forces teardown, and stale resume generations cannot reopen it.
- Give the user a 10-second choice, with a cumulative 60-second cloud budget and at most two cloud attempts. Attempt 1 uses `gemini-3.8-flash`; only documented transient failures wait 1,000–1,250ms and use `gemini-3.5-flash-lite` for attempt 2. Both cloud failures lead to the existing local-OCR/recapture choice.
- Pinned `firebase_ai 3.10.0` hides structured status/header data for some 408/429 responses. Retry classification therefore has one narrow adapter exception for official status tokens/messages; unknown messages remain nonretryable, UI copy never includes them, and a dependency upgrade must revalidate or remove this exception.
- The repository intentionally tracks a dedicated revocable Android assignment
  keystore/properties and one iOS App Check debug token for evaluator setup
  convenience. This is a user-approved take-home exception, not production
  credential practice. iOS profile/release fail closed and release artifacts
  must not contain the token.
- Android uses Play Integrity configured for compatible outside-Play installs.
  iOS uses the registered debug provider only in Flutter debug mode; the
  observed free Personal Team did not provide the production DeviceCheck key
  path required by Firebase.
- Firebase AI monitoring is enabled at 100% sampling by explicit user choice;
  only non-sensitive generated fixtures may be used for recorded live evidence.
- Use a physical Android and borrowed iPhone for final real-device proof.
- Require clean-clone, fixed-input, cloud/local, Pigeon, frame-time, memory, and heat evidence.

## Latest observed evidence

- Executable commit `1353fc9`, 2026-09-30 KST, passed source-equivalent
  ASCII-path `flutter analyze` with 0 issues, lifecycle widget tests 11/11,
  controller tests 85/85, all 252 Flutter tests, context budgets, and diff
  hygiene. These automated races cover lifecycle ownership but do not prove
  physical Android/iPhone permission timing or camera behavior.
- On 2026-09-30, source based on `9b0bb1b` plus the E2E correction diff passed
  ASCII-path analysis with 0 issues, all 245 Flutter tests, Android/iOS native
  OCR integration (3/3 each), Android/iOS fake flow (2/2 each), Android debug
  build and app unit/lint, and iOS device/simulator debug builds. iOS primary
  and fallback live cloud smokes returned nonblank generated-fixture results.
- A Play Store AVD (`AltinusPlayStore33`, Android 13/API 33) was installed and
  boot-verified with `com.android.vending`; native OCR and fake flow passed.
  Its sideloaded debug build was rejected by Play Integrity with App Check 403
  before a model request. The earlier non-Play AVD failed sooner with the exact
  outdated/missing Play Store condition. Neither result is physical attestation.
- Android API 36 emulator UI exploration passed disclosure, denial/settings
  recovery, preview/capture, rapid-tap single flight, empty-result recapture,
  background/resume, and rotation. It exposed and regression-covered a
  permission-sheet `inactive` lifecycle loop. Emulator camera behavior is not
  physical camera evidence.
- Code evidence commit `7152334`, 2026-09-29 KST, fresh ASCII-only clone:
  Pigeon regeneration clean, `flutter analyze` 0 issues, 228 Flutter tests,
  2 fake full-flow tests,
  Android debug/release builds, app unit tests/lint, and iOS debug/release
  no-codesign builds passed.
- At `899bf4c`, an iOS 18.5 simulator live smoke reached
  `gemini-3.8-flash` through the production bootstrap and returned a nonblank
  result for a generated fixture. Final `7152334` revalidation made two
  canonical attempts that failed at the sanitized service boundary; a
  diagnostic request then reached the SDK quota-exceeded branch. Firebase
  documents that this can represent project quota or model capacity. This is
  supplemental and does not prove camera or physical-iPhone behavior.
- Firebase console aggregate monitoring appeared for the iOS app. Do not open
  or copy trace inputs/outputs into evidence.
- The exact evaluator token and its source identifier were absent from expanded
  Android release APK and iOS release app outputs. Android release signing
  matched the sole registered assignment certificate.
- Commit `30cb3d0` on the iPhone 16 Pro iOS 18.5 simulator passed the real
  Pigeon → Swift → Korean ML Kit smoke for generated Korean/Latin, multiline,
  rotated, and no-text fixtures. Detected fixtures retained the generated
  Korean and Latin core tokens; multiline retained its newline/token evidence.
  The same run sanitized a missing image and completed ten
  sequential native OCR requests. The two fake full-flow tests and 9/9
  RunnerTests also passed. This does not promote any physical-device gate.
- Physical Android/iPhone camera, App Check, local OCR, lifecycle, performance,
  heat, flash, and platform parity remain blocked until hardware is connected.

## Done evidence ledger

A requirement is done only when linked to evidence:

| Requirement | Expected evidence |
|---|---|
| Preview/capture | focused test plus real-device video/screenshot/log |
| OCR result | deterministic test plus real printed-text sample |
| Non-blocking UI | architecture evidence plus device observation/profile |
| Permission errors | tests plus platform-specific manual/automated run |
| Bad input/OCR errors | deterministic failure injection and visible recovery |
| iOS/Android parity | separate dated run records for both platforms |
| AI disclosure | append-only decisions and final README summary |
