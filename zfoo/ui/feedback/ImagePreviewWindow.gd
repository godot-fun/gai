## Transient window hosting an [ImageViewer].
class_name ImagePreviewWindow
extends CommonWindow

const MAX_WIDTH_PERCENT: float = 80.0
const MAX_HEIGHT_PERCENT: float = 85.0
const GROUP_NAME: StringName = &"image_preview_window"

var image_viewer: ImageViewer


func _init() -> void:
	super()
	add_to_group(GROUP_NAME)
	image_viewer = ImageViewer.new()
	container.add_child(image_viewer)
	apply_theme()
	pass


func set_texture(texture: Texture2D) -> void:
	image_viewer.set_texture(texture)
	pass


## Size the window to the image aspect ratio within the configured maximum screen bounds.
func present_image() -> void:
	var texture := image_viewer.get_texture()
	if texture == null:
		return
	var viewport_size := gdf.gdf_node.get_tree().root.get_visible_rect().size
	var max_window_size := Vector2(
		viewport_size.x * MAX_WIDTH_PERCENT / 100.0,
		viewport_size.y * MAX_HEIGHT_PERCENT / 100.0,
	)
	var image_size := texture.get_size()
	var image_scale := minf(1.0, minf(max_window_size.x / image_size.x, max_window_size.y / image_size.y))
	var content_size := image_size * image_scale
	size = Vector2i(roundi(content_size.x), roundi(content_size.y))
	popup_centered()
	oversampling_override = DisplayScale.compute_ui_scale()
	pass


func apply_theme() -> void:
	super()
	if container != null:
		var background := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 0)
		container.add_theme_stylebox_override("panel", background)
	pass


####################################################################################################
# Static methods

## Whether an image preview window is currently open.
static func is_open() -> bool:
	return gdf.is_ready() and not gdf.gdf_node.get_tree().get_nodes_in_group(GROUP_NAME).is_empty()


## Load an image from a path, then open it through [method show_image].
static func show_window(path: String, i18n_title: String = "Image Preview") -> ImagePreviewWindow:
	var texture := await ResourceHelper.async_load(path) as Texture2D
	if texture == null:
		Log.error("failed to preview image path:[{}]", path)
		Alert.alert(I18n.t("Unable to load image"), Colors.error)
		return null
	var title := StringUtils.format("{} - {}", path.get_file(), I18n.t(i18n_title))
	return show_image(texture, title)


## Open a centered preview using an image resource that is already loaded.
static func show_image(texture: Texture2D, i18n_title: String = "Image Preview") -> ImagePreviewWindow:
	var window := create_window(i18n_title)
	window.set_texture(texture)
	window.present_image()
	return window


static func create_window(i18n_title: String) -> ImagePreviewWindow:
	var window := ImagePreviewWindow.new()
	window.title = I18n.t(i18n_title)
	gdf.gdf_node.add_child(window)
	return window
