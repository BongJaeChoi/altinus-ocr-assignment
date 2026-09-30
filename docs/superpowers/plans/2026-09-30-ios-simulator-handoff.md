# iOS simulator verification and public README handoff

User scope: another session owns common OCR production/controller tests and all Android operations. This session owns iOS verification, generated fixture test expansion, simulator camera recovery test, README/evidence and the already-authorized public GitHub visibility. Do not edit or commit the other session's code.

- [x] Public repository visibility changed and verified by explicit request.
- [x] Capture read-only snapshot of other-session common source into an isolated ASCII worktree. Hash the snapshot so results identify the tested source rather than future edits.
- [x] Expand deterministic fixtures with blur and 15-degree tilt: fixture test RED (5 distinct PNGs, expected 7), then GREEN with 7 valid distinct encodings.
- [x] Native OCR smoke handles poor images and malformed bytes as a fourth test; keep the original Korean/Latin/multiline/rotation/empty/missing/ten-sequential tests. Do not require a particular poor-image recognition accuracy.
- [x] Add explicit opt-in iOS simulator test with real camera plugin, accepted disclosure, absent-camera state and repeat recovery action. Never run it on physical hardware or call it permission/capture proof.
- [x] Test other-session source snapshot: analysis, full tests and fake flow; report failures to the owner without changing shared files.
- [x] iOS debug no-codesign build, native/fake smoke, generated-fixture primary/fallback cloud access; record first-session results and later source refresh separately.
- [x] Reset normal simulator target and run native RunnerTests using x86_64, then release no-codesign build; scan release credential containment against the completed Android artifact without Android commands.
- [x] Re-run native/fake/camera recovery and normal simulator target on the current shared-source snapshot after production synchronization. If shared source changes afterward, recheck relevant evidence before a final current-source claim.
- [x] Refresh README/CONTEXT/PRD/E2E and append-only AI log with user-approved hardware limitation, PUBLIC URL, tested devices, exact commands/results/failed experiments and no physical-performance claim.
- [x] Integrate only this session's owned test/documentation paths. Commit/push those paths without consuming another session's staged changes; final source ownership and preserved local Xcode settings remain clearly reported.

Rejected local implementation: this session's shared busy guard was green and independently reviewed, but was removed from deliverable scope after the user assigned common OCR to the other session. Its results are historical experiment evidence, not the final root implementation. Existing root Xcode signing edits are preserved.
