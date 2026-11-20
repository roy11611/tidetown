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
	_write_temp(JSON.stringify(_sample(), "  ", false))
	var expected: Array[StringName] = [&"pier", &"hut"]
	assert_eq(TileDefs.load_file(TEMP_FILE).ids(), expected)


# --- 검증 (docs/architecture.md 5.1): 정상 샘플에서 한 곳만 고치면 그 자리의 오류 하나만 나온다 ---

func test_sample_has_no_errors() -> void:
	assert_eq(_errors_of(_sample()), PackedStringArray())


func test_duplicate_id_is_an_error() -> void:
	_assert_one_error(_sample_plus(_tile("pier")), "tiles[2].id", "겹친다")


func test_id_must_be_lowercase_letters_and_underscores() -> void:
	for bad_id: Variant in ["House", "salt-farm", "pier2", "", 3, null]:
		_assert_one_error(_sample_plus(_tile(bad_id)), "tiles[2].id", "소문자와 밑줄")


func test_id_may_contain_underscores() -> void:
	assert_eq(_errors_of(_sample_plus(_tile("salt_farm"))), PackedStringArray())


func test_terrain_must_not_be_empty() -> void:
	_assert_one_error(_sample_with(["tiles", 1, "placement", "terrain"], []), "hut.placement.terrain", "비어 있으면 안 된다")


func test_unknown_terrain_name_is_an_error() -> void:
	_assert_one_error(_sample_with(["tiles", 1, "placement", "terrain"], ["land"]), "hut.placement.terrain", "\"land\"")
	_assert_one_error(_sample_with(["tiles", 0, "placement", "adjacent_terrain"], ["SEA", "MUD"]), "pier.placement.adjacent_terrain", "\"MUD\"")
	_assert_one_error(_sample_with(["tiles", 1, "scoring", 0, "match", "terrain"], ["DEEP"]), "hut.scoring[0].match.terrain", "\"DEEP\"")


func test_unknown_on_or_type_is_an_error() -> void:
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 0, "on"], "tide_mid"), "pier.scoring[0].on", "place, tide_high, tide_low")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 1, "type"], "sum"), "pier.scoring[1].type", "flat, count")


func test_match_tiles_must_name_tiles_in_file() -> void:
	_assert_one_error(_sample_with(["tiles", 1, "scoring", 2, "match", "tiles"], ["pier", "house"]), "hut.scoring[2].match.tiles", "house")


func test_match_tiles_may_name_a_later_tile() -> void:
	assert_eq(_errors_of(_sample_with(["tiles", 0, "scoring", 1, "match", "tiles"], ["hut"])), PackedStringArray())


func test_match_needs_exactly_one_of_tiles_or_terrain() -> void:
	var both := {"tiles": ["pier"], "terrain": ["SEA"]}
	_assert_one_error(_sample_with(["tiles", 1, "scoring", 0, "match"], both), "hut.scoring[0].match", "하나만")
	_assert_one_error(_sample_with(["tiles", 1, "scoring", 0, "match"], {}), "hut.scoring[0].match", "하나만")


func test_numbers_must_be_whole() -> void:
	for bad: Variant in [1.5, "3", true]:
		_assert_one_error(_sample_with(["tiles", 0, "scoring", 0, "points"], bad), "pier.scoring[0].points", "정수")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 1, "radius"], 1.5), "pier.scoring[1].radius", "1 이상의 정수")
	_assert_one_error(_sample_with(["tiles", 1, "scoring", 0, "max_count"], 2.5), "hut.scoring[0].max_count", "1 이상의 정수")
	_assert_one_error(_sample_with(["tiles", 0, "placement", "max_on_board"], "2"), "pier.placement.max_on_board", "1 이상의 정수")


func test_radius_max_count_and_max_on_board_must_be_at_least_1() -> void:
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 1, "radius"], 0), "pier.scoring[1].radius", "1 이상")
	_assert_one_error(_sample_with(["tiles", 1, "scoring", 0, "max_count"], 0), "hut.scoring[0].max_count", "1 이상")
	_assert_one_error(_sample_with(["tiles", 0, "placement", "max_on_board"], -1), "pier.placement.max_on_board", "1 이상")


func test_unknown_field_name_is_an_error() -> void:
	_assert_one_error(_sample_with(["tile"], []), "tile", "스키마에 없는")
	_assert_one_error(_sample_with(["tiles", 0, "colour"], "red"), "pier.colour", "스키마에 없는")
	_assert_one_error(_sample_with(["tiles", 0, "placement", "max_on_bord"], 1), "pier.placement.max_on_bord", "스키마에 없는")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 0, "point"], 3), "pier.scoring[0].point", "스키마에 없는")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 1, "match", "tile"], ["pier"]), "pier.scoring[1].match.tile", "스키마에 없는")


func test_display_contents_are_not_checked() -> void:
	assert_eq(_errors_of(_sample_with(["tiles", 0, "display", "anything"], 1)), PackedStringArray())


func test_missing_required_field_is_an_error() -> void:
	var no_id := _tile("x")
	no_id.erase("id")
	_assert_one_error(_sample_without(["tiles"]), "tiles", "없음")
	_assert_one_error(_sample_plus(no_id), "tiles[2].id", "없음")
	_assert_one_error(_sample_without(["tiles", 1, "placement"]), "hut.placement", "없음")
	_assert_one_error(_sample_without(["tiles", 1, "placement", "terrain"]), "hut.placement.terrain", "없음")
	_assert_one_error(_sample_without(["tiles", 1, "scoring"]), "hut.scoring", "없음")
	_assert_one_error(_sample_without(["tiles", 0, "scoring", 0, "on"]), "pier.scoring[0].on", "없음")
	_assert_one_error(_sample_without(["tiles", 0, "scoring", 0, "type"]), "pier.scoring[0].type", "없음")
	_assert_one_error(_sample_without(["tiles", 0, "scoring", 0, "points"]), "pier.scoring[0].points", "없음")
	_assert_one_error(_sample_without(["tiles", 0, "scoring", 1, "radius"]), "pier.scoring[1].radius", "없음")
	_assert_one_error(_sample_without(["tiles", 0, "scoring", 1, "match"]), "pier.scoring[1].match", "없음")


