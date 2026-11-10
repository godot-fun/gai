## Common contract for a file display hosted by [Editor].
class_name EditorView
extends Control

signal content_changed


func open_document(_document: EditorDocument) -> void:
	pass


func sync_document(_document: EditorDocument) -> void:
	pass


func focus_view() -> void:
	pass
