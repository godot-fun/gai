## Unit tests for [StyleBoxHelper], [ButtonStyle], [Margin], [DisplayScale], [ThemeColor] helpers, and the builders that go through them.

const GRAY := Color(0.5, 0.5, 0.5)


## [method DisplayScale.compute_ui_scale] maps main-window pixels to viewport units, clamped to 0.5–4.0.
func DisplayScale_compute_ui_scale_test() -> void:
	var scale := DisplayScale.compute_ui_scale()
	assert(scale >= 0.5 and scale <= 4.0)
	pass


## [method DisplayScale.compute_screen_scale] is usable width / 2K reference under the anchor.
func DisplayScale_compute_screen_scale_test() -> void:
	var anchor := Vector2i(200, 300)
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(anchor), Vector2.ONE))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var expected := float(usable.size.x) / float(DisplayScale.REF_SCREEN_WIDTH) if usable.size.x > 0 else 1.0
	assert(is_equal_approx(DisplayScale.compute_screen_scale(anchor), expected))
	pass


static func DisplayScale_adjust_ui_scale_uses_presets_test() -> void:
	var saved := DisplayScale.get_ui_scale()
	DisplayScale.set_ui_scale(1.0)
	var index := DisplayScale.find_ui_scale_index(1.0)
	DisplayScale.adjust_ui_scale(1)
	assert(is_equal_approx(DisplayScale.get_ui_scale(), DisplayScale.UI_SCALE_PRESETS[index + 1]))
	DisplayScale.adjust_ui_scale(-1)
	assert(is_equal_approx(DisplayScale.get_ui_scale(), 1.0))
	DisplayScale.set_ui_scale(saved)
	pass


static func DisplayScale_set_ui_scale_snaps_to_preset_test() -> void:
	var saved := DisplayScale.get_ui_scale()
	DisplayScale.set_ui_scale(1.07)
	assert(is_equal_approx(DisplayScale.get_ui_scale(), 1.05))
	DisplayScale.set_ui_scale(saved)
	pass


