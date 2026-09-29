# AI Prompt and Decision Log

Append-only record for transparent AI use. Record user-visible requests and implementation decisions, not hidden reasoning. Never include credentials, private mail bodies, or unrelated personal data.

## Entry template

```text
### YYYY-MM-DD HH:MM KST — actor

- Request/prompt:
- Scope/files:
- Decision/result:
- Disposition: adopted | modified | rejected
- Verification/evidence:
```

---

### 2026-09-23 — user / bootstrap

- Request/prompt: Create and run a bootstrap for the assignment with Conventional Commits containing what/why, a model-and-effort subagent catalog, sub-10KB PRD and AGENTS context files, domain-first CONTEXT, prevention of documentation-only work, E2E guidance for Google ARTEMIS/Chrome DevTools MCP/Python CDP, and a prompt conversation log.
- Scope/files: repository governance, testing guidance, local Git hooks, and prompt logging only; no assignment implementation or external submission.
- Decision/result: Use an isolated local Git repository, require `What:` and `Why:` commit sections, reject docs-only staged changes by default, cap concurrent independent subagents at three, and explicitly separate Android/browser/iOS evidence.
- Disposition: adopted with safety constraints.
- Verification/evidence: bootstrap contract test and generated-repository checks are required before this entry is considered complete.

### 2026-09-23 — user / parallel execution architecture

- Request/prompt: Review whether `flutter_implementer` is too broad and slow; verify with researched evidence whether clearly documented design and planning enables parallel execution; then add a dedicated file-finder agent and apply the validated changes.
- Scope/files: subagent architecture, task ownership contract, planner/executor split, repository-search role, and bootstrap regression checks.
- Decision/result: Replace the broad implementer with `solution_planner` plus reusable bounded executors; add read-only `file_finder`; permit at most three parallel writers only with independent dependencies, non-overlapping paths, isolated worktrees, and main-agent integration.
- Disposition: adopted with parallel-safety gates.
- Verification/evidence: OpenAI multi-agent and GPT-5.6 model guidance, plus red-green bootstrap contract tests and repository hook checks.

### 2026-09-27 — user + AI / 과제 요구사항 해석과 우선순위

- Request/prompt: GitHub 과제 README를 다시 자세히 읽고 기술 스택과 구현 범위를 요구사항에 맞춰 구체화.
- README basis: 필수 흐름은 `카메라 프리뷰 → 정지 이미지 촬영 → OCR → 결과 표시`이며, iOS/Android 패리티·실기기 프리뷰·UI Thread 비차단·나쁜 입력·권한/OCR 오류 처리가 요구된다. UI 디자인과 결과 수정·복사는 평가 대상이 아니다.
- Decision/result: 기능 완성도, 양 플랫폼 동작, 복구 가능한 오류 흐름, 실기기 검증을 시각적 장식이나 부가 기능보다 우선한다. 결과 복사 기능 포함 여부는 아직 미결정이다.
- Disposition: adopted. README의 평가항목인 기능 완성도, 실기기 성능, 예외 처리 및 설계, 테스트 전략에 직접 대응하기 때문이다.
- Rejected/modified: UI 완성도를 핵심 평가항목처럼 취급하는 접근과 문서만 늘리는 작업은 기각했다. README가 UI보다 기능 완성도를 우선한다고 명시하며, 문서는 구현·검증 증거와 연결돼야 하기 때문이다.
- Verification/evidence: 과제 README pinned commit `cb7c0d5323e9c0f347253cf52c09594e18342ced`, lines 187–251.

### 2026-09-27 — user + AI / Flutter와 지원 버전 기준

- Request/prompt: 기술 스택을 정하고 Flutter/Dart는 최신 stable로 올리되 Xcode는 유지한 상태에서 호환 버전을 선택.
- README basis: React Native 또는 Flutter를 자유롭게 선택할 수 있고 선택 이유, 주요 라이브러리, 아키텍처, trade-off와 한계를 README에 설명해야 한다.
- Decision/result: Flutter를 채택하고 로컬 도구를 Flutter `3.47.5` stable, Dart `3.13.4`로 갱신했다. Xcode는 `26.1.1`로 유지한다. 앱의 실질 최소 버전은 카메라와 ML Kit 제약을 합쳐 Android API 24, iOS 15.5로 계획한다.
- Disposition: adopted. 사용자가 Flutter에 숙련돼 있고 양 플랫폼 단일 코드베이스, 공식 카메라 패키지, 테스트 가능한 비동기 상태 구성이 과제 범위에 적합하기 때문이다.
- Rejected/modified: React Native는 과제상 허용되지만 추가 생태계 전환 이점이 없어서 기각했다. 무조건 최신 FlutterFire 조합은 Xcode 26.2 요구와 충돌하므로, 현재 Xcode와 호환되는 FlutterFire BoM `4.11.0` 계열(`firebase_ai 3.10.0`, `firebase_core 4.6.0`)로 수정했다.
- Verification/evidence: `flutter --version`, `flutter doctor`; Flutter, FlutterFire, Firebase iOS SDK, camera, Pigeon, ML Kit 공식 호환성 문서.

### 2026-09-27 — user + AI / 하이브리드 OCR 아키텍처

- Request/prompt: 서버 인식의 정확성과 온디바이스 폴백을 모두 확보하고, 커뮤니티 네이티브 브리지 의존 위험을 줄일 방법을 결정.
- README basis: OCR 엔진은 자유롭게 선택할 수 있고 온디바이스 또는 서버/클라우드 방식 모두 허용된다. 기술 선택의 합리성, trade-off, 알려진 한계를 설명해야 하며 OCR 실패를 처리해야 한다.
- Decision/result: Firebase AI Logic을 통한 Gemini Developer API의 `gemini-3.8-flash`를 1차 OCR로 사용하고, 실패 시 공식 Google ML Kit Text Recognition을 온디바이스 폴백으로 사용한다. 클라우드에는 낮은 thinking level과 구조화된 JSON 응답을 요청한다.
- Disposition: adopted. 클라우드의 광범위한 언어·복잡한 장면 대응과 온디바이스의 오프라인성·예측 가능한 복구 경로를 결합해 실제 사용 가능성을 높이기 때문이다.
- Rejected/modified: 클라우드 단독 방식은 네트워크·할당량·지연 실패 시 복구 경로가 없어 기각했다. 온디바이스 단독 방식은 한국어·라틴 문자 이외의 범용성과 복잡한 이미지 대응 폭이 좁아 1차 방식으로 기각했다. 자체 백엔드는 과제 규모 대비 운영 범위가 커서 기각했다.
- Verification/evidence: Firebase AI Logic 모델·시작·구조화 출력·thinking 공식 문서, Google ML Kit Text Recognition v2 공식 문서.

### 2026-09-27 — user + AI / Firebase 연결, 비용, 키 노출

- Request/prompt: 결제 계정 필요 여부를 먼저 확인하고 모바일 친화적인 Firebase AI Logic을 사용하되 앱 번들에 Gemini API 키를 노출하지 않는 구성을 선택.
- README basis: 서버/클라우드 OCR 사용이 허용되며, 제출 저장소는 iOS/Android에서 빌드·실행 가능해야 한다. 선택 방식의 한계도 문서화해야 한다.
- Decision/result: 별도 Gemini API 키를 앱에 넣지 않고 Firebase 프로젝트 구성 파일과 Firebase AI Logic 클라이언트 SDK를 사용한다. 과제 평가 기간에는 결제 연결 없는 Gemini Developer API 무료 사용 경로를 계획하고, 실제 사용 전 무료 할당량과 모델 가용성을 재검증한다.
- Disposition: adopted with constraints. 모바일 SDK가 인증·API 호출 구성을 단순화하고 비밀 API 키의 직접 번들링을 피할 수 있기 때문이다.
- Rejected/modified: Gradle 변수나 난독화로 API 키를 숨기는 방식은 번들 내부 비밀 보호가 되지 않으므로 기각했다. App Check enforcement는 평가 기기 등록 실패 위험 때문에 평가 기간에는 비활성화하되, 공개 배포 전 활성화가 필요하다는 위험을 명시하는 것으로 수정했다.
- Verification/evidence: Firebase AI Logic 제품·시작·App Check 공식 문서. App Check 의무화 예정일은 `2026-11-02`로 과제 마감 후이지만, 일정은 구현 시 재확인한다.

### 2026-09-27 — user + AI / 공식 카메라와 타입 안전 네이티브 OCR 브리지

