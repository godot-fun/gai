class_name MarkdownHighlighter
extends Object

## Markdown and MDX [CodeEdit] highlighting ([member EXTENSIONS]).
## [CodeHighlighter] start keys must be symbol-only ([code]__[/code] and [code]][/code] are invalid).

const EXTENSIONS := ["md", "markdown", "mdx"]
const ALERT_KEYWORDS := ["TODO", "FIXME", "NOTE", "WARNING", "IMPORTANT", "TIP", "CAUTION"]


static func create() -> CodeHighlighterInstance:
	var highlighter := CodeHighlighterInstance.new()
	apply_base(highlighter)
	configure(highlighter)
	return highlighter


static func apply_base(highlighter: CodeHighlighterInstance) -> void:
	highlighter.number_color = CodeColors.number
	highlighter.symbol_color = CodeColors.symbol
	highlighter.function_color = CodeColors.function
	highlighter.member_variable_color = CodeColors.member
	pass


static func configure(highlighter: CodeHighlighterInstance) -> void:
	highlighter.add_color_region('"', '"', CodeColors.string)
	highlighter.add_color_region("'", "'", CodeColors.string)
	for word in ALERT_KEYWORDS:
		highlighter.add_keyword_color(word, CodeColors.declaration)
	highlighter.add_color_region("```", "```", CodeColors.string)
	highlighter.add_color_region("~~~", "~~~", CodeColors.string)
	highlighter.add_color_region("`", "`", CodeColors.string)
	highlighter.add_color_region("<!--", "-->", CodeColors.comment)
	highlighter.add_color_region("[", "]", CodeColors.link)
	highlighter.add_color_region("(", ")", CodeColors.link)
	highlighter.add_color_region("<", ">", CodeColors.link)
	highlighter.add_color_region("#", "", CodeColors.declaration, true)
	highlighter.add_color_region("**", "**", CodeColors.keyword)
	highlighter.add_color_region("~~", "~~", CodeColors.comment)
	pass
