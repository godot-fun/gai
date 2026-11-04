extends PanelContainer

## Text editor scene. The toolbar is the wordmark, open-file cards, and the Markdown view buttons.
## The body is a workspace file tree beside [MarkdownEdit].

const AGENT_SCENE_PATH := "res://agent/Agent.tscn"
const WORDMARK := "GAI Editor"
const TAB_WIDTH := ControlSize.image_xs

enum Pending { NONE, CLOSE, LEAVE, QUIT }

@onready var toolbar_panel: PanelContainer = $Root/Toolbar
@onready var toolbar_margin: MarginContainer = $Root/Toolbar/ToolbarMargin
@onready var toolbar_row: HBoxContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow
@onready var logo_button: Button = $Root/Toolbar/ToolbarMargin/ToolbarRow/Logo
@onready var tab_spacer: Control = $Root/Toolbar/ToolbarMargin/ToolbarRow/TabSpacer
@onready var tab_scroll: ScrollContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow/TabScroll
@onready var tab_row: HBoxContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow/TabScroll/TabRow
@onready var mode_bar: HBoxContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow/ModeBar
@onready var body_split: HSplitContainer = $Root/Body
@onready var sidebar: PanelContainer = $Root/Body/Sidebar
@onready var file_tree: EditorFileTree = $Root/Body/Sidebar/FileTree
@onready var editor_host: Control = $Root/Body/EditorHost

var tabs: EditorTabs = EditorTabs.new()
var markdown: MarkdownEdit
var confirm: ConfirmationDialog
var discard_button: Button
var tab_cards: Array[PanelContainer] = []
var pending_kind: Pending = Pending.NONE
var pending_index: int = -1
var applying: bool = false
var reveal_serial: int = 0


func _ready() -> void:
	I18nHelper.init_i18n()
	DisplayScale.apply_ui_scale()
	get_tree().set_auto_accept_quit(false)
	var app_theme := Theme.new()
	app_theme.default_font = Fonts.regular()
	theme = app_theme

	markdown = MarkdownEdit.new()
	editor_host.add_child(markdown)
	markdown.detach_mode_bar(mode_bar)
	markdown.text_changed.connect(on_editor_text_changed)
	logo_button.pressed.connect(on_logo_pressed)
	body_split.dragged.connect(on_split_dragged)
	resized.connect(align_tabs)
	file_tree.file_activated.connect(on_file_activated)
	AgentEvents.events.workspace_changed.connect(on_workspace_changed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)

	build_confirm()
	configure_layout()
	apply_theme()
	apply_locale()
	show_active()
	file_tree.reload(AgentWorkspace.get_root())
	align_tabs.call_deferred()
	pass


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null:
		tree.set_auto_accept_quit(true)
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		on_window_close_requested()
	pass


func _input(event: InputEvent) -> void:
	if scroll_tabs(event):
		get_viewport().set_input_as_handled()
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if confirm != null and confirm.visible:
		return
	if key.keycode != KEY_S or key.alt_pressed or key.shift_pressed:
		return
	if not key.ctrl_pressed and not key.meta_pressed:
		return
	save_active()
	get_viewport().set_input_as_handled()
	pass


func build_confirm() -> void:
	confirm = ConfirmationDialog.new()
	confirm.exclusive = true
	confirm.dialog_autowrap = true
	confirm.min_size = Vector2i(420, 140)
	add_child(confirm)
	discard_button = confirm.add_button("", false, "discard")
	confirm.confirmed.connect(on_confirm_saved)
	confirm.custom_action.connect(on_confirm_custom)
	confirm.canceled.connect(on_confirm_canceled)
	pass


func configure_layout() -> void:
	toolbar_panel.custom_minimum_size.y = AgentLayout.TOOLBAR_HEIGHT
	toolbar_margin.add_theme_constant_override("margin_left", Margin.ma_3)
	toolbar_margin.add_theme_constant_override("margin_right", Margin.ma_3)
	toolbar_margin.add_theme_constant_override("margin_top", Margin.ma_2)
	toolbar_margin.add_theme_constant_override("margin_bottom", Margin.ma_2)
	toolbar_row.add_theme_constant_override("separation", Margin.ma_4)
	tab_row.add_theme_constant_override("separation", Margin.ma_2)
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_split.split_offset = AgentLayout.SIDEBAR_DEFAULT_WIDTH
	sidebar.custom_minimum_size.x = AgentLayout.SIDEBAR_MIN_WIDTH
	file_tree.set_column_expand(0, true)
	file_tree.set_column_clip_content(0, true)
	align_tabs.call_deferred()
	pass


