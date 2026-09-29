# ARTINUS Camera OCR

Flutter로 만든 카메라 OCR 과제입니다. 후면 카메라로 정지 이미지를 촬영하고 OCR 결과를 **읽기 전용**으로 보여 줍니다. 과제 원문의 필수 흐름(프리뷰 → 촬영 → OCR → 표시), iOS/Android 패리티, 비동기 처리, 나쁜 입력·권한·OCR 오류 대응, 그리고 AI 사용 근거를 목표로 합니다. [원문 과제](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)

## 현재 평가 상태 — 먼저 읽어 주세요

- 자동화·빌드 검증은 아래 표의 범위에서 수행했습니다.
- **기본 체크아웃은 Firebase가 설정되지 않은 `FirebaseConfigurationPendingGateway`를 사용합니다.** 촬영 뒤 typed pending-configuration 신호만 자동으로 기기 OCR로 이어지므로 별도 오류 화면이나 recovery tap 없이 결과를 확인할 수 있습니다. 실제로 구성된 Firebase gateway의 configuration/service 실패는 자동 전환하지 않고 회복 UI를 유지합니다. Firebase 프로젝트, 모바일 앱 설정, 모델/쿼터/지역 접근을 아직 승인·구성·실행 검증하지 않았으므로 클라우드 OCR은 live-ready가 아닙니다.
- Android 실기기와 iPhone 실기기 검증은 아직 없습니다. 따라서 카메라 프리뷰, 실제 캡처, 한국어 인식 정확도, 권한/설정 이동, 성능·메모리·발열, 라이프사이클, 10회 반복 촬영의 플랫폼 패리티는 **미입증**입니다.
- 플래시는 코드상 지원을 탐지한 경우에만 자동/끔 UI를 보이지만, 양 플랫폼에서 실제 점등·복귀·패리티가 검증되지 않았습니다. **flash-ready라고 주장하지 않습니다.** Task 13에서는 제거하지 않았으며, 출시 전 숨김/제거 여부는 루트 release decision으로 남습니다.

## 빠른 시작

필요 도구: Flutter **3.47.5** / Dart **3.13.4**, Xcode **26.1.1**, CocoaPods **1.16.2**, Java 17. 최소 플랫폼은 Android API 24, iOS 15.5입니다.

```bash
flutter pub get
dart run pigeon --input pigeons/platform_apis.dart
flutter run -d <android-or-ios-device>
```

Firebase를 임의로 만들거나 설정하지 마세요. 승인된 기존 프로젝트가 제공된 뒤에만 `flutterfire configure`와 Firebase 초기화를 추가하고, 양 실기기에서 `RUN_LIVE_OCR=true` smoke test를 실행해야 합니다.

### Firebase 없는 평가 모드

기본 checkout은 Firebase를 초기화하지 않습니다. 따라서 평가자가 확인할 의도된 흐름은 **촬영 → pending configuration 감지 → 기기 OCR → 결과**입니다. controller는 메시지나 구현 클래스가 아니라 gateway가 제공하는 명시적 capability와 typed `configuration` 실패를 함께 확인합니다. 승인된 Firebase gateway가 구성되면 cloud-first를 유지하며, 그 gateway에서 발생한 configuration/service 실패는 기존 recovery 정책을 따릅니다. Firebase 프로젝트가 승인·설정될 때까지 cloud 성공은 기대 결과가 아니며, cloud-ready라고 주장하지 않습니다.

## 구현 구성

```text
OcrScreen (immutable UI)
  └─ OcrFlowController / Riverpod Notifier
      ├─ CameraRepository → official camera 0.12.1
      ├─ FirebaseAiOcrService → firebase_ai (cloud, when configured)
      └─ PigeonLocalOcrService → Kotlin/Swift → bundled Korean ML Kit
```

주요 고정 의존성은 `camera 0.12.1`, `flutter_riverpod 3.4.3`, `firebase_core 4.6.0`, `firebase_ai 3.10.0`, `pigeon 29.0.4`입니다. 네이티브는 Android `com.google.mlkit:text-recognition-korean:16.0.1`, iOS `GoogleMLKit/TextRecognitionKorean: 8.0.0`을 잠급니다. Android app-resolved 구성은 Gradle lock, CocoaPods는 `Podfile.lock`, SwiftPM은 Runner project/workspace의 동일한 `Package.resolved` 두 파일로 재현합니다. 현재 `firebase_ai`는 SwiftPM을 직접 지원하지 않아 iOS는 CocoaPods와 FlutterFire Swift package가 섞인 구성입니다. Pigeon 산출물은 생성기로만 관리하며 수동 편집하지 않습니다.

### 기술 선택과 트레이드오프

