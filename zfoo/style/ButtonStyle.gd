class_name ButtonStyle
extends Object

## Shared [BaseButton] state styling: install the state set a button needs. The boxes themselves
## are built by [StyleBoxHelper]; hover and pressed fills use [method ThemeColor.promote] and
## [method ThemeColor.demote] so contrast stays correct when the theme flips.
##
## Solid fills (accent buttons, shadows) are the exception — those read as plain shading, so they
## keep [method Color.darkened] on every theme.
##
## Typical use:
## [codeblock]
## ButtonStyle.apply_style(button)
## [/codeblock]


## Standard card-surface button chrome shared by dialog and toolbar controls.
static func theme_normal_style() -> StyleBoxFlat:
	return StyleBoxHelper.create_style_box_flat(ThemeColor.card_surface, ControlSize.radius_md, Margin.ma_2, Margin.ma_1,
		ThemeColor.accent_theme_color(), ControlSize.border_xs)


## Hover fill for [param normal]: quiet selected surface with a soft accent outline.
static func theme_hover_style_for(normal: StyleBoxFlat) -> StyleBoxFlat:
	return StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.selected_surface, ThemeColor.alpha_theme_color(0.85))


## Pressed fill for [param normal]: stronger selected surface; [param border_color] defaults to accent.
static func theme_pressed_style_for(normal: StyleBoxFlat, border_color: Color = ThemeColor.accent_theme_color()) -> StyleBoxFlat:
	return StyleBoxHelper.duplicate_with_bg_color(normal, ThemeColor.promote(ThemeColor.selected_surface, Weights.w_2), border_color)


## Default hover box paired with [method theme_normal_style].
static func theme_hover_style() -> StyleBoxFlat:
	return theme_hover_style_for(theme_normal_style())


## Default pressed box paired with [method theme_normal_style].
static func theme_pressed_style() -> StyleBoxFlat:
	return theme_pressed_style_for(theme_normal_style())


## Apply normal, hover, and pressed states. [code]focus[/code] mirrors [param hover], disabled
## mirrors [param normal], and hover-pressed mirrors [param pressed]. Override a derived state
## directly when a particular button needs a distinct appearance.
##
## The hover-pressed override must not be omitted: Godot resolves a missing item from the default
## theme, so a button that only overrides normal / hover / pressed paints the engine's own box
## while it is pressed *and* hovered.
##
## Style boxes default to [method theme_normal_style] and its paired hover / pressed states.
## Omitted [param hover] and [param pressed] are derived from the resolved [param normal].
static func apply_style(button: BaseButton, normal: StyleBoxFlat = null, hover: StyleBoxFlat = null, pressed: StyleBoxFlat = null) -> void:
	var resolved_normal := normal if normal != null else theme_normal_style()
	var resolved_hover := hover if hover != null else theme_hover_style_for(resolved_normal)
	var resolved_pressed := pressed if pressed != null else theme_pressed_style_for(resolved_normal)
	button.add_theme_stylebox_override("normal", resolved_normal)
	button.add_theme_stylebox_override("hover", resolved_hover)
	button.add_theme_stylebox_override("pressed", resolved_pressed)
	button.add_theme_stylebox_override("focus", resolved_hover.duplicate() as StyleBoxFlat)
	button.add_theme_stylebox_override("disabled", resolved_normal.duplicate() as StyleBoxFlat)
	button.add_theme_stylebox_override("hover_pressed", resolved_pressed.duplicate() as StyleBoxFlat)
	pass


## Text colors for the same states, one per `font_*_color` theme item: focus mirrors
## [param hover] and hover-pressed mirrors [param pressed], the same pairing
## [method apply_style] uses for the boxes.
##
## Those two are not optional — an item left out is resolved from the default theme, whose focus
## and hover-pressed text are near white and would vanish on a light surface.
##
## Disabled text defaults to [param normal] at half alpha.
static func apply_font_colors(button: BaseButton, normal: Color, hover: Color, pressed: Color) -> void:
	button.add_theme_color_override("font_color", normal)
	button.add_theme_color_override("font_hover_color", hover)
	button.add_theme_color_override("font_pressed_color", pressed)
	button.add_theme_color_override("font_focus_color", hover)
	button.add_theme_color_override("font_hover_pressed_color", pressed)
	button.add_theme_color_override("font_disabled_color", Color(normal, Weights.w_8))
	pass


## Icon colors for the same interaction states as [method apply_font_colors]. This keeps icon-only
## toolbar buttons from falling back to the engine's white pressed/hover icon colors in light UI.
## Disabled icons default to [param base_color] at half alpha.
static func apply_icon_colors(button: BaseButton, base_color: Color, hover_color: Color, pressed_color: Color) -> void:
	button.add_theme_color_override("icon_normal_color", base_color)
	button.add_theme_color_override("icon_hover_color", hover_color)
	button.add_theme_color_override("icon_pressed_color", pressed_color)
	button.add_theme_color_override("icon_focus_color", hover_color)
	button.add_theme_color_override("icon_hover_pressed_color", pressed_color)
	button.add_theme_color_override("icon_disabled_color", Color(base_color, Weights.w_8))
	pass


## Theme a [CheckButton] toggle: no button chrome, accent checked indicator, optional label colors.
##
## [param hover_color] and [param pressed_color] default to [param base_color] when left transparent.
## [param checked_color] defaults to [ThemeColor.accent_theme_color].
## Horizontal margins default symmetric ([code]ma_1[/code]); spacing between icon and label uses [code]h_separation[/code].
static func apply_check_button(
	check: CheckButton,
	base_color: Color = Colors.primary_text,
	hover_color: Color = Color.TRANSPARENT,
	pressed_color: Color = Color.TRANSPARENT,
	checked_color: Color = Color.TRANSPARENT,
	h_separation: int = Margin.ma_2,
	margin_left: int = Margin.ma_0,
	margin_top: int = Margin.ma_1,
	margin_right: int = Margin.ma_1,
	margin_bottom: int = Margin.ma_1
) -> void:
	var hover := hover_color if hover_color != Color.TRANSPARENT else base_color
	var pressed := pressed_color if pressed_color != Color.TRANSPARENT else hover
	apply_font_colors(check, base_color, hover, pressed)
	check.add_theme_color_override("button_checked_color", checked_color if checked_color != Color.TRANSPARENT else ThemeColor.accent_theme_color())
	check.add_theme_constant_override("h_separation", h_separation)
	var empty := StyleBoxEmpty.new()
	StyleBoxHelper.apply_margin(empty, margin_top, margin_right, margin_bottom, margin_left)
	for state: String in ["normal", "disabled", "focus", "hover", "pressed", "hover_pressed"]:
		check.add_theme_stylebox_override(state, empty.duplicate())
	pass


## Apply standard dropdown states: the normal surface gains an accent outline while hovered,
## pressed, or focused, and retains the shared text colors in every state.
static func apply_option_button(option: OptionButton, normal: StyleBoxFlat = null, text_color: Color = Colors.primary_text) -> void:
	var resolved_normal := normal if normal != null else LineEditStyle.theme_normal_style()
	var hover: StyleBoxFlat = resolved_normal.duplicate() as StyleBoxFlat
	hover.border_color = ThemeColor.accent_theme_color()
	apply_style(option, resolved_normal, hover, hover.duplicate())
	apply_font_colors(option, text_color, text_color, text_color)
	PopupMenuStyle.apply(option.get_popup())
	pass
