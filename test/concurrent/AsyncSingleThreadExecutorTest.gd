var execution_order: Array[int] = []
var execution_thread_ids: Array[int] = []


func async_single_thread_executor_result_test() -> void:
	execution_order.clear()
	execution_thread_ids.clear()
	var executor := AsyncSingleThreadExecutor.new()
	var first_result: Variant = await executor.async_execute(Callable(self, "record_and_double").bind(21))
	var second_result: Variant = await executor.async_execute(Callable(self, "record_and_double").bind(7))
	executor.shutdown()
	assert(first_result == 42)
	assert(second_result == 14)
	assert(execution_order == [21, 7])
	assert(execution_thread_ids.size() == 2)
	assert(execution_thread_ids[0] != OS.get_thread_caller_id())
	assert(execution_thread_ids[0] == execution_thread_ids[1])
	pass


func async_single_thread_executor_fifo_test() -> void:
	execution_order.clear()
	var executor := AsyncSingleThreadExecutor.new()
	var results: Array = []
	results.resize(20)
	results.fill(null)
	for value in 20:
		gdf.callable_deferred(Callable(self, "record_result_async").bind(executor, value, results))
	while results.has(null):
		await Engine.get_main_loop().process_frame
	for value in 20:
		assert(results[value] == value * 2)
	executor.shutdown()
	assert(execution_order == Array(range(20)))
	pass


func executor_helper_async_execute_test() -> void:
	var result: Variant = await ExecutorHelper.async_execute(func() -> String: return "completed")
	assert(result == "completed")
	pass


func executor_helper_async_execute_pooled_test() -> void:
	var caller_thread_id := OS.get_thread_caller_id()
	var result: Dictionary = await ExecutorHelper.async_execute_pooled(func() -> Dictionary:
		return {"value": "completed", "thread_id": OS.get_thread_caller_id()}
	)
	assert(result["value"] == "completed")
	assert(result["thread_id"] != caller_thread_id)
	pass


func record_and_double(value: int) -> int:
	execution_order.push_back(value)
	execution_thread_ids.push_back(OS.get_thread_caller_id())
	return value * 2


func record_result_async(executor: AsyncSingleThreadExecutor, value: int, results: Array) -> void:
	results[value] = await executor.async_execute(Callable(self, "record_and_double").bind(value))
	pass
