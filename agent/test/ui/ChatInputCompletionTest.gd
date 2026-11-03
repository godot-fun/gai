extends RefCounted

## Popup flow on a real [ChatInputField]: the engine only keeps its completion state on a live node, so
## these tests drive [method ChatInputCompletion.refresh_on_text_change] and [method
## ChatInputCompletion.confirm] the way the field's virtuals do on a keystroke and on Enter.


## A file row replaces the whole `@token` with the shared Markdown link and closes the list.
func file_row_accept_links_the_file_test() -> void:
	var root := make_scratch_workspace("accept")
	var field := make_field(root, "@not")
	var completion: ChatInputCompletion = field.completion
	completion.refresh_on_text_change()
	# `notes.md` at the root is offered before `docs/notes.md`, the shallower path winning.
	assert(completion.options.size() == 2)
	assert(completion.options[0]["insert_text"]
		== MarkdownHelper.format_file_as_markdown(root.path_join("notes.md")) + " ")
	assert(completion.is_popup_open())
	field.set_code_completion_selected_index(0)
	completion.confirm()
	assert(field.text == MarkdownHelper.format_file_as_markdown(root.path_join("notes.md")) + " ")
	assert(not completion.is_popup_open())
	field.free()
	pass


## A folder row stays open: `@docs/` is left under the caret so the next level lists right away.
func folder_row_accept_keeps_drilling_test() -> void:
	var root := make_scratch_workspace("drill")
	var field := make_field(root, "@do")
	var completion: ChatInputCompletion = field.completion
	completion.refresh_on_text_change()
	assert(completion.options[0]["insert_text"] == "@docs/")
	field.set_code_completion_selected_index(0)
	completion.confirm()
	assert(field.text == "@docs/")
	assert(completion.is_popup_open())
	assert(completion.options.size() == 1)
	assert(completion.options[0]["insert_text"] == MarkdownHelper.format_file_as_markdown(
		root.path_join("docs/notes.md")) + " ")
	field.free()
	pass


## The same accept path serves `/skill`: the whole command is replaced, not just the typed tail, and
## the trailing blank keeps the list closed.
func skill_row_accept_replaces_the_command_test() -> void:
	var field := make_field("", "/aud")
	var completion: ChatInputCompletion = field.completion
	completion.options = [{
		"kind": CodeEdit.KIND_PLAIN_TEXT,
		"display_text": "/audio-trim",
		"insert_text": "/audio-trim ",
		"font_color": Color.WHITE,
	}]
	field.update_code_completion_options(true)
	assert(completion.is_popup_open())
	field.set_code_completion_selected_index(0)
	completion.confirm()
	assert(field.text == "/audio-trim ")
	assert(not completion.is_popup_open())
	field.free()
	pass


## A caret parked in the middle of the mention still leaves one clean reference behind.
func accept_replaces_the_typed_tail_test() -> void:
	var root := make_scratch_workspace("tail")
	var field := make_field(root, "@do cs", 3)
	var completion: ChatInputCompletion = field.completion
	completion.refresh_on_text_change()
	assert(completion.options[0]["insert_text"] == "@docs/")
	field.set_code_completion_selected_index(0)
	completion.confirm()
	assert(field.text == "@docs/ cs")
	field.free()
	pass


func only_one_provider_claims_the_caret_test() -> void:
	var root := make_scratch_workspace("providers")
	var field := make_field(root, "/agent")
	var completion: ChatInputCompletion = field.completion
	assert(completion.active_provider() == completion.skill_completion)
	field.text = "@age"
	field.set_caret_column(4)
	assert(completion.active_provider() == completion.file_completion)
	field.text = "hello"
	field.set_caret_column(5)
	assert(completion.active_provider() == null)
	completion.refresh_on_text_change()
	assert(not completion.is_popup_open())
	assert(completion.options.is_empty())
	field.free()
	pass


func make_field(root: String, text: String, caret_column: int = -1) -> ChatInputField:
	var field := ChatInputField.new()
	var completion := ChatInputCompletion.new()
	completion.setup(field)
	completion.file_completion.root_override = root
	field.text = text
	field.set_caret_line(0, false)
	field.set_caret_column(text.length() if caret_column < 0 else caret_column, false)
	return field


func make_scratch_workspace(name: String) -> String:
	var root := FileUtils.normalize_path("user://chat_input_completion/" + name)
	DirAccess.make_dir_recursive_absolute(root.path_join("docs"))
	var file := FileAccess.open(root.path_join("notes.md"), FileAccess.WRITE)
	file.store_string("x")
	file.close()
	file = FileAccess.open(root.path_join("docs/notes.md"), FileAccess.WRITE)
	file.store_string("x")
	file.close()
	return root
