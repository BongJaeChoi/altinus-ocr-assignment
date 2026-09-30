# ARTINUS Camera OCR

카메라로 촬영한 이미지에서 글자를 읽고 결과를 보여주는 Flutter 앱입니다. Firebase AI Logic을 먼저 사용하고, 응답이 늦거나 실패하면 기기의 한국어 ML Kit로 전환할 수 있습니다. 결과는 읽기 전용이며 편집·복사·이력 저장은 구현하지 않았습니다.

## 실행

- Flutter 3.47.5 / Dart 3.13.4, Java 17
- iOS 빌드 환경: Xcode 26.1.1 / CocoaPods 1.16.2
- 최소 지원 버전: Android API 24 / iOS 15.5

한글 상위 경로에서 Flutter/Xcode 빌드 오류가 재현되어 영문 경로에 clone한 뒤 실행하는 것을 권장합니다.

```bash
flutter pub get
flutter run -d <device-id>
```

평가용 Firebase Spark 프로젝트 설정, Android 서명 파일, iOS App Check debug token이 포함돼 있어 기본 debug 실행에 별도 Firebase 설정은 필요하지 않습니다. 이 자료는 과제 평가용이며 평가 종료 후 폐기할 예정입니다. 실물 iPhone에서는 Apple Development 서명이 필요할 수 있습니다.

처음 iOS를 빌드할 때 `Pods_Runner` 링크 오류가 발생하면 다음 명령을 먼저 실행합니다.

```bash
flutter build ios --debug --no-codesign
```

클라우드를 사용하지 않고 기기 OCR만 실행하려면 다음 옵션을 추가합니다.

```bash
flutter run -d <device-id> --dart-define=ARTINUS_CLOUD_EVIDENCE=false
```

## 구조와 기술 선택

Flutter로 두 플랫폼의 UI와 상태 흐름을 공유했습니다. UI(`OcrScreen`), 작업 관리(`OcrFlowController`), 카메라·OCR adapter를 나눠 플랫폼 차이를 분리하고 오류와 비동기 경합을 각각 테스트할 수 있도록 했습니다. 촬영 ID로 이전 응답을 걸러내고, 이미지 디코딩·방향 보정·축소는 isolate에서 처리해 UI 작업을 줄였습니다.

| 기술 | 선택한 이유 |
| --- | --- |
| Flutter + Riverpod `NotifierProvider` | 두 플랫폼에서 UI와 상태 흐름을 공유하고, 테스트에서는 카메라와 OCR 구현을 교체할 수 있습니다. 앱 규모에 맞춰 상태 코드 생성은 사용하지 않았습니다. |
| `camera` | 프리뷰와 촬영을 제공하는 공식 플러그인입니다. 초기화·해제·화면 복귀 처리는 카메라 adapter로 분리했습니다. |
| Firebase AI Logic + App Check | 공식 SDK의 구조화 응답을 사용하며, App Check로 평가 프로젝트의 요청을 검증합니다. |
| Pigeon + 한국어 ML Kit | Dart와 Kotlin/Swift 사이의 타입을 맞추고, 번들된 한국어 OCR 엔진을 호출합니다. |

의존성 버전은 [pubspec.yaml](pubspec.yaml)과 [pubspec.lock](pubspec.lock)에 고정했습니다.

## Trade-off와 알려진 한계

