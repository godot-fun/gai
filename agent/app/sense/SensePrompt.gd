class_name SensePrompt
extends Object

## Remote LLM prompts for sense input (screen OCR, one-shot compose JSON, diverge).
## Rich instructions are fine for remote models with large context.
## Local MiniCPM-V uses [SensePromptLocal] instead (short prompts + sequential steps).
## Picks Chinese or English from the app locale ([method I18n.get_locale]).

const SCREEN_PROMPT_EN := """Extract all information visible on this screenshot.
Cover every readable text (titles, menus, tabs, labels, buttons, placeholders, form values, messages, lists, status bars, tooltips, badges) and describe the app, window, layout, focused control, and any icons or images that matter for context.
Do not skip secondary panels, sidebars, or background chrome. Be complete and concrete.
Reply in plain text only.
"""

const SCREEN_PROMPT_ZH := """提取此截图中的全部可见信息。
覆盖所有可读文字（标题、菜单、标签页、标签、按钮、占位符、表单内容、消息、列表、状态栏、提示、角标），并描述应用、窗口、布局、焦点控件，以及有助于理解上下文的图标或图像。
不要遗漏次要面板、侧边栏或背景界面。尽量完整、具体。
仅用纯文本回复。
"""

const SCREEN_SEED_SYSTEM_EN := """Predict the most conservative and likely text the user would enter in the focused control from the screen context. Stay close to visible labels, nearby content, and the apparent task. Do not be creative, add unrelated details, or explain the prediction. Reply with only one directly pasteable draft."""
const SCREEN_SEED_SYSTEM_ZH := """根据屏幕上下文，预测用户最可能在焦点控件中输入的保守内容。紧贴可见标签、附近内容和当前任务，不要发挥创意、添加无关细节或解释预测过程。只回复一条可直接粘贴的正文。"""

const COMPOSE_SYSTEM_EN := """From the ASR transcript, optional screen context, and recent history, produce three candidates of the same intent.
Keep a clear length / information ladder: correct <= optimize << expand.

How to use inputs:
- Screen context (when present): disambiguate ASR with visible UI text; prefer matching labels/buttons/titles; match tone to the focused field. Do not invent unseen UI. If unavailable, use ASR and history only.
- Recent history (oldest first): resolve pronouns/ellipsis, keep topic continuity, avoid near-duplicates. Ignore unrelated older turns.

(1) correct — fix ASR errors only; stay close to what was said. If ASR is already fine, keep it nearly unchanged.
(2) optimize — polish wording and fluency of `correct`; same intent. Prefer rephrasing over adding facts. Little or no new information; do not turn it into a longer draft.
(3) expand — a much fuller pasteable draft of the same goal: add useful detail, structure, or brief rationale (screen-grounded when helpful). Do not change the goal or invent unrelated topics.

Reply with a JSON object only. Keep the keys exactly: correct, optimize, expand.

EXAMPLE JSON OUTPUT:
{"correct":"help me open settings","optimize":"please open Settings","expand":"please open the system Settings page so I can review notification preferences and app permissions"}
"""

const COMPOSE_SYSTEM_ZH := """根据语音识别文本、可选的屏幕上下文和近期历史，生成三个意图相同的候选。
保持清晰的长度 / 信息量阶梯：correct <= optimize << expand。

输入用法：
- 屏幕上下文（若有）：用可见界面文案消歧 ASR；优先对齐匹配的标签/按钮/标题；语气贴合焦点字段。不要编造未见界面。若不可用，仅用语音与历史。
- 近期历史（从旧到新）：消解指代/省略、保持话题连贯、避免近重复。忽略无关旧轮次。

(1) correct — 只修正识别错误，尽量贴近原话。若识别已正确，可几乎原样保留。
(2) optimize — 在 `correct` 上润色措辞与流畅度，意图不变。优先改写，少加新信息；不要写成更长草稿。
(3) expand — 同一目标的明显更完整、可粘贴草稿：补充有用细节、结构或简要理由（有屏幕时优先落地到界面信息）。不要改变目标或编造无关话题。

仅回复一个 JSON 对象。键名必须恰好为：correct、optimize、expand。

EXAMPLE JSON OUTPUT:
{"correct":"帮我打开设置","optimize":"请打开设置","expand":"请打开系统设置页面，我想检查通知偏好和应用程序权限"}
"""

