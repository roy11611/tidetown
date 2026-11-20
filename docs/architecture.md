# 물때마을 구조 설계

규칙의 내용은 `docs/rules.md`가 기준이다. 이 문서는 그 규칙을 코드와 데이터로 어떻게 나누어 담는지를 정한다.

## 1. 원칙

1. **core와 view를 나눈다.** `scripts/core/`는 Node, 씬, 입력을 모른다. view와 시뮬레이터는 core를 호출하고 signal로 결과를 받는다. 그래야 headless 테스트와 시뮬레이션이 된다.
2. **수치는 데이터에 둔다.** 점수, 물때 주기, 목표, 덱 구성은 `data/*.json`에 있다. 코드에는 수치를 적지 않는다.
3. **무작위는 재현된다.** 한 판의 무작위는 seed로 만든 `RandomNumberGenerator` 하나에서만 나온다.
4. **규칙의 기준은 `docs/rules.md`다.** 코드와 문서가 다르면 문서가 맞다.

## 2. 계층과 의존 방향

```
scripts/view/, scenes/          tools/sim/
            \                     /
             \                   /
              v                 v
                 GameState                한 판의 진행. 바깥에서 부르는 유일한 입구
            /      |       |      \
     Placement  Scoring   Tide    Deck    판정, 점수, 물때 시계, 타일 줄
            \      |       /
             TileDefs     /               타일 정의 (tiles.json)
                  \      /
                 BoardState               격자, 지형, 건물
```

참조는 아래 방향으로만 한다.

| 클래스 | 파일 | 참조하는 것 |
| --- | --- | --- |
| `BoardState` | `board_state.gd` | 없음 |
| `Deck` | `deck.gd` | 없음 (난수 생성기를 밖에서 받는다) |
| `TileDefs` | `tile_defs.gd` | `BoardState`의 `Cell` enum |
| `Tide` | `tide.gd` | `BoardState`의 `Cell` enum |
| `Placement` | `placement.gd` | `BoardState`, `TileDefs`, `Tide` |
| `Scoring` | `scoring.gd` | `BoardState`, `TileDefs`, `Tide` |
| `GameState` | `game_state.gd` | 위 전부 |
| view, 시뮬레이터 | `scripts/view/`, `tools/sim/` | `GameState`. 읽기용으로 `BoardState`, `Tide`, `TileDefs` |

모든 core 클래스는 `RefCounted`를 상속하고 `class_name`을 갖는다. core 객체끼리 서로를 붙잡는 순환 참조를 만들지 않는다. `GameState`가 나머지를 소유하고, 아래 계층은 위 계층을 모른다.

## 3. 클래스

아래 코드는 선언만 적은 것이다(본문 생략). 구현할 때 public 메서드마다 한 줄 주석을 단다.

### 3.1 BoardState

격자, 지형, 건물만 안다. 규칙과 물때는 모른다.

```gdscript
class_name BoardState
extends RefCounted

enum Cell { LAND, FLAT, SEA }

static func from_island(island: Dictionary) -> BoardState   # 섬 데이터의 rows로 보드를 만든다
func size() -> Vector2i                                      # (가로, 세로)
func in_bounds(pos: Vector2i) -> bool
func get_cell(pos: Vector2i) -> Cell                         # 원래 지형. 물때는 반영하지 않는다
func has_building(pos: Vector2i) -> bool
func get_building(pos: Vector2i) -> StringName               # 건물이 없으면 &""
func place_building(pos: Vector2i, tile_id: StringName) -> void
func cells_within(pos: Vector2i, radius: int) -> Array[Vector2i]
func count_of(tile_id: StringName) -> int
func all_cells() -> Array[Vector2i]
```

- `cells_within`은 거리가 1 이상 `radius` 이하인 보드 안의 칸을 돌려준다. 자기 칸은 빼고, 보드 밖은 넣지 않는다. 거리는 가로 차이와 세로 차이의 합이다. `radius`가 1이면 인접 4칸이다.
- `all_cells`와 `cells_within`은 위에서 아래로, 같은 줄에서는 왼쪽에서 오른쪽으로 돌려준다. 순회 순서가 정해져 있어야 시뮬레이션이 재현된다.
- 좌표는 `Vector2i(x, y)`이고 `rows[y][x]`에 대응한다.
- `from_island`는 `GameState.validate_island`를 통과한 섬 데이터를 받는다. 형식은 다시 검사하지 않는다.
- 보드 밖에는 건물이 없으므로 보드 밖 좌표에 `has_building`은 `false`, `get_building`은 `&""`를 돌려준다. `get_cell`은 돌려줄 지형이 없으므로 `push_error`를 내고 `LAND`를 돌려준다.
- `place_building`은 보드 밖이거나, 이미 건물이 있거나, `tile_id`가 비어 있으면 보드를 바꾸지 않고 `push_error`를 낸다. 정상 흐름에서는 `Placement.check`가 먼저 막는다.

