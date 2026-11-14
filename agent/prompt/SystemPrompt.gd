class_name SystemPrompt
extends RefCounted

## Minimal coding-agent system prompt (Pi-style, under ~500 tokens).
## A workspace-root [constant SYSTEM_PATH] replaces the generated prompt entirely when present.
## [method reload_system_context] re-reads the file, so a new session picks up an edited
## SYSTEM.md without restarting the app.


# ---------------------------------------------------------------------------
# Prompt selection
# ---------------------------------------------------------------------------

static func build() -> String:
	if has_system_context():
		return get_system_context()
	return build_generated_prompt()


# ---------------------------------------------------------------------------
# SYSTEM.md override
# ---------------------------------------------------------------------------

## Workspace-root file that overrides the generated prompt.
const SYSTEM_PATH := "SYSTEM.md"

static var system_context: String = ""


static func _static_init() -> void:
	reload_system_context()
	pass


static func reload_system_context() -> String:
	system_context = ""
	var path := AgentWorkspace.resolve_path(SYSTEM_PATH)
	if FileAccess.file_exists(path):
		system_context = FileUtils.read_file_to_string(path)
	return system_context


static func get_system_context() -> String:
	return system_context

static func has_system_context() -> bool:
	return StringUtils.is_not_blank(system_context)


# ---------------------------------------------------------------------------
# Generated prompt
# ---------------------------------------------------------------------------

static func build_generated_prompt() -> String:
	return StringUtils.format(
		"""You are a coding agent in a Godot project workspace.

Project root: {}

{}

{}

{}""",
		AgentWorkspace.get_root(),
		build_godot_context(),
		build_dependency_context(),
		build_os_context()
	)


static func build_godot_context() -> String:
	var build := StringBuilder.new()
	build.append(StringUtils.format("Godot version: {}", OSUtils.godot_version()))
	var executable_path := OS.get_executable_path()
	if StringUtils.is_not_blank(executable_path):
		build.append(StringUtils.format("Godot executable: {}", executable_path))
	return build.build_joined(FileUtils.NEWLINE_LF)


## Script runtimes a coding task calls directly. Everything else in `.dependency/` belongs to a
## single skill, which resolves its own path from `.dependency/manifest.json`.
const CORE_DEPENDENCIES: Array[String] = ["python", "node"]


## Installed core dependencies, one per line. Paths are relative to the project root.
static func build_dependency_context() -> String:
	var build := StringBuilder.new()
	build.append("Dependencies:")
	for runtime: String in CORE_DEPENDENCIES:
		var entry: DependencyManifest.DependencyManifestEntry = DependencyManifest.entries.get(runtime)
		var path := entry.bin if entry != null and entry.populated else StringUtils.EMPTY
		if StringUtils.is_blank(path) and runtime == "python":
			path = DependencyManifest.PYTHON_PATH
		if StringUtils.is_not_blank(path):
			build.append(StringUtils.format("- {}: {}", runtime, path))
	return build.build_joined(FileUtils.NEWLINE_LF)


static func build_os_context() -> String:
	var build := StringBuilder.new()
	build.append(build_operating_system_context())
	build.append(build_cpu_context())
	build.append(build_memory_context())
	build.append(build_gpu_context())
	build.append(build_locale_context())
	build.append(build_shell_context())
	return build.build_joined(FileUtils.NEWLINE_LF)


## Builds one concise line with the operating system. The distribution is only added when it says
## something beyond the OS name — Windows reports "Windows" as its distribution, which is noise.
static func build_operating_system_context() -> String:
	var os_name := OS.get_name()
	var os_version := OS.get_version()
	var distro := OS.get_distribution_name()
	var has_distro := StringUtils.is_not_blank(distro) and distro.to_lower() != os_name.to_lower()
	if has_distro:
		return StringUtils.format("OS: {} {}, distribution: {}", os_name, os_version, distro)
	return StringUtils.format("OS: {} {}", os_name, os_version)


## Builds one concise line containing the system locale and the UTC offset. The raw zone name is
## skipped because the OS returns it in the system language ("中国标准时间"), which mixes scripts
## inside an otherwise English prompt and is harder for the model to reason about than an offset.
static func build_locale_context() -> String:
	return StringUtils.format("Locale: {} · {}", OS.get_locale(), build_utc_offset_context())


## Formats the system UTC offset as UTC+08:00. Godot reports the offset in whole minutes east of UTC.
static func build_utc_offset_context() -> String:
	var offset := int(Time.get_time_zone_from_system().get("bias", 0))
	var absolute := absi(offset)
	return "UTC%s%02d:%02d" % ["+" if offset >= 0 else "-", absolute / 60, absolute % 60]


## Builds one line naming the shell used by command-line tools.
static func build_shell_context() -> String:
	if OSUtils.is_windows():
		return "Shell: Git Bash"
	return "Shell: /bin/bash"


## Builds one concise line containing CPU core count and architecture.
static func build_cpu_context() -> String:
	var arch := ""
	if OS.has_feature("arm64"):
		arch = "arm64"
	elif OS.has_feature("x86_64") or OS.has_feature("x64"):
		arch = "x86_64"
	elif OS.has_feature("x86_32") or OS.has_feature("x86"):
		arch = "x86"
	elif OS.has_feature("arm32"):
		arch = "arm32"
	if StringUtils.is_not_blank(arch):
		return StringUtils.format("CPU: {} cores, architecture: {}", OS.get_processor_count(), arch)
	return StringUtils.format("CPU: {} cores", OS.get_processor_count())


## Builds one line containing total physical memory reported by the operating system.
static func build_memory_context() -> String:
	var memory_info := OS.get_memory_info()
	var physical := int(memory_info.get("physical", 0))
	if physical > 0:
		return StringUtils.format("Memory: {}", String.humanize_size(physical))
	return "Memory: unknown"


## Builds one line containing the active GPU name and total VRAM on supported desktop platforms.
static func build_gpu_context() -> String:
	var gpu_name := RenderingServer.get_video_adapter_name()
	if StringUtils.is_blank(gpu_name):
		return "GPU: unknown"
	var video_memory_total := 0
	if OSUtils.is_windows():
		# The registry exposes the full 64-bit VRAM size; Win32_VideoController may truncate it to 4 GiB.
		var command := r"$values = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Video\*\0000' -Name 'HardwareInformation.qwMemorySize' -ErrorAction SilentlyContinue | ForEach-Object { $_.'HardwareInformation.qwMemorySize' }; ($values | Measure-Object -Maximum).Maximum"
		var result := OSUtils.execute(PackedStringArray(["powershell.exe", "-NoProfile", "-Command", command]), false)
		if result.exit_code == 0:
			video_memory_total = int(result.output.build_string().strip_edges())
	elif OS.get_name() == "Linux":
		# Dedicated GPUs expose their total VRAM through DRM sysfs.
		var result := OSUtils.execute(PackedStringArray(["/bin/sh", "-c", "cat /sys/class/drm/card*/device/mem_info_vram_total 2>/dev/null | sort -nr | head -n 1"]), false)
		if result.exit_code == 0:
			video_memory_total = int(result.output.build_string().strip_edges())
	if video_memory_total > 0:
		return StringUtils.format("GPU: {}, VRAM: {}", gpu_name, String.humanize_size(video_memory_total))
	return StringUtils.format("GPU: {}", gpu_name)
