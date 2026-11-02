class_name GitIgnore
extends Object

## What the agent ignores: the built-in rule blocks, [constant WORKSPACE_IGNORE_FILES], and the data folder.
## [member ignore_rules] is the single list — [method GitCheckpointManager.ensure_exclude_file] writes it
## into shadow repositories, and workspace search (glob / grep) uses it as skip rules.

# ---------------------------------------------------------------------------
# Ignore rules
# ---------------------------------------------------------------------------

const COMMON_EXCLUDE_RULES := """
# OS metadata
.DS_Store
.AppleDouble
.LSOverride
._*
.Spotlight-V100/
.Trashes/
Thumbs.db
Thumbs.db:encryptable
ehthumbs.db
Desktop.ini
$RECYCLE.BIN/

# Editors and IDEs
.idea/
.vscode/
.vs/
.fleet/
*.code-workspace
*.suo
*.user
*.userosscache
*.sln.docstates
*.swp
*.swo
*~

# Logs, crash dumps, and temporary files
*.log
*.log.*
*.pid
*.pid.lock
*.stackdump
*.dmp
*.tmp
*.temp
tmp*
temp*
*.bak
*.orig
*.rej

# Local environment and secrets
.env
.env.*
!.env.example
!.env.sample

# General caches and test output
.cache/
.coverage
.coverage.*
coverage/
htmlcov/
.nyc_output/
.pytest_cache/
.mypy_cache/
.ruff_cache/
.tox/

# Python
__pycache__/
*.py[cod]
*.pyd
*.egg-info/
.venv/
venv/

# JavaScript and TypeScript
node_modules/
.npm/
.yarn/cache/
.yarn/unplugged/
.pnpm-store/
*.tsbuildinfo
npm-debug.log*
yarn-debug.log*
yarn-error.log*
pnpm-debug.log*

# Frontend build caches
.next/
.nuxt/
.svelte-kit/
.angular/
.parcel-cache/
.turbo/

# Java, Kotlin, and Gradle
.gradle/
*.class

# Rust
target/

# C and C++ build metadata
CMakeFiles/
CMakeCache.txt
cmake_install.cmake
compile_commands.json

# Infrastructure tools
.terraform/
*.tfstate
*.tfstate.*
"""

const LARGE_FILE_EXCLUDE_RULES := """
# Archives
*.7z
*.rar
*.tar
*.tar.gz
*.tgz
*.zip

# Disk images and virtual machines
*.dmg
*.iso
*.vdi
*.vhd
*.vhdx
*.vmdk

# AI models and checkpoints
*.bin
*.ckpt
*.gguf
*.onnx
*.pt
*.pth
*.safetensors

# Database files and dumps
*.db
*.db-shm
*.db-wal
*.dump
*.sqlite
*.sqlite3
"""

const MANDATORY_EXCLUDE_RULES := """
.git/
.godot/
.dependency/
"""

## Workspace ignore files whose lines join the built-in blocks above.
const WORKSPACE_IGNORE_FILES: Array[String] = [".gitignore", ".cursorignore", ".agentignore", ".aiignore"]

## Every ignore rule, in apply order. Rebuilt from the current workspace root by
## [method refresh_ignore_rules] on startup and on every workspace switch.
static var ignore_rules: Array[String] = []


static func _static_init() -> void:
	# Rules follow the workspace root, so rebuild them whenever it is switched.
	AgentEvents.events.workspace_changed.connect(func(_path: String) -> void: refresh_ignore_rules())
	refresh_ignore_rules()
	pass


## Rebuilds [member ignore_rules] from the built-in blocks and the current workspace root.
static func refresh_ignore_rules() -> void:
	var rules: Array[String] = []
	append_rule_lines(rules, COMMON_EXCLUDE_RULES)
	append_rule_lines(rules, LARGE_FILE_EXCLUDE_RULES)
	append_rule_lines(rules, MANDATORY_EXCLUDE_RULES)
	for file_name in WORKSPACE_IGNORE_FILES:
		append_rule_lines(rules, FileUtils.read_file_to_string(AgentWorkspace.resolve_path(file_name)))
	append_rule_lines(rules, AgentWorkspace.data_dir + "/")
	ignore_rules = rules
	pass


## Appends the trimmed, non-empty, not-yet-present lines of one rule block or ignore file.
static func append_rule_lines(rules: Array[String], text: String) -> void:
	for line in text.split(FileUtils.NEWLINE_LF):
		var rule := line.strip_edges()
		if not rule.is_empty() and not rules.has(rule):
			rules.append(rule)
	pass

