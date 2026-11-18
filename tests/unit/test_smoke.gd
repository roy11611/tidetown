extends GutTest
## GUT가 tests/unit의 테스트를 찾아 실행하는지만 확인한다. 항상 통과한다.


func test_gut_runs() -> void:
	assert_true(true, "GUT가 이 테스트를 실행했다")
