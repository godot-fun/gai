extends Control

## Manual preview for [CommonHighlighter] — switch extensions with the toolbar and inspect token colors.

const PREVIEW_SAMPLES: Array[Dictionary] = [
	{
		"label": "GDScript",
		"path": "scripts/player.gd",
		"text": "class_name Player\nextends CharacterBody2D\n\n@export var speed: float = 220.0\n\nfunc _physics_process(_delta: float) -> void:\n\tvar direction := Input.get_vector(\"move_left\", \"move_right\", \"move_up\", \"move_down\")\n\tvelocity = direction * speed\n\tmove_and_slide()\n\tpass",
	},
	{
		"label": "Python",
		"path": "tools/build.py",
		"text": "#!/usr/bin/env python3\nfrom pathlib import Path\n\nasync def load_config(path: Path) -> dict:\n\t\"\"\"Load JSON config from disk.\"\"\"\n\tassert path.exists()\n\treturn {\"enabled\": True, \"count\": 42}\n\nif __name__ == \"__main__\":\n\tprint(load_config(Path(\"config.json\")))",
	},
	{
		"label": "TypeScript",
		"path": "src/app.ts",
		"text": "type Result<T> = { ok: true; value: T } | { ok: false; error: string };\n\nexport async function fetchJson<T>(url: string): Promise<Result<T>> {\n\tconst response = await fetch(url);\n\tif (!response.ok) return { ok: false, error: \"network\" };\n\tconst body = await response.json();\n\treturn { ok: true, value: body satisfies T };\n}\n\nconst total: bigint = 9007199254740991n;",
	},
	{
		"label": "TSX",
		"path": "ui/Button.tsx",
		"text": "import { useMemo, type FC } from \"react\";\n\ninterface Props {\n\tlabel: string;\n\tdisabled?: boolean;\n}\n\nexport const Button: FC<Props> = ({ label, disabled = false }) => {\n\tconst className = useMemo(() => (disabled ? \"btn muted\" : \"btn primary\"), [disabled]);\n\treturn <button className={className}>{label}</button>;\n};",
	},
	{
		"label": "Rust",
		"path": "src/main.rs",
		"text": "use std::collections::HashMap;\n\npub fn merge_counts(items: &[&str]) -> HashMap<&str, u32> {\n\tlet mut counts = HashMap::new();\n\tfor item in items {\n\t\t*counts.entry(item).or_insert(0) += 1;\n\t}\n\tcounts\n}\n\nfn main() {\n\tlet values = vec![Some(1), None, Some(3)];\n\tprintln!(\"{:?}\", values);\n}",
	},
	{
		"label": "Go",
		"path": "cmd/server/main.go",
		"text": "package main\n\nimport (\n\t\"context\"\n\t\"fmt\"\n\t\"time\"\n)\n\nfunc worker(ctx context.Context, ch chan<- int) {\n\tfor i := 0; i < 3; i++ {\n\t\tselect {\n\t\tcase <-ctx.Done():\n\t\t\treturn\n\t\tcase ch <- i:\n\t\t\ttime.Sleep(10 * time.Millisecond)\n\t\t}\n\t}\n}\n\nfunc main() {\n\tfmt.Println(\"ready\")\n}",
	},
	{
		"label": "C++",
		"path": "native/module.cpp",
		"text": "#include <memory>\n#include <vector>\n\nnamespace demo {\n\ttemplate<typename T>\n\tclass Buffer {\n\tpublic:\n\t\texplicit Buffer(std::size_t size) : data_(size) {}\n\t\tconst T& at(std::size_t index) const noexcept { return data_.at(index); }\n\tprivate:\n\t\tstd::vector<T> data_;\n\t};\n}\n\nint main() {\n\treturn 0;\n}",
	},
	{
		"label": "Shader",
		"path": "effects/water.gdshader",
		"text": "shader_type canvas_item;\n\nuniform sampler2D wave_texture : repeat_disable;\nuniform float strength = 0.35;\n\nvoid fragment() {\n\tvec2 uv = UV + vec2(0.01, 0.02) * strength;\n\tvec4 sample_color = texture(wave_texture, uv);\n\tCOLOR = vec4(sample_color.rgb, 1.0);\n}",
	},
	{
		"label": "SQL",
		"path": "schema.sql",
		"text": "-- Player lookup\nSELECT p.id, p.name, COUNT(s.id) AS session_count\nFROM players AS p\nLEFT JOIN sessions AS s ON s.player_id = p.id\nWHERE p.active = TRUE\nGROUP BY p.id, p.name\nHAVING COUNT(s.id) > 0\nORDER BY session_count DESC\nLIMIT 25;",
	},
	{
		"label": "Markdown",
		"path": "README.md",
		"text": "# Code Highlighter Preview\n\n> NOTE: Toggle extensions above to compare palettes.\n\nInline `code`, **bold**, ~~strike~~, and a [link](https://example.com).\n\n```gdscript\nfunc hello() -> void:\n\tprint(\"demo\")\n```",
	},
	{
		"label": "MDX",
		"path": "docs/page.mdx",
		"text": "import { Callout } from \"@/components/Callout\";\n\n# Release Notes\n\n<Callout tone=\"info\">Ship when green.</Callout>\n\nUse `pnpm test` before tagging `v1.2.0`.",
	},
	{
		"label": "JSONC",
		"path": "settings.jsonc",
		"text": "{\n\t// Editor preferences\n\t\"theme\": \"dark\",\n\t\"telemetry\": false,\n\t\"limits\": {\n\t\t\"maxItems\": 128,\n\t\t\"retryMs\": 250\n\t}\n}",
	},
	{
		"label": "YAML",
		"path": "deploy/service.yml",
		"text": "# Service manifest\nname: agent-api\nreplicas: 3\nenv:\n  LOG_LEVEL: info\n  PORT: 8080\nfeatures:\n  - metrics\n  - tracing",
	},
	{
		"label": "CSS",
		"path": "ui/panel.css",
		"text": "/* Panel chrome */\n.panel {\n\tdisplay: flex;\n\tgap: 12px;\n\tbackground: #101820;\n\tborder-radius: 8px;\n}\n\n.panel .title {\n\tcolor: var(--accent);\n\tfont-weight: 600;\n}",
	},
	{
		"label": "HTML",
		"path": "static/index.html",
		"text": "<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n\t<meta charset=\"utf-8\" />\n\t<title>Preview</title>\n</head>\n<body>\n\t<main class=\"shell\">\n\t\t<h1>Syntax Preview</h1>\n\t\t<p>Switch extensions with the toolbar.</p>\n\t</main>\n</body>\n</html>",
	},
	{
		"label": "PowerShell",
		"path": "build.ps1",
		"text": "param(\n\t[string]$Configuration = \"Release\"\n)\n\nfunction Invoke-Build {\n\tWrite-Host \"Building $Configuration\"\n\t& dotnet build --configuration $Configuration\n}\n\n# Run locally\nInvoke-Build",
	},
	{
		"label": "Patch",
		"path": "change.patch",
		"text": "diff --git a/demo.gd b/demo.gd\nindex 1111111..2222222 100644\n--- a/demo.gd\n+++ b/demo.gd\n@@ -1,3 +1,4 @@\n func old() -> void:\n-\tpass\n+func current() -> void:\n+\tprint(\"updated\")",
	},
	{
		"label": "CMake",
		"path": "CMakeLists.txt",
		"text": "cmake_minimum_required(VERSION 3.16)\nproject(demo LANGUAGES CXX)\n\nadd_executable(demo src/main.cpp)\ntarget_compile_features(demo PRIVATE cxx_std_20)\ntarget_link_libraries(demo PRIVATE Threads::Threads)",
	},
	{
		"label": "SCons",
		"path": "SConstruct",
		"text": "import os\n\nenv = Environment()\nenv.Append(CCFLAGS=[\"-O2\", \"-Wall\"])\n\nsources = Glob(\"src/*.cpp\")\ndemo = env.Program(\"demo\", sources)\n\nDefault(demo)",
	},
	{
		"label": "Lua",
		"path": "scripts/hud.lua",
		"text": "local M = {}\n\n--[[ HUD helpers ]]\nfunction M.format_score(value)\n\t-- keep two decimals\n\treturn string.format(\"%.2f\", value)\nend\n\nreturn M",
	},
	{
		"label": "Unknown",
		"path": "asset.unknown",
		"text": "plain text without language rules\n12345 + symbols: {}[]()\n# not a comment region here\n// also plain text",
	},
]

