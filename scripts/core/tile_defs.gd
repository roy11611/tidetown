class_name TileDefs
extends RefCounted
## data/tiles.json을 읽고 검증한다. 만든 뒤에는 바뀌지 않는다.
##
## 검증에 실패한 정의로는 판을 만들지 않는다(GameState.create). 찾은 문제는 모두 errors()에 모은다.
## json의 숫자는 정수도 float로 오므로 int로, 문자열 id는 StringName으로 바꿔 담는다.


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


## 지원하는 tiles.json 형식의 버전
const _SCHEMA_VERSION := 1
## 스키마에 있는 필드 이름 (docs/architecture.md 5.1)
const _ROOT_FIELDS: Array[String] = ["schema_version", "tiles"]
const _TILE_FIELDS: Array[String] = ["id", "display", "placement", "scoring"]
const _PLACEMENT_FIELDS: Array[String] = ["terrain", "adjacent_terrain", "max_on_board"]
const _RULE_FIELDS: Array[String] = ["on", "type", "points", "match", "radius", "max_count"]
const _COUNT_ONLY_FIELDS: Array[String] = ["match", "radius", "max_count"]
const _MATCH_FIELDS: Array[String] = ["tiles", "terrain"]
const _EVENTS: Array[StringName] = [&"place", &"tide_high", &"tide_low"]
const _KINDS: Array[StringName] = [&"flat", &"count"]

var _ids: Array[StringName] = []
var _defs: Dictionary[StringName, TileDef] = {}
var _errors := PackedStringArray()
var _references: Array[Array] = []           # [오류 위치, 타일 id]. 모든 타일을 읽은 뒤 확인한다


## 파싱한 json으로 정의를 만든다. 데이터가 틀려도 null이 아니고, 찾은 문제를 모두 errors()에 담는다.
static func from_dict(data: Dictionary) -> TileDefs:
	var defs := TileDefs.new()
	defs._read_root(data)
	defs._check_references()
	return defs


## 파일을 읽어 from_dict에 넘긴다. 파일이 없거나 json이 깨졌으면 그 내용을 errors()에 담은 빈 정의를 돌려준다.
static func load_file(path: String) -> TileDefs:
	if not FileAccess.file_exists(path):
		return _failed("%s: 파일이 없다" % path)
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return _failed("%s:%d: json 형식이 틀렸다 (%s)" % [path, json.get_error_line(), json.get_error_message()])
	if not json.data is Dictionary:
		return _failed("%s: 최상위가 객체가 아니다" % path)
	return from_dict(json.data)


## 검증 오류를 돌려준다. 비어 있어야 정상이다.
func errors() -> PackedStringArray:
	return _errors


## 타일 id를 json에 적힌 순서로 돌려준다. 돌려받은 배열을 바꿔도 정의는 바뀌지 않는다.
func ids() -> Array[StringName]:
	return _ids.duplicate()


## tile_id가 정의되어 있는지 돌려준다.
func has_tile(tile_id: StringName) -> bool:
	return _defs.has(tile_id)


## tile_id의 정의를 돌려준다. 없는 id면 null.
func get_def(tile_id: StringName) -> TileDef:
	return _defs.get(tile_id)


## tile_id의 점수 규칙 가운데 event(&"place" | &"tide_high" | &"tide_low") 시점의 것을 json 순서로 돌려준다.
func rules_for(tile_id: StringName, event: StringName) -> Array[ScoreRule]:
	var result: Array[ScoreRule] = []
	if not _defs.has(tile_id):
		return result
	for rule: ScoreRule in _defs[tile_id].rules:
		if rule.on == event:
			result.append(rule)
	return result


# --- 읽기: 필드 종류별로 검사하며 타입을 맞춰 담는다 ---

static func _failed(message: String) -> TileDefs:
	var defs := TileDefs.new()
	defs._errors.append(message)
	return defs


