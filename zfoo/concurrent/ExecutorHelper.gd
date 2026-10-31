class_name ExecutorHelper
extends Object

static var single_thread_executor: SingleThreadExecutor = SingleThreadExecutor.new()
static var async_single_thread_executor: AsyncSingleThreadExecutor = AsyncSingleThreadExecutor.new()


static func init() -> void:
	pass


## Queues a task on the shared single-thread executor.
static func execute(task: Callable) -> void:
	single_thread_executor.execute(task)
	pass


## Queues a task on the shared async single-thread executor and returns its result when complete.
static func async_execute(task: Callable) -> Variant:
	return await async_single_thread_executor.async_execute(task)


static func shutdown() -> void:
	single_thread_executor.shutdown()
	async_single_thread_executor.shutdown()
	pass
