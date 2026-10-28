extends Control

## Unified visual-effect preview. Drives [VisualControl] by emitting real [AgentEvents]
## (same sequence as [AgentLoop]), with no direct effect-method calls.
##
## Effect buttons are grouped by function; each click creates a new agent session.
## Agent simulation payloads and playback live in [SimulateAgent].

const EFFECT_GROUPS: Array[Dictionary] = [
	{
		"title": "Agent core",
		"effects": [
			{"type": VisualControl.Type.JARVIS, "label": "Jarvis"},
			{"type": VisualControl.Type.TRANSFORMER, "label": "Transformer"},
		],
	},
	{
		"title": "Tools",
		"effects": [
			{"type": VisualControl.Type.REASONING_TREE, "label": "Reasoning Tree"},
			{"type": VisualControl.Type.TOOL_CONSTELLATION, "label": "Tool Constellation"},
			{"type": VisualControl.Type.CYBER_COMMAND_DECK, "label": "Cyber Command Deck"},
		],
	},
	{
		"title": "Context",
		"effects": [
			{"type": VisualControl.Type.CONTEXT_MEMORY_RIVER, "label": "Context Memory River"},
			{"type": VisualControl.Type.MATRIX_RAIN, "label": "Matrix Rain"},
		],
	},
	{
		"title": "Memory & semantics",
		"effects": [
			{"type": VisualControl.Type.NEURAL_AURORA, "label": "Neural Aurora"},
			{"type": VisualControl.Type.SEMANTIC_BLACK_HOLE, "label": "Semantic Black Hole"},
		],
	},
	{
		"title": "Systems & circuits",
		"effects": [
			{"type": VisualControl.Type.QUANTUM_CIRCUIT, "label": "Quantum Circuit"},
		],
	},
	{
		"title": "Motion & style",
		"effects": [
			{"type": VisualControl.Type.DESKTOP_CAT, "label": "Desktop Cat"},
			{"type": VisualControl.Type.GEOMETRIC_GENESIS, "label": "Geometric Genesis"},
			{"type": VisualControl.Type.FILTER_CAROUSEL, "label": "Filter Carousel"},
			{"type": VisualControl.Type.INK_LANDSCAPE, "label": "Ink Landscape"},
			{"type": VisualControl.Type.TAI_CHI, "label": "Tai Chi"},
			{"type": VisualControl.Type.PIANO_RHYTHM, "label": "Piano Rhythm"},
			{"type": VisualControl.Type.PIXEL_CITY, "label": "Pixel City"},
			{"type": VisualControl.Type.IMPOSSIBLE_ROOM, "label": "Impossible Room"},
			{"type": VisualControl.Type.TEMPORAL_PRISM, "label": "Temporal Prism"},
		],
	},
]

@onready var background: ColorRect = $Background
@onready var visual_control: VisualControl = $VisualOverlay/VisualControl
@onready var title_label: Label = $UiLayer/Scroll/Ui/Intro/Title
@onready var hint_label: Label = $UiLayer/Scroll/Ui/Intro/Hint
@onready var status_label: Label = $UiLayer/Scroll/Ui/Run/Status
@onready var stop_button: Button = $UiLayer/Scroll/Ui/Run/Controls/Stop
@onready var theme_color_select_node: Button = $UiLayer/Scroll/Ui/Run/Controls/ThemeColorSelect
@onready var theme_toggle_button: Button = $UiLayer/Scroll/Ui/Run/Controls/ThemeToggle
@onready var payload_label: Label = $UiLayer/Scroll/Ui/Run/Payload/PayloadLabel
@onready var small_payload_button: Button = $UiLayer/Scroll/Ui/Run/Payload/SmallPayload
@onready var large_payload_button: Button = $UiLayer/Scroll/Ui/Run/Payload/LargePayload
@onready var effects_label: Label = $UiLayer/Scroll/Ui/Effects/Label
@onready var effect_groups: VBoxContainer = $UiLayer/Scroll/Ui/Effects/Groups
var theme_toggle: ThemeToggle = ThemeToggle.new()
var theme_color_select: ThemeColorSelect = ThemeColorSelect.new()

var demo_generation: int = 0
var simulate_agent := SimulateAgent.new()
var play_buttons: Array[Button] = []
var section_labels: Array[Label] = []


func _ready() -> void:
	TransformerController.complete_animation_on_agent_end = true
	TaiChi.complete_animation_on_agent_end = true
	I18nHelper.init_i18n()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	AgentSessionManager.load_from_disk()
	theme_color_select.setup(theme_color_select_node)
	theme_toggle.setup(theme_toggle_button)
	setup_payload_buttons()
	build_effect_buttons()
	stop_button.pressed.connect(on_stop_pressed)
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	apply_theme()
	set_status("Pick an effect button to create an agent and stream simulated AgentEvents.")
	pass


func _exit_tree() -> void:
	TransformerController.complete_animation_on_agent_end = false
	TaiChi.complete_animation_on_agent_end = false
	pass


func setup_payload_buttons() -> void:
	var payload_group := ButtonGroup.new()
	small_payload_button.button_group = payload_group
	large_payload_button.button_group = payload_group
	small_payload_button.button_pressed = true
	small_payload_button.toggled.connect(on_payload_toggled)
	large_payload_button.toggled.connect(on_payload_toggled)
	pass


