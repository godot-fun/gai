class_name DesktopToast
extends Window

## Desktop toast — a native, borderless, always-on-top OS window pinned to the bottom-right of
## the screen, so a message stays readable while the app window is behind other apps.
## `force_native` makes it a real system window without turning the app's dialogs into ones.
## It never activates and never joins Godot's popup list, so the app window keeps its input.
##
## Example: `DesktopToast.show_toast("Run finished", summary, ColorBase.success)`
## Pass a global [enum Corner] as the fourth argument to choose another screen corner.
## The card uses the [ThemeColor] surface with the per-toast accent color on its leading edge.

const CARD_WIDTH: float = 380.0
const MAX_BODY_LINES: int = 4
const SHOW_SECONDS: float = 4.5
## How long the app window stays above the others after the card is clicked.
const TOPMOST_MILLIS: int = 900

## Live toasts, oldest first — the newest one hugs the screen corner.
static var toasts: Array[DesktopToast] = []

var card: PanelContainer
var body_label: Label
## Card title and body text; `*_text` because [member Window.title] is already taken by the native [Window] base.
var title_text: String = ""
var body_text: String = ""
var accent: Color = ColorBase.info
var toast_corner: Corner = Corner.CORNER_BOTTOM_RIGHT


func _init() -> void:
	# A window must be hidden before `force_native` is assigned.
	visible = false
	force_native = true
	borderless = true
	unresizable = true
	always_on_top = true
	# Never steal focus, and stay out of the taskbar / alt-tab list: `unfocusable` alone is enough,
	# Windows gives a `WS_EX_NOACTIVATE` window neither a taskbar button nor an alt-tab entry.
	unfocusable = true
	# Deliberately not `popup_window`: Godot would add the toast to the DisplayServer popup list,
	# which redirects every key event to it and swallows each click landing outside the card — the
	# app window would look frozen for as long as the toast lives. It is a plain window instead:
	# click the card to dismiss it early, or let the auto-dismiss timer retire it.
	# Square card: Windows 11 would otherwise round (and clip) the window corners.
	sharp_corners = true
	pass


## Pop a toast in the selected [param corner], which defaults to the bottom-right.
## [param i18n_title] and [param i18n_body] may be translation keys; text without a registered
## translation is displayed unchanged.
static func show_toast(i18n_title: String, i18n_body: String, color: Color, corner: Corner = Corner.CORNER_BOTTOM_RIGHT) -> void:
	if gdf.gdf_node == null or not gdf.gdf_node.is_inside_tree():
		return
	var toast: DesktopToast = DesktopToast.new()
	toast.title_text = I18n.t(i18n_title)
	toast.body_text = I18n.t(i18n_body).strip_edges()
	toast.accent = color
	toast.toast_corner = corner
	toasts.append(toast)
	gdf.gdf_node.add_child(toast)
	pass


## Anchor in the requested corner of the usable screen area (taskbar excluded).
static func corner_position(window_size: Vector2i, corner: Corner = Corner.CORNER_BOTTOM_RIGHT) -> Vector2i:
	var screen: int = DisplayServer.window_get_current_screen(DisplayServer.MAIN_WINDOW_ID)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	var margin: int = roundi(Margin.ma_6 * DisplayScale.compute_ui_scale())
	var on_left: bool = corner == Corner.CORNER_TOP_LEFT or corner == Corner.CORNER_BOTTOM_LEFT
	var on_top: bool = corner == Corner.CORNER_TOP_LEFT or corner == Corner.CORNER_TOP_RIGHT
	var x: int = usable.position.x + margin if on_left else usable.end.x - window_size.x - margin
	var y: int = usable.position.y + margin if on_top else usable.end.y - window_size.y - margin
	return Vector2i(x, y)


## Bring the app window back: restore it when minimized, raise it when it is behind, then focus it.
static func activate_main_window() -> void:
	var window_id: int = DisplayServer.MAIN_WINDOW_ID
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode(window_id)
	if mode != DisplayServer.WINDOW_MODE_WINDOWED:
		# `ShowWindow()` behind a mode change is what restores and activates a hidden window; a plain
		# `window_move_to_foreground()` is refused by Windows while another app owns the foreground.
		# Godot drops the maximized flag while minimized, so the cached size decides that case.
		var restored: DisplayServer.WindowMode = mode
		if mode == DisplayServer.WINDOW_MODE_MINIMIZED:
			restored = DisplayServer.WINDOW_MODE_MAXIMIZED if covered_usable_screen(window_id) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(restored, window_id)
	# Raising to the top works even when the foreground change is denied; drop the flag right after
	# so the app does not stay above every other window.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true, window_id)
	DisplayServer.window_move_to_foreground(window_id)
	SchedulerBus.schedule(drop_topmost.bind(window_id), TOPMOST_MILLIS)
	pass


static func drop_topmost(window_id: int) -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false, window_id)
	pass


## True while the window covers the usable screen — either maximized or minimized from maximized,
## Godot drops the maximized flag while a window is minimized, so its cached size is all that is left.
static func covered_usable_screen(window_id: int) -> bool:
	var window_size: Vector2 = Vector2(DisplayServer.window_get_size_with_decorations(window_id))
	var usable: Vector2 = Vector2(DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen(window_id)).size)
	return window_size.x >= usable.x and window_size.y >= usable.y


