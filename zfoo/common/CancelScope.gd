class_name CancelScope
extends RefCounted

## Shared cancellation scope for in-flight async work.
##
## Async operations (HTTP requests, subprocesses) register a cancel callback through [method track];
## a single [method cancel] call stops everything registered so far. The owner decides the lifetime —
## the agent keeps one scope per run, so stopping one session never touches another session's work.
##
## Mirrors the `CancelScope` of AnyIO / Trio. [method track] may run on a worker thread (see
## [method OSUtils.async_execute]), so the registry is guarded by a mutex.

## True once [method cancel] has run; later [method track] calls fire immediately.
var cancelled: bool = false

var cancels: Array[Callable] = []
var mutex := Mutex.new()


## Registers [param cancel_cb] to run on cancellation; when this scope is already cancelled the
## callback runs right away. A registered callback is never dropped.
func track(cancel_cb: Callable) -> void:
	mutex.lock()
	if not cancelled:
		cancels.append(cancel_cb)
		mutex.unlock()
		return
	mutex.unlock()
	cancel_cb.call()
	pass


## Cancels every registered callback once; later [method track] calls fire immediately and repeat
## [method cancel] calls are no-ops.
func cancel() -> void:
	mutex.lock()
	if cancelled:
		mutex.unlock()
		return
	cancelled = true
	var callbacks := cancels.duplicate()
	cancels.clear()
	mutex.unlock()
	for cancel_cb: Callable in callbacks:
		cancel_cb.call()
	pass
