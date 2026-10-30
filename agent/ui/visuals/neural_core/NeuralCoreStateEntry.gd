class_name NeuralCoreStateEntry
extends RefCounted

## One line in the top-right STATE LOG (label + wall-clock time).

var label: String
var clock: String


func _init(p_label: String, p_clock: String) -> void:
	label = p_label
	clock = p_clock
	pass
