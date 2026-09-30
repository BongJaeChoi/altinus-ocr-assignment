# ARTINUS Camera OCR

Flutter 앱으로 `카메라 프리뷰 → 촬영 → OCR → 읽기 전용 결과 표시`를 구현했습니다. Firebase AI Logic으로 먼저 인식하며, 지연·실패하거나 결과를 다시 확인하고 싶을 때 번들된 한국어 ML Kit로 전환할 수 있습니다. 결과 편집·복사·이력 기능은 범위에서 제외했습니다.

## 실행

Flutter **3.47.5** / Dart **3.13.4**, Java 17을 사용합니다. iOS 빌드는 Xcode **26.1.1** / CocoaPods **1.16.2**에서 검증했습니다. 최소 지원 버전은 Android API 24, iOS 15.5입니다. 한글 상위 경로에서 도구 오류가 재현되어 **영문 경로에 clone**하는 것을 권장합니다.

이 저장소는 평가 편의를 위해 **과제 전용·폐기 가능한 Android 서명 자료와 iOS App Check debug token**을 포함합니다. 기본 debug 실행에는 별도 Firebase 설정이 필요하지 않습니다. 이 예외는 전용 Spark/무과금 프로젝트에 한정되며 production 자격 증명 관리 방식이 아닙니다. iPhone은 Apple Development 서명이 필요할 수 있습니다.

```bash
flutter pub get
flutter run -d <device-id>
```

깨끗한 iOS checkout에서 `Pods_Runner` 링크 오류가 나면 `flutter build ios --debug --no-codesign` 후 다시 실행합니다. 클라우드 없이 기기 OCR만 실행하려면 다음을 사용합니다.

```bash
flutter run -d <device-id> --dart-define=ARTINUS_CLOUD_EVIDENCE=false
```

## 기술 선택과 아키텍처

| 선택 | 이유 |
| --- | --- |
| Flutter + Riverpod `NotifierProvider` | iOS/Android가 상태·UI 흐름을 공유하고, 의존성 교체로 오류와 비동기 경합을 테스트하기 쉽습니다. 작은 앱이므로 상태 코드 생성은 추가하지 않았습니다. |
| 공식 `camera` | 카메라 프리뷰·촬영을 제공하며, controller 수명과 플랫폼 처리는 adapter로 격리했습니다. |
| Firebase AI Logic + App Check | 공식 SDK와 구조화 응답을 사용하고, 평가 프로젝트에 대한 요청을 App Check로 검증합니다. |
| Pigeon + 한국어 ML Kit | Dart/Kotlin/Swift 사이 타입 계약을 생성하며, 번들된 엔진으로 오프라인 OCR을 제공합니다. |

`OcrScreen → OcrFlowController → CameraRepository / FirebaseAiOcrService / PigeonLocalOcrService`로 UI, 상태·자원 소유권, 플랫폼 처리를 분리했습니다. 중복 촬영을 막고 transaction ID로 늦은 결과를 무시합니다. 클라우드 이미지 준비의 decode·방향 보정·축소는 isolate에서 수행합니다. 의존성 버전은 [pubspec.yaml](pubspec.yaml)과 lockfile에 고정했습니다.

## Trade-off와 알려진 한계

- **클라우드와 로컬:** 첫 모델은 `gemini-3.8-flash`이며, 재시도 가능한 일시 오류에만 `gemini-3.5-flash-lite`로 한 번 재시도합니다. 네트워크·quota·서비스 지연이 있고 이미지가 외부로 전송됩니다. 10초에 기기 OCR/대기 선택을 제공하고 누적 60초에 클라우드 대기를 종료합니다. 로컬 전환은 순차적으로 요청하지만 이미 시작된 SDK 호출 자체를 취소하지는 못합니다.
- **나쁜 입력·오류:** 읽을 문자 없음과 OCR 실패를 구분하고 재촬영·기기 인식을 제공합니다. 클라우드 입력은 크기·픽셀 수를 제한하고 방향을 보정합니다. 블러·저조도·기울어짐을 자동 복원하거나 인식 정확도를 보장하지 않습니다. 권한 거부·카메라 오류는 재시도 또는 설정 안내로 복구합니다.
- **임시 파일·개인정보:** 갤러리와 OCR 이력에 저장하지 않으며, 재촬영·dispose 시 소유 파일을 정리합니다. 비정상 종료 시 카메라 임시 파일은 남을 수 있습니다. Firebase AI monitoring은 100% sampling이며 입력·출력이 수집될 수 있으므로 민감한 사진은 테스트에 사용하지 마세요.
- **플랫폼 차이:** Android는 Play Integrity, iOS debug는 등록된 App Check debug provider를 사용합니다. iOS profile/release는 debug token을 사용하지 않으며 클라우드 평가 실행에 별도 production App Check 구성이 필요합니다. 기존 release 산출물에서 debug token 부재를 확인했으며, 평가 종료 후 평가용 token·인증서 등록을 폐기할 계획입니다.
- **실기기 검증:** Samsung에서 프리뷰 비율과 버튼 배치를 확인했지만 하단 버튼 overlay가 프리뷰 일부를 덮습니다. iPhone 실기기, 전체 기능 패리티, frame time·메모리·발열·flash 점등은 검증하지 못했습니다.

