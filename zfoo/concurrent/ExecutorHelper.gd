class_name ExecutorHelper
extends Object

static var single_thread_executor: SingleThreadExecutor = SingleThreadExecutor.new()
static var async_single_thread_executor: AsyncSingleThreadExecutor = AsyncSingleThreadExecutor.new()


static func init() -> void:
	pass


## Queues a task on the shared single-thread executor.
## Tasks submitted through this method execute sequentially in FIFO submission order.
## This queue is separate from [method async_execute], so ordering is not coordinated between the two methods.
static func execute(task: Callable) -> void:
	single_thread_executor.execute(task)
	pass


## Queues a task on the shared async single-thread executor and returns its result when complete.
## Tasks submitted through this method execute sequentially in FIFO submission order.
## This queue is separate from [method execute], so ordering is not coordinated between the two methods.
static func async_execute(task: Callable) -> Variant:
	return await async_single_thread_executor.async_execute(task)


static func shutdown() -> void:
	single_thread_executor.shutdown()
	async_single_thread_executor.shutdown()
	pass


# ----------------------------------------------------------------------------------------------------------------------
## Queues a task on Godot's shared worker thread pool.
## Pooled tasks may run concurrently; their start and completion order are not guaranteed.
static func execute_pooled(task: Callable) -> void:
	if not task.is_valid():
		Log.error("ExecutorHelper rejected an invalid pooled task")
		return
	WorkerThreadPool.add_task(task)
	pass


## Queues a task on Godot's shared worker thread pool and returns its result when complete.
## Pooled tasks may run concurrently; their start and completion order are not guaranteed.
## Call this method from the main thread so waiting can advance on process frames.
static func async_execute_pooled(task: Callable) -> Variant:
	if not task.is_valid():
		Log.error("ExecutorHelper rejected an invalid async pooled task")
		return null
	var pooled_task := PooledTask.new(task)
	var task_id := WorkerThreadPool.add_task(pooled_task.execute)
	while not WorkerThreadPool.is_task_completed(task_id):
		await Engine.get_main_loop().process_frame
	var error := WorkerThreadPool.wait_for_task_completion(task_id)
	if error != OK:
		Log.error("ExecutorHelper pooled task failed error:[{}]", error)
		return null
	return pooled_task.result


class PooledTask:
	extends RefCounted

	var task: Callable
	var result: Variant


	func _init(callable: Callable) -> void:
		task = callable
		pass


	func execute() -> void:
		result = task.call()
		pass