- Request/prompt: 네이티브 핵심 기능을 직접 MethodChannel로 연결하는 편이 안전한지 검토하고 공식 지원 수단이 있다면 채택.
- README basis: 양 플랫폼 동작, 원활한 실기기 프리뷰, UI Thread 비차단, 외부 라이브러리 선택 판단력을 평가한다.
- Decision/result: 카메라는 Flutter 팀의 공식 `camera` 패키지(Android CameraX, iOS AVFoundation)를 사용한다. 폴백 OCR만 Pigeon이 생성하는 타입 안전 플랫폼 채널을 통해 Android Kotlin/iOS Swift의 공식 ML Kit SDK에 연결한다. Dart→native 전달은 이미지 bytes가 아니라 임시 파일 경로를 사용한다.
- Disposition: adopted. 검증된 공식 카메라 구현을 재작성하지 않으면서, OCR 브리지 계약은 컴파일 가능한 타입으로 통제하고 대용량 채널 복사를 피하기 때문이다.
- Rejected/modified: 카메라까지 직접 네이티브 브리지로 작성하는 방식은 라이프사이클·프리뷰·회전 처리 범위를 불필요하게 키워 기각했다. 커뮤니티 `google_mlkit_text_recognition` Flutter 래퍼는 핵심 폴백의 유지보수 통제권을 줄여 기각했다. 수기 MethodChannel 문자열 계약은 타입·테스트 위험 때문에 Pigeon으로 수정했다.
- Verification/evidence: Flutter `camera`, Flutter platform channels, Pigeon, Android/iOS ML Kit 공식 문서.

### 2026-09-27 — user + AI / 온디바이스 언어 모델 범위

- Request/prompt: 공식 패키지를 사용하고 한국어 인식이 가능한 온디바이스 모델 범위를 결정.
- README basis: 나쁜 입력에 대한 최소한의 처리와 선택한 OCR 방식의 알려진 한계를 설명해야 한다.
- Decision/result: Android와 iOS에 공식 ML Kit Korean Text Recognition 모델을 번들한다. 이 모델은 한국어와 라틴 계열 문자를 폴백 범위로 삼고, 더 넓은 언어 대응은 1차 클라우드 OCR에 맡긴다.
- Disposition: adopted. 평가 환경에서 모델 다운로드를 기다리지 않고 즉시 오프라인 폴백을 실행할 수 있으며 한국어 과제 사용성을 확보하기 때문이다.
- Rejected/modified: 여러 스크립트 모델을 모두 번들하는 방식은 앱 크기·초기화 비용을 늘려 기각했다. 온디바이스 OCR이 모든 언어를 지원한다고 주장하지 않고 README에 한계로 명시하도록 수정했다.
- Verification/evidence: ML Kit 지원 언어, Android Korean package, iOS KoreanTextRecognizerOptions, ML Kit release notes.

### 2026-09-27 — user + AI / OCR 결과 계약과 빈 결과 의미

- Request/prompt: 잘못 찍은 사진에서 빈 결과가 정상일 수 있으므로 엔진 실패와 구분하고, 모델이 내용을 추측하지 않도록 결과 계약을 결정.
- README basis: 나쁜 입력과 OCR 실패를 모두 처리해야 하므로 두 상태를 사용자 흐름에서 구분해야 한다.
- Decision/result: 클라우드 응답을 구조화된 JSON으로 제한하고 `textDetected`와 `noReadableText`를 명시적으로 구분한다. `textDetected`는 비어 있지 않은 원문 텍스트와 줄바꿈을 보존하며, `noReadableText`의 빈 문자열은 정상 결과다. 상태 없이 빈 문자열만 온 경우는 계약 위반/시스템 실패로 처리한다.
- Disposition: adopted. 정상적인 무문자·판독 불가 입력을 장애로 오인하지 않으면서 모델의 요약·번역·교정·추측을 차단하기 때문이다.
- Rejected/modified: 빈 문자열을 모두 OCR 실패로 취급하는 방식과 모델이 보이지 않는 내용을 보완하는 방식은 기각했다. 저조도·블러·기울어짐의 원인을 확정적으로 진단하는 문구도 오진 가능성 때문에 기각했다.
- Verification/evidence: Firebase AI Logic structured output 공식 문서와 과제 README의 bad-input/OCR-failure 요구사항.

### 2026-09-27 — user + AI / 촬영 및 자연스러운 복구 UX

- Request/prompt: 촬영 후 불필요한 확인 단계를 두지 않고, 사용자에게 내부 오류나 에러 코드를 과도하게 노출하지 않는 재시도 경험을 설계.
- README basis: 카메라 촬영부터 결과 확인까지의 핵심 흐름, 나쁜 입력·권한 거부·OCR 실패의 사용자 경험을 평가한다.
- Decision/result: 촬영 버튼을 누르면 정지 이미지를 캡처한 뒤 별도 확인 화면 없이 인식을 시작한다. 사용자 문구에는 HTTP/Firebase/Gemini/에러 코드를 표시하지 않고 `다시 촬영`, `다시 시도`, `기기에서 인식`처럼 다음 행동을 안내한다. 기술 원인은 이미지·응답 본문을 제외한 내부 진단 로그에만 남긴다.
- Disposition: adopted. 과제의 짧은 핵심 흐름을 유지하면서 사용자가 기술 세부사항을 해석하지 않아도 복구할 수 있기 때문이다.
- Rejected/modified: 모든 저수준 오류를 그대로 표시하는 방식은 과도하고 행동 지향적이지 않아 기각했다. 반대로 모든 실패를 동일하게 삼키는 방식은 테스트와 복구 판단을 어렵게 하므로 내부 오류 분류는 유지한다.
- Verification/evidence: 과제 README의 오류 처리·실제 사용 가능성 평가항목 및 합의된 UX 원칙.

### 2026-09-27 — user + AI / 재시도, 지연, 폴백 전환

- Request/prompt: 서버 인식이 반복 실패하거나 오래 걸릴 때 항상 사용할 수 있는 폴백과 기다릴 선택지를 제공.
- README basis: OCR 실패 처리, 실제 사용 가능성, UI Thread 비차단 및 성능을 평가한다.
- Decision/result: 일시적 오류만 지수 백오프와 jitter로 최대 2회까지 클라우드 시도하며 진행 상태를 `1/2`, `2/2`로 표시한다. 재시도 불가능한 오류는 즉시 온디바이스 폴백을 제안한다. 총 10초가 지나도 요청이 살아 있으면 실패로 단정하지 않고 `takingLonger` 상태에서 `기기에서 인식`을 기본 버튼, `조금 더 기다리기`를 보조 버튼으로 제공한다.
- Disposition: adopted with modification. 10초는 네트워크 실패 판정값이 아니라 사용자가 지연을 인지하는 UX 전환점으로만 사용하고, 명시적으로 더 기다린 사용자는 기존 요청을 계속 기다릴 수 있게 하기 때문이다.
- Rejected/modified: 근거 없이 회차별 8초/12초 타임아웃을 두는 제안은 기각했다. `조금 더 기다리기`가 새 요청을 보내거나 시도 횟수를 늘리는 방식도 중복 비용·경합 때문에 기각했다. 사용자가 로컬 OCR을 선택하면 늦게 도착한 클라우드 결과는 요청 ID로 무시한다.
- Verification/evidence: Firebase AI Logic 기본 요청 제한 180초 및 Dart timeout 변경 문서, Gemini 오류별 재시도 지침, Nielsen Norman Group 응답시간 기준. 구현 전 SDK 버전의 실제 timeout 동작을 다시 검증한다.

### 2026-09-27 — user + AI / 결과가 틀리거나 읽을 수 없을 때의 폴백

- Request/prompt: 서버가 실패한 경우뿐 아니라 결과가 부정확해 보일 때도 항상 다른 인식 방법을 사용할 수 있게 구성.
- README basis: 나쁜 입력과 OCR 실패에 대한 최소 처리 및 실제 사용 가능성을 평가한다.
- Decision/result: 비어 있지 않은 결과 화면에도 사용자가 `다른 방법으로 인식`을 선택할 수 있게 하며, `noReadableText`에서는 `다시 촬영`을 기본 동작, 온디바이스 인식을 보조 동작으로 제공한다. 품질 안내는 `글자가 선명하고 화면 안에 들어오도록 다시 찍어주세요`처럼 통합된 자연스러운 문구를 사용한다.
- Disposition: adopted. 앱이 의미적으로 틀린 OCR 결과를 신뢰성 있게 자동 판정할 수 없으므로 사용자가 판단하고 전환할 수 있는 탈출구가 필요하기 때문이다.
- Rejected/modified: 결과가 비어 있지 않으면 무조건 성공으로 종료하는 방식과, 추정한 저조도·흔들림·기울어짐 원인을 단정적으로 표시하는 방식은 기각했다.
- Verification/evidence: 과제 README의 bad-input 및 exception/UX 요구사항과 합의된 오류 문구 원칙.

### 2026-09-27 — user + AI / Riverpod 상태 관리

