extends PanelContainer

## Workspace editor panel. The toolbar is the wordmark and the open-file cards.
## The body is a workspace file tree beside a display selected for the active file. Hosted by [EditorWindow].

const WORDMARK := "GAI · Editor"

enum Pending { NONE, CLOSE, CLOSE_OTHERS, CLOSE_ALL, LEAVE }

enum TabMenuAction { CLOSE, CLOSE_OTHERS, CLOSE_ALL }

@onready var toolbar_panel: PanelContainer = $Root/Toolbar
@onready var toolbar_margin: MarginContainer = $Root/Toolbar/ToolbarMargin
@onready var toolbar_row: HBoxContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow
@onready var logo_label: Label = $Root/Toolbar/ToolbarMargin/ToolbarRow/Logo
@onready var tab_spacer: Control = $Root/Toolbar/ToolbarMargin/ToolbarRow/TabSpacer
@onready var tab_scroll: ScrollContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow/TabScroll
@onready var tab_row: HBoxContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow/TabScroll/TabRow
@onready var body_split: HSplitContainer = $Root/Body
@onready var sidebar: PanelContainer = $Root/Body/Sidebar
@onready var file_tree: EditorFileTree = $Root/Body/Sidebar/FileTree
@onready var editor_host: MarginContainer = $Root/Body/EditorHost

var host_window: Window
var tabs: EditorTabs = EditorTabs.new()
var shortcut_host: EditorShortcuts.Host
var active_view: EditorView
var confirm: ConfirmationDialog
var discard_button: Button
var tab_cards: Array[PanelContainer] = []
var pending_kind: Pending = Pending.NONE
var pending_index: int = -1
var reveal_queued: bool = false
var tab_menu: PopupMenu
var context_tab_index: int = -1


func _ready() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = Fonts.regular()
	app_theme.default_font_size = Typography.body_medium
	theme = app_theme

	body_split.dragged.connect(on_split_dragged)
	resized.connect(align_tabs)
	AgentEvents.events.editor_file_selected.connect(on_file_selected)
	AgentEvents.events.editor_file_deleted.connect(on_file_deleted)
	AgentEvents.events.workspace_changed.connect(on_workspace_changed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)

	build_confirm()
	build_tab_menu()
	shortcut_host = EditorShortcuts.bind_editor(self)
	configure_layout()
	apply_theme()
	apply_locale()
	file_tree.reload(AgentWorkspace.get_root())
	tabs = EditorTabs.load()
	show_active()
	align_tabs.call_deferred()
	pass


func _exit_tree() -> void:
	sync_active()
	tabs.save()
	pass


func _input(event: InputEvent) -> void:
	if scroll_tabs(event):
		get_viewport().set_input_as_handled()
		return
	if EditorShortcuts.handle_input(event, shortcut_host):
		get_viewport().set_input_as_handled()
		return
	pass


func build_confirm() -> void:
	confirm = ConfirmationDialog.new()
	confirm.exclusive = true
	confirm.dialog_autowrap = true
	confirm.min_size = Vector2i(ControlSize.image_lg, ControlSize.image_xs)
	add_child(confirm)
	discard_button = confirm.add_button("", false, "discard")
	confirm.confirmed.connect(on_confirm_saved)
	confirm.custom_action.connect(on_confirm_custom)
	confirm.canceled.connect(on_confirm_canceled)
	pass


func build_tab_menu() -> void:
	tab_menu = PopupMenu.new()
	tab_menu.id_pressed.connect(on_tab_menu_action)
	add_child(tab_menu)
	pass


func configure_layout() -> void:
	toolbar_panel.custom_minimum_size.y = AgentLayout.toolbar_height
	toolbar_margin.add_theme_constant_override("margin_left", Margin.ma_3)
	toolbar_margin.add_theme_constant_override("margin_right", Margin.ma_3)
	toolbar_margin.add_theme_constant_override("margin_top", Margin.ma_2)
	toolbar_margin.add_theme_constant_override("margin_bottom", Margin.ma_2)
	toolbar_row.add_theme_constant_override("separation", Margin.ma_4)
	tab_row.add_theme_constant_override("separation", Margin.ma_2)
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_split.split_offset = AgentLayout.sidebar_default_width
	sidebar.custom_minimum_size.x = AgentLayout.sidebar_min_width
	file_tree.set_column_expand(0, true)
	file_tree.set_column_clip_content(0, true)
	align_tabs.call_deferred()
	pass


