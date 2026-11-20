extends GutTest
## Placement: 배치 가능 여부와 불가 이유 (docs/architecture.md 3.4, docs/rules.md 4.1)
##
## 앞부분은 테스트 안에서 만든 타일로 규칙 엔진을 보고(수치를 바꿔도 깨지지 않는다),
## 뒷부분은 실제 data/tiles.json으로 docs/rules.md의 표와 예시를 본다.

const LOW := Tide.Phase.LOW
const HIGH := Tide.Phase.HIGH
const ALLOWED := Placement.Reason.ALLOWED
const OUT_OF_BOUNDS := Placement.Reason.OUT_OF_BOUNDS
const OCCUPIED := Placement.Reason.OCCUPIED
const LIMIT_REACHED := Placement.Reason.LIMIT_REACHED
const WRONG_TERRAIN := Placement.Reason.WRONG_TERRAIN
const NO_ADJACENT_TERRAIN := Placement.Reason.NO_ADJACENT_TERRAIN


# --- 이유 5가지 ---

func test_allowed_on_matching_terrain() -> void:
	assert_eq(Placement.check(_board(["LF"]), _engine_defs(), LOW, &"hut", Vector2i(0, 0)), ALLOWED)


func test_out_of_bounds() -> void:
	var board := _board(["LL"])
	var defs := _engine_defs()
	assert_eq(Placement.check(board, defs, LOW, &"hut", Vector2i(-1, 0)), OUT_OF_BOUNDS)
	assert_eq(Placement.check(board, defs, LOW, &"hut", Vector2i(2, 0)), OUT_OF_BOUNDS)


func test_occupied() -> void:
	var board := _board(["LL"])
	board.place_building(Vector2i(0, 0), &"hut")
	assert_eq(Placement.check(board, _engine_defs(), LOW, &"hut", Vector2i(0, 0)), OCCUPIED)


func test_limit_reached_only_for_tile_with_max_on_board() -> void:
	var board := _board(["LLL"])
	var defs := _engine_defs()
	board.place_building(Vector2i(0, 0), &"tower")
	board.place_building(Vector2i(1, 0), &"hut")
	assert_eq(Placement.check(board, defs, LOW, &"tower", Vector2i(2, 0)), LIMIT_REACHED)
	assert_eq(Placement.check(board, defs, LOW, &"hut", Vector2i(2, 0)), ALLOWED)


func test_wrong_terrain() -> void:
	var board := _board(["LFS"])
	var defs := _engine_defs()
	assert_eq(Placement.check(board, defs, LOW, &"hut", Vector2i(1, 0)), WRONG_TERRAIN)
	assert_eq(Placement.check(board, defs, LOW, &"hut", Vector2i(2, 0)), WRONG_TERRAIN)


func test_no_adjacent_terrain() -> void:
	var board := _board(["LLS"])
	var defs := _engine_defs()
	assert_eq(Placement.check(board, defs, LOW, &"dock", Vector2i(1, 0)), ALLOWED)
	assert_eq(Placement.check(board, defs, LOW, &"dock", Vector2i(0, 0)), NO_ADJACENT_TERRAIN)


# --- 지형은 물때를 반영해서 본다 (docs/architecture.md 6장) ---

func test_terrain_follows_tide() -> void:
	var board := _board(["F"])
	var defs := _engine_defs()
	assert_eq(Placement.check(board, defs, LOW, &"pond", Vector2i(0, 0)), ALLOWED)
	assert_eq(Placement.check(board, defs, HIGH, &"pond", Vector2i(0, 0)), WRONG_TERRAIN)
	assert_eq(Placement.check(board, defs, LOW, &"raft", Vector2i(0, 0)), WRONG_TERRAIN)
	assert_eq(Placement.check(board, defs, HIGH, &"raft", Vector2i(0, 0)), ALLOWED)


func test_adjacent_terrain_follows_tide() -> void:
	var board := _board(["LF"])
	var defs := _engine_defs()
	assert_eq(Placement.check(board, defs, LOW, &"dock", Vector2i(0, 0)), NO_ADJACENT_TERRAIN)
	assert_eq(Placement.check(board, defs, HIGH, &"dock", Vector2i(0, 0)), ALLOWED)


func test_building_does_not_change_neighbor_terrain() -> void:
	# docs/rules.md 3장: 염전이 놓인 갯벌도 밀물에는 바다로 본다
	var board := _board(["LF"])
	board.place_building(Vector2i(1, 0), &"pond")
	assert_eq(Placement.check(board, _engine_defs(), HIGH, &"dock", Vector2i(0, 0)), ALLOWED)