- **Flutter:** 하나의 상태/UI 구현으로 iOS·Android 흐름을 맞추기 위해 선택했습니다. 반면 카메라, ML Kit, 권한·lifecycle은 플랫폼별 동작과 도구 체인을 별도로 검증해야 합니다.
- **수동 Riverpod:** `NotifierProvider` override로 controller와 외부 adapter를 격리하면서 작은 과제에 code generation 단계를 늘리지 않습니다. 상태·provider 연결 boilerplate는 직접 유지합니다.
- **Firebase AI Logic:** 공식 모바일 SDK의 구조화 응답과 cloud-first 확장성을 사용합니다. 승인된 Firebase provisioning과 live model/quota 검증이 아직 없고 App Check도 평가 build에서는 제외했습니다. 이미지가 cloud로 전송되므로 개인정보·네트워크 지연·서비스 가용성 비용이 있습니다.
- **Pigeon + 공식 ML Kit:** raw channel payload 대신 typed Dart/Kotlin/Swift 경계를 두고 오프라인 Korean OCR을 제공합니다. recognizer가 앱 binary 크기를 늘리고 두 native host와 contract를 유지해야 합니다. platform error code는 domain failure로만 매핑하며 UI에 노출하지 않습니다.
- **공식 camera:** Flutter team package로 preview/capture/lifecycle 기반을 공유합니다. 실제 권한, 방향, flash, 임시 파일 수명과 성능은 양 실기기 증거가 필요합니다.
- **bounded image preparation:** isolate에서 방향·decode·픽셀·업로드 크기를 제한해 UI/메모리 위험을 경계합니다. 축소에는 OCR 품질 비용이 있고 decode/encode 자체의 CPU 비용도 있으므로 자동 보정·deskew는 근거 없이 추가하지 않았습니다.

### OCR 및 시간 경계

1. 성공한 촬영 뒤 클라우드 OCR을 먼저 시도합니다(구성된 Firebase에서만).
2. 하나의 transaction에는 최대 2회의 cloud attempt만 허용합니다. 명확한 transient 오류만 한 번 재시도합니다.
3. 이미지 준비부터 재시도까지 공유하는 누적 예산은 **60초**입니다. **10초**에는 `기기에서 인식` 또는 계속 기다리기를 제공합니다. Firebase/ML Kit SDK의 이미 시작된 호출을 실제로 중단할 수 있다고 주장하지 않으며, 전환·마감 뒤의 늦은 결과를 transaction ID로 무시합니다.
4. pending Firebase configuration은 자동으로, 사용자가 local을 선택하거나 cloud가 회복 불가 상태가 되면 명시적으로 공식 Korean ML Kit Pigeon bridge로 순차 전환합니다. cloud와 local을 병렬 실행하지 않습니다.

이미지 준비는 isolate에서 수행하고, 과대 입력은 크기/픽셀/업로드 바이트 한도 안으로 정규화합니다. UI는 진행 상태와 중복 촬영 차단을 갖고, stale 결과가 새 촬영을 덮어쓰지 않도록 테스트합니다. 이는 구조·자동화 근거이며 실기기 성능 측정 결과는 아닙니다.

### 개인정보 및 임시 파일

- 첫 실행에서 카메라 사용 목적, cloud 전송, 영구 로컬 저장을 하지 않는다는 고지를 보여 줍니다.
- 캡처 원본(canonical)은 cloud 결과 화면에서도 사용자가 `기기에서 인식`을 선택할 수 있도록 유지될 수 있습니다. 정상 흐름에서는 재촬영과 controller dispose가 해당 transaction의 소유 파일을 정리합니다. 비정상 종료 시 OS camera temp의 canonical은 앱이 다시 sweep하지 않으며 OS 정리 전까지 남을 수 있습니다. 시작 시 sweep은 앱 cache root의 `altinus_ocr_` 접두 derivative 파일만 대상으로 하고 camera root를 sweep하지 않습니다. 갤러리 저장과 OCR 이력은 없습니다.
- 로그에는 이미지, 인식 텍스트, raw 모델 응답, 자격 증명, 로컬 경로를 기록하지 않습니다.
- 이 정책은 코드와 deterministic test로 확인한 동작입니다. 외부 cloud 사업자의 보존 정책이나 실제 기기 파일 수명은 live/device 검증 전에는 주장하지 않습니다.

## 검증

아래는 pre-release 기능/잠금 소스 커밋 `e930239`, `11169d6`에서 2026-09-29 KST에 관찰한 release gate입니다. 결과가 없는 실기기 항목을 통과로 해석하면 안 됩니다.

| Gate | 관찰 결과 |
| --- | --- |
| `flutter pub get`, Pigeon 재생성, 생성물 diff | PASS — 생성 Dart/Kotlin/Swift diff 없음 |
| handwritten Dart format (`lib/src/generated` 제외) | PASS — 43 files, 0 changed |
| `flutter test` | PASS — 213 tests |
| `flutter analyze` (현재 한글 상위 경로) | BLOCKED/FAIL — 분석 전에 LSP `FormatException: Unterminated string`; 아래 ASCII 경로 검증 사용 |
| `flutter build apk --debug` | PASS — Gradle strict lock 적용 상태 |
| Android `:app:testDebugUnitTest :app:lintDebug` | PASS |
| `flutter build ios --debug --no-codesign` (현재 한글 상위 경로) | BLOCKED/FAIL — SwiftPM이 percent-encoded Firebase package 경로의 `pubspec.yaml`을 찾지 못함; 아래 ASCII 경로 검증 사용 |
| Firebase live cloud / native smoke / 실기기 matrix | BLOCKED — 승인된 Firebase 프로젝트와 Android/iPhone 하드웨어 없음 |