func ColorBase_follow_theme_test() -> void:
	var original := ThemeColor.current_theme
	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	ThemeColor.refresh_derived_colors()
	assert(Colors.app_background == Colors.DARK_BACKGROUND)
	assert(Colors.deep_surface == Colors.DARK_DEEP_SURFACE)
	assert(Colors.chrome_surface == Colors.DARK_CHROME_SURFACE)
	assert(Colors.control_surface == Colors.DARK_CONTROL_SURFACE)
	assert(Colors.surface == Colors.DARK_SURFACE)
	assert(Colors.hover_surface == Colors.DARK_HOVER_SURFACE)
	assert(Colors.elevated_surface == Colors.DARK_ELEVATED_SURFACE)
	assert(Colors.border == Colors.DARK_BORDER)
	assert(Colors.muted_border == Colors.DARK_MUTED_BORDER)
	assert(Colors.subtle_border == Colors.DARK_SUBTLE_BORDER)
	assert(Colors.primary_text == Colors.DARK_TEXT)
	assert(Colors.secondary_text == Colors.DARK_MUTED)
	assert(Colors.info == Colors.DARK_INFO)
	assert(Colors.success == Colors.DARK_SUCCESS)
	assert(Colors.warning == Colors.DARK_WARNING)
	assert(Colors.error == Colors.DARK_ERROR)
	assert(Colors.purple == Colors.DARK_PURPLE)
	assert(Colors.info_surface == Colors.DARK_INFO_SURFACE)
	assert(Colors.success_surface == Colors.DARK_SUCCESS_SURFACE)
	assert(Colors.warning_surface == Colors.DARK_WARNING_SURFACE)
	assert(Colors.error_surface == Colors.DARK_ERROR_SURFACE)
	assert(Colors.blue_grey_surface == Colors.DARK_BLUE_GREY_SURFACE)
	assert(Colors.grey_surface == Colors.DARK_GREY_SURFACE)
	assert(Colors.purple_surface == Colors.DARK_PURPLE_SURFACE)
	assert(Colors.lime_surface == Colors.DARK_LIME_SURFACE)
	assert(ThemeColor.selected_surface == ThemeColor.DARK_SELECTED_SURFACE_BASE.lerp(ThemeColor.accent_theme_color(), ThemeColor.DARK_SELECTED_SURFACE_MIX))

	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	ThemeColor.refresh_derived_colors()
	assert(Colors.app_background == Colors.LIGHT_BACKGROUND)
	assert(Colors.deep_surface == Colors.LIGHT_DEEP_SURFACE)
	assert(Colors.chrome_surface == Colors.LIGHT_CHROME_SURFACE)
	assert(Colors.control_surface == Colors.LIGHT_CONTROL_SURFACE)
	assert(Colors.surface == Colors.LIGHT_SURFACE)
	assert(Colors.hover_surface == Colors.LIGHT_HOVER_SURFACE)
	assert(Colors.elevated_surface == Colors.LIGHT_ELEVATED_SURFACE)
	assert(Colors.border == Colors.LIGHT_BORDER)
	assert(Colors.muted_border == Colors.LIGHT_MUTED_BORDER)
	assert(Colors.subtle_border == Colors.LIGHT_SUBTLE_BORDER)
	assert(Colors.primary_text == Colors.LIGHT_TEXT)
	assert(Colors.secondary_text == Colors.LIGHT_MUTED)
	assert(Colors.info == Colors.LIGHT_INFO)
	assert(Colors.success == Colors.LIGHT_SUCCESS)
	assert(Colors.warning == Colors.LIGHT_WARNING)
	assert(Colors.error == Colors.LIGHT_ERROR)
	assert(Colors.purple == Colors.LIGHT_PURPLE)
	assert(Colors.info_surface == Colors.LIGHT_INFO_SURFACE)
	assert(Colors.success_surface == Colors.LIGHT_SUCCESS_SURFACE)
	assert(Colors.warning_surface == Colors.LIGHT_WARNING_SURFACE)
	assert(Colors.error_surface == Colors.LIGHT_ERROR_SURFACE)
	assert(Colors.blue_grey_surface == Colors.LIGHT_BLUE_GREY_SURFACE)
	assert(Colors.grey_surface == Colors.LIGHT_GREY_SURFACE)
	assert(Colors.purple_surface == Colors.LIGHT_PURPLE_SURFACE)
	assert(Colors.lime_surface == Colors.LIGHT_LIME_SURFACE)
	assert(ThemeColor.selected_surface == ThemeColor.LIGHT_SELECTED_SURFACE_BASE.lerp(ThemeColor.accent_theme_color(), ThemeColor.LIGHT_SELECTED_SURFACE_MIX))

	ThemeColor.current_theme = original
	ThemeColor.refresh_derived_colors()
	pass


func ThemeColor_promote_demote_test() -> void:
	var original := ThemeColor.current_theme
	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	assert(ThemeColor.promote(GRAY, Weights.w_2) == GRAY.lightened(Weights.w_2))
	assert(ThemeColor.demote(GRAY, Weights.w_2) == GRAY.darkened(Weights.w_2))
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	assert(ThemeColor.promote(GRAY, Weights.w_2) == GRAY.darkened(Weights.w_2))
	assert(ThemeColor.demote(GRAY, Weights.w_2) == GRAY.lightened(Weights.w_2))
	ThemeColor.current_theme = original
	pass


func ButtonStyle_with_alpha_test() -> void:
	var tinted := Color(Colors.info, 0.45)
	# `Color` stores 32-bit floats, so compare approximately.
	assert(is_equal_approx(tinted.a, 0.45))
	assert(tinted.r == Colors.info.r and tinted.b == Colors.info.b)
	pass


func StyleBoxHelper_create_style_box_flat_test() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Color(0.1, 0.2, 0.3), 8, Margin.ma_2, Margin.ma_1, Colors.info, 1)
	assert(style.bg_color == Color(0.1, 0.2, 0.3))
	assert(style.corner_radius_top_left == 8 and style.corner_radius_bottom_right == 8)
	assert(style.get_margin(SIDE_LEFT) == Margin.ma_2 and style.get_margin(SIDE_RIGHT) == Margin.ma_2)
	assert(style.get_margin(SIDE_TOP) == Margin.ma_1 and style.get_margin(SIDE_BOTTOM) == Margin.ma_1)
	assert(style.border_width_left == 1 and style.border_color == Colors.info)

	# No border width means no border at all, so a caller that does not want one keeps the default.
	var plain := StyleBoxHelper.create_style_box_flat(Color.WHITE, 4)
	assert(plain.border_width_left == 0 and plain.get_margin(SIDE_LEFT) == 0.0)
	pass


