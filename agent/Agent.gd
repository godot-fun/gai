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
@onready var normal_header: Label = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/NormalHeader
@onready var normal_list: VBoxContainer = $Root/Body/Sidebar/SidebarVBox/SessionListScroll/SessionList/NormalList
@onready var session_list_scroll: ScrollContainer = $Root/Body/Sidebar/SidebarVBox/SessionListScroll
@onready var new_session_button: Button = $Root/Body/Sidebar/SidebarVBox/NewSessionButton
@onready var chat_scroll: ScrollContainer = $Root/Body/ChatArea/ChatScroll
@onready var chat_host: MarginContainer = $Root/Body/ChatArea/ChatScroll/ChatMargin
@onready var token_usage_wrap: PanelContainer = $Root/Toolbar/ToolbarRow/TokenUsageWrap
@onready var jarvis_toggle_button: Button = $Root/Toolbar/ToolbarRow/JarvisToggleWrap/JarvisToggleButton
@onready var agent_prompt_toggle_button: Button = $Root/Toolbar/ToolbarRow/AgentPromptToggleWrap/AgentPromptToggleButton
@onready var skill_toggle_button: Button = $Root/Toolbar/ToolbarRow/SkillToggleWrap/SkillToggleButton
@onready var markdown_toggle_button: Button = $Root/Toolbar/ToolbarRow/MarkdownToggleWrap/MarkdownToggleButton
@onready var input_bar: Control = $Root/Body/ChatArea/InputBar
@onready var input_wrap: PanelContainer = $Root/Body/ChatArea/InputBar/InputWrap
@onready var input_inner: Control = $Root/Body/ChatArea/InputBar/InputWrap/InputInner
@onready var input_field: TextEdit = $Root/Body/ChatArea/InputBar/InputWrap/InputInner/InputField
@onready var send_button: Button = $Root/Body/ChatArea/InputBar/InputWrap/InputInner/SendButton
@onready var project_button: Button = $Root/Toolbar/ToolbarRow/ProjectButton
@onready var workflow_button: Button = $Root/Toolbar/ToolbarRow/WorkflowButton
@onready var search_button: Button = $Root/Toolbar/ToolbarRow/SearchButtonWrap/SearchButton
@onready var log_button: Button = $Root/Toolbar/ToolbarRow/LogButtonWrap/LogButton
@onready var theme_color_select: Button = $Root/Toolbar/ToolbarRow/ThemeColorSelectWrap/ThemeColorSelect
@onready var theme_toggle_button: Button = $Root/Toolbar/ToolbarRow/ThemeToggleWrap/ThemeToggleButton
@onready var agent_setting_button: Button = $Root/Toolbar/ToolbarRow/AgentSettingWrap/AgentSettingButton
@onready var agent_setting_wrap: MarginContainer = $Root/Toolbar/ToolbarRow/AgentSettingWrap
@onready var workspace_dialog: FileDialog = $WorkspaceDialog

var toolbar: AgentToolbar = AgentToolbar.new()
var workspace_button: WorkspaceButton = WorkspaceButton.new()
var workflow_button_ctrl: WorkflowButton = WorkflowButton.new()
var search_button_ctrl: SearchButton = SearchButton.new()
var log_button_ctrl: LogButton = LogButton.new()
var chat_input: AgentChatInput = AgentChatInput.new()
var theme_toggle: ThemeToggle = ThemeToggle.new()
var theme_color_select_ctrl: ThemeColorSelect = ThemeColorSelect.new()
var jarvis_toggle: JarvisToggle = JarvisToggle.new()
var skill_toggle: SkillToggle = SkillToggle.new()
var agent_prompt_toggle: AgentPromptToggle = AgentPromptToggle.new()
var token_usage_display: TokenUsageDisplay = TokenUsageDisplay.new()
var markdown_toggle: MarkdownToggle = MarkdownToggle.new()
var agent_setting_dialog: AgentSettingDialog = AgentSettingDialog.new()
var session_sidebar: AgentSessionSidebar = AgentSessionSidebar.new()
var chat_view: AgentChatView = AgentChatView.new()
var notification: AgentNotification = AgentNotification.new()
var sense_input: SenseInput = SenseInput.new()


func _ready() -> void:
	I18nHelper.init_i18n()
	apply_layout()
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.locale_changed.connect(apply_locale)
	apply_theme()
	
	toolbar.setup(toolbar_panel, toolbar_logo, project_button)
	notification.setup()
	session_sidebar.setup(pinned_header, pinned_list, pinned_separator,
			normal_header, normal_list, session_list_scroll, new_session_button, sidebar_panel)
	token_usage_display.setup(token_usage_wrap)
	jarvis_toggle.setup(jarvis_toggle_button)
	skill_toggle.setup(skill_toggle_button)
	agent_prompt_toggle.setup(agent_prompt_toggle_button)
	markdown_toggle.setup(markdown_toggle_button)
	chat_view.setup(chat_scroll, chat_host)

	chat_input.setup(input_bar, input_wrap, input_inner, input_field, send_button)
	theme_color_select_ctrl.setup(theme_color_select)
	theme_toggle.setup(theme_toggle_button)
	agent_setting_dialog.setup(agent_setting_button)
	workspace_button.setup(project_button, workspace_dialog)
	workflow_button_ctrl.setup(workflow_button, project_button)
	search_button_ctrl.setup(search_button)
	log_button_ctrl.setup(log_button)
	sense_input.setup()
	apply_locale()

	# session
	session_sidebar.reload_sessions()
	pass


func _exit_tree() -> void:
	sense_input.shutdown()
	pass


func apply_layout() -> void:
	body_split.split_offset = AgentLayout.SIDEBAR_DEFAULT_WIDTH
	sidebar_panel.custom_minimum_size.x = AgentLayout.SIDEBAR_MIN_WIDTH
	toolbar_row.add_theme_constant_override("separation", Margin.ma_4)
	agent_setting_wrap.add_theme_constant_override("margin_right", Margin.ma_3)
	chat_host.add_theme_constant_override("margin_left", Margin.ma_5)
	chat_host.add_theme_constant_override("margin_right", Margin.ma_5)
	chat_host.add_theme_constant_override("margin_top", Margin.ma_3)
	chat_host.add_theme_constant_override("margin_bottom", Margin.ma_2)
	pass


func apply_locale() -> void:
	new_session_button.text = I18n.t("agent.sidebar.new_session")
	pinned_header.text = I18n.t("agent.sidebar.pinned")
	normal_header.text = I18n.t("agent.sidebar.chats")
	input_field.placeholder_text = I18n.t("agent.input.placeholder")
	workspace_dialog.title = I18n.t("agent.workspace.dialog_title")
	workspace_dialog.ok_button_text = I18n.t("agent.common.select")
	pass



func apply_theme() -> void:
	chat_area_panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ColorBase.app_background))
	chat_area_panel.queue_redraw()
	add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(ColorBase.app_background))
	pass