func apply_locale() -> void:
	logo_button.tooltip_text = I18n.t("editor.back")
	confirm.title = I18n.t("editor.save_title")
	confirm.ok_button_text = I18n.t("common.save")
	confirm.cancel_button_text = I18n.t("common.cancel")
	discard_button.text = I18n.t("editor.discard")
	for card in tab_cards:
		var close_button := card.get_meta("close_button") as Button
		close_button.tooltip_text = I18n.t("editor.close")
	pass


func apply_theme() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = Fonts.regular()
	theme = app_theme
	add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.app_background))
	toolbar_panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.deep_surface, 0, 0, 0, Colors.subtle_border, ControlSize.border_xs))
	sidebar.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.chrome_surface, 0, 0, 0, Colors.muted_border, ControlSize.border_xs))
	style_logo()
	style_file_tree()
	style_confirm()
	for card in tab_cards:
		style_card(card)
	if OSUtils.is_windows():
		NativeOS.apply_title_bar_dark_mode(DisplayServer.MAIN_WINDOW_ID, ThemeColor.is_dark_theme())
	DisplayServer.window_set_title(WORDMARK, DisplayServer.MAIN_WINDOW_ID)
	align_tabs.call_deferred()
	pass


func on_split_dragged(_offset: int) -> void:
	align_tabs()
	pass


## Keeps the open-file cards on the same left edge as the editor pane.
func align_tabs() -> void:
	if not is_inside_tree() or editor_host.size.x <= 1.0:
		return
	var delta := editor_host.global_position.x - tab_scroll.global_position.x
	var width := maxf(0.0, tab_spacer.size.x + delta)
	if absf(width - tab_spacer.custom_minimum_size.x) < 1.0:
		return
	tab_spacer.custom_minimum_size.x = width
	pass


func style_logo() -> void:
	logo_button.text = WORDMARK
	logo_button.flat = true
	logo_button.focus_mode = Control.FOCUS_NONE
	logo_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	logo_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var logo_font := FontVariation.new()
	logo_font.base_font = Fonts.bold()
	logo_font.spacing_glyph = Typography.letter_spacing_lg
	logo_button.add_theme_font_override("font", logo_font)
	logo_button.add_theme_font_size_override("font_size", Typography.title_medium_size)
	var accent := ThemeColor.accent_theme_color()
	var color := accent if ThemeColor.is_dark_theme() else accent.darkened(0.08)
	ButtonStyle.apply_font_colors(logo_button, color, color, color)
	var empty := StyleBoxEmpty.new()
	logo_button.add_theme_stylebox_override("normal", empty)
	logo_button.add_theme_stylebox_override("hover", empty)
	logo_button.add_theme_stylebox_override("pressed", empty)
	logo_button.add_theme_stylebox_override("focus", empty)
	logo_button.add_theme_stylebox_override("hover_pressed", empty)
	pass


func style_file_tree() -> void:
	ScrollBarStyle.apply(tab_scroll.get_h_scroll_bar())
	file_tree.add_theme_font_override("font", Fonts.regular())
	file_tree.add_theme_font_size_override("font_size", Typography.body_medium_size)
	file_tree.add_theme_color_override("font_color", Colors.primary_text)
	file_tree.add_theme_color_override("font_hovered_color", Colors.primary_text)
	file_tree.add_theme_color_override("font_selected_color", Colors.primary_text)
	file_tree.add_theme_color_override("font_hovered_selected_color", Colors.primary_text)
	file_tree.add_theme_color_override("guide_color", Colors.muted_border)
	file_tree.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT))
	var selected := StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1)
	file_tree.add_theme_stylebox_override("selected", selected)
	file_tree.add_theme_stylebox_override("selected_focus", selected.duplicate() as StyleBoxFlat)
	file_tree.add_theme_stylebox_override("hovered_selected", selected.duplicate() as StyleBoxFlat)
	file_tree.add_theme_stylebox_override("hovered_selected_focus", selected.duplicate() as StyleBoxFlat)
	file_tree.add_theme_stylebox_override("hovered", StyleBoxHelper.create_style_box_flat(Colors.hover_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1))
	style_internal_scroll_bars(file_tree)
	pass


func style_confirm() -> void:
	confirm.add_theme_font_override("font", Fonts.regular())
	confirm.add_theme_font_size_override("font_size", Typography.body_medium_size)
	discard_button.focus_mode = Control.FOCUS_NONE
	pass


func style_internal_scroll_bars(node: Node) -> void:
	for child in node.get_children(true):
		if child is ScrollBar:
			ScrollBarStyle.apply(child as ScrollBar)
		style_internal_scroll_bars(child)
	pass


func on_workspace_changed(path: String) -> void:
	file_tree.reload(path)
	pass


