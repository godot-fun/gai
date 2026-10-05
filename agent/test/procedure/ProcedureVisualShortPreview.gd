extends "res://agent/test/procedure/ProcedureVisualPreview.gd"

## Short PROCEDURE preview for quickly reviewing every animation stage.

const SHORT_PIECES: Array[String] = [
	"每次", "我", "向你", "提问", "，", "你的", "脑子", "里", "发生", "了", "什么", "？",
]
const SHORT_IDS: Array[int] = [
	97571, 14594, 84209, 93355, 10867, 62431, 73642, 31876, 55729, 91004, 48113, 20497,
]


func build_sample_tokens() -> Array[LlamaHelper.Token]:
	var tokens: Array[LlamaHelper.Token] = []
	for index in SHORT_PIECES.size():
		tokens.append(LlamaHelper.Token.new(SHORT_IDS[index], SHORT_PIECES[index]))
	return tokens
