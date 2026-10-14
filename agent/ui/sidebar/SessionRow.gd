class_name SessionRow
extends PanelContainer

## One chat row: title, activity wave, close button, selection overlay and the inline rename field.
##
## The row renders what it is told — [AgentSessionSidebar] feeds it titles, selection and run
## state — and reports clicks back through signals, so nothing else needs to know how a row is
## built. The rename field is row-local state: opening, committing and discarding all happen here,
## and the host only has to ask [method is_renaming].

signal select_pressed(session_id: int)
signal delete_pressed(session_id: int)

## Close button and the activity wave share this slot, so swapping them while a run or compaction
## starts / stops never changes the row width (and never re-ellipsizes the title).
const ACTION_SIZE: Vector2 = Vector2(28, 28)
## Alpha of the floating row copy that follows the cursor while dragging.
const DRAG_GHOST_ALPHA: float = 0.92

var session_id: int = 0
var selected: bool = false
var hovered: bool = false

var title_button: Button
var delete_button: Button
var run_fx: SessionRowRunFx
var scifi_fx: SessionRowSciFiFx
## Live only while the row is being renamed; null otherwise.
var rename_field: LineEdit


func build(p_session_id: int, title: String) -> void:
	session_id = p_session_id
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_MOVE
	bind_hover(self)

	scifi_fx = SessionRowSciFiFx.new()
	scifi_fx.name = "SciFiFx"
	add_child(scifi_fx)

	# Inner box is transparent to the mouse, so the panel stays one big drag handle.
	var content: HBoxContainer = HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", Margin.ma_1)
	add_child(content)

	title_button = Button.new()
	title_button.text = title
	title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_button.focus_mode = Control.FOCUS_NONE
	title_button.flat = true
	title_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
	# Cut at the row width, character by character, without an ellipsis.
	title_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	title_button.pressed.connect(select_pressed.emit.bind(session_id))
	bind_hover(title_button)

	# The wave takes the close button's slot while this session runs or compacts.
	run_fx = SessionRowRunFx.new()
	run_fx.custom_minimum_size = ACTION_SIZE

	delete_button = Button.new()
	delete_button.text = "×"
	delete_button.tooltip_text = I18n.t("agent.sidebar.delete_chat")
	delete_button.custom_minimum_size = ACTION_SIZE
	delete_button.focus_mode = Control.FOCUS_NONE
	delete_button.flat = true
	delete_button.pressed.connect(delete_pressed.emit.bind(session_id))
	bind_hover(delete_button)

	content.add_child(title_button)
	content.add_child(run_fx)
	content.add_child(delete_button)
	apply_style()
	pass


# ---------------------------------------------------------------------------
# State — pushed in by the sidebar
# ---------------------------------------------------------------------------

func set_title(title: String) -> void:
	# A live rename owns the title until it is committed.
	if rename_field != null:
		return
	title_button.text = title
	pass


func set_running(running: bool) -> void:
	run_fx.set_running(running)
	delete_button.visible = not running
	pass


func set_selected(value: bool) -> void:
	selected = value
	apply_style()
	pass


func apply_style() -> void:
	add_theme_stylebox_override("panel", SessionSidebarTheme.row(selected, hovered))
	SessionSidebarTheme.apply_row_colors(title_button, delete_button, selected, hovered)
	scifi_fx.set_highlight(selected)
	# The rename field is themed with the rest, so switching theme mid-rename keeps it readable.
	if rename_field != null:
		SessionSidebarTheme.apply_rename_field(rename_field, title_button)
	pass


func apply_locale() -> void:
	delete_button.tooltip_text = I18n.t("agent.sidebar.delete_chat")
	if rename_field != null:
		rename_field.placeholder_text = I18n.t("agent.sidebar.chat_title")
	pass


func bind_hover(control: Control) -> void:
	control.mouse_entered.connect(on_mouse_entered)
	control.mouse_exited.connect(on_mouse_exited)
	pass


func on_mouse_entered() -> void:
	hovered = true
	apply_style()
	pass


## Moving between the row's own controls keeps the highlight; leaving the whole row drops it.
func on_mouse_exited() -> void:
	if get_global_rect().has_point(get_global_mouse_position()):
		return
	hovered = false
	apply_style()
	pass


# ---------------------------------------------------------------------------
# Inline rename
# ---------------------------------------------------------------------------

func is_renaming() -> bool:
	return rename_field != null