func apply_locale() -> void:
	var modifier := "Cmd" if OSUtils.is_mac() else "Ctrl"
	logo_label.tooltip_text = I18n.t("editor.shortcuts_tooltip").replace("{modifier}", modifier)
	confirm.title = I18n.t("editor.save_title")
	confirm.ok_button_text = I18n.t("common.save")
	confirm.cancel_button_text = I18n.t("common.cancel")
	discard_button.text = I18n.t("editor.discard")
	file_tree.apply_locale()
	for card in tab_cards:
		var close_button := card.get_meta("close_button") as Button
		close_button.tooltip_text = I18n.t("editor.close")
	pass


func apply_theme() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = Fonts.regular()
	app_theme.default_font_size = Typography.body_medium
	theme = app_theme
	add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.app_background))
	toolbar_panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.deep_surface, 0, 0, 0, Colors.outline_variant, ControlSize.border_xs))
	sidebar.add_theme_stylebox_override("panel", SessionSidebarTheme.sidebar_panel())
	style_logo()
	style_file_tree()
	ConfirmationDialogStyle.apply(confirm, [discard_button])
	PopupMenuStyle.apply(tab_menu)
	file_tree.apply_menu_theme()
	for card in tab_cards:
		style_card(card)
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
	logo_label.text = WORDMARK
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	logo_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var accent := ThemeColor.accent_theme_color()
	var color := accent if ThemeColor.is_dark_theme() else accent.darkened(0.08)
	var logo_font := FontVariation.new()
	logo_font.base_font = Fonts.bold()
	logo_font.spacing_glyph = Typography.letter_spacing_lg
	logo_label.add_theme_font_override("font", logo_font)
	logo_label.add_theme_font_size_override("font_size", Typography.title_medium)
	logo_label.add_theme_color_override("font_color", color)
	pass


func style_file_tree() -> void:
	ScrollBarStyle.apply(tab_scroll.get_h_scroll_bar())
	file_tree.add_theme_font_override("font", Fonts.regular())
	file_tree.add_theme_font_size_override("font_size", Typography.body_medium)
	for color_name in ["font_color", "font_hovered_color", "font_hovered_dimmed_color", "font_selected_color", "font_hovered_selected_color"]:
		file_tree.add_theme_color_override(color_name, Colors.primary_text)
	file_tree.add_theme_constant_override("draw_guides", 0)
	file_tree.add_theme_constant_override("icon_max_width", ControlSize.icon_sm)
	file_tree.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT))
	file_tree.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	file_tree.add_theme_stylebox_override("cursor", StyleBoxEmpty.new())
	file_tree.add_theme_stylebox_override("cursor_unfocused", StyleBoxEmpty.new())
	TreeStyle.apply_full_width_rows(file_tree, Margin.ma_2, Margin.ma_1)
	style_internal_scroll_bars(file_tree)
	pass


func style_internal_scroll_bars(node: Node) -> void:
	for child in node.get_children(true):
		if child is ScrollBar:
			ScrollBarStyle.apply(child as ScrollBar, ScrollBarStyle.Thickness.SM)
		style_internal_scroll_bars(child)
	pass


func on_workspace_changed(path: String) -> void:
	file_tree.reload(path)
	pass


func on_file_deleted(path: String) -> void:
	if tabs.close_under(path):
		show_active()
	pass


func on_file_selected(path: String) -> void:
	var existing := tabs.find_index(path)
	if existing >= 0 and existing == tabs.active_index:
		return
	if not EditorDocument.can_open(path):
		FileUtils.open_file(path)
		return
	sync_active()
	if tabs.open_file(path) == null:
		FileUtils.open_file(path)
		return
	show_active()
	pass


func on_tab_pressed(index: int) -> void:
	if index == tabs.active_index:
		return
	activate_tab(index)
	pass


func on_tab_close_pressed(index: int) -> void:
	sync_active()
	if index < 0 or index >= tabs.files.size():
		return
	if tabs.files[index].is_dirty():
		confirm_unsaved(Pending.CLOSE, index)
		return
	tabs.close_at(index)
	show_active()
	pass


func on_tab_gui_input(event: InputEvent, index: int) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_RIGHT:
		return
	context_tab_index = index
	tab_menu.clear()
	tab_menu.add_item(I18n.t("editor.close"), TabMenuAction.CLOSE)
	tab_menu.add_item(I18n.t("editor.close_others"), TabMenuAction.CLOSE_OTHERS)
	tab_menu.set_item_disabled(tab_menu.item_count - 1, tabs.files.size() <= 1)
	tab_menu.add_item(I18n.t("editor.close_all"), TabMenuAction.CLOSE_ALL)
	PopupMenuStyle.apply(tab_menu)
	var card := tab_cards[index]
	var popup_position := Vector2i(card.global_position) + Vector2i(mouse.position)
	tab_menu.popup(Rect2i(popup_position, Vector2i.ZERO))
	card.accept_event()
	pass


