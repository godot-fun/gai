class_name StringUtils
extends Object

const EMPTY: String = ""
const EMPTY_JSON: String = "{}"

const SPACE: String = " "
const SPACE_REGEX: String = "\\s+"

const TAB: String = "    "
const TAB_ASCII: String = "\t"

const COMMA: String = "," # [com·ma || 'kɒmə] n. comma
const COMMA_REGEX: String = ",|，"
const COMMON_SPLIT_REGEX: String = "[,，\\s]+"

const PERIOD: String = "." # period
const PERIOD_REGEX: String = "\\."

const LEFT_SQUARE_BRACKET: String = "[" # left square bracket
const RIGHT_SQUARE_BRACKET: String = "]" # right square bracket

const COLON: String = ":" # colon [co·lon || 'kəʊlən]
const COLON_REGEX: String = ":|："

const SEMICOLON: String = ";" # semicolon ['semi'kәulәn]
const SEMICOLON_REGEX: String = ";|；"

const QUOTATION_MARK: String = "\"" # quotation mark [quo·ta·tion || kwəʊ'teɪʃn]
const ELLIPSIS: String = "..." # ellipsis
const EXCLAMATION_POINT: String = "!" # exclamation point
const DASH: String = "-" # dash
const QUESTION_MARK: String = "?" # question mark
const HYPHEN: String = "-" # hyphen, the difference from DASH is that hyphen has no spaces on either side
const SLASH: String = "/" # slash
const EQUAL: String = "=" # equal sign
const BACK_SLASH: String = "\\" # back slash

const VERTICAL_BAR: String = "|" # vertical bar
const VERTICAL_BAR_REGEX: String = "\\|"

const SHARP: String = "#"
const SHARP_REGEX: String = "\\#"

const DOLLAR: String = "$" # dollar sign

## Terminal punctuation used to detect a complete sentence (ASCII + CJK).
const SENTENCE_ENDINGS: String = ".!?。！？"
## Closing quotes / brackets stripped before checking [member SENTENCE_ENDINGS].
const CLOSING_QUOTES: String = "\"'”’」』）)]}"

## Example: is_empty("") -> true; is_empty("a") -> false
static func is_empty(s: String) -> bool:
	return s == null or s.length() == 0

## Example: is_not_empty("a") -> true; is_not_empty("") -> false
static func is_not_empty(s: String) -> bool:
	return !is_empty(s)

## Example: is_blank("   ") -> true; is_blank("a") -> false
static func is_blank(s: String) -> bool:
	if is_empty(s):
		return true
	
	if is_empty(s.strip_edges(true, true)):
		return true
		
	return false

## Example: is_not_blank("a") -> true; is_not_blank("  ") -> false
static func is_not_blank(s: String) -> bool:
	return !is_blank(s)

## True when s ends with sentence punctuation, ignoring trailing closing quotes/brackets.
## Example: is_sentence_end("done。") -> true; is_sentence_end("完成。”") -> true; is_sentence_end("继续") -> false
static func is_sentence_end(s: String) -> bool:
	var trimmed := trim(s)
	if is_empty(trimmed):
		return false
	while not is_empty(trimmed) and CLOSING_QUOTES.contains(trimmed.right(1)):
		trimmed = trim(trimmed.left(-1))
	return not is_empty(trimmed) and SENTENCE_ENDINGS.contains(trimmed.right(1))

## Removes whitespace from both ends of s; preserves whitespace inside the string.
## Example: trim("  hello world  ") -> "hello world"
static func trim(s: String) -> String:
	if is_empty(s):
		return EMPTY
	return s.strip_edges(true, true)

## Returns template with args filled into format placeholders; returns template unchanged when empty or args are empty.
## Example: format("score:[{}] name:[{}]", 10, "bob") -> "score:[10] name:[bob]"
static func format(template: String, ...args: Array) -> String:
	if is_empty(template):
		return template
	if (ArrayUtils.is_empty(args)):
		return template
	return template.format(args, EMPTY_JSON)

## Returns the substring before the first delimiter; returns EMPTY if s is empty or delimiter is not found.
## Example: substring_before("a/b/c.txt", "/") -> "a"; substring_before("a/b", "#") -> ""
static func substring_before(s: String, delimiter: String) -> String:
	if is_empty(s):
		return EMPTY
	var index := s.find(delimiter)
	if index == -1:
		return EMPTY
	return s.substr(0, index)

## Returns the substring after the first delimiter; returns EMPTY if s is empty or delimiter is not found.
## Example: substring_after("a/b/c.txt", "/") -> "b/c.txt"; substring_after("a/b", "#") -> ""
static func substring_after(s: String, delimiter: String) -> String:
	if is_empty(s):
		return EMPTY
	var index := s.find(delimiter)
	if index == -1:
		return EMPTY
	return s.substr(index + delimiter.length(), s.length())

## Returns the substring before the last delimiter; returns EMPTY if s is empty or delimiter is not found.
## Example: substring_before_last("a/b/c.txt", "/") -> "a/b"; substring_before_last("a/b/c.txt", ".") -> "a/b/c"
static func substring_before_last(s: String, delimiter: String) -> String:
	if is_empty(s):
		return EMPTY
	var index := s.rfind(delimiter)
	if index == -1:
		return EMPTY
	return s.substr(0, index)

## Returns the substring after the last delimiter; returns EMPTY if s is empty or delimiter is not found.
## Example: substring_after_last("a/b/c.txt", "/") -> "c.txt"; substring_after_last("a/b/c.txt", ".") -> "txt"
static func substring_after_last(s: String, delimiter: String) -> String:
	if is_empty(s):
		return EMPTY
	var index := s.rfind(delimiter)
	if index == -1:
		return EMPTY
	return s.substr(index + delimiter.length(), s.length())