### 3.2 TileDefs

`data/tiles.json`을 읽고 검증한다. 만든 뒤에는 바뀌지 않는다.

```gdscript
class_name TileDefs
extends RefCounted

class ScoreRule:
	var on: StringName                           # &"place" | &"tide_high" | &"tide_low"
	var kind: StringName                         # &"flat" | &"count"
	var points: int
	var radius: int                              # count 전용
	var match_tiles: Array[StringName]           # count 전용. match_terrain과 둘 중 하나만 쓴다
	var match_terrain: Array[BoardState.Cell]
	var max_count: int                           # 0이면 제한 없음

class TileDef:
	var id: StringName
	var terrain: Array[BoardState.Cell]          # 놓을 수 있는 지형 (물때 반영 후)
	var adjacent_terrain: Array[BoardState.Cell] # 비어 있지 않으면 인접 칸 중 하나 이상이 이 지형이어야 한다
	var max_on_board: int                        # 0이면 제한 없음
	var rules: Array[ScoreRule]
	var display: Dictionary                      # 이름, 라벨, 색. view만 쓴다

static func from_dict(data: Dictionary) -> TileDefs          # 파싱한 json으로 만든다
static func load_file(path: String) -> TileDefs              # 파일을 읽어 from_dict에 넘긴다
func errors() -> PackedStringArray                           # 검증 오류. 비어 있어야 정상이다
func ids() -> Array[StringName]                              # json에 적힌 순서
func has_tile(tile_id: StringName) -> bool
func get_def(tile_id: StringName) -> TileDef
func rules_for(tile_id: StringName, event: StringName) -> Array[ScoreRule]
```

- `from_dict`와 `load_file`을 나눈 것은 테스트에서 파일 없이 정의를 만들기 위해서다.
- 검증에 실패한 정의로는 판을 만들지 않는다(3.7).
- `from_dict`는 데이터가 틀려도 `null`을 돌려주지 않고, 찾은 문제를 모두 `errors()`에 담는다. `load_file`도 파일이 없거나, JSON이 깨졌거나, 최상위가 객체가 아니면 그 내용을 `errors()`에 담은 빈 정의를 돌려준다. 부르는 쪽은 언제나 `errors()`만 보면 된다.

### 3.3 Tide

물때 시계다. "밀물의 갯벌은 바다" 판정도 여기 한 곳에만 둔다.

```gdscript
class_name Tide
extends RefCounted

enum Phase { LOW, HIGH }
signal phase_changed(new_phase: Phase)

func _init(initial: Phase, period_turns: int) -> void
func get_phase() -> Phase
func turns_until_switch() -> int                             # 1 이상 period_turns 이하
func advance_turn() -> bool                                  # 턴 하나를 진행한다. 물때가 바뀌었으면 true
static func effective_cell(cell: BoardState.Cell, phase: Phase) -> BoardState.Cell
```

- `effective_cell`은 밀물일 때 갯벌을 바다로 바꿔 돌려주고, 나머지는 그대로 돌려준다. `Placement`와 `Scoring`은 지형을 볼 때 반드시 이 함수를 거친다.
- `Tide`는 점수를 계산하지 않는다. 물때 점수 계산은 `Scoring.tide_scores`가 하고, 호출은 `GameState`가 한다.
- `advance_turn`은 배치한 턴에만 부른다. 버리기는 물때를 움직이지 않는다.
- `advance_turn`은 물때를 바꾼 다음 `phase_changed`를 보낸다. signal을 받는 쪽에서 `get_phase()`는 이미 새 물때다.
- `_init`은 `GameState.validate_island`를 통과한 값을 받는다(`period_turns`는 1 이상). 다시 검사하지 않는다.

### 3.4 Placement

배치 가능 여부를 판정한다. 상태가 없고 모두 static 함수다.

