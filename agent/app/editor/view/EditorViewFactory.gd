## Creates the display appropriate for an editor document.
class_name EditorViewFactory
extends Object


static func create(document: EditorDocument) -> EditorView:
	match document.kind:
		EditorDocument.Kind.TEXT:
			return EditorTextView.new()
		EditorDocument.Kind.IMAGE:
			return EditorImageView.new()
	return null