var background: ColorRect
var page_margin: MarginContainer
var title_label: Label
var path_label: Label
var button_flow: HFlowContainer
var editor_panel: PanelContainer
var code_edit: CodeEdit

var sample_buttons: Array[Button] = []
var button_group: ButtonGroup
var active_path: String = ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	button_group = ButtonGroup.new()
	build_ui()
	build_sample_buttons()
	gdf.events.theme_changed.connect(apply_theme)
	gdf.events.theme_color_changed.connect(apply_theme)
	select_sample(0)
	apply_theme()
	pass


func build_ui() -> void:
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	page_margin = MarginContainer.new()
	page_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page_margin)

	var layout := VBoxContainer.new()
	layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", Margin.ma_3)
	page_margin.add_child(layout)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", Margin.ma_1)
	layout.add_child(header)

	title_label = Label.new()
	title_label.text = "Code Editor Highlighter Preview"
	header.add_child(title_label)

	path_label = Label.new()
	path_label.text = "scripts/player.gd"
	header.add_child(path_label)

	var toolbar_scroll := ScrollContainer.new()
	toolbar_scroll.custom_minimum_size.y = 120.0
	toolbar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	toolbar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(toolbar_scroll)

	button_flow = HFlowContainer.new()
	button_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_flow.add_theme_constant_override("h_separation", Margin.ma_2)
	button_flow.add_theme_constant_override("v_separation", Margin.ma_2)
	toolbar_scroll.add_child(button_flow)

	editor_panel = PanelContainer.new()
	editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(editor_panel)

	code_edit = CodeEdit.new()
	code_edit.custom_minimum_size.y = 480.0
	code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	code_edit.editable = false
	code_edit.gutters_draw_line_numbers = true
	code_edit.highlight_current_line = false
	code_edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	editor_panel.add_child(code_edit)
	pass


