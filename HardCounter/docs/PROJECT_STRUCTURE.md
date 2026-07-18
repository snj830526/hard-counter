# 프로젝트 구조

## 기술 구성

Hard Counter는 SwiftUI 앱 안에 SpriteKit 전투 장면을 넣는 구조다.

```text
SwiftUI App
  └─ ContentView
      ├─ ModeSelectionView
      ├─ FighterSelectionView
      ├─ NearbyLobbyView
      └─ CombatContainerView
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
│   │   ├── CombatTuning.swift
│   │   └── FighterStats.swift
│   ├── Debug/
│   │   ├── MotionClipShowcaseController.swift
│   │   ├── MotionShowcaseController.swift
│   │   └── SwayShowcaseController.swift
│   ├── Feedback/
│   │   └── HapticController.swift
│   ├── Flow/
│   │   ├── FighterProfile.swift
│   │   ├── FighterPortraitView.swift
│   │   ├── FlowBackground.swift
│   │   ├── ModeSelectionView.swift
│   │   ├── FighterSelectionView.swift
│   │   ├── NearbyLobbyView.swift
│   │   ├── NetworkCombatContainerView.swift
│   │   └── CombatContainerView.swift
│   ├── Fighter/
│   │   ├── Fighter3DRenderer.swift
│   │   ├── Fighter3DMotionProfile.swift
│   │   ├── FighterNode.swift
│   │   ├── FighterRig.swift
│   │   ├── FighterAppearance.swift
│   │   ├── FighterGeometry.swift
│   │   ├── FighterPose.swift
│   │   ├── FighterMotionClip.swift
│   │   └── FighterLocomotion.swift
│   ├── Input/
│   │   ├── CombatControlsNode.swift
│   │   ├── FighterCommand.swift
│   │   ├── LocalInputSource.swift
│   │   ├── CPUInputSource.swift
│   │   └── SwayInputResolver.swift
│   ├── Network/
│   │   ├── NearbyLobbyModels.swift
│   │   └── NearbyLobbyService.swift
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
- `ContentView.swift`: 모드 선택, 캐릭터 선택, 경기 화면의 앱 흐름과 전환을 관리한다.
- `ModeSelectionView.swift`: 솔로와 근거리 대전 진입점을 제공한다.
- `NearbyLobbyView.swift`: 방 만들기·주변 방 찾기, 선수 선택과 양쪽 준비 상태를 하나의 근거리 로비 흐름으로 표시한다.
- `NetworkCombatContainerView.swift`: 로비 연결을 유지한 채 네트워크 전투 장면과 종료 동작을 SwiftUI 흐름에 연결한다.
- `FighterSelectionView.swift`: 출전 선수의 외형 테마와 능력치 미리보기를 선택한다.
- `FighterProfile.swift`: 선수 식별자, 이름, 스타일, 색상과 능력치 미리보기 데이터를 정의한다.
- `FighterPortraitView.swift`: 선수별 피부, 체형, 헤어와 장비 색상을 선택 카드의 사람형 초상으로 표현한다.
- `CombatContainerView.swift`: 선택된 선수로 `CombatScene`을 만들고 안전 영역 전달과 메뉴 복귀를 담당한다.

### 장면 계층

- `CombatScene.swift`: 게임 루프와 객체 조정자다. 입력 소스가 만든 공통 명령, 이동, 화면상 히트 거리, 전투 이벤트, HUD와 라운드 재시작을 연결한다. 확대된 경기장에는 데드존 기반의 부드러운 추적을 적용하고 HUD는 고정한다.
- `BoxingRingNode.swift`: 쿼터 뷰 축을 따르는 캔버스 패널과 봉제선, 조명 면, 로프, 포스트 및 저채도 로우폴리 관중석을 생성한다. 3D 캐릭터보다 배경이 튀지 않도록 색과 명암을 제한한다.
- `QuarterViewProjection.swift`: 정사각형 링 내부 좌표를 대각선 쿼터 뷰 화면 좌표로 변환하고, 화면 입력을 다시 링 이동 방향으로 역변환한다.

### 전투 계층

- `CombatEngine.swift`: 선수 상태와 전투 단계 전이를 관리한다. 이동 의도와 펀치 리듬으로 펀치 프로필을 만들고 스웨이 방향·유효 시간을 판정하며 SpriteKit 노드에 직접 의존하지 않는다.
- `CombatTuning.swift`: 피해량, 프레임 시간, 이동 속도, 사거리, 연출 시간 등 조정 가능한 수치를 모은다.
- `FighterStats.swift`: 선수별 최대 체력, 최대 스태미너와 이동 속도 배율을 정의하며 저스태미너 기준도 최대치 비율로 계산한다.

전투 상태는 대략 다음 순서로 흐른다.

```text
idle → punchStartup → punchActive → punchRecovery → idle
idle → swaying → idle
피격 → hit → idle
체력 0 → knockedOut
```

### 표현 및 입력 계층

- `FighterNode.swift`: 전투 이벤트를 포즈와 모션으로 연결하는 표현 계층의 조정자다. 방향, 상태 전환, 피격·KO 연출을 관리하지만 리그 생성과 이동 수학은 직접 소유하지 않는다.
- `Fighter3DRenderer.swift`: 기존 전투 상태와 모션 프로필을 읽어 저폴리곤 3D 스켈레톤의 가드, 셔플, 펀치, 스웨이, 피격과 KO를 표현하는 실험 렌더러다. 모든 절차형 포즈를 합친 뒤 무릎·고관절·발목 등 관절을 인체 범위로 제한하며 판정과 네트워크 상태는 소유하지 않는다.
- `Fighter3DMotionProfile.swift`: JIN, MASON, LEO와 CPU 라이벌의 가드 높이, 무릎 굽힘, 호흡, 보폭, 골반 회전, 리치, 스웨이 폭, 회복 무게와 대표 기술을 정의한다. 전투 능력치와 분리되어 모션 개성이 피해량이나 판정을 우연히 바꾸지 않는다.
- `FighterRig.swift`: 골반·상체 모션 루트와 허벅지–종아리–발목, 위팔–아래팔 노드 계층을 생성하고 캡슐화한다.
- `FighterAppearance.swift`: 피부와 음영, 체형, 헤어스타일, 트렁크·글러브·복싱화 색상을 선수별로 정의한다.
- `FighterGeometry.swift`: 로우 폴리곤 도형, 팔다리 길이와 공통 신체 색상을 제공한다.
- `FighterPose.swift`: 가드·펀치·스웨이 포즈 데이터와 펀치 프로필에 따른 순수 포즈 변형을 담당한다.
- `FighterMotionClip.swift`: 시간축 키프레임, 보간 곡선과 루트·발 고정 오프셋을 샘플링한다. 현재 가드 호흡, 리어 스트레이트와 스트레이트 피격 반응부터 이 경로를 사용한다.
- `MotionClipShowcaseController.swift`: Debug 실행에서 기존 리드 스트레이트와 시간축 리어 스트레이트를 번갈아 재생해 새 모션 경로를 A/B 비교한다.
- `SwayShowcaseController.swift`: Debug 실행에서 좌우 슬립·풀백·전진 실패를 일정한 간격으로 반복해 스웨이 실루엣을 비교한다.
- `FighterLocomotion.swift`: SpriteKit에 의존하지 않고 가드 호흡, 셔플 단계, 무릎·골반·상체의 절차형 오프셋을 프레임 데이터로 계산한다.
- `CombatControlsNode.swift`: 아날로그 스틱과 펀치/스웨이 버튼을 그리고 멀티터치 입력을 해석한다. 스틱과 버튼의 시각 피드백은 터치 시작 프레임에 즉시 표시한다.
- `FighterCommand.swift`: 이동과 전투 행동을 선수 식별자·입력 시각과 함께 전달하는 공통 명령 형식과 입력 소스 규약을 정의한다.
- `LocalInputSource.swift`: 이동 터치, 최근 스웨이 방향, 스웨이–펀치 버퍼를 소유하고 플레이어 명령을 만든다.
- `CPUInputSource.swift`: CPU 판단 결과를 로컬 입력과 같은 `FighterCommand`로 변환한다. 근거리 대전에서는 동일한 자리에 원격 입력 소스를 연결한다.
- `SwayInputResolver.swift`: 버튼을 누른 순간의 스틱 입력을 상대 축 기준의 좌우 슬립, 풀백, 전진 실패로 변환한다.
- `HapticController.swift`: 스트레이트·스매시·어퍼컷의 일반 타격, 강한 카운터, 스웨이 성공의 햅틱을 구분한다.
- `CPUController.swift`: 거리별 접근, 후퇴, 선회, 대기와 공격 시점을 결정한다.

### 근거리 네트워크 계층

- `NearbyLobbyModels.swift`: 호스트/게스트 역할, 로비 단계, 매치 구성, 전투 입력과 권위 상태 메시지를 정의한다.
- `NearbyLobbyService.swift`: Network.framework의 Bonjour 광고·검색과 일대일 TCP 연결을 관리한다. 길이 헤더가 있는 JSON 프레임으로 로비, 경기 시작, 입력과 상태 보정을 전달한다.
- 호스트는 왼쪽 선수, 게스트는 오른쪽 선수를 담당한다. 각 기기는 로컬 입력을 즉시 예측하고 호스트가 15Hz 상태 스냅샷으로 위치·체력·스태미너·승패를 교정한다. KO 후 재대결은 양쪽의 수락 투표가 모였을 때만 호스트가 실행한다.

## 의존 방향 원칙

- 전투 규칙은 화면 노드에서 분리한다.
- 시각 노드는 전투 이벤트를 받아 표현하되 승패 규칙을 결정하지 않는다.
- 모션 계산은 `FighterLocomotionController`, `FighterPoseResolver`, `FighterMotionClipPlayer`에서 수행하고, `FighterNode`는 계산 결과를 `FighterRig`에 적용한다.
- 시간축 클립은 루트 이동과 양발의 상쇄 오프셋을 함께 기록해 체중 이동 중에도 발이 매트에서 미끄러지지 않게 한다. 검증된 클립만 기존 상태 전환 모션을 단계적으로 대체한다.
- 3D 스파이크는 `FighterNode` 아래의 표현만 교체한다. 링 좌표, 히트 판정, 입력, CPU와 네트워크 메시지 형식은 2D 렌더러와 공유하므로 실험을 폐기해도 전투 로직에는 영향이 없어야 한다.
- 캐릭터 능력치는 `FighterStats`, 외형은 `FighterAppearance`, 모션 개성과 대표 기술 연출은 `Fighter3DMotionProfile`이 각각 소유한다. 이후 캐릭터 고유 기술의 실제 전투 규칙을 추가할 때는 표현 프로필을 직접 판정에 사용하지 않고 별도 전투 설정으로 명시적으로 연결한다.
- 절차형 모션은 마지막 적용 단계에서 관절 제한을 반드시 통과한다. 양쪽 무릎은 캐릭터 로컬 좌표에서 같은 해부학적 방향으로만 접히고 고관절의 좌우 벌림을 제한한다. 스탠스의 앞뒤 차이는 다리 뿌리의 깊이로 표현하며 발목은 고관절과 무릎의 합을 보정하되 과회전하지 않는다.
- 3D 캐릭터의 발바닥 기준점은 링 좌표와 같은 원점을 사용한다. 호흡은 상체에서 처리하고 스웨이는 골반보다 상체 이동 비중을 크게 두어 발이 접촉 그림자에서 떨어지지 않게 한다.
- 리그 계층이나 도형을 바꿀 때 모션 규칙을 함께 수정하지 않고, 모션 규칙을 바꿀 때 SpriteKit 노드 생성 코드를 건드리지 않는다.
- 이동 경계는 링 내부 좌표로 계산하고, 펀치 사거리와 선수 간 최소 간격은 실제 보이는 크기에 맞춰 투영된 화면 거리로 계산한다.
- 조정 수치는 가능한 한 `CombatTuning` 한 곳에서 관리한다.
- `CombatScene`이 지나치게 커지면 입력, 이동/충돌, HUD를 별도 객체로 분리한다.
- 온라인 기능을 추가할 때도 `CombatEngine`을 서버 또는 동기화 계층에서 재사용할 수 있어야 한다.
