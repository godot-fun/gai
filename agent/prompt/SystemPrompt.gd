class_name SystemPrompt
extends RefCounted

## Minimal coding-agent system prompt (Pi-style, under ~500 tokens).


static func build() -> String:
	return StringUtils.format(
		"""You are a coding agent in a Godot project workspace.

Project root: {}

{}

{}

{}

Rules:
- Inspect relevant files before modifying them.
- Keep changes minimal and focused.
- Briefly summarize completed changes.""",
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


static func build_dependency_context() -> String:
	var build := StringBuilder.new()
	build.append(StringUtils.format("Python path: {}", DependencyManifest.PYTHON_PATH))
	return build.build_joined(FileUtils.NEWLINE_LF)


static func build_os_context() -> String:
	var build := StringBuilder.new()
	build.append(build_operating_system_context())
	build.append(build_locale_context())
	build.append(build_cpu_context())
	build.append(build_memory_context())
	build.append(build_gpu_context())
	build.append(build_shell_context())
	return build.build_joined(FileUtils.NEWLINE_LF)


## Builds one concise line containing the operating system name, version, and distribution.
static func build_operating_system_context() -> String:
	var distro := OS.get_distribution_name()
	if StringUtils.is_not_blank(distro):
		return StringUtils.format("Operating system: {} {}, distribution: {}", OS.get_name(), OS.get_version(), distro)
	return StringUtils.format("Operating system: {} {}", OS.get_name(), OS.get_version())


## Builds one concise line containing the system locale and time zone.
static func build_locale_context() -> String:
	var time_zone := str(Time.get_time_zone_from_system().get("name", ""))
	if StringUtils.is_not_blank(time_zone):
		return StringUtils.format("Locale: {}, time zone: {}", OS.get_locale(), time_zone)
	return StringUtils.format("Locale: {}", OS.get_locale())


## Builds one line describing the Bash environment used by command-line tools.
static func build_shell_context() -> String:
	if OSUtils.is_windows():
		return "Bash tool runs via: Git Bash"
	return "Bash tool runs via: /bin/bash"


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
