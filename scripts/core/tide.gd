class_name Tide
extends RefCounted
## 물때 시계다. "밀물의 갯벌은 바다" 판정도 이 클래스 한 곳에만 둔다.
##
## 점수는 계산하지 않는다. 물때 점수는 Scoring.tide_scores가 계산하고 GameState가 호출한다.

enum Phase { LOW, HIGH }

signal phase_changed(new_phase: Phase)


## 시작 물때와 전환 주기(턴 수)로 시계를 만든다.
func _init(initial: Phase, period_turns: int) -> void:
	# TODO: 구현
	pass


## 지금 물때를 돌려준다.
func get_phase() -> Phase:
	# TODO: 구현
	return Phase.LOW


## 다음 전환까지 남은 턴 수를 돌려준다. 1 이상 period_turns 이하다.
func turns_until_switch() -> int:
	# TODO: 구현
	return 0


## 턴 하나를 진행한다. 물때가 바뀌었으면 true. 배치한 턴에만 부르고, 버리기에는 부르지 않는다.
func advance_turn() -> bool:
	# TODO: 구현
	return false


## 물때를 반영한 지형을 돌려준다. 밀물이면 갯벌을 바다로 바꾸고, 나머지는 그대로 돌려준다.
static func effective_cell(cell: BoardState.Cell, phase: Phase) -> BoardState.Cell:
	# TODO: 구현
	return BoardState.Cell.LAND
