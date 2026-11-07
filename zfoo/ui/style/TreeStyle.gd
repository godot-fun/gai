class_name TreeStyle
extends RefCounted

## Applies the shared full-width interaction states used by navigation trees.
static func apply_full_width_rows(tree: Tree, margin_x: int = 0, margin_y: int = 0) -> void:
	var selected := make_full_width_row(ThemeColor.selected_surface, margin_x, margin_y)
	var hover := make_full_width_row(
		ThemeColor.inset_surface.lerp(ThemeColor.accent_theme_color(), Weights.w_2), margin_x, margin_y)
	for state in ["selected", "selected_focus", "hovered_selected", "hovered_selected_focus"]:
		tree.add_theme_stylebox_override(state, selected.duplicate() as StyleBoxFlat)
	for state in ["hovered", "hovered_dimmed"]:
		tree.add_theme_stylebox_override(state, hover.duplicate() as StyleBoxFlat)
	pass


## Tree rows start at their indentation point; overscan makes the background span the control width.
static func make_full_width_row(background: Color, margin_x: int = 0, margin_y: int = 0) -> StyleBoxFlat:
	var style := StyleBoxHelper.create_style_box_flat(background, 0, margin_x, margin_y)
	style.expand_margin_left = 4096
	style.expand_margin_right = 4096
	return style
