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
	bool atomic_replace_file(const String &temporary_path, const String &target_path) const;
};

} // namespace godot

#endif // LITTLE_CHIHIRO_WINDOWS_WINDOW_ENUMERATOR_H
