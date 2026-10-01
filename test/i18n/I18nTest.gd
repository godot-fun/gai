extends Object


func resolve_locale_empty_defaults_to_en_test() -> void:
	assert(I18n.resolve_locale("") == I18n.EN)
	assert(I18n.resolve_locale("   ") == I18n.EN)
	pass


func resolve_locale_language_only_test() -> void:
	assert(I18n.resolve_locale("en") == I18n.EN)
	assert(I18n.resolve_locale("ja_JP") == I18n.JA)
	assert(I18n.resolve_locale("ko-KR") == I18n.KO)
	assert(I18n.resolve_locale("fr_CA") == I18n.FR)
	pass


func resolve_locale_chinese_by_country_test() -> void:
	assert(I18n.resolve_locale("zh_CN") == I18n.ZH_HANS)
	assert(I18n.resolve_locale("zh_SG") == I18n.ZH_HANS)
	assert(I18n.resolve_locale("zh_TW") == I18n.ZH_HANT)
	assert(I18n.resolve_locale("zh_HK") == I18n.ZH_HANT)
	assert(I18n.resolve_locale("zh_MO") == I18n.ZH_HANT)
	pass


func resolve_locale_chinese_by_script_test() -> void:
	assert(I18n.resolve_locale("zh_Hans") == I18n.ZH_HANS)
	assert(I18n.resolve_locale("zh_Hant") == I18n.ZH_HANT)
	assert(I18n.resolve_locale("zh_Hans_CN") == I18n.ZH_HANS)
	assert(I18n.resolve_locale("zh_Hant_TW") == I18n.ZH_HANT)
	pass


func resolve_locale_strips_extra_test() -> void:
	assert(I18n.resolve_locale("zh_CN@currency=CNY") == I18n.ZH_HANS)
	assert(I18n.resolve_locale("en_US@calendar=gregorian") == I18n.EN)
	pass


func resolve_locale_generic_chinese_test() -> void:
	assert(I18n.resolve_locale("zh") == I18n.ZH)
	pass
