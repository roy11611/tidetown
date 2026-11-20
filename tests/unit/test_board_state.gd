extends GutTest
## BoardState: 지도 읽기, 범위, 칸 순회 순서, 건물 놓기 (docs/architecture.md 3.1)

const LAND := BoardState.Cell.LAND
const FLAT := BoardState.Cell.FLAT
const SEA := BoardState.Cell.SEA


func _board(rows: Array[String]) -> BoardState:
	return BoardState.from_island({"rows": rows})


# --- 지도 읽기 ---

func test_size_is_width_then_height() -> void:
	var board := _board(["LLLL", "FFFF", "SSSS"])
	assert_eq(board.size(), Vector2i(4, 3))


func test_get_cell_reads_rows_y_x() -> void:
	var board := _board(["LFS", "SLF"])
	assert_eq(board.get_cell(Vector2i(0, 0)), LAND)
	assert_eq(board.get_cell(Vector2i(1, 0)), FLAT)
	assert_eq(board.get_cell(Vector2i(2, 0)), SEA)
	assert_eq(board.get_cell(Vector2i(0, 1)), SEA)
	assert_eq(board.get_cell(Vector2i(1, 1)), LAND)
	assert_eq(board.get_cell(Vector2i(2, 1)), FLAT)


# --- 범위 ---

func test_in_bounds() -> void:
	var board := _board(["LLL", "LLL"])
	assert_true(board.in_bounds(Vector2i(0, 0)))
	assert_true(board.in_bounds(Vector2i(2, 1)))
	assert_false(board.in_bounds(Vector2i(-1, 0)))
	assert_false(board.in_bounds(Vector2i(0, -1)))
	assert_false(board.in_bounds(Vector2i(3, 0)))
	assert_false(board.in_bounds(Vector2i(0, 2)))


# --- 칸 순회: 위에서 아래로, 같은 줄에서는 왼쪽에서 오른쪽으로 ---

func test_all_cells_goes_top_to_bottom_then_left_to_right() -> void:
	var board := _board(["LLL", "LLL"])
	var expected: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	]
	assert_eq(board.all_cells(), expected)


func test_cells_within_radius_1_is_four_neighbors_in_order() -> void:
	var board := _board(["LLL", "LLL", "LLL"])
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]
	assert_eq(board.cells_within(Vector2i(1, 1), 1), expected)


func test_cells_within_leaves_out_cells_outside_board() -> void:
	var board := _board(["LLL", "LLL", "LLL"])
	var expected: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1)]
	assert_eq(board.cells_within(Vector2i(0, 0), 1), expected)


func test_cells_within_radius_2_is_12_cells_in_order() -> void:
	var board := _board(["LLLLL", "LLLLL", "LLLLL", "LLLLL", "LLLLL"])
	var expected: Array[Vector2i] = [
		Vector2i(2, 0),
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(3, 2), Vector2i(4, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
		Vector2i(2, 4),
	]
	assert_eq(board.cells_within(Vector2i(2, 2), 2), expected)


func test_cells_within_radius_2_matches_rules_example_6() -> void:
	# docs/rules.md 8장 예시 6: (2,2)에서 반경 2 안의 y=1 칸은 (1,1), (2,1), (3,1)뿐이다
	var board := _board(["SSSSS", "LLLLL", "LLLLL"])
	var row_1: Array[Vector2i] = []
	for cell: Vector2i in board.cells_within(Vector2i(2, 2), 2):
		if cell.y == 1:
			row_1.append(cell)
	var expected: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)]
	assert_eq(row_1, expected)


func test_cells_within_radius_0_is_empty() -> void:
	var board := _board(["LLL", "LLL", "LLL"])
	assert_eq(board.cells_within(Vector2i(1, 1), 0).size(), 0)


# --- 건물 ---

func test_new_board_has_no_buildings() -> void:
	var board := _board(["LL"])
	assert_false(board.has_building(Vector2i(0, 0)))
	assert_eq(board.get_building(Vector2i(0, 0)), &"")
	assert_eq(board.count_of(&"house"), 0)


func test_place_building() -> void:
	var board := _board(["LL"])
	board.place_building(Vector2i(1, 0), &"house")
	assert_true(board.has_building(Vector2i(1, 0)))
	assert_eq(board.get_building(Vector2i(1, 0)), &"house")
	assert_false(board.has_building(Vector2i(0, 0)))


func test_count_of_counts_each_tile_id() -> void:
	var board := _board(["LLLL"])
	board.place_building(Vector2i(0, 0), &"house")
	board.place_building(Vector2i(1, 0), &"pier")
	board.place_building(Vector2i(2, 0), &"house")
	assert_eq(board.count_of(&"house"), 2)
	assert_eq(board.count_of(&"pier"), 1)
	assert_eq(board.count_of(&"market"), 0)


func test_building_does_not_change_terrain() -> void:
	# docs/rules.md 3장: 건물이 있어도 그 칸의 지형은 그대로다
	var board := _board(["LF"])
	board.place_building(Vector2i(1, 0), &"salt_farm")
	assert_eq(board.get_cell(Vector2i(1, 0)), FLAT)


# --- 잘못된 호출 (docs/architecture.md 3.1) ---

func test_place_on_occupied_cell_keeps_first_building() -> void:
	var board := _board(["LL"])
	board.place_building(Vector2i(0, 0), &"house")
	board.place_building(Vector2i(0, 0), &"pier")
	assert_push_error("이미 건물")
	assert_eq(board.get_building(Vector2i(0, 0)), &"house")
	assert_eq(board.count_of(&"house"), 1)
	assert_eq(board.count_of(&"pier"), 0)


func test_place_outside_board_changes_nothing() -> void:
	var board := _board(["LL"])
	board.place_building(Vector2i(-1, 0), &"house")
	assert_push_error("보드 밖")
	assert_eq(board.count_of(&"house"), 0)


func test_place_empty_tile_id_changes_nothing() -> void:
	var board := _board(["LL"])
	board.place_building(Vector2i(0, 0), &"")
	assert_push_error("빈 타일 id")
	assert_false(board.has_building(Vector2i(0, 0)))


func test_outside_board_has_no_building() -> void:
	var board := _board(["LL"])
	assert_false(board.has_building(Vector2i(-1, 0)))
	assert_eq(board.get_building(Vector2i(2, 0)), &"")


func test_get_cell_outside_board_reports_error() -> void:
	# 범위 검사가 없으면 (-1, 0)은 배열의 마지막 칸 (1, 0)의 SEA로 읽힌다
	var board := _board(["LS"])
	assert_eq(board.get_cell(Vector2i(-1, 0)), LAND)
	assert_push_error("보드 밖")