func StyleBoxHelper_apply_margin_test() -> void:
	var style := StyleBoxHelper.create_style_box_flat(Color.WHITE, 4)
	StyleBoxHelper.apply_margin(style, Margin.ma_2, Margin.ma_1, Margin.ma_0, Margin.ma_3)
	assert(style.get_margin(SIDE_LEFT) == Margin.ma_3 and style.get_margin(SIDE_RIGHT) == Margin.ma_1)
	assert(style.get_margin(SIDE_TOP) == Margin.ma_2 and style.get_margin(SIDE_BOTTOM) == Margin.ma_0)

	# Base class on purpose: an empty box takes the same padding as a filled one.
	var empty := StyleBoxEmpty.new()
	StyleBoxHelper.apply_margin(empty, Margin.ma_1, Margin.ma_1, Margin.ma_1, Margin.ma_1)
	assert(empty.get_margin(SIDE_LEFT) == Margin.ma_1)
	pass


## The snackbar shadow is the one card value that cannot be a plain token: the same alpha over a dark
## surface and over a light one reads as either nothing or a smudge.
func Alert_card_shadow_test() -> void:
	var original: ThemeColor.ThemeEnum = ThemeColor.current_theme

	ThemeColor.current_theme = ThemeColor.ThemeEnum.DARK
	var dark := Alert.make_card_style(Colors.info)
	ThemeColor.current_theme = ThemeColor.ThemeEnum.LIGHT
	var light := Alert.make_card_style(Colors.info)
	assert(is_equal_approx(dark.shadow_color.a, Alert.shadow_alpha_dark))
	assert(is_equal_approx(light.shadow_color.a, Alert.shadow_alpha_light))
	assert(dark.shadow_color.a > light.shadow_color.a)
	assert(light.shadow_size == Alert.shadow_size)
	assert(light.shadow_offset == Alert.shadow_offset)

	ThemeColor.current_theme = original
	pass


## Both feedback cards use the accent surface; the snackbar frames both edges while the desktop toast
## only marks the leading one.
func card_components_test() -> void:
	var snackbar := Alert.make_card_style(Colors.success)
	assert(snackbar.corner_radius_top_left == ControlSize.radius_md)
	assert(snackbar.border_width_left == ControlSize.border_md)
	assert(snackbar.shadow_size == Alert.shadow_size)

	var scale := DisplayScale.compute_ui_scale()
	var toast: DesktopToast = DesktopToast.new()
	toast.accent = Colors.success
	toast.build_card()
	var toast_card: StyleBoxFlat = toast.card.get_theme_stylebox("panel") as StyleBoxFlat
	assert(toast_card.bg_color == snackbar.bg_color)
	assert(toast_card.border_color == snackbar.border_color)
	assert(toast_card.border_width_left == roundi(ControlSize.border_md * scale))
	assert(toast_card.border_width_right == 0)
	# StyleBox stores margins as engine floats, so a non-integer display scale can round-trip with
	# slightly different precision when this scene follows native-window integration tests.
	assert(is_equal_approx(toast_card.get_margin(SIDE_RIGHT), Margin.ma_5 * scale))
	toast.free()
	pass


## Every state box is a copy of the normal one with a new background color, so the border, padding and corners
## only have to be written once — this is the copy that keeps them.
func StyleBoxHelper_duplicate_with_bg_color_test() -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Color(0.2, 0.2, 0.2), 6, Margin.ma_2, Margin.ma_1, Color.WHITE, 1)
	var hover := StyleBoxHelper.duplicate_with_bg_color(normal, Color(0.3, 0.3, 0.3))
	assert(hover.bg_color == Color(0.3, 0.3, 0.3))
	assert(hover.border_color == normal.border_color and hover.get_margin(SIDE_LEFT) == Margin.ma_2)
	assert(hover.corner_radius_top_left == 6)
	assert(normal.bg_color == Color(0.2, 0.2, 0.2))

	# A border color is only written when one is given, so a state keeps the normal outline by default.
	var outlined := StyleBoxHelper.duplicate_with_bg_color(normal, Color(0.3, 0.3, 0.3), Color.RED)
	assert(outlined.border_color == Color.RED and normal.border_color == Color.WHITE)
	pass


