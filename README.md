# ARTINUS Camera OCR

Flutter로 만든 카메라 OCR 과제입니다. 후면 카메라로 정지 이미지를 촬영하고 OCR 결과를 **읽기 전용**으로 보여 줍니다. 과제 원문의 필수 흐름(프리뷰 → 촬영 → OCR → 표시), iOS/Android 패리티, 비동기 처리, 나쁜 입력·권한·OCR 오류 대응, 그리고 AI 사용 근거를 목표로 합니다. [원문 과제](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)

## 현재 평가 상태 — 먼저 읽어 주세요

- 자동화·빌드 검증은 아래 표의 범위에서 수행했습니다.
- **기본 체크아웃은 Firebase가 설정되지 않은 `FirebaseConfigurationPendingGateway`를 사용합니다.** 앱 시작은 가능하지만 사용자가 클라우드 OCR을 시도하면 typed `configuration` 오류로 회복 UI를 표시합니다. Firebase 프로젝트, 모바일 앱 설정, 모델/쿼터/지역 접근을 아직 승인·구성·실행 검증하지 않았으므로 클라우드 OCR은 live-ready가 아닙니다.
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

기본 checkout은 Firebase를 초기화하지 않습니다. 따라서 평가자가 확인할 의도된 흐름은 **촬영 → `configuration` recovery UI → `기기에서 인식`**입니다. 이때 local 선택은 Pigeon을 거쳐 기기에 번들된 Korean ML Kit으로 전환합니다. Firebase 프로젝트가 승인·설정될 때까지 cloud 성공은 기대 결과가 아니며, cloud-ready라고 주장하지 않습니다.

## 구현 구성

```text
OcrScreen (immutable UI)
  └─ OcrFlowController / Riverpod Notifier
      ├─ CameraRepository → official camera 0.12.1
      ├─ FirebaseAiOcrService → firebase_ai (cloud, when configured)
      └─ PigeonLocalOcrService → Kotlin/Swift → bundled Korean ML Kit
```

주요 고정 의존성은 `camera 0.12.1`, `flutter_riverpod 3.4.3`, `firebase_core 4.6.0`, `firebase_ai 3.10.0`, `pigeon 29.0.4`입니다. 네이티브는 Android `com.google.mlkit:text-recognition-korean:16.0.1`, iOS `GoogleMLKit/TextRecognitionKorean: 8.0.0`을 잠급니다. Pigeon 산출물은 생성기로만 관리하며 수동 편집하지 않습니다.

### OCR 및 시간 경계

1. 성공한 촬영 뒤 클라우드 OCR을 먼저 시도합니다(구성된 Firebase에서만).
2. 하나의 transaction에는 최대 2회의 cloud attempt만 허용합니다. 명확한 transient 오류만 한 번 재시도합니다.
3. 이미지 준비부터 재시도까지 공유하는 누적 예산은 **60초**입니다. **10초**에는 요청을 취소하지 않고 `기기에서 인식` 또는 계속 기다리기를 제공합니다. 60초 뒤의 늦은 결과는 transaction ID로 무시합니다.
4. 사용자가 local을 선택하거나 cloud가 회복 불가 상태가 되면, 공식 Korean ML Kit Pigeon bridge로 순차적으로 전환합니다. cloud와 local을 병렬 실행하지 않습니다.

이미지 준비는 isolate에서 수행하고, 과대 입력은 크기/픽셀/업로드 바이트 한도 안으로 정규화합니다. UI는 진행 상태와 중복 촬영 차단을 갖고, stale 결과가 새 촬영을 덮어쓰지 않도록 테스트합니다. 이는 구조·자동화 근거이며 실기기 성능 측정 결과는 아닙니다.

### 개인정보 및 임시 파일

