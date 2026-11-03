class_name MarkdownHighlighter
extends Object

## Markdown and MDX [CodeEdit] highlighting ([member EXTENSIONS]).
## [CodeHighlighter] start keys must be symbol-only ([code]__[/code] and [code]][/code] are invalid).

const EXTENSIONS := ["md", "markdown", "mdx"]
const ALERT_KEYWORDS := ["TODO", "FIXME", "NOTE", "WARNING", "IMPORTANT", "TIP", "CAUTION"]
const URL_SCHEMES := ["http://", "https://", "mailto:", "res://", "user://", "ftp://"]


static func configure(highlighter: CodeHighlighterInstance) -> void:
	CommonHighlighter.add_quoted_strings(highlighter, CodeColors.string)
	CommonHighlighter.add_keywords(highlighter, ALERT_KEYWORDS, CodeColors.declaration)
	add_url_keywords(highlighter)
	highlighter.add_color_region("```", "```", CodeColors.string)
	highlighter.add_color_region("~~~", "~~~", CodeColors.string)
	highlighter.add_color_region("`", "`", CodeColors.string)
	highlighter.add_color_region("<!--", "-->", CodeColors.comment)
	highlighter.add_color_region("[", "]", CodeColors.function)
	highlighter.add_color_region("<", ">", CodeColors.link)
	highlighter.add_color_region("#", "", CodeColors.declaration, true)
	highlighter.add_color_region("**", "**", CodeColors.keyword)
	highlighter.add_color_region("~~", "~~", CodeColors.comment)
	pass


static func add_url_keywords(highlighter: CodeHighlighterInstance) -> void:
	for scheme in URL_SCHEMES:
		highlighter.add_keyword_color(scheme, CodeColors.link)
	pass
