class_name BashProcessResult
extends RefCounted

var status: String
var process_id: String
var exit_code: int
var output: String


func _init(_status: String, _process_id: String, _exit_code: int, _output: String) -> void:
	status = _status
	process_id = _process_id
	exit_code = _exit_code
	output = _output
	pass
