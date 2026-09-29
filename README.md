# ARTINUS Camera OCR

Flutter로 만든 카메라 OCR 과제입니다. 후면 카메라 프리뷰에서 정지 이미지를 촬영하고, Firebase AI Logic으로 먼저 인식한 뒤 결과를 읽기 전용으로 보여 줍니다. 클라우드가 늦거나 실패하면 앱에 번들된 한국어 ML Kit로 전환할 수 있습니다. 과제 원문의 필수 흐름, iOS/Android 공통 동작, 비동기 처리, 권한·입력·OCR 오류 대응, AI 사용 근거를 구현 범위로 삼았습니다. [원문 과제](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)

## 빠른 시작

필요 도구는 Flutter **3.47.5** / Dart **3.13.4**, Java 17이며, iOS는 Xcode **26.1.1** / CocoaPods **1.16.2**에서 검증했습니다. 최소 플랫폼은 Android API 24, iOS 15.5입니다.

```bash
flutter pub get
flutter run -d <android-or-ios-device>
```

기본 debug 실행은 별도 Firebase 설정 없이 전용 Spark 프로젝트의 App Check를 거쳐 `gemini-3.8-flash` 클라우드 OCR을 먼저 사용합니다. 일시적 과부하·quota·timeout·5xx이면 약 1초 뒤 `gemini-3.5-flash-lite`로 한 번만 재시도합니다. iPhone 실기기는 평가자의 Apple Development 서명 선택이 필요할 수 있습니다. Flutter 3.47의 혼합 SwiftPM/CocoaPods 초기화에서 깨끗한 iOS 체크아웃이 `Pods_Runner` 링크 오류를 한 번 보이면 아래 명령으로 native dependency를 먼저 생성한 뒤 다시 실행합니다.

```bash
flutter build ios --debug --no-codesign
flutter run -d <ios-device>
```

Firebase를 전혀 초기화하지 않고 번들된 기기 OCR만 확인하려면 다음 명시적 escape hatch를 사용합니다.

```bash
flutter run -d <android-or-ios-device> \
  --dart-define=ARTINUS_CLOUD_EVIDENCE=false
```

## 과제 평가용 자격 증명 예외

이 저장소에는 평가자의 빌드 절차를 줄이기 위해 다음 **과제 전용·폐기 가능한** 자료를 의도적으로 포함합니다.

- Android 전용 평가 keystore와 `key.properties`: 기본 debug/profile/release APK가 Firebase에 등록된 동일 인증서로 서명됩니다.
- iOS App Check debug token: Flutter debug mode에서만 활성화됩니다. profile/release는 이를 활성화하지 않고 fail closed합니다.

이는 production 자격 증명 관리 방식이 아닙니다. Firebase 공식 지침상 App Check debug token은 비공개로 취급해야 하지만, 사용자가 전용 Spark/무과금 프로젝트의 과제 전달 편의를 위해 이 제한된 예외를 승인했습니다. 저장소에는 Gemini API key, service-account key, Firebase CLI token, Apple 계정·세션, `.p12`, provisioning profile, production signing asset가 없습니다. iOS와 Android release 산출물에서 debug token 값과 소스 식별자가 모두 없음을 최종 스캔했고, 평가 종료 후 token과 인증서 등록을 폐기합니다.

Firebase AI monitoring은 사용량·지연·오류 확인을 위해 사용자의 명시적 선택으로 100% sampling 상태입니다. 입력과 출력이 sampling될 수 있으므로 민감한 사진을 테스트에 사용하지 마세요. 앱의 첫 화면도 이미지가 cloud로 전송되지만 기기에는 영구 저장하지 않는다는 조건을 안내합니다.

## 구현 구성

```text
OcrScreen (immutable UI)
  └─ OcrFlowController / Riverpod Notifier
      ├─ CameraRepository → official camera 0.12.1
      ├─ FirebaseAiOcrService → Firebase AI Logic + App Check
      └─ PigeonLocalOcrService → Kotlin/Swift → bundled Korean ML Kit
```