func on_file_activated(path: String) -> void:
	var existing := tabs.find_index(path)
	if existing >= 0 and existing == tabs.active_index:
		return
	if not EditorDocument.can_edit(path):
		Alert.alert(I18n.t("editor.not_text"), Colors.error)
		return
	sync_active()
	if tabs.open_file(path) == null:
		Alert.alert(I18n.t("editor.not_text"), Colors.error)
		return
	show_active()
	pass


func on_tab_pressed(index: int) -> void:
	if index == tabs.active_index:
		return
	sync_active()
	tabs.active_index = index
	show_active()
	pass


func on_tab_close_pressed(index: int) -> void:
	sync_active()
	if index < 0 or index >= tabs.documents.size():
		return
	if tabs.documents[index].is_dirty():
		ask(Pending.CLOSE, index)
		return
	tabs.close_at(index)
	show_active()
	pass


func on_logo_pressed() -> void:
	sync_active()
	if tabs.dirty_documents().is_empty():
		leave()
		return
	ask(Pending.LEAVE, -1)
	pass


func on_window_close_requested() -> void:
	if pending_kind != Pending.NONE:
		return
	sync_active()
	if tabs.dirty_documents().is_empty():
		get_tree().quit()
		return
	ask(Pending.QUIT, -1)
	pass


func on_editor_text_changed() -> void:
	if applying:
		return
	var document := tabs.active()
	if document == null:
		return
	document.text = markdown.text
	update_dirty_marks()
	pass


## The tab strip scrolls without a bar, so the toolbar height stays put when cards overflow.
func scroll_tabs(event: InputEvent) -> bool:
	if confirm != null and confirm.visible:
		return false
	if not tab_scroll.get_global_rect().has_point(tab_scroll.get_global_mouse_position()):
		return false
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed:
		if mouse.button_index == MOUSE_BUTTON_WHEEL_UP or mouse.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			tab_scroll.scroll_horizontal -= TAB_WIDTH
			return true
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN or mouse.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			tab_scroll.scroll_horizontal += TAB_WIDTH
			return true
	var pan := event as InputEventPanGesture
	if pan != null:
		var delta := pan.delta.x if absf(pan.delta.x) >= absf(pan.delta.y) else pan.delta.y
		tab_scroll.scroll_horizontal += roundi(delta)
		return true
	return false


func reveal_active_tab(serial: int = -1, retries: int = 4) -> void:
	if serial < 0:
		reveal_serial += 1
		serial = reveal_serial
	if serial != reveal_serial:
		return
	var index := tabs.active_index
	if index < 0 or index >= tab_cards.size():
		return
	var stride := float(TAB_WIDTH + tab_row.get_theme_constant("separation"))
	var left := index * stride
	var right := left + float(TAB_WIDTH)
	var view_width := tab_scroll.size.x
	# Card positions are still 0 until the row lays out, so wait a frame and measure by index.
	if view_width <= 1.0 or tab_row.size.x + 1.0 < right:
		if retries > 0 and is_inside_tree():
			get_tree().process_frame.connect(func() -> void: reveal_active_tab(serial, retries - 1), CONNECT_ONE_SHOT)
		return
	var view_left := float(tab_scroll.scroll_horizontal)
	var view_right := view_left + view_width
	if right > view_right:
		tab_scroll.scroll_horizontal = roundi(right - view_width)
	elif left < view_left:
		tab_scroll.scroll_horizontal = roundi(left)
	pass


func show_active() -> void:
	var document := tabs.active()
	applying = true
	if document == null:
		markdown.text = ""
		markdown.text_edit.editable = false
	else:
		markdown.text_edit.editable = true
		markdown.text = document.text
	applying = false
	rebuild_tabs()
	markdown.focus_editor()
	pass


func sync_active() -> void:
	var document := tabs.active()
	if document == null or markdown == null:
		return
	document.text = markdown.text
	pass


func save_active() -> void:
	sync_active()
	var document := tabs.active()
	if document == null or not document.is_dirty():
		return
	if document.save() != OK:
		Alert.alert(I18n.t("editor.save_failed"), Colors.error)
		return
	update_dirty_marks()
	pass


func save_all_dirty() -> bool:
	sync_active()
	for document in tabs.dirty_documents():
		if document.save() != OK:
			Alert.alert(I18n.t("editor.save_failed"), Colors.error)
			return false
	update_dirty_marks()
	return true


func ask(kind: Pending, index: int) -> void:
	pending_kind = kind
	pending_index = index
	var dirty := tabs.dirty_documents()
	if kind == Pending.CLOSE:
		confirm.dialog_text = StringUtils.format(I18n.t("editor.save_changes"), tabs.documents[index].file_name())
	elif dirty.size() == 1:
		confirm.dialog_text = StringUtils.format(I18n.t("editor.save_changes"), dirty[0].file_name())
	else:
		confirm.dialog_text = StringUtils.format(I18n.t("editor.save_changes_many"), dirty.size())
	confirm.popup_centered()
	pass