- 첫 실행에서 카메라 사용 목적, cloud 전송, 영구 로컬 저장을 하지 않는다는 고지를 보여 줍니다.
- 캡처 원본(canonical)은 cloud 결과 화면에서도 사용자가 `기기에서 인식`을 선택할 수 있도록 유지될 수 있습니다. 재촬영과 controller dispose에서 해당 transaction의 소유 파일을 정리합니다. 시작 시 sweep은 앱 cache root의 `altinus_ocr_` 접두 derivative 파일만 대상으로 하며, camera root를 sweep하지 않습니다. 갤러리 저장과 OCR 이력은 없습니다.
- 로그에는 이미지, 인식 텍스트, raw 모델 응답, 자격 증명, 로컬 경로를 기록하지 않습니다.
- 이 정책은 코드와 deterministic test로 확인한 동작입니다. 외부 cloud 사업자의 보존 정책이나 실제 기기 파일 수명은 live/device 검증 전에는 주장하지 않습니다.

## 검증

아래는 문서 커밋 전 소스 커밋 `be032cf5b80b9362638fd08a9da7c8e76afdce19`에서 2026-09-29 KST에 관찰한 release gate입니다. 결과가 없는 실기기 항목을 통과로 해석하면 안 됩니다.

| Gate | 관찰 결과 |
| --- | --- |
| `flutter pub get`, Pigeon 재생성, 생성물 diff | PASS — 생성 Dart/Kotlin/Swift diff 없음 |
| `dart format --output=none --set-exit-if-changed lib test integration_test pigeons` | PASS |
| `flutter test` | PASS — 200 tests |
| `flutter analyze` (현재 한글 상위 경로) | BLOCKED/FAIL — 분석 전에 LSP `FormatException: Unterminated string`; 아래 ASCII 경로 검증 사용 |
| `flutter build apk --release` | PASS — universal release APK `84.5MB` (Flutter 보고값) |
| `flutter build ios --release --no-codesign` (현재 한글 상위 경로) | BLOCKED/FAIL — SwiftPM이 percent-encoded Firebase package 경로의 `pubspec.yaml`을 찾지 못함; 아래 ASCII 경로 검증 사용 |
| Firebase live cloud / native smoke / 실기기 matrix | BLOCKED — 승인된 Firebase 프로젝트와 Android/iPhone 하드웨어 없음 |

원본 작업 경로의 한글 상위 디렉터리는 Flutter analyzer LSP framing과 Xcode SwiftPM percent-encoding을 깨뜨립니다. 소스를 변경하거나 Xcode를 우회 수정하지 않고, **ASCII 전용 임시 clone**에서 같은 Flutter SDK로 분석·테스트·Android/iOS build를 실행합니다.

첫 README 커밋 `766f8adcec2c4d8811c23a333cc68962afaa0d1e`을 ASCII 임시 clone(`ARTINUS_CLONE_DIR`)에서 새로 확인했습니다: `flutter pub get`, Pigeon 재생성 후 `git diff --exit-code`, `flutter analyze`(4.3초), `flutter test`(200 tests), Android debug build, iOS debug no-codesign build 모두 PASS. 관찰한 universal debug APK는 **189M**, iOS debug `Runner.app` 디렉터리는 **171M**였습니다. iOS build 뒤 `git status --porcelain --untracked-files=all`은 Xcode가 생성한 SwiftPM workspace metadata 두 디렉터리만 보였고, tracked tree는 clean이며 `git diff --exit-code`도 PASS했습니다. 같은 ASCII clone의 release도 Android universal APK **84.5MB**, iOS `Runner.app` **68.8MB**로 PASS했습니다. 이는 archive/store 크기나 실기기 실행 증명이 아닙니다.

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

## 근거

- [과제 원문](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)
- [Flutter integration test](https://docs.flutter.dev/testing/integration-tests), [camera package](https://pub.dev/packages/camera), [Pigeon](https://pub.dev/packages/pigeon)
- [Firebase AI Logic for Flutter](https://firebase.google.com/docs/ai-logic/get-started?api=dev&platform=flutter), [ML Kit Android](https://developers.google.com/ml-kit/vision/text-recognition/v2/android), [ML Kit iOS](https://developers.google.com/ml-kit/vision/text-recognition/v2/ios)
