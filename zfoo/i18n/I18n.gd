class_name I18n
extends Object

const LOCALE_SETTING_KEY := "locale"

## Common language codes (ISO 639-1).
## Top 10 by total speakers (Ethnologue): EN ZH HI ES FR AR BN PT RU UR.
const AR := "ar" ## Arabic
const BN := "bn" ## Bengali
const DE := "de" ## German
const EN := "en" ## English
const ES := "es" ## Spanish
const FR := "fr" ## French
const HI := "hi" ## Hindi
const ID := "id" ## Indonesian
const IT := "it" ## Italian
const JA := "ja" ## Japanese
const KO := "ko" ## Korean
const NL := "nl" ## Dutch
const PL := "pl" ## Polish
const PT := "pt" ## Portuguese
const RU := "ru" ## Russian
const TH := "th" ## Thai
const TR := "tr" ## Turkish
const UK := "uk" ## Ukrainian
const UR := "ur" ## Urdu
const VI := "vi" ## Vietnamese
const ZH := "zh" ## Chinese
const ZH_HANS := "zh_Hans" ## Simplified Chinese
const ZH_HANT := "zh_Hant" ## Traditional Chinese


## Saved locale, or a system-detected language code when unset.
static func get_locale() -> String:
	var locale := Setting.get_string(LOCALE_SETTING_KEY)
	if not locale.is_empty():
		return locale
	var system_locale := OS.get_locale()
	if system_locale.is_empty():
		system_locale = TranslationServer.get_locale()
	return resolve_locale(system_locale)


static func is_initialized() -> bool:
	var locale := Setting.get_string(LOCALE_SETTING_KEY)
	return not locale.is_empty() and TranslationServer.has_translation_for_locale(locale, true)


static func t(key: String) -> String:
	return TranslationServer.translate(key)


## Loads the translation at path when needed, then switches to its declared locale.
static func set_locale(locale_path: String) -> void:
	var locale_data := LocaleData.parse_json_file(locale_path)
	if locale_data == null:
		return
	remove_old_locale_translation()
	if not TranslationServer.has_translation_for_locale(locale_data.locale, true):
		TranslationServer.add_translation(create_translation(locale_data))
	TranslationServer.set_locale(locale_data.locale)
	Setting.set_string(LOCALE_SETTING_KEY, locale_data.locale)
	Setting.save()
	gdf.events.locale_changed.emit()
	pass


static func remove_old_locale_translation() -> void:
	var old_locale := Setting.get_string(LOCALE_SETTING_KEY)
	if old_locale.is_empty():
		return
	var standardized_locale := TranslationServer.standardize_locale(old_locale)
	for translation: Translation in TranslationServer.get_translations():
		if TranslationServer.standardize_locale(translation.locale) == standardized_locale:
			TranslationServer.remove_translation(translation)
	pass


static func create_translation(locale_data: LocaleData) -> Translation:
	var translation := Translation.new()
	translation.locale = locale_data.locale
	for key in locale_data.data:
		translation.add_message(key, locale_data.data[key])
	return translation


# ----------------------------------------------------------------------------------------------------------------------
# System locale detection
# ----------------------------------------------------------------------------------------------------------------------

## Maps a raw locale string to a language code; Chinese uses Hans/Hant by script or country.
static func resolve_locale(raw_locale: String) -> String:
	var locale := raw_locale.strip_edges()
	if locale.is_empty():
		return EN
	var at := locale.find("@")
	if at >= 0:
		locale = locale.substr(0, at)
	var standardized := TranslationServer.standardize_locale(locale)
	if standardized.is_empty():
		return EN
	var parts := standardized.split("_")
	var language := parts[0].to_lower()
	if language.is_empty():
		return EN
	var script := ""
	var country := ""
	for i in range(1, parts.size()):
		var part: String = parts[i]
		if part.length() == 4 and part[0] == part[0].to_upper() and part.substr(1) == part.substr(1).to_lower():
			script = part
		elif part == part.to_upper() and (part.length() == 2 or part.length() == 3):
			country = part
	if language != ZH:
		return language
	if script == "Hant" or country == "TW" or country == "HK" or country == "MO":
		return ZH_HANT
	if script == "Hans" or country == "CN" or country == "SG":
		return ZH_HANS
	return ZH