func on_confirm_saved() -> void:
	var kind := pending_kind
	var index := pending_index
	if kind == Pending.NONE:
		return
	clear_pending()
	if kind == Pending.CLOSE:
		if index < 0 or index >= tabs.documents.size():
			return
		sync_active()
		if tabs.documents[index].save() != OK:
			Alert.alert(I18n.t("editor.save_failed"), Colors.error)
			return
		tabs.close_at(index)
		show_active()
		return
	if not save_all_dirty():
		return
	finish_leave(kind)
	pass


func on_confirm_custom(action: StringName) -> void:
	if action != "discard":
		return
	var kind := pending_kind
	var index := pending_index
	if kind == Pending.NONE:
		return
	clear_pending()
	confirm.hide()
	if kind == Pending.CLOSE:
		tabs.close_at(index)
		show_active()
		return
	finish_leave(kind)
	pass


func on_confirm_canceled() -> void:
	clear_pending()
	pass


func finish_leave(kind: Pending) -> void:
	if kind == Pending.QUIT:
		get_tree().quit()
		return
	if kind == Pending.LEAVE:
		leave()
	pass


func clear_pending() -> void:
	pending_kind = Pending.NONE
	pending_index = -1
	pass


func leave() -> void:
	await SceneHelper.async_change_scene_to_file(AGENT_SCENE_PATH)
	pass


func rebuild_tabs() -> void:
	for card in tab_cards:
		tab_row.remove_child(card)
		card.queue_free()
	tab_cards.clear()
	for index in tabs.documents.size():
		var card := make_tab(index)
		tab_row.add_child(card)
		tab_cards.append(card)
	reveal_active_tab()
	pass


func make_tab(index: int) -> PanelContainer:
	var document := tabs.documents[index]
	var card := PanelContainer.new()
	card.custom_minimum_size.x = TAB_WIDTH
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", Margin.ma_1)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(row)

	var name_button := Button.new()
	name_button.focus_mode = Control.FOCUS_NONE
	name_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	name_button.flat = true
	name_button.clip_text = true
	name_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_button.text = document.file_name()
	name_button.tooltip_text = document.path
	name_button.custom_minimum_size.y = ControlSize.sm
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.add_theme_font_override("font", Fonts.regular())
	name_button.add_theme_font_size_override("font_size", Typography.label_medium_size)
	name_button.pressed.connect(on_tab_pressed.bind(index))
	row.add_child(name_button)

	var dirty_label := Label.new()
	dirty_label.text = "●"
	dirty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dirty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dirty_label.modulate.a = 1.0 if document.is_dirty() else 0.0
	dirty_label.add_theme_font_size_override("font_size", Typography.label_medium_size)
	dirty_label.add_theme_color_override("font_color", ThemeColor.accent_theme_color())
	row.add_child(dirty_label)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = I18n.t("editor.close")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.flat = true
	close_button.custom_minimum_size = ControlSize.square(ControlSize.xs)
	close_button.add_theme_font_size_override("font_size", Typography.label_medium_size)
	close_button.pressed.connect(on_tab_close_pressed.bind(index))
	row.add_child(close_button)

	card.set_meta("active", index == tabs.active_index)
	card.set_meta("name_button", name_button)
	card.set_meta("dirty_label", dirty_label)
	card.set_meta("close_button", close_button)
	style_card(card)
	return card


func style_card(card: PanelContainer) -> void:
	var active := bool(card.get_meta("active", false))
	var name_button := card.get_meta("name_button") as Button
	var close_button := card.get_meta("close_button") as Button
	var dirty_label := card.get_meta("dirty_label") as Label
	var background := ThemeColor.selected_surface if active else Colors.control_surface
	var border := ThemeColor.accent_theme_color() if active else Colors.subtle_border
	card.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(background, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, border, ControlSize.border_xs))
	var text_color := Colors.primary_text if active else Colors.secondary_text
	ButtonStyle.apply_font_colors(name_button, text_color, Colors.primary_text, Colors.primary_text)
	ButtonStyle.apply_font_colors(close_button, Colors.secondary_text, Colors.primary_text, Colors.primary_text)
	dirty_label.add_theme_color_override("font_color", ThemeColor.accent_theme_color())
	for button in [name_button, close_button]:
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover_pressed", StyleBoxEmpty.new())
	pass


func update_dirty_marks() -> void:
	for index in tab_cards.size():
		var dirty_label := tab_cards[index].get_meta("dirty_label") as Label
		dirty_label.modulate.a = 1.0 if tabs.documents[index].is_dirty() else 0.0
	pass
