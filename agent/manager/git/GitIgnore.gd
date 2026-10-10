class_name GitIgnore
extends Object

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
.gai/
.godot/
.dependency/
"""


static func write_exclude_rules(git_dir: String) -> bool:
	var project_rules := FileUtils.read_file_to_string(AgentWorkspace.get_root().path_join(".gitignore"))
	var exclude_rules := project_rules
	if not exclude_rules.is_empty() and not exclude_rules.ends_with(FileUtils.NEWLINE_LF):
		exclude_rules += FileUtils.NEWLINE_LF
	exclude_rules += COMMON_EXCLUDE_RULES
	exclude_rules += LARGE_FILE_EXCLUDE_RULES
	## `.git` is the user's real repository — snapshots must never swallow it.
	## Mandatory rules come last so project negation rules cannot re-include these directories.
	exclude_rules += MANDATORY_EXCLUDE_RULES
	var git_exclude_path := git_dir.path_join("info/exclude")
	if FileUtils.write_string_to_file(git_exclude_path, exclude_rules):
		return true
	Log.error("agent checkpoint exclude write failed:[{}]", git_exclude_path)
	return false
