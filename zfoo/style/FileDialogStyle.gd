class_name FileDialogStyle
extends Object

## Shared appearance for Godot's embedded file and folder picker. FileDialog builds much of its
## content internally, so this helper styles its public controls after the dialog is in the tree.
## Call [method apply] again after a theme or accent-color change.


## Apply the application's dialog, field, list, button, and scrollbar tokens to [param dialog].
## The ready-time second pass catches FileDialog controls created when the node enters the scene tree.
static func apply(dialog: FileDialog) -> void:
	configure_dismissal(dialog)
	apply_control_theme(dialog)
	style_dialog(dialog)
	refresh_controls(dialog)
	if not dialog.is_node_ready():
		dialog.ready.connect(func() -> void: refresh_controls(dialog), CONNECT_ONE_SHOT)
	pass


## FileDialog is reused by settings and workspace selection, so dismiss it by hiding rather than
## freeing it. `popup_window` makes an outside click emit `close_requested`, matching CommonWindow.
static func configure_dismissal(dialog: FileDialog) -> void:
	dialog.popup_window = true
	dialog.exclusive = false
	var close_callable := hide_dialog.bind(dialog)
	if not dialog.close_requested.is_connected(close_callable):
		dialog.close_requested.connect(close_callable)
	var input_callable := on_dialog_window_input.bind(dialog)
	if not dialog.window_input.is_connected(input_callable):
		dialog.window_input.connect(input_callable)
	pass


static func hide_dialog(dialog: FileDialog) -> void:
	dialog.hide()
	pass


static func on_dialog_window_input(event: InputEvent, dialog: FileDialog) -> void:
	if dialog.visible and event.is_action_pressed("ui_cancel"):
		dialog.hide()
		dialog.set_input_as_handled()
	pass


## Give FileDialog a calm hierarchy: the common accent frame leads into the same inset content
## surface used by CommonWindow, while dense controls use neutral reading surfaces.
static func apply_control_theme(dialog: FileDialog) -> void:
	var theme := Theme.new()
	theme.default_font = Fonts.regular()
	# FileDialog inherits its background panel from AcceptDialog, not from FileDialog itself.
	# Match CommonWindow's content surface, then keep dense lists and fields neutral for scanning.
	theme.set_stylebox("panel", "AcceptDialog", make_dialog_body_style())
	theme.set_stylebox("panel", "ItemList", make_file_list_style())
	theme.set_stylebox("panel", "ItemListSecondary", make_file_list_style())
	theme.set_stylebox("panel", "Panel", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "LineEdit", make_field_style())
	theme.set_stylebox("read_only", "LineEdit", make_field_style())
	var focus_field := make_field_style()
	focus_field.border_color = ThemeColor.accent_theme_color()
	theme.set_stylebox("focus", "LineEdit", focus_field)
	theme.set_color("font_color", "Label", ThemeColor.title_color)
	theme.set_color("font_color", "HeaderSmall", ThemeColor.title_color)
	theme.set_color("font_color", "Tree", ThemeColor.title_color)
	theme.set_color("font_color", "ItemList", ThemeColor.title_color)
	theme.set_color("font_color", "ItemListSecondary", ThemeColor.title_color)
	theme.set_color("font_color", "LineEdit", ThemeColor.title_color)
	dialog.theme = theme
	pass


static func style_dialog(dialog: FileDialog) -> void:
	dialog.transient = true
	CommonWindow.apply_window_theme(dialog, ThemeColor.accent_surface, ThemeColor.title_color, ThemeColor.title_color)
	var folder_color := Colors.info.lerp(ThemeColor.accent_theme_color(), 0.35)
	dialog.add_theme_color_override("folder_icon_color", folder_color)
	dialog.add_theme_color_override("file_icon_color", Color(Colors.secondary_text, 0.78))
	dialog.add_theme_color_override("file_disabled_color", Color(Colors.secondary_text, 0.50))
	pass


## Open a centered FileDialog at the same viewport-relative size convention as CommonWindow.
static func present_centered(dialog: FileDialog, width_percent: int = 60, height_percent: int = 70) -> void:
	dialog.size = CommonWindow.size_from_viewport_percent(width_percent, height_percent)
	dialog.popup_centered()
	dialog.oversampling_override = DisplayScale.compute_ui_scale()
	apply(dialog)
	pass


