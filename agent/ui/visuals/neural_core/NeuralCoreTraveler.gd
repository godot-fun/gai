class_name NeuralCoreTraveler
extends RefCounted

## A dot gliding along a tendril curve (0..1 along the bezier).

var tendril_index: int
var progress: float
var speed: float


func _init(p_tendril_index: int, p_speed: float) -> void:
	tendril_index = p_tendril_index
	progress = 0.0
	speed = p_speed
	pass
