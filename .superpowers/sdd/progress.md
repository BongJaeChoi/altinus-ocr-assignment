# SDD Progress

- Plan: `docs/superpowers/plans/2026-09-28-altinus-camera-ocr.md`
- Branch: `feat/altinus-ocr-implementation`
- Base: `27fe659b4f09747599a313e79d5033945b1124fb`

| Task | Status | Commit | Review |
| --- | --- | --- | --- |
| 1. D0 documentation reconciliation | complete | `0529ad6` | Approved; no findings |
| 2. Flutter scaffold and dependencies | complete | `3350219` | Approved; no blocking findings |
| 3. Domain contracts and states | complete | `065f9d8` | Approved after invariant fix |
| 4. Controller with fake-clock TDD | complete | `e19c8a6` | Approved after ownership/concurrency fixes |
| 5. Disclosure and UI | complete | `9d3cb57` | Approved after privacy/lifecycle/accessibility fixes |
| 6. Camera and lifecycle | complete | `36fcddc` | Approved; physical flash proof deferred |
| 7. Firebase and image preparation | core complete; config pending | `1a7e1c1` | Core approved; awaiting authorized Firebase project |
| 8. Pigeon contracts | complete | `23ee862`, `ee0c984` | Approved after implicit-engine plan and null-invariant fixes |
| 9. Android ML Kit and settings | complete; device gate pending | `c2b2366`, `cf3e496`, `6786af7` | Approved after threading, callback, teardown, and test hardening |
| 10. iOS ML Kit and settings | complete; device gate pending | `d0e2e48` | Approved; Swift tests 9/9 and clean builds pass |
| 11. Full composition and integration | complete; Firebase/device gates pending | `23be2cf`, `872a517`, `2aff052` | Approved; root Minor follow-ups addressed |
| 12. Real-device and performance verification | pending | — | — |
| 13. README and clean-clone verification | complete with gates | `0bb87c6`, `cf1fe3d`, `caca759`, `2aff052..HEAD` | Root-review follow-up verified; Firebase/device/flash gates remain |
| 14. Whole-branch pre-release fixes | complete with external gates | `732c68b`, `1a11178`, `9101ac1`, `HEAD` | Pending Firebase auto-local, native taxonomy, Gradle/SwiftPM locks, and clean-clone verification complete; Firebase/device/signing gates remain |
| 15. Independent pre-release follow-up | complete with external gates | `8da5c3e`, `HEAD` | Pending capability now bypasses all cloud-only work; default Gradle lock-mode wording and 57/57 state evidence corrected |

## Firebase Signed Cloud Evidence Plan

- Plan: `docs/superpowers/plans/2026-09-29-firebase-signed-cloud-evidence.md`
- Base: `a7cb87d`

| Task | Status | Commit | Review |
| --- | --- | --- | --- |
| 1–2. Firebase project/apps and durable mobile identity | complete | `a7cb87d..711fe83` | Approved; remote project/apps, Pigeon stability, focused Dart/native tests independently verified |
| 3. Generated Firebase configuration | complete | `711fe83..de01922` | Approved; exact remote inventory, generated identities, focused test, native locks, Android/iOS builds verified |
| 4. Opt-in Firebase/App Check bootstrap | complete | `HEAD` | RED/GREEN bootstrap ordering, default-local composition, and full Flutter regression verified |
| 5. Android registered signing identity | complete | `072b4ff..HEAD` | Follow-up verified: partial/invalid secrets and malformed defines fail closed; every enabled Android build type uses the registered certificate |
| 6. Apple signing and App Check gate | pending | — | Requires action-time Team authorization before mutation |
| 7. Live cloud/device/final evidence | pending | — | — |

## Minor findings

- Task 11: the generated mixed fixture/nonblank native smoke proves bridge execution, not Korean glyph rendering or Korean-character recognition. Task 12 must validate actual Korean characters independently on Android and iPhone hardware.
