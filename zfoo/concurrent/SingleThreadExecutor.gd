## Executes submitted callables sequentially on one dedicated worker thread.
## Call [method shutdown] when the executor is no longer needed.
class_name SingleThreadExecutor
extends RefCounted

enum State {
	NEW,
	RUNNING,
	TERMINATED,
}

var task_queue: Array[Callable] = []
var mutex: Mutex = Mutex.new()
var semaphore: Semaphore = Semaphore.new()
var worker_thread: Thread = Thread.new()
var state: int = State.NEW
var worker_caller_id: int = 0


## Starts the worker thread. An executor can only be started once.
func start() -> Error:
	mutex.lock()
	if state != State.NEW:
		mutex.unlock()
		return ERR_ALREADY_IN_USE
	state = State.RUNNING
	var error := worker_thread.start(worker_loop)
	if error != OK:
		state = State.NEW
	mutex.unlock()
	return error


## Queues a task for FIFO execution. Returns false when not running.
func execute(task: Callable) -> bool:
	if not task.is_valid():
		return false
	mutex.lock()
	if state != State.RUNNING:
		mutex.unlock()
		return false
	var wake_worker := task_queue.is_empty()
	task_queue.push_back(task)
	mutex.unlock()
	if wake_worker:
		semaphore.post()
	return true


## Stops accepting tasks, completes the queue, and waits for the worker to finish.
func shutdown() -> void:
	mutex.lock()
	if state == State.NEW:
		state = State.TERMINATED
		mutex.unlock()
		return
	if state == State.RUNNING:
		state = State.TERMINATED
		semaphore.post()
	var caller_is_worker := worker_caller_id != 0 and OS.get_thread_caller_id() == worker_caller_id
	mutex.unlock()
	if worker_thread.is_started() and not caller_is_worker:
		worker_thread.wait_to_finish()
	pass

func worker_loop() -> void:
	mutex.lock()
	worker_caller_id = OS.get_thread_caller_id()
	mutex.unlock()
	while true:
		semaphore.wait()
		mutex.lock()
		var tasks := task_queue
		task_queue = []
		var terminated := state == State.TERMINATED
		mutex.unlock()
		for task in tasks:
			task.call()
		if terminated:
			return
	pass
