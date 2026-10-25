class_name FileDialogStyle
extends Object

## Shared appearance for Godot's embedded file and folder picker. FileDialog builds much of its
## content internally, so this helper styles its public controls after the dialog is in the tree.
## Call [method apply] again after a theme or accent-color change.


## Apply the application's dialog, field, list, button, and scrollbar tokens to [param dialog].
## [param label_texts] maps Godot's built-in English captions to caller-resolved display text.
## Its keys must be the original strings exposed by FileDialog (for example, [code]"Path:"[/code],
## [code]"View items as a list."[/code], or [code]"Sort by Name (Ascending)"[/code]); values are
## applied to matching labels, control tooltips, and PopupMenu entries. Missing keys preserve
## Godot's original text. Callers own translation and pass a fresh map when the locale changes,
## keeping this reusable style helper independent of I18n. The ready-time second pass catches
## FileDialog controls created when the node enters the scene tree.
static func apply(dialog: FileDialog, label_texts: Dictionary[String, String] = {}) -> void:
	apply_close(dialog)
	apply_control_theme(dialog)
	apply_dialog_style(dialog)
	apply_control_styles(dialog, label_texts)
	if not dialog.is_node_ready():
		dialog.ready.connect(func() -> void: apply_control_styles(dialog, label_texts), CONNECT_ONE_SHOT)
	pass


## FileDialog is reused by settings and workspace selection, so dismiss it by hiding rather than
## freeing it. `popup_window` makes an outside click emit `close_requested`, matching CommonWindow.
static func apply_close(dialog: FileDialog) -> void:
	dialog.exclusive = true
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
	var file_list := make_file_list_style()
	var field := file_dialog_field_style()
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = ThemeColor.accent_theme_color()
	# FileDialog inherits its background panel from AcceptDialog, not from FileDialog itself.
	theme.set_stylebox("panel", "AcceptDialog", make_dialog_body_style())
	theme.set_stylebox("panel", "ItemList", file_list)
	theme.set_stylebox("panel", "ItemListSecondary", file_list)
	theme.set_stylebox("panel", "Panel", StyleBoxEmpty.new())
	theme.set_stylebox("panel", "PanelContainer", StyleBoxEmpty.new())
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("read_only", "LineEdit", field.duplicate())
	theme.set_stylebox("focus", "LineEdit", field_focus)
	for type_name: StringName in [&"Label", &"HeaderSmall", &"Tree", &"ItemList", &"ItemListSecondary", &"LineEdit"]:
		theme.set_color("font_color", type_name, ThemeColor.title_color)
	dialog.theme = theme
	pass


static func apply_dialog_style(dialog: FileDialog) -> void:
	dialog.transient = true
	CommonWindow.apply_window_theme(dialog, ThemeColor.accent_surface, ThemeColor.title_color, ThemeColor.title_color)
	var folder_color := Colors.info.lerp(ThemeColor.accent_theme_color(), 0.35)
	dialog.add_theme_color_override("folder_icon_color", folder_color)
	dialog.add_theme_color_override("file_icon_color", Color(Colors.secondary_text, 0.78))
	dialog.add_theme_color_override("file_disabled_color", Color(Colors.secondary_text, Weights.w_8))
	pass


## Open a centered FileDialog at the same viewport-relative size convention as CommonWindow.
static func present_centered(dialog: FileDialog, width_percent: int = 60, height_percent: int = 70, label_texts: Dictionary[String, String] = {}) -> void:
	dialog.size = CommonWindow.size_from_viewport_percent(width_percent, height_percent)
	dialog.popup_centered()
	dialog.oversampling_override = DisplayScale.compute_ui_scale()
	apply(dialog, label_texts)
	pass


static func style_controls(root: Node, label_texts: Dictionary[String, String]) -> void:
	for child in root.get_children(true):
		style_control(child, label_texts)
		style_controls(child, label_texts)
	pass


