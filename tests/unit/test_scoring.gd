extends GutTest
## Scoring: 배치 점수와 물때 점수 (docs/architecture.md 3.5, 6장, docs/rules.md 4.2, 4.3, 5장)
##
## 앞부분은 테스트 안에서 만든 규칙과 타일로 규칙 엔진을 보고(수치를 바꿔도 깨지지 않는다),
## 뒷부분은 실제 data/tiles.json으로 docs/rules.md 8장의 예시 값을 본다.

const LOW := Tide.Phase.LOW
const HIGH := Tide.Phase.HIGH
const LAND := BoardState.Cell.LAND
const FLAT := BoardState.Cell.FLAT
const SEA := BoardState.Cell.SEA


# --- 규칙 종류별 점수 (rule_points) ---

func test_flat_rule_gives_its_points() -> void:
	assert_eq(Scoring.rule_points(_board(["LL"]), LOW, _flat(3), Vector2i(0, 0)), 3)


func test_count_rule_counts_matching_tiles_times_points() -> void:
	var board := _three_by_three_with_neighbors()
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut"], 1, 2), Vector2i(1, 1)), 4)
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut", &"shed"], 1, 2), Vector2i(1, 1)), 6)
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut"], 1, -1), Vector2i(1, 1)), -2)


func test_max_count_caps_the_count() -> void:
	var board := _three_by_three_with_neighbors()
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut"], 1, 2, 1), Vector2i(1, 1)), 2)
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut"], 1, 2, 0), Vector2i(1, 1)), 4)


func test_count_rule_uses_radius() -> void:
	var board := _board(["LLLLL"])
	board.place_building(Vector2i(2, 0), &"hut")
	board.place_building(Vector2i(3, 0), &"hut")
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut"], 1, 1), Vector2i(0, 0)), 0)
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut"], 2, 1), Vector2i(0, 0)), 1)
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut"], 3, 1), Vector2i(0, 0)), 2)


func test_own_cell_is_not_counted() -> void:
	# docs/rules.md 5장: 자기 칸은 세지 않는다
	var board := _board(["LL"])
	board.place_building(Vector2i(0, 0), &"hut")
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([&"hut"], 1, 1), Vector2i(0, 0)), 0)


func test_terrain_count_follows_tide() -> void:
	var board := _board(["SLF"])
	assert_eq(Scoring.rule_points(board, LOW, _count_terrain([SEA], 1, 1), Vector2i(1, 0)), 1)
	assert_eq(Scoring.rule_points(board, HIGH, _count_terrain([SEA], 1, 1), Vector2i(1, 0)), 2)
	assert_eq(Scoring.rule_points(board, HIGH, _count_terrain([FLAT], 1, 1), Vector2i(1, 0)), 0)


func test_terrain_count_ignores_buildings() -> void:
	# docs/architecture.md 6장: 건물이 있어도 지형으로 센다
	var board := _board(["SLF"])
	board.place_building(Vector2i(0, 0), &"raft")
	board.place_building(Vector2i(2, 0), &"pond")
	assert_eq(Scoring.rule_points(board, HIGH, _count_terrain([SEA], 1, 1), Vector2i(1, 0)), 2)


func test_count_rule_with_empty_match_counts_nothing() -> void:
	var board := _three_by_three_with_neighbors()
	assert_eq(Scoring.rule_points(board, LOW, _count_tiles([], 1, 5), Vector2i(1, 1)), 0)


func test_unknown_rule_kind_reports_error() -> void:
	# docs/architecture.md 3.5: 모르는 kind면 push_error를 내고 0점
	var rule := _flat(3)
	rule.kind = &"sum"
	assert_eq(Scoring.rule_points(_board(["L"]), LOW, rule, Vector2i(0, 0)), 0)
	assert_push_error("모르는 규칙 종류")


# --- placement_score, tide_scores ---

