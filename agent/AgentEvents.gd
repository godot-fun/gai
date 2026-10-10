class_name AgentEvents
extends RefCounted

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

	# Session management
	signal session_added(session_id: int, title: String)
	signal session_removed(session_id: int)
	signal session_selected(session_id: int, previous_session_id: int)
	signal session_title_changed(session_id: int, title: String)
	signal session_resume(session_id: int)
	signal session_stop(session_id: int)
	## Pending user messages changed for one session.
	signal session_queue_changed(session_id: int)

	# Workspace
	## Workspace root switched (see [method AgentWorkspace.set_root]) — sessions and file
	## paths now resolve under the new root, so listeners reload their state.
	signal workspace_changed(path: String)

	# UI configuration
	signal chat_entry_add(session_id: int, entry: ChatEntry)
	signal chat_entry_update(session_id: int, entry: ChatEntry, stream_kind: String)
	signal chat_entry_delete(session_id: int)
	## A search result requests that the transcript reveal a specific persisted entry.
	signal chat_search_result_selected(session_id: int, entry_index: int)
	## Emitted after ChatBubbleFlusher applies a pending batch (every ~100 ms while streaming).
	signal chat_bubble_flushed
	## A bubble handed its body back to the chat input (delete / revert) for re-editing.
	signal chat_input_prefill(text: String)
	## Markdown bubble rendering switched (see [method AgentSetting.set_markdown_enabled]).
	signal markdown_changed(enabled: bool)
	## Active run visual changed (see [method AgentSetting.set_visual_type]).
	signal visual_type_changed(visual_type: int)
	signal skill_context_changed(session_id: int)
	## AGENTS.md project prompt added to / removed from a session (see AgentPromptToggle).
	signal agent_context_changed(session_id: int)
	pass