func test_wrong_type_is_an_error() -> void:
	_assert_one_error(_sample_with(["tiles"], "pier"), "tiles", "배열")
	_assert_one_error(_sample_plus("hut"), "tiles[2]", "객체")
	_assert_one_error(_sample_with(["tiles", 0, "display"], "부두"), "pier.display", "객체")
	_assert_one_error(_sample_with(["tiles", 1, "placement"], ["LAND"]), "hut.placement", "객체")
	_assert_one_error(_sample_with(["tiles", 1, "placement", "terrain"], "LAND"), "hut.placement.terrain", "배열")
	_assert_one_error(_sample_with(["tiles", 1, "scoring"], {}), "hut.scoring", "배열")
	_assert_one_error(_sample_with(["tiles", 1, "scoring", 1], 3), "hut.scoring[1]", "객체")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 1, "match"], ["pier"]), "pier.scoring[1].match", "객체")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 1, "match", "tiles"], "pier"), "pier.scoring[1].match.tiles", "배열")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 1, "match", "tiles"], ["pier", 3]), "pier.scoring[1].match.tiles", "문자열")


func test_flat_rule_must_not_have_count_only_fields() -> void:
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 0, "radius"], 1), "pier.scoring[0].radius", "count 규칙에만")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 0, "max_count"], 1), "pier.scoring[0].max_count", "count 규칙에만")
	_assert_one_error(_sample_with(["tiles", 0, "scoring", 0, "match"], {"tiles": ["pier"]}), "pier.scoring[0].match", "count 규칙에만")


func test_schema_version_must_be_1() -> void:
	_assert_one_error(_sample_with(["schema_version"], 2), "schema_version", "1이어야")
	_assert_one_error(_sample_with(["schema_version"], "1"), "schema_version", "1이어야")
	_assert_one_error(_sample_without(["schema_version"]), "schema_version", "없음")


func test_collects_every_error() -> void:
	var data := _sample_with(["tiles", 0, "scoring", 0, "points"], 1.5)
	data["tiles"][1]["placement"]["terrain"] = []
	assert_eq(_errors_of(data).size(), 2)


func test_load_file_reports_missing_file() -> void:
	var defs := TileDefs.load_file("user://no_such_tiles.json")
	assert_not_null(defs)
	assert_eq(defs.errors().size(), 1)
	assert_string_contains(defs.errors()[0], "파일이 없다")


func test_load_file_reports_broken_json_with_line_number() -> void:
	_write_temp('{\n  "schema_version": 1,\n  "tiles": \n}')
	var errors := TileDefs.load_file(TEMP_FILE).errors()
	assert_eq(errors.size(), 1)
	assert_true(RegEx.create_from_string("^%s:\\d+: json" % TEMP_FILE.replace(".", "\\.")).search(errors[0]) != null, errors[0])


func test_load_file_reports_non_object_top_level() -> void:
	_write_temp("[1, 2]")
	var errors := TileDefs.load_file(TEMP_FILE).errors()
	assert_eq(errors.size(), 1)
	assert_string_contains(errors[0], "최상위가 객체가 아니다")


# --- 도우미 ---

func _points_of(rules: Array[TileDefs.ScoreRule]) -> Array[int]:
	var points: Array[int] = []
	for rule: TileDefs.ScoreRule in rules:
		points.append(rule.points)
	return points


func _write_temp(text: String) -> void:
	var file := FileAccess.open(TEMP_FILE, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _errors_of(data: Dictionary) -> PackedStringArray:
	return _defs_from(data).errors()


## 오류가 정확히 하나이고, where 자리의 오류이며, hint를 담고 있는지 확인한다.
func _assert_one_error(data: Dictionary, where: String, hint: String) -> void:
	var errors := _errors_of(data)
	var found := errors.size() == 1 and errors[0].begins_with(where + ": ") and errors[0].contains(hint)
	assert_true(found, "'%s: …%s…' 오류 하나를 기대했다. 받은 오류: %s" % [where, hint, errors])


## 검증 테스트에서 덧붙이는 가장 단순한 타일
func _tile(id: Variant) -> Dictionary:
	return {"id": id, "placement": {"terrain": ["LAND"]}, "scoring": []}


func _sample_plus(tile: Variant) -> Dictionary:
	var data := _sample()
	data["tiles"].append(tile)
	return data


## _sample()에서 path 자리의 값만 value로 바꾼 데이터
func _sample_with(path: Array, value: Variant) -> Dictionary:
	var data := _sample()
	var parent: Variant = _parent_of(data, path)
	parent[path[-1]] = value
	return data


## _sample()에서 path 자리의 필드를 지운 데이터
func _sample_without(path: Array) -> Dictionary:
	var data := _sample()
	var parent: Variant = _parent_of(data, path)
	parent.erase(path[-1])
	return data


func _parent_of(data: Dictionary, path: Array) -> Variant:
	var node: Variant = data
	for i: int in path.size() - 1:
		node = node[path[i]]
	return node