func test_placement_score_sums_place_rules_only() -> void:
	# mixed: place 규칙 1점 + 인접 hut 1개 × 2점 = 3. tide_low 규칙(5점)은 넣지 않는다
	var board := _board(["LLL"])
	board.place_building(Vector2i(0, 0), &"hut")
	assert_eq(Scoring.placement_score(board, _engine_defs(), LOW, &"mixed", Vector2i(1, 0)), 3)
	assert_false(board.has_building(Vector2i(1, 0)), "점수 계산은 보드를 바꾸지 않는다")


func test_placement_score_without_place_rules_is_0() -> void:
	var board := _board(["LF"])
	var defs := _engine_defs()
	assert_eq(Scoring.placement_score(board, defs, LOW, &"lowfarm", Vector2i(1, 0)), 0)
	assert_eq(Scoring.placement_score(board, defs, LOW, &"castle", Vector2i(0, 0)), 0)


func test_tide_scores_cover_buildings_with_rules_for_the_new_phase() -> void:
	var board := _board(["LLLL", "FFFF"])
	board.place_building(Vector2i(0, 0), &"tidal")
	board.place_building(Vector2i(2, 0), &"tidal")
	board.place_building(Vector2i(3, 0), &"hut")
	board.place_building(Vector2i(1, 1), &"lowfarm")
	var defs := _engine_defs()
	var at_high: Dictionary[Vector2i, int] = {Vector2i(0, 0): 3, Vector2i(2, 0): 3}
	var at_low: Dictionary[Vector2i, int] = {Vector2i(1, 1): 2}
	assert_eq(Scoring.tide_scores(board, defs, HIGH), at_high)
	assert_eq(Scoring.tide_scores(board, defs, LOW), at_low)


func test_tide_scores_include_zero_point_buildings() -> void:
	# docs/architecture.md 3.5: 0점인 건물도 넣는다. (1,0)은 3점에서 인접 tidal 3개를 빼 0점
	var board := _board(["LLL", "LLL"])
	for pos: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]:
		board.place_building(pos, &"tidal")
	var scores := Scoring.tide_scores(board, _engine_defs(), HIGH)
	assert_eq(scores.size(), 4)
	assert_eq(scores.get(Vector2i(1, 0)), 0)


func test_tide_scores_see_terrain_with_the_new_phase() -> void:
	# docs/rules.md 5장: 지형을 보는 물때 규칙은 바뀐 뒤의 물때로 센다
	var board := _board(["LF"])
	board.place_building(Vector2i(0, 0), &"shore")
	var expected: Dictionary[Vector2i, int] = {Vector2i(0, 0): 1}
	assert_eq(Scoring.tide_scores(board, _engine_defs(), HIGH), expected)


# --- v1 데이터: data/tiles.json으로 docs/rules.md 8장의 예시 값을 확인한다 ---

func test_rules_example_1_house_and_market() -> void:
	var defs := _v1_defs()
	var board := _board(["LLLL"])
	var got: Array[int] = []
	got.append(_place(board, defs, &"house", Vector2i(0, 0)))
	got.append(_place(board, defs, &"house", Vector2i(1, 0)))
	got.append(_place(board, defs, &"market", Vector2i(3, 0)))
	got.append(_place(board, defs, &"house", Vector2i(2, 0)))
	var expected: Array[int] = [0, 1, 0, 3]
	assert_eq(got, expected)


func test_rules_example_1_market_last_gives_same_total() -> void:
	var defs := _v1_defs()
	var board := _board(["LLLL"])
	var got: Array[int] = []
	got.append(_place(board, defs, &"house", Vector2i(0, 0)))
	got.append(_place(board, defs, &"house", Vector2i(1, 0)))
	got.append(_place(board, defs, &"house", Vector2i(2, 0)))
	got.append(_place(board, defs, &"market", Vector2i(3, 0)))
	var expected: Array[int] = [0, 1, 1, 2]
	assert_eq(got, expected)


