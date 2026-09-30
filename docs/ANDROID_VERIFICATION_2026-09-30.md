# Android physical verification — 2026-09-30

## Scope and source identity

This session owns common OCR concurrency and Android verification. The user
assigned iOS simulator work and README updates to another session; no physical
iPhone is available. Android success does not establish physical platform parity.

- Device: Samsung SM-S911N (Galaxy S23), Android 16/API 36.
- Common fix: `d81d731eff2618638807e25ba355d0eeb5a51945`.
- Controller SHA-256: `6d35c323782fb39d19eba2f30f4f936e57dc3b1bcbbaf570670ed5306056cc72`.
- Controller-test SHA-256: `2f33693588c94180ff06eeb123e50d6ae33e2a248e913178483bb1f1c7823106`.
- Physical profile run used `/tmp/altinus-device-verification.NdmShZ`, an
  ASCII-path clone with the final common source copied in; production controller
  bytes match the committed fix. This is source-equivalent evidence, not a claim
  that the entire temporary checkout was clean.
- Final automated Android runs used the local clean clone
  `/tmp/altinus-device-clean-d81d731` of `d81d731`. The expanded native run then
  copied only three fixture/test files from the iOS owner. Their native smoke
  hash matches the subsequently integrated `984335a` source:
  `d10fb5d48d530bd7613534c668b222d39ae6bc602c67fc045b320790b1d310b1`.

## Requirement correspondence and physical observations

The original assignment README, pinned at `cb7c0d`, requires camera preview,
still capture, OCR, text display, iOS/Android core parity, smooth real-device
preview, non-blocking processing, poor-input and permission/OCR failure handling.
Its evaluation includes memory and heat. Cloud OCR and flash are implementation
choices, so their checks supplement those requirements.

| Requirement/scenario | Android evidence | Limit |
| --- | --- | --- |
| Camera → still → OCR → text | Actual camera and local ML Kit path succeeded on printed Korean/Latin packaging; 10 warmed capture/result/recapture cycles all returned text with expected Korean core and Latin present. | No character-accuracy percentage or OCR-only latency measured. |
| Duplicate taps | First physical cycle used three quick capture taps; stable single result and retry observed. | Exact camera request count comes from deterministic tests, not physical instrumentation. |
| Permission recovery | First denial and second/permanent denial displayed guidance; app settings opened; granting camera permission and retry restored preview. | Android only; restricted/no-camera hardware cases not physically induced. |
| Empty input | Blank paper produced the distinct no-text state; retry returned preview. | Actual blank input, not an injected engine failure. |
| Low light/flash | Dark/partially occluded input with automatic flash returned text; flash-off attempt returned no text and recovered. User later explicitly confirmed the LED fired with room lights completely off. | LED observation is user-reported; no lux measurement or low-light accuracy guarantee. |
| Blur/skew/rotated/malformed input | Expanded native fixture suite passed typed text-or-empty checks for dark, blurred and skewed images; rotated original fixture and malformed-byte rejection passed. | These are generated inputs through the real native engine, not all physical camera conditions. |
| Lifecycle/retry | Background/return during preview restored camera. Backgrounding while visible capture progress was shown returned to usable preview. Long result scrolling exposed recapture action. | Native OCR-processing phase was too short to isolate physically; deterministic tests cover interruption during OCR. |
| Orientation/control reachability | OS-configured landscape and restored portrait retained visible controls. | This does not prove physical sensor rotation or all captured EXIF orientations. |
| UI responsiveness/memory/heat | Profile-mode frame stream, PSS and temperatures recorded below. | Short warmed local-only run on one device; no long-duration or cloud-performance claim. |
| Actual camera/cloud path | Generated Mac image was framed; automation observed cloud attempt 1/2 and the delayed local/wait choice. User took over and reported “느리지만 잘됬음”. | Successful recognition is user-observed; no measured duration, model identity, exact-token assertion or cloud→local re-recognition completion recorded. |
| iOS/Android parity | Android results are recorded here. Separate simulator handoff exists. | Physical iPhone preview, permission, flash, performance and parity remain unverified. |

The physical Android core flow and several recovery scenarios have evidence.
At the initial handoff, README still described the earlier partial Android
checkpoint, including unverified frame time, memory, heat and flash. The user
subsequently authorized this session to update README from this record.
The complete repository E2E matrix is not all passed: physical engine-failure
injection, exact native-OCR lifecycle interruption, network-disconnected operation
and camera-unavailable hardware remain unobserved. Automated tests supplement
these gaps; local-only configuration is not an airplane-mode test.

## Common concurrency correction

Recapture could start another native OCR before the previous call settled and
could delete an input still being read. The fix serializes native dispatch by
completion, drops stale queued transactions, retains input until native reads
settle, and accounts for later productions of the same path during cleanup.
Recapture returns to preview while contained cleanup waits. A native call that
never settles can hold subsequent local work; actual native cancellation is not
claimed. Current queue ownership is per controller; future simultaneous
controller instances would need a shared engine policy.

