class_name EditorFileIcon
extends RefCounted

## Resolves a workspace path to a Material icon in [code]res://agent/asset/image/file[/code].
## Names are matched in lowercase. [code].gd[/code] uses [code]godot.svg[/code], not a file named [code]gd.svg[/code].

const ICON_DIRECTORY := "res://agent/asset/image/file/"

const FILE_NAMES: Dictionary[String, String] = {
	"dockerfile": "docker",
	"makefile": "makefile",
	"gnumakefile": "makefile",
	"sconstruct": "scons",
	"sconscript": "scons",
	"cmakelists.txt": "cmake",
	".gitignore": "git",
	".gitattributes": "git",
	".gitmodules": "git",
	".gitconfig": "git",
	".editorconfig": "editorconfig",
	"go.mod": "go-mod",
	"go.sum": "go-mod",
	"package.json": "nodejs",
	"tsconfig.json": "tsconfig",
	"license": "license",
	"copying": "license",
	"readme": "readme",
	"changelog": "changelog",
	"authors": "authors",
	"contributors": "authors",
	"contributing": "contributing",
	"codeowners": "codeowners",
}

static var extensions: Dictionary[String, String] = {}
static var present: Dictionary[String, bool] = {}
static var textures: Dictionary = {}


static func _static_init() -> void:
	bind_extensions(["gd"], "godot")
	bind_extensions(["tscn", "tres", "godot", "gdextension", "gdshader", "gdshaderinc", "import"], "godot-assets")
	bind_extensions(["py", "pyw", "pyi"], "python")
	bind_extensions(["rb", "rake"], "ruby")
	bind_extensions(["pl"], "prolog")
	bind_extensions(["pm"], "perl")
	bind_extensions(["cs"], "csharp")
	bind_extensions(["cc", "cpp", "cxx"], "cpp")
	bind_extensions(["hh", "hpp", "hxx"], "hpp")
	bind_extensions(["m"], "objective-c")
	bind_extensions(["mm"], "objective-cpp")
	bind_extensions(["js", "mjs", "cjs"], "javascript")
	bind_extensions(["jsx"], "react")
	bind_extensions(["ts", "mts", "cts"], "typescript")
	bind_extensions(["tsx"], "react_ts")
	bind_extensions(["kt", "kts"], "kotlin")
	bind_extensions(["rs"], "rust")
	bind_extensions(["yml"], "yaml")
	bind_extensions(["jsonc", "json5"], "json")
	bind_extensions(["ini", "cfg", "conf", "properties"], "settings")
	bind_extensions(["env"], "tune")
	bind_extensions(["htm", "xhtml"], "html")
	bind_extensions(["md", "markdown", "mdown", "mkd"], "markdown")
	bind_extensions(["scss", "sass"], "sass")
	bind_extensions(["sh", "bash", "zsh", "fish", "bat", "cmd"], "console")
	bind_extensions(["ps1", "psm1"], "powershell")
	bind_extensions(["sql", "psql", "ddl", "dml"], "database")
	bind_extensions(["diff", "rej"], "diff")
	bind_extensions(["patch"], "git")
	bind_extensions(["tex", "cls", "sty"], "tex")
	bind_extensions(["bib"], "bibliography")
	bind_extensions(["glsl", "vert", "frag", "geom", "tesc", "tese", "comp", "hlsl", "fx", "wgsl"], "shader")
	bind_extensions(["bmp", "dds", "exr", "jpg", "jpeg", "gif", "ktx", "png", "tga", "webp", "ico", "tif", "tiff", "avif", "heic"], "image")
	bind_extensions(["wav", "mp3", "ogg", "flac", "aac", "m4a"], "audio")
	bind_extensions(["avi", "m4v", "mkv", "mov", "mp4", "mpeg", "mpg", "ogv", "webm"], "video")
	bind_extensions(["ttf", "otf", "woff", "woff2", "eot"], "font")
	bind_extensions(["gz", "tgz", "tar", "bz2", "xz", "7z", "rar"], "zip")
	bind_extensions(["txt"], "document")
	pass


static func bind_extensions(names: PackedStringArray, stem: String) -> void:
	for name in names:
		extensions[name] = stem
	pass


## Resource path of the SVG for [param file_path]. Directories use the folder icon.
static func icon_path(file_path: String, is_directory: bool) -> String:
	if is_directory:
		return icon_file("folder")
	var file_name := file_path.get_file().to_lower()
	var stem := str(FILE_NAMES.get(file_name, ""))
	if stem.is_empty():
		var extension := file_name.get_extension()
		stem = str(extensions.get(extension, ""))
		if stem.is_empty() and not extension.is_empty() and has_icon(extension):
			stem = extension
	if not has_icon(stem):
		stem = "file"
	return icon_file(stem)


static func texture(file_path: String, is_directory: bool) -> Texture2D:
	var path := icon_path(file_path, is_directory)
	if textures.has(path):
		return textures[path]
	var loaded := load(path) as Texture2D
	if loaded != null:
		textures[path] = loaded
	return loaded


static func icon_file(stem: String) -> String:
	return ICON_DIRECTORY + stem + ".svg"


static func has_icon(stem: String) -> bool:
	if stem.is_empty():
		return false
	if present.has(stem):
		return present[stem]
	var found := FileAccess.file_exists(icon_file(stem))
	present[stem] = found
	return found
