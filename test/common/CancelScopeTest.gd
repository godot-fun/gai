
func CancelScope_cancel_runs_all_tracked_callbacks_test() -> void:
	var scope := CancelScope.new()
	var hits: Array[int] = []
	scope.track(func() -> void: hits.append(1))
	scope.track(func() -> void: hits.append(2))
	assert(not scope.cancelled)
	scope.cancel()
	assert(scope.cancelled)
	assert(hits.size() == 2 and hits[0] == 1 and hits[1] == 2)
	pass


func CancelScope_track_after_cancel_runs_immediately_test() -> void:
	var scope := CancelScope.new()
	scope.cancel()
	var hits: Array[int] = []
	scope.track(func() -> void: hits.append(1))
	assert(hits.size() == 1)
	pass


func CancelScope_cancel_is_idempotent_test() -> void:
	var scope := CancelScope.new()
	var hits: Array[int] = []
	scope.track(func() -> void: hits.append(1))
	scope.cancel()
	scope.cancel()
	assert(scope.cancelled)
	assert(hits.size() == 1)
	pass


func CancelScope_cancel_without_callbacks_test() -> void:
	var scope := CancelScope.new()
	scope.cancel()
	assert(scope.cancelled)
	pass
