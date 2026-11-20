extends GutTest
## Tide: 물때 시계와 물때를 반영한 지형 (docs/architecture.md 3.3, docs/rules.md 3장)

const LOW := Tide.Phase.LOW
const HIGH := Tide.Phase.HIGH
const LAND := BoardState.Cell.LAND
const FLAT := BoardState.Cell.FLAT
const SEA := BoardState.Cell.SEA


# --- 물때 시계 ---

func test_starts_with_initial_phase() -> void:
	assert_eq(Tide.new(LOW, 4).get_phase(), LOW)
	assert_eq(Tide.new(HIGH, 4).get_phase(), HIGH)


func test_phase_follows_rules_timetable() -> void:
	# docs/rules.md 8장 예시 8: 1–4번째 턴 썰물, 5–8번째 턴 밀물, 9–12번째 턴 썰물.
	# 물때는 4번째, 8번째, 12번째 턴의 배치가 끝날 때 바뀐다.
	var tide := Tide.new(LOW, 4)
	var phases: Array[Tide.Phase] = []
	var switched_after: Array[int] = []
	for turn: int in range(1, 13):
		phases.append(tide.get_phase())
		if tide.advance_turn():
			switched_after.append(turn)
	var expected_phases: Array[Tide.Phase] = [LOW, LOW, LOW, LOW, HIGH, HIGH, HIGH, HIGH, LOW, LOW, LOW, LOW]
	var expected_switches: Array[int] = [4, 8, 12]
	assert_eq(phases, expected_phases)
	assert_eq(switched_after, expected_switches)


func test_turns_until_switch_counts_down_and_resets() -> void:
	var tide := Tide.new(LOW, 4)
	var counts: Array[int] = []
	for i: int in 8:
		counts.append(tide.turns_until_switch())
		tide.advance_turn()
	var expected: Array[int] = [4, 3, 2, 1, 4, 3, 2, 1]
	assert_eq(counts, expected)


func test_period_and_initial_phase_come_from_constructor() -> void:
	var tide := Tide.new(HIGH, 3)
	var phases: Array[Tide.Phase] = []
	for i: int in 6:
		phases.append(tide.get_phase())
		tide.advance_turn()
	var expected: Array[Tide.Phase] = [HIGH, HIGH, HIGH, LOW, LOW, LOW]
	assert_eq(phases, expected)
	assert_eq(tide.get_phase(), HIGH)


func test_period_1_switches_every_turn() -> void:
	var tide := Tide.new(LOW, 1)
	assert_eq(tide.turns_until_switch(), 1)
	assert_true(tide.advance_turn())
	assert_eq(tide.get_phase(), HIGH)
	assert_eq(tide.turns_until_switch(), 1)
	assert_true(tide.advance_turn())
	assert_eq(tide.get_phase(), LOW)


# --- signal ---

func test_phase_changed_is_emitted_only_on_switch() -> void:
	var tide := Tide.new(LOW, 4)
	watch_signals(tide)
	for i: int in 3:
		tide.advance_turn()
	assert_signal_not_emitted(tide, "phase_changed")
	tide.advance_turn()
	assert_signal_emit_count(tide, "phase_changed", 1)
	assert_signal_emitted_with_parameters(tide, "phase_changed", [HIGH])


func test_phase_is_already_new_when_phase_changed_is_emitted() -> void:
	var tide := Tide.new(LOW, 1)
	var seen: Array = []
	var record := func(_new_phase: Tide.Phase) -> void: seen.append(tide.get_phase())
	tide.phase_changed.connect(record)
	tide.advance_turn()
	tide.phase_changed.disconnect(record)
	assert_eq(seen, [HIGH])


# --- 물때를 반영한 지형 (docs/rules.md 3장의 표) ---

func test_effective_cell_at_low_tide_keeps_terrain() -> void:
	assert_eq(Tide.effective_cell(LAND, LOW), LAND)
	assert_eq(Tide.effective_cell(FLAT, LOW), FLAT)
	assert_eq(Tide.effective_cell(SEA, LOW), SEA)


func test_effective_cell_at_high_tide_turns_flat_into_sea() -> void:
	assert_eq(Tide.effective_cell(LAND, HIGH), LAND)
	assert_eq(Tide.effective_cell(FLAT, HIGH), SEA)
	assert_eq(Tide.effective_cell(SEA, HIGH), SEA)