static func style_controls(root: Node) -> void:
	for child in root.get_children(true):
		style_control(child)
		style_controls(child)
	pass


## FileDialog creates its navigation, drive selector, and lists as internal children. Include those
## nodes, then restore the two dialog actions after generic button styling has run.
static func refresh_controls(dialog: FileDialog) -> void:
	style_controls(dialog)
	style_action_button(dialog.get_ok_button(), true)
	style_action_button(dialog.get_cancel_button(), false)
	pass


static func style_control(node: Node) -> void:
	if node is LineEdit:
		style_line_edit(node as LineEdit)
	elif node is OptionButton:
		style_path_option(node as OptionButton)
	elif node is PopupMenu:
		PopupMenuStyle.apply(node as PopupMenu)
	elif node is MenuButton:
		style_toolbar_button(node as MenuButton)
	elif node is Button:
		var button := node as Button
		if button.theme_type_variation == &"FlatButton":
			style_toolbar_button(button)
		else:
			style_button(button)
	elif node is Tree:
		style_tree(node as Tree)
	elif node is ItemList:
		style_item_list(node as ItemList)
	elif node is ScrollBar:
		ScrollBarStyle.apply(node as ScrollBar)
	elif node is Label:
		(node as Label).add_theme_color_override("font_color", ThemeColor.title_color)
	pass


static func style_action_button(button: Button, primary: bool) -> void:
	var normal := StyleBoxHelper.create_style_box_flat(
		ThemeColor.accent_theme_color() if primary else Colors.elevated_surface,
		ControlSize.radius_md, Margin.ma_3, Margin.ma_1,
		ThemeColor.accent_theme_color() if primary else Colors.subtle_border, ControlSize.border_xs
	)
	var hover := ButtonStyle.filled(normal, ThemeColor.promote(normal.bg_color, Colors.am_2))
	var pressed := ButtonStyle.filled(normal, ThemeColor.demote(normal.bg_color, Colors.am_2))
	ButtonStyle.apply(button, normal, hover, pressed)
	var text_color := ThemeColor.inset_surface if primary else ThemeColor.title_color
	ButtonStyle.apply_font_colors(button, text_color, text_color, text_color, Color(text_color, 0.5))
	pass


static func style_button(button: Button) -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_sm, Margin.ma_2, Margin.ma_1,
		Colors.subtle_border, ControlSize.border_xs)
	ButtonStyle.apply(button, normal,
		make_button_hover_style(normal),
		make_button_pressed_style(normal))
	ButtonStyle.apply_font_colors(button, ThemeColor.title_color, ThemeColor.title_color, ThemeColor.title_color)
	pass


## Compact toolbar controls remain visually quiet until hovered or pressed.
static func style_toolbar_button(button: Button) -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, ControlSize.radius_sm, Margin.ma_2, Margin.ma_1)
	ButtonStyle.apply(button, normal,
		make_button_hover_style(normal),
		make_button_pressed_style(normal))
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, ThemeColor.title_color, ThemeColor.title_color)
	ButtonStyle.apply_icon_colors(button, Colors.secondary_text, ThemeColor.title_color, ThemeColor.accent_theme_color())
	pass


## The drive selector shares the path field's surface and focus treatment, so the two controls
## read as one location bar instead of a dark dropdown beside a light text field.
static func style_path_option(option: OptionButton) -> void:
	var normal := make_field_style()
	var hover := make_button_hover_style(normal)
	var pressed := make_button_pressed_style(normal)
	ButtonStyle.apply(option, normal, hover, pressed)
	ButtonStyle.apply_font_colors(option, ThemeColor.title_color, ThemeColor.title_color, ThemeColor.title_color)
	ButtonStyle.apply_icon_colors(option, Colors.secondary_text, ThemeColor.title_color, ThemeColor.accent_theme_color())
	PopupMenuStyle.apply(option.get_popup())
	pass