- **공유 코드와 네이티브 처리:** Flutter로 UI를 공유하지만 카메라 권한·앱 복귀·OCR 연동은 OS별 구현과 검증이 필요합니다.
- **클라우드와 기기 OCR:** 클라우드는 네트워크·서비스 상태에 영향을 받고 이미지를 외부로 전송합니다. `gemini-3.8-flash`의 재시도 가능한 오류에는 `gemini-3.5-flash-lite`로 한 번 더 요청합니다. 10초에 기기 OCR/대기 선택을 제공하고 누적 60초로 대기를 제한했습니다. 이미 보낸 SDK 요청은 취소할 수 없어 늦은 응답만 무시합니다. 기기 OCR은 앞선 호출이 끝나야 다음 요청을 시작하며, 그동안 원본 파일을 유지합니다. 호출이 끝나지 않으면 다음 작업도 대기합니다.
- **입력과 복구:** 글자 없음과 OCR 오류를 구분하고 재촬영·기기 인식·권한 설정 안내를 제공합니다. 클라우드 입력 크기와 픽셀 수를 제한하고 방향을 보정했습니다. 흐림·저조도·기울어진 이미지·손상 파일을 테스트했지만 흐림이나 저조도를 복원하는 기능은 없습니다.
- **파일과 개인정보:** 갤러리·인식 이력을 저장하지 않고 임시 파일을 정리합니다. 비정상 종료 시 일부 파일은 남을 수 있습니다. Firebase AI monitoring은 모든 요청을 수집하도록 설정돼 있어 민감한 사진은 사용하지 않는 것이 좋습니다.
- **플랫폼 설정:** Android는 Play Integrity, iOS debug는 App Check debug provider를 사용합니다. iOS profile/release에는 debug token을 넣지 않으며 클라우드 실행에 별도 production App Check 설정이 필요합니다. release 파일에서 debug token이 제외된 것을 확인했습니다.

## 테스트와 기기 확인

```bash
flutter analyze
flutter test
flutter test -d flutter-tester integration_test/fake_flow_test.dart
```

2026년 9월 30일 기준 분석 오류 0건, 단위·widget 테스트 262개, 호스트의 fake 통합 테스트 2개가 통과했습니다. 상태 전이, 중복 요청, 이전 응답 처리, 화면 전환, 오류 안내와 임시 파일 정리를 검사합니다. 공통 OCR 수정 커밋은 `d81d731`이며, 기기별 테스트에 사용한 소스와 명령은 아래 기록에 남겼습니다.

| 환경 | 확인한 내용 |
| --- | --- |
| Samsung SM-S911N, Android 16 / API 36 | 실제 촬영 → 기기 OCR → 재촬영 10회 모두 성공했습니다. 권한 거부·설정 복구, 빈 입력, 저조도, 플래시 모드, 프리뷰의 background/resume, 촬영 중 background 복구와 OS 설정을 통한 회전을 확인했습니다. 어두운 방에서 자동 플래시가 켜지는 것도 직접 확인했습니다. native OCR 테스트 4개와 fake 통합 테스트 2개가 통과했습니다. |
| 같은 Samsung, 클라우드 | 생성한 테스트 이미지의 fallback 모델 호출은 성공했고, primary 모델 호출은 재시도 가능한 서비스 오류로 실패했습니다. 이후 기본 앱으로 실제 촬영했을 때 응답은 느렸지만 글자가 인식되는 것을 확인했습니다. 이 촬영의 처리 시간과 최종 사용 모델은 기록하지 못했습니다. |
| iPhone 16 Pro, iOS 18.5 시뮬레이터 | native OCR 테스트 4개, fake 통합 테스트 2개, 실제 카메라 플러그인의 카메라 없음·재시도 테스트 1개, XCTest 9개가 통과했습니다. 생성한 테스트 이미지로 primary/fallback 모델 호출도 각각 성공했습니다. |
| Android API 33 Play Store / API 36 에뮬레이터, 이전 실행 | API 33에서 native OCR과 fake 통합 테스트가 통과했지만 클라우드는 App Check 403으로 차단됐습니다. API 36에서는 권한·재촬영·background/resume·회전을 확인했습니다. |

