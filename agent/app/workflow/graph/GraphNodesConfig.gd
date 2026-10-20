class_name GraphNodesConfig
extends RefCounted

const GRAPH_NODES := "res://agent/app/workflow/graph/graph_nodes.json"

const SOURCE_DEFS := "sources"
const CONTROL_DEFS := "controls"
const SKILL_DEFS := "skills"

const PORT_OUTPUT := "out"

const SOURCE_CATEGORY := "source"
const SKILL_CATEGORY_AUDIO := "audio"
const SKILL_CATEGORY_IMAGE := "image"
const SKILL_CATEGORY_VIDEO := "video"

const CATEGORY_IDS := [
	SOURCE_CATEGORY,
	SKILL_CATEGORY_AUDIO,
	SKILL_CATEGORY_IMAGE,
	SKILL_CATEGORY_VIDEO,
]

const SOURCE_NODE_ORDER: Array[String] = [
	"input-audio",
	"input-image",
	"input-video",
	"input-text",
	"input-folder",
	"batch-for-each",
]

const SKILL_ORDER_AUDIO: Array[String] = [
	"audio-to-wav",
	"audio-trim",
	"audio-denoise",
	"audio-fade",
	"audio-loudness-normalization",
	"audio-volume-adjust",
	"audio-sample-rate-standardize",
	"audio-to-ogg",
]

const SKILL_ORDER_IMAGE: Array[String] = [
	"image-to-png",
	"image-remove-white-background",
	"image-remove-background",
	"image-trim",
	"image-resize",
]

const SKILL_ORDER_VIDEO: Array[String] = [
	"video-to-wav",
	"video-remove-audio",
	"video-to-60fps",
	"video-to-4k",
	"video-4k-normalization",
	"video-merge",
	"video-merge-gpu",
	"video-compress-to-size",
	"video-to-ogv",
]

const CONTROL_BATCH_FOR_EACH := "batch-for-each"
const CONTROL_PORT_FOLDER := "folder"
const CONTROL_PORT_ITEM := "item"
const CONTROL_FIELD_GLOB := "glob"
const CONTROL_FIELD_ITEM_TYPE := "item_type"

static var defs_by_id: Dictionary[String, GraphNodeDef] = {}
static var sources: Array[SourceDef] = []
static var controls: Array[ControlDef] = []
static var skills: Array[SkillDef] = []


static func _static_init() -> void:
	defs_by_id.clear()
	sources.clear()
	controls.clear()
	skills.clear()

	var text := FileAccess.get_file_as_string(GRAPH_NODES)
	if text.is_empty():
		Log.error("graph nodes config missing or empty:[{}]", GRAPH_NODES)
		return

	var catalog: GraphNodesDef = JsonUtils.json_to_object(text, GraphNodesDef)
	if catalog == null:
		Log.error("graph nodes config json parse failed:[{}]", GRAPH_NODES)
		return

	for def in catalog.sources:
		sources.append(def)
		defs_by_id[def.id] = def

	for def in catalog.controls:
		controls.append(def)
		defs_by_id[def.id] = def

	for def in catalog.skills:
		skills.append(def)
		defs_by_id[def.skill] = def


static func category_label(category_id: String) -> String:
	var key := "workflow.category." + category_id
	var translated := I18n.t(key)
	if translated != key:
		return translated
	return PortDef.type_label(category_id)


static func get_def(def_id: String) -> GraphNodeDef:
	return defs_by_id.get(def_id, null)

static func get_skill(skill_id: String) -> SkillDef:
	var def := get_def(skill_id)
	if def is SkillDef:
		return def as SkillDef
	return null


static func skill_order_for_category(category: String) -> Array[String]:
	match category:
		SKILL_CATEGORY_AUDIO:
			return SKILL_ORDER_AUDIO
		SKILL_CATEGORY_IMAGE:
			return SKILL_ORDER_IMAGE
		SKILL_CATEGORY_VIDEO:
			return SKILL_ORDER_VIDEO
		_:
			return []


static func catalog_sort_index(order: Array[String], catalog_id: String) -> int:
	var index := order.find(catalog_id)
	if index >= 0:
		return index
	return order.size()


static func sort_by_catalog_order(items: Array[GraphNodeDef], order: Array[String]) -> Array[GraphNodeDef]:
	var result := items.duplicate()
	result.sort_custom(
		func(a: GraphNodeDef, b: GraphNodeDef) -> bool:
			var ai := catalog_sort_index(order, a.catalog_id())
			var bi := catalog_sort_index(order, b.catalog_id())
			if ai != bi:
				return ai < bi
			return a.catalog_id() < b.catalog_id(),
	)
	return result


static func list_skills_in_category(category: String) -> Array[GraphNodeDef]:
	if category == SOURCE_CATEGORY:
		var result: Array[GraphNodeDef] = []
		for def in sources:
			result.append(def)
		for ctrl in controls:
			result.append(ctrl)
		return sort_by_catalog_order(result, SOURCE_NODE_ORDER)

	var result: Array[GraphNodeDef] = []
	for def in skills:
		if def.category == category:
			result.append(def)
	var order := skill_order_for_category(category)
	if order.is_empty():
		return result
	return sort_by_catalog_order(result, order)


static func create_node(def_id: String) -> SkillNode:
	## Most nodes need no dedicated GDScript class; `graph_nodes.json` drives the UI.
	## Add a subclass only for custom interaction or pipeline logic (e.g. BatchForEachNode).
	var def := get_def(def_id)
	if def is SourceDef:
		return InputSourceNode.new()
	if def is ControlDef:
		return BatchForEachNode.new()
	return PathInputSkillNode.new()
