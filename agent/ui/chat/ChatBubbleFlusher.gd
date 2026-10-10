class_name ChatBubbleFlusher
extends RefCounted

## Coalesces streaming chat bubble UI updates.
## Agent tokens arrive faster than useful repaint rate — enqueue (rich_text, entry)
## pairs and flush every FLUSH_MS via SchedulerBus. Listeners use
## AgentEvents.bubble_rich_text_flushed to scroll or react after a batch.

const FLUSH_MS := 100
const TIMER_NAME := "agent_chat_bubble_flush"


## One pending sync target; entry.body mutates in place while rich_text stays fixed.
class PendingItem:
	var rich_text: RichTextLabel = null
	var entry: ChatEntry = null

	func _init(p_rich_text: RichTextLabel, p_entry: ChatEntry) -> void:
		rich_text = p_rich_text
		entry = p_entry


## Deduped by rich_text — same bubble only appears once per flush window.
var pending: Array[PendingItem] = []


func setup() -> void:
	SchedulerBus.schedule_at_fixed_rate(flush, FLUSH_MS, TIMER_NAME)
	pass


## Record a bubble that changed since the last flush; refresh entry pointer if already queued.
func enqueue(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	if rich_text == null or entry == null:
		return
	for item: PendingItem in pending:
		if item.rich_text == rich_text:
			item.entry = entry
			return
	pending.append(PendingItem.new(rich_text, entry))
	pass


## Drain pending immediately — e.g. agent run finished before the next timer tick.
func flush_now() -> void:
	flush()
	pass


func flush() -> void:
	if pending.is_empty():
		return
	# Swap so enqueue during flush goes to the next batch.
	var batch := pending
	pending = []
	for item: PendingItem in batch:
		if item.entry == null or item.rich_text == null or not is_instance_valid(item.rich_text):
			continue
		refresh_rich_text(item.rich_text, item.entry)
	await ThreadUtils.async_sleep(FLUSH_MS)
	AgentEvents.events.chat_bubble_flushed.emit()
	pass


## Push entry.body into the bubble RichTextLabel — full re-render per flush.
static func refresh_rich_text(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	## Thinking / Result use their own preview rules; other kinds honor MarkdownToggle.
	if entry.kind == ChatEntry.KIND_THINKING or entry.kind == ChatEntry.KIND_RESULT:
		ChatBubblePreview.apply(rich_text, entry.body)
		return
	if entry.kind == ChatEntry.KIND_FILE_TOOL:
		FileBubble.refresh(rich_text, entry)
		return
	if entry.kind == ChatEntry.KIND_GIT_DIFF:
		GitDiffBubble.refresh(rich_text, entry)
		return
	if entry.kind == ChatEntry.KIND_SKILL or entry.kind == ChatEntry.KIND_AGENT_PROMPT:
		SkillBubble.refresh(rich_text, entry)
		return
	rich_text.visible = StringUtils.is_not_blank(entry.body)
	MarkdownHelper.update_rich_text_label_text(
			rich_text,
			entry.body,
			MarkdownToggle.markdown_enabled_for_entry(entry)
	)
	pass
