class_name RuntimeState
extends RefCounted


var stop_requested: bool = false
var step_entry: ChatEntry = null

var cancel_scope: CancelScope = CancelScope.new()
