class_name Deck
extends RefCounted
## 타일의 줄이다. 위에서 뽑고 아래로 넣는다.
##
## 난수 생성기는 밖에서 받는다. Array.shuffle()은 전역 난수를 쓰므로 쓰지 않고,
## 받은 생성기로 뒤에서부터 randi_range로 자리를 바꿔 섞는다.


## 섞기에 쓸 난수 생성기를 받는다.
func _init(rng: RandomNumberGenerator) -> void:
	# TODO: 구현
	pass


## {"house": 3, ...} 구성을 타일 id 사전순으로 펼쳐 섞은 뒤 덱 아래에 넣는다.
func add_bundle(counts: Dictionary) -> void:
	# TODO: 구현
	pass


## 위에서 최대 count장을 꺼낸다.
func draw(count: int) -> Array[StringName]:
	# TODO: 구현
	return []


## 받은 순서대로 덱 아래에 넣는다.
func put_bottom(tiles: Array[StringName]) -> void:
	# TODO: 구현
	pass


## 덱에 남은 장수를 돌려준다.
func size() -> int:
	# TODO: 구현
	return 0


## 덱이 비었는지 돌려준다.
func is_empty() -> bool:
	# TODO: 구현
	return false


## 덱을 위에서 아래 순서로 복사해 돌려준다.
func contents() -> Array[StringName]:
	# TODO: 구현
	return []
