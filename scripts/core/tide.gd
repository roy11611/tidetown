class_name Tide
extends RefCounted
## 물때 시계다. "밀물의 갯벌은 바다" 판정도 이 클래스 한 곳에만 둔다.
##
## 점수는 계산하지 않는다. 물때 점수는 Scoring.tide_scores가 계산하고 GameState가 호출한다.

enum Phase { LOW, HIGH }

signal phase_changed(new_phase: Phase)

var _phase: Phase
var _period_turns: int
var _turns_since_switch: int = 0


## 시작 물때와 전환 주기(턴 수)로 시계를 만든다. period_turns는 validate_island를 통과한 값(1 이상)이어야 한다.
func _init(initial: Phase, period_turns: int) -> void:
	_phase = initial
	_period_turns = period_turns


## 지금 물때를 돌려준다.
func get_phase() -> Phase:
	return _phase


## 다음 전환까지 남은 턴 수를 돌려준다. 1 이상 period_turns 이하다.
func turns_until_switch() -> int:
	return _period_turns - _turns_since_switch


## 턴 하나를 진행한다. 물때가 바뀌었으면 true. 물때를 바꾼 다음 phase_changed를 보낸다. 배치한 턴에만 부른다.
func advance_turn() -> bool:
	_turns_since_switch += 1
	if _turns_since_switch < _period_turns:
		return false
	_turns_since_switch = 0
	_phase = Phase.HIGH if _phase == Phase.LOW else Phase.LOW
	phase_changed.emit(_phase)
	return true


## 물때를 반영한 지형을 돌려준다. 밀물이면 갯벌을 바다로 바꾸고, 나머지는 그대로 돌려준다.
static func effective_cell(cell: BoardState.Cell, phase: Phase) -> BoardState.Cell:
	if phase == Phase.HIGH and cell == BoardState.Cell.FLAT:
		return BoardState.Cell.SEA
	return cell
