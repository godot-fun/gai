class_name TransformerStageEffect
extends Control

## Shared play-generation + tween bookkeeping for transformer stage effects.


var play_generation: int = 0
var stage_tweens: Array[Tween] = []


func begin_play() -> int:
	play_generation += 1
	return play_generation


func is_current(generation: int) -> bool:
	return generation == play_generation


func remember_tween(tween: Tween) -> Tween:
	stage_tweens.append(tween)
	return tween


func stop_animation() -> void:
	for tween in stage_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	stage_tweens.clear()
	pass
