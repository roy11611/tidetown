class_name Scoring
extends RefCounted
## 점수를 계산한다. 상태가 없고 보드를 바꾸지 않는다.
##
## 배치 가능 여부는 보지 않는다(판정은 Placement). 지형은 모두 Tide.effective_cell을 거쳐 본다.
## 타일 하나의 점수는 그 시점(on)에 해당하는 규칙들의 합이다(docs/architecture.md 6장).


## tile_id를 pos에 놓을 때의 배치 점수를 놓기 전의 보드로 계산한다. 화면의 예상 점수도 이 함수를 쓴다.
static func placement_score(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> int:
	return _sum(board, phase, defs.rules_for(tile_id, &"place"), pos)


## 바뀐 뒤의 물때를 받아, 그 이벤트의 규칙이 있는 건물마다 점수를 돌려준다. 0점인 건물도 넣는다.
static func tide_scores(board: BoardState, defs: TileDefs, new_phase: Tide.Phase) -> Dictionary[Vector2i, int]:
	var scores: Dictionary[Vector2i, int] = {}
	var event := _tide_event(new_phase)
	for pos: Vector2i in board.all_cells():
		if not board.has_building(pos):
			continue
		var rules := defs.rules_for(board.get_building(pos), event)
		if not rules.is_empty():
			scores[pos] = _sum(board, new_phase, rules, pos)
	return scores


## 점수 규칙 하나가 pos에서 주는 점수를 돌려준다. 모르는 kind면 push_error를 내고 0점.
static func rule_points(board: BoardState, phase: Tide.Phase, rule: TileDefs.ScoreRule, pos: Vector2i) -> int:
	if rule.kind == &"flat":
		return rule.points
	if rule.kind == &"count":
		return _matching_count(board, phase, rule, pos) * rule.points
	push_error("Scoring: 모르는 규칙 종류다 (%s)" % rule.kind)
	return 0


static func _sum(board: BoardState, phase: Tide.Phase, rules: Array[TileDefs.ScoreRule], pos: Vector2i) -> int:
	var total := 0
	for rule: TileDefs.ScoreRule in rules:
		total += rule_points(board, phase, rule, pos)
	return total


## radius 안에서 match에 맞는 칸의 수. max_count가 있으면 그 값으로 자른다.
static func _matching_count(board: BoardState, phase: Tide.Phase, rule: TileDefs.ScoreRule, pos: Vector2i) -> int:
	var count := 0
	for cell: Vector2i in board.cells_within(pos, rule.radius):
		if _matches(board, phase, rule, cell):
			count += 1
	if rule.max_count > 0:
		count = mini(count, rule.max_count)
	return count


## match.tiles는 그 칸의 건물 id를, match.terrain은 물때를 반영한 지형을 본다. 건물이 있어도 지형으로 센다.
static func _matches(board: BoardState, phase: Tide.Phase, rule: TileDefs.ScoreRule, cell: Vector2i) -> bool:
	if not rule.match_tiles.is_empty():
		return rule.match_tiles.has(board.get_building(cell))
	return rule.match_terrain.has(Tide.effective_cell(board.get_cell(cell), phase))


static func _tide_event(new_phase: Tide.Phase) -> StringName:
	return &"tide_high" if new_phase == Tide.Phase.HIGH else &"tide_low"
