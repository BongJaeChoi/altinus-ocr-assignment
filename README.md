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

UI는 `OcrScreen`, 상태 전이와 작업 관리는 `OcrFlowController`, 카메라와 OCR 호출은 각각의 adapter가 담당합니다. 촬영마다 ID를 부여해 이전 작업의 응답이 새 결과를 덮어쓰지 않도록 했습니다. 이미지 디코딩·방향 보정·축소는 별도 isolate에서 처리합니다.

| 기술 | 선택한 이유 |
| --- | --- |
| Flutter + Riverpod `NotifierProvider` | 두 플랫폼에서 UI와 상태 흐름을 공유하고, 테스트에서는 카메라와 OCR 구현을 교체할 수 있습니다. 앱 규모에 맞춰 상태 코드 생성은 사용하지 않았습니다. |
| `camera` | 프리뷰와 촬영을 제공하는 공식 플러그인입니다. 초기화·해제·화면 복귀 처리는 카메라 adapter로 분리했습니다. |
| Firebase AI Logic + App Check | 공식 SDK의 구조화 응답을 사용하며, App Check로 평가 프로젝트의 요청을 검증합니다. |
| Pigeon + 한국어 ML Kit | Dart와 Kotlin/Swift 사이의 타입을 맞추고, 번들된 한국어 OCR 엔진을 호출합니다. |

의존성 버전은 [pubspec.yaml](pubspec.yaml)과 [pubspec.lock](pubspec.lock)에 고정했습니다.

## 구현하면서 고려한 점

**클라우드 지연과 기기 OCR 전환**

첫 요청은 `gemini-3.8-flash`로 보냅니다. 재시도 가능한 일시 오류가 발생하면 `gemini-3.5-flash-lite`로 한 번 더 요청합니다. 10초가 지나면 기기 OCR로 전환하거나 더 기다릴 수 있고, 클라우드 대기는 누적 60초로 제한했습니다. 이미 보낸 SDK 요청은 취소할 수 없어 전환 후에도 잠시 진행될 수 있지만, 늦게 도착한 결과는 화면에 반영하지 않습니다.

기기 OCR은 이전 호출이 끝난 뒤 다음 요청을 시작합니다. 재촬영하더라도 엔진이 읽고 있는 원본 파일은 완료까지 유지합니다. 네이티브 호출이 끝나지 않으면 다음 작업도 대기하는 한계가 있습니다.

**오류와 입력 처리**

글자가 없는 결과와 OCR 오류를 구분하고, 재촬영과 기기 인식으로 복구할 수 있도록 했습니다. 권한 거부에는 재시도 또는 설정 안내를 표시합니다. 클라우드 입력의 크기와 픽셀 수를 제한하고 방향을 보정하며, 흐린 이미지·저조도·기울어진 이미지·손상 파일의 처리도 테스트했습니다. 흐림이나 저조도 자체를 복원하는 기능은 없습니다.

**파일과 개인정보**

촬영 이미지를 갤러리나 별도 이력에 저장하지 않습니다. 재촬영하거나 화면을 종료하면 임시 파일을 정리하지만, 앱이 비정상 종료되면 일부 파일이 남을 수 있습니다. 클라우드 OCR은 이미지를 외부로 전송합니다. 평가 프로젝트의 Firebase AI monitoring은 모든 요청을 수집하도록 설정돼 있으므로 민감한 사진은 사용하지 않는 것이 좋습니다.

**플랫폼 설정**

Android는 Play Integrity, iOS debug는 App Check debug provider를 사용합니다. iOS profile/release에는 debug token을 넣지 않으며, 클라우드를 사용하려면 별도 production App Check 설정이 필요합니다. 빌드된 release 파일에서 debug token이 제외된 것을 확인했습니다.

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

Codex를 요구사항 정리, 설계 대안 검토, 코드와 테스트 초안, 코드 리뷰, 문서 작성에 사용했습니다. 제안은 그대로 적용하기보다 과제 범위와 테스트 결과를 확인하며 수정했습니다.

- **채택:** 상태 머신과 Pigeon으로 UI·작업 관리·네이티브 OCR을 나누는 구조를 채택했습니다. 구현은 테스트와 빌드로 확인했고, AI 출력 전체를 수정 없이 그대로 사용한 항목은 없습니다.
- **수정:** 180초 대기 제안은 지연이 길다고 판단해 누적 60초와 10초 선택 화면으로 바꿨습니다. 프리뷰 비율과 버튼 배치, 화면 복귀 시 카메라 처리, 재촬영 중 OCR 중첩과 원본 삭제 문제도 테스트와 기기 확인을 거쳐 수정했습니다. 공통 controller 테스트 92개가 포함돼 있습니다.
- **제외:** 공식 SDK와 중복되는 HTTP/Dio 도입은 제외했습니다. 오류 메시지를 넓게 추측해 재시도하는 방식도 제한했습니다. 다만 `firebase_ai 3.10.0`에서 408/429 상태 정보가 일부 누락되는 문제는 adapter 내부에서 좁은 범위의 분류와 테스트로 대응했습니다. 결과 편집·복사는 과제의 촬영·인식·오류 복구 흐름에 집중하기 위해 제외했습니다.

자세한 결정 과정은 [AI 사용 기록](docs/AI_PROMPT_LOG.md)에 남겼습니다.

## 참고

- [과제 원문](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md)
- [설계 문서](docs/superpowers/specs/2026-09-28-altinus-camera-ocr-design.md)
- [Firebase App Check debug provider](https://firebase.google.com/docs/app-check/flutter/debug-provider)
- [Firebase AI monitoring](https://firebase.google.com/docs/ai-logic/monitoring)
- [Apple의 시뮬레이터·실기기 안내](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices)
