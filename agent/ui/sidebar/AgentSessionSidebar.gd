class_name AgentSessionSidebar
extends RefCounted

## Left sidebar — pinned + normal session lists with select / delete / drag reorder.
##
## Wiring only: rows are [SessionRow] nodes, styling is [SessionSidebarTheme] and drag & drop is
## [SessionRowDrag]. The outside-click handling of an open rename rides on the window input hook
## (see [method on_window_input]).

var pinned_header: Label
var pinned_list: VBoxContainer
var pinned_separator: HSeparator
var normal_header: Label
var normal_list: VBoxContainer
var session_list_scroll: ScrollContainer
var new_session_button: Button
var sidebar_panel: PanelContainer

var session_rows: Dictionary[int, SessionRow] = {}
var drag := SessionRowDrag.new()


# ---------------------------------------------------------------------------
# Setup & theme
# ---------------------------------------------------------------------------

func setup(
	p_pinned_header: Label,
	p_pinned_list: VBoxContainer,
	p_pinned_separator: HSeparator,
	p_normal_header: Label,
	p_normal_list: VBoxContainer,
	p_session_list_scroll: ScrollContainer,
	p_new_session_button: Button,
	p_sidebar_panel: PanelContainer
) -> void:
	pinned_header = p_pinned_header
	pinned_list = p_pinned_list
	pinned_separator = p_pinned_separator
	normal_header = p_normal_header
	normal_list = p_normal_list
	session_list_scroll = p_session_list_scroll
	new_session_button = p_new_session_button
	sidebar_panel = p_sidebar_panel
	drag.setup(session_rows, pinned_list, normal_list)

	new_session_button.pressed.connect(on_new_session_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)
	AgentEvents.events.session_added.connect(on_session_added)
	AgentEvents.events.session_removed.connect(remove_row)
	AgentEvents.events.session_selected.connect(select_item)
	AgentEvents.events.session_title_changed.connect(on_session_refresh)
	AgentEvents.events.agent_start.connect(on_session_refresh)
	AgentEvents.events.session_stop.connect(on_session_refresh)
	AgentEvents.events.workspace_changed.connect(on_workspace_changed)

	# Lists and headers are drop targets — the padding between rows has to accept a drop too.
	pinned_header.mouse_filter = Control.MOUSE_FILTER_PASS
	normal_header.mouse_filter = Control.MOUSE_FILTER_PASS
	drag.bind_list(pinned_list, true)
	drag.bind_list(pinned_header, true)
	drag.bind_list(normal_list, false)
	drag.bind_list(normal_header, false)

	# Rows are appended, moved between sections and freed from several places, so the separator and
	# the unpin drop pad follow the lists themselves instead of every caller remembering to ask.
	for list: VBoxContainer in [pinned_list, normal_list]:
		list.child_entered_tree.connect(on_section_changed)
		list.child_exiting_tree.connect(on_section_changed)
	# Any click outside the open rename field closes it: row buttons never take the focus, so
	# focus loss cannot do it. Same window-level hook the chat input uses for outside clicks.
	sidebar_panel.get_window().window_input.connect(on_window_input)

	apply_theme()
	pass


func on_session_refresh(session_id: int, _arg: Variant = null) -> void:
	refresh_item(session_id)
	pass


func on_workspace_changed(_path: String) -> void:
	reload_sessions()
	pass


func apply_theme() -> void:
	sidebar_panel.add_theme_stylebox_override("panel", SessionSidebarTheme.sidebar_panel())
	pinned_header.add_theme_color_override("font_color", ColorBase.secondary_text)
	normal_header.add_theme_color_override("font_color", ColorBase.secondary_text)
	pinned_separator.add_theme_stylebox_override("separator", SessionSidebarTheme.pinned_separator())
	ScrollBarStyle.apply(session_list_scroll.get_v_scroll_bar())
	SessionSidebarTheme.apply_new_session_button(new_session_button)
	for row: SessionRow in session_rows.values():
		row.apply_style()
	pass


func apply_locale() -> void:
	pinned_header.text = I18n.t("agent.sidebar.pinned")
	normal_header.text = I18n.t("agent.sidebar.chats")
	new_session_button.text = I18n.t("agent.sidebar.new_session")
	for row: SessionRow in session_rows.values():
		row.apply_locale()
	pass


# ---------------------------------------------------------------------------
# List rebuild & refresh
# ---------------------------------------------------------------------------

## Sessions are stored under the workspace root, so switching workspace swaps the whole set.
func reload_sessions() -> void:
	AgentSessionManager.load_from_disk()
	rebuild()
	pass


func rebuild() -> void:
	clear()
	for session_index: AgentSessionIndexes.SessionIndex in AgentSessionManager.session_indexes.pinned_indexes:
		append_row(session_index.id, session_index.title, true)
	for session_index: AgentSessionIndexes.SessionIndex in AgentSessionManager.session_indexes.indexes:
		append_row(session_index.id, session_index.title, false)
	select_item(AgentSessionManager.active_session_id)
	pass