원본 작업 경로의 한글 상위 디렉터리는 Flutter analyzer LSP framing과 Xcode SwiftPM percent-encoding을 깨뜨립니다. 소스를 변경하거나 Xcode를 우회 수정하지 않고, **ASCII 전용 임시 clone**에서 같은 Flutter SDK로 분석·테스트·Android/iOS build를 실행합니다.

기존 release 증거에 더해 pre-release 문서 커밋 `7ac0e93046bbbf61f12e4b13237547053873aa73`을 ASCII 임시 clone(`ARTINUS_CLONE_DIR`)에서 다시 검증했습니다. Pigeon 재생성, analyze, 213-test suite, 2 fake integration tests, strict-lock Android debug build와 app test/lint, iOS debug no-codesign build가 PASS했고 build/resolve 뒤 tracked tree도 clean이었습니다. 생성 Pigeon Dart/Kotlin/Swift는 29.0.4 출력 그대로이며 재생성 byte diff가 없습니다. 생성기가 남기는 trailing spaces는 손으로 고치지 않았고, whitespace 검사는 handwritten source 범위에만 적용합니다. Gradle lock은 app-resolved 구성과 Flutter assemble에 필요한 runtime 구성을 포함하며 지원되는 `:app:dependencies --write-locks`로 생성했습니다. Xcode가 생성한 Runner project/workspace `Package.resolved`는 서로 같은 해시이고 `xcodebuild -resolvePackageDependencies` 뒤에도 유지됩니다. CocoaPods `Podfile.lock`도 유지합니다.

개발/재현 명령은 다음과 같습니다.

```bash
ARTINUS_CLONE_ROOT="$(mktemp -d /tmp/artinus-ocr.XXXXXX)"
ARTINUS_CLONE_DIR="$ARTINUS_CLONE_ROOT/artinus-ocr"
git clone . "$ARTINUS_CLONE_DIR"
cd "$ARTINUS_CLONE_DIR"
flutter pub get
dart run pigeon --input pigeons/platform_apis.dart
git diff --exit-code
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

`flutter build apk`는 ABI split이 아닌 universal APK입니다. debug와 release 크기를 서로 비교하거나 release 수치로 debug 크기를 추정하지 않습니다.

## AI 사용과 검증 흔적

상세한 append-only 기록은 [docs/AI_PROMPT_LOG.md](docs/AI_PROMPT_LOG.md)에 있습니다. 요약:

- **Used as-is:** 없음. AI 결과는 모두 코드·테스트·리뷰로 확인하거나 수정한 뒤에만 채택했습니다.
- **Adopted:** 검증 가능한 Riverpod transaction state machine, typed Pigeon Korean OCR/settings 경계, 생성 가능한 fixed-image fixture 접근을 RED→GREEN 테스트와 리뷰를 거쳐 채택했습니다.
- **Modified / verified — fixed clock:** review가 full-flow E2E의 `DateTime.now` 의존을 지적했고, 고정 UTC clock override를 주입했습니다. `fake_flow_test.dart` 1/1 통과로 wall-clock 의존 제거를 확인했습니다.
- **Modified / verified — fixture disposal:** root review가 생성 fixture의 `TextPainter` dispose 누락을 지적했고, `finally`에서 dispose하도록 바꿨습니다. 전체 200-test suite 재실행으로 확인했습니다.
- **Rejected:** 예외 메시지로 HTTP 상태를 추론하거나 raw `HttpClient`/불필요한 Dio를 넣는 제안, 모든 CocoaPod의 static framework 전환(중복 심볼), Firebase 프로젝트·billing·App Check의 임의 변경을 거절했습니다.

## 남은 release gates

1. 사용자가 승인한 정확한 Firebase project ID로 Android/iOS 설정을 만들고, `gemini-3.8-flash`의 live model/quota/location을 양 실기기에서 기록합니다.
2. Android와 iPhone 각각에서 permission/settings, preview/capture, cloud/local, Korean glyph/recognition, bad input, lifecycle, orientation, rapid taps, 10-cycle, 10s/60s, profile frame/memory/CPU/heat을 commit·기기·OS·build mode와 함께 기록합니다.
3. 위 결과가 나오기 전에는 cloud-ready, physical parity, 또는 flash-ready라고 표시하지 않습니다.
4. Android/iOS bundle identifier는 아직 `com.example...`이고 Android release도 debug signing을 사용합니다. 배포 식별자·서명·provisioning은 release 설정 전환이 필요합니다.

## 근거

- [과제 원문](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)
- [Flutter integration test](https://docs.flutter.dev/testing/integration-tests), [camera package](https://pub.dev/packages/camera), [Pigeon](https://pub.dev/packages/pigeon)
- [Firebase AI Logic for Flutter](https://firebase.google.com/docs/ai-logic/get-started?api=dev&platform=flutter), [ML Kit Android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android), [ML Kit iOS](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios)
