class_name ChatBubbleFlusher
extends RefCounted

## Buffers streaming bubble refreshes, deduplicates them, and applies them in batches.

const FLUSH_MS := 100
const TIMER_NAME := "agent_chat_bubble_refresh"


## One buffered refresh target; entry.body mutates in place while the bubble stays fixed.
class BufferedRefresh:
	var bubble: BubbleContainer = null
	var entry: ChatEntry = null

	func _init(p_bubble: BubbleContainer, p_entry: ChatEntry) -> void:
		bubble = p_bubble
		entry = p_entry


## Deduped by bubble; the same bubble appears only once per flush window.
var pending: Array[BufferedRefresh] = []


func setup() -> void:
	SchedulerBus.schedule_at_fixed_rate(flush, FLUSH_MS, TIMER_NAME)
	pass


## Buffer a bubble refresh; update its entry pointer when it is already pending.
func enqueue(bubble: BubbleContainer, entry: ChatEntry) -> void:
	if not is_instance_valid(bubble) or entry == null:
		return
	for item: BufferedRefresh in pending:
		if item.bubble == bubble:
			item.entry = entry
			return
	pending.append(BufferedRefresh.new(bubble, entry))
	pass


func flush() -> void:
	if pending.is_empty():
		return
	# Swap so enqueue during flush goes to the next batch.
	var batch := pending
	pending = []
	for item: BufferedRefresh in batch:
		if not is_instance_valid(item.bubble):
			continue
		item.bubble.refresh(item.entry)
	await ThreadUtils.async_sleep(FLUSH_MS)
	AgentEvents.events.chat_bubble_flushed.emit()
	pass