- Request/prompt: Riverpod 코드 생성 없이 공식 권장 방식으로 명시적인 상태 관리를 구성.
- README basis: OCR 비동기 처리, 오류 설계, 아키텍처 선택 이유와 trade-off를 설명해야 한다.
- Decision/result: `flutter_riverpod 3.4.3`의 수동 `NotifierProvider`와 immutable sealed `OcrFlowState`를 사용한다. 카메라, 클라우드 OCR, 로컬 OCR을 인터페이스 뒤에 두고 테스트에서는 `ProviderScope` override로 대체한다. 생명주기 자원은 auto-dispose 경계에서 정리한다.
- Disposition: adopted. 작은 과제에서 생성 도구 복잡도를 늘리지 않으면서 명시적 상태 전이, 의존성 교체, stale-result 방지를 테스트하기 쉽기 때문이다.
- Rejected/modified: Riverpod code generation, `build_runner`, annotation 추가는 기존 생성 파이프라인이 없는 프로젝트에 과도해 기각했다. `ChangeNotifier`, `StateNotifier`, `StateProvider` 중심 설계는 Riverpod 3의 권장 방향과 명시적 상태 머신 요구에 맞지 않아 기각했다.
- Verification/evidence: Riverpod code generation 및 3.0 migration 공식 문서, `flutter_riverpod` 패키지 문서.

### 2026-09-27 — user + AI / 임시 이미지 수명과 개인정보

- Request/prompt: OCR에 저장이 필요할 때만 이미지를 유지하고 불필요한 영구 보관은 피하도록 범위를 결정.
- README basis: 실제 사용 가능성, 메모리·성능, 예외 처리 및 설계가 평가된다.
- Decision/result: `camera`가 생성한 임시 이미지 파일을 현재 캡처·재시도·폴백 흐름에서만 공유한다. 재촬영, 결과 화면 종료, 새 인식 시작 시 삭제하고 앱 시작 시 남은 임시 파일을 정리한다. 갤러리나 영구 저장소에는 저장하지 않는다.
- Disposition: adopted. Pigeon에는 파일 경로가 필요하지만 영구 보관은 요구사항이 아니며 개인정보·저장공간·리소스 누수 위험만 늘리기 때문이다.
- Rejected/modified: 결과 이미지를 자동으로 갤러리에 저장하거나 기록 기능을 추가하는 방식은 과제 범위 밖이어서 기각했다. 인식 중 파일을 즉시 삭제하는 방식은 재시도와 폴백을 깨뜨리므로 흐름 종료 시점까지 유지하도록 수정했다.
- Verification/evidence: 과제 README의 성능·설계 평가항목, Flutter camera 캡처 파일 동작, Pigeon 브리지 계약 결정.

### 2026-09-28 — user / AI 결정 기록 형식

- Request/prompt: 사용자와 AI가 나눈 대화를 원문이 아니라 결정 단위로 요약하고, GitHub README에 요구된 AI 제안의 채택·수정·기각과 그 이유를 빠짐없이 기록.
- README basis: 사용한 AI 도구와 활용 범위, 그대로 사용한 부분, 직접 수정·검증한 부분, 기각하거나 직접 판단한 사례를 제출 README에 작성해야 한다.
- Decision/result: 이 문서를 append-only 근거 원장으로 사용하고, 최종 제출 README에는 구현 결과와 일치하는 핵심 사례만 간략히 옮긴다. 미결정 사항은 채택된 것처럼 기록하지 않으며 구현·실기기 검증 결과는 확인 후 별도 항목으로 추가한다.
- Disposition: adopted. 프롬프트 원문 전체를 싣는 것보다 평가자가 판단·검증·개선 과정을 추적하기 쉽고 민감정보 및 불필요한 분량을 줄일 수 있기 때문이다.
- Rejected/modified: 전체 대화 원문 보존은 개인정보와 잡음이 크고 README의 요구가 대화 전문이 아니라 활용·검증·수정·기각 사례 설명이므로 기각했다.
- Verification/evidence: 과제 README pinned commit `cb7c0d5323e9c0f347253cf52c09594e18342ced`, AI 관련 제출 요구 lines 230–236 및 평가항목 lines 239–247.

### 2026-09-28 — user / 결과 화면 범위

- Request/prompt: 인식 결과 화면은 `인식 결과 표시만 제공`하는 안으로 확정.
- README basis: 인식된 텍스트를 사용자가 확인할 수 있어야 하지만 수정·복사 기능은 불필요하며, UI 디자인보다 기능 완성도를 우선한다.
- Decision/result: 결과 화면은 인식 텍스트 표시, 재촬영, 필요 시 다른 OCR 방식으로 다시 인식하는 복구 동작만 제공한다. 텍스트 편집과 전용 전체 복사 기능은 구현하지 않는다.
- Disposition: adopted. 필수 사용자 흐름과 실패 복구에 구현·테스트 시간을 집중하고 제출 직전 부가 기능으로 인한 회귀 위험을 줄이기 때문이다.
- Rejected/modified: 전용 `전체 복사` 버튼과 텍스트 편집 기능은 README에서 요구하지 않고 OCR 정확성·패리티·성능 검증에 기여하지 않으므로 기각했다.
- Verification/evidence: 과제 README pinned commit `cb7c0d5323e9c0f347253cf52c09594e18342ced`, requirements lines 214–221 and constraints lines 224–236.

### 2026-09-28 — user + AI / 최초 권한 요청과 클라우드 전송 안내

- Request/prompt: 별도 안내 없이 곧바로 권한을 요청하기보다 최초 실행 안내가 있는 흐름을 채택.
- README basis: 카메라 권한 거부를 처리해야 하고, 실제 사용 가능한 UX와 예외 설계를 평가한다. 클라우드 OCR 선택의 trade-off와 한계도 설명해야 한다.
- Decision/result: 최초 실행에서 카메라 사용 목적과 촬영 이미지가 인식을 위해 클라우드로 전송된다는 사실을 짧게 안내한다. 사용자가 `카메라 시작`을 누를 때 시스템 권한을 요청하고, 이후 권한이 유지되면 바로 카메라로 진입한다. 로컬 임시 이미지는 앱에 영구 보관하지 않는다고 안내한다.
- Disposition: adopted. 권한 요청과 데이터 전송이 사용자의 명시적 행동 및 현재 맥락에 연결되고, 서버 기반 AI 사용 사실을 촬영 전에 투명하게 알릴 수 있기 때문이다.
- Rejected/modified: 앱 시작과 동시에 설명 없이 시스템 권한 창을 표시하는 방식은 사용 목적과 클라우드 전송을 충분히 전달하지 못해 기각했다. 클라우드 사업자가 이미지를 전혀 저장하지 않는다고 보장하는 문구는 검증 범위를 벗어나므로, 앱의 로컬 영구 보관 여부만 정확히 설명하도록 수정했다.
- Verification/evidence: Apple Human Interface Guidelines `Privacy` 및 `Generative AI`, Android Developers `Request runtime permissions`, 과제 README permission/error-handling requirements.

### 2026-09-28 — user + AI / 나쁜 입력의 최소 처리 범위

- Request/prompt: 이미지 처리는 Firebase·ML Kit 공식 입력 지침과 과제의 저조도·블러·기울어진 텍스트 처리 요구에 맞춰 결정.
- README basis: 저조도, 블러, 기울어진 텍스트 등 나쁜 입력을 최소한 처리하고, OCR이 UI Thread를 blocking하지 않아야 하며 실기기 메모리·발열도 평가한다.
- Decision/result: EXIF/플랫폼 방향 정보를 이용해 올바른 방향으로 입력하고, Firebase의 요청 크기 제한을 초과할 위험이 있을 때만 UI 스레드 밖에서 비율을 유지해 축소한다. 촬영 가이드에는 글자가 화면을 충분히 차지하도록 가까이 촬영하고 밝기와 초점을 확보하도록 안내한다. 판독 불가 시 원인을 단정하지 않고 재촬영과 온디바이스 폴백을 제공한다.
- Disposition: adopted with bounded preprocessing. 공식 지침이 충분한 글자 픽셀, 초점, 올바른 회전을 정확도 핵심으로 제시하며, 이 범위는 양 플랫폼에서 객관적으로 검증할 수 있기 때문이다.
- Rejected/modified: 검증되지 않은 자동 대비·샤픈·노이즈 제거·기하학적 deskew는 글자 획 훼손, CPU·메모리 비용, 플랫폼별 결과 차이 위험 때문에 초기 구현에서 기각했다. 보정이 실제 고정 테스트 세트에서 개선됨을 입증할 때만 별도 변경으로 재검토한다.
- Verification/evidence: Firebase AI Logic `Supported input files and requirements`—단일 이미지, 올바른 방향, 높은 해상도, 20MB inline request limit; ML Kit Text Recognition v2 Android/iOS input guidelines—문자당 권장 픽셀, 초점, 해상도·지연 trade-off; 과제 README bad-input 및 non-blocking requirements.

### 2026-09-28 — user + AI / 카메라 조작 범위와 플래시 검증 게이트

