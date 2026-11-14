class_name ChatInputCompletion
extends RefCounted

## The composer's completion list: `/skill` commands and `@file` references.
##
## [CodeEdit] owns the popup but none of its default behavior fits a chat box. It filters rows by its
## own word rules (subsequence over `display_text`, reordered by match quality) and replaces only the
## trailing "base" of the token, so `@agent/ui` or `/audio-t` cannot survive it. [ChatInputEdit]
## therefore overrides the three completion virtuals — request, filter, confirm — and every decision
## lands here:
##
## - request: ask the active provider for rows and hand them over ([method async_refresh]);
## - filter: give the rows back untouched ([method filter_candidates]);
## - confirm: replace the whole token with the accepted row ([method confirm]).
##
## Providers are asked in order and the first active one wins. Accepting always rebuilds the list, so a
## child folder row (`@agent/`) keeps drilling, while the row of the folder the token already names and a
## file row close it — both leave the Markdown link the drop path produces
## (`[browser/](<path/>)` / `[name](<path>) `).

## Rows the list tries to show at once; the composer is grown to match while it is open.
const POPUP_ROWS: int = 10
## Widest the list may get, in [CodeEdit]'s own `completion_max_width` unit (font sizes). The popup
## ellipsizes rows that overflow it, so rows are handed over untruncated and this is the width budget.
const POPUP_MAX_WIDTH: int = 64
## Padding around the visible rows, in line heights: one row above and one below the selection.
const POPUP_PADDING_ROWS := 2

var input_field: CodeEdit
var skill_completion: ChatInputSkillCompletion = ChatInputSkillCompletion.new()
var file_completion: ChatInputFileCompletion = ChatInputFileCompletion.new()
## Rows currently offered to the engine, in the same order as its options.
var options: Array[ChatInputCompletionProvider.CompletionRow] = []


func setup(p_input_field: CodeEdit) -> void:
	input_field = p_input_field
	input_field.code_completion_enabled = true
	skill_completion.input_field = input_field
	file_completion.input_field = input_field
	# Assigned by name on purpose: [ChatInputEdit] holds this dispatcher and this dispatcher drives
	# that field, so naming the class here would make the two scripts depend on each other, and the
	# engine crashes at shutdown on that cycle. A field without the script fails loudly right here.
	input_field.set("completion", self)
	pass


## Drops the list and forgets the rows, so a later engine re-filter cannot resurrect them.
func cancel() -> void:
	options.clear()
	input_field.update_code_completion_options(false)
	pass


func async_refresh() -> void:
	var provider := active_provider()
	if provider == null:
		cancel()
		return
	if provider == file_completion:
		await file_completion.async_refresh_index()
	var rows: Array[ChatInputCompletionProvider.CompletionRow] = provider.build_options()
	if rows.is_empty():
		cancel()
		return
	options.clear()
	options.append_array(rows)
	# Copying the rows back through [method filter_candidates] is what activates the list and resets
	# the highlighted row for the new match set.
	input_field.update_code_completion_options(true)
	pass


## Engine hook ([ChatInputEdit]): rows are already filtered and ordered, so nothing to narrow.
func filter_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for row: ChatInputCompletionProvider.CompletionRow in options:
		candidates.append({
			"display_text": row.display_text,
			"insert_text": row.insert_text,
			"kind": row.kind,
			"font_color": row.font_color,
		})
	return candidates


## Engine hook ([ChatInputEdit]): put the highlighted row in place of the token.
func confirm() -> void:
	var provider := active_provider()
	if provider == null:
		cancel()
		return
	var index: int = input_field.get_code_completion_selected_index()
	if index < 0 or index >= options.size():
		cancel()
		return
	var span: Vector2i = provider.token_span()
	if span.x < 0:
		cancel()
		return
	var line: int = input_field.get_caret_line()
	input_field.begin_complex_operation()
	input_field.remove_text(line, span.x, line, span.y)
	input_field.set_caret_column(span.x)
	input_field.insert_text_at_caret(options[index].insert_text)
	input_field.end_complex_operation()
	# A directory row leaves a live `@dir/` token under the caret and reopens the list; a file row ends
	# in a Markdown link and a skill row in a blank, so the rebuild finds no provider and stays closed.
	await async_refresh()
	pass


func active_provider() -> ChatInputCompletionProvider:
	if skill_completion.is_active():
		return skill_completion
	if file_completion.is_active():
		return file_completion
	return null


## True while the list is on screen, i.e. CodeEdit has a highlighted row.
func is_popup_open() -> bool:
	return input_field.get_code_completion_selected_index() >= 0


## Height the composer needs while the list is open. [CodeEdit] draws the list inside the field rect,
## so a short composer would only fit one or two rows; the padding rows keep the list readable.
func get_popup_height() -> float:
	var rows: int = clampi(options.size(), 1, POPUP_ROWS)
	return input_field.get_line_height() * (rows + POPUP_PADDING_ROWS) + Margin.ma_6