## Swaps the title button for a LineEdit in the same slot, so the row neither grows nor jumps.
## Enter / focus loss commit, Esc discards, a blank title keeps the previous name.
func open_rename() -> void:
	if rename_field != null:
		return
	var field: LineEdit = LineEdit.new()
	field.text = title_button.text
	field.placeholder_text = I18n.t("agent.sidebar.chat_title")
	field.max_length = AgentSessionManager.MAX_TITLE_LENGTH
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if title_button.size.y > 0.0:
		field.custom_minimum_size.y = title_button.size.y
	field.alignment = HORIZONTAL_ALIGNMENT_LEFT
	field.select_all_on_focus = true
	field.drag_and_drop_selection_enabled = false
	field.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	field.text_submitted.connect(func(_text: String) -> void: commit_rename())
	field.focus_exited.connect(commit_rename)
	field.gui_input.connect(on_rename_gui_input)
	SessionSidebarTheme.apply_rename_field(field, title_button)

	title_button.visible = false
	var content: Node = title_button.get_parent()
	content.add_child(field)
	content.move_child(field, title_button.get_index())
	rename_field = field
	# Deferred: the click that opened the field is still being handled here.
	field.call_deferred("grab_focus")
	pass


## Stores the typed title and puts the row back to its normal state. Wired to Enter, to focus loss
## (clicking another row, the chat input, …) and to the host's outside-click hook, so it has to be
## idempotent.
func commit_rename() -> void:
	if rename_field == null:
		return
	var title: String = rename_field.text
	close_rename_field()
	# A blank title is rejected by the manager, so the row falls back to its previous name.
	AgentSessionManager.set_title(session_id, title)
	pass


func cancel_rename() -> void:
	if rename_field == null:
		return
	# The single field is boxed: the title button still holds the stored name, so closing is all
	# that a discard needs.
	close_rename_field()
	pass


## Closes the field when the click landed outside it, keeping what was typed. The host calls this
## from its window mouse hook, because row buttons are [constant Control.FOCUS_NONE] — a click on
## another row never blurs the field, so focus loss alone cannot dismiss it.
## [param click_position] has to be in canvas coordinates, i.e. the space
## [method Control.get_global_rect] uses (see [method Control.get_global_mouse_position]).
func commit_rename_if_clicked_outside(click_position: Vector2) -> void:
	if rename_field == null or rename_field.get_global_rect().has_point(click_position):
		return
	commit_rename()
	pass


func on_rename_gui_input(event: InputEvent) -> void:
	if rename_field == null or not event.is_action_pressed("ui_cancel"):
		return
	var field: LineEdit = rename_field
	cancel_rename()
	field.accept_event()
	pass


## Drops the field first, so the focus loss it causes cannot re-enter the handlers above.
func close_rename_field() -> void:
	var field: LineEdit = rename_field
	rename_field = null
	if field == null:
		return
	# Hidden right away: the slot is handed back to the title button before the free lands.
	field.visible = false
	field.queue_free()
	title_button.visible = true
	pass


# ---------------------------------------------------------------------------
# Drag & drop — the sidebar binds the drag callbacks (see SessionRowDrag)
# ---------------------------------------------------------------------------

## Row padding, title and close button are all drag handles and drop targets.
func bind_drag_forwarding(get_data: Callable, can_drop: Callable, drop: Callable) -> void:
	for host: Control in [self, title_button, delete_button]:
		host.set_drag_forwarding(get_data, can_drop, drop)
	pass


## Floating copy of the row that follows the cursor until the mouse is released.
func build_drag_preview() -> Control:
	var row_size: Vector2 = size
	if row_size.x < 1.0 or row_size.y < 1.0:
		row_size = get_combined_minimum_size()

	var preview: Control = Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = row_size
	preview.size = row_size
	preview.modulate.a = DRAG_GHOST_ALPHA

	var ghost: PanelContainer = PanelContainer.new()
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.size = row_size
	ghost.add_theme_stylebox_override("panel", SessionSidebarTheme.drag_ghost())
	preview.add_child(ghost)

	var label: Label = Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = title_button.text
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_CHAR
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	SessionSidebarTheme.copy_font(label, title_button)
	label.add_theme_color_override("font_color", Colors.primary_text)
	ghost.add_child(label)

	# The engine moves `preview` to the cursor, so offset the ghost by the grab point — the cursor
	# can already sit a few pixels outside the row once the drag starts.
	var grab: Vector2 = get_local_mouse_position()
	ghost.position = -Vector2(clampf(grab.x, 0.0, row_size.x), clampf(grab.y, 0.0, row_size.y))
	return preview