TDD observed six expected failures with the original implementation and added
an expected failing same-path pending-capture regression during review. Final
controller tests passed 92/92; complete Flutter suite passed 262/262 and analysis
reported zero issues. Independent review checked the final same-path cleanup.

## Automated commands and recorded outcomes

Run from the ASCII checkout with the physical device selected explicitly:

```bash
flutter analyze
flutter test --reporter expanded
flutter test integration_test/native_ocr_smoke_test.dart -d R3CWB00LP0D --no-uninstall
flutter test integration_test/fake_flow_test.dart -d R3CWB00LP0D --no-uninstall
flutter build apk --profile --dart-define=ARTINUS_CLOUD_EVIDENCE=false
flutter build apk --debug
scripts/check_context_budget.sh
git diff --check
```

- Analysis: zero issues; full unit/widget suite: 262 passed.
- Original clean-clone native suite: 3 passed. Expanded native suite: 4 passed
  (poor fixtures/malformed bytes, original recognition, missing-file sanitization,
  ten sequential native requests). Device fake-flow suite: 2 passed.
- Profile local-only build and final default-cloud debug build/install succeeded.
  The temporary profile APK was re-signed with the existing evaluator certificate
  to preserve installed data; repository signing files were not changed.
- Final phone target was restored to the normal default-cloud debug application,
  not an integration-test listener. Subsequent automation was stopped when the
  user chose to capture manually.
- Clean-clone logs: `android-native-clean.log`, `android-native-expanded.log`,
  `android-fake-clean.log`, `analyze-expanded.log`, `tests-expanded.log`,
  `android-default-debug-build.log`, `android-default-install.log` in the second
  temporary checkout. Local artifacts are not durable submission attachments.

### Live cloud service checks

Only generated, non-sensitive fixtures were sent to the authorized Firebase
project. Earlier direct-service checks from the first temporary checkout passed
the fallback model (`gemini-3.5-flash-lite`, 1/1) and failed the primary smoke.
A temporary diagnostic wrapper recorded `FirebaseAIException` and sanitized
`service`/`retryable=true`; its checks did not identify App Check/attestation,
403, 429 or 503 literals. This does not identify the exact remote cause.
The model service tests do not establish controller failover or camera capture.
The later actual-camera success is the separate user observation above.

```bash
flutter test integration_test/live_cloud_smoke_test.dart -d R3CWB00LP0D \
  --no-uninstall --dart-define=RUN_LIVE_OCR=true \
  --dart-define=OCR_DEVICE=Samsung-SM-S911N \
  --dart-define=OCR_GIT_COMMIT=a2a6254-plus-local-gate \
  --dart-define=OCR_CLOUD_ATTEMPT=fallback
```

Use `OCR_CLOUD_ATTEMPT=primary` for the failed primary case. The supplied commit
label is historical metadata from that run, not the final-source identity.
Logs are `android-cloud-primary.log`, `android-cloud-diagnostic.log` and
`android-cloud-fallback.log` in the first temporary checkout. No raw service
message, image, notification, credential or recognized document is committed.

## Profile observations

The VM Extension stream supplied 3,788 `Flutter.Frame` events around warmed
10-cycle capture/recognition/recapture, preview and scrolling. Profile used
`ARTINUS_CLOUD_EVIDENCE=false`. Display render rate was observed once at about
60 Hz; adaptive refresh was not locked.

| Metric | Median | p95 | Maximum |
| --- | ---: | ---: | ---: |
| UI build | 0.469 ms | 1.853 ms | 12.615 ms |
| Raster | 2.752 ms | 4.134 ms | 10.199 ms |
| Whole frame span (`elapsed`) | 4.505 ms | 6.994 ms | 72.471 ms |

Neither build nor raster exceeded 16.667 ms in these samples. Two whole-frame
spans did, so this is not a zero-jank claim. `elapsed` is not OCR duration and
is not simply build plus raster.

- PSS before/after: 272.6 → 296.4 MiB; maximum per-cycle sample 324.8 MiB;
  final-cycle sample 291.5 MiB. A leak conclusion requires longer repeated runs.
- Battery: 38.1 → 39.0°C; AP: 42.7 → 43.7°C; thermal status stayed 0.
  USB charging was active; these samples do not establish sustained heat behavior.
- UI polling durations include ADB and dump overhead and are not OCR latency.
- Sanitized committed artifacts: [profile metrics](evidence/android-2026-09-30/profile-metrics.json)
  and [physical cycles](evidence/android-2026-09-30/physical-cycles.json).
  Raw screenshots, XML, VM authentication URI and recognized packaging text stay
  in temporary local storage; phone notification content is excluded from records.

## Sources

- [Original assignment README, pinned commit](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md): requirements and evaluation criteria.
- [Flutter performance view](https://docs.flutter.dev/tools/devtools/performance) and [UI performance](https://docs.flutter.dev/perf/ui-performance): profile-mode measurement and UI/raster frame interpretation.
- Repository requirements: [PRD](PRD.md); evidence boundaries: [E2E guide](E2E_TESTING.md).
- Separate scope: [iOS simulator handoff](FINAL_VERIFICATION_2026-09-30.md), which does not establish physical iPhone results.
