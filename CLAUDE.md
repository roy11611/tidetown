# CLAUDE.md — 물때마을 (Tidetown)

이 파일은 Claude Code가 매 세션 시작 시 읽는 프로젝트 기준 문서다.
규칙이 바뀌면 이 파일과 `docs/` 문서를 먼저 고친 뒤 코드를 고친다.

## 1. 프로젝트 개요

- **게임:** 밀물·썰물로 땅이 바뀌는 한국 바닷가 마을 건설 퍼즐 (cozy puzzle city builder, 타일 배치형)
- **플랫폼:** 1차 PC(Steam, Windows), 2차 Android 포팅
- **현재 단계:** 프로토타입 — 목표는 "핵심 루프가 재미있는가" 검증. 그래픽은 색 블록으로 충분하다.
- **출시 범위(고정):** 섬 3개, 건물 타일 약 30종, 도전 모드 1종. 범위 밖 기능은 구현하지 말고 `docs/backlog.md`에 적기만 한다.
- **하지 않는 것:** 전투, 멀티플레이, 긴 스토리, 온라인 기능

## 2. 기술 스택

- 엔진: Godot 4.7.x (GDScript, static typing 사용)
- 테스트: GUT (Godot Unit Test) — `addons/gut/`
- 버전 관리: Git, 기능 단위로 commit
- 대상 해상도: 1920×1080 기준, 1280×720까지 깨지지 않게

## 3. 폴더 구조

```
project.godot
scenes/
  main.tscn            # 진입 씬
  board/               # 보드·타일 표시
  ui/                  # 손패(타일 3장), 점수, 물때 표시
scripts/
  core/                # 순수 게임 로직 (Node 의존 금지, RefCounted 기반)
    board_state.gd     # 격자, 셀 종류, 배치된 건물
    tile_defs.gd       # 타일 정의 로드 (data/tiles.json)
    placement.gd       # 배치 가능 여부 판정
    scoring.gd         # 점수 계산
    tide.gd            # 물때 상태와 전환
    deck.gd            # 타일 뽑기 (seed 고정 RNG)
    game_state.gd      # 턴 흐름, 목표 점수, 게임 종료
  view/                # 화면 표시와 입력 처리 (core를 호출만 함)
data/
  tiles.json           # 타일 종류·점수 규칙 수치
  islands/island_01.json
tests/
  unit/                # core 로직 단위 테스트
tools/
  sim/                 # headless 밸런스 시뮬레이터
docs/
  rules.md             # 게임 규칙 명세 (단일 진실 공급원)
  architecture.md      # 구조 설계
  decisions.md         # 설계 결정 기록 (날짜, 결정, 이유)
  backlog.md           # 범위 밖 아이디어
```

## 4. 아키텍처 원칙

1. **core와 view 분리:** `scripts/core/`는 Node·씬·입력을 전혀 모른다. view는 core의 메서드를 호출하고 signal로 갱신만 받는다. 그래야 headless 테스트와 시뮬레이션이 가능하다.
2. **데이터 주도:** 타일 점수, 물때 주기, 목표 점수 같은 수치는 `data/*.json`에 둔다. 코드에 magic number 금지.
3. **결정론적 RNG:** 모든 무작위는 seed를 받는 `RandomNumberGenerator` 하나를 통해서만 쓴다. 같은 seed면 같은 게임이 재현되어야 한다.
4. **규칙의 기준은 `docs/rules.md`:** 코드와 문서가 다르면 문서가 기준이다. 규칙을 바꾸려면 문서부터 고친다.

## 5. 게임 규칙 초안 (v1 — 플레이테스트로 바뀔 예정)

자세한 명세는 `docs/rules.md`. 여기에는 요약만 둔다.

**셀 종류:** 육지(LAND), 갯벌(FLAT), 바다(SEA)

