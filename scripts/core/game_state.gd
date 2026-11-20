class_name GameState
extends RefCounted
## 한 판의 진행을 맡는다. view와 시뮬레이터가 부르는 유일한 입구다.
##
## 행동 처리 순서는 docs/architecture.md 4장, signal 순서는 8장을 따른다.

signal tile_placed(pos: Vector2i, tile_id: StringName, points: int)
signal tile_discarded(tile_id: StringName)
signal tide_changed(new_phase: Tide.Phase, points_by_cell: Dictionary)
signal goal_reached(stage: int, new_goal: int)
signal score_changed(score: int, goal: int)
signal hand_changed(hand: Array[StringName])
signal game_over(final_score: int, stage: int)


## 섬 json을 읽는다. 실패하면 빈 Dictionary를 돌려준다.
static func load_island(path: String) -> Dictionary:
	# TODO: 구현
	return {}


## 섬 데이터의 검증 오류를 돌려준다. 비어 있어야 정상이다.
static func validate_island(island: Dictionary, defs: TileDefs) -> PackedStringArray:
	# TODO: 구현
	return PackedStringArray()


## 새 판을 만든다. 타일 정의나 섬 데이터에 오류가 있으면 null을 돌려준다.
static func create(defs: TileDefs, island: Dictionary, rng_seed: int) -> GameState:
	# TODO: 구현
	return null


## 지금 손패를 돌려준다.
func get_hand() -> Array[StringName]:
	# TODO: 구현
	return []


## 손패 hand_index번 타일을 pos에 놓을 수 있는지 돌려준다.
func can_place(hand_index: int, pos: Vector2i) -> bool:
	# TODO: 구현
	return false


## 손패 hand_index번 타일을 pos에 놓을 수 없는 이유를 돌려준다. 놓을 수 있으면 ALLOWED.
func why_not(hand_index: int, pos: Vector2i) -> Placement.Reason:
	# TODO: 구현
	return Placement.Reason.ALLOWED


## 손패 hand_index번 타일을 놓을 수 있는 칸을 돌려준다.
func legal_cells(hand_index: int) -> Array[Vector2i]:
	# TODO: 구현
	return []


## 손패 hand_index번 타일을 pos에 놓을 때의 배치 점수를 돌려준다. 물때 점수는 넣지 않는다.
func preview_score(hand_index: int, pos: Vector2i) -> int:
	# TODO: 구현
	return 0


## 손패 hand_index번 타일을 pos에 놓는다. 실패하면 false이고 아무것도 바뀌지 않는다.
func place(hand_index: int, pos: Vector2i) -> bool:
	# TODO: 구현
	return false


## 손패 hand_index번 타일을 버린다. 턴과 물때는 그대로다.
func discard(hand_index: int) -> bool:
	# TODO: 구현
	return false


## 판이 끝났는지 돌려준다.
func is_over() -> bool:
	# TODO: 구현
	return false


## 누적 점수를 돌려준다.
func get_score() -> int:
	# TODO: 구현
	return 0


## 지금 목표 점수를 돌려준다.
func get_goal() -> int:
	# TODO: 구현
	return 0


## 지금 단계(달성한 목표의 수)를 돌려준다.
func get_stage() -> int:
	# TODO: 구현
	return 0


## 끝난 턴 수(배치한 횟수)를 돌려준다.
func get_turn() -> int:
	# TODO: 구현
	return 0


## 이 판의 seed를 돌려준다.
func get_seed() -> int:
	# TODO: 구현
	return 0


## 덱에 남은 장수를 돌려준다.
func get_deck_size() -> int:
	# TODO: 구현
	return 0


## 보드를 돌려준다. 읽기만 한다.
func get_board() -> BoardState:
	# TODO: 구현
	return null


## 물때 시계를 돌려준다. 읽기만 한다.
func get_tide() -> Tide:
	# TODO: 구현
	return null


## 타일 정의를 돌려준다.
func get_defs() -> TileDefs:
	# TODO: 구현
	return null


## 시뮬레이터용 통계를 돌려준다. 키는 placed, discarded, placement_points, tide_points, leftover다.
func get_stats() -> Dictionary:
	# TODO: 구현
	return {}