func test_diagonal_is_not_adjacent() -> void:
	assert_eq(Placement.check(_board(["LL", "LS"]), _engine_defs(), LOW, &"dock", Vector2i(0, 0)), NO_ADJACENT_TERRAIN)


func test_outside_board_is_not_sea() -> void:
	# docs/rules.md 2장: 보드 밖은 칸이 아니고 바다로 치지도 않는다
	assert_eq(Placement.check(_board(["L"]), _engine_defs(), HIGH, &"dock", Vector2i(0, 0)), NO_ADJACENT_TERRAIN)


# --- 여러 이유에 걸리면 정해진 순서에서 처음 것 (docs/architecture.md 3.4) ---

func test_out_of_bounds_comes_first() -> void:
	var board := _board(["L"])
	board.place_building(Vector2i(0, 0), &"tower")
	assert_eq(Placement.check(board, _engine_defs(), LOW, &"tower", Vector2i(5, 5)), OUT_OF_BOUNDS)


func test_occupied_comes_before_limit_and_terrain() -> void:
	var board := _board(["S"])
	board.place_building(Vector2i(0, 0), &"tower")
	assert_eq(Placement.check(board, _engine_defs(), LOW, &"tower", Vector2i(0, 0)), OCCUPIED)


func test_limit_comes_before_terrain() -> void:
	var board := _board(["LS"])
	board.place_building(Vector2i(0, 0), &"tower")
	assert_eq(Placement.check(board, _engine_defs(), LOW, &"tower", Vector2i(1, 0)), LIMIT_REACHED)


func test_terrain_comes_before_adjacent_terrain() -> void:
	assert_eq(Placement.check(_board(["FL"]), _engine_defs(), LOW, &"dock", Vector2i(0, 0)), WRONG_TERRAIN)


# --- can_place, legal_cells, has_legal_cell ---

func test_can_place_means_allowed() -> void:
	var board := _board(["LS"])
	var defs := _engine_defs()
	assert_true(Placement.can_place(board, defs, LOW, &"hut", Vector2i(0, 0)))
	assert_false(Placement.can_place(board, defs, LOW, &"hut", Vector2i(1, 0)))
	assert_false(Placement.can_place(board, defs, LOW, &"hut", Vector2i(9, 9)))


func test_legal_cells_follow_board_order() -> void:
	var board := _board(["LFL", "LLS"])
	board.place_building(Vector2i(0, 1), &"hut")
	var expected: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(1, 1)]
	assert_eq(Placement.legal_cells(board, _engine_defs(), LOW, &"hut"), expected)


func test_has_legal_cell_follows_tide() -> void:
	var board := _board(["LF"])
	var defs := _engine_defs()
	assert_true(Placement.has_legal_cell(board, defs, LOW, &"pond"))
	assert_false(Placement.has_legal_cell(board, defs, HIGH, &"pond"))


func test_has_legal_cell_is_false_after_limit() -> void:
	var board := _board(["LL"])
	var defs := _engine_defs()
	board.place_building(Vector2i(0, 0), &"tower")
	assert_true(Placement.has_legal_cell(board, defs, LOW, &"hut"))
	assert_false(Placement.has_legal_cell(board, defs, LOW, &"tower"))


func test_unknown_tile_cannot_be_placed() -> void:
	# docs/architecture.md 3.4: 정의에 없는 타일은 놓을 수 있는 지형이 없는 타일로 본다
	var board := _board(["LL"])
	var defs := _engine_defs()
	assert_eq(Placement.check(board, defs, LOW, &"castle", Vector2i(0, 0)), WRONG_TERRAIN)
	assert_push_error("정의에 없는 타일")
	assert_eq(Placement.check(board, defs, LOW, &"castle", Vector2i(9, 9)), OUT_OF_BOUNDS)
	assert_push_error("정의에 없는 타일")
	assert_eq(Placement.legal_cells(board, defs, LOW, &"castle").size(), 0)
	assert_push_error("정의에 없는 타일")
	assert_false(Placement.has_legal_cell(board, defs, LOW, &"castle"))
	assert_push_error("정의에 없는 타일")


# --- v1 데이터: data/tiles.json으로 docs/rules.md의 표와 예시를 확인한다 ---

