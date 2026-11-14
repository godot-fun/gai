extends RefCounted

## Attachment rows share the composer's Markdown shapes: a folder keeps the folder link the `@` list
## produces, everything else stays the file link, and Explorer's `.uid` / `.import` sidecars are skipped.
## The folder-or-file decision itself lives in [method MarkdownHelper.format_path_as_markdown] and is
## tested with the other formatters in MarkdownParserTest.


func join_markdown_for_attachments_test() -> void:
	var root := make_attachment_workspace()
	var attachment := ChatInputAttachment.new()
	var field := TextEdit.new()
	attachment.input_field = field
	var folder := root.path_join("docs")
	var file := root.path_join("docs/notes.md")
	assert(attachment.join_markdown_for_attachments(PackedStringArray([folder]))
		== MarkdownHelper.format_path_as_markdown(folder) + "    ")
	# The `.uid` sidecar Explorer lists next to the file is dropped, and existing composer text keeps a
	# separator on both sides.
	var files := PackedStringArray([folder, file, file + ".uid"])
	assert(attachment.join_markdown_for_attachments(files) == (
		MarkdownHelper.format_path_as_markdown(folder) + "    "
		+ MarkdownHelper.format_path_as_markdown(file) + "    "))
	field.text = "hi"
	assert(attachment.join_markdown_for_attachments(PackedStringArray([file])).begins_with("    "))
	field.free()
	pass


func make_attachment_workspace() -> String:
	var root := FileUtils.normalize_path("user://chat_input_attachment_test")
	DirAccess.make_dir_recursive_absolute(root.path_join("docs"))
	FileUtils.write_string_to_file(root.path_join("docs/notes.md"), "x")
	return root