## Returns s truncated to max_length, appending suffix when longer. Total length never exceeds max_length; returns s when empty or already short enough.
## Example: truncate("abcdef", 5) -> "ab..."; truncate("abcdef", 6) -> "abcdef"
static func truncate(s: String, max_length: int, suffix: String = ELLIPSIS) -> String:
	if is_empty(s) or s.length() <= max_length:
		return s
	if max_length < suffix.length():
		return s.substr(0, max_length)
	return s.substr(0, max_length - suffix.length()) + suffix


## Returns s truncated to max_length keeping the end; prepends prefix when longer. Total length never exceeds max_length.
## Example: truncate_last("abcdef", 5) -> "...ef"; truncate_last("abcdef", 6) -> "abcdef"
static func truncate_last(s: String, max_length: int, prefix: String = ELLIPSIS) -> String:
	if is_empty(s) or s.length() <= max_length:
		return s
	if max_length <= prefix.length():
		return s.substr(s.length() - max_length, max_length)
	return prefix + s.substr(s.length() - (max_length - prefix.length()), max_length - prefix.length())


## Returns the first max_lines lines of s; later lines are dropped with no ellipsis.
## Example: first_lines("a\nb\nc", 2) -> "a\nb"; first_lines("a\nb", 3) -> "a\nb"
static func first_lines(s: String, max_lines: int) -> String:
	if max_lines <= 0:
		return EMPTY
	if is_empty(s):
		return s
	if s.count(FileUtils.NEWLINE_LF) < max_lines:
		return s
	var pos := 0
	for _n in max_lines:
		var idx := s.find(FileUtils.NEWLINE_LF, pos)
		if idx == -1:
			return s
		pos = idx + 1
	return s.substr(0, pos - 1)


## Returns the text after the first max_lines lines; returns EMPTY when s has at most max_lines lines.
## Example: first_lines_after("a\nb\nc", 2) -> "c"; first_lines_after("a\nb", 3) -> ""
static func first_lines_after(s: String, max_lines: int) -> String:
	if max_lines <= 0:
		return s
	if is_empty(s):
		return s
	if s.count(FileUtils.NEWLINE_LF) < max_lines:
		return EMPTY
	var pos := 0
	for _n in max_lines:
		var idx := s.find(FileUtils.NEWLINE_LF, pos)
		if idx == -1:
			return EMPTY
		pos = idx + 1
	return s.substr(pos)


## Returns the last max_lines lines of s; earlier lines are dropped with no ellipsis.
## Example: last_lines("a\nb\nc", 2) -> "b\nc"; last_lines("a\nb", 3) -> "a\nb"
static func last_lines(s: String, max_lines: int) -> String:
	if max_lines <= 0:
		return EMPTY
	if is_empty(s):
		return s
	if s.count(FileUtils.NEWLINE_LF) < max_lines:
		return s
	var idx := s.length()
	for _n in max_lines:
		idx = s.rfind(FileUtils.NEWLINE_LF, idx - 1)
		if idx < 0:
			return s
	return s.substr(idx + 1)


## Returns the enum key name for value; returns "UNKNOWN" if value is not in enum_obj.
## Example: enum_to_string(State, State.IDLE) -> "IDLE"; enum_to_string(State, 99) -> "UNKNOWN"
static func enum_to_string(enum_obj: Dictionary, value: int) -> String:
	for key in enum_obj.keys():
		if enum_obj[key] == value:
			return key
	return "UNKNOWN"

# ----------------------------------------------------------------------------------------------------------------------
const ANIMAL_EMOJIS: PackedStringArray = [
	"🐶","🐱","🐭","🐹","🐰","🦊","🐻","🐼","🐻‍","🐨","🐯","🦁","🐮","🐷","🐽","🐸","🐵","🙈","🙉","🙊",
	"🐒","🐔","🐧","🐦","🐤","🐣","🐥","🦆","🦅","🦉","🦇","🐺","🐗","🐴","🦄","🐝","🐛","🦋","🐌","🐞",
	"🕷️","🦂","🦟","🦀","🦞","🦐","🦑","🐙","🐡","🐠","🐟","🐬","🐳","🐋","🦈","🐊","🐅","🐆","🦓","🦍",
	"🦧","🐘","🦛","🦏","🐪","🐫","🦒","🦘","🐃","🐂","🐄","🐎","🐖","🐏","🐑","🦙","🐐","🦌","🐕","🐩",
	"🦮","🐕‍🦺","🐈","🐓","🦃","🦚","🦜","🦢","🦩","🕊️","🐇","🦝","🦨","🦡","🦦","🦥","🐁","🐀","🐿️","🦔",
	"🐉","🐲"]

## Returns a random emoji string (Unicode range or animal emoji fallback).
## Example: random_emoji() -> "🐶" (any emoji)
static func random_emoji() -> String:
	# emoji Unicode range
	var ranges := [
		[0x1F600, 0x1F64F], # emoj
		[0x1F300, 0x1F5FF], # other
		[0x1F680, 0x1F6FF], # traffic
		[0x1F900, 0x1F9FF], # emoj
	]

	var r = ranges.pick_random()

	var codepoint := randi_range(r[0], r[1])

	var emoji := char(codepoint)

	if StringUtils.is_blank(emoji):
		return emoji
	
	return RandomUtils.random_ele(ANIMAL_EMOJIS)
