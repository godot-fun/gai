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
	signal session_stop(session_id: int, error_message: String)
	## Manual context compaction lifecycle.
	signal compaction_start(session_id: int)
	signal compaction_end(session_id: int, success: bool, error_code: String)

	# Pending message queue
	## Pending user messages changed for one session.
	signal session_queue_changed(session_id: int)

	# Chat entries
	signal chat_entry_add(session_id: int, entry: ChatEntry)
	signal chat_entry_update(session_id: int, entry: ChatEntry, stream_kind: String)
	## A chat entry was deleted. When delete_from_here is true, the selected entry and every
	## entry after it were removed; otherwise only the selected entry was removed.
	signal chat_entry_delete(session_id: int, entry_idx: int, delete_from_here: bool)

	# Workspace
	## Workspace root switched (see [method AgentWorkspace.set_root]) — sessions and file
	## paths now resolve under the new root, so listeners reload their state.
	signal workspace_changed(path: String)

	# ===========================================================================
	# SETTINGS — common -> UI
	# ===========================================================================

	## Markdown bubble rendering switched (see [method AgentSetting.set_markdown_enabled]).
	signal markdown_changed(enabled: bool)
	## Proxy address changed (see [method ApiSetting.save]).
	signal proxy_address_changed

	# ---------------------------------------------------------------------------

	## Chat-search shortcut changed (see [method ShortcutSetting.set_search_shortcut]).
	signal search_shortcut_changed
	## Previous user-message shortcut changed (see [method ShortcutSetting.set_prev_user_message_shortcut]).
	signal prev_user_message_shortcut_changed
	## Next user-message shortcut changed (see [method ShortcutSetting.set_next_user_message_shortcut]).
	signal next_user_message_shortcut_changed
	## Previous agent-reply shortcut changed (see [method ShortcutSetting.set_prev_reply_shortcut]).
	signal prev_reply_shortcut_changed
	## Next agent-reply shortcut changed (see [method ShortcutSetting.set_next_reply_shortcut]).
	signal next_reply_shortcut_changed

	# ===========================================================================
	# UI-ONLY COORDINATION — UI -> UI; managers must never subscribe below
	# ===========================================================================

	## Emitted after ChatBubbleFlusher applies a pending batch (every ~100 ms while streaming).
	signal chat_bubble_flushed
	## Middle-button chat-history auto-scroll interaction started.
	signal middle_scroll_started
	## Middle-button chat-history auto-scroll interaction ended.
	signal middle_scroll_ended(at_bottom: bool)

	# Chat navigation and input
	## A search result requests that the chat history reveal a specific persisted entry.
	signal chat_search_result_selected(session_id: int, entry_index: int)
	## A bubble handed its body back to the chat input (delete / revert) for re-editing.
	signal chat_input_prefill(text: String)

	# Sidebar session row actions (SessionRow -> AgentSessionSidebar)
	## User clicked a session row title (select or start rename when already active).
	signal session_select_pressed(session_id: int)
	## User clicked the session row delete button.
	signal session_delete_pressed(session_id: int)

	# Session context controls
	signal skill_context_changed(session_id: int)
	## Project memory index added to / removed from a session (see MemoryToggle).
	signal memory_context_changed(session_id: int)
	## AGENTS.md project prompt added to / removed from a session (see AgentPromptToggle).
	signal agent_context_changed(session_id: int)

	# ===========================================================================
	# EDITOR EVENTS
	# ===========================================================================

	## Workspace editor selected a file for display.
	signal editor_file_selected(path: String)
	## Workspace editor created a file.
	signal editor_file_created(path: String)
	## Workspace editor deleted a file.
	signal editor_file_deleted(path: String)
	## Workspace editor directory contents changed.
	signal editor_files_changed(parent_path: String)

	pass
