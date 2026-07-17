# Project Structure

Hard Counter는 SwiftUI 앱 내부에 SpriteKit 전투 화면을 포함한다.

현재 구현 범위는 iPhone 가로 화면에서 실행되는 Solo 전투 프로토타입이다.
온라인 기능은 구현하지 않지만, 전투 규칙이 SpriteKit 화면과 강하게 결합되지 않도록 구성한다.

HardCounter/
├── App/
│   ├── HardCounterApp.swift
│   └── ContentView.swift
│
├── Game/
│   ├── Scene/
│   │   └── CombatScene.swift
│   │
│   ├── Fighter/
│   │   ├── FighterNode.swift
│   │   ├── FighterState.swift
│   │   └── FighterSide.swift
│   │
│   ├── Combat/
│   │   ├── CombatAction.swift
│   │   ├── CombatEvent.swift
│   │   ├── CombatState.swift
│   │   ├── CombatEngine.swift
│   │   └── CombatTuning.swift
│   │
│   ├── Input/
│   │   ├── CombatInputSource.swift
│   │   └── TouchInputController.swift
│   │
│   ├── CPU/
│   │   └── CPUController.swift
│   │
│   └── Feedback/
│       ├── HapticController.swift
│       └── CameraFeedback.swift
│
├── Resources/
│   ├── Assets.xcassets
│   └── Audio/
│
└── Docs/
    ├── GameDesign.md
    ├── Architecture.md
    ├── AI-Usage.md
    └── DevLog.md
