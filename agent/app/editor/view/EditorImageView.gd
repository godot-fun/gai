## Read-only image-file view backed by [ImageViewer].
class_name EditorImageView
extends EditorView

var image_viewer: ImageViewer


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	image_viewer = ImageViewer.new()
	add_child(image_viewer)
	image_viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pass


func open_document(document: EditorDocument) -> void:
	var texture := await ResourceHelper.async_load(document.path) as Texture2D
	if texture == null:
		Log.error("failed to display editor image path:[{}]", document.path)
		Alert.alert(I18n.t("Unable to load image"), Colors.error)
		return
	image_viewer.set_texture(texture)
	pass