## A missed `hover_pressed` override resolves to the *default theme* box, not to `pressed`,
## so the helper has to set it. This is what that regression looked like.
func ButtonStyle_apply_test() -> void:
	var normal := StyleBoxHelper.create_style_box_flat(Color(0.2, 0.2, 0.2), 6, Margin.ma_2, Margin.ma_1, Color.WHITE, 1)
	var hover := StyleBoxHelper.duplicate_with_bg_color(normal, Color(0.3, 0.3, 0.3))
	var pressed := StyleBoxHelper.duplicate_with_bg_color(normal, Color(0.1, 0.1, 0.1))

	var button := Button.new()
	ButtonStyle.apply_style(button, normal, hover, pressed)
	assert(button.get_theme_stylebox("normal") == normal)
	assert(button.get_theme_stylebox("hover") == hover)
	assert(button.get_theme_stylebox("pressed") == pressed)
	assert((button.get_theme_stylebox("focus") as StyleBoxFlat).bg_color == hover.bg_color)
	assert((button.get_theme_stylebox("disabled") as StyleBoxFlat).bg_color == normal.bg_color)
	assert((button.get_theme_stylebox("hover_pressed") as StyleBoxFlat).bg_color == pressed.bg_color)

	var bare := Button.new()
	bare.add_theme_stylebox_override("pressed", pressed)
	assert(bare.get_theme_stylebox("hover_pressed") != pressed)

	button.free()
	bare.free()
	pass


func ButtonStyle_theme_style_test() -> void:
	var normal := ButtonStyle.theme_normal_style()
	assert(normal.bg_color == ThemeColor.card_surface)
	assert(normal.corner_radius_top_left == ControlSize.radius_md)
	assert(normal.get_margin(SIDE_LEFT) == Margin.ma_2)
	assert(normal.border_color == ThemeColor.accent_theme_color())
	var hover := ButtonStyle.theme_hover_style()
	var pressed := ButtonStyle.theme_pressed_style()
	assert(hover.bg_color == ThemeColor.selected_surface)
	assert(hover.border_color == ThemeColor.alpha_theme_color(0.85))
	assert(pressed.bg_color == ThemeColor.promote(ThemeColor.selected_surface, Weights.w_2))
	assert(pressed.border_color == ThemeColor.accent_theme_color())
	assert(hover.get_margin(SIDE_LEFT) == normal.get_margin(SIDE_LEFT))
	pass


func RangeStyle_apply_spin_box_test() -> void:
	var spin := SpinBox.new()
	RangeStyle.apply_spin_box(spin)
	assert((spin.get_line_edit().get_theme_stylebox("normal") as StyleBoxFlat).bg_color == ThemeColor.card_surface)
	assert(spin.get_theme_color("up_icon_modulate") == Colors.primary_text)
	var theme_color := ThemeColor.accent_theme_color()
	assert((spin.get_theme_stylebox("up_background_hovered") as StyleBoxFlat).bg_color == ThemeColor.promote(theme_color, Weights.w_2))
	assert((spin.get_theme_stylebox("up_background_pressed") as StyleBoxFlat).bg_color == ThemeColor.demote(theme_color, Weights.w_2))
	assert(spin.get_theme_stylebox("field_and_buttons_separator") is StyleBoxEmpty)
	spin.free()
	pass


func ButtonStyle_apply_option_button_test() -> void:
	var option := OptionButton.new()
	var normal := StyleBoxHelper.create_style_box_flat(Color(0.2, 0.2, 0.2), 6, Margin.ma_2, Margin.ma_1, Color.WHITE, 1)
	ButtonStyle.apply_option_button(option, normal, Color.BLACK)
	var hover: StyleBoxFlat = option.get_theme_stylebox("hover") as StyleBoxFlat
	assert(option.get_theme_stylebox("normal") == normal)
	assert(hover.border_color == ThemeColor.accent_theme_color())
	assert((option.get_theme_stylebox("pressed") as StyleBoxFlat).border_color == ThemeColor.accent_theme_color())
	assert((option.get_theme_stylebox("focus") as StyleBoxFlat).border_color == ThemeColor.accent_theme_color())
	assert(option.get_theme_color("font_color") == Color.BLACK)
	option.free()
	pass