- **Flutter + 수동 Riverpod:** 하나의 상태/UI 흐름으로 플랫폼 패리티를 맞추고 `NotifierProvider` override로 외부 adapter를 격리합니다. 작은 과제에 state code generation 단계는 추가하지 않았습니다.
- **Firebase AI Logic:** 공식 Flutter SDK와 구조화 JSON 응답을 사용합니다. 첫 시도는 `gemini-3.8-flash`, 재시도 가능한 실패 뒤 마지막 한 번은 모델별 일일 한도가 더 큰 `gemini-3.5-flash-lite`입니다. Firebase gateway의 공유 제한까지 분리된다고 주장하지 않습니다. 이미지는 cloud로 전송되며 네트워크·서비스·quota 지연이 존재합니다. 활성 App Check 인스턴스를 AI client에 명시적으로 전달합니다.
- **Pigeon + 공식 ML Kit:** raw method-channel payload 대신 생성된 typed Dart/Kotlin/Swift 경계를 사용합니다. Android `text-recognition-korean:16.0.1`, iOS `GoogleMLKit/TextRecognitionKorean: 8.0.0`을 앱에 번들해 오프라인 fallback을 제공합니다.
- **공식 camera:** rear camera preview/capture와 lifecycle을 adapter 뒤에 둡니다. 실제 권한·방향·flash·성능은 플랫폼 실기기 검증이 필요합니다.
- **제한된 이미지 준비:** isolate에서 방향, decode, 픽셀 수, 업로드 바이트를 제한합니다. 자동 deskew나 임의 보정은 과제 범위를 넘어 추가하지 않았습니다.

주요 고정 의존성은 `camera 0.12.1`, `flutter_riverpod 3.4.3`, `firebase_core 4.6.0`, `firebase_app_check 0.4.2`, `firebase_ai 3.10.0`, `pigeon 29.0.4`입니다. Gradle lock, `Podfile.lock`, Runner project/workspace의 `Package.resolved`를 추적합니다. Pigeon 산출물은 생성기로만 관리합니다.

## OCR 흐름과 복구 정책

1. 촬영 파일 ownership을 확보한 뒤 cloud OCR을 먼저 시작합니다.
2. 하나의 transaction은 최대 두 번의 cloud attempt만 허용합니다. `408`, `429`/quota, `5xx`와 transport failure만 1,000–1,250ms 뒤 대체 모델로 한 번 재시도합니다. 구성·지역·safety/recitation·잘못된 입력·응답 계약 오류는 재시도하지 않습니다. 화면에는 `1/2`, `2/2`를 표시합니다.
3. 이미지 준비부터 재시도까지 누적 cloud budget은 **60초**입니다. **10초**가 지나면 `기기에서 인식` 또는 `조금 더 기다리기`를 선택할 수 있습니다.
4. cloud 오류의 기술 원인·코드·raw message는 화면에 노출하지 않습니다. 자연스러운 재촬영 또는 기기 OCR 전환만 제공합니다.
5. 기기 OCR은 cloud와 병렬 실행하지 않습니다. 전환·마감 뒤 늦게 도착한 결과는 transaction ID로 무시합니다.
6. 읽을 문자가 없는 사진은 정상적인 `noReadableText` 결과이며 시스템 오류로 취급하지 않습니다.

Firebase/ML Kit SDK의 이미 시작된 native 호출을 실제로 취소한다고 주장하지 않습니다. 상태 소유권과 늦은 결과 무시를 통해 UI 일관성을 지킵니다.

## 개인정보와 임시 파일

