extends GutTest
## 실제 data/ 파일이 검증을 통과하는지 확인한다 (docs/architecture.md 9장)

const TILES_PATH := "res://data/tiles.json"


func test_tiles_json_passes_validation() -> void:
	assert_eq(TileDefs.load_file(TILES_PATH).errors(), PackedStringArray())


func test_tiles_json_has_the_six_v1_tiles() -> void:
	# docs/rules.md 4.1의 타일 6종
	var defs := TileDefs.load_file(TILES_PATH)
	assert_eq(defs.ids().size(), 6)
	for tile_id: StringName in [&"house", &"pier", &"market", &"lighthouse", &"salt_farm", &"drying_rack"]:
		assert_true(defs.has_tile(tile_id), "%s가 있어야 한다" % tile_id)
