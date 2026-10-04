extends Control

const PALETTE_LABEL_MAX: int = 30

@onready var body_split: HSplitContainer = $Root/Body
@onready var graph_edit: SkillGraphEdit = $Root/Body/SkillGraphEdit
@onready var toolbar: PanelContainer = $Root/Toolbar
@onready var toolbar_margin: MarginContainer = $Root/Toolbar/ToolbarMargin
@onready var toolbar_row: HBoxContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow
@onready var logo_label: Label = $Root/Toolbar/ToolbarMargin/ToolbarRow/Logo
@onready var title_label: Label = $Root/Toolbar/ToolbarMargin/ToolbarRow/Title
@onready var actions: HBoxContainer = $Root/Toolbar/ToolbarMargin/ToolbarRow/Actions
@onready var sidebar: PanelContainer = $Root/Body/Sidebar
@onready var sidebar_margin: MarginContainer = $Root/Body/Sidebar/SidebarMargin
@onready var palette_vbox: VBoxContainer = $Root/Body/Sidebar/SidebarMargin/PaletteVBox
@onready var palette_scroll: ScrollContainer = $Root/Body/Sidebar/SidebarMargin/PaletteVBox/PaletteScroll
@onready var palette_tree: Tree = $Root/Body/Sidebar/SidebarMargin/PaletteVBox/PaletteScroll/PaletteTree
@onready var palette_title: Label = $Root/Body/Sidebar/SidebarMargin/PaletteVBox/PaletteTitle
@onready var palette_hint: Label = $Root/Body/Sidebar/SidebarMargin/PaletteVBox/PaletteHint
@onready var new_button: Button = $Root/Toolbar/ToolbarMargin/ToolbarRow/Actions/NewButton
@onready var load_button: Button = $Root/Toolbar/ToolbarMargin/ToolbarRow/Actions/LoadButton
@onready var save_button: Button = $Root/Toolbar/ToolbarMargin/ToolbarRow/Actions/SaveButton
@onready var delete_button: Button = $Root/Toolbar/ToolbarMargin/ToolbarRow/Actions/DeleteButton
@onready var log_button: Button = $Root/Toolbar/ToolbarMargin/ToolbarRow/Actions/LogButton
@onready var run_button: Button = $Root/Toolbar/ToolbarMargin/ToolbarRow/Actions/RunButton
@onready var save_dialog: FileDialog = $SaveDialog
@onready var load_dialog: FileDialog = $LoadDialog

var pipeline_runner: PipelineRunner = PipelineRunner.new()

var running_pipeline: bool = false


func _ready() -> void:
	I18nHelper.init_i18n()
	var app_theme := Theme.new()
	app_theme.default_font = Fonts.regular()
	theme = app_theme
	save_dialog.add_theme_font_override("title_font", Fonts.regular())
	load_dialog.add_theme_font_override("title_font", Fonts.regular())
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	configure_sidebar_layout()
	configure_dialog_layout()
	apply_theme()
	apply_ui_locale()
	set_workflow_name(WorkflowManager.workflow_name)
	style_run_button()
	build_palette_tree()

	new_button.pressed.connect(on_new_pressed)
	save_button.pressed.connect(on_save_pressed)
	load_button.pressed.connect(on_load_pressed)
	run_button.pressed.connect(on_run_pressed)
	delete_button.pressed.connect(on_delete_pressed)
	log_button.pressed.connect(on_log_pressed)

	palette_tree.item_selected.connect(on_palette_item_selected)
	palette_tree.item_activated.connect(on_palette_item_activated)

	save_dialog.file_selected.connect(on_save_file_selected)
	load_dialog.file_selected.connect(on_load_file_selected)

	WorkflowEvents.events.step_started.connect(on_step_started)
	WorkflowEvents.events.step_finished.connect(on_step_finished)
	WorkflowEvents.events.pipeline_finished.connect(on_pipeline_finished)
	WorkflowEvents.events.pipeline_stopped.connect(on_pipeline_stopped)

	WorkflowManager.ensure_workflows_dir()
	pass