```gdscript
class_name Placement
extends RefCounted

enum Reason { ALLOWED, OUT_OF_BOUNDS, OCCUPIED, LIMIT_REACHED, WRONG_TERRAIN, NO_ADJACENT_TERRAIN }

static func check(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> Reason
static func can_place(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> bool
static func legal_cells(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName) -> Array[Vector2i]
static func has_legal_cell(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName) -> bool
```

`check`는 아래 순서로 검사해 처음 걸린 이유를 돌려준다. 순서가 정해져 있어야 테스트가 한 가지 답을 기대할 수 있다.

1. `OUT_OF_BOUNDS`: 보드 밖
2. `OCCUPIED`: 이미 건물이 있음
3. `LIMIT_REACHED`: `max_on_board`만큼 이미 놓았음
4. `WRONG_TERRAIN`: 물때를 반영한 지형이 `terrain`에 없음
5. `NO_ADJACENT_TERRAIN`: `adjacent_terrain`이 있는데 인접 칸 중 맞는 지형이 없음

- `legal_cells`는 `BoardState.all_cells`의 순서(위에서 아래, 같은 줄에서는 왼쪽에서 오른쪽)로 돌려준다. 봇이 같은 판에서 같은 칸을 고르게 하기 위해서다.
- `defs`에 없는 `tile_id`는 놓을 수 있는 지형이 없는 타일로 보고 `push_error`로 알린다. `check`는 위 순서대로 4번에서 `WRONG_TERRAIN`을 돌려주고, `legal_cells`는 빈 배열, `has_legal_cell`은 `false`를 돌려준다. 정상 흐름에서는 덱의 id를 `validate_island`가 먼저 검사한다.

### 3.5 Scoring

점수를 계산한다. 상태가 없고 보드를 바꾸지 않는다.

```gdscript
class_name Scoring
extends RefCounted

static func placement_score(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> int
static func tide_scores(board: BoardState, defs: TileDefs, new_phase: Tide.Phase) -> Dictionary[Vector2i, int]
static func rule_points(board: BoardState, phase: Tide.Phase, rule: TileDefs.ScoreRule, pos: Vector2i) -> int
```

- `placement_score`는 타일을 놓기 전의 보드로 계산한다. 화면의 예상 점수와 실제 점수가 같은 함수를 쓴다.
- `tide_scores`는 바뀐 뒤의 물때를 받아, 그 이벤트의 규칙이 있는 건물마다 점수를 돌려준다. 0점인 건물도 넣는다.
- `rule_points`는 규칙 하나의 점수다. 규칙 종류별 테스트를 쓰기 쉽게 공개한다.

### 3.6 Deck

타일의 줄이다. 난수 생성기는 밖에서 받는다.

```gdscript
class_name Deck
extends RefCounted

func _init(rng: RandomNumberGenerator) -> void
func add_bundle(counts: Dictionary) -> void                  # {"house": 3, ...}를 섞어 덱 아래에 넣는다
func draw(count: int) -> Array[StringName]                   # 위에서 최대 count장을 꺼낸다
func put_bottom(tiles: Array[StringName]) -> void            # 받은 순서대로 덱 아래에 넣는다
func size() -> int
func is_empty() -> bool
func contents() -> Array[StringName]                         # 위에서 아래 순서의 복사본
```

- `add_bundle`은 타일 id를 사전순으로 정렬해 펼친 다음 섞는다. 결과가 json의 키 순서가 아니라 seed와 구성에만 달려 있게 하기 위해서다.
- 섞기는 받은 난수 생성기로 직접 한다(뒤에서부터 `randi_range`로 자리를 바꾸는 방식). `Array.shuffle()`은 전역 난수를 쓰므로 쓰지 않는다.

### 3.7 GameState

한 판의 진행을 맡는다. view와 시뮬레이터가 부르는 유일한 입구다.

