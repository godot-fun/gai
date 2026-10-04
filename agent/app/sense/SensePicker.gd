class_name SensePicker
extends Window

## Always-on-top candidate sheet for sense input. Briefly steals focus for ↑↓ / Enter / Esc,
## then [method NativeOS.restore_foreground_window] before paste so Ctrl+V hits the target app.
## ↑↓ walks ready entries and the cancel row; Enter confirms; 1–5 / keypad jump to a ready slot; Esc cancels.
## Drag the title to move; slots fill in as each candidate arrives (voice first, then compose / diverge).

signal finished(text: String)

const SLOT_COUNT := 5
const MAX_BODY_LINES := 4
## Left badge column width at 2K (number + two-char label); scaled by [member screen_scale].
const BADGE_WIDTH := 64.0
## Card / row fill alpha on the transparent native window (see through to the desktop).
const CARD_ALPHA := 0.88
const ROW_ALPHA := 0.92

const SLOT_VOICE := 0
const SLOT_CORRECT := 1
const SLOT_OPTIMIZE := 2
const SLOT_EXPAND := 3
const SLOT_DIVERGE := 4
## Synthetic index for the cancel row in ↑↓ / Enter navigation (not a candidate slot).
const SLOT_CANCEL := 5

static var instance: SensePicker = null

var anchor: Vector2i = Vector2i.ZERO
## Scale vs 2K ([method DisplayScale.compute_screen_scale]) — wave band, fonts, and margins share it.
var screen_scale: float = 1.0
var card: PanelContainer
var entries_column: VBoxContainer
var closed: bool = false
## True after the user drags the title; later size fits keep the moved position.
var user_moved: bool = false
var dragging: bool = false
## Screen mouse position minus window position at drag start.
var drag_grab: Vector2i = Vector2i.ZERO

var entry_labels: PackedStringArray = PackedStringArray()
var entry_texts: PackedStringArray = PackedStringArray()
var entry_ready: Array[bool] = []
## True when a slot finished with no candidate (stops [code]pick_pending[/code]; not clickable).
var entry_skipped: Array[bool] = []
var body_labels: Array[Label] = []
var entry_rows: Array[PanelContainer] = []
var row_normal_styles: Array[StyleBoxFlat] = []
var row_hover_styles: Array[StyleBoxFlat] = []
var row_selected_styles: Array[StyleBoxFlat] = []
var cancel_row: PanelContainer
var cancel_label: Label
var cancel_normal_style: StyleBoxFlat
var cancel_hover_style: StyleBoxFlat
var cancel_selected_style: StyleBoxFlat
## Ready slot index, [constant SLOT_CANCEL], or `-1` when none.
var selected_index: int = -1
## Row under the mouse (entry index or [constant SLOT_CANCEL]).
var hovered_index: int = -1


func _init() -> void:
	visible = false
	force_native = true
	borderless = true
	transparent = true
	unresizable = true
	always_on_top = true
	# Focusable so ↑↓ / Enter / Esc work; restore the target app before paste.
	unfocusable = false
	sharp_corners = true
	entry_labels.resize(SLOT_COUNT)
	entry_texts.resize(SLOT_COUNT)
	entry_ready.resize(SLOT_COUNT)
	entry_skipped.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		entry_ready[i] = false
		entry_skipped[i] = false
	pass


## Open an empty five-slot sheet near [param screen_anchor]. Caller awaits [signal finished].
static func open(screen_anchor: Vector2i) -> SensePicker:
	dismiss()
	if gdf.gdf_node == null or not gdf.gdf_node.is_inside_tree():
		return null
	# Capture the typing target before this Window steals activation.
	if Engine.has_singleton("NativeOS"):
		NativeOS.remember_foreground_window()
	instance = SensePicker.new()
	instance.anchor = screen_anchor
	instance.entry_labels[SLOT_VOICE] = I18n.t("agent.sense.label_voice")
	instance.entry_labels[SLOT_CORRECT] = I18n.t("agent.sense.label_correct")
	instance.entry_labels[SLOT_OPTIMIZE] = I18n.t("agent.sense.label_optimize")
	instance.entry_labels[SLOT_EXPAND] = I18n.t("agent.sense.label_expand")
	instance.entry_labels[SLOT_DIVERGE] = I18n.t("agent.sense.label_diverge")
	gdf.gdf_node.add_child(instance)
	return instance