## FileDialog creates its navigation, drive selector, and lists as internal children. Include those
## nodes, then restore the two dialog actions after generic button styling has run.
static func apply_control_styles(dialog: FileDialog, label_texts: Dictionary[String, String]) -> void:
	style_controls(dialog, label_texts)
	style_confirm_button(dialog.get_ok_button())
	style_cancel_button(dialog.get_cancel_button())
	pass


static func style_control(node: Node, label_texts: Dictionary[String, String] = {}) -> void:
	if node is Control:
		apply_tooltip_text(node as Control, label_texts)
	if node is LineEdit:
		var path_edit := node as LineEdit
		LineEditStyle.apply(path_edit, file_dialog_field_style(), ThemeColor.title_color, ThemeColor.demote(Colors.secondary_text, Weights.w_2),
			ThemeColor.selection_color, Margin.ma_0)
		path_edit.custom_minimum_size.y = maxi(path_edit.custom_minimum_size.y, ControlSize.md)
	elif node is OptionButton:
		style_path_option(node as OptionButton)
	elif node is PopupMenu:
		var popup_menu := node as PopupMenu
		PopupMenuStyle.apply(popup_menu)
		apply_popup_menu_text(popup_menu, label_texts)
	elif node is MenuButton:
		ButtonStyle.apply_icon_button(node as MenuButton)
	elif node is Button:
		var button := node as Button
		if button.theme_type_variation == &"FlatButton":
			ButtonStyle.apply_icon_button(button)
		else:
			style_button(button)
	elif node is Tree:
		style_tree(node as Tree)
	elif node is ItemList:
		style_item_list(node as ItemList)
	elif node is ScrollBar:
		ScrollBarStyle.apply(node as ScrollBar)
	elif node is Label:
		var label := node as Label
		apply_label_text(label, label_texts)
		label.add_theme_color_override("font_color", ThemeColor.title_color)
	pass


## FileDialog owns these labels internally, so callers supply their already-resolved text. Keep
## the original caption as metadata so refreshing an open dialog works after its text changes.
static func apply_label_text(label: Label, label_texts: Dictionary[String, String]) -> void:
	var source := str(label.get_meta("file_dialog_label_source", label.text))
	if label_texts.has(source):
		label.set_meta("file_dialog_label_source", source)
		label.text = label_texts[source]
	pass


## Buttons and menus created by FileDialog also keep their captions internally as tooltips.
static func apply_tooltip_text(control: Control, label_texts: Dictionary[String, String]) -> void:
	var source := str(control.get_meta("file_dialog_tooltip_source", control.tooltip_text))
	if label_texts.has(source):
		control.set_meta("file_dialog_tooltip_source", source)
		control.tooltip_text = label_texts[source]
	pass


## Preserve each internal menu item's original caption so locale refreshes do not need to know
## which popup owns it. This leaves item metadata untouched for menus that use it for behavior.
static func apply_popup_menu_text(popup_menu: PopupMenu, label_texts: Dictionary[String, String]) -> void:
	var sources := popup_menu.get_meta("file_dialog_popup_menu_sources", {}) as Dictionary
	for index in range(popup_menu.item_count):
		var source := str(sources.get(index, popup_menu.get_item_text(index)))
		if label_texts.has(source):
			sources[index] = source
			popup_menu.set_item_text(index, label_texts[source])
	popup_menu.set_meta("file_dialog_popup_menu_sources", sources)
	pass


static func style_confirm_button(button: Button) -> void:
	var fill := ThemeColor.accent_theme_color()
	var normal := make_outline_action_normal(ThemeColor.alpha_theme_color(0.55))
	var hover := StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.selected_surface, fill)
	var pressed := StyleBoxHelper.duplicate_with_bg_color(normal, fill, fill)
	ButtonStyle.apply_style(button, normal, hover, pressed)
	ButtonStyle.apply_font_colors(button, fill, fill, ThemeColor.inset_surface)
	pass


## Cancel mirrors CommonWindow's close button: quiet title-color at rest, error-red on interaction.
static func style_cancel_button(button: Button) -> void:
	var normal := make_outline_action_normal(Color(ThemeColor.title_color, 0.35))
	var hover := StyleBoxHelper.duplicate_with_bg_color(normal, Colors.error_surface, Colors.error)
	var pressed := StyleBoxHelper.duplicate_with_bg_color(normal, Colors.error, Colors.error)
	ButtonStyle.apply_style(button, normal, hover, pressed)
	ButtonStyle.apply_font_colors(button, ThemeColor.title_color, Colors.error, ThemeColor.inset_surface)
	pass