- Request/prompt: 후면 카메라와 최소 플래시 제어를 우선 채택하되 플래시를 테스트 중점사항으로 명시.
- README basis: 실기기에서 원활한 카메라 프리뷰, 저조도 입력의 최소 처리, iOS/Android 기능 패리티, 메모리·발열과 실제 사용 가능성을 평가한다.
- Decision/result: 후면 카메라만 사용하고 지원 기기에서 `자동 플래시/끔` 전환을 제공한다. 전면 카메라 전환, 수동 줌, 탭 초점, 상시 토치는 초기 범위에서 제외한다. 플래시 지원 여부 조회, 버튼 노출, 실제 촬영 시 발광, 앱 background/foreground 후 상태, 예외 복구를 Android/iOS 실기기 중점 검증 항목으로 남긴다.
- Disposition: provisionally adopted, verification required. 저조도 촬영에 직접 도움이 되는 최소 제어이지만 카메라별 지원과 플랫폼 동작 차이가 있어 실기기 증거 없이는 완료로 볼 수 없기 때문이다.
- Rejected/modified: 다양한 카메라 전환과 수동 촬영 제어는 OCR 필수 흐름과 무관하게 상태·테스트 범위를 늘려 기각했다. 플래시 기능이 한 플랫폼에서 불안정하거나 패리티를 깨면 숨김 또는 제거하는 것으로 범위를 축소한다.
- Verification/evidence: Flutter `camera` 공식 패키지의 flash mode API 및 lifecycle 책임; 과제 README real-device preview, bad-input, parity, performance requirements. 현재 실기기 검증 결과는 없음.

### 2026-09-28 — user + AI / 양 플랫폼 평가 범위와 보유 실기기

- Request/prompt: Android 실기기는 확보 가능하며, 과제가 실제로 iOS와 Android 모두를 평가하는지 원문에서 재확인.
- README basis: 요구사항은 `iOS / Android 양쪽 동작 및 기능 패리티`와 `실기기에서 원활한 카메라 프리뷰`를 각각 명시한다. 평가항목의 실기기 성능은 `iOS / Android 프리뷰 성능, UI Thread blocking, 메모리·발열 등`을 확인하며, 제출 저장소는 iOS/Android에서 빌드·실행 가능해야 한다.
- Decision/result: 양 플랫폼 구현·빌드·기능 패리티를 필수로 취급한다. Android는 확보 가능한 실기기에서 카메라·OCR·성능·발열을 검증한다. 현재 iOS 실기기는 확보되지 않았으므로 시뮬레이터 빌드와 자동화 테스트만으로 실기기 프리뷰 성능을 검증했다고 주장하지 않는다.
- Disposition: requirement confirmed; iOS real-device evidence remains an open risk. 원문이 양 플랫폼을 명시적으로 평가하지만 `양 플랫폼 각각의 실기기 테스트 증거 제출`이라는 단일 문장으로 적지는 않았으므로, 양쪽 실기기 검증이 강하게 기대된다는 해석과 문언상 한계를 함께 유지한다.
- Rejected/modified: Android 실기기 검증만으로 iOS 실기기 성능과 패리티까지 충족했다고 간주하는 접근은 기각했다. iOS 기기를 끝내 확보하지 못하면 최종 README에 검증 범위와 한계를 정확히 공개한다.
- Verification/evidence: 과제 README pinned commit `cb7c0d5323e9c0f347253cf52c09594e18342ced`, requirements lines 214–221, evaluation lines 239–247, deliverable lines 249–251; current `flutter devices` lists no Android/iOS device connected.

### 2026-09-28 — user / iOS 실기기 확보 계획

- Request/prompt: 제출 전 iPhone을 임시로 빌려 실기기 검증하는 방향이 현실적으로 가능할 것으로 판단.
- README basis: iOS/Android 패리티, 실기기 프리뷰 성능, 검증 기기와 테스트 한계를 README에 작성해야 한다.
- Decision/result: Android 보유 기기에서 반복 개발 검증을 수행하고, iPhone은 최종 iOS 실기기 smoke/performance pass 전에 임시 확보한다. 실제 기기 모델·OS·검증 결과는 실행 시점에 기록하며 지금은 추정하지 않는다.
- Disposition: adopted as a verification dependency. iOS 시뮬레이터가 실제 카메라 프리뷰·권한·발열·메모리·플래시 동작을 대체할 수 없기 때문이다.
- Rejected/modified: 빌릴 예정이라는 계획만으로 iOS 실기기 검증 완료를 표시하지 않는다. 기기 확보에 실패하면 Android 실기기와 iOS 빌드/시뮬레이터 결과를 구분하고 한계를 공개한다.
- Verification/evidence: user-confirmed expected access; device identity and run evidence pending.

### 2026-09-28 — user + AI / 계층형 아키텍처 승인

- Request/prompt: 클라우드 우선·온디바이스 폴백 A안을 선택하고 상세 계획을 시작하며, 레이어 분리를 핵심 설계 원칙으로 승인.
- README basis: 주요 라이브러리와 아키텍처 선택 이유, trade-off와 한계를 설명해야 하며 비동기 처리·예외 설계·테스트 전략을 평가한다.
- Decision/result: UI, Riverpod `OcrFlowController`, camera/OCR repositories, Firebase AI/ML Kit services, Pigeon native adapters를 분리한다. UI는 immutable 상태만 렌더링하고, controller가 흐름을 조정하며, repository/service가 SDK 오류와 원시 응답을 도메인 결과로 변환한다.
- Disposition: adopted. 외부 SDK·플랫폼 코드를 화면 상태와 분리하면 fake 기반 상태 테스트, iOS/Android 구현 교체, stale-result 차단, 병렬 작업의 파일 소유권을 명확히 할 수 있기 때문이다.
- Rejected/modified: 화면 위젯이 camera/Firebase/Pigeon을 직접 호출하는 구조와 모든 책임을 하나의 controller에 넣는 구조는 테스트 격리와 변경 안정성을 해치므로 기각했다. 작은 과제인 만큼 별도 use-case 계층은 중복 위임만 만들 수 있어 두지 않는다.
- Verification/evidence: user approval; Flutter app architecture official guidance; Riverpod provider guidance; Pigeon package contract.

### 2026-09-28 — user + AI / OCR 상태·데이터 흐름 승인

- Request/prompt: 클라우드 우선·온디바이스 폴백 상태 흐름을 그림으로 검토하고, 해당 플로우 차트를 기록으로 보존.
- Decision/result: 아래 Mermaid 차트를 승인된 데이터 흐름의 시각적 원본으로 사용한다. 최종 설계 spec에는 구현과 일치하도록 이 차트를 옮기며, 이후 상태 이름이나 분기가 바뀌면 새 결정 항목으로 차이를 기록한다.
- Disposition: adopted. 재시도·10초 지연·사용자 전환·stale result·파일 정리가 여러 비동기 분기로 연결되므로 문장보다 상태 전이 그림이 모순을 찾기 쉽기 때문이다.
- Verification/evidence: user-approved design section 2/4; implementation and automated transition tests pending.

```mermaid
flowchart TD
    START([앱 시작]) --> NOTICE{최초 안내를 확인했나?}

    NOTICE -- 아니오 --> DISCLOSURE["카메라 사용 목적<br/>클라우드 전송 안내"]
    DISCLOSURE --> START_CAMERA["카메라 시작"]
    START_CAMERA --> PERMISSION{카메라 권한}

    NOTICE -- 예 --> PERMISSION
    PERMISSION -- 허용 --> READY["카메라 준비<br/>후면 카메라 · 자동 플래시/끔"]
    PERMISSION -- 거부 --> DENIED["자연스러운 권한 안내"]
    DENIED --> RETRY_PERMISSION["다시 요청 또는 설정 열기"]
    RETRY_PERMISSION --> PERMISSION

    READY --> CAPTURE["촬영<br/>버튼 잠금 · transactionId 생성"]
    CAPTURE --> TEMP["원본 임시 파일 보관"]
    TEMP --> PREPARE["방향 정규화<br/>요청 크기 제한 확인"]
    PREPARE --> CLOUD1["클라우드 인식 1/2"]

    CLOUD1 --> CLOUD_RESULT{클라우드 응답}
    CLOUD2["백오프 후 클라우드 인식 2/2"] --> CLOUD_RESULT
    CLOUD_RESULT -- textDetected --> RESULT["인식 결과 표시"]
    CLOUD_RESULT -- noReadableText --> EMPTY["읽을 수 있는 글자 없음"]
    CLOUD_RESULT -- 일시적 오류 --> ATTEMPTS{남은 시도가 있나?}
    CLOUD_RESULT -- 재시도 불가 --> FALLBACK["기기에서 인식 제안"]
    ATTEMPTS -- 예 --> CLOUD2
    ATTEMPTS -- 아니오 --> FALLBACK

    CLOUD1 -. 첫 요청부터 10초 경과 .-> SLOW["조금 더 걸리고 있어요"]
    CLOUD2 -. 누적 10초 경과 .-> SLOW

    SLOW --> WAIT{사용자 선택}
    WAIT -- 조금 더 기다리기 --> SAME["기존 요청 유지<br/>새 요청·횟수 증가 없음"]
    SAME --> CLOUD_RESULT
    WAIT -- 기기에서 인식 --> INVALIDATE["클라우드 transactionId 무효화"]
    FALLBACK --> INVALIDATE

    INVALIDATE --> LOCAL["Pigeon → Kotlin/Swift<br/>공식 ML Kit Korean OCR"]
    LOCAL --> LOCAL_RESULT{온디바이스 결과}
    LOCAL_RESULT -- 텍스트 있음 --> RESULT
    LOCAL_RESULT -- 텍스트 없음 --> EMPTY
    LOCAL_RESULT -- 실패 --> RECOVER["다시 촬영 안내"]

    INVALIDATE -. 늦게 도착한 클라우드 결과 .-> IGNORED["requestId 불일치<br/>결과 무시"]

    RESULT --> ACTION{다음 행동}
    ACTION -- 다시 촬영 --> CLEANUP["원본·파생 임시 파일 삭제"]
    ACTION -- 다른 방법으로 인식 --> INVALIDATE
    EMPTY --> EMPTY_ACTION{다음 행동}
    EMPTY_ACTION -- 다시 촬영 --> CLEANUP
    EMPTY_ACTION -- 기기에서 인식 --> INVALIDATE
    RECOVER --> CLEANUP
    CLEANUP --> READY
```

