# Cloud Model Failover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep cloud OCR useful when the primary model is rate-limited or temporarily unavailable by making one bounded attempt with a fallback model that has a larger observed model-specific daily limit before offering bundled on-device OCR.

**Architecture:** The transaction controller continues to own attempt count, delay, the cumulative 60-second deadline, and recovery UI. The domain port passes only a primary/fallback strategy; the Firebase adapter maps that strategy to exact model IDs and classifies only documented transient failures as retryable.

**Tech Stack:** Flutter 3.47.5, Dart 3.13.4, Riverpod, `firebase_ai 3.10.0`, `fake_async`, Flutter test.

## Global Constraints

- Cloud attempt 1 uses `gemini-3.8-flash`; attempt 2 uses `gemini-3.5-flash-lite`.
- Retry only 408, 429, and 5xx/transient transport failures, with about one second of exponential backoff plus jitter.
- Never make more than two cloud calls in one transaction; both share the existing 60-second deadline.
- Configuration, permission/location, safety/recitation, malformed response, and invalid input failures do not retry.
- Never expose model IDs, exception messages, HTTP status, or error codes in user-facing copy.
- After the second cloud failure, preserve the existing natural choice to use bundled on-device OCR or retake.

---

### Task 1: Express primary/fallback strategy at the cloud port

**Files:**
- Modify: `lib/features/ocr/domain/ocr_ports.dart`
- Modify: `test/support/ocr_fakes.dart`
- Modify: `lib/features/ocr/application/ocr_flow_controller.dart`
- Test: `test/features/ocr/application/ocr_flow_controller_test.dart`

**Interfaces:**
- Produces: `CloudOcrAttempt { primary, fallback }`
- Produces: `CloudOcrService.recognize(String imagePath, {CloudOcrAttempt attempt = CloudOcrAttempt.primary})`

- [x] Add a failing controller test asserting the first request records `primary` and the single retry records `fallback`.
- [x] Run `flutter test test/features/ocr/application/ocr_flow_controller_test.dart` and confirm RED.
- [x] Add the enum/optional named parameter, record attempts in the controllable fake, and pass the controller attempt explicitly.
- [x] Re-run the focused controller test and confirm PASS.

### Task 2: Map strategies to models and classify transient Firebase failures

**Files:**
- Modify: `lib/features/ocr/data/firebase_ai_ocr_service.dart`
- Modify: `lib/features/ocr/domain/ocr_failure.dart`
- Test: `test/features/ocr/data/firebase_ai_ocr_service_test.dart`

**Interfaces:**
- `FirebaseModelRequest.cloudAttempt` carries the strategy to the SDK gateway.
- `OcrFailure.quota()` and a dedicated transient-service constructor are retryable; the controller still enforces the two-call ceiling.

- [x] Add failing tests for exact primary/fallback model IDs, retryable quota, retryable 408/5xx/internal/unavailable messages, and nonretryable unknown 4xx/configuration/safety/invalid response.
- [x] Run `flutter test test/features/ocr/data/firebase_ai_ocr_service_test.dart` and confirm RED.
- [x] Map `primary` to `gemini-3.8-flash` and `fallback` to `gemini-3.5-flash-lite`; add conservative transient classification without surfacing message contents.
- [x] Re-run the focused data tests and confirm PASS.

### Task 3: Align backoff and verify the bounded recovery experience

**Files:**
- Modify: `lib/features/ocr/application/ocr_providers.dart`
- Test: `test/features/ocr/application/ocr_flow_controller_test.dart`
- Test: `test/features/ocr/presentation/ocr_screen_test.dart`

**Interfaces:**
- Produces: first retry delay in the range 1000–1250 ms.

- [x] Add or update tests proving quota/service-transient gets exactly one fallback attempt and nonretryable failures stay at one call.
- [x] Change the delay base to 1000 ms with at most 250 ms jitter.
- [x] Run focused controller and presentation tests and confirm the existing `1/2`, `2/2`, 10-second choice, 60-second bound, and sanitized recovery copy remain intact.

### Task 4: Record evidence and run release-proportional verification

**Files:**
- Modify: `README.md`
- Modify: `docs/AI_PROMPT_LOG.md`
- Modify: this plan (check completed steps)

**Interfaces:**
- Produces: evaluator-facing rationale and reproducible test evidence without secrets or recognized content.

- [x] Run `dart format --output=none --set-exit-if-changed lib test`.
- [x] Run focused tests, then `flutter analyze` and the full `flutter test` suite.
- [x] Run the deterministic fake integration test and relevant debug builds if the Dart-only change stays green.
- [x] Record the observed 20 RPD primary and 500 RPD fallback quota evidence, without claiming quotas that were not observed.
- [x] Commit with a Conventional Commit subject and a body stating what changed and why.
