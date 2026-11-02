extends RefCounted

## Skill index only — front matter parsing, description trimming, and the shipped catalog.


static func parse_front_matter_plain_test() -> void:
	var text := "---\nname: audio-trim\ndescription: Trims silence.\n---\n\n# Audio Trim\n"
	var front_matter := SkillManager.parse_front_matter(text)
	assert(front_matter.get("name", "") == "audio-trim")
	assert(front_matter.get("description", "") == "Trims silence.")
	assert(not front_matter.has("# Audio Trim"))
	pass


static func parse_front_matter_block_scalar_test() -> void:
	var text := "---\nname: storyboard\ndescription: >-\n  Turns materials into a storyboard\n  with bilingual narration.\n---\n"
	var front_matter := SkillManager.parse_front_matter(text)
	assert(front_matter.get("name", "") == "storyboard")
	assert(front_matter.get("description", "") == "Turns materials into a storyboard with bilingual narration.")
	pass


static func parse_front_matter_without_header_test() -> void:
	assert(SkillManager.parse_front_matter("# Audio Trim\n\nBody.").is_empty())
	assert(SkillManager.parse_front_matter("").is_empty())
	pass


static func summarize_test() -> void:
	assert(SkillManager.summarize("Trims silence.") == "Trims silence.")
	assert(SkillManager.summarize("Short. Second sentence.") == "Short")
	var long_text := "Trims leading and trailing silence from audio files using FFmpeg and more words here"
	var summary := SkillManager.summarize(long_text)
	assert(summary.length() <= SkillManager.MAX_DESCRIPTION_LENGTH)
	assert(summary.ends_with("…"))
	assert(not summary.left(summary.length() - 1).ends_with(" "))
	pass


## Every shipped skill must survive parsing, otherwise the popup would silently lose summaries.
static func shipped_skills_load_test() -> void:
	var summaries := SkillManager.get_summaries()
	assert(summaries.size() > 0)
	for summary: SkillSummary in summaries:
		assert(StringUtils.is_not_blank(summary.name))
		assert(StringUtils.is_not_blank(summary.description))
	pass


static func summaries_are_sorted_by_name_test() -> void:
	var names: Array[String] = []
	for summary: SkillSummary in SkillManager.get_summaries():
		names.append(summary.name)
	var expected := names.duplicate()
	expected.sort()
	assert(names == expected)
	pass


# ---------------------------------------------------------------------------
# Disk fingerprint — the cache must notice skills added or edited while the app runs
# ---------------------------------------------------------------------------

const TEMP_SKILL_ROOT := "user://skill_manager_test/skills"


## Two skills on disk, isolated from the workspace so tests never touch `.agents/skills`.
static func prepare_temp_root() -> String:
	var root := ProjectSettings.globalize_path(TEMP_SKILL_ROOT)
	FileUtils.delete_file_or_directory(root)
	write_skill(root, "alpha", "First skill.")
	write_skill(root, "beta", "Second skill.")
	return root


static func write_skill(root: String, folder: String, description: String) -> void:
	var path := root.path_join(folder).path_join(SkillManager.SKILL_FILE)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	FileUtils.write_string_to_file(path, "---\nname: %s\ndescription: %s\n---\n" % [folder, description])
	pass


## Deleting the folder is enough: the next [method SkillManager.get_summaries] sees a workspace root that
## differs from the cached temporary one and rescans by itself.
static func cleanup_temp_root(root: String) -> void:
	FileUtils.delete_file_or_directory(root)
	pass


static func signature_changes_when_a_skill_is_added_or_removed_test() -> void:
	var root := prepare_temp_root()
	var baseline := SkillManager.build_signature(FileUtils.get_all_directories_in_folder(root))
	# Re-reading an unchanged folder must produce the same fingerprint, otherwise every keystroke reloads.
	assert(SkillManager.build_signature(FileUtils.get_all_directories_in_folder(root)) == baseline)
	write_skill(root, "gamma", "Third skill.")
	var grown := SkillManager.build_signature(FileUtils.get_all_directories_in_folder(root))
	assert(grown != baseline)
	assert(grown.contains("gamma:"))
	FileUtils.delete_file_or_directory(root.path_join("alpha"))
	assert(SkillManager.build_signature(FileUtils.get_all_directories_in_folder(root)) != grown)
	cleanup_temp_root(root)
	pass


static func signature_changes_when_skill_file_appears_test() -> void:
	var root := prepare_temp_root()
	DirAccess.make_dir_recursive_absolute(root.path_join("delta"))
	var before := SkillManager.build_signature(FileUtils.get_all_directories_in_folder(root))
	# A folder without SKILL.md has no mtime yet; writing it must invalidate the fingerprint.
	assert(before.contains("delta:0"))
	write_skill(root, "delta", "Late skill.")
	assert(SkillManager.build_signature(FileUtils.get_all_directories_in_folder(root)) != before)
	cleanup_temp_root(root)
	pass


static func index_rebuilds_when_the_disk_changed_test() -> void:
	var root := prepare_temp_root()
	assert(SkillManager.is_stale(root, FileUtils.get_all_directories_in_folder(root)))
	SkillManager.load_summaries(root)
	assert(SkillManager.summaries.size() == 2)
	assert(SkillManager.summaries[0].name == "alpha")
	assert(not SkillManager.is_stale(root, FileUtils.get_all_directories_in_folder(root)))
	write_skill(root, "gamma", "Third skill.")
	assert(SkillManager.is_stale(root, FileUtils.get_all_directories_in_folder(root)))
	SkillManager.load_summaries(root)
	assert(SkillManager.summaries.size() == 3)
	assert(SkillManager.summaries[2].name == "gamma")
	cleanup_temp_root(root)
	pass