func LineEditStyle_apply_test() -> void:
	var edit := LineEdit.new()
	edit.clear_button_enabled = true
	var normal := StyleBoxHelper.create_style_box_flat(Color(0.2, 0.2, 0.2), 6, Margin.ma_2, Margin.ma_1, Color.WHITE, 1)
	LineEditStyle.apply(edit, normal, Color.BLACK, Color.GRAY, Color.BLUE)
	var focus: StyleBoxFlat = edit.get_theme_stylebox("focus") as StyleBoxFlat
	assert(edit.get_theme_color("font_color") == Color.BLACK)
	assert(edit.get_theme_color("font_placeholder_color") == Color.GRAY)
	assert(edit.get_theme_color("selection_color") == Color.BLUE)
	assert(focus.border_color == ThemeColor.accent_theme_color())
	assert(focus.border_width_left == ControlSize.border_sm)
	assert(edit.get_theme_stylebox("read_only") != normal)
	assert(edit.get_theme_color("clear_button_color") == Colors.secondary_text)
	edit.free()
	pass


func LineEditStyle_apply_default_style_test() -> void:
	var edit := LineEdit.new()
	LineEditStyle.apply(edit)
	var normal: StyleBoxFlat = edit.get_theme_stylebox("normal") as StyleBoxFlat
	assert(normal.bg_color == ThemeColor.card_surface)
	assert(normal.corner_radius_top_left == ControlSize.radius_md)
	assert(normal.get_margin(SIDE_LEFT) == Margin.ma_3)
	assert(normal.border_color == Color(ThemeColor.title_color, Weights.w_2))
	assert(normal.border_width_left == ControlSize.border_xs)
	assert(edit.get_theme_stylebox("focus") is StyleBoxFlat)
	edit.free()
	pass


func LineEditStyle_theme_normal_style_test() -> void:
	var normal := LineEditStyle.theme_normal_style()
	assert(normal.bg_color == ThemeColor.card_surface)
	assert(normal.corner_radius_top_left == ControlSize.radius_md)
	assert(normal.get_margin(SIDE_LEFT) == Margin.ma_3)
	assert(normal.border_color == Color(ThemeColor.title_color, Weights.w_2))
	pass


## Same hole on the text side: the default theme paints focus and hover-pressed text near white,
## so a button that only overrides normal / hover / pressed goes blank on a light surface.
func ButtonStyle_apply_font_colors_test() -> void:
	var button := Button.new()
	ButtonStyle.apply_font_colors(button, Color.BLACK, Color.RED, Color.GREEN)
	assert(button.get_theme_color("font_color") == Color.BLACK)
	assert(button.get_theme_color("font_hover_color") == Color.RED)
	assert(button.get_theme_color("font_pressed_color") == Color.GREEN)
	assert(button.get_theme_color("font_focus_color") == Color.RED)
	assert(button.get_theme_color("font_hover_pressed_color") == Color.GREEN)
	assert(button.get_theme_color("font_disabled_color") == Color(Color.BLACK, 0.5))
	button.free()
	pass


func ButtonStyle_apply_icon_button_test() -> void:
	var button := Button.new()
	ButtonStyle.apply_icon_button(button)
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	assert(normal.bg_color == Color.TRANSPARENT)
	assert(button.get_theme_color("font_color") == Colors.secondary_text)
	assert(button.get_theme_color("icon_pressed_color") == ThemeColor.accent_theme_color())
	button.free()
	pass


func ButtonStyle_apply_icon_colors_test() -> void:
	var button := Button.new()
	ButtonStyle.apply_icon_colors(button, Color.BLACK, Color.RED, Color.GREEN)
	assert(button.get_theme_color("icon_normal_color") == Color.BLACK)
	assert(button.get_theme_color("icon_hover_color") == Color.RED)
	assert(button.get_theme_color("icon_pressed_color") == Color.GREEN)
	assert(button.get_theme_color("icon_focus_color") == Color.RED)
	assert(button.get_theme_color("icon_hover_pressed_color") == Color.GREEN)
	assert(button.get_theme_color("icon_disabled_color") == Color(Color.BLACK, 0.5))
	button.free()
	pass


