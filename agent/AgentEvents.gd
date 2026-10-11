class_name AgentEvents
extends RefCounted

## Application state notifications shared by the agent runtime, managers, and UI.
## Managers and runtime code emit completed state changes; UI code may observe them.
## UI actions must call a manager's public command method directly. Managers must not
## subscribe to UI-originated events through this event bus.

## Pi agent-core event names. Multi-session: agent/turn signals include session_id.

# prompt("...")
# ├─ agent_start              # whole run begins
# │   ├─ turn_start           # one LLM round + tools
# │   │   ├─ message_update   (assistant streaming)
# │   │   ├─ message_complete (assistant response received)
# │   │   ├─ tool_execution_start
# │   │   └─ tool_execution_end
# │   └─ turn_end
# └─ agent_end                # whole run ends


static var events := Events.new()


class Events:
	# ===========================================================================
	# AGENT RUNTIME EVENTS — AgentLoop -> manager/UI
	# ===========================================================================

	# Agent lifecycle
	signal agent_start(session_id: int)
	signal agent_end(session_id: int, error_message: String)

	# Turn lifecycle — one LLM call + tool executions
	signal turn_start(session_id: int)
	signal turn_end(session_id: int)

	# Message lifecycle
	signal message_update(session_id: int, chunk: String, stream_kind: String)
	signal message_complete(session_id: int, usage: OpenAiUsage)

	# Tool execution lifecycle
	signal tool_execution_start(session_id: int, tool_call_id: String, tool_name: String, args: Dictionary[String, Variant])
	signal tool_execution_end(session_id: int, tool_call_id: String, tool_name: String, agent_tool_result: AgentToolResult)

	# ===========================================================================
	# APPLICATION STATE NOTIFICATIONS — manager/common -> UI
	# ===========================================================================

	# Session management
	signal session_added(session_id: int, title: String)
	signal session_removed(session_id: int)
	signal session_selected(session_id: int, previous_session_id: int)
	signal session_title_changed(session_id: int, title: String)

	# Session run control
	signal session_stop(session_id: int)
	## Manual context compaction lifecycle.
	signal compaction_start(session_id: int)
	signal compaction_end(session_id: int, success: bool, error_code: String)

	# Pending message queue
	## Pending user messages changed for one session.
	signal session_queue_changed(session_id: int)

	# Chat entries
	signal chat_entry_add(session_id: int, entry: ChatEntry)
	signal chat_entry_update(session_id: int, entry: ChatEntry, stream_kind: String)
	signal chat_entry_delete(session_id: int)
	# Appearance
	## Markdown bubble rendering switched (see [method AgentSetting.set_markdown_enabled]).
	signal markdown_changed(enabled: bool)
	## Active run visual changed (see [method AgentSetting.set_visual_type]).
	signal visual_type_changed(visual_type: int)

	# Workspace
	## Workspace root switched (see [method AgentWorkspace.set_root]) — sessions and file
	## paths now resolve under the new root, so listeners reload their state.
	signal workspace_changed(path: String)

	# ===========================================================================
	# UI-ONLY COORDINATION — UI -> UI; managers must never subscribe below
	# ===========================================================================

	## Emitted after ChatBubbleFlusher applies a pending batch (every ~100 ms while streaming).
	signal chat_bubble_flushed

	# Chat navigation and input
	## A search result requests that the transcript reveal a specific persisted entry.
	signal chat_search_result_selected(session_id: int, entry_index: int)
	## A bubble handed its body back to the chat input (delete / revert) for re-editing.
	signal chat_input_prefill(text: String)

	# Session context controls
	signal skill_context_changed(session_id: int)
	## AGENTS.md project prompt added to / removed from a session (see AgentPromptToggle).
	signal agent_context_changed(session_id: int)
	pass
