## Material snackbar on `gdf_layer`: an accent-tinted card (near-black with near-white text in the dark
## theme) and the semantic color as a stripe down both edges. Its surface follows [ThemeColor], so
## the snackbar follows the app accent.
## It drops in at the top center — one short fall from the top edge of the screen down to
## [constant Margin.ma_6] — holds, then fades out; live cards stack downward, the newest one hugging
## the top edge.
##
## Example: `Alert.alert("Saved", Colors.success)`
class_name Alert
extends PanelContainer

## Entry drop and re-stacking shift — both are short moves, fading in on the way down.
const move_seconds: float = 0.18
## Plain fade-out that ends the toast.
const exit_seconds: float = 0.22
const default_wait_time: int = 2700
## A snackbar stays on one line: text wider than this is trimmed with an ellipsis instead of wrapped.
const text_max_width: float = 720.0
## Drop shadow. The alpha has to follow the theme: one value either vanishes over the light card or
## smudges over the dark one.
const shadow_alpha_dark: float = 0.35
const shadow_alpha_light: float = 0.18
const shadow_size: int = 4
const shadow_offset: Vector2 = Vector2(0.0, 2.0)

## Live cards, oldest first — [method relayout] stacks them from the top edge downward.
static var alerts: Array[Alert] = []

var label: Label
## Motion tween (entry drop, re-stacking) and the separate fade tween, so retargeting the motion never
## freezes an entry fade half-way.
var move_tween: Tween
var fade_tween: Tween


static func create_alert(i18n_text: String, stripe_color: Color) -> Alert:
	var card := Alert.new()
	# A toast never swallows a click meant for the UI underneath it.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", make_card_style(stripe_color))
	card.label = Label.new()
	card.label.text = I18n.t(i18n_text)
	card.label.vertical_alignment = VerticalAlignment.VERTICAL_ALIGNMENT_CENTER
	card.label.add_theme_font_override("font", make_font())
	card.label.add_theme_font_size_override("font_size", Typography.body_large_size)
	# Near-white on the dark surface, dark on the light one — the accent-tinted card decides this.
	card.label.add_theme_color_override("font_color", ThemeColor.title_color)
	card.label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.add_child(card.label)
	card.resize_to_text()
	return card


## Dark surface in the app accent, with the semantic color as a stripe on each side and the card shadow.
static func make_card_style(stripe_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ThemeColor.accent_surface
	style.set_corner_radius_all(ControlSize.radius_md)
	style.content_margin_left = Margin.ma_4
	style.content_margin_right = Margin.ma_4
	style.content_margin_top = Margin.ma_3
	style.content_margin_bottom = Margin.ma_3
	style.border_color = stripe_color
	style.set_border_width(SIDE_LEFT, ControlSize.border_md)
	style.set_border_width(SIDE_RIGHT, ControlSize.border_md)
	style.shadow_color = Color(0.0, 0.0, 0.0, shadow_alpha_dark if ThemeColor.is_dark_theme() else shadow_alpha_light)
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	return style


## Medium weight at the body letter spacing, so a snackbar reads as part of the app type scale.
static func make_font() -> Font:
	var variation := FontVariation.new()
	variation.base_font = Fonts.medium()
	variation.spacing_glyph = Typography.letter_spacing_xs
	return variation


## One line, [constant text_max_width] of text at most. Both axes come from the font metrics instead
## of [method Control.get_combined_minimum_size], whose theme cache is only filled once the card
## enters the tree: this way sizing, resting slot and entry start are fixed on the very first frame.
func resize_to_text() -> void:
	var font: Font = label.get_theme_font("font")
	var text_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Typography.body_large_size).x
	var style: StyleBox = get_theme_stylebox("panel")
	size = Vector2(
		minf(text_width, text_max_width) + style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT),
		font.get_height(Typography.body_large_size) + style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	)
	pass


## Snackbar slot: top center, [constant Margin.ma_6] below the top edge and pushed further down by the
## cards stacked below it.
func slot_position() -> Vector2:
	var viewport: Vector2 = gdf.gdf_node.get_viewport().get_visible_rect().size
	var lift: float = 0.0
	for i in range(alerts.find(self) + 1, alerts.size()):
		var newer: Alert = alerts[i]
		if is_instance_valid(newer):
			lift += newer.size.y + Margin.ma_3
	return Vector2((viewport.x - size.x) / 2.0, Margin.ma_6 + lift)


## Drop in from the top edge of the screen into the slot, fading in on the way down: the fall covers one
## [constant Margin.ma_6], from y = 0 to the resting inset. Takes over from the slot tween
## [method relayout] started for this card, which has not moved it yet.
func drop_in() -> void:
	position = Vector2(slot_position().x, 0.0)
	make_move_tween().tween_property(self, "position", slot_position(), move_seconds)
	fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 1.0, move_seconds)
	pass


## Tween into a slot: the re-stacking move when a card arrives above or leaves the stack. Only the
## motion is retargeted — the entry fade tween is left alone, so it still reaches full alpha.
func slide_to(target: Vector2) -> void:
	if position.is_equal_approx(target):
		return
	make_move_tween().tween_property(self, "position", target, move_seconds)
	pass


## Ease-out tween that drives the card, replacing the one still in flight.
func make_move_tween() -> Tween:
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return move_tween


## Fade out, free, and let the cards below slide back up to the top edge. Safe to run twice.
func dismiss() -> void:
	if is_queued_for_deletion():
		return
	alerts.erase(self)
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	if fade_tween != null and fade_tween.is_valid():
		fade_tween.kill()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, exit_seconds)
	await tween.finished
	queue_free()
	relayout()
	pass


## Move every live card into its slot.
static func relayout() -> void:
	for i in range(alerts.size() - 1, -1, -1):
		var card: Alert = alerts[i]
		if is_instance_valid(card):
			card.slide_to(card.slot_position())
	pass

####################################################################################################
# Alert

## Show a snackbar for [constant default_wait_time] ms. [param i18n_text] may be a translation key;
## text without a registered translation is displayed unchanged.
static func alert(i18n_text: String, color: Color) -> void:
	var card: Alert = create_alert(i18n_text, color)
	# Hidden before the first frame: without a slot yet, an opaque card would flash at the tree origin.
	card.modulate.a = 0.0
	gdf.gdf_layer.add_child(card)
	alerts.append(card)
	# The cards below make room, then the new one drops in from the top edge of the screen.
	relayout()
	card.drop_in()
	await ThreadUtils.async_sleep(default_wait_time)
	# A scene change or another caller may have dismissed the card already.
	if is_instance_valid(card):
		await card.dismiss()
	pass
