# Repository Map

- `zfoo/`: Reusable Godot framework.
- `agent/`: Desktop agent application.
- `cli/`: Command-line application.
- `cpp/`: godot-cpp GDExtension (C++ bindings for the Godot script API).
- `test/`: Unit and integration tests.
- `.agents/skills/`: Reusable AI agent skills.
- `.ai/`: Scripts used by skills.


---


# GDScript Rules

## General

- **Types**: Use explicit types on function signatures and return values (`-> void`, etc.). Use the `class_name` type when a class has one. **Prefer `:=` for locals** to lock in the inferred type at declaration; use `var x = ...` only when you need Variant or mixed types.
- **Docs**: Use `##` comments for scene entry points or complex logic. Match the tone of nearby files.
- **Nodes**: Prefer `@onready var name: Type = $Path`.
- **Compact formatting**: Keep code on one line when it remains readable.
- **Trailing pass**: Every named function without an explicit `return` must end with `pass`, even when its body is non-empty. Inline anonymous functions are exempt.

## Naming

**`_` is mainly for engine callbacks** (`_ready`, `_process`, `_notification`, `_init`, etc.). **Do not prefix business methods** like `_refresh_xxx` — that clutters the file with `_` like lifecycle hooks. Use `_` on variables sparingly for internal details. GDScript has no real private; use structure and folders instead.

**Member variables**: Normal state/refs usually **no `_`** (`player`, `news_cache`). Too many `_` names hurt autocomplete and search, and look like lifecycle hooks. Use `_` only for clear implementation details (`_http_client`, `_buffer`, `_is_loading`). Official small demos often use `var _speed`; large projects do not need that pattern everywhere.

| Kind | Naming | Notes |
|------|--------|-------|
| Engine lifecycle | `_ready`, `_process`, `_physics_process`, `_input`, etc. | Keep the official `_` prefix. |
| Normal members | `player`, `ui_panel`, `news_cache` | **No** `_` prefix. |
| Internal vars | `_http_client`, `_buffer`, `_retry_count` | Implementation detail; **use sparingly**. |
| Signal handlers | `on_buy_pressed`, `on_timer_timeout`, or `handle_buy`, `handle_close` | **No** `_on_*`; keep separate from engine hooks. |
| Business / utils | `refresh_trending_items`, `set_tab`, `load_config_file` | **No** `_` prefix; distinguish from lifecycle funcs. |

When connecting signals in `_ready`, prefer:

```gdscript
func _ready() -> void:
	button.pressed.connect(on_buy_item)
	pass

func on_buy_item() -> void:
	pass

func refresh_ui() -> void:
	update_labels()
	pass
```


---


# Godot Framework Reference

## GodotFramework — gdf

The Autoload node runs `GodotFramework.gd`, whose global class name is `gdf`.

```gdscript
# Defer a callable to the main thread (useful from network / worker callbacks)
gdf.callable_deferred(func() -> void: refresh_ui())

# Graceful exit (waits a few frames before quit)
await gdf.quit()
```


## AI — OpenAI-compatible chat

```gdscript
var client := OpenAiClient.new(OS.get_environment("OPENAI_API_KEY"), "https://api.deepseek.com/chat/completions", "deepseek-v4-flash")
var reply := await client.async_chat("hello", "you are a helpful assistant")

# Streaming — on_delta called for each token fragment; read full text from completion.content
var stream_completion := await client.async_chat_messages_stream(client.build_messages("hello", "you are a helpful assistant"), tools,
	proxy, func(delta: String, stream_kind: String): print(delta))
var streamed := stream_completion.content
```


## Audio — music, voice, and sound effects

```gdscript
# Single track or playlist (auto cross-fade near end of track)
Audio.play_music("res://audio/bgm.mp3")
Audio.play_musics(["res://audio/a.mp3", "res://audio/b.mp3"])

# One-shot sound / voice
await Audio.play_voice("res://audio/narration.mp3")

# Multi-channel SFX (overlapping sounds on SoundEffect bus)
Audios.play("res://audio/click.mp3", 0.8)
```


## Animation

