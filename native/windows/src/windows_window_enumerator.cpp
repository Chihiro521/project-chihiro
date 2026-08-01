#include "windows_window_enumerator.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/rect2i.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dwmapi.h>

#include <cstdint>
#include <string>
#include <vector>

namespace godot {
namespace {

struct EnumerationContext {
	Array snapshots;
	int32_t max_count = 0;
	int32_t z_order = 0;
	bool include_titles = true;
};

String from_wide(const std::wstring &value) {
	if (value.empty()) {
		return String();
	}
	return String::utf16(reinterpret_cast<const char16_t *>(value.data()), static_cast<int64_t>(value.size()));
}

std::wstring to_wide(const String &value) {
	const Char16String utf16 = value.utf16();
	return std::wstring(
			reinterpret_cast<const wchar_t *>(utf16.get_data()),
			static_cast<size_t>(utf16.length()));
}

std::wstring window_title(HWND window) {
	const int length = GetWindowTextLengthW(window);
	if (length <= 0) {
		return std::wstring();
	}
	std::vector<wchar_t> buffer(static_cast<size_t>(length) + 1, L'\0');
	const int written = GetWindowTextW(window, buffer.data(), static_cast<int>(buffer.size()));
	return written > 0 ? std::wstring(buffer.data(), static_cast<size_t>(written)) : std::wstring();
}

std::wstring window_class(HWND window) {
	std::vector<wchar_t> buffer(256, L'\0');
	const int written = GetClassNameW(window, buffer.data(), static_cast<int>(buffer.size()));
	return written > 0 ? std::wstring(buffer.data(), static_cast<size_t>(written)) : std::wstring();
}

std::wstring process_name(DWORD process_id) {
	HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process_id);
	if (process == nullptr) {
		return std::wstring();
	}
	std::vector<wchar_t> path(32768, L'\0');
	DWORD size = static_cast<DWORD>(path.size());
	const BOOL ok = QueryFullProcessImageNameW(process, 0, path.data(), &size);
	CloseHandle(process);
	if (!ok || size == 0) {
		return std::wstring();
	}
	std::wstring full_path(path.data(), static_cast<size_t>(size));
	const size_t separator = full_path.find_last_of(L"\\/");
	return separator == std::wstring::npos ? full_path : full_path.substr(separator + 1);
}

RECT extended_window_rect(HWND window) {
	RECT rect{};
	if (FAILED(DwmGetWindowAttribute(window, DWMWA_EXTENDED_FRAME_BOUNDS, &rect, sizeof(rect)))) {
		GetWindowRect(window, &rect);
	}
	return rect;
}

bool is_cloaked(HWND window) {
	DWORD cloaked = 0;
	return SUCCEEDED(DwmGetWindowAttribute(window, DWMWA_CLOAKED, &cloaked, sizeof(cloaked))) && cloaked != 0;
}

bool is_shell_class(const std::wstring &class_name) {
	return _wcsicmp(class_name.c_str(), L"Progman") == 0 ||
			_wcsicmp(class_name.c_str(), L"WorkerW") == 0 ||
			_wcsicmp(class_name.c_str(), L"Shell_TrayWnd") == 0 ||
			_wcsicmp(class_name.c_str(), L"Shell_SecondaryTrayWnd") == 0;
}

Dictionary make_snapshot(HWND window, int32_t z_order, bool include_title) {
	Dictionary snapshot;
	if (window == nullptr || !IsWindow(window)) {
		return snapshot;
	}

	DWORD process_id = 0;
	GetWindowThreadProcessId(window, &process_id);
	const RECT rect = extended_window_rect(window);
	const std::wstring class_name = window_class(window);
	const LONG_PTR extended_style = GetWindowLongPtrW(window, GWL_EXSTYLE);

	snapshot["handle"] = static_cast<int64_t>(reinterpret_cast<intptr_t>(window));
	snapshot["rect"] = Rect2i(
			Vector2i(rect.left, rect.top),
			Vector2i(rect.right - rect.left, rect.bottom - rect.top));
	snapshot["z_order"] = z_order;
	snapshot["title"] = include_title ? from_wide(window_title(window)) : String();
	snapshot["process_name"] = from_wide(process_name(process_id));
	snapshot["process_id"] = static_cast<int64_t>(process_id);
	snapshot["class_name"] = from_wide(class_name);
	snapshot["visible"] = IsWindowVisible(window) != FALSE;
	snapshot["minimized"] = IsIconic(window) != FALSE;
	snapshot["maximized"] = IsZoomed(window) != FALSE;
	snapshot["cloaked"] = is_cloaked(window);
	snapshot["shell_window"] = window == GetShellWindow() || is_shell_class(class_name);
	snapshot["tool_window"] = (extended_style & WS_EX_TOOLWINDOW) != 0;
	snapshot["owner_handle"] = static_cast<int64_t>(reinterpret_cast<intptr_t>(GetWindow(window, GW_OWNER)));
	return snapshot;
}

BOOL CALLBACK collect_window(HWND window, LPARAM user_data) {
	auto *context = reinterpret_cast<EnumerationContext *>(user_data);
	if (context->max_count > 0 && context->snapshots.size() >= context->max_count) {
		return FALSE;
	}
	const int32_t z_order = context->z_order;
	context->z_order += 1;
	if (window == nullptr || !IsWindow(window) || !IsWindowVisible(window) || IsIconic(window) || is_cloaked(window)) {
		return TRUE;
	}
	DWORD process_id = 0;
	GetWindowThreadProcessId(window, &process_id);
	if (process_id == ::GetCurrentProcessId()) {
		return TRUE;
	}
	const RECT rect = extended_window_rect(window);
	if (rect.right <= rect.left || rect.bottom <= rect.top) {
		return TRUE;
	}
	const std::wstring class_name = window_class(window);
	if (window == GetShellWindow() || is_shell_class(class_name)) {
		return TRUE;
	}
	Dictionary snapshot = make_snapshot(window, z_order, context->include_titles);
	if (!snapshot.is_empty()) {
		context->snapshots.push_back(snapshot);
	}
	return TRUE;
}

} // namespace