static func dismiss() -> void:
	if instance != null and is_instance_valid(instance):
		instance.close_picker(StringUtils.EMPTY)
	pass


static func is_open() -> bool:
	return instance != null and is_instance_valid(instance)


## Screen-space top-left aligned with the wave overlay: same width / offset / top edge.
## [param window_size].y is ignored for placement — vertical pin uses scaled wave height so the
## picker grows downward from where the sine wave sat.
static func window_position_for_anchor(screen_anchor: Vector2i, window_size: Vector2i, scale: float = 1.0) -> Vector2i:
	var wave_h := maxi(1, roundi(float(SenseWave.WAVE_HEIGHT) * scale))
	return SenseWave.window_position_for_cursor(screen_anchor, Vector2i(window_size.x, wave_h))


## Fill or replace slot [param index] once that candidate is ready. No-op after close.
func set_entry(index: int, text: String) -> void:
	if closed or index < 0 or index >= SLOT_COUNT:
		return
	var value := text.strip_edges()
	entry_texts[index] = value
	entry_ready[index] = StringUtils.is_not_blank(value)
	entry_skipped[index] = false
	if body_labels.size() > index:
		body_labels[index].text = value if entry_ready[index] else I18n.t("agent.sense.pick_pending")
		body_labels[index].add_theme_color_override(
			"font_color",
			ThemeColor.body_color if entry_ready[index] else ColorBase.secondary_text)
		entry_rows[index].mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND if entry_ready[index] else Control.CURSOR_ARROW)
		refresh_entry_row_style(index)
	if entry_ready[index] and selected_index < 0:
		set_selected_index(index)
	fit_window_size()
	pass


## Mark slot finished with no text (not clickable). Clears the forever-[code]pick_pending[/code] hang.
func skip_entry(index: int) -> void:
	if closed or index < 0 or index >= SLOT_COUNT:
		return
	entry_texts[index] = StringUtils.EMPTY
	entry_ready[index] = false
	entry_skipped[index] = true
	if body_labels.size() > index:
		body_labels[index].text = I18n.t("agent.sense.pick_skipped")
		body_labels[index].add_theme_color_override("font_color", ColorBase.secondary_text)
		entry_rows[index].mouse_default_cursor_shape = Control.CURSOR_ARROW
		refresh_entry_row_style(index)
	if selected_index == index:
		set_selected_index(find_nearest_ready(index))
	fit_window_size()
	pass


## Voice row when ASR produced nothing; screen-driven compose can still fill the remaining rows.
func skip_voice_slot() -> void:
	skip_entry(SLOT_VOICE)
	pass


func _ready() -> void:
	screen_scale = DisplayScale.compute_screen_scale(anchor)
	get_viewport().transparent_bg = true
	build_card()
	visible = true
	for _i in 3:
		if is_layout_settled():
			break
		await get_tree().process_frame
	fit_window_size()
	grab_focus()
	pass