## Stack each corner independently: top toasts grow downward and bottom toasts grow upward.
## Dismissed toasts leave [member toasts] first, so only a node freed behind our back can still
## show up here.
static func relayout() -> void:
	var top_left_offset: int = 0
	var top_right_offset: int = 0
	var bottom_left_offset: int = 0
	var bottom_right_offset: int = 0
	var gap: int = roundi(Margin.ma_3 * DisplayScale.compute_ui_scale())
	for i in range(toasts.size() - 1, -1, -1):
		var toast: DesktopToast = toasts[i]
		if not is_instance_valid(toast):
			continue
		var anchor: Vector2i = corner_position(toast.size, toast.toast_corner)
		match toast.toast_corner:
			Corner.CORNER_TOP_LEFT:
				toast.position = Vector2i(anchor.x, anchor.y + top_left_offset)
				top_left_offset += toast.size.y + gap
			Corner.CORNER_TOP_RIGHT:
				toast.position = Vector2i(anchor.x, anchor.y + top_right_offset)
				top_right_offset += toast.size.y + gap
			Corner.CORNER_BOTTOM_LEFT:
				toast.position = Vector2i(anchor.x, anchor.y - bottom_left_offset)
				bottom_left_offset += toast.size.y + gap
			Corner.CORNER_BOTTOM_RIGHT:
				toast.position = Vector2i(anchor.x, anchor.y - bottom_right_offset)
				bottom_right_offset += toast.size.y + gap
	pass


func _ready() -> void:
	build_card()
	# Controls only lay out inside a visible window, and the font-metric estimate cannot know how
	# the body wraps, so let the wrapping settle and then fit the window to the card.
	visible = true
	for _i in 3:
		if is_layout_settled():
			break
		await get_tree().process_frame
	fit_window_size()
	relayout()
	# Auto-dismiss. A connection, unlike an await, is dropped if the card is clicked first.
	get_tree().create_timer(SHOW_SECONDS).timeout.connect(close_toast)
	pass


## Body wrapping is done once the label got its real width from the container.
func is_layout_settled() -> bool:
	return body_label == null or body_label.size.x > 1.0


## Fit the window to the card, so a wrapped body is never clipped.
func fit_window_size() -> void:
	if not is_layout_settled():
		return
	size = Vector2i(size.x, roundi(card.get_combined_minimum_size().y))
	pass


func build_card() -> void:
	var unit: float = DisplayScale.compute_ui_scale()
	var pad: float = Margin.ma_5 * unit
	var card_width: float = CARD_WIDTH * unit
	var text_width: float = card_width - pad * 2.0
	var title_font: Font = Fonts.semibold()
	var body_font: Font = Fonts.regular()
	var title_size: int = roundi(Typography.title_medium_size * unit)
	var body_size: int = roundi(Typography.body_medium_size * unit)
	var gap: float = Margin.ma_2 * unit
	# First guess from font metrics; `fit_window_size` corrects it once the labels wrapped.
	var body_height: float = 0.0
	if StringUtils.is_not_blank(body_text):
		body_height = body_font.get_multiline_string_size(body_text, HORIZONTAL_ALIGNMENT_LEFT, text_width, body_size, MAX_BODY_LINES).y
	var card_height: float = pad * 2.0 + title_font.get_height(title_size) + (gap + body_height if body_height > 0.0 else 0.0)
	size = Vector2i(roundi(card_width), roundi(card_height))
	# Place it while it is still invisible, so the window never flashes at the tree origin.
	position = corner_position(size, toast_corner)

	card = PanelContainer.new()
	# The card with one accent stripe down the leading edge, everything scaled by the app UI scale.
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = ThemeColor.accent_surface
	card_style.content_margin_left = pad
	card_style.content_margin_right = pad
	card_style.content_margin_top = pad
	card_style.content_margin_bottom = pad
	card_style.border_color = accent
	card_style.set_border_width(SIDE_LEFT, roundi(ControlSize.border_md * unit))
	card.add_theme_stylebox_override("panel", card_style)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.gui_input.connect(on_card_input)
	add_child(card)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", roundi(gap))
	card.add_child(column)

	var title_label: Label = Label.new()
	title_label.text = title_text
	title_label.add_theme_font_override("font", title_font)
	title_label.add_theme_font_size_override("font_size", title_size)
	title_label.add_theme_color_override("font_color", ThemeColor.title_color)
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(title_label)

	if body_height > 0.0:
		body_label = Label.new()
		body_label.text = body_text
		body_label.add_theme_font_override("font", body_font)
		body_label.add_theme_font_size_override("font_size", body_size)
		body_label.add_theme_color_override("font_color", ThemeColor.body_color)
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.max_lines_visible = MAX_BODY_LINES
		body_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(body_label)
	pass


func close_toast() -> void:
	# Safe to run twice: erasing an absent element and queueing an already queued node are both no-ops,
	# so the card click and the auto-dismiss timer can race without a guard flag.
	toasts.erase(self)
	queue_free()
	DesktopToast.relayout()
	pass


func on_card_input(event: InputEvent) -> void:
	# Click anywhere on the card: open the app window and dismiss the toast early.
	if event is InputEventMouseButton and event.pressed:
		activate_main_window()
		close_toast()
	pass
