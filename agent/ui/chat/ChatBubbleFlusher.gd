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
	if not is_instance_valid(rich_text) or entry == null:
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
		if not is_instance_valid(item.rich_text):
			continue
		ChatBubbleFactory.refresh_rich_text(item.rich_text, item.entry)
	await ThreadUtils.async_sleep(FLUSH_MS)
	AgentEvents.events.chat_bubble_flushed.emit()
	pass
