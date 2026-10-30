class_name ExecutorHelper
extends Object

static var single_thread_executor: SingleThreadExecutor = SingleThreadExecutor.new()


static func init() -> void:
	pass


## Queues a task on the shared single-thread executor.
static func execute(task: Callable) -> void:
	single_thread_executor.execute(task)
	pass


static func shutdown() -> void:
	single_thread_executor.shutdown()
	pass