- 첫 실행에서 카메라 목적, cloud 전송, 영구 로컬 저장 없음과 재시도 조건을 안내합니다.
- cloud 결과 뒤 기기 OCR로 전환할 수 있어 transaction 동안 원본이 유지될 수 있습니다. 정상 흐름에서는 재촬영 또는 controller dispose가 소유 파일을 정리합니다.
- 비정상 종료 시 OS camera temp 파일은 OS 정리 전까지 남을 수 있습니다. 앱 시작 sweep은 앱 cache root의 `altinus_ocr_` derivative만 대상으로 하며 camera root 전체를 지우지 않습니다.
- 갤러리 저장과 OCR 이력은 없습니다. 앱 로그에는 이미지, 인식 텍스트, raw 모델 응답, token, password, 로컬 경로를 기록하지 않습니다.

## 검증 상태

아래 로컬 결과는 2026-09-29 KST, 코드 증거 커밋 `7152334`의 깨끗한 ASCII 경로 clone에서 관찰했습니다. live cloud 성공은 `899bf4c`에서 관찰했으며, `7152334` 최종 재검증은 quota/capacity 오류로 차단됐습니다. 결과가 없는 실기기 항목을 통과로 해석하면 안 됩니다.

| Gate | 관찰 결과 |
| --- | --- |
| `flutter pub get`, Pigeon 재생성, tracked diff | PASS — 생성물 byte diff와 tracked 변경 없음 |
| `flutter analyze` | PASS — 0 issues |
| `flutter test` | PASS — 228 tests |
| fake full-flow integration | PASS — 2 tests |
| Android debug/release build | PASS — release universal APK 86.1 MB |
| Android app unit test + lint | PASS — 422 tasks, build successful |
| Android release signing | PASS — Firebase에 유일하게 등록된 과제 인증서 SHA-256과 일치 |
| iOS debug/release no-codesign build | PASS — release `Runner.app` 69.4 MB |
| iOS simulator native OCR | PASS — iOS 18.5, real Pigeon → Swift → Korean ML Kit; Korean/Latin core tokens, multiline/newline, rotated, no-text, missing input, 10 sequential OCR requests |
| iOS simulator fake full-flow | PASS — disclosure, pause/resume, cloud retry, 10-second local selection, stale cloud rejection |
| iOS simulator RunnerTests | PASS — 9/9 native policy tests on x86_64 |
| iOS release credential containment | PASS — evaluator debug token 값/식별자 없음 |
| Android release credential containment | PASS — evaluator debug token 값/식별자 없음 |
| iOS simulator live cloud smoke | PARTIAL — `899bf4c` PASS; `7152334` 재검증은 2회 service 실패 후 진단 요청에서 quota/capacity 오류 확인 |
| Firebase AI monitoring (developer-observed remote evidence) | OBSERVED — iOS 요청/성공·실패/지연/token 집계 생성 확인; 콘솔 권한 없이는 재현 불가 |
| Android physical device | BLOCKED — 최종 검증 시 연결된 기기 없음 |
| iPhone physical device | BLOCKED — 최종 검증 시 연결된 기기 없음 |

원본 개발 경로의 한글 상위 디렉터리에서는 Flutter 3.47.5 analyzer LSP framing과 Xcode SwiftPM percent-encoding 문제가 재현됩니다. 소스 우회 변경 대신 ASCII-only clone을 최종 기준으로 사용했습니다. 깨끗한 clone에서 iOS integration test를 바로 실행하면 혼합 package 초기화가 `Pods_Runner` 링크 오류를 낼 수 있었고, 위 빠른 시작의 iOS debug no-codesign build를 먼저 실행하자 동일 clone에서 live smoke가 통과했습니다.

재현 명령:

```bash
flutter pub get
dart run pigeon --input pigeons/platform_apis.dart
git diff --exit-code
flutter analyze
flutter test
flutter test -d flutter-tester integration_test/fake_flow_test.dart
flutter build apk --debug
./android/gradlew -p android :app:testDebugUnitTest :app:lintDebug
flutter build apk --release
flutter build ios --debug --no-codesign
flutter build ios --release --no-codesign
./scripts/test_verify_release_containment.sh
./scripts/verify_release_containment.sh
```

live cloud smoke는 개인 정보가 없는 생성 fixture만 사용합니다.