func apply_theme() -> void:
	add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ColorBase.app_background))
	toolbar.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ColorBase.deep_surface, 0, 0, 0, ColorBase.muted_border, ControlSize.border_xs))
	sidebar.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ColorBase.chrome_surface, 0, 0, 0, ColorBase.muted_border, ControlSize.border_xs))
	apply_layout_tokens()
	apply_text_tokens()
	style_toolbar_buttons()
	style_palette_tree()
	style_run_button()
	set_run_button_running(running_pipeline)
	graph_edit.apply_theme()
	style_internal_scroll_bars(graph_edit)
	pass


func apply_layout_tokens() -> void:
	toolbar_margin.add_theme_constant_override("margin_left", Margin.ma_3)
	toolbar_margin.add_theme_constant_override("margin_top", Margin.ma_3)
	toolbar_margin.add_theme_constant_override("margin_right", Margin.ma_3)
	toolbar_margin.add_theme_constant_override("margin_bottom", Margin.ma_3)
	toolbar_row.add_theme_constant_override("separation", Margin.ma_4)
	actions.add_theme_constant_override("separation", Margin.ma_4)
	sidebar_margin.add_theme_constant_override("margin_left", Margin.ma_4)
	sidebar_margin.add_theme_constant_override("margin_top", Margin.ma_4)
	sidebar_margin.add_theme_constant_override("margin_right", Margin.ma_4)
	sidebar_margin.add_theme_constant_override("margin_bottom", Margin.ma_4)
	palette_vbox.add_theme_constant_override("separation", Margin.ma_3)
	pass


func apply_text_tokens() -> void:
	var logo_font := FontVariation.new()
	logo_font.base_font = Fonts.bold()
	logo_font.spacing_glyph = Typography.letter_spacing_md
	logo_label.add_theme_font_override("font", logo_font)
	logo_label.add_theme_font_size_override("font_size", Typography.title_medium_size)
	var logo_color := ThemeColor.accent_theme_color()
	logo_label.add_theme_color_override("font_color", logo_color if ThemeColor.is_dark_theme() else logo_color.darkened(0.08))
	title_label.add_theme_font_size_override("font_size", Typography.title_medium_size)
	title_label.add_theme_color_override("font_color", ColorBase.primary_text)
	palette_title.add_theme_font_size_override("font_size", Typography.title_medium_size)
	palette_title.add_theme_color_override("font_color", ColorBase.primary_text)
	palette_hint.add_theme_font_size_override("font_size", Typography.body_small_size)
	palette_hint.add_theme_color_override("font_color", ColorBase.secondary_text)
	pass


func style_toolbar_buttons() -> void:
	style_toolbar_button(new_button, tr("workflow.toolbar.new"))
	style_toolbar_button(load_button, tr("workflow.toolbar.load"))
	style_toolbar_button(save_button, tr("workflow.toolbar.save"))
	style_toolbar_button(delete_button, tr("workflow.toolbar.delete"))
	style_toolbar_button(log_button, tr("workflow.toolbar.log"))
	pass


func style_toolbar_button(button: Button, tooltip: String) -> void:
	AgentToolbarButton.style(button, tooltip)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pass


