class_name ChatInputFile
extends RefCounted

## All file input paths for the chat field: window drops and platform clipboard files.

var input_bar: Control
var input_wrap: PanelContainer
var input_field: TextEdit
var prepare_drop: Callable
var focus_input: Callable
var restore_caret: Callable
var drop_focus_guard: bool = false


func setup(
	p_input_bar: Control,
	p_input_wrap: PanelContainer,
	p_input_field: TextEdit,
	p_prepare_drop: Callable,
	p_focus_input: Callable,
	p_restore_caret: Callable
) -> void:
	input_bar = p_input_bar
	input_wrap = p_input_wrap
	input_field = p_input_field
	prepare_drop = p_prepare_drop
	focus_input = p_focus_input
	restore_caret = p_restore_caret
	input_bar.get_window().files_dropped.connect(on_files_dropped)
	pass


func is_drop_focus_guarded() -> bool:
	return drop_focus_guard


func paste_clipboard_files() -> bool:
	if not input_field.editable:
		return false
	# Explorer can expose copied image files both as image pixels and as a FileDropList. Prefer the
	# file list so a mixed selection (for example, images plus videos) is pasted in full.
	var file_markdown := get_pasted_file_markdown()
	if not file_markdown.is_empty():
		input_field.insert_text_at_caret(file_markdown)
		return true
	var image_markdown := save_clipboard_image()
	if image_markdown.is_empty():
		return false
	input_field.insert_text_at_caret(image_markdown)
	return true


## Persists copied pixel data before inserting it, so the chat message references a stable file.
## A copied image file is not pixel data and continues through the platform file-list path below.
func save_clipboard_image() -> String:
	if not DisplayServer.clipboard_has_image():
		return StringUtils.EMPTY
	var image: Image = DisplayServer.clipboard_get_image()
	if image == null or image.is_empty():
		return StringUtils.EMPTY
	var cache_path := MarkdownRender.IMAGE_CACHE_DIR.path_join("clipboard_" + str(IdUtils.uuid()) + ".png")
	var error := MarkdownRender.save_cached_image(image, cache_path)
	if error != OK:
		Log.error("clipboard image cache failed path:[{}] err:[{}]", cache_path, error)
		return StringUtils.EMPTY
	return format_files_as_markdown(PackedStringArray([cache_path]))


func on_files_dropped(files: PackedStringArray) -> void:
	if not input_field.editable or files.is_empty() or not input_bar.is_inside_tree():
		return
	var markdown := format_files_as_markdown(files)
	if markdown.is_empty():
		return
	var mouse: Vector2 = input_bar.get_global_mouse_position()
	if not input_wrap.get_global_rect().has_point(mouse) and not input_bar.get_global_rect().has_point(mouse):
		return
	drop_focus_guard = true
	prepare_drop.call()
	insert_files.call_deferred(markdown)
	var guard_timer: SceneTreeTimer = input_bar.get_tree().create_timer(0.4)
	guard_timer.timeout.connect(clear_drop_focus_guard, CONNECT_ONE_SHOT)
	pass


func insert_files(markdown: String) -> void:
	if not input_field.editable or markdown.is_empty():
		return
	restore_caret.call()
	input_field.insert_text_at_caret(markdown)
	focus_input.call_deferred()
	var retry_timer: SceneTreeTimer = input_bar.get_tree().create_timer(0.05)
	retry_timer.timeout.connect(focus_input, CONNECT_ONE_SHOT)
	pass


func clear_drop_focus_guard() -> void:
	drop_focus_guard = false
	pass


## Godot exposes clipboard text and images, but not Explorer's CF_HDROP file list. Explorer may
## publish both FileDropList and text flavors for copied files, so always inspect FileDropList on
## Windows; an empty result lets ordinary text continue through the native paste path.
func get_pasted_file_markdown() -> String:
	if not OSUtils.is_windows():
		return StringUtils.EMPTY
	# Get-Clipboard passes FileDropList as one collection object on some PowerShell versions, causing
	# a direct pipeline to join all paths into one invalid path. Expand FullName before encoding items.
	# Base64 keeps Unicode paths intact; commas are safe delimiters because Base64 never contains them.
	var script := "$paths = (Get-Clipboard -Format FileDropList -ErrorAction SilentlyContinue).FullName; " \
		+ "$encoded = foreach ($path in $paths) { " \
		+ "[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($path)) }; " \
		+ "[Console]::Out.Write(($encoded -join ','))"
	var result := OSUtils.execute(PackedStringArray([
		"powershell.exe", "-NoProfile", "-NonInteractive", "-STA", "-Command", script
	]), false)
	if result.exit_code != 0:
		return StringUtils.EMPTY
	var files := PackedStringArray()
	var output := result.output.build_string().strip_edges()
	for path in decode_clipboard_paths(output):
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			files.append(path)
	return format_files_as_markdown(files)


func decode_clipboard_paths(output: String) -> PackedStringArray:
	var paths := PackedStringArray()
	for encoded_path in output.split(",", false):
		paths.append(Marshalls.base64_to_utf8(encoded_path.strip_edges()))
	return paths


func format_files_as_markdown(files: PackedStringArray) -> String:
	var build := StringBuilder.new()
	for file in files:
		if file.ends_with(".uid"):
			continue
		build.append("    " + MarkdownHelper.format_file_as_markdown(file) + "    ")
	return build.build_string()