func on_tab_menu_action(action: int) -> void:
	match action:
		TabMenuAction.CLOSE:
			on_tab_close_pressed(context_tab_index)
		TabMenuAction.CLOSE_OTHERS:
			close_other_tabs(context_tab_index)
		TabMenuAction.CLOSE_ALL:
			close_all_tabs()
	pass


func close_other_tabs(index: int) -> void:
	if index < 0 or index >= tabs.files.size() or tabs.files.size() <= 1:
		return
	sync_active()
	if not dirty_files_except(index).is_empty():
		confirm_unsaved(Pending.CLOSE_OTHERS, index)
		return
	tabs.close_others(index)
	show_active()
	pass


func close_all_tabs() -> void:
	if tabs.files.is_empty():
		return
	sync_active()
	if not tabs.dirty_files().is_empty():
		confirm_unsaved(Pending.CLOSE_ALL, -1)
		return
	tabs.close_all()
	show_active()
	pass


## Returns [code]true[/code] when close is blocked pending a save/discard dialog.
func handle_host_close_request() -> bool:
	return defer_leave_for_unsaved()


func defer_leave_for_unsaved() -> bool:
	if pending_kind != Pending.NONE:
		return true
	sync_active()
	if tabs.dirty_files().is_empty():
		return false
	confirm_unsaved(Pending.LEAVE, -1)
	return true


func dismiss_host_window() -> void:
	if host_window != null and is_instance_valid(host_window):
		host_window.queue_free()
	pass


func focus_active_editor() -> void:
	if active_view != null:
		active_view.focus_view()
	pass


func on_active_view_content_changed() -> void:
	var document := tabs.active()
	if document == null or active_view == null:
		return
	active_view.sync_document(document)
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
			tab_scroll.scroll_horizontal -= ControlSize.image_xs
			return true
		if mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN or mouse.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			tab_scroll.scroll_horizontal += ControlSize.image_xs
			return true
	var pan := event as InputEventPanGesture
	if pan != null:
		var delta := pan.delta.x if absf(pan.delta.x) >= absf(pan.delta.y) else pan.delta.y
		tab_scroll.scroll_horizontal += roundi(delta)
		return true
	return false


func queue_reveal() -> void:
	if reveal_queued or not is_inside_tree():
		return
	reveal_queued = true
	get_tree().process_frame.connect(reveal_active_tab, CONNECT_ONE_SHOT)
	pass


func reveal_active_tab() -> void:
	reveal_queued = false
	var index := tabs.active_index
	if index < 0 or index >= tab_cards.size() or tab_scroll.size.x <= 1.0:
		return
	var card := tab_cards[index]
	var left := int(card.position.x)
	var right := left + int(card.size.x)
	var view_width := int(tab_scroll.size.x)
	if right > tab_scroll.scroll_horizontal + view_width:
		tab_scroll.scroll_horizontal = right - view_width
	elif left < tab_scroll.scroll_horizontal:
		tab_scroll.scroll_horizontal = left
	pass


func show_active() -> void:
	var document := tabs.active()
	clear_active_view()
	if document != null:
		active_view = EditorViewFactory.create(document)
		if active_view != null:
			active_view.content_changed.connect(on_active_view_content_changed)
			editor_host.add_child(active_view)
			active_view.open_document(document)
	rebuild_tabs()
	focus_active_editor()
	tabs.save()
	pass


func clear_active_view() -> void:
	if active_view != null:
		editor_host.remove_child(active_view)
		active_view.queue_free()
		active_view = null
	pass


func activate_tab(index: int) -> void:
	if index < 0 or index >= tabs.files.size() or index == tabs.active_index:
		return
	sync_active()
	tabs.active_index = index
	show_active()
	pass


func sync_active() -> void:
	var document := tabs.active()
	if document == null or active_view == null:
		return
	active_view.sync_document(document)
	pass


func save_active_from_shortcut() -> void:
	sync_active()
	var document := tabs.active()
	if document == null or not document.is_dirty():
		return
	if document.save() != OK:
		Alert.alert(I18n.t("editor.save_failed"), Colors.error)
		return
	update_dirty_marks()
	Alert.alert(StringUtils.format(I18n.t("editor.save_succeeded"), document.file_name()), Colors.success)
	pass


func save_all_from_shortcut() -> void:
	sync_active()
	var dirty := tabs.dirty_files()
	if dirty.is_empty():
		return
	var count := dirty.size()
	if not save_all_dirty():
		return
	Alert.alert(StringUtils.format(I18n.t("editor.save_all_succeeded"), count), Colors.success)
	pass


func close_active_from_shortcut() -> void:
	var index := tabs.active_index
	if index < 0:
		return
	on_tab_close_pressed(index)
	pass