func ButtonStyle_apply_check_button_test() -> void:
	var check := CheckButton.new()
	ButtonStyle.apply_check_button(check, Color.BLUE, Color.RED, Color.GREEN, Color.YELLOW, Margin.ma_1, 3, 4, 5, 2)
	assert(check.get_theme_color("font_color") == Color.BLUE)
	assert(check.get_theme_color("font_hover_color") == Color.RED)
	assert(check.get_theme_color("font_pressed_color") == Color.GREEN)
	assert(check.get_theme_color("button_checked_color") == Color.YELLOW)
	assert(check.get_theme_constant("h_separation") == Margin.ma_1)
	var normal: StyleBox = check.get_theme_stylebox("normal")
	assert(normal.content_margin_left == 2)
	assert(normal.content_margin_top == 3)
	assert(normal.content_margin_right == 4)
	assert(normal.content_margin_bottom == 5)
	check.free()
	pass


func FileDialogStyle_apply_test() -> void:
	var dialog := FileDialog.new()
	FileDialogStyle.apply(dialog)
	var dialog_panel: StyleBoxFlat = dialog.theme.get_stylebox("panel", "AcceptDialog") as StyleBoxFlat
	var file_list_panel: StyleBoxFlat = dialog.theme.get_stylebox("panel", "ItemListSecondary") as StyleBoxFlat
	assert(dialog_panel.bg_color == ThemeColor.inset_surface)
	assert(dialog_panel.expand_margin_left == ControlSize.border_xs)
	assert(dialog_panel.expand_margin_top == ControlSize.border_xs)
	assert(dialog_panel.expand_margin_right == ControlSize.border_xs)
	assert(dialog_panel.expand_margin_bottom == ControlSize.border_xs)
	assert(file_list_panel.bg_color == FileDialogStyle.file_list_surface())
	assert(file_list_panel.border_color == Colors.subtle_border)
	assert(dialog.get_theme_color("folder_icon_color") == Colors.info.lerp(ThemeColor.accent_theme_color(), 0.35))
	assert(dialog.get_theme_color("title_color") == ThemeColor.title_color)
	assert(dialog.transient)
	assert(dialog.popup_window)
	assert(not dialog.exclusive)
	assert(dialog.close_requested.is_connected(FileDialogStyle.hide_dialog.bind(dialog)))
	assert(dialog.window_input.is_connected(FileDialogStyle.on_dialog_window_input.bind(dialog)))
	assert(dialog.get_theme_font("title_font") == Fonts.semibold())
	assert(dialog.theme.get_color("font_color", "Label") == ThemeColor.title_color)
	var confirm: Button = dialog.get_ok_button()
	assert((confirm.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Color.TRANSPARENT)
	assert((confirm.get_theme_stylebox("hover") as StyleBoxFlat).bg_color == ThemeColor.selected_surface)
	assert((confirm.get_theme_stylebox("pressed") as StyleBoxFlat).bg_color == ThemeColor.accent_theme_color())
	assert(confirm.get_theme_color("font_color") == ThemeColor.accent_theme_color())
	var cancel: Button = dialog.get_cancel_button()
	assert((cancel.get_theme_stylebox("normal") as StyleBoxFlat).bg_color == Color.TRANSPARENT)
	assert((cancel.get_theme_stylebox("normal") as StyleBoxFlat).border_color == Color(ThemeColor.title_color, 0.35))
	assert((cancel.get_theme_stylebox("hover") as StyleBoxFlat).bg_color == Colors.error_surface)
	assert((cancel.get_theme_stylebox("pressed") as StyleBoxFlat).bg_color == Colors.error)
	assert(cancel.get_theme_color("font_color") == ThemeColor.title_color)
	assert(cancel.get_theme_color("font_pressed_color") == ThemeColor.inset_surface)
	dialog.free()
	pass


func FileDialogStyle_path_option_test() -> void:
	var option := OptionButton.new()
	FileDialogStyle.style_path_option(option)
	var normal: StyleBoxFlat = option.get_theme_stylebox("normal") as StyleBoxFlat
	var hover: StyleBoxFlat = option.get_theme_stylebox("hover") as StyleBoxFlat
	assert(normal.bg_color == ThemeColor.card_surface)
	assert(normal.border_color == Color(ThemeColor.title_color, Weights.w_2))
	assert(normal.border_width_left == ControlSize.border_xs)
	assert(hover.bg_color == ThemeColor.card_surface)
	assert(hover.border_color == ThemeColor.accent_theme_color())
	assert(option.get_theme_color("font_color") == ThemeColor.title_color)
	option.free()
	pass


func FileDialogStyle_internal_controls_test() -> void:
	var dialog := FileDialog.new()
	FileDialogStyle.apply(dialog)
	var drive_selector := find_internal_option_button(dialog)
	assert(drive_selector != null)
	var normal: StyleBoxFlat = drive_selector.get_theme_stylebox("normal") as StyleBoxFlat
	assert(normal.bg_color == ThemeColor.card_surface)
	dialog.free()
	pass


func FileDialogStyle_apply_label_text_test() -> void:
	var label := Label.new()
	label.text = "Favorites:"
	FileDialogStyle.apply_label_text(label, {"Favorites:": "收藏夹："})
	assert(label.text == "收藏夹：")
	assert(label.get_meta("file_dialog_label_source") == "Favorites:")
	label.free()
	pass


func FileDialogStyle_apply_tooltip_text_test() -> void:
	var button := Button.new()
	button.tooltip_text = "View items as a grid of thumbnails."
	FileDialogStyle.apply_tooltip_text(button, {"View items as a grid of thumbnails.": "以缩略图网格方式查看项目。"})
	assert(button.tooltip_text == "以缩略图网格方式查看项目。")
	assert(button.get_meta("file_dialog_tooltip_source") == "View items as a grid of thumbnails.")
	button.free()
	pass


func FileDialogStyle_apply_popup_menu_text_test() -> void:
	var popup_menu := PopupMenu.new()
	popup_menu.add_item("Sort by Name (Ascending)")
	FileDialogStyle.apply_popup_menu_text(popup_menu, {"Sort by Name (Ascending)": "按名称排序（升序）"})
	assert(popup_menu.get_item_text(0) == "按名称排序（升序）")
	popup_menu.free()
	pass


func FileDialogStyle_file_list_selection_test() -> void:
	var list := ItemList.new()
	FileDialogStyle.style_item_list(list)
	var hovered: StyleBoxFlat = list.get_theme_stylebox("hovered") as StyleBoxFlat
	var selected: StyleBoxFlat = list.get_theme_stylebox("selected") as StyleBoxFlat
	var hovered_selected: StyleBoxFlat = list.get_theme_stylebox("hovered_selected") as StyleBoxFlat
	assert(hovered.bg_color == ThemeColor.inset_surface.lerp(ThemeColor.accent_theme_color(), Weights.w_2))
	assert(selected.bg_color == FileDialogStyle.file_list_selection_surface())
	assert(hovered_selected.bg_color == FileDialogStyle.file_list_selection_surface())
	assert(list.get_theme_color("font_selected_color") == ThemeColor.title_color)
	assert(list.get_theme_color("font_hovered_selected_color") == ThemeColor.title_color)
	list.free()
	pass


func FileDialogStyle_popup_menu_test() -> void:
	var dialog := FileDialog.new()
	var menu := PopupMenu.new()
	dialog.add_child(menu, false, Node.INTERNAL_MODE_FRONT)
	FileDialogStyle.apply(dialog)
	var panel: StyleBoxFlat = menu.get_theme_stylebox("panel") as StyleBoxFlat
	assert(panel.bg_color == ThemeColor.inset_surface)
	assert(menu.get_theme_color("font_color") == Colors.primary_text)
	dialog.free()
	pass


func FileDialogStyle_menu_button_test() -> void:
	var button := MenuButton.new()
	FileDialogStyle.style_control(button)
	var normal: StyleBoxFlat = button.get_theme_stylebox("normal") as StyleBoxFlat
	assert(normal.bg_color == Color.TRANSPARENT)
	assert(button.get_theme_color("font_color") == Colors.secondary_text)
	button.free()
	pass


func find_internal_option_button(root: Node) -> OptionButton:
	for child in root.get_children(true):
		if child is OptionButton:
			return child as OptionButton
		var nested := find_internal_option_button(child)
		if nested != null:
			return nested
	return null
