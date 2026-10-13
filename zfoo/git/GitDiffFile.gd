class_name GitDiffFile
extends RefCounted

## One cached file comparison. Text snapshots make the right pane a real editor instead of an
## editable rendering of a partial unified patch.

const STATUS_ADDED := "added"
const STATUS_DELETED := "deleted"
const STATUS_MODIFIED := "modified"

var old_path: String = ""
var new_path: String = ""
var old_text: String = ""
var new_text: String = ""
var new_hash: String = ""
var new_exists: bool = true
var status: String = STATUS_MODIFIED
var binary: bool = false
var complete: bool = true
var old_changed_lines: PackedInt32Array = PackedInt32Array()
var new_changed_lines: PackedInt32Array = PackedInt32Array()


static func from_dictionary(data: Dictionary) -> GitDiffFile:
	var file := GitDiffFile.new()
	file.old_path = str(data.get("old_path", ""))
	file.new_path = str(data.get("new_path", ""))
	file.old_text = str(data.get("old_text", ""))
	file.new_text = str(data.get("new_text", ""))
	file.new_hash = str(data.get("new_hash", file.new_text.sha256_text()))
	file.new_exists = bool(data.get("new_exists", true))
	file.status = str(data.get("status", STATUS_MODIFIED))
	file.binary = bool(data.get("binary", false))
	file.complete = bool(data.get("complete", true))
	for line: Variant in data.get("old_changed_lines", []):
		file.old_changed_lines.append(int(line))
	for line: Variant in data.get("new_changed_lines", []):
		file.new_changed_lines.append(int(line))
	return file


func to_dictionary() -> Dictionary:
	return {
		"old_path": old_path,
		"new_path": new_path,
		"old_text": old_text,
		"new_text": new_text,
		"new_hash": new_hash,
		"new_exists": new_exists,
		"status": status,
		"binary": binary,
		"complete": complete,
		"old_changed_lines": Array(old_changed_lines),
		"new_changed_lines": Array(new_changed_lines),
	}


func display_path() -> String:
	return new_path if not new_path.is_empty() else old_path


func can_edit() -> bool:
	return complete and not binary and status != STATUS_DELETED and not new_path.is_empty()
