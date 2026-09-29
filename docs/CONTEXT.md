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
- No Android device was connected during bootstrap analysis.
- Registered iPhones were unavailable during bootstrap analysis.
- Flutter is the committed implementation stack.

Re-check environment/device facts immediately before implementation and E2E; they are time-sensitive.

## Committed implementation decisions

- Use `firebase_ai` cloud-first OCR, with official Korean ML Kit through a Pigeon fallback.
- In the unconfigured evaluator build only, an explicit pending capability plus typed `configuration` failure continues directly to local OCR; configured Firebase configuration/service failures keep the recovery UI.
- Use manual Riverpod `NotifierProvider`; do not use code generation.
- Give the user a 10-second choice, with a cumulative 60-second cloud budget and at most two cloud attempts.
- Iterate on an Android device; borrow an iPhone for final real-device proof.
- Require clean-clone, fixed-input, cloud/local, Pigeon, frame-time, memory, and heat evidence.

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
