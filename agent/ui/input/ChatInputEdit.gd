class_name ChatInputEdit
extends CodeEdit

## The composer's editor. [CodeEdit]'s completion list is driven entirely by [member completion]: the
## three virtuals below are the only way to stop the engine from filtering rows with its own word rules
## and from replacing just the trailing word instead of the whole `/skill` or `@file` token.

var completion: ChatInputCompletion


func _request_code_completion(_force: bool) -> void:
	if completion == null:
		return
	await completion.async_refresh()
	pass


func _filter_code_completion_candidates(_candidates: Array[Dictionary]) -> Array[Dictionary]:
	if completion != null:
		return completion.filter_candidates()
	return []


func _confirm_code_completion(_replace: bool) -> void:
	if completion == null:
		return
	await completion.confirm()
	pass