## 테스트 방법과 검증 기기

```bash
flutter analyze
flutter test
flutter test -d flutter-tester integration_test/fake_flow_test.dart
```

단위/widget 테스트는 상태 전이, 중복·stale 결과, lifecycle, 오류·복구 UI와 임시 파일 처리를 검증합니다. fake integration과 native OCR integration은 실제 카메라·실기기 성능 증거와 구분합니다.

| 기준 / 환경 | 기록된 결과와 범위 |
| --- | --- |
| `1d83b68`, 2026-09-30 22:03 KST, 영문 경로 소스 export | `flutter analyze` 0 issues, Flutter 테스트 **255개 통과**. 이 checkpoint에서 native matrix 전체를 재실행하지 않았습니다. |
| Android API 33 Play Store / API 36 emulator, 이전 커밋 실행 | API 33은 native OCR·fake flow 통과, cloud는 App Check 403으로 차단됐습니다. API 36은 권한·재촬영·background/resume·회전 등을 확인했습니다. 물리 카메라 증거는 아닙니다. |
| iPhone 16 Pro / iOS 18.5 및 iPhone 14 Pro Max / iOS 18.3 simulator, 이전 커밋 실행 | native OCR·fake flow·cloud 실행 기록이 있으며, iOS 18.3에서 primary/fallback cloud를 확인했습니다. 서로 다른 실행이며 실기기 검증을 대체하지 않습니다. |
| Samsung SM-S911N, Android 16/API 36, local-only debug | 권한 허용·촬영 후 프리뷰 문제를 수정하고 비율 유지·버튼 배치를 확인했습니다. 전체 OCR·cloud·성능 matrix는 미완료입니다. 확인 스크린샷은 저장소에 포함하지 않았습니다. |
| iPhone 실기기 | 연결된 기기가 없어 **미검증**입니다. |

Android debug/release 및 iOS no-codesign build의 기존 통과 기록은 최신 실기기 실행 완료를 의미하지 않습니다. 명령·기기별 재현 절차는 [E2E 가이드](docs/E2E_TESTING.md), 커밋별 결과는 [검증 기록](docs/CONTEXT.md#latest-observed-evidence)과 [상세 cloud/build 보고서](.superpowers/sdd/firebase-cloud-evidence-report.md)에 있습니다.

## AI 도구와 직접 판단한 내용

**Codex**를 요구사항 분석, 설계 대안, 구현·테스트 초안, 코드 검토와 문서 정리에 활용했습니다. 작업은 설계·범위가 제한된 구현·검토 역할로 나누고 결과를 통합했습니다.

- **그대로 사용:** 기록상 AI 출력을 수정 없이 그대로 사용한 항목은 없습니다. 채택한 상태 머신·Pigeon 경계 설계도 코드·테스트·build 결과와 대조했습니다. Pigeon 생성 파일은 도구 산출물이며 AI가 작성한 코드와 구분합니다.
- **직접 수정·검증:** AI의 180초 watchdog 제안은 사용자 판단으로 누적 60초와 10초 선택 UI로 변경했습니다. Samsung에서 발견된 프리뷰 왜곡과 화면 밖 버튼을 수정하고 비율·짧은 화면 widget 회귀 테스트 및 실제 화면 확인으로 검증했습니다. lifecycle 경합은 실패 테스트를 먼저 관찰한 뒤 수정했습니다.
- **기각·판단:** raw HTTP/Dio 추가는 공식 SDK와 기능이 중복되어 기각했습니다. 광범위한 오류 문자열 추측은 잘못된 재시도를 유발하므로 제한했습니다. 단, `firebase_ai 3.10.0`의 408/429 상태 정보 누락에는 adapter 내부의 좁은 분류 예외를 두고 테스트했습니다. 결과 편집·복사는 필수 흐름과 오류 복구에 집중하기 위해 제외했습니다.

제안의 채택·수정·기각 이유와 실행 근거는 [AI 결정 로그](docs/AI_PROMPT_LOG.md)에 남겼습니다.

## 근거

- [과제 원문 — 제약사항과 README 필수 항목](https://github.com/git-artinus/artinus-fe-recurit/blob/cb7c0d5323e9c0f347253cf52c09594e18342ced/README.md#제약사항)
- [구현 설계](docs/superpowers/specs/2026-09-28-altinus-camera-ocr-design.md), [AI·검증 기록](docs/AI_PROMPT_LOG.md)
- [Firebase App Check debug provider](https://firebase.google.com/docs/app-check/flutter/debug-provider), [Firebase AI monitoring](https://firebase.google.com/docs/ai-logic/monitoring)
