# 프로젝트 구조

## 기술 구성

Hard Counter는 SwiftUI 앱 안에 SpriteKit 전투 장면을 넣는 구조다.

```text
SwiftUI App
  └─ ContentView
      └─ SpriteView
          └─ CombatScene
              ├─ 입력과 이동
              ├─ 전투 엔진
              ├─ CPU
              ├─ 캐릭터와 링 렌더링
              └─ 햅틱 및 화면 피드백
```

SwiftUI는 앱 생명주기, 가로 화면 요청, 안전 영역 전달을 담당한다. SpriteKit은 프레임 업데이트, 터치, 캐릭터와 링의 렌더링을 담당한다.

## 실제 디렉터리

```text
HardCounter/
├── HardCounterApp.swift
├── ContentView.swift
├── Assets.xcassets/
├── Game/
│   ├── CPU/
│   │   └── CPUController.swift
│   ├── Combat/
│   │   ├── CombatEngine.swift
│   │   └── CombatTuning.swift
│   ├── Feedback/
│   │   └── HapticController.swift
│   ├── Fighter/
│   │   └── FighterNode.swift
│   ├── Input/
│   │   ├── CombatControlsNode.swift
│   │   └── SwayInputResolver.swift
│   └── Scene/
│       ├── BoxingRingNode.swift
│       ├── CombatScene.swift
│       └── QuarterViewProjection.swift
└── docs/
    ├── README.md
    ├── GAME_CONCEPT.md
    ├── PROJECT_STRUCTURE.md
    ├── DEVELOPMENT_GUIDE.md
    ├── TESTING_GUIDE.md
    └── GIT_WORKFLOW.md
```

## 주요 파일의 책임

### 앱 계층

- `HardCounterApp.swift`: 앱 진입점과 가로 방향 제한
- `ContentView.swift`: `SpriteView` 생성, 시스템 UI 숨김, 안전 영역 전달

### 장면 계층

- `CombatScene.swift`: 게임 루프와 객체 조정자다. 터치 입력, 이동, 화면상 히트 거리, 전투 이벤트, HUD와 라운드 재시작을 연결한다. 확대된 경기장에는 데드존 기반의 부드러운 추적을 적용하고 HUD는 고정한다.
- `BoxingRingNode.swift`: 링 바닥, 로프, 포스트, 관중과 배경을 생성한다.
- `QuarterViewProjection.swift`: 정사각형 링 내부 좌표를 대각선 쿼터 뷰 화면 좌표로 변환하고, 화면 입력을 다시 링 이동 방향으로 역변환한다.

### 전투 계층

- `CombatEngine.swift`: 선수 상태와 전투 단계 전이를 관리한다. 이동 의도와 펀치 리듬으로 펀치 프로필을 만들고 스웨이 방향·유효 시간을 판정하며 SpriteKit 노드에 직접 의존하지 않는다.
- `CombatTuning.swift`: 피해량, 프레임 시간, 이동 속도, 사거리, 연출 시간 등 조정 가능한 수치를 모은다.

전투 상태는 대략 다음 순서로 흐른다.

```text
idle → punchStartup → punchActive → punchRecovery → idle
idle → swaying → idle
피격 → hit → idle
체력 0 → knockedOut
```

### 표현 및 입력 계층

- `FighterNode.swift`: 폴리곤 선수 리그, 독립적인 상·하체 풋워크, 가드/펀치/스웨이/피격/KO 포즈, 상대 방향에 따른 2.5D 자세를 표현한다. 정면에 가까운 각도에서는 방향과 팔다리 깊이에 히스테리시스를 적용해 시각적 뒤집힘을 막는다.
- `CombatControlsNode.swift`: 아날로그 스틱과 펀치/스웨이 버튼을 그리고 멀티터치 입력을 해석한다. 스틱과 버튼의 시각 피드백은 터치 시작 프레임에 즉시 표시한다.
- `SwayInputResolver.swift`: 버튼을 누른 순간의 스틱 입력을 상대 축 기준의 좌우 슬립, 풀백, 전진 실패로 변환한다.
- `HapticController.swift`: 일반 타격, 카운터, 스웨이 성공의 햅틱을 구분한다.
- `CPUController.swift`: 거리별 접근, 후퇴, 선회, 대기와 공격 시점을 결정한다.

## 의존 방향 원칙

- 전투 규칙은 화면 노드에서 분리한다.
- 시각 노드는 전투 이벤트를 받아 표현하되 승패 규칙을 결정하지 않는다.
- 이동 경계는 링 내부 좌표로 계산하고, 펀치 사거리와 선수 간 최소 간격은 실제 보이는 크기에 맞춰 투영된 화면 거리로 계산한다.
- 조정 수치는 가능한 한 `CombatTuning` 한 곳에서 관리한다.
- `CombatScene`이 지나치게 커지면 입력, 이동/충돌, HUD를 별도 객체로 분리한다.
- 온라인 기능을 추가할 때도 `CombatEngine`을 서버 또는 동기화 계층에서 재사용할 수 있어야 한다.