static func style_button(button: Button) -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_sm, Margin.ma_2, Margin.ma_1,
		Colors.subtle_border, ControlSize.border_xs)
	ButtonStyle.apply_style(button, normal)
	ButtonStyle.apply_font_colors(button, ThemeColor.title_color, ThemeColor.title_color, ThemeColor.title_color)
	pass


static func style_tree(tree: Tree) -> void:
	apply_browser_font_colors(tree)
	tree.add_theme_stylebox_override("panel", make_file_list_style())
	var selected := StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, ControlSize.radius_sm)
	var selected_focus := selected.duplicate() as StyleBoxFlat
	selected_focus.border_color = ThemeColor.accent_theme_color()
	selected_focus.set_border_width_all(ControlSize.border_xs)
	tree.add_theme_stylebox_override("selected", selected)
	tree.add_theme_stylebox_override("selected_focus", selected_focus)
	pass


static func style_item_list(list: ItemList) -> void:
	apply_browser_font_colors(list)
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


static func apply_browser_font_colors(control: Control) -> void:
	control.add_theme_color_override("font_color", ThemeColor.title_color)
	control.add_theme_color_override("font_hovered_color", ThemeColor.title_color)
	control.add_theme_color_override("font_selected_color", ThemeColor.title_color)
	pass


static func make_outline_action_normal(border_color: Color) -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT,
		ControlSize.radius_md, Margin.ma_3, Margin.ma_1, border_color, ControlSize.border_xs)


## Path bar fields use vertical padding; shared [method LineEditStyle.theme_normal_style] uses [member Margin.ma_0] and reads too flat in FileDialog rows.
static func file_dialog_field_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, ControlSize.radius_md, Margin.ma_3, Margin.ma_1,
		Color(ThemeColor.title_color, Weights.w_2), ControlSize.border_xs)


## Drive selector matches the path [LineEdit] so the location row reads as one control.
static func style_path_option(option: OptionButton) -> void:
	var normal := file_dialog_field_style()
	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = ThemeColor.accent_theme_color()
	ButtonStyle.apply_style(option, normal, hover, hover.duplicate())
	ButtonStyle.apply_font_colors(option, ThemeColor.title_color, ThemeColor.title_color, ThemeColor.title_color)
	PopupMenuStyle.apply(option.get_popup())
	pass


## A lightly lifted, misty version of the inset surface separates the lists without the stark
## pure-white card effect, while retaining the active theme hue.
static func make_file_list_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, ControlSize.radius_sm, Margin.ma_1, Margin.ma_1,
		Colors.subtle_border, ControlSize.border_xs)



## A distinct, accent-tinted selection is readable over the file browser surface in either theme.
static func file_list_selection_surface() -> Color:
	return ThemeColor.inset_surface.lerp(ThemeColor.accent_theme_color(), Weights.w_5)


static func make_file_list_hover_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(
		ThemeColor.inset_surface.lerp(ThemeColor.accent_theme_color(), Weights.w_2),
		ControlSize.radius_sm, 0, 0, ThemeColor.alpha_theme_color(0.45), ControlSize.border_xs
	)


static func make_file_list_selection_style(border_color: Color) -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(file_list_selection_surface(), ControlSize.radius_sm, 0, 0,
		border_color, ControlSize.border_xs)


static func make_dialog_body_style() -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(ThemeColor.inset_surface, 0, Margin.ma_2, Margin.ma_2)
	# Match CommonWindow's all-edge overscan so embedded-window pixel rounding cannot expose a seam.
	style.expand_margin_left = ControlSize.border_xs
	style.expand_margin_top = ControlSize.border_xs
	style.expand_margin_right = ControlSize.border_xs
	style.expand_margin_bottom = ControlSize.border_xs
	return style
