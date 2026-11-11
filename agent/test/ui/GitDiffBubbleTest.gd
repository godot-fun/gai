extends Object

## Regression guard for the git diff bubble header.
##
## The header is one row of xs-tall controls. The rollback help disc used the default sm tier, so it
## set the row height and stretched Revert / Diff with it — the two buttons grew taller than the
## title beside them.

const WIDTH := 440.0


func git_diff_header_buttons_share_the_xs_tier_test() -> void:
	var host := add_host()
	await settled()
	var bubble := build_bubble(host)
	await settled()

	for button_name: String in ["RollbackHelpButton", "RevertButton", "DiffButton"]:
		var button := bubble.find_child(button_name, true, false) as Button
		assert(button != null)
		assert(button.custom_minimum_size.y == ControlSize.xs)
		assert(is_equal_approx(button.size.y, ControlSize.xs))

	# Nothing in the row may ask for more height than the buttons themselves.
	var header := bubble.find_child("RollbackHelpButton", true, false).get_parent() as Control
	assert(is_equal_approx(header.size.y, ControlSize.xs))
	host.queue_free()
	pass


func build_bubble(host: Control) -> GitDiffBubble:
	var details: Dictionary[String, String] = {}
	details[ChatEntry.DETAIL_CHECKPOINT] = "0".repeat(40)
	details[ChatEntry.DETAIL_GIT_DIFF_PATCH] = "patch"
	var entry := ChatEntry.new(ChatEntry.KIND_GIT_DIFF, ChatEntry.TITLE_GIT_DIFF, "agent/ui/toolbar/EditorButton.gd\t12\t3", details)
	var bubble := GitDiffBubble.new()
	bubble.apply(1, entry)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.add_child(bubble)
	return bubble


static func add_host() -> Control:
	var host := VBoxContainer.new()
	host.size = Vector2(WIDTH, 0.0)
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(host)
	return host


static func settled() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	await tree.process_frame
	await tree.process_frame
	pass
