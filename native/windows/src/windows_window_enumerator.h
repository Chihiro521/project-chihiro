#ifndef LITTLE_CHIHIRO_WINDOWS_WINDOW_ENUMERATOR_H
#define LITTLE_CHIHIRO_WINDOWS_WINDOW_ENUMERATOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstdint>

namespace godot {

class WindowsWindowEnumerator : public RefCounted {
	GDCLASS(WindowsWindowEnumerator, RefCounted)

protected:
	static void _bind_methods();

public:
	Array enumerate_windows(int32_t max_count = 0, bool include_titles = true) const;
	Dictionary get_window_snapshot(int64_t handle, bool include_title = true) const;
	Dictionary get_foreground_window_snapshot(bool include_title = true) const;
	int64_t get_current_process_id() const;
	bool set_window_rect(int64_t handle, int32_t x, int32_t y, int32_t width, int32_t height) const;
	bool atomic_replace_file(const String &temporary_path, const String &target_path) const;

	// SetWinEventHook machinery. The worker thread only flips atomics; the
	// GDScript side polls consume_dirty_flag()/get_dirty_handle() each frame.
	bool start_event_hook();
	void stop_event_hook();
	bool is_event_hook_active() const;
	bool consume_dirty_flag();
	int64_t get_dirty_handle() const;
	void set_event_hook_tracked_handles(const Array &handles);
};

// Join-safe shutdown for module unload; joins the hook worker before its
// std::thread state is destroyed.
void stop_window_event_hook_global();

} // namespace godot

#endif // LITTLE_CHIHIRO_WINDOWS_WINDOW_ENUMERATOR_H
