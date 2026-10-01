# --------------------------------------------------------------------------------------------------
class Teacher:
	var name: String
	var age: int
	pass

static var teacher1 := Teacher.new()
static var teacher2 := Teacher.new()

static func test_before() -> void:
	teacher1.name = "Peter"
	teacher1.age = 50
	teacher2.name = "David"
	teacher2.age = 40
	pass

func simple_json_test() -> void:
	var json := "{\"name\": \"test\", \"age\": 10}"
	var obj = JsonUtils.json_to_object(json, Teacher)
	var json_text := JsonUtils.object_to_json(obj)
	assert(json == json_text)
	pass



# --------------------------------------------------------------------------------------------------
class Student:
	var name: String
	var age: int
	var subjects: Array[String]
	var teachers: Array[Teacher]
	var scores: Dictionary[String, int]
	var teacherMap: Dictionary[String, Teacher]
	var friendMap: Dictionary[int, String]
pass


## [method JsonUtils.parse_object_lenient] prefers strict JSON, then recovers string fields from near-JSON.
func parse_object_lenient_test() -> void:
	var keys := PackedStringArray(["correct", "optimize", "expand"])
	var ok := JsonUtils.parse_object_lenient('{"correct":"fixed","optimize":"polished","expand":"fuller"}', keys)
	assert(ok.correct == "fixed")
	assert(ok.optimize == "polished")
	assert(ok.expand == "fuller")
	var wrapped := JsonUtils.parse_object_lenient('Here: {"correct":"x","optimize":"y","expand":"z"} thanks', keys)
	assert(wrapped.correct == "x")
	assert(wrapped.optimize == "y")
	assert(wrapped.expand == "z")
	var escaped := JsonUtils.parse_object_lenient('{"correct":"say \\"hi\\"","optimize":"line\\n2","expand":"ok"}', keys)
	assert(escaped.correct == "say \"hi\"")
	assert(escaped.optimize == "line\n2")
	assert(escaped.expand == "ok")
	assert(JsonUtils.extract_string_field('{"name":"Ada"}', "name") == "Ada")
	assert(JsonUtils.extract_string_field('{"name":"Ada"}', "age") == "")
	pass


## Invalid / near-JSON must not use [method JSON.parse_string] (ERR_FAIL → [code]log_error[/code] fails UnitTest).
## Covers: no braces, trailing comma recovery, unrecoverable bodies, non-object root, empty keys.
func parse_object_lenient_invalid_json_test() -> void:
	var keys := PackedStringArray(["correct", "optimize", "expand"])
	assert(JsonUtils.parse_object_lenient("", keys).is_empty())
	assert(JsonUtils.parse_object_lenient("   ", keys).is_empty())
	assert(JsonUtils.parse_object_lenient("not json", keys).is_empty())
	assert(JsonUtils.parse_object_lenient("only open { brace", keys).is_empty())
	assert(JsonUtils.parse_object_lenient("} only close", keys).is_empty())
	# Godot JSON.parse accepts a single trailing comma — still a valid recovery path either way.
	var trailing := JsonUtils.parse_object_lenient('{"correct":"a","optimize":"b","expand":"c",}', keys)
	assert(trailing.correct == "a")
	assert(trailing.optimize == "b")
	assert(trailing.expand == "c")
	# Double trailing comma fails strict parse; field extraction recovers quoted strings (no ERR_FAIL).
	var junk := JsonUtils.parse_object_lenient('{"correct":"a","optimize":"b","expand":"c",,}', keys)
	assert(junk.correct == "a")
	assert(junk.optimize == "b")
	assert(junk.expand == "c")
	# Unterminated string / missing closing brace: no recoverable fields.
	assert(JsonUtils.parse_object_lenient('{"correct": "unterminated', keys).is_empty())
	assert(JsonUtils.parse_object_lenient('{"correct":"a"', keys).is_empty())
	# JSON array root has no `{`…`}` slice → empty.
	assert(JsonUtils.parse_object_lenient("[1, 2, 3]", keys).is_empty())
	# Strict parse success returns the full dict even when [param keys] are absent from it.
	var other := JsonUtils.parse_object_lenient('{"other":"x"}', keys)
	assert(other.get("other") == "x")
	assert(not other.has("correct"))
	assert(not other.has("optimize"))
	assert(not other.has("expand"))
	# Without keys, failed strict parse returns empty (no extraction pass). Use `,,` — Godot accepts a single trailing comma.
	assert(JsonUtils.parse_object_lenient('{"correct":"a",,}', PackedStringArray()).is_empty())
	# Non-string values are not extracted by the string-field fallback (strict parse must fail first).
	var numbers := JsonUtils.parse_object_lenient('{"correct":1,"optimize":2,"expand":3,,}', keys)
	assert(numbers.is_empty())
	pass


func json_escapes_control_characters_test() -> void:
	# Godot String cannot hold U+0000: char(0) logs "Unexpected NUL character" and becomes U+FFFD.
	# Valid char() range excludes 0x0000; test ESC + VT only, plus round-trip behavior.
	var content := "ansi" + char(0x1B) + "[0m" + "x" + char(0x0B) + "vt"
	var json := JsonUtils.object_to_json(content)
	assert(JSON.parse_string(json) == content)
	assert(json.contains("\\u001b"))
	assert(json.contains("\\u000b"))
	assert(not json.contains(char(0x1B)))
	assert(not json.contains(char(0x0B)))
	var wrapped := JsonUtils.object_to_json({"role": "tool", "content": content})
	var parsed: Dictionary = JSON.parse_string(wrapped)
	assert(parsed["role"] == "tool")
	assert(parsed["content"] == content)
	pass


func json_test() -> void:
	var student := Student.new()
	student.name = "Peter"
	student.age = 30
	student.subjects = ["math", "history"]
	student.teachers = [teacher1, teacher1]
	student.scores = {}
	student.scores["math"] = 100
	student.scores["history"] = 99
	student.teacherMap = {}
	student.teacherMap["Peter"] = teacher1
	student.teacherMap["David"] = teacher2
	student.friendMap[1] = "Jay"
	student.friendMap[99] = "Sun"
	student.friendMap[-999] = "zfoo"
	var json := JsonUtils.object_to_json(student)
	var obj: Student = JsonUtils.json_to_object(json, Student)
	var json_text := JsonUtils.object_to_json(obj)
	assert(json == json_text)
	pass