func style_palette_tree() -> void:
	ScrollBarStyle.apply(palette_scroll.get_v_scroll_bar())
	style_internal_scroll_bars(palette_tree)
	palette_tree.add_theme_font_size_override("font_size", Typography.title_medium_size)
	palette_tree.add_theme_color_override("font_color", ColorBase.primary_text)
	palette_tree.add_theme_color_override("font_hovered_color", ColorBase.primary_text)
	palette_tree.add_theme_color_override("font_selected_color", ColorBase.primary_text)
	palette_tree.add_theme_color_override("font_hovered_selected_color", ColorBase.primary_text)
	palette_tree.add_theme_color_override("guide_color", ColorBase.muted_border)
	palette_tree.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Color.TRANSPARENT))
	var selected := StyleBoxHelper.create_style_box_flat(ThemeColor.selected_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1)
	palette_tree.add_theme_stylebox_override("selected", selected)
	palette_tree.add_theme_stylebox_override("selected_focus", selected.duplicate() as StyleBoxFlat)
	palette_tree.add_theme_stylebox_override("hovered_selected", selected.duplicate() as StyleBoxFlat)
	palette_tree.add_theme_stylebox_override("hovered_selected_focus", selected.duplicate() as StyleBoxFlat)
	palette_tree.add_theme_stylebox_override("hovered", StyleBoxHelper.create_style_box_flat(ColorBase.hover_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1))
	pass


## Tree and GraphEdit expose their scroll bars as internal children in Godot 4.6.
func style_internal_scroll_bars(node: Node) -> void:
	for child: Node in node.get_children(true):
		if child is ScrollBar:
			ScrollBarStyle.apply(child as ScrollBar)
		style_internal_scroll_bars(child)
	pass


func configure_sidebar_layout() -> void:
	body_split.split_offset = AgentLayout.SIDEBAR_DEFAULT_WIDTH
	sidebar.custom_minimum_size.x = AgentLayout.SIDEBAR_MIN_WIDTH
	sidebar.clip_contents = true
	palette_tree.custom_minimum_size.x = AgentLayout.SIDEBAR_MIN_WIDTH - Margin.ma_8
	palette_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	palette_tree.set_column_expand(0, true)
	palette_tree.set_column_custom_minimum_width(0, AgentLayout.SIDEBAR_MIN_WIDTH - Margin.ma_8)
	pass


func configure_dialog_layout() -> void:
	save_dialog.size = AgentLayout.FILE_DIALOG_SIZE
	load_dialog.size = AgentLayout.FILE_DIALOG_SIZE
	pass


func palette_display_label(label: String) -> String:
	return StringUtils.truncate(label, PALETTE_LABEL_MAX)


func set_palette_item_text(item: TreeItem, label: String) -> void:
	item.set_text(0, palette_display_label(label))
	if label.length() > PALETTE_LABEL_MAX:
		item.set_tooltip_text(0, label)
	else:
		item.set_tooltip_text(0, "")
	pass


func apply_ui_locale() -> void:
	new_button.text = tr("workflow.toolbar.new")
	load_button.text = tr("workflow.toolbar.load")
	save_button.text = tr("workflow.toolbar.save")
	delete_button.text = tr("workflow.toolbar.delete")
	log_button.text = tr("workflow.toolbar.log")
	if running_pipeline:
		run_button.text = tr("workflow.toolbar.stop")
	else:
		run_button.text = tr("workflow.toolbar.run")
	palette_title.text = tr("workflow.palette.title")
	palette_hint.text = tr("workflow.palette.hint")
	palette_hint.add_theme_color_override("font_color", ColorBase.secondary_text)
	save_dialog.title = tr("workflow.dialog.save_title")
	save_dialog.ok_button_text = tr("workflow.toolbar.save")
	save_dialog.filters = PackedStringArray([
		"*.workflow.json ; " + tr("workflow.dialog.workflow_filter"),
		"* ; " + tr("workflow.dialog.all_files"),
	])
	load_dialog.title = tr("workflow.dialog.load_title")
	load_dialog.ok_button_text = tr("workflow.toolbar.load")
	load_dialog.filters = PackedStringArray([
		"*.workflow.json ; " + tr("workflow.dialog.workflow_filter"),
	])
	pass


