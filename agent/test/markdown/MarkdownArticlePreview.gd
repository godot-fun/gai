extends Control

@onready var background: ColorRect = $Background
@onready var page_margin: MarginContainer = $ContentScroll/PageMargin
@onready var article_body: VBoxContainer = $ContentScroll/PageMargin/ArticleBody


func _ready() -> void:
	background.color = Colors.app_background
	page_margin.add_theme_constant_override("margin_left", Margin.ma_12)
	page_margin.add_theme_constant_override("margin_top", Margin.ma_8)
	page_margin.add_theme_constant_override("margin_right", Margin.ma_12)
	page_margin.add_theme_constant_override("margin_bottom", Margin.ma_12)
	article_body.add_theme_constant_override("separation", Margin.ma_4)
	render_article()
	gdf.events.test_passed.emit()
	pass


func render_article() -> void:
	article_body.add_child(MarkdownHelper.create_rich_text_label(Colors.primary_text, MarkdownArticleFixture.ARTICLE, true))
	pass