### 2026-09-28 — user + AI / 클라우드 watchdog을 60초로 제한

- Request/prompt: Firebase 기본 제한인 180초까지 사용자를 기다리게 하는 것은 과도하므로 앱의 최대 클라우드 대기 시간을 1분으로 제한.
- Decision/result: 앱의 transaction-level cloud watchdog은 첫 `recognizingCloud` 진입부터 총 60초로 설정한다. 이미지 준비, 첫 요청, 백오프, 두 번째 요청이 같은 60초 예산을 공유하며 재시도나 `조금 더 기다리기`가 시간을 초기화하지 않는다. 10초에는 기존 요청을 유지한 채 로컬 전환 또는 계속 기다리기를 제공하고, 60초에는 transaction을 무효화해 로컬 인식 또는 재촬영만 제안한다.
- Disposition: modified. Firebase의 문서상 180초는 SDK 기본 제한이지 이 OCR 앱이 사용자에게 보장해야 할 UX 시간이 아니다. 사용자가 명시적으로 더 기다리더라도 모바일 단일 이미지 OCR에 3분은 과도하므로 사용자가 정한 60초 상한을 우선한다.
- Rejected/modified: 180초 앱 watchdog과 요청별 60초 초기화는 기각했다. 60초 이후 원본 네트워크 Future가 계속 실행될 수는 있지만 `transactionId`를 무효화해 늦은 성공·실패가 UI를 변경하지 못하게 한다.
- Verification/evidence: user-approved product constraint; Firebase AI Logic documents a 180-second default request timeout, while Dart `Future.timeout` documents that the source future can still complete after the timeout. Boundary behavior requires fake-clock tests at 10 and 60 seconds.

```mermaid
flowchart LR
    START["클라우드 인식 시작 · 0초"] --> TEN["10초 · 느림 안내"]
    TEN -->|기기에서 인식| LOCAL["클라우드 결과 무효화<br/>ML Kit 실행"]
    TEN -->|조금 더 기다리기| WAIT["같은 요청 유지<br/>남은 예산 최대 50초"]
    WAIT -->|60초 전 성공| RESULT["결과 표시"]
    WAIT -->|누적 60초| LIMIT["transactionId 무효화"]
    LIMIT --> FALLBACK["기기에서 인식 또는 다시 촬영"]
```

### 2026-09-28 — user + AI / 설계 명세 우선과 문서 정합성 게이트

- Request/prompt: README 전체를 검증할 수 있는지 확인한 뒤, 문서와 테스트 중 무엇을 먼저 진행할지 근거를 비교하고 뒤처진 문서 정리를 반드시 할 일로 남김.
- README basis: 기능·성능·예외·테스트뿐 아니라 아키텍처와 라이브러리 선택 이유, trade-off, 검증 기기, AI 채택·수정·기각 과정을 최종 README에 설명해야 한다.
- Decision/result: 합의된 아키텍처·상태·오류·테스트를 단일 설계 명세로 먼저 고정하고, 사용자 검토 후 테스트 중심 구현 계획을 작성한다. `PRD.md`, `CONTEXT.md`, `E2E_TESTING.md`, `AGENTS.md`, 에이전트 카탈로그의 확인된 drift는 구현 실행 전 `D0` 게이트에서 교정한다.
- Disposition: adopted. 현재 앱과 인터페이스가 없어 테스트부터 쓰면 상태·오류·파일 수명·Pigeon 계약을 테스트 코드가 우연히 결정하고 병렬 작업 간 계약이 달라질 수 있기 때문이다.
- Rejected/modified: 기능 코드부터 작성하는 방식과 모든 문서를 먼저 전면 개편하는 방식은 기각했다. 문서 작업 자체가 목적이 되지 않도록 새 문서 부채 목록은 만들지 않고 설계 명세와 이후 구현 계획에 파일별 완료 조건을 둔다.
- Verification/evidence: `docs/superpowers/specs/2026-09-28-altinus-camera-ocr-design.md`; 구현·테스트·실기기 증거는 아직 생성되지 않았으며 확인 후에만 추가한다.

### 2026-09-28 — user + AI / HTTP 클라이언트 경계와 Dio 사용 조건

- Request/prompt: raw HTTP client를 직접 모두 구현·검증하지 말고 Dio를 사용하도록 결정.
- Decision/result: 현재 클라우드 OCR은 공식 `firebase_ai` SDK가 전송을 소유하므로 별도 HTTP 계층이나 Dio 의존성을 추가하지 않는다. 이후 승인된 직접 HTTP endpoint가 생길 때는 raw `dart:io HttpClient` 대신 버전을 고정한 Dio adapter를 사용한다.
- Disposition: adopted with scope clarification. Dio는 interceptor, timeout, cancellation, adapter를 제공해 직접 HTTP 경계에는 적합하지만, 공식 SDK 위에 사용하지 않는 wrapper를 추가하면 의존성과 테스트만 중복되기 때문이다.
- Rejected/modified: Firebase AI Logic SDK를 Dio 기반 직접 REST 호출로 교체하는 방식과, 실제 endpoint 없이 미리 Dio를 추가하는 방식은 인증·보안·오류 처리 범위를 다시 만들거나 미사용 의존성을 남기므로 기각했다.
- Verification/evidence: official `firebase_ai` package metadata identifies it as the Firebase AI Logic SDK and lists its own HTTP dependency; Dio package documentation lists cancellation, timeout, interceptor, and adapter support. Implementation dependency changes are not required by this decision.

### 2026-09-28 — user + AI / 설계 명세 최종 승인과 구현 계획 전환

- Request/prompt: Firebase SDK 전송을 유지하고 직접 HTTP가 생길 때만 Dio를 사용하도록 수정한 설계 명세를 최종 승인.
- Decision/result: D0 문서 정합성, Flutter 기반, 도메인/상태 머신, 카메라, Firebase, Pigeon, Android/iOS ML Kit, 통합 테스트, 양 플랫폼 실기기, clean clone 순서의 테스트 중심 구현 계획을 작성한다.
- Disposition: adopted. 공유 계약과 고위험 비동기 상태를 먼저 고정한 뒤 SDK·플랫폼 adapter를 분리하면 재작업과 병렬 충돌을 줄이고 README 평가항목별 증거를 생성할 수 있기 때문이다.
- Rejected/modified: 모든 기능을 한 에이전트가 한 번에 구현하거나 iOS 통합을 마지막까지 미루는 방식은 기각했다. 병렬 작업은 기반 계약 완료 후 서로 겹치지 않는 Android/iOS 또는 adapter 파일에만 허용한다.
- Verification/evidence: `docs/superpowers/plans/2026-09-28-altinus-camera-ocr.md`; 구현과 기기 검증은 아직 시작하지 않았다.

### 2026-09-28 — user + AI / D0 실행 문맥 정합성

