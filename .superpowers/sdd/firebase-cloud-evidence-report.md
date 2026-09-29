# Firebase Cloud Evidence Report

Date: 2026-09-29 KST

Code evidence commit: `7152334`

Successful live-smoke commit: `899bf4c`

Project: `artinus-ocr-bongjae-202609`

Plan: `docs/superpowers/plans/2026-09-29-evaluator-cloud-bundle.md`

## Result

The dedicated Spark project, Android Play Integrity registration, iOS debug
provider, Firebase AI Logic Gemini Developer API, and default App Check
enforcement are configured. A production-bootstrap live smoke succeeded at
`899bf4c` on an iOS 18.5 simulator with `gemini-3.8-flash` and a generated
non-sensitive image. Final `7152334` revalidation made two canonical requests
that failed at the sanitized service boundary; a diagnostic request then
reached the SDK quota-exceeded branch. Firebase documents that 429 can mean
project quota exhaustion or model capacity exhaustion. Clean-clone automated,
Android/iOS build, signing, and release-containment gates passed at `7152334`.
No physical Android or iPhone was connected, so camera, native OCR,
attestation, and platform-parity claims remain blocked.

No billing upgrade, app-store upload, push, public-repository action, or task
submission was performed.

## Remote configuration observed

- Plan: Spark, shown as free (`$0/month`); no billing change was made.
- Mobile namespace: `dev.bongjae.artinusocr` for the single Android and single
  iOS app in the dedicated project.
- Android App Check: Play Integrity; the assignment certificate is the sole
  registered SHA-256. `PLAY_RECOGNIZED` and `LICENSED` are not required;
  minimum integrity is device integrity.
- iOS App Check: exactly one evaluator debug-token registration, no production
  provider registration. The token value is not reproduced here.
- Firebase AI Logic: Gemini Developer API enabled, Agent Platform API disabled,
  default App Check enforcement applied, template-only and authenticated-user
  modes disabled.
- AI monitoring: enabled at 100% sampling by explicit user decision.
- No client Gemini key, service-account key, Firebase CLI token, database,
  Authentication, Storage, Analytics, or unrelated application resource was
  created during this setup.

## Clean-clone verification

The final checks ran in an ASCII-only clone because Flutter 3.47.5 reproducibly
crashes its analyzer LSP initialization and Xcode percent-encodes SwiftPM paths
under the Korean parent directory.

| Gate | Result |
| --- | --- |
| `flutter pub get` | PASS |
| Pigeon generation + `git diff --exit-code` | PASS |
| `flutter analyze` | PASS, 0 issues |
| `flutter test` | PASS, 228 tests |
| fake full-flow integration | PASS, 2 tests |
| Android debug APK | PASS |
| Android app unit tests + lint | PASS, 422 Gradle tasks |
| Android release APK | PASS, 86.1 MB universal APK |
| Android release certificate | PASS, sole registered assignment SHA-256 |
| iOS debug no-codesign | PASS |
| iOS release no-codesign | PASS, 69.4 MB `Runner.app` |
| context budgets | PASS; `AGENTS.md` and `docs/PRD.md` below 10 KiB |
| tracked tree after generation/build | PASS, clean in the evidence clone |

Existing toolchain warnings remain: `firebase_ai 3.10.0` has not migrated to
Flutter built-in Kotlin or SwiftPM support, Gradle reports future Gradle 10
deprecations, and bundled Google ML Kit targets warn about the iOS 26+
Apple-Silicon simulator arm64 requirement. They did not fail the pinned builds.

## Live cloud diagnosis and proof

The first canonical live smoke obtained an iOS App Check token but every
Firebase AI request mapped to a service failure. One-variable probes showed
baseline text, structured response, and image requests all failed, ruling out
the OCR prompt, response schema, thinking level, and image input as the common
cause.

Source inspection then showed that App Check activation alone does not attach a
token to Firebase AI: `FirebaseAI.googleAI` receives an optional `appCheck`
instance, and the SDK adds `X-Firebase-AppCheck` only when it is supplied. The
gateway had called `FirebaseAI.googleAI()` without that instance.

TDD evidence:

1. A regression requiring the active App Check instance to cross the gateway
   boundary failed to compile before the seam existed.
2. `FirebaseSdkModelGateway` gained an injectable App Check provider and passes
   the resulting instance to both the SDK path and test generation boundary.
3. The production client helper is now directly tested to retain the active
   App Check instance. The focused service suite passed 47 tests; the full
   suite passed 228.
