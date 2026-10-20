extends Control

## Agent main app — multi-session chat UI.

@onready var toolbar_panel: PanelContainer = $Root/Toolbar
@onready var toolbar_row: HBoxContainer = $Root/Toolbar/ToolbarRow
@onready var toolbar_logo: Label = $Root/Toolbar/ToolbarRow/Logo
@onready var body_split: HSplitContainer = $Root/Body
@onready var sidebar_panel: PanelContainer = $Root/Body/Sidebar
@onready var chat_area_panel: Panel = $Root/Body/ChatArea
@onready var pinned_header: Label = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/PinnedHeader
@onready var pinned_list: VBoxContainer = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/PinnedList
@onready var pinned_separator: HSeparator = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/PinnedSeparator
@onready var unpinned_header: Label = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/UnpinnedHeader
@onready var unpinned_list: VBoxContainer = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/UnpinnedList
@onready var session_list_scroll: ScrollContainer = $Root/Body/Sidebar/SidebarVBox/SessionListScroll
@onready var new_session_button: Button = $Root/Body/Sidebar/SidebarVBox/NewSessionButton
@onready var chat_scroll_node: ScrollContainer = $Root/Body/ChatArea/ChatScroll
@onready var chat_list: MarginContainer = $Root/Body/ChatArea/ChatScroll/ChatList
@onready var token_usage_wrap: PanelContainer = $Root/Toolbar/ToolbarRow/TokenUsageWrap
@onready var memory_toggle_button: Button = $Root/Toolbar/ToolbarRow/MemoryToggleWrap/MemoryToggleButton
@onready var visuals_button_node: Button = $Root/Toolbar/ToolbarRow/VisualsButtonWrap/VisualsButton
@onready var agent_prompt_toggle_button: Button = $Root/Toolbar/ToolbarRow/AgentPromptToggleWrap/AgentPromptToggleButton
@onready var skill_toggle_button: Button = $Root/Toolbar/ToolbarRow/SkillToggleWrap/SkillToggleButton
@onready var input_bar: Control = $Root/Body/ChatArea/InputBar
@onready var input_wrap: PanelContainer = $Root/Body/ChatArea/InputBar/InputWrap
@onready var input_inner: Control = $Root/Body/ChatArea/InputBar/InputWrap/InputInner
@onready var input_field: TextEdit = $Root/Body/ChatArea/InputBar/InputWrap/InputInner/InputField
@onready var send_button: Button = $Root/Body/ChatArea/InputBar/InputWrap/InputInner/SendButton
@onready var workspace_button_node: Button = $Root/Toolbar/ToolbarRow/WorkspaceButton
@onready var workflow_button_node: Button = $Root/Toolbar/ToolbarRow/WorkflowButton
@onready var sense_button_node: Button = $Root/Toolbar/ToolbarRow/SenseButton
@onready var note_button_node: Button = $Root/Toolbar/ToolbarRow/NoteButton
@onready var search_button_node: Button = $Root/Toolbar/ToolbarRow/SearchButtonWrap/SearchButton
@onready var log_button_node: Button = $Root/Toolbar/ToolbarRow/LogButtonWrap/LogButton
@onready var theme_color_select_node: Button = $Root/Toolbar/ToolbarRow/ThemeColorSelectWrap/ThemeColorSelect
@onready var theme_toggle_button: Button = $Root/Toolbar/ToolbarRow/ThemeToggleWrap/ThemeToggleButton
@onready var agent_setting_button: Button = $Root/Toolbar/ToolbarRow/AgentSettingWrap/AgentSettingButton
@onready var agent_setting_wrap: MarginContainer = $Root/Toolbar/ToolbarRow/AgentSettingWrap
@onready var workspace_dialog: FileDialog = $WorkspaceDialog

