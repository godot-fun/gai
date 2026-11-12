class_name EditorFileIcon
extends RefCounted

## Resolves a workspace path to a Material icon in [code]res://agent/asset/image/file[/code].
## Names are matched in lowercase. [code].gd[/code] uses [code]godot.svg[/code], not a file named [code]gd.svg[/code].
## Directories reuse the colorless Material Symbols folders from [code]res://agent/asset/image/ui[/code],
## tinted with the accent color so they follow the theme like the toolbar app icons.

const ICON_DIRECTORY := "res://agent/asset/image/file/"
const FOLDER_ICON := "res://agent/asset/image/ui/folder.svg"
const FOLDER_OPEN_ICON := "res://agent/asset/image/ui/folder_open.svg"

const FILE_NAMES: Dictionary[String, String] = {
	"dockerfile": "docker",
	"gnumakefile": "makefile",
	"sconstruct": "scons",
	"sconscript": "scons",
	"cmakelists.txt": "cmake",
	".gitignore": "git",
	".gitattributes": "git",
	".gitmodules": "git",
	".gitconfig": "git",
	"go.mod": "go-mod",
	"go.sum": "go-mod",
	"package.json": "nodejs",
	"tsconfig.json": "tsconfig",
	"copying": "license",
	"contributors": "authors",
}

const EXTENSIONS: Dictionary[String, String] = {
	"gd": "godot",
	"tscn": "godot-assets",
	"tres": "godot-assets",
	"godot": "godot-assets",
	"gdextension": "godot-assets",
	"gdshader": "godot-assets",
	"gdshaderinc": "godot-assets",
	"import": "godot-assets",
	"py": "python",
	"pyw": "python",
	"pyi": "python",
	"rb": "ruby",
	"rake": "ruby",
	"pl": "prolog",
	"pm": "perl",
	"cs": "csharp",
	"cc": "cpp",
	"cxx": "cpp",
	"hh": "hpp",
	"hxx": "hpp",
	"m": "objective-c",
	"mm": "objective-cpp",
	"js": "javascript",
	"mjs": "javascript",
	"cjs": "javascript",
	"jsx": "react",
	"ts": "typescript",
	"mts": "typescript",
	"cts": "typescript",
	"tsx": "react_ts",
	"kt": "kotlin",
	"kts": "kotlin",
	"rs": "rust",
	"yml": "yaml",
	"jsonc": "json",
	"json5": "json",
	"ini": "settings",
	"cfg": "settings",
	"conf": "settings",
	"properties": "settings",
	"env": "tune",
	"htm": "html",
	"xhtml": "html",
	"md": "markdown",
	"mdown": "markdown",
	"mkd": "markdown",
	"scss": "sass",
	"sh": "console",
	"bash": "console",
	"zsh": "console",
	"fish": "console",
	"bat": "console",
	"cmd": "console",
	"ps1": "powershell",
	"psm1": "powershell",
	"sql": "database",
	"psql": "database",
	"ddl": "database",
	"dml": "database",
	"rej": "diff",
	"patch": "git",
	"cls": "tex",
	"sty": "tex",
	"bib": "bibliography",
	"glsl": "shader",
	"vert": "shader",
	"frag": "shader",
	"geom": "shader",
	"tesc": "shader",
	"tese": "shader",
	"comp": "shader",
	"hlsl": "shader",
	"fx": "shader",
	"wgsl": "shader",
	"bmp": "image",
	"dds": "image",
	"exr": "image",
	"jpg": "image",
	"jpeg": "image",
	"gif": "image",
	"ktx": "image",
	"png": "image",
	"tga": "image",
	"webp": "image",
	"ico": "image",
	"tif": "image",
	"tiff": "image",
	"avif": "image",
	"heic": "image",
	"wav": "audio",
	"mp3": "audio",
	"ogg": "audio",
	"flac": "audio",
	"aac": "audio",
	"m4a": "audio",
	"avi": "video",
	"m4v": "video",
	"mkv": "video",
	"mov": "video",
	"mp4": "video",
	"mpeg": "video",
	"mpg": "video",
	"ogv": "video",
	"webm": "video",
	"ttf": "font",
	"otf": "font",
	"woff": "font",
	"woff2": "font",
	"eot": "font",
	"gz": "zip",
	"tgz": "zip",
	"tar": "zip",
	"bz2": "zip",
	"xz": "zip",
	"7z": "zip",
	"rar": "zip",
	"txt": "document",
}

static var present: Dictionary[String, bool] = {}
static var textures: Dictionary = {}


## Resource path of the SVG for [param file_path]. Directories use the folder icon.
static func icon_path(file_path: String, is_directory: bool) -> String:
	if is_directory:
		return FOLDER_ICON
	var file_name := file_path.get_file().to_lower()
	var stem: String = FILE_NAMES.get(file_name, "")
	if stem.is_empty():
		var extension := file_name.get_extension()
		if extension.is_empty():
			stem = file_name if has_icon(file_name) else ""
		else:
			stem = EXTENSIONS.get(extension, "")
			if stem.is_empty() and has_icon(extension):
				stem = extension
	if not has_icon(stem):
		stem = "file"
	return icon_file(stem)


## Texture for a row icon. Directories switch to the open folder while expanded; the Material
## Symbols folders carry no fill color, so [IconStyle] tints them with the accent color.
static func texture(file_path: String, is_directory: bool, expanded: bool = false) -> Texture2D:
	if is_directory:
		return IconStyle.tinted(FOLDER_OPEN_ICON if expanded else FOLDER_ICON, ThemeColor.accent_theme_color())
	var path := icon_path(file_path, false)
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