```gdscript
class_name GameState
extends RefCounted

signal tile_placed(pos: Vector2i, tile_id: StringName, points: int)
signal tile_discarded(tile_id: StringName)
signal tide_changed(new_phase: Tide.Phase, points_by_cell: Dictionary)
signal goal_reached(stage: int, new_goal: int)
signal score_changed(score: int, goal: int)
signal hand_changed(hand: Array[StringName])
signal game_over(final_score: int, stage: int)

static func load_island(path: String) -> Dictionary          # 섬 json을 읽는다. 실패하면 빈 Dictionary
static func validate_island(island: Dictionary, defs: TileDefs) -> PackedStringArray
static func create(defs: TileDefs, island: Dictionary, rng_seed: int) -> GameState   # 데이터에 오류가 있으면 null

func get_hand() -> Array[StringName]
func can_place(hand_index: int, pos: Vector2i) -> bool
func why_not(hand_index: int, pos: Vector2i) -> Placement.Reason
func legal_cells(hand_index: int) -> Array[Vector2i]
func preview_score(hand_index: int, pos: Vector2i) -> int
func place(hand_index: int, pos: Vector2i) -> bool           # 배치. 실패하면 false이고 아무것도 바뀌지 않는다
func discard(hand_index: int) -> bool                        # 버리기. 턴과 물때는 그대로다

func is_over() -> bool
func get_score() -> int
func get_goal() -> int
func get_stage() -> int
func get_turn() -> int                                       # 끝난 턴 수 = 배치한 횟수
func get_seed() -> int
func get_deck_size() -> int
func get_board() -> BoardState                               # 읽기만 한다
func get_tide() -> Tide                                      # 읽기만 한다
func get_defs() -> TileDefs
func get_stats() -> Dictionary
```

- `create`는 `defs.errors()`나 `validate_island`의 결과가 비어 있지 않으면 판을 만들지 않고 `null`을 돌려준다.
- 매개변수 이름을 `rng_seed`로 한 것은 `seed`가 GDScript 전역 함수 이름이기 때문이다.
- `get_stats()`는 시뮬레이터가 CSV를 만드는 데 쓴다. 아래 키를 갖는다.

| 키 | 값 |
| --- | --- |
| `placed` | 타일 id별 배치 횟수 |
| `discarded` | 타일 id별 버린 횟수 |
| `placement_points` | 타일 id별 배치 점수 합 |
| `tide_points` | 타일 id별 물때 점수 합 |
| `leftover` | 판이 끝났을 때 남은 타일 수 |

## 4. 행동 처리 순서

`docs/rules.md` 6장을 그대로 옮긴 것이다.

**`place(hand_index, pos)`**

1. 판이 끝났거나, `hand_index`가 손패 범위 밖이거나, `Placement.check`가 `ALLOWED`가 아니면 `false`를 돌려준다. 상태는 바뀌지 않는다.
2. `Scoring.placement_score`로 점수를 구한다(놓기 전 보드).
3. 건물을 놓고 점수를 더한다. `tile_placed`를 보낸다.
4. 고르지 않은 손패를 순서대로 `Deck.put_bottom`에 넘긴다.
5. `Tide.advance_turn()`을 부른다. `true`면 `Scoring.tide_scores`를 구해 더하고 `tide_changed`를 보낸다.
6. 점수가 목표 이상인 동안 반복한다: 단계를 올리고, 그 단계의 묶음을 `Deck.add_bundle`에 넘기고, 목표를 다음 값으로 바꾸고, `goal_reached`를 보낸다.
7. `score_changed`를 보낸다.
8. 다음 손패로 넘어간다(아래).

**`discard(hand_index)`**

1. 판이 끝났거나 `hand_index`가 손패 범위 밖이면 `false`를 돌려준다.
2. 고른 타일을 없앤다. `tile_discarded`를 보낸다.
3. 고르지 않은 손패를 순서대로 `Deck.put_bottom`에 넘긴다.
4. 다음 손패로 넘어간다(아래).

**다음 손패로 넘어가기**

1. 덱에 있는 타일 종류 가운데 지금 물때에 `Placement.has_legal_cell`이 참인 것이 하나도 없으면 판을 끝내고 `game_over`를 보낸다. 덱이 빈 경우도 여기에 걸린다.
2. 아니면 `Deck.draw(hand_size)`로 손패를 뽑고 `hand_changed`를 보낸다.

**단계와 목표**

- 단계 `s`의 목표: 데이터에 적힌 단계 수를 `n`이라 할 때, `s < n`이면 `stages[s].goal`, 아니면 `stages[n-1].goal + (s - n + 1) * goal_step`.
- 단계 `s`의 목표를 달성했을 때 받는 묶음: `s < n`이면 `stages[s].bundle`, 아니면 `after_last_stage.bundle`.

## 5. 데이터 스키마

json의 숫자와 배열은 읽어 온 뒤 검증하고 타입을 맞춰 옮겨 담는다. 검증 오류는 어느 타일의 어느 필드인지 알 수 있게 적는다.

### 5.1 `data/tiles.json`

v1 규칙을 그대로 옮긴 내용이다.