func test_rules_4_1_on_land_without_water() -> void:
	# docs/rules.md 4.1: 집, 시장, 등대, 덕장은 육지. 부두는 물 칸과 인접해야 하고, 염전은 갯벌에만
	var expected := {
		&"house": ALLOWED, &"market": ALLOWED, &"lighthouse": ALLOWED, &"drying_rack": ALLOWED,
		&"pier": NO_ADJACENT_TERRAIN, &"salt_farm": WRONG_TERRAIN,
	}
	var board := _board(["L"])
	var defs := _v1_defs()
	for tile_id: StringName in expected:
		assert_eq(Placement.check(board, defs, LOW, tile_id, Vector2i(0, 0)), expected[tile_id], String(tile_id))


func test_only_salt_farm_goes_on_flat() -> void:
	# docs/rules.md 4.1: 갯벌에 놓을 수 있는 건물은 염전뿐이다
	var board := _board(["SFS"])
	var defs := _v1_defs()
	for tile_id: StringName in defs.ids():
		var expected := ALLOWED if tile_id == &"salt_farm" else WRONG_TERRAIN
		assert_eq(Placement.check(board, defs, LOW, tile_id, Vector2i(1, 0)), expected, String(tile_id))


func test_rules_example_4() -> void:
	# docs/rules.md 8장 예시 4. 지도는 L L F S. [타일, 칸, 썰물일 때, 밀물일 때]
	var cases := [
		[&"pier", Vector2i(1, 0), NO_ADJACENT_TERRAIN, ALLOWED],
		[&"pier", Vector2i(0, 0), NO_ADJACENT_TERRAIN, NO_ADJACENT_TERRAIN],
		[&"salt_farm", Vector2i(2, 0), ALLOWED, WRONG_TERRAIN],
		[&"salt_farm", Vector2i(1, 0), WRONG_TERRAIN, WRONG_TERRAIN],
		[&"house", Vector2i(2, 0), WRONG_TERRAIN, WRONG_TERRAIN],
	]
	var board := _board(["LLFS"])
	var defs := _v1_defs()
	for c: Array in cases:
		assert_eq(Placement.check(board, defs, LOW, c[0], c[1]), c[2], "%s %s 썰물" % [c[0], c[1]])
		assert_eq(Placement.check(board, defs, HIGH, c[0], c[1]), c[3], "%s %s 밀물" % [c[0], c[1]])


func test_rules_example_6_second_lighthouse() -> void:
	# docs/rules.md 8장 예시 6: 등대가 이미 있으면 두 번째 등대는 어디에도 놓을 수 없다
	var board := _board(["SSSSS", "LLLLL", "LLLLL"])
	var defs := _v1_defs()
	assert_true(Placement.has_legal_cell(board, defs, LOW, &"lighthouse"))
	board.place_building(Vector2i(2, 2), &"lighthouse")
	assert_false(Placement.has_legal_cell(board, defs, LOW, &"lighthouse"))
	assert_eq(Placement.check(board, defs, LOW, &"lighthouse", Vector2i(0, 2)), LIMIT_REACHED)


func test_rules_example_11_salt_farm_at_high_tide() -> void:
	# docs/rules.md 8장 예시 11: 밀물이면 빈 갯벌이 있어도 염전을 놓을 수 없다
	var board := _board(["LFF"])
	var defs := _v1_defs()
	assert_false(Placement.has_legal_cell(board, defs, HIGH, &"salt_farm"))
	assert_true(Placement.has_legal_cell(board, defs, LOW, &"salt_farm"))


# --- 도우미 ---

func _board(rows: Array[String]) -> BoardState:
	return BoardState.from_island({"rows": rows})


## 규칙 엔진 테스트용 타일. hut은 육지, dock은 바다와 인접한 육지, pond는 갯벌, raft는 바다, tower는 1개까지
func _engine_defs() -> TileDefs:
	var defs := TileDefs.from_dict({"schema_version": 1, "tiles": [
		{"id": "hut", "placement": {"terrain": ["LAND"]}, "scoring": []},
		{"id": "dock", "placement": {"terrain": ["LAND"], "adjacent_terrain": ["SEA"]}, "scoring": []},
		{"id": "pond", "placement": {"terrain": ["FLAT"]}, "scoring": []},
		{"id": "raft", "placement": {"terrain": ["SEA"]}, "scoring": []},
		{"id": "tower", "placement": {"terrain": ["LAND"], "max_on_board": 1}, "scoring": []},
	]})
	assert_eq(defs.errors(), PackedStringArray(), "테스트용 타일 정의가 틀렸다")
	return defs


func _v1_defs() -> TileDefs:
	var defs := TileDefs.load_file("res://data/tiles.json")
	assert_eq(defs.errors(), PackedStringArray(), "data/tiles.json이 검증을 통과하지 못했다")
	return defs