void WindowsWindowEnumerator::_bind_methods() {
	ClassDB::bind_method(D_METHOD("enumerate_windows", "max_count", "include_titles"), &WindowsWindowEnumerator::enumerate_windows, DEFVAL(0), DEFVAL(true));
	ClassDB::bind_method(D_METHOD("get_window_snapshot", "handle", "include_title"), &WindowsWindowEnumerator::get_window_snapshot, DEFVAL(true));
	ClassDB::bind_method(D_METHOD("get_foreground_window_snapshot", "include_title"), &WindowsWindowEnumerator::get_foreground_window_snapshot, DEFVAL(true));
	ClassDB::bind_method(D_METHOD("get_current_process_id"), &WindowsWindowEnumerator::get_current_process_id);
	ClassDB::bind_method(D_METHOD("set_window_rect", "handle", "x", "y", "width", "height"), &WindowsWindowEnumerator::set_window_rect);
	ClassDB::bind_method(D_METHOD("atomic_replace_file", "temporary_path", "target_path"), &WindowsWindowEnumerator::atomic_replace_file);
}

Array WindowsWindowEnumerator::enumerate_windows(int32_t max_count, bool include_titles) const {
	EnumerationContext context;
	context.max_count = max_count > 0 ? max_count : 0;
	context.include_titles = include_titles;
	EnumWindows(collect_window, reinterpret_cast<LPARAM>(&context));
	return context.snapshots;
}

Dictionary WindowsWindowEnumerator::get_window_snapshot(int64_t handle, bool include_title) const {
	HWND window = reinterpret_cast<HWND>(static_cast<intptr_t>(handle));
	return make_snapshot(window, 0, include_title);
}

Dictionary WindowsWindowEnumerator::get_foreground_window_snapshot(bool include_title) const {
	return make_snapshot(GetForegroundWindow(), 0, include_title);
}

int64_t WindowsWindowEnumerator::get_current_process_id() const {
	return static_cast<int64_t>(::GetCurrentProcessId());
}

bool WindowsWindowEnumerator::set_window_rect(int64_t handle, int32_t x, int32_t y, int32_t width, int32_t height) const {
	HWND window = reinterpret_cast<HWND>(static_cast<intptr_t>(handle));
	if (window == nullptr || !IsWindow(window) || width <= 0 || height <= 0) {
		return false;
	}
	return SetWindowPos(
			window,
			nullptr,
			x,
			y,
			width,
			height,
			SWP_NOACTIVATE | SWP_NOOWNERZORDER | SWP_NOZORDER) != FALSE;
}

bool WindowsWindowEnumerator::atomic_replace_file(const String &temporary_path, const String &target_path) const {
	const std::wstring temporary = to_wide(temporary_path);
	const std::wstring target = to_wide(target_path);
	if (temporary.empty() || target.empty()) {
		return false;
	}
	return MoveFileExW(
			temporary.c_str(),
			target.c_str(),
			MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != FALSE;
}

} // namespace godot