func test_rules_example_2_market_bonus_counts_once() -> void:
	var board := _board(["LLL", "LLL", "LLL"])
	board.place_building(Vector2i(1, 0), &"market")
	board.place_building(Vector2i(0, 1), &"market")
	assert_eq(Scoring.placement_score(board, _v1_defs(), LOW, &"house", Vector2i(1, 1)), 2)


func test_rules_example_3_water_cells_depend_on_tide() -> void:
	var board := _board(["SLF"])
	var defs := _v1_defs()
	assert_eq(Scoring.placement_score(board, defs, LOW, &"house", Vector2i(1, 0)), 1)
	assert_eq(Scoring.placement_score(board, defs, HIGH, &"house", Vector2i(1, 0)), 2)
	board.place_building(Vector2i(2, 0), &"salt_farm")
	assert_eq(Scoring.placement_score(board, defs, HIGH, &"house", Vector2i(1, 0)), 2)


func test_rules_example_5_pier_tide_scores() -> void:
	var defs := _v1_defs()
	var together := _board(["SSSSS", "LLLLL"])
	for x: int in [0, 1, 2]:
		together.place_building(Vector2i(x, 1), &"pier")
	var expected_together: Dictionary[Vector2i, int] = {Vector2i(0, 1): 2, Vector2i(1, 1): 1, Vector2i(2, 1): 2}
	assert_eq(Scoring.tide_scores(together, defs, HIGH), expected_together)
	var apart := _board(["SSSSS", "LLLLL"])
	for x: int in [0, 2, 4]:
		apart.place_building(Vector2i(x, 1), &"pier")
	var expected_apart: Dictionary[Vector2i, int] = {Vector2i(0, 1): 3, Vector2i(2, 1): 3, Vector2i(4, 1): 3}
	assert_eq(Scoring.tide_scores(apart, defs, HIGH), expected_apart)


func test_rules_example_5_market_and_drying_rack_next_to_piers() -> void:
	var defs := _v1_defs()
	var board := _board(["SSSSS", "LLLLL"])
	for x: int in [0, 2, 4]:
		board.place_building(Vector2i(x, 1), &"pier")
	assert_eq(_place(board, defs, &"market", Vector2i(1, 1)), 4)
	assert_eq(_place(board, defs, &"drying_rack", Vector2i(3, 1)), 4)


func test_rules_example_6_lighthouse_radius_2() -> void:
	var board := _board(["SSSSS", "LLLLL", "LLLLL"])
	for x: int in 5:
		board.place_building(Vector2i(x, 1), &"pier")
	assert_eq(Scoring.placement_score(board, _v1_defs(), LOW, &"lighthouse", Vector2i(2, 2)), 9)


func test_rules_example_7_penalty_in_either_order() -> void:
	var defs := _v1_defs()
	var rack_first := _board(["LLL"])
	_place(rack_first, defs, &"drying_rack", Vector2i(1, 0))
	assert_eq(_place(rack_first, defs, &"house", Vector2i(0, 0)), -1)
	var house_first := _board(["LLL"])
	_place(house_first, defs, &"house", Vector2i(0, 0))
	assert_eq(_place(house_first, defs, &"drying_rack", Vector2i(1, 0)), -1)


func test_rules_example_8_who_scores_at_each_switch() -> void:
	# docs/rules.md 4.3, 8장 예시 8: 밀물로 바뀌면 부두가, 썰물로 바뀌면 염전이 점수를 받는다
	var board := _board(["SLF"])
	board.place_building(Vector2i(1, 0), &"pier")
	board.place_building(Vector2i(2, 0), &"salt_farm")
	var defs := _v1_defs()
	var at_high: Dictionary[Vector2i, int] = {Vector2i(1, 0): 3}
	var at_low: Dictionary[Vector2i, int] = {Vector2i(2, 0): 2}
	assert_eq(Scoring.tide_scores(board, defs, HIGH), at_high)
	assert_eq(Scoring.tide_scores(board, defs, LOW), at_low)