```json
{
  "schema_version": 1,
  "tiles": [
    { "id": "house",
      "display": { "name": "집", "label": "집", "color": "#E0B050" },
      "placement": { "terrain": ["LAND"] },
      "scoring": [
        { "on": "place", "type": "count", "match": { "tiles": ["house"] }, "radius": 1, "points": 1 },
        { "on": "place", "type": "count", "match": { "tiles": ["market"] }, "radius": 1, "points": 2, "max_count": 1 },
        { "on": "place", "type": "count", "match": { "terrain": ["SEA"] }, "radius": 1, "points": 1 },
        { "on": "place", "type": "count", "match": { "tiles": ["drying_rack"] }, "radius": 1, "points": -1 }
      ] },
    { "id": "pier",
      "display": { "name": "부두", "label": "부", "color": "#8D6E63" },
      "placement": { "terrain": ["LAND"], "adjacent_terrain": ["SEA"] },
      "scoring": [
        { "on": "tide_high", "type": "flat", "points": 3 },
        { "on": "tide_high", "type": "count", "match": { "tiles": ["pier"] }, "radius": 1, "points": -1 }
      ] },
    { "id": "market",
      "display": { "name": "시장", "label": "시", "color": "#D9534F" },
      "placement": { "terrain": ["LAND"] },
      "scoring": [
        { "on": "place", "type": "count", "match": { "tiles": ["house", "pier"] }, "radius": 1, "points": 2 }
      ] },
    { "id": "lighthouse",
      "display": { "name": "등대", "label": "등", "color": "#F5F5F5" },
      "placement": { "terrain": ["LAND"], "max_on_board": 1 },
      "scoring": [
        { "on": "place", "type": "count", "match": { "tiles": ["pier"] }, "radius": 2, "points": 3 }
      ] },
    { "id": "salt_farm",
      "display": { "name": "염전", "label": "염", "color": "#CFD8DC" },
      "placement": { "terrain": ["FLAT"] },
      "scoring": [
        { "on": "tide_low", "type": "flat", "points": 2 }
      ] },
    { "id": "drying_rack",
      "display": { "name": "덕장", "label": "덕", "color": "#A1887F" },
      "placement": { "terrain": ["LAND"] },
      "scoring": [
        { "on": "place", "type": "count", "match": { "tiles": ["pier"] }, "radius": 1, "points": 2 },
        { "on": "place", "type": "count", "match": { "tiles": ["house"] }, "radius": 1, "points": -1 }
      ] }
  ]
}
```

**타일 필드**

| 필드 | 필수 | 뜻 |
| --- | --- | --- |
| `id` | 예 | 타일 id. 소문자와 밑줄. 파일 안에서 겹치면 안 된다 |
| `display` | 아니오 | 이름, 한 글자 라벨, 색. core는 해석하지 않고 view에 넘긴다 |
| `placement.terrain` | 예 | 놓을 수 있는 지형. `LAND`, `FLAT`, `SEA` 중 하나 이상 |
| `placement.adjacent_terrain` | 아니오 | 있으면 인접 칸 중 하나 이상이 이 지형이어야 한다 |
| `placement.max_on_board` | 아니오 | 보드에 놓을 수 있는 최대 개수. 없으면 제한 없음 |
| `scoring` | 예 | 점수 규칙 목록. 비어 있어도 된다 |

**점수 규칙 필드**

| 필드 | 필수 | 뜻 |
| --- | --- | --- |
| `on` | 예 | 계산 시점. `place`(놓을 때), `tide_high`(밀물로 바뀔 때), `tide_low`(썰물로 바뀔 때) |
| `type` | 예 | `flat` 또는 `count` |
| `points` | 예 | 정수. 음수 가능 |
| `match` | `count`일 때 | `{"tiles": [...]}` 또는 `{"terrain": [...]}` 중 하나 |
| `radius` | `count`일 때 | 1 이상의 정수. 1이면 인접 |
| `max_count` | 아니오 | 세는 개수의 상한. 1이면 "하나라도 있으면" |

**검증에서 오류로 잡는 것**

