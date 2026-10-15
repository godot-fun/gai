class_name GitDiffFile
extends RefCounted

## One cached file comparison. Text snapshots make the right pane a real editor instead of an
## editable rendering of a partial unified patch.

const STATUS_ADDED := "added"
const STATUS_DELETED := "deleted"
const STATUS_MODIFIED := "modified"

var old_path: String = ""
var new_path: String = ""
## Full snapshots, not unified-patch hunks. The right snapshot can therefore be saved as a file.
var old_text: String = ""
var new_text: String = ""
## Hash/existence captured when the bundle was created and checked again immediately before Save.
var new_hash: String = ""
var new_exists: bool = true
var status: String = STATUS_MODIFIED
var binary: bool = false
## One-based real file line numbers parsed from the patch; CodeEdit APIs convert them to zero-based.
var changed_lines := GitDiffParser.ChangedLines.new()


func display_path() -> String:
	return new_path if not new_path.is_empty() else old_path


func can_edit() -> bool:
	# Deleted and binary files have no UTF-8 target that can be written safely.
	return not binary and status != STATUS_DELETED and not new_path.is_empty()