4. A fresh-clone canonical live smoke then passed without diagnostic source
   modifications:

```text
model: gemini-3.8-flash
platform: ios simulator
OS: iOS 18.5
fixture: generated, non-sensitive
result: nonblank OCR, test passed
```

The successful fresh clone initially hit a mixed SwiftPM/CocoaPods `Pods_Runner` link
failure when integration test was the first iOS build. Running
`flutter build ios --debug --no-codesign` initialized the native dependency
state; the same clone then passed the live smoke. This is documented as the iOS
clean-checkout recovery order, not treated as an OCR product defect.

Final revalidation at `7152334` preserved that build order. Two canonical live
requests failed at the app's sanitized service boundary. A temporary diagnostic
in the disposable clone then reached the SDK `QuotaExceeded` branch. The
diagnostic source was not committed, and its clone is not evidence of a passing
request. No billing or quota increase was requested. The earlier success and
the final remote block are deliberately reported separately.

After refresh, Firebase console aggregate monitoring for the iOS app showed six
requests, 50% aggregate success, p95 latency 15.6 seconds, and token metrics.
Those aggregates include deliberate failing diagnostic probes; they are not a
production success-rate claim. No trace input or output was opened or copied.

## Release containment

The executable verifier reads the approved token privately from source and
scans the expanded Android release APK and iOS release app without printing it.
Its repeatable fixture test proves clean artifacts pass and injected iOS-token
or Android-identifier leaks fail. Both the exact value and
`evaluatorIosAppCheckDebugToken` source identifier were absent from the real
artifacts:

```text
RELEASE_TOKEN_CONTAINMENT=PASS
ANDROID_RELEASE_CERTIFICATE=PASS
```

```text
android_release_apk_sha256=4b820c31b2f43d421bec8a3238ef59f8d68993634b493a5e16a7ea482cadaa61
ios_release_runner_sha256=404b89dbe0a66b01fd69babd579b801fe73b1c00488163cd72a619f65b5d283d
```

The repository still contains the user-approved assignment-only source token
and Android signing material for evaluator debug/build convenience. This is not
production credential handling. The project is dedicated, revocable, and
Spark/no-billing; revocation is scheduled after evaluation.

## Unverified physical-device gates

`flutter devices --machine` listed only the iOS simulator, macOS, and Chrome;
`adb devices -l` listed no Android device. Therefore the following remain
unverified:

- physical Android Play Integrity acceptance for an outside-Play install;
- physical iPhone debug-token acceptance and Personal Team signing;
- actual rear-camera preview/capture, permission/settings recovery, orientation,
  flash, background/resume, and rapid taps;
- bundled Korean ML Kit results and offline fallback on both platforms;
- Korean glyph accuracy, explicit no-text photographs, 10/60-second UX, ten
  capture cycles, frame time, memory/CPU, and heat.

The iOS simulator result is supplemental and must not be used as physical
platform-parity evidence.

## Independent hiring-persona review

Final read-only re-review after the four Important fixes found Critical 0,
Important 0, and Minor 2.

- Overall: `86/100`
- HR / recruiter: `88/100`
- Hiring manager / development lead: `84/100`

The two Minor findings are bounded: the production client factory identity is
directly tested but a future gateway edit could theoretically bypass that
factory without the unit test detecting the new call graph; and this ignored
report had to be force-added in the final evidence commit. The latter is
resolved by the final staged manifest.

The three highest-leverage remaining improvements are: run the complete camera,
fallback, lifecycle, and performance matrix on physical Android and iPhone;
repeat the canonical `7152334` cloud smoke after quota/capacity recovery without
adding billing; and preserve the exact evidence report plus artifact hashes in
the final commit. The score is limited by missing physical-device evidence, not
by an unreported static blocker.

## Sources

- https://firebase.google.com/docs/ai-logic/get-started?api=dev&platform=flutter
- https://firebase.google.com/docs/ai-logic/models
- https://firebase.google.com/docs/ai-logic/pricing
- https://firebase.google.com/docs/ai-logic/monitoring
- https://firebase.google.com/docs/ai-logic/quotas
- https://firebase.google.com/docs/ai-logic/error-codes
- https://firebase.google.com/docs/app-check/flutter/debug-provider
- https://firebase.google.com/docs/app-check/android/play-integrity-provider
- https://firebase.google.com/docs/app-check/ios/devicecheck-provider
- https://developer.apple.com/support/compare-memberships/