- Request/prompt: 구현 전 stale execution context를 승인된 설계 명세와 일치시키고, 기존 AI 결정 기록은 append-only로 보존.
- Scope/files: `docs/PRD.md`, `docs/CONTEXT.md`, `docs/E2E_TESTING.md`, `.agents/catalog.yaml`; `AGENTS.md`는 확인만 수행.
- Decision/result: Flutter 3.47.5 / Dart 3.13.4, 결과 표시 전용, `firebase_ai` cloud-first와 공식 한국어 ML Kit Pigeon fallback, 수동 Riverpod NotifierProvider, 10초 선택·누적 60초 cloud budget·최대 2회 시도, Android 반복 개발·iPhone 최종 증거, clean-clone/fixed-input/cloud-local/Pigeon/frames/memory/heat evidence를 현재 실행 기준으로 반영했다. 카메라 권한 용어는 공식 패키지 상태(`denied`, `restricted`, `permanentlyDenied`)를 유지한다.
- Disposition: adopted.
- Verification/evidence: pre-edit drift search matched superseded stack, selectable/copyable, Flutter/Dart versions, and uncommitted-stack/decision markers; D0 gates run after reconciliation.

### 2026-09-28 — user + AI / SDK 없는 OCR 도메인 계약과 상태 고정

- Request/prompt: SDK 타입이 새지 않는 OCR·카메라·저장소·설정 경계와 immutable OCR 흐름 상태를 TDD로 구현.
- Decision/result: Cloud/local OCR, 이미지 준비·정리, 설정, 공개 동의, 카메라 계약을 순수 Dart 타입으로 분리했다. `OcrResult`는 공백 텍스트를 거부하고, `transportTransient`만 재시도 가능하다. sealed `OcrFlowState`는 모든 화면 상태와 cloud transaction ID·시도 수·지연 표시·시작 시각 및 결과 엔진을 모델링한다.
- Disposition: adopted. 이후 Firebase, camera, Pigeon adapter와 controller가 컴파일 시점의 SDK-독립 경계에 의존하도록 하기 위함이다.
- Verification/evidence: test-first RED에서 누락된 도메인 타입 오류를 확인한 후 focused test 4개를 GREEN으로 통과했다. `dart analyze lib/features test/features`와 ASCII 임시 복제본의 exact `flutter analyze lib/features test/features`가 통과했다. 원본 한글 상위 경로의 Flutter analyze는 분석 서버 LSP 초기화 파싱 오류로 실패하는 기존 환경 제약이다.

### 2026-09-28 — user + AI / OCR 텍스트 생성자 불변식 보강

- Request/prompt: public `TextDetected` 생성자가 공백 텍스트 불변식을 우회할 수 있다는 리뷰 지적을 수정하고, 모든 failure kind의 retryability를 증명.
- Decision/result: `TextDetected`의 unchecked public const 생성자를 제거하고, 검증하는 public factory와 private const 생성자로 제한했다. 재시도 테스트는 `OcrFailureKind.values` 전체를 순회하여 `transportTransient`만 true임을 확인한다.
- Disposition: adopted. 모든 public construction path에서 `OcrResult`의 nonblank 도메인 불변식을 보장하고 향후 enum 추가 시 보수적 재시도 정책의 회귀를 막기 위함이다.
- Verification/evidence: 새 direct-construction regression test는 수정 전 `returned <Instance of 'TextDetected'>`로 RED를 확인했고, 수정 후 focused test 5개와 전체 test 6개가 통과했다. ASCII 임시 복제본에서 exact `flutter analyze lib/features test/features`도 통과했다.

### 2026-09-28 — user + AI / 단일 소유 OCR transaction controller 구현

- Request/prompt: Task 3의 SDK-독립 port/state만 사용해 수동 Riverpod auto-dispose controller를 TDD로 구현하고, 10초 선택·60초 누적 마감·최대 2회 시도·local 전환·stale completion·lifecycle·정리 경계를 fake clock으로 검증.
- Scope/files: `lib/features/ocr/application/ocr_flow_controller.dart`, `lib/features/ocr/application/ocr_providers.dart`, `test/features/ocr/application/ocr_flow_controller_test.dart`, `test/support/ocr_fakes.dart`.
- Decision/result: 카메라 async operation ID와 cloud/local transaction ID를 분리하고 모든 async 상태 쓰기를 소유권으로 보호했다. 10/60초 timer는 capture 성공 직후와 image preparation 전에 한 번만 시작하고, `keepWaiting`과 retry가 원본 request·attempt·deadline을 바꾸지 않게 했다. 임시 파일은 capture 소유 세대별로 기록해 같은 경로가 재사용되거나 preparation이 늦게 완료되어도 소유 파일만 한 번씩 정리한다.
- Disposition: adopted with deterministic timing injection. 운영 retry는 최대 2초로 제한된 exponential backoff + jitter를 사용하고, 테스트는 500ms 전략으로 override해 경계를 재현 가능하게 고정했다.
- Rejected/modified: request별 60초 timer 재생성, 임의 예외 메시지를 분석한 retry, local 선택 후 cloud 결과 반영, 경로 문자열 전역 dedup은 기각했다. 특히 경로 재사용은 새 파일 소유권이므로 capture 세대별 정리로 수정했다.
- Verification/evidence: 최초 RED는 controller/provider 파일 누락 컴파일 실패였다. lifecycle/recapture 경합은 수정 전 initialize count `expected 1, actual 2`, 경로 재사용은 cleanup count `expected 2, actual 1`로 각각 RED를 확인했다. deadline 후 늦은 cleanup 실패가 `CloudRecovery`를 `RecoverableError`로 덮어쓰는 RED도 추가로 확인했다. 최종 focused 23개, 전체 29개 test가 통과했고, `dart analyze` 및 ASCII 복제본의 exact `flutter analyze lib/features/ocr/application test/features/ocr/application test/support/ocr_fakes.dart`가 문제없이 완료됐다. 원본 한글 상위 경로의 `flutter analyze`는 기록된 analysis-server LSP JSON 파싱 결함으로 코드 진단 전 종료됐다.

### 2026-09-28 — AI review fix / OCR controller 진입·경로 소유·예외 경계 보강

- Review/request: Task 4 리뷰에서 `start`/`acceptDisclosure` 중복·오진입, 오래된 owner와 새 owner가 같은 경로를 겹칠 때의 잘못된 실제 삭제, 그리고 port 예외의 미분류·dispose 후 zone leak를 Important 문제로 보고.
- Decision/result: `start` 진입은 `Booting`, `acceptDisclosure` 진입은 `DisclosureRequired`로 제한하고 각각 pending flag로 첫 await 전부터 debounce했다. 파일 owner ID는 capture 콜백이 아닌 capture 시작 순서로 배정한다. 더 최신 owner의 capture/preparation이 경로를 생산 중이면 오래된 정리를 유예하고, 같은 경로를 이미 최신 owner가 claim했으면 오래된 물리 삭제를 억제한다. 물리 cleanup이 진행 중일 때는 새 capture를 받지 않는다.
- Exception policy: orphan cleanup, disclosure read/write, recapture cleanup, active camera disposal, settings launch 실패를 메시지 파싱 없이 domain `OcrFailure` 회복 상태로 변환했다. operation/state 소유권이 사라진 실패는 현재 상태를 바꾸지 않고, provider dispose 후 camera/file cleanup 실패는 contained future로 종료한다.
- Disposition: adopted. 단순 path-string dedup이나 오래된 cleanup의 즉시 실행은 활성 파일 삭제 가능성 때문에 기각했다. 경로 생산과 물리 cleanup 사이를 owner 세대와 gate로 직렬화했다.
- Verification/evidence: 수정 전 duplicate `start`는 orphan cleanup `expected 1, actual 2`, cloud 중 `start`는 camera initialize `expected 1, actual 2`로 RED였다. 늦은 capture의 정리가 newer active path를 실제 cleanup하고, newer pending claim 전에도 cleanup을 시작하는 RED를 확인했다. orphan cleanup 예외은 수정 전 private message와 stack으로 zone에 누출되고 state가 `Booting`에 머물렀다. 보강 후 focused 42개와 전체 48개 test, in-place `dart analyze`, ASCII 복제본의 exact `flutter analyze lib/features/ocr/application test/features/ocr/application test/support/ocr_fakes.dart`가 통과했다.

### 2026-09-28 — AI re-review fix / live file claims and invalidatable operation tokens

