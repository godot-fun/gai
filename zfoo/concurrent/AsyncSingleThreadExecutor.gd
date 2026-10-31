## Executes submitted callables sequentially on one dedicated worker thread.
## Use [code]await async_execute(task)[/code] to wait without blocking the main thread
## and receive the value returned by the task.
class_name AsyncSingleThreadExecutor
extends RefCounted

var task_queue: Array[AsyncTask] = []
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var worker_thread: Thread = Thread.new()


func _init() -> void:
	var error := worker_thread.start(worker_loop)
	if error != OK:
		Log.error("AsyncSingleThreadExecutor start failed error:[{}]", error)
	else:
		Log.info("start async single thread executor threadId:[{}]", worker_thread.get_id())
	pass


## Queues a valid task for FIFO execution, waits asynchronously, and returns its result.
## Call this method from the main thread so waiting can advance on process frames.
func async_execute(task: Callable) -> Variant:
	if not task.is_valid():
		Log.error("AsyncSingleThreadExecutor rejected an invalid task")
		return null
	var async_task := AsyncTask.new(task)
	mutex.lock()
	var wake_worker := task_queue.is_empty()
	task_queue.push_back(async_task)
	mutex.unlock()
	if wake_worker:
		semaphore.post()
	while not async_task.try_wait_for_completion():
		await Engine.get_main_loop().process_frame
	return async_task.get_result()


## Completes all accepted tasks and waits for the worker to finish.
## Must be called outside the worker thread after all producers have stopped.
func shutdown() -> void:
	mutex.lock()
	task_queue.push_back(null)
	mutex.unlock()
	semaphore.post()
	if worker_thread.is_started():
		worker_thread.wait_to_finish()
	pass


func worker_loop() -> void:
	while true:
		semaphore.wait()
		mutex.lock()
		var tasks := task_queue
		task_queue = []
		mutex.unlock()
		for async_task in tasks:
			if async_task == null:
				return
			async_task.execute()
	pass


class AsyncTask:
	extends RefCounted

	var task: Callable
	var result: Variant
	var completion_semaphore: Semaphore = Semaphore.new()


	func _init(callable: Callable) -> void:
		task = callable
		pass


	func execute() -> void:
		result = task.call()
		completion_semaphore.post()
		pass


	func try_wait_for_completion() -> bool:
		return completion_semaphore.try_wait()


	func get_result() -> Variant:
		return result