func _read_root(data: Dictionary) -> void:
	_check_fields(data, _ROOT_FIELDS, "")
	var version: Variant = data.get("schema_version")
	if not (_is_whole_number(version) and int(version) == _SCHEMA_VERSION):
		_bad_value("schema_version", "%d이어야 한다" % _SCHEMA_VERSION, version)
	var tiles: Variant = data.get("tiles")
	if not tiles is Array:
		_bad_value("tiles", "타일의 배열이어야 한다", tiles)
		return
	for i: int in tiles.size():
		_read_tile(tiles[i], "tiles[%d]" % i)


func _read_tile(value: Variant, where: String) -> void:
	if not value is Dictionary:
		_bad_value(where, "타일 객체여야 한다", value)
		return
	var tile: Dictionary = value
	var id := _read_id(tile.get("id"), where)
	if id != &"":
		where = String(id)
	_check_fields(tile, _TILE_FIELDS, where)
	var def := TileDef.new()
	def.id = id
	def.display = _read_display(tile.get("display", {}), _path(where, "display"))
	_read_placement(tile.get("placement"), def, _path(where, "placement"))
	def.rules = _read_rules(tile.get("scoring"), _path(where, "scoring"))
	if id != &"":
		_ids.append(id)
		_defs[id] = def


## 올바른 id면 StringName, 아니면 오류를 남기고 &""
func _read_id(value: Variant, where: String) -> StringName:
	if not (value is String and _is_valid_id(value)):
		_bad_value(_path(where, "id"), "소문자와 밑줄로 된 문자열이어야 한다", value)
		return &""
	if _defs.has(StringName(value)):
		_error(_path(where, "id"), "앞의 타일과 겹친다 (%s)" % value)
		return &""
	return StringName(value)


func _read_display(value: Variant, where: String) -> Dictionary:
	if value is Dictionary:
		return value
	_bad_value(where, "객체여야 한다", value)
	return {}


func _read_placement(value: Variant, def: TileDef, where: String) -> void:
	if not value is Dictionary:
		_bad_value(where, "객체여야 한다", value)
		return
	var placement: Dictionary = value
	_check_fields(placement, _PLACEMENT_FIELDS, where)
	var terrain: Variant = placement.get("terrain")
	def.terrain = _read_cells(terrain, _path(where, "terrain"))
	if terrain is Array and terrain.is_empty():
		_error(_path(where, "terrain"), "비어 있으면 안 된다")
	if placement.has("adjacent_terrain"):
		def.adjacent_terrain = _read_cells(placement["adjacent_terrain"], _path(where, "adjacent_terrain"))
	if placement.has("max_on_board"):
		def.max_on_board = _read_positive_int(placement["max_on_board"], _path(where, "max_on_board"))


func _read_cells(value: Variant, where: String) -> Array[BoardState.Cell]:
	var cells: Array[BoardState.Cell] = []
	if not value is Array:
		_bad_value(where, "지형 이름의 배열이어야 한다", value)
		return cells
	for cell_name: Variant in value:
		if cell_name is String and BoardState.Cell.has(cell_name):
			cells.append(BoardState.Cell[cell_name])
		else:
			_bad_value(where, "%s 중 하나여야 한다" % ", ".join(PackedStringArray(BoardState.Cell.keys())), cell_name)
	return cells


func _read_rules(value: Variant, where: String) -> Array[ScoreRule]:
	var rules: Array[ScoreRule] = []
	if not value is Array:
		_bad_value(where, "점수 규칙의 배열이어야 한다", value)
		return rules
	for i: int in value.size():
		var rule := _read_rule(value[i], "%s[%d]" % [where, i])
		if rule != null:
			rules.append(rule)
	return rules


func _read_rule(value: Variant, where: String) -> ScoreRule:
	if not value is Dictionary:
		_bad_value(where, "점수 규칙 객체여야 한다", value)
		return null
	var data: Dictionary = value
	_check_fields(data, _RULE_FIELDS, where)
	var rule := ScoreRule.new()
	rule.on = _read_choice(data.get("on"), _EVENTS, _path(where, "on"))
	rule.kind = _read_choice(data.get("type"), _KINDS, _path(where, "type"))
	rule.points = _read_int(data.get("points"), _path(where, "points"))
	if rule.kind == &"count":
		_read_count_fields(data, rule, where)
	elif rule.kind == &"flat":
		_check_flat_fields(data, where)
	return rule