func _unhandled_input(event: InputEvent) -> void:
	if closed or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ESCAPE:
			close_picker(StringUtils.EMPTY)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER:
			confirm_selection()
			get_viewport().set_input_as_handled()
		KEY_UP:
			move_selection(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			move_selection(1)
			get_viewport().set_input_as_handled()
		KEY_1, KEY_KP_1:
			confirm_slot(0)
			get_viewport().set_input_as_handled()
		KEY_2, KEY_KP_2:
			confirm_slot(1)
			get_viewport().set_input_as_handled()
		KEY_3, KEY_KP_3:
			confirm_slot(2)
			get_viewport().set_input_as_handled()
		KEY_4, KEY_KP_4:
			confirm_slot(3)
			get_viewport().set_input_as_handled()
		KEY_5, KEY_KP_5:
			confirm_slot(4)
			get_viewport().set_input_as_handled()
	pass


func is_layout_settled() -> bool:
	return card != null and card.get_combined_minimum_size().y > 1.0


func fit_window_size() -> void:
	if not is_layout_settled():
		return
	size = Vector2i(size.x, roundi(card.get_combined_minimum_size().y))
	if user_moved:
		position = clamp_to_usable(position, size)
	else:
		position = clamp_to_usable(window_position_for_anchor(anchor, size, screen_scale), size)
	pass


func clamp_to_usable(pos: Vector2i, window_size: Vector2i) -> Vector2i:
	var screen := DisplayServer.get_screen_from_rect(Rect2(Vector2(pos), Vector2(maxi(1, window_size.x), maxi(1, window_size.y))))
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var margin := roundi(Margin.ma_2 * screen_scale)
	var x := clampi(pos.x, usable.position.x + margin, usable.end.x - window_size.x - margin)
	var y := clampi(pos.y, usable.position.y + margin, usable.end.y - window_size.y - margin)
	return Vector2i(x, y)


## Title-bar drag: poll global mouse so motion still tracks when the cursor leaves the label.
func _process(_delta: float) -> void:
	if not dragging or closed:
		set_process(false)
		dragging = false
		return
	if (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT) == 0:
		dragging = false
		set_process(false)
		return
	user_moved = true
	position = clamp_to_usable(DisplayServer.mouse_get_position() - drag_grab, size)
	pass


func on_title_gui_input(event: InputEvent) -> void:
	if closed or not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse.pressed:
		dragging = true
		drag_grab = DisplayServer.mouse_get_position() - position
		set_process(true)
	else:
		dragging = false
		set_process(false)
	pass


func build_card() -> void:
	var pad := Margin.ma_5 * screen_scale
	var card_width := float(SenseWave.WAVE_WIDTH) * screen_scale
	var title_font := Fonts.semibold()
	var body_font := Fonts.regular()
	var title_size := roundi(Typography.title_medium_size * screen_scale)
	var label_size := roundi(Typography.label_large_size * screen_scale)
	var body_size := roundi(Typography.body_large_size * screen_scale)
	var gap := Margin.ma_3 * screen_scale
	size = Vector2i(roundi(card_width), roundi(pad * 2.0 + title_font.get_height(title_size)))
	position = clamp_to_usable(window_position_for_anchor(anchor, size, screen_scale), size)

	card = PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(ThemeColor.accent_surface, CARD_ALPHA)
	card_style.content_margin_left = pad
	card_style.content_margin_right = pad
	card_style.content_margin_top = pad
	card_style.content_margin_bottom = pad
	card_style.border_color = ThemeColor.accent_theme_color()
	card_style.set_border_width(SIDE_LEFT, roundi(ControlSize.border_md * screen_scale))
	card_style.set_corner_radius_all(roundi(ControlSize.radius_md * screen_scale))
	card.add_theme_stylebox_override("panel", card_style)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(card)

	entries_column = VBoxContainer.new()
	entries_column.add_theme_constant_override("separation", roundi(gap))
	card.add_child(entries_column)

	var title_label := Label.new()
	title_label.text = I18n.t("agent.sense.pick_title")
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.mouse_default_cursor_shape = Control.CURSOR_MOVE
	title_label.add_theme_font_override("font", title_font)
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.add_theme_color_override("font_color", ThemeColor.title_color)
	title_label.gui_input.connect(on_title_gui_input)
	entries_column.add_child(title_label)

	body_labels.clear()
	entry_rows.clear()
	row_normal_styles.clear()
	row_hover_styles.clear()
	row_selected_styles.clear()
	for i in SLOT_COUNT:
		var row := make_entry_row(i, label_size, body_size, body_font)
		entries_column.add_child(row)
		entry_rows.append(row)

	entries_column.add_child(make_cancel_row(label_size))
	# Apply any set_entry / skip_entry calls that raced ahead of _ready.
	for i in SLOT_COUNT:
		if entry_ready[i]:
			set_entry(i, entry_texts[i])
		elif entry_skipped[i]:
			skip_entry(i)
	pass


func make_entry_row(index: int, label_size: int, body_size: int, body_font: Font) -> PanelContainer:
	var row := PanelContainer.new()
	var radius := roundi(ControlSize.radius_sm * screen_scale)
	var row_bg := Color(ThemeColor.card_surface, ROW_ALPHA)
	var normal := StyleBoxHelper.create_style_box_flat(row_bg, radius, Margin.ma_4, Margin.ma_3, ColorBase.subtle_border, ControlSize.border_xs)
	var hover := StyleBoxHelper.create_style_box_flat(ButtonStyle.hover_color(row_bg, 0.08), radius, Margin.ma_4, Margin.ma_3, ThemeColor.accent_theme_color(), ControlSize.border_xs)
	var selected := StyleBoxHelper.create_style_box_flat(ButtonStyle.hover_color(row_bg, 0.14), radius, Margin.ma_4, Margin.ma_3, ThemeColor.accent_theme_color(), ControlSize.border_sm)
	row_normal_styles.append(normal)
	row_hover_styles.append(hover)
	row_selected_styles.append(selected)
	row.add_theme_stylebox_override("panel", normal)
	row.mouse_default_cursor_shape = Control.CURSOR_ARROW
	row.mouse_entered.connect(func() -> void:
		hovered_index = index
		if entry_ready[index]:
			set_selected_index(index)
		else:
			refresh_entry_row_style(index)
	)
	row.mouse_exited.connect(func() -> void:
		if hovered_index == index:
			hovered_index = -1
		refresh_entry_row_style(index)
	)
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_entry_pressed(index)
	)

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", roundi(Margin.ma_3 * screen_scale))
	row.add_child(hbox)

	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.text = StringUtils.format("{} {}", index + 1, entry_labels[index])
	badge.add_theme_font_override("font", Fonts.semibold())
	badge.add_theme_font_size_override("font_size", label_size)
	badge.add_theme_color_override("font_color", ThemeColor.accent_theme_color())
	badge.custom_minimum_size = Vector2(roundi(BADGE_WIDTH * screen_scale), 0.0)
	hbox.add_child(badge)

	var body := Label.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.text = I18n.t("agent.sense.pick_pending")
	body.add_theme_font_override("font", body_font)
	body.add_theme_font_size_override("font_size", body_size)
	body.add_theme_color_override("font_color", ColorBase.secondary_text)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.max_lines_visible = MAX_BODY_LINES
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(body)
	body_labels.append(body)
	return row