func build_sample_buttons() -> void:
	for index in PREVIEW_SAMPLES.size():
		var sample: Dictionary = PREVIEW_SAMPLES[index]
		var button := Button.new()
		button.text = str(sample["label"])
		button.focus_mode = Control.FOCUS_NONE
		button.toggle_mode = true
		button.button_group = button_group
		var sample_index := index
		button.toggled.connect(func(pressed: bool) -> void:
			if pressed:
				show_sample(sample_index)
		)
		button_flow.add_child(button)
		sample_buttons.append(button)
	pass


func select_sample(index: int) -> void:
	if index < 0 or index >= PREVIEW_SAMPLES.size():
		return
	sample_buttons[index].button_pressed = true
	show_sample(index)
	pass


func show_sample(index: int) -> void:
	var sample: Dictionary = PREVIEW_SAMPLES[index]
	active_path = str(sample["path"])
	path_label.text = active_path
	code_edit.text = str(sample["text"])
	apply_highlighter_and_editor_style()
	pass


func apply_highlighter_and_editor_style() -> void:
	if active_path.is_empty() or code_edit == null:
		return
	code_edit.syntax_highlighter = CommonHighlighter.create(active_path)
	CodeEditStyle.apply_diff_editor(code_edit)
	pass


func apply_theme() -> void:
	if background == null:
		return
	background.color = Colors.app_background
	page_margin.add_theme_constant_override("margin_left", Margin.ma_6)
	page_margin.add_theme_constant_override("margin_top", Margin.ma_4)
	page_margin.add_theme_constant_override("margin_right", Margin.ma_6)
	page_margin.add_theme_constant_override("margin_bottom", Margin.ma_4)
	title_label.add_theme_font_override("font", Fonts.semibold())
	title_label.add_theme_font_size_override("font_size", Typography.title_medium_size)
	title_label.add_theme_color_override("font_color", Colors.primary_text)
	path_label.add_theme_font_override("font", Fonts.regular())
	path_label.add_theme_font_size_override("font_size", Typography.body_medium_size)
	path_label.add_theme_color_override("font_color", Colors.secondary_text)
	editor_panel.add_theme_stylebox_override("panel", StyleBoxHelper.create_style_box_flat(Colors.surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_0, Colors.subtle_border, ControlSize.border_xs))
	for button: Button in sample_buttons:
		style_sample_button(button)
	apply_highlighter_and_editor_style()
	pass


func style_sample_button(button: Button) -> void:
	button.add_theme_font_override("font", Fonts.medium())
	button.add_theme_font_size_override("font_size", Typography.label_medium_size)
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