func _read_count_fields(data: Dictionary, rule: ScoreRule, where: String) -> void:
	rule.radius = _read_positive_int(data.get("radius"), _path(where, "radius"))
	if data.has("max_count"):
		rule.max_count = _read_positive_int(data["max_count"], _path(where, "max_count"))
	_read_match(data.get("match"), rule, _path(where, "match"))


func _check_flat_fields(data: Dictionary, where: String) -> void:
	for field: String in _COUNT_ONLY_FIELDS:
		if data.has(field):
			_error(_path(where, field), "count 규칙에만 쓰는 필드다")


func _read_match(value: Variant, rule: ScoreRule, where: String) -> void:
	if not value is Dictionary:
		_bad_value(where, "객체여야 한다", value)
		return
	var match_dict: Dictionary = value
	_check_fields(match_dict, _MATCH_FIELDS, where)
	if match_dict.has("tiles") == match_dict.has("terrain"):
		_error(where, "tiles와 terrain 중 하나만 있어야 한다")
	elif match_dict.has("tiles"):
		rule.match_tiles = _read_tile_refs(match_dict["tiles"], _path(where, "tiles"))
	else:
		rule.match_terrain = _read_cells(match_dict["terrain"], _path(where, "terrain"))


## 타일 id 목록을 읽는다. 파일에 있는 id인지는 모든 타일을 읽은 뒤 _check_references에서 본다.
func _read_tile_refs(value: Variant, where: String) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		_bad_value(where, "타일 id의 배열이어야 한다", value)
		return result
	for item: Variant in value:
		if item is String:
			result.append(StringName(item))
			_references.append([where, StringName(item)])
		else:
			_bad_value(where, "타일 id 문자열이어야 한다", item)
	return result


func _check_references() -> void:
	for pending: Array in _references:
		if not _defs.has(pending[1]):
			_error(pending[0], "파일에 없는 타일 id다 (%s)" % pending[1])
	_references.clear()


func _read_choice(value: Variant, choices: Array[StringName], where: String) -> StringName:
	if value is String and choices.has(StringName(value)):
		return StringName(value)
	_bad_value(where, "%s 중 하나여야 한다" % ", ".join(PackedStringArray(choices)), value)
	return &""


func _read_int(value: Variant, where: String) -> int:
	if _is_whole_number(value):
		return int(value)
	_bad_value(where, "정수여야 한다", value)
	return 0


func _read_positive_int(value: Variant, where: String) -> int:
	if _is_whole_number(value) and int(value) >= 1:
		return int(value)
	_bad_value(where, "1 이상의 정수여야 한다", value)
	return 0


func _check_fields(data: Dictionary, allowed: Array[String], where: String) -> void:
	for key: Variant in data:
		if not allowed.has(key):
			_error(_path(where, str(key)), "스키마에 없는 필드다")


# --- 오류 기록 ---

func _error(where: String, message: String) -> void:
	_errors.append("%s: %s" % [where, message])


func _bad_value(where: String, expectation: String, got: Variant) -> void:
	_error(where, "%s (받은 값: %s)" % [expectation, _shown(got)])


static func _path(where: String, field: String) -> String:
	return field if where.is_empty() else "%s.%s" % [where, field]


## 오류 메시지에 넣을 값. 문자열은 따옴표로 감싸고, 정수인 float는 정수로 적는다.
static func _shown(value: Variant) -> String:
	if value == null:
		return "없음"
	if value is String:
		return "\"%s\"" % value
	if _is_whole_number(value):
		return str(int(value))
	return str(value)


static func _is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and value == floorf(value)


static func _is_valid_id(text: String) -> bool:
	if text.is_empty():
		return false
	for c: String in text:
		if c != "_" and (c < "a" or c > "z"):
			return false
	return true
