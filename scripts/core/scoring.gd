class_name Scoring
extends RefCounted
## 점수를 계산한다. 상태가 없고 보드를 바꾸지 않는다.


## tile_id를 pos에 놓을 때의 배치 점수를 놓기 전의 보드로 계산한다. 화면의 예상 점수도 이 함수를 쓴다.
static func placement_score(board: BoardState, defs: TileDefs, phase: Tide.Phase, tile_id: StringName, pos: Vector2i) -> int:
	# TODO: 구현
	return 0


## 바뀐 뒤의 물때를 받아, 그 이벤트의 규칙이 있는 건물마다 점수를 돌려준다. 0점인 건물도 넣는다.
static func tide_scores(board: BoardState, defs: TileDefs, new_phase: Tide.Phase) -> Dictionary[Vector2i, int]:
	# TODO: 구현
	return {}


## 점수 규칙 하나가 pos에서 주는 점수를 돌려준다.
static func rule_points(board: BoardState, phase: Tide.Phase, rule: TileDefs.ScoreRule, pos: Vector2i) -> int:
	# TODO: 구현
	return 0
