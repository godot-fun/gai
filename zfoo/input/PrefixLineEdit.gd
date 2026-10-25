class_name PrefixLineEdit
extends PanelContainer

## Card-styled [LineEdit] with a prefix SVG icon and optional built-in clear button.

var line_edit: LineEdit
var prefix_icon: TextureRect

var shell_normal: StyleBoxFlat
var shell_hover: StyleBoxFlat
var shell_focus: StyleBoxFlat
var shell_hovered: bool = false
var prefix_icon_path: String = ""


func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, ControlSize.lg)
	build_children()
	pass


func _ready() -> void:
	focus_at_end.call_deferred()
	pass


func build_children() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", Margin.ma_2)
	add_child(row)
	prefix_icon = TextureRect.new()
	prefix_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(prefix_icon)
	line_edit = LineEdit.new()
	line_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line_edit.clear_button_enabled = true
	line_edit.focus_entered.connect(refresh_shell_style)
	line_edit.focus_exited.connect(refresh_shell_style)
	line_edit.mouse_entered.connect(on_line_edit_mouse_entered)
	line_edit.mouse_exited.connect(on_line_edit_mouse_exited)
	row.add_child(line_edit)
	pass


func apply_prefix(prefix_icon_res: String) -> void:
	prefix_icon_path = prefix_icon_res
	refresh_prefix_icon()
	pass


## [param base_style] defaults to the shared card field look used in search and settings.
func apply_theme_style(base_style: StyleBoxFlat = null) -> void:
	shell_normal = base_style if base_style != null else make_default_field_style()
	shell_hover = shell_normal.duplicate() as StyleBoxFlat
	shell_hover.border_color = ThemeColor.accent_theme_color()
	shell_focus = shell_hover.duplicate() as StyleBoxFlat
	shell_focus.set_border_width_all(ControlSize.border_sm)
	line_edit.add_theme_color_override("font_color", Colors.primary_text)
	line_edit.add_theme_color_override("font_placeholder_color", ThemeColor.demote(Colors.secondary_text, Weights.w_2))
	line_edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	line_edit.add_theme_color_override("font_selected_color", Colors.primary_text)
	line_edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	line_edit.caret_blink = true
	var empty := StyleBoxEmpty.new()
	line_edit.add_theme_stylebox_override("normal", empty)
	line_edit.add_theme_stylebox_override("hover", empty)
	line_edit.add_theme_stylebox_override("focus", empty)
	line_edit.add_theme_stylebox_override("read_only", empty)
	if line_edit.clear_button_enabled:
		line_edit.add_theme_color_override("clear_button_color", Colors.secondary_text)
		line_edit.add_theme_color_override("clear_button_color_pressed", ThemeColor.accent_theme_color())
	refresh_prefix_icon()
	refresh_shell_style()
	pass


func refresh_prefix_icon() -> void:
	if shell_normal == null:
		return
	if StringUtils.is_not_blank(prefix_icon_path):
		prefix_icon.texture = null
		load_prefix_icon(prefix_icon_path)
		prefix_icon.visible = true
	else:
		prefix_icon.texture = null
		prefix_icon.visible = false
	pass


static func make_default_field_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, 7, Margin.ma_2, Margin.ma_1,
		Color(ThemeColor.title_color, 0.10), ControlSize.border_xs)


func load_prefix_icon(path: String) -> void:
	prefix_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prefix_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	prefix_icon.custom_minimum_size = ControlSize.square(ControlSize.xs)
	var texture: Texture2D = await ResourceHelper.async_load(path)
	if texture == null:
		return
	prefix_icon.texture = texture
	prefix_icon.self_modulate = Colors.secondary_text
	pass


func on_line_edit_mouse_entered() -> void:
	shell_hovered = true
	refresh_shell_style()
	pass


func on_line_edit_mouse_exited() -> void:
	shell_hovered = false
	refresh_shell_style()
	pass


func refresh_shell_style() -> void:
	if shell_normal == null:
		return
	if line_edit.has_focus():
		add_theme_stylebox_override("panel", shell_focus)
	elif shell_hovered:
		add_theme_stylebox_override("panel", shell_hover)
	else:
		add_theme_stylebox_override("panel", shell_normal)
	pass


func focus_at_end() -> void:
	line_edit.grab_focus()
	line_edit.deselect()
	line_edit.caret_column = line_edit.text.length()
	pass
