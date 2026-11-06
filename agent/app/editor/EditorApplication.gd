class_name EditorApplication
extends RefCounted

## One discovered workspace editor and the metadata needed to display and launch it.

var id: String
var label: String
var executable: String
var arguments: PackedStringArray
var icon_path: String


func _init(p_id: String, p_label: String, p_executable: String, p_icon_path: String,
		p_arguments: PackedStringArray = PackedStringArray()) -> void:
	id = p_id
	label = p_label
	executable = p_executable
	icon_path = p_icon_path
	arguments = p_arguments
	pass