**물때:** 밀물(HIGH) / 썰물(LOW). 썰물로 시작해 4턴마다 전환. 턴은 타일을 놓는 것이고, 버리기는 턴이 아니다.
- 썰물: 갯벌이 드러나 염전 배치 가능
- 밀물: 갯벌은 바다(물 칸)로 취급, 새 배치 불가

**턴 흐름:**
1. 덱에서 타일 3장을 보여 준다
2. 플레이어가 1장을 골라 배치한다 (나머지 2장은 덱 아래로). 배치 대신 1장을 버릴 수도 있다 (0점, 턴과 물때는 그대로)
3. 배치 점수를 즉시 계산한다 (놓는 순간 한 번만, 이후 변동 없음)
4. 턴 +1, 물때 주기가 되면 전환하고 물때 점수를 정산한다
5. 누적 점수가 목표 이상이면 새 타일 묶음을 받고 목표가 올라간다
6. 남은 타일 중 지금 놓을 수 있는 것이 없으면 게임 종료 (타일이 다 떨어진 경우 포함)

**프로토타입 타일 6종 (수치는 `data/tiles.json`에서 조정):**

| 타일 | 배치 조건 | 점수 |
| --- | --- | --- |
| 집 House | 육지 | 인접 집 1개당 +1, 인접 시장이 있으면 +2, 인접 물 칸 1개당 +1, 인접 덕장 1개당 -1 |
| 부두 Pier | 바다(또는 밀물 때 갯벌)와 인접한 육지 | 밀물로 전환될 때마다 +3, 인접 부두 1개당 -1 |
| 시장 Market | 육지 | 인접 집·부두 1개당 +2 |
| 등대 Lighthouse | 육지, 섬당 1개 | 반경 2(가로 차이 + 세로 차이) 안의 부두 1개당 +3 |
| 염전 Salt Farm | 썰물 때 갯벌에만 | 썰물로 전환될 때마다 +2 |
| 덕장 Drying Rack | 육지 | 인접 부두 1개당 +2, 인접 집 1개당 -1 |

인접 = 상하좌우 4방향 (v1 기준, 변경 가능)

## 6. 코딩 규칙

- GDScript static typing 필수 (`var score: int = 0`, 함수 반환 타입 명시)
- 이름: 파일·변수·함수 `snake_case`, 클래스 `PascalCase` + `class_name`
- 한 함수는 한 가지 일만. 40줄이 넘으면 나눈다.
- public 메서드에는 한 줄 주석으로 역할을 적는다.
- 점수·배치 규칙을 추가하거나 바꾸면 **반드시 단위 테스트를 같이** 추가한다.

## 7. 명령어

Godot 실행 파일 이름은 환경마다 다르다. 아래 `godot`은 본인 PC의 Godot 4.7 실행 파일 경로로 바꿔 쓴다.

```bash
# 단위 테스트 전체 실행
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit

# 밸런스 시뮬레이션 (예: 1,000판, seed 42)
godot --headless -s tools/sim/run_sim.gd -- --games=1000 --seed=42

# 게임 실행
godot --path .
```

## 8. Claude 작업 규칙

1. 작업 시작 전 `docs/rules.md`와 `docs/architecture.md`를 읽는다.
2. 구현 전에 3–5줄짜리 계획을 먼저 보여 준다.
3. 테스트를 먼저 쓰고, 구현하고, 테스트를 실행해 통과를 확인한다. 실패하면 통과할 때까지 고친다.
4. 기능 하나가 끝나면 commit한다. 메시지 형식: `feat: 염전 점수 규칙 추가`, `fix: ...`, `test: ...`, `docs: ...`
5. 애드온·외부 라이브러리 추가, 폴더 구조 변경, 규칙 변경은 **먼저 물어본다.**
6. 설계 결정을 내렸으면 `docs/decisions.md`에 날짜·결정·이유를 한 줄로 남긴다.
7. `assets/` 폴더의 아트 파일은 수정하지 않는다.
8. 확신이 없는 규칙 해석은 추측하지 말고 질문한다.
