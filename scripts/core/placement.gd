class_name Placement
extends RefCounted
## 배치 가능 여부를 판정한다. 상태가 없고 모두 static 함수다.
##
## check는 OUT_OF_BOUNDS, OCCUPIED, LIMIT_REACHED, WRONG_TERRAIN, NO_ADJACENT_TERRAIN 순서로
## 검사해 처음 걸린 이유를 돌려준다. 지형은 모두 Tide.effective_cell을 거쳐 본다.

enum Reason { ALLOWED, OUT_OF_BOUNDS, OCCUPIED, LIMIT_REACHED, WRONG_TERRAIN, NO_ADJACENT_TERRAIN }


## pos에 tile_id를 놓을 수 있는지 정해진 순서로 검사해 처음 걸린 이유를 돌려준다. 놓을 수 있으면 ALLOWED.
static func check(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> Reason:
	return _check_def(board, _find_def(defs, tile_id), phase, pos)


## pos에 tile_id를 놓을 수 있는지 돌려준다.
static func can_place(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> bool:
	return check(board, defs, phase, tile_id, pos) == Reason.ALLOWED


## tile_id를 놓을 수 있는 칸을 BoardState.all_cells 순서(위에서 아래, 왼쪽에서 오른쪽)로 돌려준다.
static func legal_cells(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var def := _find_def(defs, tile_id)
	if def == null:
		return result
	for pos: Vector2i in board.all_cells():
		if _check_def(board, def, phase, pos) == Reason.ALLOWED:
			result.append(pos)
	return result


## tile_id를 놓을 수 있는 칸이 하나라도 있는지 돌려준다.
static func has_legal_cell(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName) -> bool:
	var def := _find_def(defs, tile_id)
	if def == null:
		return false
	for pos: Vector2i in board.all_cells():
		if _check_def(board, def, phase, pos) == Reason.ALLOWED:
			return true
	return false


## 정의를 찾는다. 없으면 push_error로 알리고 null(놓을 수 있는 지형이 없는 타일로 본다).
static func _find_def(defs: TileDefs, tile_id: StringName) -> TileDefs.TileDef:
	var def := defs.get_def(tile_id)
	if def == null:
		push_error("Placement: 정의에 없는 타일 id다 (%s)" % tile_id)
	return def


static func _check_def(board: BoardState, def: TileDefs.TileDef, phase: Tide.Phase, pos: Vector2i) -> Reason:
	if not board.in_bounds(pos):
		return Reason.OUT_OF_BOUNDS
	if board.has_building(pos):
		return Reason.OCCUPIED
	if def == null:
		return Reason.WRONG_TERRAIN
	if def.max_on_board > 0 and board.count_of(def.id) >= def.max_on_board:
		return Reason.LIMIT_REACHED
	if not def.terrain.has(Tide.effective_cell(board.get_cell(pos), phase)):
		return Reason.WRONG_TERRAIN
	if not def.adjacent_terrain.is_empty() and not _touches(board, phase, pos, def.adjacent_terrain):
		return Reason.NO_ADJACENT_TERRAIN
	return Reason.ALLOWED


## pos의 인접 칸(상하좌우, 보드 안) 가운데 물때를 반영한 지형이 terrains에 있는 칸이 있는지
static func _touches(board: BoardState, phase: Tide.Phase, pos: Vector2i, terrains: Array[BoardState.Cell]) -> bool:
	for neighbor: Vector2i in board.cells_within(pos, 1):
		if terrains.has(Tide.effective_cell(board.get_cell(neighbor), phase)):
			return true
	return false