static func style_line_edit(edit: LineEdit) -> void:
	edit.add_theme_color_override("font_color", ThemeColor.title_color)
	edit.add_theme_color_override("font_placeholder_color", ThemeColor.body_color)
	edit.add_theme_color_override("caret_color", ThemeColor.accent_theme_color())
	edit.add_theme_color_override("selection_color", ThemeColor.selection_color)
	var normal := make_field_style()
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = ThemeColor.accent_theme_color()
	edit.add_theme_stylebox_override("normal", normal)
	edit.add_theme_stylebox_override("focus", focus)
	edit.add_theme_stylebox_override("read_only", normal.duplicate())
	pass


static func style_tree(tree: Tree) -> void:
	tree.add_theme_color_override("font_color", ThemeColor.title_color)
	tree.add_theme_color_override("font_hovered_color", ThemeColor.title_color)
	tree.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	tree.add_theme_stylebox_override("panel", make_file_list_style())
	tree.add_theme_stylebox_override("selected", StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, ControlSize.radius_sm))
	tree.add_theme_stylebox_override("selected_focus", StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, ControlSize.radius_sm,
		0, 0, ThemeColor.accent_theme_color(), ControlSize.border_xs))
	pass


static func style_item_list(list: ItemList) -> void:
	list.add_theme_color_override("font_color", ThemeColor.title_color)
	list.add_theme_color_override("font_hovered_color", ThemeColor.title_color)
	list.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	# Godot otherwise resolves this compound state to its default white text.
	list.add_theme_color_override("font_hovered_selected_color", ThemeColor.title_color)
	list.add_theme_stylebox_override("panel", make_file_list_style())
	list.add_theme_stylebox_override("hovered", make_file_list_hover_style())
	var selected := make_file_list_selection_style(ThemeColor.alpha_theme_color(0.72))
	var selected_focus := make_file_list_selection_style(ThemeColor.accent_theme_color())
	list.add_theme_stylebox_override("selected", selected)
	list.add_theme_stylebox_override("selected_focus", selected_focus)
	list.add_theme_stylebox_override("hovered_selected", selected.duplicate())
	list.add_theme_stylebox_override("hovered_selected_focus", selected_focus.duplicate())
	pass


## A lightly lifted, misty version of the inset surface separates the lists without the stark
## pure-white card effect, while retaining the active theme hue.
static func make_file_list_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(file_list_surface(), ControlSize.radius_sm, Margin.ma_1, Margin.ma_1,
		Colors.subtle_border, ControlSize.border_xs)


static func file_list_surface() -> Color:
	return ThemeColor.inset_surface.lerp(Colors.surface, 0.25)


## A distinct, accent-tinted selection is readable over the file browser surface in either theme.
static func file_list_selection_surface() -> Color:
	return ThemeColor.inset_surface.lerp(ThemeColor.accent_theme_color(), Colors.am_5)


static func make_file_list_hover_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(
		ThemeColor.inset_surface.lerp(ThemeColor.accent_theme_color(), Colors.am_2),
		ControlSize.radius_sm, 0, 0, ThemeColor.alpha_theme_color(0.45), ControlSize.border_xs
	)


static func make_file_list_selection_style(border_color: Color) -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(file_list_selection_surface(), ControlSize.radius_sm, 0, 0,
		border_color, ControlSize.border_xs)


## Match BubbleContainer's header actions: a selected accent surface gives quiet, non-white hover
## feedback, and the pressed state increases contrast without changing the button's geometry.
static func make_button_hover_style(normal: StyleBoxFlat) -> StyleBoxFlat:
	return ButtonStyle.filled(normal, ThemeColor.selected_surface, ThemeColor.alpha_theme_color(0.85))


static func make_button_pressed_style(normal: StyleBoxFlat) -> StyleBoxFlat:
	return ButtonStyle.filled(normal, ThemeColor.promote(ThemeColor.selected_surface, Colors.am_2), ThemeColor.accent_theme_color())


static func make_dialog_body_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 0, Margin.ma_2, Margin.ma_2)


static func make_field_style() -> StyleBoxFlat:
	# The location controls belong to the file browser's innermost reading surface, rather than
	# floating as white cards above it in the light theme.
	return StyleBoxHelper.create_style_box_flat(file_list_surface(), ControlSize.radius_sm, Margin.ma_2, Margin.ma_1,
		Colors.subtle_border, ControlSize.border_xs)