- 겹치는 `id`, 빈 `terrain`, 모르는 지형 이름, 모르는 `on`이나 `type`
- `match.tiles`에 적힌 id가 파일에 없음
- `match`에 `tiles`와 `terrain`이 둘 다 있거나 둘 다 없음
- 정수가 아닌 `points`, `radius`, `max_count`, `max_on_board`, 또는 1보다 작은 `radius`, `max_count`, `max_on_board`
- 스키마에 없는 필드 이름(오타를 잡기 위해)
- 필수 필드가 없거나 타입이 틀림(배열 자리에 문자열 등). 최상위의 `tiles`도 필수다
- 소문자와 밑줄로 된 문자열이 아닌 `id`(숫자도 안 된다)
- 1이 아닌 `schema_version`(없는 경우 포함)
- `flat` 규칙에 있는 `match`, `radius`, `max_count`. 이 셋은 `count` 규칙에만 쓴다

`display` 안의 필드는 검사하지 않는다. core가 해석하지 않고 view에 넘기기 때문이다. 다만 `display`가 있으면 객체여야 한다.

오류는 `house.scoring[1].radius: 1 이상의 정수여야 한다 (받은 값: 0)`처럼 타일 id와 필드 경로로 적는다. id를 알 수 없거나 앞의 타일과 겹치면 `tiles[3].id`처럼 순서로 적는다. 첫 오류에서 멈추지 않고 모두 모은다.

### 5.2 `data/islands/island_01.json`

지도와 수치는 형식을 보여 주는 임시값이다. 지도는 세션 3에서 다시 그리고, 수치는 시뮬레이터로 조정한다.

```json
{
  "schema_version": 1,
  "id": "island_01",
  "name": "첫 섬",
  "rows": [
    "SSSSSSSS",
    "SSFLLSSS",
    "SFLLLLFS",
    "SLLLLLFS",
    "SLLLLLLS",
    "SFLLLLFS",
    "SSFFLLSS",
    "SSSSSSSS"
  ],
  "tide": { "initial": "LOW", "period_turns": 4 },
  "hand_size": 3,
  "start_deck": { "house": 5, "pier": 2, "market": 2, "salt_farm": 2, "drying_rack": 1, "lighthouse": 1 },
  "stages": [
    { "goal": 10, "bundle": { "house": 2, "pier": 1, "market": 1, "salt_farm": 2 } },
    { "goal": 24, "bundle": { "house": 2, "pier": 1, "market": 1, "drying_rack": 1, "salt_farm": 1 } },
    { "goal": 42, "bundle": { "house": 2, "pier": 1, "market": 1, "salt_farm": 2 } },
    { "goal": 64, "bundle": { "house": 2, "pier": 1, "market": 1, "drying_rack": 1, "salt_farm": 1 } },
    { "goal": 90, "bundle": { "house": 2, "pier": 1, "market": 1, "salt_farm": 2 } },
    { "goal": 120, "bundle": { "house": 2, "pier": 1, "market": 1, "drying_rack": 1, "salt_farm": 1 } }
  ],
  "after_last_stage": { "goal_step": 30, "bundle": { "house": 2, "pier": 1, "market": 1, "salt_farm": 2 } }
}
```

| 필드 | 뜻 |
| --- | --- |
| `rows` | 지도. 한 줄이 문자열 하나이고 `L`은 육지, `F`는 갯벌, `S`는 바다다. `rows[y][x]` |
| `tide.initial` | 시작 물때. `LOW` 또는 `HIGH` |
| `tide.period_turns` | 물때가 바뀌는 턴 간격 |
| `hand_size` | 손패 장수 |
| `start_deck` | 시작 덱 구성. 타일 id별 장수 |
| `stages[i].goal` | 단계 `i`의 목표 점수 |
| `stages[i].bundle` | 그 목표를 달성했을 때 받는 묶음 구성 |
| `after_last_stage.goal_step` | 마지막 단계 이후 목표가 오르는 폭 |
| `after_last_stage.bundle` | 마지막 단계 이후 받는 묶음 구성 |

**검증에서 오류로 잡는 것**

- `rows`의 줄 길이가 서로 다름, `L`, `F`, `S`가 아닌 글자, 빈 지도
- `period_turns`나 `hand_size`가 1보다 작음
- 덱이나 묶음에 `tiles.json`에 없는 id가 있음, 장수가 1보다 작음, 빈 묶음, 빈 시작 덱
- `stages`가 비어 있음, 목표가 앞 단계보다 크지 않음, `goal_step`이 1보다 작음

지도 가장자리는 바다로 두르는 것을 권한다. 보드 밖은 칸이 아니어서, 가장자리에 붙은 육지는 그쪽으로는 물과 인접하지 않는다.

물때 주기, 손패 장수, 덱, 목표를 섬 파일에 둔 것은 새 파일을 만들지 않기 위해서다. 섬이 여러 개가 되어 공통 수치가 생기면 그때 나눈다.

