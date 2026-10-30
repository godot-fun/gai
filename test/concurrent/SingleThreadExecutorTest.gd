const PRODUCER_COUNT: int = 4
const TASKS_PER_PRODUCER: int = 250

var execution_order: Array[int] = []
var execution_thread_ids: Array[int] = []
var completed_task_count: int = 0


func single_thread_executor_fifo_test() -> void:
	execution_order.clear()
	execution_thread_ids.clear()
	var executor := SingleThreadExecutor.new()
	for value in 100:
		executor.execute(Callable(self, "record_execution").bind(value))
	executor.shutdown()
	assert(execution_order.size() == 100)
	for value in 100:
		assert(execution_order[value] == value)
	assert(not execution_thread_ids.is_empty())
	var worker_thread_id: int = execution_thread_ids.front()
	assert(worker_thread_id != OS.get_thread_caller_id())
	for thread_id in execution_thread_ids:
		assert(thread_id == worker_thread_id)
	pass


func single_thread_executor_parallel_submission_test() -> void:
	completed_task_count = 0
	var executor := SingleThreadExecutor.new()
	var producers: Array[Thread] = []
	for _producer_index in PRODUCER_COUNT:
		var producer := Thread.new()
		assert(producer.start(Callable(self, "submit_tasks").bind(executor)) == OK)
		producers.push_back(producer)
	for producer in producers:
		producer.wait_to_finish()
	executor.shutdown()
	assert(completed_task_count == PRODUCER_COUNT * TASKS_PER_PRODUCER)
	pass


func record_execution(value: int) -> void:
	execution_order.push_back(value)
	execution_thread_ids.push_back(OS.get_thread_caller_id())
	pass


func submit_tasks(executor: SingleThreadExecutor) -> void:
	for _task_index in TASKS_PER_PRODUCER:
		executor.execute(Callable(self, "increment_completed_task_count"))
	pass


func increment_completed_task_count() -> void:
	completed_task_count += 1
	pass