func build_palette_tree() -> void:
	palette_tree.clear()
	palette_tree.hide_root = true
	palette_tree.column_titles_visible = false
	var root: TreeItem = palette_tree.create_item()

	for category_id in GraphNodesConfig.CATEGORY_IDS:
		var skills: Array[GraphNodeDef] = GraphNodesConfig.list_skills_in_category(category_id)
		if skills.is_empty():
			continue

		var category_item: TreeItem = palette_tree.create_item(root)
		set_palette_item_text(category_item, GraphNodesConfig.category_label(category_id))
		category_item.set_collapsed(true)
		category_item.set_selectable(0, true)

		for skill in skills:
			var skill_item: TreeItem = palette_tree.create_item(category_item)
			set_palette_item_text(skill_item, skill.display_label())
			skill_item.set_metadata(0, {"kind": "skill", "id": skill.catalog_id()})
			skill_item.set_selectable(0, true)

	var workflows_item: TreeItem = palette_tree.create_item(root)
	set_palette_item_text(workflows_item, tr("workflow.palette.my_workflows"))
	workflows_item.set_collapsed(false)
	workflows_item.set_selectable(0, true)

	for workflow_path in WorkflowManager.list_saved_workflows():
		var workflow_item: TreeItem = palette_tree.create_item(workflows_item)
		var label: String = WorkflowManager.workflow_name_from_path(workflow_path)
		set_palette_item_text(workflow_item, label)
		workflow_item.set_metadata(0, {"kind": "workflow", "path": workflow_path})
		workflow_item.set_selectable(0, true)
	pass
func on_palette_item_selected() -> void:
	var item: TreeItem = palette_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta == null:
		item.set_collapsed(false)
	pass


func on_palette_item_activated() -> void:
	var item: TreeItem = palette_tree.get_selected()
	if item == null:
		return
	var meta: Variant = item.get_metadata(0)
	if meta == null or not meta is Dictionary:
		return
	var kind: String = str(meta.get("kind", ""))
	if kind == "workflow":
		open_workflow_at_path(str(meta.get("path", "")))
	elif kind == "skill":
		var spawn_pos: Vector2 = Vector2(120 + graph_edit.node_seq * 24, 120 + graph_edit.node_seq * 18)
		graph_edit.add_skill_node(str(meta.get("id", "")), spawn_pos)
	pass


func on_new_pressed() -> void:
	graph_edit.clear_graph()
	WorkflowManager.new_workflow()
	set_workflow_name(WorkflowManager.workflow_name)
	pass


func on_save_pressed() -> void:
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.current_dir = WorkflowManager.globalized_workflows_dir()
	if not WorkflowManager.current_path.is_empty():
		save_dialog.current_path = WorkflowManager.current_path
	else:
		save_dialog.current_file = StringUtils.format(
			"{}{}", WorkflowManager.workflow_name, WorkflowManager.WORKFLOW_EXT
		)
	save_dialog.popup_centered()
	pass


func on_load_pressed() -> void:
	load_dialog.current_dir = WorkflowManager.globalized_workflows_dir()
	load_dialog.popup_centered()
	pass


func on_save_file_selected(path: String) -> void:
	var doc: WorkflowDocument = graph_edit.build_document(WorkflowManager.workflow_name_from_path(path))
	WorkflowManager.save(path, doc)
	set_workflow_name(WorkflowManager.workflow_name)
	build_palette_tree()
	pass


func on_load_file_selected(path: String) -> void:
	open_workflow_at_path(path)
	pass


func open_workflow_at_path(path: String) -> void:
	if path.is_empty():
		return
	var doc: WorkflowDocument = WorkflowManager.load(path)
	if doc == null:
		return
	graph_edit.load_document(doc)
	set_workflow_name(WorkflowManager.workflow_name)
	pass


func set_workflow_name(name: String) -> void:
	if StringUtils.is_blank(name):
		return
	WorkflowManager.workflow_name = name.strip_edges()
	var display_name: String = WorkflowManager.workflow_name
	if display_name == "Untitled":
		display_name = tr("workflow.untitled")
	get_window().title = tr("workflow.window_title").format([display_name], StringUtils.EMPTY_JSON)
	pass


func on_log_pressed() -> void:
	LogWindow.show_log_window()
	pass


func on_delete_pressed() -> void:
	graph_edit.remove_selected_nodes()
	pass