const DIVERGE_SYSTEM_EN := """Predict what the user is about to type next into the focused field.
Use only the screen context (focused input, thread, labels, placeholders, nearby UI). There is no current utterance and no prior history.

Reply with ONLY the predicted next draft — no quotes, labels, titles, or commentary.

Go extravagant. Overshoot. Be gloriously excessive — not the safe, thin, corporate guess:
- The screen is a launchpad. Read its mood, genre, icons, half-finished thoughts, and empty fields, then vault into something vivid, surprising, and still pasteable.
- Prefer a lush, complete block over a short stub whenever the field can hold more than a few words. Fill the canvas; do not leave a timid one-liner when a paragraph would sing.
- Chat / email / comment: a full next message with heat — wit, tenderness, swagger, mischief, or drama as the thread allows. Add texture: a sharp image, a tiny story beat, a playful twist, a concrete example, a line that feels alive.
- Creative / prompt / search / idea boxes: flood the field with imagination — cinematic scenes, odd angles, lush sensory detail, alternate worlds, bold hypotheses, multi-beat sparks packed into one continuous draft.
- Brainstorm / notes / docs: spiral outward from what is visible into richer framing, unexpected connections, and high-voltage phrasing — still useful, never dry.
- Form / settings / command fields: stay concrete and specific (labels, placeholders, selection, nearby text), but pick the boldest plausible fill — the option with the most charge, not the beige default.
- If many paths fit, choose the single most dazzling high-leverage next draft: the one that would make the user grin, gasp, or move faster — while remaining on-theme with the screen.
- Anchor on visible names, titles, and quotes; around those anchors, invent without apology. Ornament freely. Do not collapse into generic filler, and do not wander into topics that ignore the UI.
- Sound human, magnetic, and immediately pasteable — never explain your process, never hedge with "maybe you could…".
"""

const DIVERGE_SYSTEM_ZH := """根据屏幕上下文，预测用户即将在焦点输入框中输入的内容。
只使用屏幕上下文（焦点输入框、对话线程、标签、占位符、附近界面）。没有当前语音，也没有历史记录。

只回复预测的下一步草稿——不要加引号、标签、标题或说明。

大胆一些。宁可过火，也不要安全、单薄、公司模板式的猜测：
- 屏幕是跳板。读懂它的氛围、类型、图标、半成品思路和空白字段，然后跃入生动、意外且仍可粘贴的内容。
- 只要字段能装下更多文字，就优先写饱满完整的一段，而不是短 stub。填满画布；能写一段时不要只留怯生生的一行。
- 聊天 / 邮件 / 评论：写一条有温度的下一条消息——机智、温柔、自信、调皮或戏剧张力，视线程而定。加点质感：鲜明意象、微小故事节拍、俏皮转折、具体例子、有生命力的句子。
- 创意 / 提示词 / 搜索 / 想法框：用想象力灌满字段——电影感场景、怪角度、丰沛感官细节、异世界、大胆假设、多节拍火花收进一段连续草稿。
- 头脑风暴 / 笔记 / 文档：从可见内容向外螺旋，补更丰富的框架、意外关联和高电压措辞——仍然有用，绝不干巴。
- 表单 / 设置 / 命令字段：保持具体明确（标签、占位符、选项、附近文字），但选最有冲击力的合理填法——有电荷的选项，不是米色默认值。
- 若多条路都成立，选那条最耀眼、最高杠杆的下一步草稿：让用户会心一笑、倒抽一口气或立刻行动——同时仍贴合屏幕主题。
- 锚定可见的名称、标题和引文；在锚定周围大胆虚构。自由点缀。不要塌成泛泛填充，也不要漂到无视界面的话题。
- 听起来像人、有吸引力、立刻可粘贴——永远不要解释过程，永远不要用「也许你可以…」式的犹豫。
"""

const DIVERGE_USER_EN := "Screen context:\n{}\n"
const DIVERGE_USER_ZH := "屏幕上下文：\n{}\n"

const COMPOSE_USER_EN := "ASR transcript:\n{}\n\nScreen context:\n{}\n\nRecent voice history (oldest first):\n{}\n"
const COMPOSE_USER_ZH := "语音识别文本：\n{}\n\n屏幕上下文：\n{}\n\n近期语音历史（从旧到新）：\n{}\n"

const HISTORY_NONE_EN := "(none)"
const HISTORY_NONE_ZH := "（无）"
const SCREEN_UNAVAILABLE_EN := "(unavailable)"
const SCREEN_UNAVAILABLE_ZH := "（不可用）"


static func use_chinese() -> bool:
	return I18n.get_locale().begins_with(I18n.ZH)


static func screen_prompt() -> String:
	return SCREEN_PROMPT_ZH if use_chinese() else SCREEN_PROMPT_EN


static func screen_seed_system() -> String:
	return SCREEN_SEED_SYSTEM_ZH if use_chinese() else SCREEN_SEED_SYSTEM_EN


static func compose_system() -> String:
	return COMPOSE_SYSTEM_ZH if use_chinese() else COMPOSE_SYSTEM_EN


static func diverge_system() -> String:
	return DIVERGE_SYSTEM_ZH if use_chinese() else DIVERGE_SYSTEM_EN


static func diverge_user_prompt(screen_text: String) -> String:
	var template := DIVERGE_USER_ZH if use_chinese() else DIVERGE_USER_EN
	return StringUtils.format(template, screen_text)


static func compose_user_prompt(voice_text: String, screen_context: String, history_lines: Array[String]) -> String:
	var chinese := use_chinese()
	var screen_block := screen_context if StringUtils.is_not_blank(screen_context) else (SCREEN_UNAVAILABLE_ZH if chinese else SCREEN_UNAVAILABLE_EN)
	var history_block := "\n".join(history_lines) if not history_lines.is_empty() else (HISTORY_NONE_ZH if chinese else HISTORY_NONE_EN)
	var template := COMPOSE_USER_ZH if chinese else COMPOSE_USER_EN
	return StringUtils.format(template, voice_text, screen_block, history_block)
