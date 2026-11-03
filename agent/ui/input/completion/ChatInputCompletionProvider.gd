class_name ChatInputCompletionProvider
extends RefCounted

## One trigger of the composer completion list — `/skill` today, `@file` — and the shared contract
## [ChatInputCompletion] needs from it.
##
## A provider owns three facts and nothing else: whether the caret sits in its token, which
## [CompletionRow]s the list may show for that token, and which columns of the caret line an accepted
## row replaces. [ChatInputCompletion] maps those rows for [CodeEdit] and performs the replacement.

var input_field: CodeEdit


## One completion list row: popup label, insert payload, and the [CodeEdit] option fields.
class CompletionRow extends RefCounted:
	var display_text: String = ""
	var insert_text: String = ""
	var kind: int = CodeEdit.KIND_PLAIN_TEXT
	var font_color: Color = Colors.primary_text

	func _init(row_display_text: String = "", row_insert_text: String = "") -> void:
		display_text = row_display_text
		insert_text = row_insert_text
		pass


## True while the caret sits inside this provider's token, i.e. while the list may show at all.
func is_active() -> bool:
	return false


## Rows for the current token in display order.
func build_options() -> Array[CompletionRow]:
	return []


## Caret-line column span the accepted row replaces: `x` is the first token column, `y` the column
## right after its last character. `Vector2i(-1, -1)` means the token is gone.
func token_span() -> Vector2i:
	return Vector2i(-1, -1)