```gdscript
# Plays a one-shot sprite sheet animation and removes itself when finished. Multi-row sheet: 4 columns × 4 rows, scale 0.5, 13 fps
EffectAnimation2D.spawn(Vector2(500, 200), self, "res://effects/attack.png", Vector2i(4, 4), 0.5, 13)
```


## Hot update

- Godot PCK hot update for a single PCK
- Workflow: Launch App → Check Version → Download PCK → Verify MD5 → Load PCK → Enter Game


## HTTP

```gdscript
# GET request
var response := await HttpHelper.async_get("https://api.example.com/data")
if response.success:
	Log.info(response.get_body_string())
```


## Log

- Logs are written to `{user_data}/logs/godot.log`.

```gdscript
Log.info("player login uid:[{}]", user_id)
Log.error("load failed path:[{}] err:[{}]", path, err)
```


## Network

- Supports `TcpClient`, `TcpClientThread`, `WebsocketClient`, and `WebsocketClientThread`.

```gdscript
# Create a network session
# `ICodec` for encode/decode
var session: Session = TcpClient.new(Codec.new(), "127.0.0.1:80")

# Register receiver (typically at login / session init)
Router.register_receiver(LoginResponse, func(packet: LoginResponse) -> void: on_login_response(packet))

# Send a message without waiting for a response (fire-and-forget)
Router.send(session, SomeRequest.new())

# Request–response (waits for matching reply or timeout)
var reply: LoginResponse = await Router.async_ask(session, LoginRequest.new())
```


## ResourceHelper — async loading

- Avoid blocking the main thread when loading large assets.

```gdscript
var texture: Texture2D = await ResourceHelper.async_load("res://assets/icon.svg")
var scene: PackedScene = await ResourceHelper.async_load("res://scene/Level.tscn")
```


## SceneHelper — scenes & nodes

```gdscript
# Switch scene with fade transition (default: RectTransitionFade)
await SceneHelper.async_change_scene_to_file("res://scene/Main.tscn")

# Custom slide transition
await SceneHelper.async_change_scene_to_file("res://scene/Main.tscn", RectTransitionSlide.new())

# Instantiate a scene as a child of a node
var node := SceneHelper.add_scene_to_node(load("res://scene/Popup.tscn"), self)

# Safe queue_free
SceneHelper.queue_free(old_node)
```


## SchedulerBus — delayed & periodic tasks

```gdscript
var sw := StopWatch.new() # sw.cost_seconds()

# Run once after 1000 ms
SchedulerBus.schedule(func() -> void: do_something(), 1000)

# Repeating timers instead of manually creating a `Timer`.
SchedulerBus.schedule_at_fixed_rate(func() -> void: poll_status(), 2000)
```


## Setting — persistent user config

```gdscript
Setting.set_bool("sound_enabled", true)
Setting.set_string("nickname", "player1")
Setting.save()

var enabled := Setting.get_bool("sound_enabled", false)
var name := Setting.get_string("nickname", "")
```


## I18n — localization

Use `I18n.t()` to translate text:

```gdscript
label.text = I18n.t("settings.title")
```


## Collection — collection utilities

`ConcurrentArrayList`, `ConcurrentMapInt`, `LazyCache`, `LruStringCache`, `ReadyQueue`, `RingIntList`, `RingStringList`


## Common — common utilities

`StringBuilder`, `Utf8StreamDecoder`


## Utils — common helpers

- `ArrayUtils`, `CollectionUtils`, `FileUtils`, `GitUtils`, `GlobUtils`
- `HttpUtils`, `IdUtils`, `JsonUtils`, `NetUtils`
- `NodeUtils`, `NumberUtils`, `OSUtils`, `ProxyUtils`, `RandomUtils`
- `RateLimitUtils`, `ReflectionUtils`, `StringUtils`, `ThreadUtils`, `TimeUtils`


---


# UI Style Guide

## Typography

- `Fonts`: Lazily loads the bundled Noto Sans SC fonts in light, regular, medium, semibold, and bold weights.
- `Typography`: Provides shared display, headline, title, body, and label sizes, plus letter-spacing values.


