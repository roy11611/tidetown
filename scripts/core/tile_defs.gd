class_name TileDefs
extends RefCounted
## data/tiles.json을 읽고 검증한다. 만든 뒤에는 바뀌지 않는다.
##
## 검증에 실패한 정의로는 판을 만들지 않는다(GameState.create).
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


var _ids: Array[StringName] = []
var _defs: Dictionary[StringName, TileDef] = {}
var _errors := PackedStringArray()


## 파싱한 json으로 정의를 만든다. 테스트에서 파일 없이 정의를 만들 때도 쓴다.
static func from_dict(data: Dictionary) -> TileDefs:
	var defs := TileDefs.new()
	for tile: Dictionary in data["tiles"]:
		defs._add_tile(tile)
	return defs


## 파일을 읽어 from_dict에 넘긴다.
static func load_file(path: String) -> TileDefs:
	return from_dict(JSON.parse_string(FileAccess.get_file_as_string(path)))


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


func _add_tile(tile: Dictionary) -> void:
	var def := TileDef.new()
	def.id = StringName(tile["id"])
	def.display = tile.get("display", {})
	var placement: Dictionary = tile["placement"]
	def.terrain = _cells_of(placement["terrain"])
	def.adjacent_terrain = _cells_of(placement.get("adjacent_terrain", []))
	def.max_on_board = int(placement.get("max_on_board", 0))
	for rule: Dictionary in tile["scoring"]:
		def.rules.append(_rule_of(rule))
	_ids.append(def.id)
	_defs[def.id] = def


static func _rule_of(data: Dictionary) -> ScoreRule:
	var rule := ScoreRule.new()
	rule.on = StringName(data["on"])
	rule.kind = StringName(data["type"])
	rule.points = int(data["points"])
	rule.radius = int(data.get("radius", 0))
	rule.max_count = int(data.get("max_count", 0))
	var match_dict: Dictionary = data.get("match", {})
	rule.match_tiles = _ids_of(match_dict.get("tiles", []))
	rule.match_terrain = _cells_of(match_dict.get("terrain", []))
	return rule


static func _cells_of(names: Array) -> Array[BoardState.Cell]:
	var cells: Array[BoardState.Cell] = []
	for cell_name: String in names:
		cells.append(BoardState.Cell[cell_name])
	return cells


static func _ids_of(values: Array) -> Array[StringName]:
	var result: Array[StringName] = []
	for value: String in values:
		result.append(StringName(value))
	return result