func refresh_item(session_id: int) -> void:
	var row: SessionRow = session_rows.get(session_id)
	if row == null:
		return
	# A live rename owns the title until it is committed; the run state still refreshes.
	row.set_title(AgentSessionManager.get_title(session_id))
	row.set_running(RuntimeManager.is_running(session_id))
	pass


## Only the row that lost the selection and the one that gained it need a restyle —
## the rest are already styled when they are built.
func select_item(session_id: int, previous_session_id: int = 0) -> void:
	# Covers selection changes that no click triggered (e.g. the fallback after a delete).
	commit_open_rename()
	refresh_item(session_id)
	set_row_selected(previous_session_id, false)
	set_row_selected(session_id, true)
	pass


func set_row_selected(session_id: int, selected: bool) -> void:
	var row: SessionRow = session_rows.get(session_id)
	if row != null:
		row.set_selected(selected)
	pass


## A row entered / left one of the lists — settle the sections once the tree has stopped moving.
## [signal Node.child_exiting_tree] still counts the leaving row, and a section move fires both
## signals in a row, so this has to wait for the end of the frame.
func on_section_changed(_node: Node) -> void:
	sync_sections.call_deferred()
	pass


func sync_sections() -> void:
	var has_pinned := pinned_list.get_child_count() > 0
	var has_normal := normal_list.get_child_count() > 0
	pinned_separator.visible = has_pinned and has_normal
	# An empty Chats list has no row hit target — keep a small drop pad when unpinning is possible.
	normal_list.custom_minimum_size = Vector2(0, 40) if has_pinned and not has_normal else Vector2.ZERO
	pass


# ---------------------------------------------------------------------------
# Rows — build, refresh, remove
# ---------------------------------------------------------------------------

func append_row(session_id: int, title: String, pinned: bool) -> void:
	var row := SessionRow.new()
	row.build(session_id, title)
	row.select_pressed.connect(on_session_row_pressed)
	row.delete_pressed.connect(on_session_delete_pressed)
	drag.list_for_pinned(pinned).add_child(row)
	# Registered before the refresh: refresh looks rows up by session id.
	session_rows[session_id] = row
	drag.bind_row(row)
	refresh_item(session_id)
	pass


func remove_row(session_id: int) -> void:
	var row: SessionRow = session_rows.get(session_id)
	if row == null:
		return
	row.queue_free()
	session_rows.erase(session_id)
	pass


func clear() -> void:
	for list: VBoxContainer in [pinned_list, normal_list]:
		for child in list.get_children():
			child.queue_free()
	session_rows.clear()
	pass


# ---------------------------------------------------------------------------
# Event handlers
# ---------------------------------------------------------------------------

func on_session_added(session_id: int, title: String) -> void:
	append_row(session_id, title, false)
	normal_list.move_child(session_rows[session_id], 0)
	pass


func on_new_session_pressed() -> void:
	var session := AgentSessionManager.create_session()
	AgentSessionManager.select_session(session.id)
	pass


func on_session_row_pressed(session_id: int) -> void:
	# Clicking the chat that is already open starts renaming it instead of re-opening it.
	if AgentSessionManager.is_active(session_id):
		begin_rename(session_id)
		return
	AgentSessionManager.select_session(session_id)
	pass


func on_session_delete_pressed(session_id: int) -> void:
	AgentSessionManager.delete_session(session_id)
	pass


# ---------------------------------------------------------------------------
# Inline rename — click the open chat again to edit its title where the title sits
# ---------------------------------------------------------------------------

## The field lives in the row, so "is anything being renamed" is asked, never mirrored here.
func begin_rename(session_id: int) -> void:
	var row: SessionRow = session_rows.get(session_id)
	if row == null or row.is_renaming():
		return
	commit_open_rename()
	row.open_rename()
	pass


## Commits the open rename, if any. Rows are few and [method SessionRow.commit_rename] no-ops on
## rows that are not editing, so sweeping them beats tracking which one is open.
func commit_open_rename() -> void:
	for row: SessionRow in session_rows.values():
		row.commit_rename()
	pass


## A click that never moved the focus (row buttons, toolbars, empty areas) still has to close the
## field. Window input coordinates do not share the canvas transform of
## [method Control.get_global_rect] while the viewport is stretched, so the mouse is read through
## a control — the same trick as [method AgentChatInput.on_global_input].
func on_window_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not (event as InputEventMouseButton).pressed:
		return
	var click_position := sidebar_panel.get_global_mouse_position()
	for row: SessionRow in session_rows.values():
		row.commit_rename_if_clicked_outside(click_position)
	pass
