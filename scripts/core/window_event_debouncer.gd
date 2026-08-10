class_name WindowEventDebouncer
extends RefCounted

## Polls the native WinEventHook for desktop-window changes and schedules the
## caller's next full refresh. Events for the currently ridden window are
## ignored: the 33ms platform-track loop already follows it, so a full rebuild
## would be redundant. All native calls are guarded by has_method so a missing
## DLL degrades to the 500ms snapshot baseline without ever touching the hook.

const DEFAULT_DEBOUNCE_MS := 80.0

var debounce_ms := DEFAULT_DEBOUNCE_MS
var ridden_handle := 0

var _bridge: Variant = null
var _pending_deadline := INF


func set_bridge(bridge: Variant) -> void:
	_bridge = bridge


func set_ridden_handle(handle: int) -> void:
	ridden_handle = handle


## Returns the earliest wall-clock deadline for the caller's next refresh, or
## INF when nothing new happened. A pending deadline is sticky: repeated dirty
## polls before it fires keep returning the original deadline (debounce merge),
## so a drag flood collapses into one refresh. Call acknowledge() after the
## refresh has run.
func poll(now: float) -> float:
	if _pending_deadline != INF:
		return _pending_deadline
	if _bridge == null or not _bridge.has_method("consume_dirty_flag"):
		return INF
	if not bool(_bridge.call("consume_dirty_flag")):
		return INF
	var handle := ridden_handle
	if _bridge.has_method("get_dirty_handle"):
		handle = int(_bridge.call("get_dirty_handle"))
	if ridden_handle != 0 and handle == ridden_handle:
		return INF
	_pending_deadline = now + debounce_ms
	return _pending_deadline


## Clears the pending deadline after the caller rebuilt the window world.
func acknowledge() -> void:
	_pending_deadline = INF


func start_event_hook() -> void:
	if _bridge != null and _bridge.has_method("start_event_hook"):
		_bridge.call("start_event_hook")


func stop_event_hook() -> void:
	if _bridge != null and _bridge.has_method("stop_event_hook"):
		_bridge.call("stop_event_hook")
