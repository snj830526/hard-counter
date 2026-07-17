# Game Design

## Concept

Hard Counter is a simple PvP fighting game.

The core gameplay is not combo attacks.

The player waits for the opponent's attack,
dodges it,
and lands a decisive counter punch.

The goal is to maximize the feeling of reading the opponent.


## Design Change

Initially the project focused on Ring Out.

After reviewing the idea,
the core gameplay was simplified to:

Punch
Dodge
Counter

This change reduces implementation complexity
while emphasizing player skill and timing.


## Core Game

The core gameplay is identical in every mode.

- Punch

- Dodge

- Counter

- Health

- KO

Every game mode shares the same combat system.


## Game Modes

### Solo

Fight against AI opponents.

Features

- Practice
- Stage Progression
- Difficulty Levels

---

### Online PvP

Fight against another player.

Features

- 1 vs 1
- Matchmaking
- Ranking (Future)


## Prototype Art Strategy

초기 프로토타입은 스틱맨 형태의 관절 캐릭터를 사용한다.

외형 제작 비용은 최소화하되, 게임의 핵심인 공격 예고,
회피 궤적, 체중 이동, 피격 반응 및 카운터 타격감을
검증할 수 있도록 전투 애니메이션은 초기 단계부터 구현한다.

스틱맨은 단순한 임시 이미지가 아니라,
핵심 전투 감각을 검증하기 위한 애니메이션 프로토타입이다.
