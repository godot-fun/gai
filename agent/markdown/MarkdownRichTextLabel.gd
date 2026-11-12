class_name MarkdownRichTextLabel
extends RichTextLabel

## Rendered Markdown body: a selectable [RichTextLabel] that also drops its highlight when a click lands
## outside it, and remembers the Markdown it was rendered from.
##
## `deselect_on_focus_loss_enabled` only fires when focus moves to another *focusable* control, and a
## click on a bubble background never moves focus at all (chat lists and their panels are not focusable),
## so the highlight outlived the click that was meant to clear it. The label therefore watches presses
## itself: [method _input] runs before GUI routing, so pressing outside clears the highlight before the
## click reaches whatever is underneath. Watch starts on the press that selects and ends with the
## highlight, so labels without one stay out of the input path.

## Markdown this body was rendered from. Two files can share a name, and a link click has to know which
## one holds this very text; the rendered text itself has already lost its markers.
var raw_text: String = ""


func _init() -> void:
	# selection_enabled already forces FOCUS_ALL; focus loss stays as the cheap path for clicks that do
	# land on another focusable control.
	selection_enabled = true
	deselect_on_focus_loss_enabled = true
	gui_input.connect(on_body_gui_input)
	focus_exited.connect(stop_outside_press_watch)


## A script `_input` is auto-enabled on ready; only a highlight needs it here.
func _ready() -> void:
	stop_outside_press_watch()
	pass


## Left press inside — RichTextLabel starts (or clears) a highlight from here.
func on_body_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
		start_outside_press_watch()
	pass


## Input processing is the watch: outside this window [method _input] is not called at all.
func start_outside_press_watch() -> void:
	set_process_input(true)
	pass


func stop_outside_press_watch() -> void:
	set_process_input(false)
	pass


## Right click opens the copy menu and the wheel only scrolls the chat history — both read the
## highlight, so a left press outside is the one that clears it.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if get_global_rect().has_point(mouse.position):
		return
	stop_outside_press_watch()
	deselect()
	pass
