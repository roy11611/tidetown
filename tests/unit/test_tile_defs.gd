extends GutTest
## TileDefs: tiles.json 형식의 데이터를 읽어 타입을 맞춰 담는다 (docs/architecture.md 3.2, 5.1)
##
## 규칙 엔진 테스트라 실제 data/tiles.json의 수치에 기대지 않고, 테스트 안에서 만든 타일을 쓴다.

const LAND := BoardState.Cell.LAND
const FLAT := BoardState.Cell.FLAT
const SEA := BoardState.Cell.SEA
const TEMP_FILE := "user://test_tile_defs.json"


## 파싱 테스트에 쓰는 정상 데이터. id 순서가 사전순이 아니다.
func _sample() -> Dictionary:
	return {
		"schema_version": 1,
		"tiles": [
			{
				"id": "pier",
				"display": {"name": "부두", "label": "부", "color": "#8D6E63"},
				"placement": {"terrain": ["LAND"], "adjacent_terrain": ["SEA", "FLAT"], "max_on_board": 2},
				"scoring": [
					{"on": "tide_high", "type": "flat", "points": 3},
					{"on": "tide_high", "type": "count", "match": {"tiles": ["pier"]}, "radius": 1, "points": -1},
				],
			},
			{
				"id": "hut",
				"placement": {"terrain": ["LAND", "FLAT"]},
				"scoring": [
					{"on": "place", "type": "count", "match": {"terrain": ["SEA"]}, "radius": 2, "points": 1, "max_count": 3},
					{"on": "tide_low", "type": "flat", "points": 2},
					{"on": "place", "type": "count", "match": {"tiles": ["pier", "hut"]}, "radius": 1, "points": 2},
				],
			},
		],
	}


## 실제 입력처럼 json을 한 번 거쳐서 만든다. 숫자는 float, 배열은 타입 없는 Array가 된다.
func _defs_from(data: Dictionary) -> TileDefs:
	return TileDefs.from_dict(JSON.parse_string(JSON.stringify(data, "", false)))


func after_each() -> void:
	if FileAccess.file_exists(TEMP_FILE):
		DirAccess.remove_absolute(TEMP_FILE)


# --- 타일 목록 ---

func test_ids_follow_json_order() -> void:
	var expected: Array[StringName] = [&"pier", &"hut"]
	assert_eq(_defs_from(_sample()).ids(), expected)


func test_ids_returns_a_copy() -> void:
	var defs := _defs_from(_sample())
	defs.ids().append(&"extra")
	assert_eq(defs.ids().size(), 2)


func test_has_tile() -> void:
	var defs := _defs_from(_sample())
	assert_true(defs.has_tile(&"pier"))
	assert_true(defs.has_tile(&"hut"))
	assert_false(defs.has_tile(&"house"))


func test_get_def_of_unknown_tile_is_null() -> void:
	assert_null(_defs_from(_sample()).get_def(&"house"))


# --- 배치 조건 ---

func test_reads_placement() -> void:
	var def := _defs_from(_sample()).get_def(&"pier")
	var terrain: Array[BoardState.Cell] = [LAND]
	var adjacent: Array[BoardState.Cell] = [SEA, FLAT]
	assert_eq(def.id, &"pier")
	assert_eq(def.terrain, terrain)
	assert_eq(def.adjacent_terrain, adjacent)
	assert_eq(def.max_on_board, 2)


func test_optional_placement_fields_default_to_no_condition() -> void:
	var def := _defs_from(_sample()).get_def(&"hut")
	var terrain: Array[BoardState.Cell] = [LAND, FLAT]
	assert_eq(def.terrain, terrain)
	assert_eq(def.adjacent_terrain.size(), 0)
	assert_eq(def.max_on_board, 0)


# --- 점수 규칙 ---

func test_reads_flat_rule() -> void:
	var rule := _defs_from(_sample()).get_def(&"pier").rules[0]
	assert_eq(rule.on, &"tide_high")
	assert_eq(rule.kind, &"flat")
	assert_eq(rule.points, 3)
	assert_eq(rule.radius, 0)
	assert_eq(rule.max_count, 0)
	assert_eq(rule.match_tiles.size(), 0)
	assert_eq(rule.match_terrain.size(), 0)


func test_reads_count_rule_matching_tiles() -> void:
	var rule := _defs_from(_sample()).get_def(&"pier").rules[1]
	var match_tiles: Array[StringName] = [&"pier"]
	assert_eq(rule.on, &"tide_high")
	assert_eq(rule.kind, &"count")
	assert_eq(rule.points, -1)
	assert_eq(rule.radius, 1)
	assert_eq(rule.match_tiles, match_tiles)
	assert_eq(rule.match_terrain.size(), 0)
	assert_eq(rule.max_count, 0)


func test_reads_count_rule_matching_terrain_with_max_count() -> void:
	var rule := _defs_from(_sample()).get_def(&"hut").rules[0]
	var match_terrain: Array[BoardState.Cell] = [SEA]
	assert_eq(rule.on, &"place")
	assert_eq(rule.radius, 2)
	assert_eq(rule.points, 1)
	assert_eq(rule.max_count, 3)
	assert_eq(rule.match_terrain, match_terrain)
	assert_eq(rule.match_tiles.size(), 0)


func test_rules_for_picks_event_in_json_order() -> void:
	var defs := _defs_from(_sample())
	var expected_place: Array[int] = [1, 2]
	var expected_low: Array[int] = [2]
	assert_eq(_points_of(defs.rules_for(&"hut", &"place")), expected_place)
	assert_eq(_points_of(defs.rules_for(&"hut", &"tide_low")), expected_low)
	assert_eq(defs.rules_for(&"hut", &"tide_high").size(), 0)


func test_rules_for_unknown_tile_is_empty() -> void:
	assert_eq(_defs_from(_sample()).rules_for(&"house", &"place").size(), 0)


# --- display, 파일 ---

func test_display_is_passed_through() -> void:
	var defs := _defs_from(_sample())
	assert_eq(defs.get_def(&"pier").display, {"name": "부두", "label": "부", "color": "#8D6E63"})
	assert_eq(defs.get_def(&"hut").display, {})


func test_load_file_reads_json_file() -> void:
	var file := FileAccess.open(TEMP_FILE, FileAccess.WRITE)
	file.store_string(JSON.stringify(_sample(), "  ", false))
	file.close()
	var expected: Array[StringName] = [&"pier", &"hut"]
	assert_eq(TileDefs.load_file(TEMP_FILE).ids(), expected)


func _points_of(rules: Array[TileDefs.ScoreRule]) -> Array[int]:
	var points: Array[int] = []
	for rule: TileDefs.ScoreRule in rules:
		points.append(rule.points)
	return points
