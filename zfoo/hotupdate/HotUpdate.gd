class_name HotUpdate
extends Object

## Godot PCK Hot Update for single pck
## Workflow: Launch App → Check Version → Download PCK → Verify MD5 → Load PCK → Enter Game

# --------------------------------------------------------------------------------------------------
const SETTING_HOT_UPDATE_VERSION_KEY: String = "hot_update_version"
const PCK_PATH: String = "user://patch.pck"

# --------------------------------------------------------------------------------------------------
enum State { IDLE, CHECKING, DOWNLOADING, APPLYING, COMPLETED, ERROR, FORCE_UPDATE_APK }

signal state_checking
signal state_downloading
signal state_applying
signal state_completed
signal state_error
signal state_force_update_apk

var version_url: String = StringUtils.EMPTY
var app_version: String = StringUtils.EMPTY

var state: State = State.IDLE

var remote_hot_update_manifest: HotUpdateManifest = null

var message: String = ""

var http_download: HTTPRequest = null

# --------------------------------------------------------------------------------------------------
func _init(_version_url: String, _app_version: String):
	version_url = _version_url
	app_version = _app_version
	Log.info("HotUpdate init, version_url:[{}] app_version:[{}] current_version:[{}]", version_url, app_version, current_version())
	pass

func current_version() -> String:
	var hot_update_version := Setting.get_string(SETTING_HOT_UPDATE_VERSION_KEY)
	if StringUtils.is_empty(hot_update_version):
		return app_version
	return hot_update_version if compare_version(hot_update_version, app_version) >= 0 else app_version

# --------------------------------------------------------------------------------------------------
func checking() -> void:
	state = State.CHECKING
	message = "Checking remote version manifest for updates..."
	state_checking.emit()
	Log.info("Checking remote version manifest url:[{}]", version_url)
	var response := await HttpHelper.async_get(version_url)
	Log.info("Remote version manifest response:[{}]}", response.get_body_string())
	if !response.is_ok():
		_fail("Request remote version manifest fail, please check your network connection and try again.")
		return
	remote_hot_update_manifest = JsonUtils.json_to_object(response.get_body_string(), HotUpdateManifest)
	
	if !is_same_major_version(current_version(), remote_hot_update_manifest.version):
		state = State.FORCE_UPDATE_APK
		state_force_update_apk.emit()
		return
	
	var has_update := compare_version(current_version(), remote_hot_update_manifest.version) >= 0
	if has_update:
		applying()
		return

	downloading()
	pass

# --------------------------------------------------------------------------------------------------
func downloading() -> void:
	state = State.DOWNLOADING
	state_downloading.emit()
	
	Log.info("current_version:[{}], remote_version:[{}]", current_version(), remote_hot_update_manifest.version)
	var size_bytes: int = remote_hot_update_manifest.size
	var size_mb := snappedf(float(size_bytes) / FileUtils.BYTES_PER_MB, 0.01)
	message = StringUtils.format("remote version:[{}] Update available ({}MB), downloading...", remote_hot_update_manifest.version, size_mb)
	
	var pck_url: String = remote_hot_update_manifest.pck_url
	FileUtils.delete_file_or_directory(PCK_PATH)

	if http_download == null:
		http_download = HTTPRequest.new()
		http_download.name = "HotUpdateDownload"
		http_download.download_file = PCK_PATH
		http_download.download_chunk_size = 65536
		http_download.request_completed.connect(on_download_completed)
		http_download.process_thread_group = Node.PROCESS_THREAD_GROUP_SUB_THREAD
		gdf.gdf_node.add_child(http_download)

	var error := http_download.request(pck_url)
	if error != OK:
		_fail(StringUtils.format("Download request error: [{}]", error))
		return

func get_download_progress() -> float:
	var total := http_download.get_body_size()
	if total <= 0:
		return 0.0
	return float(http_download.get_downloaded_bytes()) / float(total)

func on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS || code != 200:
		_fail(StringUtils.format("Download failed, result: {}, code: {}", result, code))
		FileUtils.delete_file_or_directory(PCK_PATH)
		return
	# check MD5
	var expected_md5: String = remote_hot_update_manifest.md5
	if StringUtils.is_not_empty(expected_md5):
		var actual_md5 := FileAccess.get_md5(PCK_PATH)
		if actual_md5 != expected_md5:
			_fail(StringUtils.format("MD5 mismatch, expected: [{}], actual: [{}]", expected_md5, actual_md5))
			FileUtils.delete_file_or_directory(PCK_PATH)
			return
	Setting.set_string(SETTING_HOT_UPDATE_VERSION_KEY, remote_hot_update_manifest.version)
	Setting.save()
	Log.info("Download completed")
	applying()
	pass

# --------------------------------------------------------------------------------------------------
# apply pck
func applying() -> void:
	state = State.APPLYING
	message = "Applying patch..."
	state_applying.emit()
	if !FileAccess.file_exists(PCK_PATH):
		completed()
		return
	
	# Overwrite installation may leave old hot-update patches.
	# Skip loading the patch if the app version is greater than the patch version.
	var hot_update_version := Setting.get_string(SETTING_HOT_UPDATE_VERSION_KEY)
	if StringUtils.is_empty(hot_update_version) || compare_version(app_version, hot_update_version) >= 0:
		completed()
		return
	
	var success := ProjectSettings.load_resource_pack(PCK_PATH, true)
	if !success:
		_fail("Failed to load patch.pck")
		FileUtils.delete_file_or_directory(PCK_PATH)
		Setting.set_string(SETTING_HOT_UPDATE_VERSION_KEY, app_version)
		Setting.save()
		return
	Log.info("Loaded patch.pck")
	completed()
	pass

# --------------------------------------------------------------------------------------------------
func completed() -> void:
	state = State.COMPLETED
	message = "Completed to update. Ready to play!"
	state_completed.emit()
	destroy()
	pass

# --------------------------------------------------------------------------------------------------
func destroy() -> void:
	if http_download != null:
		http_download.queue_free()
		http_download = null
	pass

func _fail(err: String) -> void:
	state = State.ERROR
	message = err
	Log.error("{}", err)
	state_error.emit()
	pass

# --------------------------------------------------------------------------------------------------
static func compare_version(v1: String, v2: String) -> int:
	var p1 := v1.split(".")
	var p2 := v2.split(".")
	for i in range(max(p1.size(), p2.size())):
		var n1 := int(p1[i]) if i < p1.size() else 0
		var n2 := int(p2[i]) if i < p2.size() else 0
		if n1 != n2:
			return n1 - n2
	return 0

static func is_same_major_version(v1: String, v2: String) -> bool:
	var p1 := v1.split(".")
	var p2 := v2.split(".")
	var n1 := int(p1[0]) if p1.size() > 0 else 0
	var n2 := int(p2[0]) if p2.size() > 0 else 0
	return n1 == n2
