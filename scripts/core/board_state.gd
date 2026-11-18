class_name BoardState
extends RefCounted
## 격자, 지형, 건물만 안다. 규칙과 물때는 모른다.
##
## 좌표는 Vector2i(x, y)이고 섬 데이터의 rows[y][x]에 대응한다.
## 잘못된 호출은 보드를 바꾸지 않고 push_error로 알린다(docs/architecture.md 3.1).

enum Cell { LAND, FLAT, SEA }

## 섬 데이터 rows의 글자와 지형 (docs/architecture.md 5.2)
const _CELL_BY_CHAR: Dictionary[String, Cell] = { "L": Cell.LAND, "F": Cell.FLAT, "S": Cell.SEA }

var _size: Vector2i = Vector2i.ZERO
var _cells: Array[Cell] = []                            # rows[y][x]를 y * 가로 + x 자리에 담는다
var _buildings: Dictionary[Vector2i, StringName] = {}
var _counts: Dictionary[StringName, int] = {}           # count_of를 위한 타일 id별 개수


## 섬 데이터의 rows로 보드를 만든다. GameState.validate_island를 통과한 데이터여야 한다.
static func from_island(island: Dictionary) -> BoardState:
	var rows: Array = island["rows"]
	var board := BoardState.new()
	board._size = Vector2i((rows[0] as String).length(), rows.size())
	for row: String in rows:
		for x in board._size.x:
			board._cells.append(_CELL_BY_CHAR[row[x]])
	return board


## 보드 크기를 (가로, 세로)로 돌려준다.
func size() -> Vector2i:
	return _size


## pos가 보드 안의 칸인지 돌려준다.
func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < _size.x and pos.y < _size.y


## pos의 원래 지형을 돌려준다. 물때는 반영하지 않는다. 보드 밖이면 push_error를 내고 LAND.
func get_cell(pos: Vector2i) -> Cell:
	if not in_bounds(pos):
		push_error("BoardState.get_cell: 보드 밖 좌표 %s" % pos)
		return Cell.LAND
	return _cells[pos.y * _size.x + pos.x]


## pos에 건물이 있는지 돌려준다. 보드 밖이면 false.
func has_building(pos: Vector2i) -> bool:
	return _buildings.has(pos)


## pos에 놓인 건물의 타일 id를 돌려준다. 건물이 없거나 보드 밖이면 &"".
func get_building(pos: Vector2i) -> StringName:
	return _buildings.get(pos, &"")


## pos에 tile_id 건물을 놓는다. 보드 밖, 이미 건물이 있는 칸, 빈 id면 보드를 바꾸지 않고 push_error.
func place_building(pos: Vector2i, tile_id: StringName) -> void:
	var problem := _place_problem(pos, tile_id)
	if problem != "":
		push_error("BoardState.place_building: " + problem)
		return
	_buildings[pos] = tile_id
	_counts[tile_id] = _counts.get(tile_id, 0) + 1


## pos에서 거리 1 이상 radius 이하인 보드 안의 칸을 위에서 아래, 왼쪽에서 오른쪽 순서로 돌려준다.
func cells_within(pos: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		var reach := radius - absi(dy)
		for dx in range(-reach, reach + 1):
			var cell := pos + Vector2i(dx, dy)
			if cell != pos and in_bounds(cell):
				result.append(cell)
	return result


## 보드에 놓인 tile_id 건물의 수를 돌려준다.
func count_of(tile_id: StringName) -> int:
	return _counts.get(tile_id, 0)


## 보드의 모든 칸을 위에서 아래, 왼쪽에서 오른쪽 순서로 돌려준다.
func all_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in _size.y:
		for x in _size.x:
			result.append(Vector2i(x, y))
	return result


func _place_problem(pos: Vector2i, tile_id: StringName) -> String:
	if not in_bounds(pos):
		return "보드 밖 좌표 %s" % pos
	if has_building(pos):
		return "%s에 이미 건물 %s가 있다" % [pos, get_building(pos)]
	if tile_id == &"":
		return "빈 타일 id"
	return ""
