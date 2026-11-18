class_name Placement
extends RefCounted
## 배치 가능 여부를 판정한다. 상태가 없고 모두 static 함수다.
##
## check는 OUT_OF_BOUNDS, OCCUPIED, LIMIT_REACHED, WRONG_TERRAIN, NO_ADJACENT_TERRAIN 순서로
## 검사해 처음 걸린 이유를 돌려준다.

enum Reason { ALLOWED, OUT_OF_BOUNDS, OCCUPIED, LIMIT_REACHED, WRONG_TERRAIN, NO_ADJACENT_TERRAIN }


## pos에 tile_id를 놓을 수 있는지 정해진 순서로 검사해 처음 걸린 이유를 돌려준다. 놓을 수 있으면 ALLOWED.
static func check(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> Reason:
	# TODO: 구현
	return Reason.ALLOWED


## pos에 tile_id를 놓을 수 있는지 돌려준다.
static func can_place(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> bool:
	# TODO: 구현
	return false


## tile_id를 놓을 수 있는 칸을 모두 돌려준다.
static func legal_cells(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName) -> Array[Vector2i]:
	# TODO: 구현
	return []


## tile_id를 놓을 수 있는 칸이 하나라도 있는지 돌려준다.
static func has_legal_cell(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName) -> bool:
	# TODO: 구현
	return false