## 6. 규칙 엔진

타일의 배치 조건과 점수 규칙은 코드가 아니라 `tiles.json`에 적는다. core에는 타일 이름에 따라 갈라지는 코드를 두지 않는다.

**지형 판정**

배치 조건의 `terrain`, `adjacent_terrain`과 점수 규칙의 `match.terrain`은 모두 `Tide.effective_cell`을 거친 지형과 비교한다. 그래서 염전의 "썰물에만"은 `"terrain": ["FLAT"]`으로, 부두의 "밀물에는 갯벌도 바다"는 `"adjacent_terrain": ["SEA"]`로 표현된다. 물때에 따른 특수 처리는 없다.

**규칙 종류**

| 종류 | 계산 |
| --- | --- |
| `flat` | `points` |
| `count` | `BoardState.cells_within(pos, radius)`의 칸 가운데 `match`에 맞는 칸의 수를 세고, `max_count`가 있으면 그 값으로 자른 뒤 `points`를 곱한다 |

- `match.tiles`는 그 칸의 건물 id가 목록에 있는지를 본다.
- `match.terrain`은 그 칸의 물때를 반영한 지형이 목록에 있는지를 본다. 건물이 있어도 지형으로 센다.
- 타일 하나의 점수는 그 시점(`on`)에 해당하는 규칙들의 합이다.
- 물때 규칙의 지형 판정은 바뀐 뒤의 물때로 한다.

**새 타일 추가**

위 필드의 조합으로 표현되는 타일은 `tiles.json`에 항목을 추가하고 덱 구성에 넣으면 된다. 코드는 고치지 않는다. 새로운 종류의 조건이나 규칙(예: 지급 횟수 상한, 줄이나 무리의 크기)이 필요하면 `Placement`나 `Scoring`에 종류를 하나 추가하고 이 문서의 표와 검증을 함께 고친다.

## 7. 무작위와 재현

- `GameState.create`가 `RandomNumberGenerator`를 하나 만들어 `rng_seed`를 넣고 `Deck`에 넘긴다. core는 이 생성기 말고는 무작위를 쓰지 않는다. 전역 `randi()`, `randf()`, `randomize()`, `Array.shuffle()`, `pick_random()`을 쓰지 않는다.
- 같은 seed, 같은 데이터, 같은 행동 순서면 같은 판이 된다. 판은 seed와 행동 목록만으로 다시 만들 수 있다.
- 시뮬레이터의 봇이 무작위를 쓸 때는 게임의 생성기를 쓰지 않고 봇용 생성기를 따로 둔다. 봇이 바뀌어도 같은 seed의 덱 순서가 유지된다.
- 재현을 깨뜨리는 것: Dictionary 순회 순서에 기대는 코드, 시간이나 프레임에 기대는 코드.

## 8. view와 시뮬레이터가 core를 쓰는 방법

**view**

- 판을 만들 때 `TileDefs.load_file`, `GameState.load_island`, `GameState.create`를 차례로 부른다.
- 입력은 `GameState.place`와 `GameState.discard`로만 전달한다. 놓을 수 있는지와 예상 점수는 `can_place`, `why_not`, `legal_cells`, `preview_score`에 묻는다. view는 규칙을 스스로 판단하지 않는다.
- 화면 갱신은 signal을 받아서 한다. 지형과 건물은 `get_board()`로 읽고, 타일의 이름과 색은 `TileDefs`의 `display`에서 읽는다.
- 밀물 때 갯벌을 다른 색으로 그릴 때도 `Tide.effective_cell`을 쓴다.

**signal 순서**

| 행동 | 보내는 순서 |
| --- | --- |
| 배치 | `tile_placed`, (물때가 바뀌면) `tide_changed`, (달성한 단계마다) `goal_reached`, `score_changed`, 그리고 `hand_changed` 또는 `game_over` |
| 버리기 | `tile_discarded`, 그리고 `hand_changed` 또는 `game_over` |

**시뮬레이터**

- 봇은 `get_hand`, `legal_cells`, `preview_score`로 선택지를 보고 `place`나 `discard`를 부른다.
- 놓을 수 있는 타일이 손패에 없으면 봇은 버려야 한다. 그러지 않으면 판이 진행되지 않는다.
- 판별 결과는 `get_score`, `get_stage`, `get_turn`, `get_stats`에서 얻는다.
- 그 턴 점수만 보는 봇은 놓는 순간 0점인 부두와 염전을 뒤로 미룬다. 사람은 이 타일을 일찍 놓으므로, 밸런스를 볼 때는 수입 타일을 먼저 놓는 봇을 함께 두는 것이 좋다.

