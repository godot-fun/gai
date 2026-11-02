class_name LocalTokenizer
extends Object

## Offline, dependency-free stand-in for the llama-server `/tokenize` endpoint.
## Used by visual effects that must never wait for a cold model start (or for a machine
## without the gguf dependencies). Splits on visible word boundaries only: CJK per
## character, latin/digit runs kept as whole words, punctuation alone.

## Qwen2/MiniCPM-V vocabulary size; IDs stay inside it so downstream id-based colors and
## embedding positions look the same as real model tokens.
const VOCAB_SIZE: int = 151936
const MAX_TOKENS: int = 128
## SentencePiece word-boundary marker after whitespace; [method TransformerTokenNode.display_piece] renders it as a space.
const SPACE_MARKER: String = "▁"
const NEWLINE: String = "\n"


## Splits text into pieces with deterministic IDs. Consecutive whitespace collapses into one marker.
static func tokenize(text: String) -> Array[LlamaHelper.Token]:
	var tokens: Array[LlamaHelper.Token] = []
	var source := text.replace("\r\n", NEWLINE).replace("\r", NEWLINE)
	var index := 0
	var pending_space := false
	while index < source.length() and tokens.size() < MAX_TOKENS:
		var code := source.unicode_at(index)
		if code == 32 or code == 9:
			pending_space = true
			index += 1
			continue
		if code == 10:
			append_token(tokens, NEWLINE)
			pending_space = false
			index += 1
			continue
		if is_word_char(code):
			var end := index
			while end < source.length() and is_word_char(source.unicode_at(end)):
				end += 1
			append_token(tokens, (SPACE_MARKER if pending_space else "") + source.substr(index, end - index))
			pending_space = false
			index = end
			continue
		append_token(tokens, (SPACE_MARKER + source[index]) if pending_space else source[index])
		pending_space = false
		index += 1
	return tokens


## Rebuilds the source text from pieces; the inverse of [method tokenize] for single-space input.
static func restore_text(tokens: Array[LlamaHelper.Token]) -> String:
	var builder := StringBuilder.new()
	for token in tokens:
		builder.append(token.piece.replace(SPACE_MARKER, " "))
	return builder.build_string()


## FNV-1a over the UTF-8 bytes so a piece keeps one ID across runs, effects, and OS builds.
static func stable_token_id(piece: String) -> int:
	var value := 2166136261
	for byte in piece.to_utf8_buffer():
		value = (value ^ byte) * 16777619 & 0xFFFFFFFF
	return int(value % VOCAB_SIZE)


static func is_word_char(code: int) -> bool:
	if code >= 48 and code <= 57:
		return true
	if code >= 65 and code <= 90:
		return true
	if code >= 97 and code <= 122:
		return true
	# Keep common word-internal marks glued to their run: apostrophe, hyphen, underscore, accented latin.
	return code == 39 or code == 45 or code == 95 or (code >= 0xC0 and code <= 0x24F)


static func append_token(tokens: Array[LlamaHelper.Token], piece: String) -> void:
	tokens.append(LlamaHelper.Token.new(stable_token_id(piece), piece))
	pass