func on_payload_toggled(pressed: bool) -> void:
	if not pressed:
		return
	apply_theme()
	pass


func build_effect_buttons() -> void:
	for group: Dictionary in EFFECT_GROUPS:
		var heading := Label.new()
		heading.text = str(group["title"])
		section_labels.append(heading)
		effect_groups.add_child(heading)
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", Margin.ma_2)
		effect_groups.add_child(buttons)
		for spec: Dictionary in group["effects"]:
			var button := make_effect_button(str(spec["label"]), int(spec["type"]))
			buttons.add_child(button)
			play_buttons.append(button)
	pass


func make_effect_button(label: String, visual_type: int) -> Button:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void: start_demo(visual_type as VisualControl.Type, selected_turn_count(), selected_large_payload()))
	return button


func selected_large_payload() -> bool:
	return large_payload_button.button_pressed


func selected_turn_count() -> int:
	return SimulateAgent.LARGE_TURNS if selected_large_payload() else SimulateAgent.SMALL_TURNS


func apply_theme() -> void:
	background.color = Colors.app_background
	title_label.add_theme_font_override("font", Fonts.semibold())
	title_label.add_theme_font_size_override("font_size", Typography.title_large_size)
	title_label.add_theme_color_override("font_color", Colors.primary_text)
	for label: Label in [hint_label, status_label, payload_label, effects_label]:
		label.add_theme_font_override("font", Fonts.regular())
		label.add_theme_font_size_override("font_size", Typography.body_medium_size)
		label.add_theme_color_override("font_color", Colors.secondary_text)
	payload_label.add_theme_color_override("font_color", Colors.primary_text)
	for label: Label in section_labels:
		label.add_theme_font_override("font", Fonts.medium())
		label.add_theme_font_size_override("font_size", Typography.label_large_size)
		label.add_theme_color_override("font_color", Colors.primary_text)
	style_toolbar_button(stop_button)
	for button: Button in play_buttons:
		style_toolbar_button(button)
	for button: Button in [small_payload_button, large_payload_button]:
		style_payload_button(button)
	pass


func style_toolbar_button(button: Button) -> void:
	button.add_theme_font_override("font", Fonts.medium())
	button.add_theme_font_size_override("font_size", Typography.label_large_size)
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, Colors.subtle_border, ControlSize.border_xs)
	ButtonStyle.apply_style(button, normal,
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.promote(Colors.control_surface, Weights.w_2)),
		StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.demote(Colors.control_surface, Weights.w_2)))
	ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, ThemeColor.accent_theme_color())
	pass


func style_payload_button(button: Button) -> void:
	button.add_theme_font_override("font", Fonts.medium())
	button.add_theme_font_size_override("font_size", Typography.label_large_size)
	var normal := StyleBoxHelper.create_style_box_flat(Colors.control_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1, Colors.subtle_border, ControlSize.border_xs)
	var selected := StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.promote(Colors.control_surface, Weights.w_2), ThemeColor.accent_theme_color())
	if button.button_pressed:
		ButtonStyle.apply_style(button, selected, selected, selected)
		ButtonStyle.apply_font_colors(button, ThemeColor.accent_theme_color(), ThemeColor.accent_theme_color(), ThemeColor.accent_theme_color())
	else:
		ButtonStyle.apply_style(button, normal,
			StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.promote(Colors.control_surface, Weights.w_2)),
			StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.demote(Colors.control_surface, Weights.w_2)))
		ButtonStyle.apply_font_colors(button, Colors.secondary_text, Colors.primary_text, ThemeColor.accent_theme_color())
	pass


func set_status(text: String) -> void:
	status_label.text = text
	pass


func on_stop_pressed() -> void:
	stop_demo("Stopped.", true)
	pass


func start_demo(visual_type: VisualControl.Type, turn_count: int, large: bool) -> void:
	select_visual(visual_type)
	var session := AgentSessionManager.create_session()
	simulate_agent.active_session_ids.append(session.id)
	var generation := demo_generation
	var is_active := func() -> bool: return demo_generation == generation
	await simulate_agent.run_agent_events(self, session.id, turn_count, large, is_active, set_status, visual_label())
	var session_ids: Array[int] = [session.id]
	simulate_agent.delete_sessions(session_ids)
	pass


func select_visual(visual_type: VisualControl.Type) -> void:
	if AgentSetting.get_visual_type() != visual_type:
		AgentSetting.set_visual_type(visual_type as int)
	pass


func stop_demo(status_text: String, as_error: bool = false) -> void:
	demo_generation += 1
	var session_ids := simulate_agent.active_session_ids.duplicate()
	if as_error:
		for session_id: int in session_ids:
			if session_id != 0:
				AgentEvents.events.agent_end.emit(session_id, "Stop.")
	simulate_agent.delete_sessions(session_ids)
	if StringUtils.is_not_blank(status_text):
		set_status(status_text)
	pass


func visual_label() -> String:
	var visual_type := AgentSetting.get_visual_type()
	for group: Dictionary in EFFECT_GROUPS:
		for spec: Dictionary in group["effects"]:
			if spec["type"] == visual_type:
				return str(spec["label"])
	return "None"