- Review/request: Task 4 second review found that pending path-producer waits could deadlock after invalidation, historical highest-owner state could suppress a necessary later cleanup, failed cleanup discarded retry ownership, entry booleans could be stuck or cleared by an older `finally`, and late preparation could delete the canonical input retained for local OCR.
- Decision/result: startup and disclosure work now use operation-scoped tokens that invalidation abandons independently. Capture assigns an owner and a producer marker before its first await; inactive, deadline, recapture, local selection, and provider disposal settle only the relevant wait marker while the underlying future remains free to finish into stale-owner recording and cleanup. A private ownership helper tracks only live path claims, serializes cleanup per owner, releases ownership only after successful physical cleanup or safe suppression by a newer live claim, and attempts every owner during disposal even after an earlier failure.
- Canonical policy: deadline and local fallback retain the active canonical claim. A late preparation cleans only newly derived stale outputs; recapture or disposal later cleans the retained canonical exactly once. Cleanup failures retain their paths and claims for a later retry.
- Disposition: adopted. Monotonic historical path ownership and shared in-flight booleans were removed because neither represents current ownership. Source futures are not treated as canceled; only controller wait markers and state authority are invalidated.
- Verification/evidence: regression-first failures included pending-start retry `expected 2, actual 1`, never-completing newer producer leaving older cleanup empty, released newer same-path ownership leaving physical cleanup count `expected 2, actual 1`, failed cleanup retry count `expected 2, actual 1`, and deadline-late preparation deleting the canonical path. After the fix, focused 54 tests and full 60 tests passed; in-place `dart analyze` and exact `flutter analyze` in ASCII copy `/tmp/altinus-task4-rereview.rm2kbA` reported no issues.

### 2026-09-28 — user + AI / first-run disclosure and recoverable OCR UI

- Request/prompt: Persist the approved camera/cloud disclosure and render every immutable OCR flow state with only controller actions, concise Korean recovery copy, and mobile-safe layout.
- Scope/files: SharedPreferences disclosure adapter; state-driven OCR presentation; app composition seam; focused persistence and widget tests.
- Decision/result: Acceptance is stored only as `disclosure.camera_cloud.v1`, with a missing value treated as unaccepted. The disclosure states camera purpose, cloud OCR image transfer, and no persistent local image storage. One exhaustive Dart switch maps each approved state to a display-only screen; cloud-only states can transition once to local OCR, whereas local outcomes cannot loop back. No user-facing copy exposes vendor, bridge, transport, exception, or numeric error details.
- Disposition: adopted. A provider-injected app home seam retains smoke bootability until Task 11 wires real adapters instead of adding fake production dependencies.
- Verification/evidence: Missing adapter/screen tests first failed at compilation (RED). Focused persistence/presentation tests then passed (13 tests), including exact `1/2`/`2/2`, 10-second actions, fallback boundaries, unsafe-copy absence, and a small viewport/2x text check. Native-path `flutter analyze` hit the known analysis-server LSP JSON path failure; an ASCII temporary copy completed the same requested analysis with no issues.

### 2026-09-29 — AI review correction / disclosure gate and recoverable progress UI

- Review/request: A recovery from startup failure could enter camera initialization without rechecking the persisted disclosure. The initial UI also lacked recovery actions for camera initialization, capture, and local recognition, and needed stronger copy, reachability, lifecycle, and semantics evidence.
- Decision/result: Every `recapture()` now reads `DisclosureStore.hasAccepted()` after cleanup and before either preview restoration or camera initialization. An unaccepted value returns to `DisclosureRequired`; a read failure returns safe domain recovery; operation ownership guards stale reads. Progress-only states expose the existing recapture action. Dynamic progress, result, empty, and recovery regions are live regions; titles are semantic headings; the viewport minimum height now contains its padding.
- Disposition: adopted. The disclosure gate is a privacy boundary and cannot be bypassed by recovery. Reusing the controller's existing recapture invalidation preserves bounded, user-directed recovery without inventing cancellation or new timeout policy.
- Verification/evidence: Regression-first controller tests failed with `PreviewReady` rather than `DisclosureRequired` and accepted-recapture read count `1` rather than `2`. Widget regressions failed for the missing disclosure screen, missing progress recapture key, and absent heading/live-region semantics. The corrected focused controller suite has 58 passing tests and presentation suite has 19; the final full suite has 85 and ASCII-path analysis has no issues.

### 2026-09-29 — AI re-review correction / serialized camera retry and stable recovery announcement

- Review/request: Retrying while camera initialization was still pending could create a second adapter-owned initialization before the first released its resources. The live-region wrapper was inconsistent across states, generic startup failures implied OCR/capture had already failed, and the lifecycle test did not actually dispose before the callback it intended to test.
- Decision/result: `CameraRepository.dispose()` now documents the adapter contract that it terminates pending initialization/resource ownership. A non-ready recapture invalidates the prior camera operation, awaits that teardown boundary, verifies ownership, then begins exactly one replacement initialization. The controllable camera fake models held initialization cancellation, active/max concurrent initialization, and live sessions. The screen has one stable, top-level live region for every switched state, while titles remain headings. `RecoverableError` presents only the neutral Korean “잠시 문제가 생겼어요. 다시 시도해 주세요.” with “다시 시도”. Startup is deferred to a scheduled second post-frame callback so a real build-phase replacement can dispose the screen before the provider read.
- Disposition: adopted. Starting a replacement before `dispose` completes would violate the camera adapter's exclusive resource ownership. Per-branch live regions were removed because permission and preview transitions otherwise had no consistent announcement container. A neutral recovery avoids making an untrue claim about which operation failed.
- Verification/evidence: New regression tests were RED before the implementation: pending-init recapture observed `disposeCount 0` and stale old initialization remained uncancelled; preview lacked the stable live region; injected raw startup failure lacked the generic copy; and the real build-phase disposal test observed one startup. After the correction, the focused controller/presentation command passed 79 tests, including max concurrent initialization `1`, one live replacement session, stale-completion suppression, preview/denial live semantics, generic unsafe-copy absence, and pre-callback disposal.
- Final verification: full `flutter test` passed 87 tests. The expanded `flutter analyze` scope passed with `No issues found` in a fresh ASCII-path temporary copy after the test fake stopped exposing a private held-initialization type through its public API.

### 2026-09-29 — AI final correction / shared camera teardown ownership

- Review/request: A recovery could read disclosure and exit before disposing a pending invalidated initialization; repeated recovery/lifecycle calls each invoked adapter teardown independently, so a stale teardown could overlap or outlive a replacement session.
- Decision/result: The controller now owns one `_cameraTeardownFuture`. `_ensureCameraDisposed()` starts `CameraRepository.dispose()` once, shares that exact future with every caller, and clears it only when that exact future settles. `recapture()` awaits teardown immediately after invalidation and before file cleanup or disclosure read; after the await, only the current operation can continue. `onInactive`, resume waiting, and terminal provider cleanup use the same boundary. A failed disposal leaves `_cameraNeedsDispose` true for a later user-directed retry, while terminal cleanup remains contained.
- Disposition: adopted. A shared controller boundary is required because repository resource ownership spans controller entry points; independent `dispose()` calls cannot prove ordering or prevent a stale teardown from reaching a newer camera session.
- Verification/evidence: RED controller tests observed `disposeCount 0` when disclosure was false or failed after a pending initialize, two dispose calls for rapid recaptures, and no second teardown after a failed inactive disposal. GREEN passed all four regressions: pending initialization is cancelled before false/error disclosure handling, rapid retries share one held teardown and produce one live replacement session with max concurrent initialization `1`, and teardown failure is retryable without an unhandled future.
- Final verification: focused controller/presentation tests passed 83 tests; full `flutter test` passed 91 tests. The expanded analysis scope reported `No issues found` in a fresh ASCII-path temporary copy; `git diff --check` passed.

### 2026-09-29 — user + AI / official camera adapter and lifecycle-safe preview

- Request/prompt: Integrate only Flutter's pinned `camera 0.12.1` behind an injectable pure facade, preserve SDK-free application/domain contracts, render an isolated preview, and own inactive/resume teardown without stale initialization or capture callbacks.
- Decision/result: Rear-only `ResolutionPreset.high`/audio-off sessions map exact permission codes without message parsing. Adapter initialization, capture, and per-session teardown use generation and single-flight ownership; failed teardown remains retryable, and a stale JPEG is deleted or handed to controller-owned cleanup. `CameraPreviewSurface` alone constructs `CameraPreview`; fake repositories render a neutral placeholder. Auto/off flash appears only after a successful auto probe, hides on failure, and resets through lifecycle reinitialization.
- Disposition: adopted after review corrections. Front-camera fallback, duplicate capture, unsupported flash claims, lost failed-dispose ownership, forgotten stale paths, and concurrent native disposal calls were rejected.
- Verification/evidence: Test-first RED covered missing adapter/lifecycle behavior, rear-only fallback, teardown retry, stale deletion ownership, and single-flight disposal. Final full suite passed 116 tests; exact Flutter analysis passed in ASCII worktree `/tmp/altinus-task6-final.Liu301`; Android debug APK and iOS debug no-codesign app both built. Pinned CameraX uses `.jpg` and pinned AVFoundation defaults to JPEG; physical output/flash parity remains a later real-device gate.

### 2026-09-29 — AI review correction / terminal native teardown and boot lifecycle resume