## Layout and controls

- `Margin`: Provides spacing tokens in 4-pixel increments.
- `ControlSize`: Provides standard control heights, corner radii, border widths, and square sizes.
- `StyleBoxHelper`: Creates `StyleBoxFlat` instances and applies their content margins.
- `ButtonStyle`: Builds and applies theme-aware button state boxes and font colors.
- `ScrollBarStyle`: Applies standard or custom scrollbar thickness, colors, and rounding.


## Theme and colors

- `ThemeColor`: Manages dark/light mode, the user accent color, and colors derived from the active theme.
- `ColorBase`: Provides theme-aware semantic colors for surfaces, text, borders, and status feedback.
- `ColorFile`: Provides theme-aware colors for audio, image, video, text, and folder types.
- `ColorMarkdown`: Provides theme-aware colors used by Markdown rendering.

Avoid hard-coded fonts, sizes, spacing, radii, and colors when a matching shared token exists.


## Feedback — alerts, desktop toasts, popup windows

```gdscript
# Brief in-app feedback: show a non-blocking top-center message with a semantic result color.
Alert.alert("Saved successfully", ColorBase.success)
Alert.alert("Network error", ColorBase.error)

# Background-task feedback: show an OS-level notification when the app may be unfocused.
DesktopToast.show_toast("Run finished", "All tasks completed", ColorBase.success)

# Detailed feedback: show important or long content in a popup sized by viewport percentages.
PopupWindow.show_window("Details", "Full feedback message", 70, 80)
```


---


# Testing

Run the unit test scene relevant to the changed code before reporting the task complete. A test run passes only when Godot exits with code `0`; do not report completion when the command fails, hangs, or prints a GDScript parse error.

## Run tests from the command line

Run commands from the repository root. Replace `godot` with the path to the Godot 4 executable when it is not available on `PATH`.

```powershell
# Example: run one unit test scene.
godot --headless --path . res://test/common/CommonTest.tscn

# GDExtension (godot-cpp) tests — requires cpp/ binaries and .godot/extension_list.cfg.
godot --headless --path . res://test/cpp/CppTest.tscn
```

## Unit tests

Attach `zfoo/gdtest/UnitTest.gd` to a scene root. It scans `.gd` files in the scene’s folder; set `include_subfolders` on the scene root only when recursive discovery is intended.

A method is discovered as a unit test when:

- Its name starts or ends with `test`, case-insensitively.
- It takes no arguments.
- An instance test belongs to an instantiable script; `static` tests are also supported and run first.

Use `assert(...)` for expectations. A failed assertion or any error logged through `gdf.events.log_error` fails the run and exits with code `1`.

```gdscript
func substring_before_test() -> void:
	assert(StringUtils.substring_before("a/b/c", "/") == "a")
	pass

static func OSUtils_is_windows_test() -> void:
	assert(OSUtils.is_windows() == (OS.get_name() == "Windows"))
	pass
```

Place the test script beside its runner scene. For example, `test/common/CommonTest.tscn` runs matching methods from the `.gd` files in `test/common/`.

## Integration tests

Attach `zfoo/gdtest/IntegrationTest.gd` to a scene root. It discovers `.tscn` files in the same folder whose basename starts or ends with `test`, case-insensitively. Set `include_subfolders` when the runner should scan recursively.

Integration test scenes run one at a time. Each scene must emit `gdf.events.test_passed` when its asynchronous work is complete; scenes using `UnitTest.gd` emit this signal automatically.

```gdscript
func _ready() -> void:
	await run_scenario()
	gdf.events.test_passed.emit()
	pass
```

Log failures through `Log.error(...)` so the runner receives `gdf.events.log_error`, stops the suite, and exits with code `1`. Do not emit `test_passed` after a failed expectation.

## Completion checklist

Before reporting a code change complete:

1. Run the unit test scene most relevant to the changed code.
2. Confirm the process exits with code `0` and has no parse errors or failure logs.
3. Run integration tests only when the change affects cross-scene behavior; the complete integration suite is not required by default because it is slow.
4. If tests cannot be run, state exactly why and identify what remains unverified.