```bash
flutter test integration_test/live_cloud_smoke_test.dart -d <device-id> \
  --dart-define=RUN_LIVE_OCR=true \
  --dart-define=OCR_DEVICE=<public-device-model> \
  --dart-define=OCR_GIT_COMMIT=$(git rev-parse HEAD) \
  --dart-define=OCR_CLOUD_ATTEMPT=primary
```

대체 모델 자체를 검증할 때만 마지막 값을 `fallback`으로 바꿉니다.

상세 원격 구성과 실행 증거는 `.superpowers/sdd/firebase-cloud-evidence-report.md`에 기록합니다.

## AI 사용과 검증 흔적

상세 append-only 기록은 [docs/AI_PROMPT_LOG.md](docs/AI_PROMPT_LOG.md)에 있습니다.

- **Used as-is:** 없음. 제안은 코드·테스트·공식 문서 또는 실제 build/run으로 확인한 뒤 채택했습니다.
- **Adopted:** Riverpod transaction state machine, typed Pigeon boundary, cloud-first + sequential local fallback, 생성 fixture, App Check가 적용된 Firebase AI client.
- **Modified:** 180초 watchdog 제안을 사용자 결정에 따라 누적 60초로 줄였고, 10초 시점에 계속 기다리기/기기 인식 선택을 제공했습니다. 단일 거대 구현 agent 대신 설계·bounded executor·review 역할을 분리했습니다. `firebase_ai 3.10.0`이 408/429의 구조화된 상태·header를 공개하지 않는 한계 때문에, adapter 내부에서 공식 상태 토큰과 문구의 좁은 허용 목록만 분류합니다. 패키지 업그레이드 때 이 예외를 재검증합니다.
- **Rejected:** raw HTTP/Dio 중복 구현, 광범위한 예외 문자열 추측, 모든 CocoaPod 강제 static 전환, client Gemini key, billing 연결, 기술 오류 코드의 사용자 노출을 채택하지 않았습니다.

## 남은 실기기 게이트

Android와 iPhone 각각에서 다음을 확인해야 physical parity나 flash-ready를 주장할 수 있습니다.

1. permission/settings, 실제 preview/capture, 한국어·라틴 OCR 및 no-text 입력
2. cloud/local 전환, offline local, 10초/60초, background/resume, rotation, rapid taps
3. flash 노출·점등·복귀, 10회 반복 촬영, frame time, memory/CPU/발열
4. Android 외부 설치 Play Integrity와 iPhone debug provider의 실제 token 승인

실기기 증거가 없으므로 이 저장소는 자동화·빌드·iOS 시뮬레이터 cloud/native OCR까지만 검증된 상태입니다. push, 앱스토어 업로드, 과제 제출은 수행하지 않았습니다.

## 근거

- [과제 원문](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)
- [Flutter integration test](https://docs.flutter.dev/testing/integration-tests), [camera package](https://pub.dev/packages/camera), [Pigeon](https://pub.dev/packages/pigeon)
- [Firebase AI Logic for Flutter](https://firebase.google.com/docs/ai-logic/get-started?api=dev&platform=flutter), [모델](https://firebase.google.com/docs/ai-logic/models), [가격](https://firebase.google.com/docs/ai-logic/pricing), [모니터링](https://firebase.google.com/docs/ai-logic/monitoring), [할당량](https://firebase.google.com/docs/ai-logic/quotas), [오류 코드](https://firebase.google.com/docs/ai-logic/error-codes)
- [Gemini API 오류·재시도 지침](https://ai.google.dev/gemini-api/docs/troubleshooting), [Gemini 3.5 Flash-Lite](https://ai.google.dev/gemini-api/docs/models/gemini-3.5-flash-lite)
- [Firebase App Check debug provider](https://firebase.google.com/docs/app-check/flutter/debug-provider), [Play Integrity outside Google Play](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [ML Kit Android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android), [ML Kit iOS](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios)