- Review/request: `CameraController.dispose()` marks the controller disposed before native teardown settles, so a failed native release followed by a successful no-op retry cannot prove exclusive ownership was released. Booting work interrupted by lifecycle also lacked resume intent, and startup could run while the app was initially hidden or paused.
- Decision/result: `CameraPluginRepository` now latches the first teardown failure per concrete session, never invokes that session's dispose again, retains it, and blocks initialize/capture with `interrupted`; only a successful first teardown permits replacement initialization. The controller distinguishes its generic repository-level retry boundary from this terminal official-adapter state. Booting inactive records resume intent, resume creates a new guarded `start()` generation, and stale orphan-cleanup/disclosure completions cannot overwrite the new branch. `OcrScreen` deduplicates all non-resumed lifecycle states and defers initial boot while hidden/paused.
- Disposition: adopted. Process/app restart is the only conservative recovery after an unproven native release; UI remains generic. Controller-level retry remains valid only for repository implementations that can prove later release.
- Verification/evidence: RED observed a second raw dispose being accepted, only one boot attempt after inactive/resume, and hidden/paused mount failing to resume into preview. A production-semantics fake proves a later raw dispose would no-op, while the repository makes only one native call, retains ownership, rejects initialize/capture, and never opens a replacement. Refreshed final verification follows in the Task 6 report.
- Refreshed verification: format checked 26 files with zero changes; focused camera/controller/presentation passed 115 tests and the full suite passed 122. ASCII-path analysis reported no issues; Android debug and iOS debug no-codesign builds both succeeded. The remaining physical-device JPEG/flash/orientation gate is unchanged.

### 2026-09-29 — user + AI / bounded Firebase OCR core; project configuration pending

- Request/prompt: Implement Task 7 Steps 1–3 and a provider-ready Firebase SDK gateway, but stop before choosing or mutating any Firebase project because the user has not authorized which of four existing projects to reuse.
- Scope/files: `lib/features/ocr/data/{firebase_ai_ocr_service,image_preparer,temp_image_store}.dart`, `lib/features/ocr/application/ocr_providers.dart`, and focused data tests. `main.dart`, Firebase generated options/service files, console APIs, billing, and App Check were intentionally not changed.
- Decision/result: Added pinned `firebase_ai` structured OCR with `gemini-3.8-flash`, low thinking, JSON schema, `InlineDataPart`, transcription-only instructions, exact line preservation, strict duplicate/malformed/contradictory response rejection, and public-type-only error mapping. Added async file validation/read/write, 32 MiB source and 8192-dimension/32-Mi-pixel decode guards, isolate-owned decode/EXIF/resize/encode, sub-14-MiB derivatives, canonical preservation, partial-write cleanup, and path/symlink-safe prefixed orphan cleanup.
- Disposition: core adopted; Firebase configuration and live model/quota verification remain `NEEDS_CONTEXT` until the user selects an exact existing Firebase project ID. No `flutterfire configure`, project/app creation, AI Logic enablement, billing/App Check mutation, generated Firebase files, or synthetic `main.dart` initialization was performed.
- Review: independent review initially identified unbounded raster/source inputs, partial derivative retention, and duplicate JSON keys. Regressions were added first and all findings were fixed; final re-review reported no remaining Critical or Important findings.
- Verification/evidence: initial RED was missing production files; later REDs reproduced directory-symlink escape, non-safety block misclassification, duplicate JSON acceptance, excessive source dimensions/bytes, and partial-write retention. Final focused data tests passed 52, full suite passed 174, format/context-budget/diff checks passed, and scoped Flutter analysis reported no issues in ASCII copy `/tmp/altinus-task7-final.8nL1Cy`. Android debug and ASCII-copy iOS debug no-codesign builds succeeded. Original-path iOS build remains affected by the recorded Unicode-path SwiftPM encoding issue, not a Dart compile failure.

### 2026-09-29 — AI review correction / iOS capture cleanup and actual-byte image validation

- Review/request: Follow-up review found that pinned AVFoundation captures live under `Directory.systemTemp/camera`, outside `path_provider`'s iOS cache root; it also identified stat/read races, magic-byte-only upload validation, nonexclusive derivative naming, insufficient deletion identity checks, and incomplete EXIF direction evidence.
- Decision/result: Explicit owner cleanup now accepts only the injected cache root or pinned camera root and fails closed outside them, while startup cleanup remains limited to direct `altinus_ocr_` files in the derivative root. Cleanup rejects links/non-files, walks in-root components, revalidates after resolution, and deletes the resolved candidate. Portable Dart cannot make hostile ancestor replacement and unlink atomic, so the guarantee is intentionally scoped to private mobile sandbox roots. Image preparation and upload recheck actual bytes after stat; upload bytes are dimension/pixel bounded and fully decoded in `Isolate.run`, with MIME derived from the supported decoder. Derivatives use cryptographically random names and OS-exclusive creation with collision retry.
- Disposition: adopted. Silent outside-root cleanup was rejected because the controller would release ownership without deleting the iOS capture; arbitrary `Directory.systemTemp` cleanup and camera-root startup sweeping were also rejected.
- Verification/evidence: regression-first compilation failures proved the new seams were absent. GREEN includes distinct cache/camera-root deletion boundaries, outside/traversal/symlink/root-identity/race rejection, propagated cleanup failures and controller ownership retry, fake/truncated/path-replaced/growing images, bounded decode, exclusive collision retention, clockwise EXIF marker placement, and mirrored EXIF placement. Focused data tests passed 65, full suite passed 187, scoped ASCII-path analysis reported no issues, and Android debug plus ASCII-copy iOS debug no-codesign builds succeeded. Firebase project selection/configuration and live model verification remain explicitly pending user choice.

### 2026-09-29 — user + AI / typed Pigeon boundaries and implicit-engine registration correction

- Request/prompt: Generate reproducible typed Korean OCR/settings Pigeon contracts, keep generated files generator-owned, test app-owned Dart mappings, and correct the later iOS host-registration plan for Flutter 3.47.5's implicit-engine AppDelegate.
- Scope/files: `pigeons/platform_apis.dart`, generated Dart/Kotlin/Swift contracts, Dart OCR/settings adapters, focused adapter tests, and Task 10 registration instructions. No native host implementation or Firebase/external state changed.
- Decision/result: `NativeOcrGateway` and `SettingsGateway` isolate generated clients from app ports. Detected text is preserved, no-readable-text is explicit, null/blank detected text is `invalidResponse`, gateway exceptions are `bridge`, and settings booleans pass through. Task 10 now registers both generated setup classes after plugin registration with `engineBridge.applicationRegistrar.messenger()` and owns Runner Compile Sources membership for generated and handwritten Swift files.
- Disposition: adopted after review correction. `controller.binaryMessenger` was rejected because the committed Flutter template implements `FlutterImplicitEngineDelegate` and has no explicit controller registration boundary.
- Verification/evidence: adapter RED failed on missing types before implementation; GREEN passed the focused mappings. A temporary null-validation regression made the new null contradiction test fail by returning `NoReadableText`, then the restored implementation passed. Pigeon regeneration was stable; scoped analysis passed from an ASCII-path verification copy because the Korean parent path triggers the recorded analysis-server framing defect. Local Pigeon output confirms both `setUp(binaryMessenger:api:)` signatures, and the installed Flutter 3.47.5 template/engine examples confirm `engineBridge.applicationRegistrar.messenger()`.

### 2026-09-29 — user + AI / Android bundled Korean ML Kit hosts

- Request/prompt: Implement Task 9 only: pin bundled Korean ML Kit `16.0.1`, implement the generated asynchronous OCR/settings hosts, register both in `configureFlutterEngine`, preserve recognized text exactly, and close recognizer resources on every terminal path without logging image paths or text.
- Scope/files: Android app Gradle dependency, `MlKitNativeOcrHostApi`, `AndroidAppSettingsHostApi`, `MainActivity`, and focused JVM policy tests. Generated Pigeon files, iOS, Firebase configuration, and external state were not changed.
- Decision/result: Missing, blank, and non-file paths fail before decoding; `InputImage.fromFilePath` and `KoreanTextRecognizerOptions` feed asynchronous ML Kit processing. Blank results map to `NO_READABLE_TEXT`, nonblank results are returned byte-for-byte as Kotlin strings, and all host errors use sanitized Pigeon `FlutterError` callbacks. Recognizers are closed before every success/failure callback after creation. App settings opens the package details intent.
- Disposition: adopted with a narrow pure-policy seam and JUnit dependency; Robolectric and broader native test dependencies were not added. No path or recognized text is logged or included in error details.
- Verification/evidence: RED failed because `NativeOcrPolicy` did not exist; GREEN passed 3 focused policy tests. Pigeon regeneration produced no generated diff, the 7 Dart adapter tests passed, ML Kit resolved exactly to `16.0.1`, app-scoped Gradle unit tests and `lintDebug` passed, and a debug APK built. The aggregate unqualified Gradle test task also ran CameraX plugin-owned Robolectric tests and failed 55 of 180 because the plugin misdecoded the Korean parent path; this is retained as an environment risk rather than masked by app configuration changes.
