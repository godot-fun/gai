class_name EditorEvents
extends RefCounted

## UI coordination and completed filesystem changes for the workspace editor.

static var events := Events.new()


class Events:
	signal file_selected(path: String)
	signal file_deleted(path: String)
	pass
