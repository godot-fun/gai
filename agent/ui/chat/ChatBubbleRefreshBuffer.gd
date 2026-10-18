class_name ChatBubbleRefreshBuffer
extends RefCounted

## Buffers streaming bubble refreshes, deduplicates them, and applies them in batches.

const FLUSH_MS := 100
const TIMER_NAME := "agent_chat_bubble_refresh"


## One buffered refresh target; entry.body mutates in place while rich_text stays fixed.
class BufferedRefresh:
	var rich_text: RichTextLabel = null
	var entry: ChatEntry = null

	func _init(p_rich_text: RichTextLabel, p_entry: ChatEntry) -> void:
		rich_text = p_rich_text
		entry = p_entry


## Deduped by rich_text; the same bubble appears only once per flush window.
var pending: Array[BufferedRefresh] = []


func setup() -> void:
	SchedulerBus.schedule_at_fixed_rate(flush, FLUSH_MS, TIMER_NAME)
	pass


## Buffer a bubble refresh; update its entry pointer when it is already pending.
func enqueue(rich_text: RichTextLabel, entry: ChatEntry) -> void:
	if not is_instance_valid(rich_text) or entry == null:
		return
	for item: BufferedRefresh in pending:
		if item.rich_text == rich_text:
			item.entry = entry
			return
	pending.append(BufferedRefresh.new(rich_text, entry))
	pass


func flush() -> void:
	if pending.is_empty():
		return
	# Swap so enqueue during flush goes to the next batch.
	var batch := pending
	pending = []
	for item: BufferedRefresh in batch:
		if not is_instance_valid(item.rich_text):
			continue
		ChatBubbleFactory.refresh_rich_text(item.rich_text, item.entry)
	await ThreadUtils.async_sleep(FLUSH_MS)
	AgentEvents.events.chat_bubble_flushed.emit()
	pass
