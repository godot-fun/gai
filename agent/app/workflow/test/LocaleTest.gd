## Locale label tests for GraphNodesConfig node definitions.

const LOCALE_PATH_EN := "res://agent/config/locale/en.json"


func ensure_translations() -> void:
	if not TranslationServer.has_translation_for_locale(I18n.EN, true):
		I18n.set_locale(LOCALE_PATH_EN)
	pass


func graph_nodes_locale_test() -> void:
	ensure_translations()
	TranslationServer.set_locale(I18n.EN)
	assert(GraphNodesConfig.get_def("input-audio").display_label() == I18n.t("node.input-audio"))
	assert(GraphNodesConfig.category_label(GraphNodesConfig.SOURCE_CATEGORY) == I18n.t("category.source"))
	pass


func translation_server_locale_test() -> void:
	ensure_translations()
	TranslationServer.set_locale(I18n.EN)
	assert(I18n.t("workflow.window_title") == I18n.t("workflow window_title"))
	pass
