class_name GitDiffBundle
extends RefCounted

## Versioned JSON cache for one agent-run diff.

var version: int = 0
var patch: String = ""
var files: Array[GitDiffFile] = []
