class_name ExecutorHelper
extends Object

static var single_thread_executor: SingleThreadExecutor = SingleThreadExecutor.new()


static func init() -> void:
	pass

static func shutdown() -> void:
	single_thread_executor.shutdown()
	pass