func make_cancel_row(label_size: int) -> PanelContainer:
	var row := PanelContainer.new()
	var radius := roundi(ControlSize.radius_sm * screen_scale)
	var row_bg := Color(ThemeColor.card_surface, ROW_ALPHA)
	cancel_normal_style = StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT, radius, Margin.ma_3, Margin.ma_2)
	cancel_hover_style = StyleBoxHelper.create_style_box_flat(ButtonStyle.hover_color(row_bg, 0.08), radius, Margin.ma_3, Margin.ma_2, ThemeColor.accent_theme_color(), ControlSize.border_xs)
	cancel_selected_style = StyleBoxHelper.create_style_box_flat(ButtonStyle.hover_color(row_bg, 0.14), radius, Margin.ma_3, Margin.ma_2, ThemeColor.accent_theme_color(), ControlSize.border_sm)
	row.add_theme_stylebox_override("panel", cancel_normal_style)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			close_picker(StringUtils.EMPTY)
	)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = I18n.t("agent.sense.pick_cancel")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Fonts.regular())
	label.add_theme_font_size_override("font_size", label_size)
	label.add_theme_color_override("font_color", ColorBase.secondary_text)
	row.add_child(label)
	cancel_row = row
	cancel_label = label
	row.mouse_entered.connect(func() -> void:
		hovered_index = SLOT_CANCEL
		set_selected_index(SLOT_CANCEL)
	)
	row.mouse_exited.connect(func() -> void:
		if hovered_index == SLOT_CANCEL:
			hovered_index = -1
		refresh_cancel_row_style()
	)
	return row


