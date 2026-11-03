class_name ChatInputCompletionProvider
extends RefCounted

## One trigger of the composer completion list — `/skill` today, `@file` — and the shared contract
## [ChatInputCompletion] needs from it.
##
## A provider owns three facts and nothing else: whether the caret sits in its token, which rows the
## list may show for that token, and which columns of the caret line an accepted row replaces. The
## dispatcher adds colors and kinds, talks to [CodeEdit], and performs the replacement.

var input_field: CodeEdit


## True while the caret sits inside this provider's token, i.e. while the list may show at all.
func is_active() -> bool:
	return false


## Rows for the current token in display order. Each row carries `display_text` (what the popup
## draws) and `insert_text` (what the field holds once the row is accepted).
func build_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	return options


## Caret-line column span the accepted row replaces: `x` is the first token column, `y` the column
## right after its last character. `Vector2i(-1, -1)` means the token is gone.
func token_span() -> Vector2i:
	return Vector2i(-1, -1)