Samsung의 기기 OCR profile 실행에서 3,788개 프레임을 수집했습니다. UI build p95는 1.853ms, raster p95는 4.134ms였고 전체 프레임 시간은 16.667ms를 넘긴 경우가 2건 있었습니다. PSS는 272.6 → 296.4MiB, 배터리 온도는 38.1 → 39.0°C, AP 온도는 42.7 → 43.7°C였습니다. USB 충전 중 짧게 측정한 값으로, 장시간 메모리 누수나 발열까지 확인한 결과는 아닙니다.

실물 iPhone을 확보하지 못해 iOS의 실제 프리뷰·촬영·권한 동작·플래시·성능과 두 플랫폼의 실기기 동작 일치는 확인하지 못했습니다. Android에서도 정확한 OCR 처리 시점의 background 전환, 엔진 오류 주입, 카메라 없는 기기, 네트워크 차단 상태는 따로 확인하지 않았습니다. 클라우드에서 기기 OCR로 전환한 후의 실제 재인식도 추가 확인이 필요합니다. 프리뷰 하단의 버튼 영역은 화면 일부를 덮습니다.

- [Android 실기기 검증과 측정 기록](docs/ANDROID_VERIFICATION_2026-09-30.md)
- [iOS 시뮬레이터 검증 기록](docs/FINAL_VERIFICATION_2026-09-30.md)
- [테스트 실행 방법](docs/E2E_TESTING.md)

시뮬레이터에서 native OCR과 카메라 없음 상태를 확인하려면 다음 명령을 사용합니다. 카메라 없음 테스트는 시뮬레이터에서만 실행합니다.

```bash
flutter build ios --debug --no-codesign
flutter test integration_test/native_ocr_smoke_test.dart -d <simulator-id>
flutter test integration_test/fake_flow_test.dart -d <simulator-id>
flutter test integration_test/simulator_camera_recovery_test.dart \
  -d <simulator-id> --dart-define=RUN_SIMULATOR_CAMERA_CHECK=true
```

현재 ML Kit 버전은 arm64/iOS 26 이상 시뮬레이터 지원 경고가 있어 iOS 18.5/x86_64 환경에서 검증했습니다.

## AI 활용

Codex를 요구사항 정리, 설계 대안 검토, 코드·테스트 초안, 코드 리뷰와 문서 작성에 사용했습니다.

- **그대로 사용한 부분:** 기록상 수정 없이 그대로 사용한 항목은 없습니다. 상태 머신과 Pigeon으로 UI·작업 관리·네이티브 OCR을 나누는 설계는 채택하되 구현을 테스트와 빌드로 확인했습니다. Pigeon 생성 파일은 AI 출력이 아닌 도구의 자동 생성 결과입니다.
- **직접 수정·검증한 부분:** 180초 대기 제안은 누적 60초와 10초 선택 화면으로 바꿨습니다. 프리뷰 비율·버튼 배치, 앱 복귀 시 카메라 처리, 재촬영 중 OCR 중첩·원본 삭제 문제를 수정하고 실패 테스트와 기기 확인으로 검증했습니다. controller 테스트 92개를 포함한 전체 테스트 262개가 통과했습니다.
- **기각·직접 판단한 사례:** 공식 SDK와 중복되는 HTTP/Dio 도입을 제외하고, 오류 메시지를 넓게 추측해 재시도하는 방식은 제한했습니다. `firebase_ai 3.10.0`의 408/429 정보 누락만 adapter 내부에서 좁게 분류하고 테스트했습니다. 결과 편집·복사는 촬영·인식·오류 복구에 집중하기 위해 제외했습니다.

자세한 결정 과정은 [AI 사용 기록](docs/AI_PROMPT_LOG.md)에 남겼습니다.

## 참고

- [과제 원문](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)
- [설계 문서](docs/superpowers/specs/2026-09-28-altinus-camera-ocr-design.md)
- [Firebase App Check debug provider](https://firebase.google.com/docs/app-check/flutter/debug-provider)
- [Firebase AI monitoring](https://firebase.google.com/docs/ai-logic/monitoring)
- [Apple의 시뮬레이터·실기기 안내](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
