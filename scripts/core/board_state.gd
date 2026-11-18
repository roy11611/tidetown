class_name BoardState
extends RefCounted
## 격자, 지형, 건물만 안다. 규칙과 물때는 모른다.
##
## 좌표는 Vector2i(x, y)이고 섬 데이터의 rows[y][x]에 대응한다.

enum Cell { LAND, FLAT, SEA }


## 섬 데이터의 rows로 보드를 만든다.
static func from_island(island: Dictionary) -> BoardState:
	# TODO: 구현
	return null


## 보드 크기를 (가로, 세로)로 돌려준다.
func size() -> Vector2i:
	# TODO: 구현
	return Vector2i.ZERO


## pos가 보드 안의 칸인지 돌려준다.
func in_bounds(pos: Vector2i) -> bool:
	# TODO: 구현
	return false


## pos의 원래 지형을 돌려준다. 물때는 반영하지 않는다.
func get_cell(pos: Vector2i) -> Cell:
	# TODO: 구현
	return Cell.LAND


## pos에 건물이 있는지 돌려준다.
func has_building(pos: Vector2i) -> bool:
	# TODO: 구현
	return false


## pos에 놓인 건물의 타일 id를 돌려준다. 건물이 없으면 &"".
func get_building(pos: Vector2i) -> StringName:
	# TODO: 구현
	return &""


## pos에 tile_id 건물을 놓는다.
func place_building(pos: Vector2i, tile_id: StringName) -> void:
	# TODO: 구현
	pass


## pos에서 거리 1 이상 radius 이하인 보드 안의 칸을 위에서 아래, 왼쪽에서 오른쪽 순서로 돌려준다.
func cells_within(pos: Vector2i, radius: int) -> Array[Vector2i]:
	# TODO: 구현
	return []


## 보드에 놓인 tile_id 건물의 수를 돌려준다.
func count_of(tile_id: StringName) -> int:
	# TODO: 구현
	return 0


## 보드의 모든 칸을 위에서 아래, 왼쪽에서 오른쪽 순서로 돌려준다.
func all_cells() -> Array[Vector2i]:
	# TODO: 구현
	return []