func on_run_pressed() -> void:
	if running_pipeline:
		pipeline_runner.request_stop()
		return
	running_pipeline = true
	set_run_button_running(true)
	var doc: WorkflowDocument = graph_edit.build_document(WorkflowManager.workflow_name)
	Log.info("--- Starting workflow ---")
	await pipeline_runner.run(doc)
	pass


func on_step_started(node_id: String, label: String) -> void:
	Log.info("step started label:[{}] node:[{}]", label, node_id)
	pass


func on_step_finished(node_id: String, exit_code: int, output_path: String) -> void:
	if exit_code == 0:
		Log.info("step finished node:[{}] output:[{}]", node_id, output_path)
	else:
		Log.error("step failed node:[{}] exit:[{}]", node_id, exit_code)
	pass


func on_pipeline_stopped() -> void:
	running_pipeline = false
	set_run_button_running(false)
	var message := tr("pipeline.stopped")
	Log.info(message)
	Alert.alert(message, ColorBase.warning)
	pass


func on_pipeline_finished(success: bool, message: String) -> void:
	running_pipeline = false
	set_run_button_running(false)
	if success:
		Log.info(message)
		Alert.alert(message, ColorBase.success)
	else:
		Log.error(message)
		Alert.alert(message, ColorBase.error)
	pass


# ----------------------------------------------------------------------------------------------------------------------
func set_run_button_running(running: bool) -> void:
	if running:
		apply_run_button_style(ColorBase.error)
		run_button.icon = make_stop_icon(Typography.title_small_size, Color.WHITE)
		run_button.text = tr("workflow.toolbar.stop")
	else:
		apply_run_button_style(ColorBase.success)
		run_button.icon = make_play_icon(Typography.title_small_size, Color.WHITE)
		run_button.text = tr("workflow.toolbar.run")
	pass


func style_run_button() -> void:
	apply_run_button_style(ColorBase.success)
	run_button.custom_minimum_size = ControlSize.square(ControlSize.sm)
	run_button.add_theme_font_size_override("font_size", Typography.label_small_size)
	ButtonStyle.apply_font_colors(run_button, Color.WHITE, Color.WHITE, Color.WHITE)
	run_button.focus_mode = Control.FOCUS_NONE
	run_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	run_button.icon = make_play_icon(Typography.title_small_size, Color.WHITE)
	run_button.text = tr("workflow.toolbar.run")
	run_button.add_theme_constant_override("icon_max_width", Typography.title_small_size)
	run_button.add_theme_constant_override("icon_max_height", Typography.title_small_size)
	run_button.add_theme_constant_override("h_separation", Margin.ma_2)
	pass


func apply_run_button_style(base_color: Color) -> void:
	var normal := StyleBoxHelper.create_style_box_flat(base_color, ControlSize.radius_md, Margin.ma_2, Margin.ma_1)
	ButtonStyle.apply(run_button, normal,
		ButtonStyle.filled(normal, base_color.lightened(0.12)),
		ButtonStyle.filled(normal, base_color.darkened(0.08)),
		null, ButtonStyle.filled(normal, base_color.darkened(0.02)))
	pass


func make_play_icon(size: int, color: Color) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var left: int = int(size * 0.25)
	var right: int = int(size * 0.92)
	var top: int = int(size * 0.18)
	var bottom: int = int(size * 0.82)
	var mid_y: int = (top + bottom) / 2
	for y in range(top, bottom + 1):
		var x_max: int
		if y <= mid_y:
			x_max = left + int(float(right - left) * float(y - top) / float(mid_y - top))
		else:
			x_max = left + int(float(right - left) * float(bottom - y) / float(bottom - mid_y))
		for x in range(left, x_max + 1):
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


func make_stop_icon(size: int, color: Color) -> ImageTexture:
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var margin: int = int(size * 0.22)
	for y in range(margin, size - margin):
		for x in range(margin, size - margin):
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
# ----------------------------------------------------------------------------------------------------------------------
