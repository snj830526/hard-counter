# Hard Counter

## Project Goal

iPhone용 1:1 카운터 중심 격투 게임.

상대의 펀치를 보고 피한 뒤,
빈틈에 반격하는 짧고 직관적인 전투가 핵심이다.

초기 목표는 완성된 게임이 아니라
스틱맨 캐릭터를 이용해 아래 감각을 검증하는 것이다.

- 공격 타이밍
- 회피 쾌감
- 카운터 타격감
- 반복 플레이 가능성

## Target Platform

- iPhone only
- Landscape orientation
- Swift
- SwiftUI app lifecycle
- SpriteKit for gameplay
- No iPad optimization in the prototype
- No external game engine

## Game Modes

최종적으로 두 가지 모드를 제공한다.

1. Solo
   - CPU 상대
   - 핵심 전투 시스템과 손맛을 먼저 검증
2. Online 1v1
   - 다른 플레이어와 실시간 대전
   - Solo 전투 시스템 검증 후 구현

현재 작업 범위는 Solo 프로토타입만 포함한다.
온라인, 매칭, 랭크 시스템은 구현하지 않는다.

## Core Combat

초기 전투 행동은 두 가지다.

- Punch
- Dodge

핵심 플레이 흐름:

1. 상대의 펀치 예비동작을 본다.
2. 적절한 타이밍에 회피한다.
3. 회피 직후 열린 짧은 시간 안에 펀치를 입력한다.
4. 성공 시 일반 공격보다 강한 Counter Hit가 발생한다.

## Prototype Character

초기 캐릭터는 관절형 스틱맨으로 구현한다.

스틱맨은 단순한 정적 플레이스홀더가 아니다.
다음 감각을 확인할 수 있는 애니메이션 프로토타입이어야 한다.

- Idle 자세와 미세한 체중 이동
- Punch 예비동작, 뻗기, 접촉, 회수
- 상체와 머리를 이용한 Dodge
- 일반 Hit 반응
- 강한 Counter Hit 반응
- KO 반응

외형, 복장, 얼굴 및 최종 캐릭터 아트는 구현하지 않는다.

## First Milestone

하나의 전투 장면에서 아래 흐름을 실행할 수 있어야 한다.

- 플레이어와 CPU 스틱맨이 서로 마주 본다.
- CPU가 일정 간격으로 읽을 수 있는 펀치를 시도한다.
- 플레이어가 화면 입력으로 회피한다.
- 회피 성공 직후 펀치하면 Counter Hit가 발생한다.
- 일반 Hit와 Counter Hit의 반응이 명확히 다르다.

## Controls

초기 iPhone 가로 화면 기준:

- 화면 왼쪽 영역 터치: Dodge
- 화면 오른쪽 영역 터치: Punch

정확한 제스처 방식은 프로토타입 플레이 후 변경 가능하다.

## Feel Requirements

Counter Hit에는 임시로 다음 효과를 적용한다.

- 짧은 hit stop
- 일반 공격보다 큰 피격 반응
- 작은 camera shake
- 명확한 시각 효과
- 임시 햅틱

수치는 상수로 분리해 반복 조정할 수 있게 한다.

## Architecture Guidelines

전투 규칙과 화면 표현을 가능한 한 분리한다.

권장 구성:

- GameScene
- FighterNode
- FighterState
- CombatSystem
- InputController
- CPUController
- CombatTuning

모든 타이밍과 수치는 `CombatTuning`에서 조절 가능하게 한다.

## Online Architecture

The final game will support real-time 1v1 matches through a lightweight
server hosted initially on a home Mac mini.

The server will be authoritative for:

- Room lifecycle
- Player input order
- Punch and dodge validation
- Hit and counter resolution
- Health and round state
- Match result

The iPhone client will be responsible for:

- User input
- Rendering
- Animation
- Effects
- Haptics
- Optional local prediction

The Solo prototype will use the same combat rules locally so that the
combat system can later be moved to or shared with the online server.


## Online Server

The online mode will use a lightweight real-time server hosted initially
on a home Mac mini.

Planned stack:

- Node.js
- TypeScript
- WebSocket
- In-memory room state for the prototype

The server will manage:

- Player connections
- Room creation and matching
- Input ordering
- Combat validation
- Match state
- Rematch flow


codex 에게 줄 요청

PROJECT.md와 Docs 문서를 읽고 기존 Xcode 프로젝트를 확인해줘.

오늘의 목표는 iPhone 실기기에서 Solo 전투의 조작감과 카운터 타격감을 확인하는 것이다.

먼저 다음을 수행해줘.

1. 제안된 구조 중 오늘 구현에 꼭 필요한 파일만 생성한다.
2. SwiftUI에서 SpriteKit CombatScene을 표시한다.
3. 관절형 스틱맨 두 명을 코드로 그린다.
4. 플레이어 Punch와 Dodge 입력을 구현한다.
5. CPU가 예비동작이 보이는 Punch를 반복한다.
6. Dodge 직후의 짧은 시간에 Punch가 적중하면 Counter Hit로 처리한다.
7. 모든 타이밍과 효과 수치를 CombatTuning에 모은다.
8. iPhone 가로 화면과 Safe Area를 고려한다.
9. 빌드 가능한 작은 단위로 작업하고 각 단계마다 커밋 후보 메시지를 제시한다.

온라인, 메뉴, 저장, 최종 아트는 구현하지 않는다.
먼저 현재 프로젝트 분석과 구현 계획을 제시한 뒤 작업을 시작한다.
