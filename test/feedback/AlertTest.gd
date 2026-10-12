## Unit tests for [Alert]. Loaded with the other scripts in this folder by [code]test/feedback/FeedbackTest.tscn[/code] ([UnitTest]).

## [method Alert.show_alert] builds a single-line card: accent-tinted surface, semantic stripe, app font.
func Alert_create_card_test() -> void:
	var card := Alert.create_alert("feedback", Colors.success)
	assert(card.label != null)
	assert(card.label.text == "feedback")
	assert(card.label.get_theme_font_size("font_size") == Typography.body_large_size)
	assert(card.label.get_theme_font("font") is FontVariation)
	assert(card.label.get_theme_color("font_color") == ThemeColor.title_color)
	assert(card.label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert(card.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var style := card.get_theme_stylebox("panel") as StyleBoxFlat
	assert(style.bg_color == ThemeColor.accent_surface)
	assert(style.border_color == Colors.success)
	assert(style.border_width_left == ControlSize.border_md)
	assert(style.border_width_right == ControlSize.border_md)
	assert(style.border_width_top == 0 and style.border_width_bottom == 0)
	assert(style.corner_radius_top_left == ControlSize.radius_md)
	assert(style.content_margin_left == Margin.ma_4)
	assert(style.shadow_size == Alert.shadow_size)
	card.free()
	pass


## Display text is resolved through [TranslationServer]; unknown text remains unchanged.
func Alert_i18n_text_test() -> void:
	var translation := feedback_test_translation("feedback.alert", "Translated alert")
	var card := Alert.create_alert("feedback.alert", Colors.success)
	assert(card.label.text == "Translated alert")
	card.free()
	TranslationServer.remove_translation(translation)
	pass


## [method Alert.resize_to_text] hugs short text and caps long text at [constant Alert.text_max_width].
func Alert_single_line_test() -> void:
	var card := Alert.create_alert("feedback", Colors.info)
	var style: StyleBox = card.get_theme_stylebox("panel")
	var padding: float = style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	var text_height: float = style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM) + Alert.make_font().get_height(Typography.body_large_size)
	assert(is_equal_approx(card.size.y, text_height))
	assert(card.size.x > padding and card.size.x < Alert.text_max_width)
	var long_card := Alert.create_alert("feedback ".repeat(40), Colors.info)
	assert(is_equal_approx(long_card.size.x, Alert.text_max_width + padding))
	pass


## [method Alert.slide_to] tweens the card into its slot instead of snapping there on the first frame.
func Alert_slide_to_test() -> void:
	var card := Alert.create_alert("feedback", Colors.info)
	gdf.gdf_layer.add_child(card)
	card.position = Vector2(100.0, 100.0)
	card.slide_to(Vector2(100.0, 300.0))
	assert(card.position == Vector2(100.0, 100.0))
	await ThreadUtils.async_sleep(Alert.move_seconds * 1000.0 + 100.0)
	assert(card.position.is_equal_approx(Vector2(100.0, 300.0)))
	card.queue_free()
	pass


## [method Alert.drop_in] falls from the top edge of the screen into the top-center slot — a short drop.
func Alert_drop_in_test() -> void:
	var card := Alert.create_alert("feedback", Colors.info)
	gdf.gdf_layer.add_child(card)
	Alert.alerts.append(card)
	card.modulate.a = 0.0
	card.drop_in()
	var viewport_size := card.get_viewport().get_visible_rect().size
	assert(is_equal_approx(card.position.y, 0.0))
	assert(is_equal_approx(card.position.x, (viewport_size.x - card.size.x) / 2.0))
	await ThreadUtils.async_sleep(Alert.move_seconds * 1000.0 + 100.0)
	assert(card.position.is_equal_approx(card.slot_position()))
	# A short drop: the card settles at the top edge, not across the screen.
	assert(is_equal_approx(card.position.y, Margin.ma_6))
	assert(card.position.y < viewport_size.y / 2.0)
	assert(is_equal_approx(card.modulate.a, 1.0))
	Alert.alerts.erase(card)
	card.queue_free()
	pass


## [method Alert.alert] mounts a hidden card at the top edge, drops it into the top-center slot, then frees it.
func Alert_alert_test() -> void:
	var existing := live_alerts()
	Alert.alert("feedback alert test", Colors.success)
	var card := top_alert()
	assert(card != null and !existing.has(card))
	assert(card.label.text == "feedback alert test")
	# Positioned synchronously: the first frame shows it faded out at the top edge of the screen.
	assert(is_equal_approx(card.modulate.a, 0.0))
	assert(is_equal_approx(card.position.y, 0.0))
	assert(is_equal_approx(card.position.x, (card.get_viewport().get_visible_rect().size.x - card.size.x) / 2.0))
	await ThreadUtils.async_sleep(Alert.move_seconds * 1000.0 + 100.0)
	var viewport_size := card.get_viewport().get_visible_rect().size
	assert(card.position.is_equal_approx(card.slot_position()))
	assert(is_equal_approx(card.position.x, (viewport_size.x - card.size.x) / 2.0))
	assert(is_equal_approx(card.position.y, Margin.ma_6))
	assert(is_equal_approx(card.modulate.a, 1.0))
	await ThreadUtils.async_sleep(Alert.default_wait_time + Alert.exit_seconds * 1000.0 + 300.0)
	await gdf.gdf_node.get_tree().process_frame
	assert(!is_instance_valid(card))
	pass


## A card arriving while another is still fading in must not freeze that one half-transparent: the
## re-stacking move retargets the motion only and leaves the entry fade running.
func Alert_interrupted_entry_test() -> void:
	Alert.alert("interrupted first", Colors.info)
	var first := top_alert()
	Alert.alert("interrupted second", Colors.success)
	var second := top_alert()
	assert(first != second)
	assert(first.modulate.a < 1.0)
	await ThreadUtils.async_sleep(Alert.move_seconds * 1000.0 + 100.0)
	assert(is_equal_approx(first.modulate.a, 1.0))
	await first.dismiss()
	await second.dismiss()
	pass


## Live cards stack downward: the newest hugs the top edge, the older one sits below it by a height plus the gap.
func Alert_stack_test() -> void:
	var existing := live_alerts()
	var stacked := Alert.alerts.size()
	Alert.alert("stack first", Colors.info)
	var first := top_alert()
	Alert.alert("stack second", Colors.success)
	var second := top_alert()
	# The older card is only tweened downward, so compare the slots it is heading for.
	assert(is_equal_approx(second.slot_position().y, Margin.ma_6))
	assert(is_equal_approx(second.slot_position().x, (second.get_viewport().get_visible_rect().size.x - second.size.x) / 2.0))
	assert(is_equal_approx(second.slot_position().y + second.size.y + Margin.ma_3, first.slot_position().y))
	# Dismissing takes a card out of the live list before the node itself is freed.
	await first.dismiss()
	await second.dismiss()
	assert(Alert.alerts.size() == stacked)
	await gdf.gdf_node.get_tree().process_frame
	assert(live_alerts().size() == existing.size())
	pass


## Live cards: a dismissed one leaves [member Alert.alerts] first and is freed at the end of the frame,
## so it must not count as still on screen.
func live_alerts() -> Array[Alert]:
	var cards: Array[Alert] = []
	for child in gdf.gdf_layer.get_children():
		if child is Alert and not child.is_queued_for_deletion():
			cards.push_back(child)
	return cards


func top_alert() -> Alert:
	var cards := live_alerts()
	return null if cards.is_empty() else cards[cards.size() - 1]


func feedback_test_translation(key: String, value: String) -> Translation:
	var translation := Translation.new()
	translation.locale = TranslationServer.get_locale()
	translation.add_message(key, value)
	TranslationServer.add_translation(translation)
	return translation
