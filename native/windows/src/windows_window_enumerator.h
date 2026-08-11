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
	int32_t get_self_window_z_order() const;
	bool set_window_rect(int64_t handle, int32_t x, int32_t y, int32_t width, int32_t height) const;
	bool atomic_replace_file(const String &temporary_path, const String &target_path) const;

	// Cursor confiscation ("绝对没收"). The WH_MOUSE_LL hook only swallows mouse
	// events while capture is active; a forgotten stop_cursor_capture() degrades
	// to pass-through, never a permanently trapped mouse.
	void set_cursor_position(int32_t x, int32_t y) const;
	void set_cursor_visible(bool visible) const;
	bool is_key_pressed(int32_t vk) const;
	bool start_cursor_capture();
	void stop_cursor_capture();
	bool is_cursor_capture_active() const;

	// Desktop icons (Explorer's SysListView32). Positions are in screen pixels
	// of the virtual desktop; underlying .lnk/files are never touched.
	Array enumerate_desktop_icons() const;
	bool set_desktop_icon_position(const String &name, int32_t screen_x, int32_t screen_y) const;
	bool desktop_listview_available() const;
	// LVM_GETITEMSPACING is a scalar message: it does not pass a pointer into
	// Explorer, so it is safe across the desktop ListView process boundary.
	Vector2i desktop_icon_spacing() const;

	// Hiding a desktop icon broadcasts SHCNE_DELETE for its desktop-namespace
	// pidl: the same notification explorer sends when a file is really deleted,
	// so the desktop view drops the icon while the .lnk and its saved position
	// stay intact on disk. Any shell refresh re-enumerates the namespace and
	// re-adds it at its original spot. refresh_desktop_icons() asks the shell to
	// re-enumerate (the light restore); force_desktop_icon_refresh() is the
	// guaranteed fallback (toggles "show desktop icons").
	bool hide_desktop_icon(const String &name) const;
	bool desktop_icon_present(const String &name) const;
	void refresh_desktop_icons() const;
	void force_desktop_icon_refresh() const;
	int64_t desktop_explorer_process_id() const;

	// SetWinEventHook machinery. The worker thread only flips atomics; the
	// GDScript side polls consume_dirty_flag()/get_dirty_handle() each frame.
	bool start_event_hook();
	void stop_event_hook();
	bool is_event_hook_active() const;
	bool consume_dirty_flag();
	int64_t get_dirty_handle() const;
	void set_event_hook_tracked_handles(const Array &handles);

private:
	// Z-order of the pet's own always-on-top window, captured by
	// enumerate_windows() (the topmost own-process window). Used as the
	// occlusion threshold: only windows in front of the pet (z < self_z)
	// truly cover its feet. Mutable because enumerate_windows() is const.
	mutable int32_t self_z_order_ = -1;
};

// Join-safe shutdown for module unload; joins the hook worker before its
// std::thread state is destroyed.
void stop_window_event_hook_global();
void stop_cursor_capture_global();

} // namespace godot

#endif // LITTLE_CHIHIRO_WINDOWS_WINDOW_ENUMERATOR_H
