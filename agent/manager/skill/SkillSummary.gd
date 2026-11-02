class_name SkillSummary
extends RefCounted

## One skill of `.agents/skills` as the index exposes it: the front-matter `name` and a trimmed
## single-line `description`. A summary, not the skill itself — no folder path, no `SKILL.md` body,
## no command line. Built by [SkillManager].

var name: String = ""
var description: String = ""


func _init(skill_name: String = "", skill_description: String = "") -> void:
	name = skill_name
	description = skill_description
	pass
