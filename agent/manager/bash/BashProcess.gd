class_name BashProcess
extends RefCounted

var id: String
var argv: PackedStringArray
var pid: int = -1
var thread := Thread.new()
var exit_code: int = OSUtils.EXIT_CODE_NOT_STARTED
var running: bool = true
var stop_requested: bool = false
# Output waiting for the next async_poll call. Access is guarded by mutex because the worker
# appends while the main thread may copy and clear the chunks.
var output_chunks: Array[String] = []
var output_bytes: int = 0
var mutex := Mutex.new()
