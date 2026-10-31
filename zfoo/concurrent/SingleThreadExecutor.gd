## Executes submitted callables sequentially on one dedicated worker thread.
## Stop all producers before calling [method shutdown], and do not submit afterward.
class_name SingleThreadExecutor
extends RefCounted

var task_queue: Array[Callable] = []
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var worker_thread: Thread = Thread.new()


func _init() -> void:
	var error := worker_thread.start(worker_loop)
	if error != OK:
		Log.error("SingleThreadExecutor start failed error:[{}]", error)
	else:
		Log.info("start single thread executor threadId:[{}]", worker_thread.get_id())
	pass


## Queues a valid task for FIFO execution.
func execute(task: Callable) -> void:
	if not task.is_valid():
		Log.error("SingleThreadExecutor rejected an invalid task")
		return
	mutex.lock()
	var wake_worker := task_queue.is_empty()
	task_queue.push_back(task)
	mutex.unlock()
	if wake_worker:
		semaphore.post()
	pass


## Completes all accepted tasks and waits for the worker to finish.
## Must be called outside the worker thread after all producers have stopped.
func shutdown() -> void:
	mutex.lock()
	task_queue.push_back(Callable())
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
		for task in tasks:
			if task == Callable():
				return
			task.call()
	pass
