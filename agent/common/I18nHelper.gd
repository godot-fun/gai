class_name I18nHelper
extends Object


class LocaleConfig:
	var locale_path: String
	var language: String

	func _init(path: String, locale_language: String) -> void:
		locale_path = path
		language = locale_language
		pass


static var LOCALE_PATHS: Dictionary[String, LocaleConfig] = {
	I18n.ZH: LocaleConfig.new("res://agent/config/locale/zh.json", "简体中文"),
	I18n.EN: LocaleConfig.new("res://agent/config/locale/en.json", "English"),
}

static func init_i18n() -> void:
	if I18n.is_initialized():
		return
	var locale := I18n.get_locale().get_slice("_", 0).get_slice("-", 0).to_lower()
	if not LOCALE_PATHS.has(locale):
		locale = I18n.EN
	var locale_config: LocaleConfig = LOCALE_PATHS.get(locale, LOCALE_PATHS[I18n.EN])
	I18n.set_locale(locale_config.locale_path)
	pass
