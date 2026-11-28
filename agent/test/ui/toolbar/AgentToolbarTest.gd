extends Node

## The GAI wordmark is painted from the accent color, so an accent change must repaint it —
## a dark/light switch alone is not enough.


## Changing the accent from the color picker at runtime must recolor the logo.
func AgentToolbar_accent_color_repaint_test() -> void:
	var original := ThemeColor.theme_color
	var panel := PanelContainer.new()
	var logo := Label.new()
	var workspace := Button.new()
	panel.add_child(logo)
	panel.add_child(workspace)
	add_child(panel)

	var toolbar := AgentToolbar.new()
	toolbar.setup(panel, logo, workspace)
	assert(gdf.events.theme_color_changed.is_connected(toolbar.apply_theme))

	ThemeColor.set_theme_color(Color("#ff5c8a"))
	assert(logo.get_theme_color("font_color") == expected_logo_color())
	assert(toolbar.workspace_button.get_theme_color("font_color") == Colors.secondary_text)

	ThemeColor.set_theme_color(Color("#35c2a0"))
	assert(logo.get_theme_color("font_color") == expected_logo_color())

	ThemeColor.set_theme_color(original)
	remove_child(panel)
	panel.queue_free()
	pass


static func expected_logo_color() -> Color:
	var accent := ThemeColor.accent_theme_color()
	return accent if ThemeColor.is_dark_theme() else accent.darkened(0.08)
