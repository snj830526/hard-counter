# Git 및 버전 관리

## 기본 전략

Hard Counter는 Git Flow를 단순화해 사용한다.

```text
main
  └─ develop
       ├─ feature/input-polish
       ├─ feature/new-punches
       └─ release/0.2.0

main
  └─ hotfix/0.1.1
```

## 브랜치 역할

### `main`

- 실행 및 배포 가능한 안정 버전만 둔다.
- feature 작업을 직접 커밋하지 않는다.
- 릴리스 병합 후 버전 태그를 추가한다.

### `develop`

- 완료된 기능을 통합하는 다음 개발 기준점이다.
- 새 feature 브랜치는 최신 `develop`에서 만든다.
- 검증되지 않은 실험을 직접 쌓지 않는다.

### `feature/<기능명>`

- 하나의 기능 또는 명확한 개선 작업을 담당한다.
- 영문 소문자와 하이픈을 사용한다.
- 예: `feature/input-polish`, `feature/rewrite-docs`
- 완료 후 `develop`으로 병합하고 브랜치를 정리한다.

### `release/<버전>`

- 배포 전 최종 안정화, 버전 번호, 릴리스 문서만 다룬다.
- 예: `release/0.2.0`
- 완료 후 `main`과 `develop` 양쪽에 반영한다.

### `hotfix/<버전-또는-문제>`

- 배포 버전의 긴급 문제를 `main`에서 수정한다.
- 완료 후 `main`과 `develop` 양쪽에 반영한다.

## 기능 개발 흐름

```bash
git switch develop
git pull --ff-only origin develop
git switch -c feature/<기능명>

# 구현과 검증
git add <변경 파일>
git commit -m "feat: 기능 설명"
git push -u origin feature/<기능명>
```

feature 브랜치의 검증이 끝나면 Pull Request로 `develop`에 병합하는 것을 기본으로 한다. 병합 전 최신 `develop`과의 충돌 여부 및 빌드를 다시 확인한다.

## 커밋 규칙

커밋 메시지는 다음 형식을 사용한다.

```text
<type>: <짧은 설명>
```

주요 type은 다음과 같다.

- `feat`: 사용자에게 보이는 기능 추가 또는 개선
- `fix`: 버그 수정
- `tune`: 게임 밸런스 및 손맛 수치 조정
- `refactor`: 동작 변경 없는 구조 개선
- `docs`: 문서 작성 또는 수정
- `test`: 테스트 추가 또는 수정
- `build`: Xcode 프로젝트와 빌드 설정 변경
- `chore`: 그 외 유지보수

하나의 커밋은 하나의 목적을 갖는다. 빌드 결과물, 개인 설정, 비밀 정보는 커밋하지 않는다.

## 병합 규칙

- feature → develop: Pull Request와 검증 후 병합
- release → main: 배포 준비 완료 후 병합 및 태그
- release → develop: 릴리스 중 수정 사항 역병합
- hotfix → main/develop: 양쪽에 반드시 반영
- `main`과 `develop`에는 강제 푸시하지 않는다.

팀 규모가 작더라도 원격에 올라간 공용 커밋은 `rebase`나 강제 푸시로 다시 쓰지 않는다. 수정이 필요하면 새 커밋 또는 `revert`를 사용한다.

## 버전 번호와 태그

릴리스 버전은 Semantic Versioning 형식을 사용한다.

```text
MAJOR.MINOR.PATCH
```

- MAJOR: 호환되지 않는 큰 구조나 제품 변화
- MINOR: 새로운 기능이 포함된 호환 가능한 릴리스
- PATCH: 버그 수정과 작은 안정화 릴리스

초기 개발 단계는 `0.x.y`를 사용한다. 릴리스 커밋을 `main`에 병합한 후 다음과 같이 태그한다.

```bash
git tag -a v0.1.0 -m "Hard Counter 0.1.0"
git push origin v0.1.0
```

## 저장소에 올리기 전 확인

1. 현재 브랜치가 작업 목적에 맞는가
2. 의도하지 않은 파일이 포함되지 않았는가
3. 시뮬레이터 및 실제 iOS 대상 빌드가 성공하는가
4. `git diff --check`가 통과하는가
5. 관련 문서가 현재 코드와 일치하는가
6. 커밋 메시지가 변경 목적을 설명하는가