func switch_tab(direction: int) -> void:
	if tabs.files.is_empty() or direction == 0:
		return
	var count := tabs.files.size()
	var index := tabs.active_index
	if index < 0:
		index = 0
	index = (index + direction) % count
	if index < 0:
		index += count
	if index == tabs.active_index:
		return
	activate_tab(index)
	pass


func save_all_dirty() -> bool:
	sync_active()
	for document in tabs.dirty_files():
		if document.save() != OK:
			Alert.alert(I18n.t("editor.save_failed"), Colors.error)
			return false
	update_dirty_marks()
	return true


func dirty_files_except(keep_index: int) -> Array[EditorDocument]:
	var dirty: Array[EditorDocument] = []
	for index in tabs.files.size():
		if index != keep_index and tabs.files[index].is_dirty():
			dirty.append(tabs.files[index])
	return dirty


func save_dirty_except(keep_index: int) -> bool:
	for document in dirty_files_except(keep_index):
		if document.save() != OK:
			Alert.alert(I18n.t("editor.save_failed"), Colors.error)
			return false
	update_dirty_marks()
	return true


func confirm_unsaved(kind: Pending, index: int) -> void:
	pending_kind = kind
	pending_index = index
	var dirty := dirty_files_except(index) if kind == Pending.CLOSE_OTHERS else tabs.dirty_files()
	if kind == Pending.CLOSE:
		confirm.dialog_text = StringUtils.format(I18n.t("editor.save_changes"), tabs.files[index].file_name())
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
		if index < 0 or index >= tabs.files.size():
			return
		sync_active()
		if tabs.files[index].save() != OK:
			Alert.alert(I18n.t("editor.save_failed"), Colors.error)
			return
		tabs.close_at(index)
		show_active()
		return
	if kind == Pending.CLOSE_OTHERS:
		if not save_dirty_except(index):
			return
		tabs.close_others(index)
		show_active()
		return
	if kind == Pending.CLOSE_ALL:
		if not save_all_dirty():
			return
		tabs.close_all()
		show_active()
		return
	if not save_all_dirty():
		return
	finish_pending(kind)
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
	if kind == Pending.CLOSE_OTHERS:
		tabs.close_others(index)
		show_active()
		return
	if kind == Pending.CLOSE_ALL:
		tabs.close_all()
		show_active()
		return
	finish_pending(kind)
	pass


func on_confirm_canceled() -> void:
	clear_pending()
	pass


func finish_pending(kind: Pending) -> void:
	if kind == Pending.LEAVE:
		dismiss_host_window()
	pass


func clear_pending() -> void:
	pending_kind = Pending.NONE
	pending_index = -1
	pass


func rebuild_tabs() -> void:
	for card in tab_cards:
		tab_row.remove_child(card)
		card.queue_free()
	tab_cards.clear()
	for index in tabs.files.size():
		var card := make_tab(index)
		tab_row.add_child(card)
		tab_cards.append(card)
	var count := tab_cards.size()
	var separation := tab_row.get_theme_constant("separation")
	tab_row.custom_minimum_size.x = count * ControlSize.image_xs + maxi(count - 1, 0) * separation
	queue_reveal()
	pass


func make_tab(index: int) -> PanelContainer:
	var document := tabs.files[index]
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(ControlSize.image_xs, AgentLayout.toolbar_height - Margin.ma_2 * 2)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(on_tab_gui_input.bind(index))
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
	name_button.custom_minimum_size.y = ControlSize.xs
	name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_button.add_theme_font_override("font", Fonts.regular())
	name_button.add_theme_font_size_override("font_size", Typography.label_medium)
	name_button.pressed.connect(on_tab_pressed.bind(index))
	name_button.gui_input.connect(on_tab_gui_input.bind(index))
	row.add_child(name_button)

	var dirty_label := Label.new()
	dirty_label.text = "●"
	dirty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dirty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dirty_label.modulate.a = 1.0 if document.is_dirty() else 0.0
	dirty_label.add_theme_font_size_override("font_size", Typography.label_medium)
	dirty_label.add_theme_color_override("font_color", ThemeColor.accent_theme_color())
	row.add_child(dirty_label)

	var close_button := Button.new()
	close_button.text = "×"
	close_button.tooltip_text = I18n.t("editor.close")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close_button.flat = true
	close_button.custom_minimum_size = ControlSize.square(ControlSize.xs)
	close_button.add_theme_font_size_override("font_size", Typography.label_medium)
	close_button.pressed.connect(on_tab_close_pressed.bind(index))
	close_button.gui_input.connect(on_tab_gui_input.bind(index))
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
	card.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(background, ControlSize.radius_md, Margin.ma_2, Margin.ma_1))
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
		dirty_label.modulate.a = 1.0 if tabs.files[index].is_dirty() else 0.0
	pass
