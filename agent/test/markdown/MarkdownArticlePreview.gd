extends Control

const ARTICLE := """# The Field Guide to Markdown Rendering

This long-form article exercises **MarkdownParser** and **MarkdownHelper** with realistic English prose, structured content, inline formatting, code, tables, links, and images. A dedicated Chinese section later in the article verifies CJK fonts, punctuation, wrapping, and mixed-language layout.

> Markdown is valuable because structure and meaning remain readable even before the document is rendered.
> This second quoted line checks consecutive blockquotes, indentation, color, and responsive wrapping.

---

## 1. Typography and Inline Styles

A normal paragraph should remain comfortable to read when the window becomes narrow. This sentence contains **bold text**, *italic text*, ***bold italic text***, ~~struck text~~, __underscore bold__, _underscore italic_, and the supported extension <u>HTML underline</u>.

Inline code such as `var message := "Hello, Markdown!"` should use a distinct background. Literal content inside code—`[b]`, `**asterisks**`, and `array[0]`—must not be parsed a second time.

External links should be clearly recognizable: visit [Godot Engine](https://godotengine.org), test a formatted label with [**OpenAI**](https://openai.com "OpenAI"), or open an [email](mailto:user@example.com).

### A Third-Level Heading

#### A Fourth-Level Heading

##### A Fifth-Level Heading

###### A Sixth-Level Heading

## 2. Lists and Tasks

- The first unordered item is intentionally short.
- The second item is long enough to wrap across multiple lines, making bullet alignment and continuation indentation easy to inspect.
* An asterisk can also introduce a list item.
+ A plus sign is accepted as another list marker.

1. Prepare the Markdown source.
2. Convert the source into RichTextLabel BBCode.
3) Render the result and inspect its visual hierarchy.

- [x] Headings and paragraphs
- [x] Emphasis, links, and inline code
- [x] Tables, quotes, and images
- [ ] Verify the layout at several window widths

> [!NOTE]
> Informational context uses a blue marker and an info symbol.

> [!WARNING]
> Check potentially surprising behavior before continuing.

> [!TIP]
> A successful recommendation uses a green check.

> [!IMPORTANT]
> Important guidance is highlighted in purple.

> [!CAUTION]
> A destructive or dangerous action uses a red cross.

## 3. Code Blocks

```gdscript
func greet(name: String) -> String:
    var message := "Hello, %s!" % name
    # Markdown stays literal here: **bold**, [link](url), and ---
    return message
```

The fenced block above should preserve indentation and spaces while presenting an independent background. The plain-text block below also contains a blank line:

~~~
Markdown -> Parser -> BBCode -> RichTextLabel

Blank lines must survive the conversion.
~~~

## 4. Feature Matrix

The first matrix covers inline syntax. It intentionally mixes plain text, nested formatting, punctuation, links, code, and CJK characters inside table cells.

| Inline feature | Markdown source | Rendered sample | What to inspect |
| :--- | :---: | :--- | ---: |
| Bold | `**strong**` | **strong** | Weight |
| Italic | `*emphasis*` | *emphasis* | Slant |
| Bold italic | `***both***` | ***both*** | Nested style |
| Underscore bold | `__strong__` | __strong__ | Alternate marker |
| Underscore italic | `_emphasis_` | _emphasis_ | Word boundaries |
| Strike | `~~obsolete~~` | ~~obsolete~~ | Strike line |
| HTML underline | `<u>underlined</u>` | <u>underlined</u> | Underline position |
| Inline code | `` `code()` `` | `code()` | Font and chip |
| Link | `[Godot](https://godotengine.org)` | [Godot](https://godotengine.org) | Color and click |
| Formatted link | `[**OpenAI**](https://openai.com)` | [**OpenAI**](https://openai.com) | Nested bold label |
| Literal brackets | `array[0]` | array[0] | No BBCode leak |
| Nested emphasis | `**outer *inner* text**` | **outer *inner* text** | Recursive styling |
| Dunder name | `__init__` | __init__ | No false bold |
| Chinese bold | `**中文粗体**` | **中文粗体** | CJK weight |
| Mixed language | `Godot 引擎 4.x` | Godot 引擎 4.x | Shared baseline |
| Empty cell | | Content after empty cell | Column normalization |

The second matrix records the block-level coverage provided by this article. The examples are descriptive because block constructs cannot be nested safely inside a table cell.

| Block feature | Source pattern | Demonstrated in | Visual expectation |
| :--- | :---: | :--- | ---: |
| Headings | `#` through `######` | Sections 1–7 | Clear size hierarchy |
| Paragraphs | Consecutive prose | Every section | Natural wrapping |
| Blockquotes | `> quoted line` | Introduction and edge cases | Accent bar and inset text |
| GitHub alerts | `> [!NOTE]` | Section 2 | Colored symbol, title, and accent bar |
| Unordered lists | `-`, `*`, `+` | Section 2 | Stable bullet alignment |
| Ordered lists | `1.` and `3)` | Section 2 | Preserved numbering |
| Task lists | `- [x]`, `- [ ]` | Sections 2 and 6 | Checked and empty boxes |
| Fenced code | Triple backticks plus language | Section 3 | Colored keyboard title and preserved whitespace |
| Tilde fence | Triple tildes | Section 3 | Same code treatment |
| Tables | Header separator row | Section 4 and 6 | Grid, padding, header fill |
| Horizontal rules | `---`, `* * *`, `___` | Sections 7 and conclusion | Full-width divider |
| Local images | `![alt](res://path)` | Section 5 | Resource loading and scaling |
| Remote images | `![alt](https://...)` | Section 5 | Download, cache, and replacement |
| Local videos | `![alt](res://path.mp4)` | Section 5 | Video placeholder and clickable path |
| Local audio | `[label](res://path.wav)` | Section 5 | File link label and clickable path |
| Local folders | `[label](res://folder)` | Section 5 | Folder character and clickable path |
| Local files | `[label](res://path.gd)` | Section 5 | File character and clickable path |
| Config and executable files | `[label](res://path.json)` | Section 5 | Gear character and clickable path |
| Text and documents | `[label](res://path.md)` | Section 5 | Memo character and clickable path |

## 5. Media Gallery

The images in this section are read directly from `.ai/test/image`. The first PNG checks portrait scaling and fine visual detail.

![Portrait test image](C:/github/gai/.ai/test/image/girl.png)

### Armored Vehicle Series

These three JPEG files verify consecutive images, differing aspect ratios, scaling, captions, and spacing inside a long article.

![Tank test image one](res://.ai/test/image/tank1.jpg)

![Tank test image two](res://.ai/test/image/tank2.jpg)

![Tank test image three](res://.ai/test/image/tank3.jpg)

### Remote Image

The Godot logo below is downloaded over HTTPS. It verifies the remote-image request, local cache, placeholder replacement, and repeated-render behavior.

![Remote Godot logo](https://raw.githubusercontent.com/github/explore/main/topics/godot/godot.png)

### Missing Remote Image

The image below intentionally points to a missing remote file. It verifies the placeholder appearance when an image request fails.

![Missing remote image](https://raw.githubusercontent.com/github/explore/main/topics/godot/this-image-does-not-exist.png)

### Local Videos

These two MP4 files verify that local videos render as video placeholders instead of being loaded as image textures. Clicking either placeholder should expose the original video path through the normal Markdown media link behavior.

![Opening test video](res://.ai/test/video/opening.mp4)

![Ending test video](res://.ai/test/video/ending.mp4)

### Local Audio

These WAV files verify that local audio paths render as clickable Markdown file links with readable labels.

[Han voice](res://.ai/test/audio/han.wav)

[Han voice, louder version](res://.ai/test/audio/han_loud.wav)

[Zhu Bajie voice](res://.ai/test/audio/zhu_ba_jie.wav)

### Local Folder and Files

These links verify that the parser adds distinct, colored characters for folders and file categories while keeping every path clickable.

[Markdown folder](res://zfoo/markdown)

[Ordinary file](res://LICENSE)

[Markdown parser source](res://zfoo/markdown/MarkdownParser.gd)

[Project configuration](res://project.godot)

[PowerShell executable script](res://sync-godot-framework.ps1)

## 6. 中文排版测试

这一节专门检查中文 Markdown 的显示效果。中文正文应使用正确的字体，标点符号应该清晰，窗口变窄时需要自然换行，不能出现字符缺失或异常间距。

这里包含 **中文粗体**、*中文斜体*、***粗斜体组合***、~~中文删除线~~、<u>中文下划线</u>，以及行内代码 `打印("你好，世界！")`。

> **中文组合引用：** 引用内部包含粗体、*斜体*、`代码片段` 和 [中文链接](https://example.com)。这一行写得稍长，用于观察中文连续文本在引用区域内的自动换行。

- 第一项：检查项目符号与中文基线
- 第二项：检查较长的中文列表内容换行之后，后续文字是否与首行内容保持正确对齐
- [x] 中文标题、正文和引用
- [ ] 中文与 English 混排效果

| 检查项目 | 示例内容 | 预期结果 |
| :--- | :---: | ---: |
| 字体 | 中文字符 ABC 123 | 字形完整 |
| 标点 | “引号”、句号。 | 间距自然 |
| 混排 | Godot 引擎 4.x | 基线一致 |

## 7. Edge Cases

The following expressions should remain ordinary text rather than accidental formatting: `my_var_name`, 3 * 4 * 5, a _ b _ c, test@example.com, and the literal tag `[center]`.

Raw RichTextLabel tags must be escaped rather than executed: [b]not bold[/b], [/code], and [url=https://example.com]not a live BBCode link[/url].

These links exercise destination parsing: [a URL with parentheses](https://en.wikipedia.org/wiki/Markdown_(markup)), [an angle-bracket destination](<https://example.com/docs>), [a double-quoted title](https://example.com "Example title"), and [a single-quoted title](https://example.com 'Another title').

  ### An Indented Heading

### A Heading with Closing Hashes ###

The next two lines contain pipes but no separator row, so they must remain ordinary paragraphs rather than becoming a table:

alpha | beta
gamma | delta

### Horizontal Rule Variants

Three hyphens:

---

Three spaced asterisks:

* * *

Three underscores:

___

> **Combined English quote:** A blockquote may contain bold text, *emphasis*, `code`, and a [link](https://example.com) without losing its structure.

---

## Conclusion

The visual review passes when heading hierarchy, inline styles, lists, task boxes, code blocks, tables, links, Chinese text, all four local images, both local video placeholders, all three local audio links, the local folder and ordinary-file links, the remote image, scrolling, and text selection render correctly.
"""

@onready var background: ColorRect = $Background
@onready var page_margin: MarginContainer = $ContentScroll/PageMargin
@onready var article_body: VBoxContainer = $ContentScroll/PageMargin/ArticleBody


func _ready() -> void:
	background.color = Colors.app_background
	page_margin.add_theme_constant_override("margin_left", Margin.ma_12)
	page_margin.add_theme_constant_override("margin_top", Margin.ma_8)
	page_margin.add_theme_constant_override("margin_right", Margin.ma_12)
	page_margin.add_theme_constant_override("margin_bottom", Margin.ma_12)
	article_body.add_theme_constant_override("separation", Margin.ma_4)
	render_article()
	gdf.events.test_passed.emit()
	pass


func render_article() -> void:
	article_body.add_child(MarkdownHelper.create_rich_text_label(Colors.primary_text, ARTICLE, true))
	pass