## 9. 테스트

단위 테스트는 `tests/unit/`에 두고 GUT로 실행한다.

| 파일 | 확인하는 것 |
| --- | --- |
| `test_board_state.gd` | 지도 읽기, 범위, `cells_within`의 칸 수와 순서, 건물 놓기 |
| `test_tile_defs.gd` | 정상 정의 읽기, 검증 오류 각각 |
| `test_placement.gd` | 타일별 가능과 불가, 물때에 따라 달라지는 경우, 이유 코드의 순서 |
| `test_scoring.gd` | 규칙 종류별 계산, `docs/rules.md` 8장의 예시 |
| `test_tide.gd` | 주기마다 전환, signal, `effective_cell` |
| `test_deck.gd` | 같은 seed면 같은 순서, 뽑기와 덱 아래로 넣기의 순서 |
| `test_game_state.gd` | 배치와 버리기의 흐름, 목표와 묶음, 종료 조건, signal 순서 |
| `test_data.gd` | 실제 `data/` 파일이 검증을 통과하는지 |

점수와 배치 테스트는 두 층으로 나눈다.

1. **규칙 엔진 테스트.** 테스트 안에서 만든 정의를 `TileDefs.from_dict`에 넣어 `flat`, `count`, 배치 조건의 동작을 확인한다. `data/tiles.json`의 수치를 조정해도 깨지지 않는다.
2. **v1 데이터 테스트.** 실제 `data/tiles.json`을 읽어 `docs/rules.md` 8장의 예시 값을 확인한다. 수치를 조정하면 이 테스트의 기대값과 문서의 예시를 함께 고친다.

끝까지 돌려 보는 테스트도 둔다. core만으로 무작위 행동을 반복해 판이 오류 없이 끝나는지, 같은 seed와 같은 행동이면 같은 결과가 나오는지 확인한다. 판이 반드시 끝난다는 성질(`docs/rules.md` 6.4)이 있으므로 이 테스트에 행동 횟수 상한을 걸어 두고, 상한에 닿으면 실패로 본다.

## 10. 구현할 때 주의할 점

- json에서 읽은 숫자는 정수도 float로 온다(11장). 정수인지 확인하고 `int`로 바꿔 담는다.
- json에서 읽은 배열은 타입 없는 `Array`다. `Array[StringName]` 같은 typed array 매개변수에 바로 넘기지 말고 새 배열에 옮겨 담는다.
- json의 문자열 id는 읽을 때 `StringName`으로 바꾸고, core 안에서는 `StringName`만 쓴다.
- core에서는 Node, SceneTree, Input, 씬 파일을 쓰지 않는다. 파일 읽기(`FileAccess`)와 `JSON`은 써도 된다.
- 한 함수가 40줄을 넘으면 나눈다. 데이터 검증은 필드 종류별 작은 함수로 나누면 넘지 않는다.

## 11. Godot 4.7에서 확인한 것

이 설계는 Godot를 실행할 수 없는 환경에서 작성했다. 프로젝트 골격을 만들 때(2026-11-18) Godot 4.7.stable로 아래를 확인했다. 3장의 선언은 모두 그대로 파싱되어 표기를 바꾼 것이 없다.

| 확인한 것 | 결과 |
| --- | --- |
| 3장의 선언 전체 | `--check-only`와 `--import`에서 오류 없이 파싱되고, 7개 `class_name`이 모두 등록된다 |
| 다른 클래스의 enum을 원소로 하는 typed array (`Array[BoardState.Cell]`) | 된다. 실행 중에는 원소 타입이 `int`인 typed array다 |
| `Dictionary[Vector2i, int]` 반환 타입 | 된다. `return {}`도 키가 `Vector2i`, 값이 `int`인 typed dictionary가 된다 |
| 다른 클래스의 enum을 타입으로 적은 signal 매개변수 (`new_phase: Tide.Phase`) | 된다. 매개변수 정보에는 타입 `int`, 클래스 이름 `Tide.Phase`로 나온다 |
| `JSON` 파싱 결과의 정수 | 정수도 모두 `float`로 온다(`1` → `1.0`). 배열은 타입 없는 `Array`로 온다 |