func set_selected_index(index: int) -> void:
	var previous := selected_index
	if index == SLOT_CANCEL:
		pass
	elif index >= 0 and (index >= SLOT_COUNT or not entry_ready[index]):
		index = -1
	selected_index = index
	refresh_selection_style(previous)
	refresh_selection_style(selected_index)
	pass


func move_selection(delta: int) -> void:
	var nav_indices := navigable_indices()
	if nav_indices.is_empty():
		return
	var pos := nav_indices.find(selected_index)
	if pos < 0:
		set_selected_index(nav_indices[0] if delta > 0 else nav_indices[nav_indices.size() - 1])
		return
	pos = (pos + delta) % nav_indices.size()
	if pos < 0:
		pos += nav_indices.size()
	set_selected_index(nav_indices[pos])
	pass


## Ready candidate slots plus the cancel row (always last).
func navigable_indices() -> Array[int]:
	var indices: Array[int] = []
	for i in SLOT_COUNT:
		if entry_ready[i]:
			indices.append(i)
	indices.append(SLOT_CANCEL)
	return indices


func find_nearest_ready(from_index: int) -> int:
	for i in range(from_index, SLOT_COUNT):
		if entry_ready[i]:
			return i
	for i in range(from_index - 1, -1, -1):
		if entry_ready[i]:
			return i
	return -1


func refresh_selection_style(index: int) -> void:
	if index == SLOT_CANCEL:
		refresh_cancel_row_style()
	elif index >= 0 and index < entry_rows.size():
		refresh_entry_row_style(index)
	pass


func refresh_entry_row_style(index: int) -> void:
	if index < 0 or index >= entry_rows.size():
		return
	var style: StyleBoxFlat = row_normal_styles[index]
	if selected_index == index:
		style = row_selected_styles[index]
	elif hovered_index == index and entry_ready[index]:
		style = row_hover_styles[index]
	entry_rows[index].add_theme_stylebox_override("panel", style)
	pass


func refresh_cancel_row_style() -> void:
	if cancel_row == null or cancel_label == null:
		return
	var style: StyleBoxFlat = cancel_normal_style
	var font_color := ColorBase.secondary_text
	if selected_index == SLOT_CANCEL:
		style = cancel_selected_style
		font_color = ThemeColor.body_color
	elif hovered_index == SLOT_CANCEL:
		style = cancel_hover_style
		font_color = ThemeColor.body_color
	cancel_row.add_theme_stylebox_override("panel", style)
	cancel_label.add_theme_color_override("font_color", font_color)
	pass


func confirm_selection() -> void:
	if selected_index == SLOT_CANCEL:
		close_picker(StringUtils.EMPTY)
		return
	confirm_slot(selected_index)
	pass


## Confirm slot [param index] when ready (keyboard digit / Enter / click). No-op if pending or skipped.
func confirm_slot(index: int) -> void:
	if closed or index < 0 or index >= SLOT_COUNT:
		return
	if not entry_ready[index]:
		return
	close_picker(entry_texts[index])
	pass


func on_entry_pressed(index: int) -> void:
	confirm_slot(index)
	pass


func close_picker(text: String) -> void:
	if closed:
		return
	closed = true
	if instance == self:
		instance = null
	# Return activation to the typing target before the caller pastes via Ctrl+V.
	if Engine.has_singleton("NativeOS"):
		NativeOS.restore_foreground_window()
	finished.emit(text)
	queue_free()
	pass
