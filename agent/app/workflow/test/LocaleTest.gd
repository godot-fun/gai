## Locale label tests for GraphNodesConfig node definitions.

const LOCALE_PATH_EN := "res://agent/config/locale/en.json"
const LOCALE_PATH_ZH := "res://agent/config/locale/zh.json"


func ensure_translations() -> void:
	if not TranslationServer.has_translation_for_locale(I18n.EN, true):
		I18n.set_locale(LOCALE_PATH_EN)
	pass


func locale_keys_match_test() -> void:
	assert(I18nCheck.check_configs([LOCALE_PATH_EN, LOCALE_PATH_ZH]) == OK)
	pass


func graph_nodes_locale_test() -> void:
	ensure_translations()
	TranslationServer.set_locale(I18n.EN)
	assert(GraphNodesConfig.get_def("input-audio").display_label() == I18n.t("workflow.node.input-audio"))
	assert(GraphNodesConfig.category_label(GraphNodesConfig.SOURCE_CATEGORY) == I18n.t("workflow.category.source"))
	assert(GraphNodesConfig.category_label(GraphNodesConfig.SKILL_CATEGORY_AUDIO) == I18n.t("common.audio"))
	for key in ["common.audio", "common.file", "workflow.node_port.audio-to-wav.out", "workflow.pipeline.stopped"]:
		assert(I18n.t(key) != key)
	pass


func translation_server_locale_test() -> void:
	ensure_translations()
	TranslationServer.set_locale(I18n.EN)
	assert(I18n.t("workflow.window_title") == I18n.t("workflow window_title"))
	pass
