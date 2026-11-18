class_name TileDefs
extends RefCounted
## data/tiles.json을 읽고 검증한다. 만든 뒤에는 바뀌지 않는다.
##
## 검증에 실패한 정의로는 판을 만들지 않는다(GameState.create).


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


## 파싱한 json으로 정의를 만든다. 테스트에서 파일 없이 정의를 만들 때도 쓴다.
static func from_dict(data: Dictionary) -> TileDefs:
	# TODO: 구현
	return null


## 파일을 읽어 from_dict에 넘긴다.
static func load_file(path: String) -> TileDefs:
	# TODO: 구현
	return null


## 검증 오류를 돌려준다. 비어 있어야 정상이다.
func errors() -> PackedStringArray:
	# TODO: 구현
	return PackedStringArray()


## 타일 id를 json에 적힌 순서로 돌려준다.
func ids() -> Array[StringName]:
	# TODO: 구현
	return []


## tile_id가 정의되어 있는지 돌려준다.
func has_tile(tile_id: StringName) -> bool:
	# TODO: 구현
	return false


## tile_id의 정의를 돌려준다.
func get_def(tile_id: StringName) -> TileDef:
	# TODO: 구현
	return null


## tile_id의 점수 규칙 가운데 event(&"place" | &"tide_high" | &"tide_low") 시점의 것을 돌려준다.
func rules_for(tile_id: StringName, event: StringName) -> Array[ScoreRule]:
	# TODO: 구현
	return []