func test_pier_with_three_neighbor_piers_scores_0() -> void:
	# docs/rules.md 4.3: 부두 하나가 한 번에 받는 점수는 0–3점이다. 가운데 부두는 3 - 3 = 0
	var board := _board(["SSS", "LLL", "SLS"])
	for pos: Vector2i in [Vector2i(1, 1), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		board.place_building(pos, &"pier")
	var scores := Scoring.tide_scores(board, _v1_defs(), HIGH)
	assert_eq(scores.size(), 4)
	assert_eq(scores.get(Vector2i(1, 1)), 0)


# --- 도우미 ---

func _board(rows: Array[String]) -> BoardState:
	return BoardState.from_island({"rows": rows})


## GameState처럼 놓기 전의 보드로 배치 점수를 구한 뒤 놓는다
func _place(board: BoardState, defs: TileDefs, tile_id: StringName, pos: Vector2i, phase: Tide.Phase = LOW) -> int:
	var points := Scoring.placement_score(board, defs, phase, tile_id, pos)
	board.place_building(pos, tile_id)
	return points


## 가운데 (1,1)의 인접 칸에 hut 2개와 shed 1개가 있는 3×3 육지
func _three_by_three_with_neighbors() -> BoardState:
	var board := _board(["LLL", "LLL", "LLL"])
	board.place_building(Vector2i(1, 0), &"hut")
	board.place_building(Vector2i(0, 1), &"hut")
	board.place_building(Vector2i(2, 1), &"shed")
	return board


func _flat(points: int) -> TileDefs.ScoreRule:
	var rule := TileDefs.ScoreRule.new()
	rule.on = &"place"
	rule.kind = &"flat"
	rule.points = points
	return rule


func _count_tiles(tiles: Array[StringName], radius: int, points: int, max_count: int = 0) -> TileDefs.ScoreRule:
	var rule := TileDefs.ScoreRule.new()
	rule.on = &"place"
	rule.kind = &"count"
	rule.match_tiles = tiles
	rule.radius = radius
	rule.points = points
	rule.max_count = max_count
	return rule


func _count_terrain(terrain: Array[BoardState.Cell], radius: int, points: int) -> TileDefs.ScoreRule:
	var rule := TileDefs.ScoreRule.new()
	rule.on = &"place"
	rule.kind = &"count"
	rule.match_terrain = terrain
	rule.radius = radius
	rule.points = points
	return rule


## 규칙 엔진 테스트용 타일. tidal은 부두처럼, lowfarm은 염전처럼, shore는 물때 때 바다를 세는 타일
func _engine_defs() -> TileDefs:
	var defs := TileDefs.from_dict({"schema_version": 1, "tiles": [
		{"id": "hut", "placement": {"terrain": ["LAND"]}, "scoring": []},
		{"id": "mixed", "placement": {"terrain": ["LAND"]}, "scoring": [
			{"on": "place", "type": "flat", "points": 1},
			{"on": "place", "type": "count", "match": {"tiles": ["hut"]}, "radius": 1, "points": 2},
			{"on": "tide_low", "type": "flat", "points": 5},
		]},
		{"id": "tidal", "placement": {"terrain": ["LAND"]}, "scoring": [
			{"on": "tide_high", "type": "flat", "points": 3},
			{"on": "tide_high", "type": "count", "match": {"tiles": ["tidal"]}, "radius": 1, "points": -1},
		]},
		{"id": "lowfarm", "placement": {"terrain": ["FLAT"]}, "scoring": [
			{"on": "tide_low", "type": "flat", "points": 2},
		]},
		{"id": "shore", "placement": {"terrain": ["LAND"]}, "scoring": [
			{"on": "tide_high", "type": "count", "match": {"terrain": ["SEA"]}, "radius": 1, "points": 1},
		]},
	]})
	assert_eq(defs.errors(), PackedStringArray(), "테스트용 타일 정의가 틀렸다")
	return defs


func _v1_defs() -> TileDefs:
	var defs := TileDefs.load_file("res://data/tiles.json")
	assert_eq(defs.errors(), PackedStringArray(), "data/tiles.json이 검증을 통과하지 못했다")
	return defs