var agent_toolbar: AgentToolbar = AgentToolbar.new()
var workspace_button: WorkspaceButton = WorkspaceButton.new()
var workflow_button: WorkflowButton = WorkflowButton.new()
var sense_button: SenseButton = SenseButton.new()
var note_button: NoteButton = NoteButton.new()
var search_button: SearchButton = SearchButton.new()
var log_button: LogButton = LogButton.new()
var agent_chat_input: AgentChatInput = AgentChatInput.new()
var theme_toggle: ThemeToggle = ThemeToggle.new()
var theme_color_select: ThemeColorSelect = ThemeColorSelect.new()
var visuals_button: VisualsButton = VisualsButton.new()
var skill_toggle: SkillToggle = SkillToggle.new()
var agent_prompt_toggle: AgentPromptToggle = AgentPromptToggle.new()
var compaction_button: CompactionButton = CompactionButton.new()
var memory_toggle: MemoryToggle = MemoryToggle.new()
var agent_setting_dialog: AgentSettingDialog = AgentSettingDialog.new()
var agent_session_sidebar: AgentSessionSidebar = AgentSessionSidebar.new()
var agent_chat_view: AgentChatView = AgentChatView.new()
var agent_notification: AgentNotification = AgentNotification.new()
var sense_input: SenseInput = SenseInput.new()


func _ready() -> void:
	I18nHelper.init_i18n()
	apply_layout()
	apply_theme()
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)
	
	agent_toolbar.setup(toolbar_panel, toolbar_logo, workspace_button_node)
	agent_notification.setup()
	agent_session_sidebar.setup(pinned_header, pinned_list, pinned_separator,
			unpinned_header, unpinned_list, session_list_scroll, new_session_button, sidebar_panel)
	compaction_button.setup(token_usage_wrap)
	memory_toggle.setup(memory_toggle_button)
	visuals_button.setup(visuals_button_node)
	skill_toggle.setup(skill_toggle_button)
	agent_prompt_toggle.setup(agent_prompt_toggle_button)
	agent_chat_view.setup(chat_scroll_node, chat_list)

	agent_chat_input.setup(input_bar, input_wrap, input_inner, input_field, send_button)
	theme_color_select.setup(theme_color_select_node)
	theme_toggle.setup(theme_toggle_button)
	agent_setting_dialog.setup(agent_setting_button)
	workspace_button.setup(workspace_button_node, workspace_dialog)
	workflow_button.setup(workflow_button_node, workspace_button_node)
	sense_button.setup(sense_button_node, sense_input)
	note_button.setup(note_button_node)
	search_button.setup(search_button_node)
	log_button.setup(log_button_node)
	sense_input.setup()
	apply_locale()

	# session
	agent_session_sidebar.reload_sessions()
	pass


func _exit_tree() -> void:
	sense_input.shutdown()
	pass


func apply_layout() -> void:
	body_split.split_offset = AgentLayout.SIDEBAR_DEFAULT_WIDTH
	sidebar_panel.custom_minimum_size.x = AgentLayout.SIDEBAR_MIN_WIDTH
	toolbar_row.add_theme_constant_override("separation", Margin.ma_4)
	agent_setting_wrap.add_theme_constant_override("margin_right", Margin.ma_3)
	chat_list.add_theme_constant_override("margin_left", Margin.ma_5)
	chat_list.add_theme_constant_override("margin_right", Margin.ma_5)
	chat_list.add_theme_constant_override("margin_top", Margin.ma_3)
	chat_list.add_theme_constant_override("margin_bottom", Margin.ma_2)
	pass


func apply_locale() -> void:
	input_field.placeholder_text = I18n.t("agent.input.placeholder")
	workspace_dialog.title = I18n.t("agent.workspace.dialog_title")
	workspace_dialog.ok_button_text = I18n.t("common.select")
	pass



func apply_theme() -> void:
	var app_theme := Theme.new()
	app_theme.default_font = Fonts.regular()
	theme = app_theme
	
	workspace_dialog.add_theme_font_override("title_font", Fonts.regular())	
	chat_area_panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.app_background))
	chat_area_panel.queue_redraw()
	add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.app_background))
	pass
