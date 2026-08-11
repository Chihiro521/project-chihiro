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
#include <commctrl.h>
#include <dwmapi.h>

#include <algorithm>
#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

namespace godot {
namespace {

struct EnumerationContext {
	Array snapshots;
	int32_t max_count = 0;
	int32_t z_order = 0;
	int32_t self_z_order = -1;
	bool include_titles = true;
};

// --- WinEventHook state ----------------------------------------------------
// The hook worker thread never touches Godot APIs: WinEventProc only flips
// atomics (plus the mutex-guarded tracked-handle set), so delivery under
// WINEVENT_OUTOFCONTEXT is safe on its own thread. The GDScript side polls
// consume_dirty_flag()/get_dirty_handle() every frame and debounces.
struct EventHookState {
	std::atomic<bool> dirty{false};
	std::atomic<int64_t> last_handle{0};
	std::atomic<bool> active{false};
	std::atomic<DWORD> worker_thread_id{0};
	std::thread worker;
	HWINEVENTHOOK hook = nullptr;
	std::mutex tracked_mutex;
	std::vector<int64_t> tracked;
};
static EventHookState g_event_hook;

void CALLBACK win_event_proc(
		HWINEVENTHOOK hook,
		DWORD event,
		HWND window,
		LONG id_object,
		LONG id_child,
		DWORD event_thread,
		DWORD event_time) {
	(void)hook;
	(void)event;
	(void)event_thread;
	(void)event_time;
	if (id_object != OBJID_WINDOW || id_child != CHILDID_SELF) {
		return;
	}
	if (window == nullptr || !IsWindow(window)) {
		return;
	}
	if (GetAncestor(window, GA_ROOT) != window) {
		return; // only top-level windows matter to the pet world
	}
	const int64_t handle = static_cast<int64_t>(reinterpret_cast<intptr_t>(window));
	{
		std::lock_guard<std::mutex> lock(g_event_hook.tracked_mutex);
		if (!g_event_hook.tracked.empty()) {
			bool relevant = false;
			for (const int64_t candidate : g_event_hook.tracked) {
				if (candidate == handle) {
					relevant = true;
					break;
				}
			}
			if (!relevant) {
				return;
			}
		}
	}
	g_event_hook.last_handle = handle;
	g_event_hook.dirty = true;
}

void event_hook_worker() {
	// Register the thread id before installing the hook so stop_event_hook() can
	// always wake us with PostThreadMessageW even if SetWinEventHook stalls.
	g_event_hook.worker_thread_id = GetCurrentThreadId();
	g_event_hook.hook = SetWinEventHook(
			EVENT_OBJECT_CREATE,
			EVENT_OBJECT_UNCLOAKED,
			nullptr,
			win_event_proc,
			0,
			0,
			WINEVENT_OUTOFCONTEXT);
	if (g_event_hook.hook == nullptr) {
		g_event_hook.active = false;
		return;
	}
	g_event_hook.active = true;
	MSG message;
	while (GetMessageW(&message, nullptr, 0, 0) > 0) {
		if (message.message == WM_APP) {
			break;
		}
		TranslateMessage(&message);
		DispatchMessageW(&message);
	}
	UnhookWinEvent(g_event_hook.hook);
	g_event_hook.hook = nullptr;
	g_event_hook.active = false;
}

// Wakes and joins the worker thread (up to ~200ms if the thread is still
// starting). Safe to call when no hook is running.
void shutdown_hook_worker() {
	for (int attempt = 0; attempt < 200 && g_event_hook.worker_thread_id.load() == 0; ++attempt) {
		Sleep(1);
	}
	const DWORD thread_id = g_event_hook.worker_thread_id.exchange(0);
	if (thread_id != 0) {
		PostThreadMessageW(thread_id, WM_APP, 0, 0);
	}
	if (g_event_hook.worker.joinable()) {
		g_event_hook.worker.join();
	}
}

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
		// The pet's own always-on-top window is enumerated topmost; capture its
		// z-order as the occlusion threshold. first-hit-wins: the topmost
		// own-process window is the pet; later own windows never overwrite it.
		if (context->self_z_order < 0) {
			context->self_z_order = z_order;
		}
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

// --- Cursor capture (WH_MOUSE_LL) ------------------------------------------
// Absolute mouse takeover for the cursor-confiscation behavior. The low-level
// hook is only a conduit: it swallows every mouse event while the atomic
// `active` flag is set and passes everything through otherwise. That flag is
// the real gate, so even a forgotten UnhookWindowsHookEx can never lock the
// user's mouse — the moment active clears, input flows again.
struct CursorCaptureState {
	std::atomic<bool> active{false};
	std::atomic<bool> installed{false};
	std::atomic<DWORD> worker_thread_id{0};
	std::thread worker;
	HHOOK hook = nullptr;
};
static CursorCaptureState g_cursor_capture;

LRESULT CALLBACK mouse_hook_proc(int n_code, WPARAM w_param, LPARAM l_param) {
	if (n_code >= 0 && g_cursor_capture.active.load()) {
		// Swallow every mouse event during confiscation: moves, buttons, wheel.
		return 1;
	}
	return CallNextHookEx(nullptr, n_code, w_param, l_param);
}

void cursor_capture_worker() {
	g_cursor_capture.worker_thread_id = GetCurrentThreadId();
	// lpfn lives in this DLL, which is loaded into the Godot process, so the
	// hook can be installed with hMod = NULL (the documented in-process form).
	g_cursor_capture.hook = SetWindowsHookExW(WH_MOUSE_LL, mouse_hook_proc, nullptr, 0);
	if (g_cursor_capture.hook == nullptr) {
		g_cursor_capture.installed = false;
		g_cursor_capture.worker_thread_id = 0;
		return;
	}
	g_cursor_capture.installed = true;
	MSG message;
	while (GetMessageW(&message, nullptr, 0, 0) > 0) {
		if (message.message == WM_APP) {
			break;
		}
		TranslateMessage(&message);
		DispatchMessageW(&message);
	}
	UnhookWindowsHookEx(g_cursor_capture.hook);
	g_cursor_capture.hook = nullptr;
	g_cursor_capture.installed = false;
}

void shutdown_cursor_capture_worker() {
	for (int attempt = 0; attempt < 200 && g_cursor_capture.worker_thread_id.load() == 0; ++attempt) {
		Sleep(1);
	}
	const DWORD thread_id = g_cursor_capture.worker_thread_id.exchange(0);
	if (thread_id != 0) {
		PostThreadMessageW(thread_id, WM_APP, 0, 0);
	}
	if (g_cursor_capture.worker.joinable()) {
		g_cursor_capture.worker.join();
	}
	g_cursor_capture.active = false;
}

// --- Desktop icons (Explorer SysListView32) --------------------------------
// The desktop's icon list is the SysListView32 control under the shell's
// DefView (Progman, or a WorkerW on Windows 11). Icons are moved with
// LVM_SETITEMPOSITION only — never deleted, so the .lnk/files stay intact and
// every move is reversible.

HWND desktop_def_view() {
	// Only follow the Progman branch when Progman actually exists. Falling back
	// to an unscoped top-level FindWindowExW here can match an unrelated
	// Explorer window's SHELLDLL_DefView, whose SysListView32 is a *file list*,
	// not the desktop — moving icons there would corrupt a normal window.
	HWND progman = FindWindowW(L"Progman", nullptr);
	HWND def_view = nullptr;
	if (progman != nullptr) {
		def_view = FindWindowExW(progman, nullptr, L"SHELLDLL_DefView", nullptr);
	}
	if (def_view != nullptr) {
		return def_view;
	}
	struct WorkerSearch {
		HWND found = nullptr;
	};
	WorkerSearch search;
	EnumWindows([](HWND top, LPARAM user_data) -> BOOL {
		auto *state = reinterpret_cast<WorkerSearch *>(user_data);
		wchar_t class_name[64] = {};
		if (GetClassNameW(top, class_name, 64) > 0 && _wcsicmp(class_name, L"WorkerW") == 0) {
			HWND def = FindWindowExW(top, nullptr, L"SHELLDLL_DefView", nullptr);
			if (def != nullptr) {
				state->found = def;
				return FALSE;
			}
		}
		return TRUE;
	}, reinterpret_cast<LPARAM>(&search));
	return search.found;
}

HWND desktop_list_view() {
	HWND def_view = desktop_def_view();
	if (def_view == nullptr) {
		return nullptr;
	}
	return FindWindowExW(def_view, nullptr, L"SysListView32", nullptr);
}

POINT desktop_listview_screen_origin(HWND list_view) {
	POINT origin = {0, 0};
	if (list_view != nullptr) {
		ClientToScreen(list_view, &origin);
	}
	return origin;
}

// --- Desktop icon names + positions via remote buffers ---------------------
// The desktop icon list is the SysListView32 under the shell's DefView. Its
// comctl32 handlers for LVM_GETITEMTEXTW and LVM_GETITEMPOSITION write to the
// pointer carried in the message; when that address is unmapped in explorer's
// process the write faults and takes Explorer.EXE down (faulting module
// comctl32.dll, reproduced on Win11 26100 / comctl32 6.10.26100.8875). So no
// message may carry a pointer into our address space.
//
// Instead the LVITEM, its text buffer and the POINT array are all allocated
// inside explorer's own process (VirtualAllocEx) and the results are copied
// back with ReadProcessMemory. Reading names this way is also authoritative:
// we get exactly the display names the desktop shows (微信, not 微信.lnk) and
// each name stays aligned with its own position by construction — no shell
// namespace, no sort-order guessing. Writes (LVM_SETITEMPOSITION) carry pure
// scalars and remain safe on their own.
class DesktopListViewReader {
public:
	std::vector<std::wstring> names;
	std::vector<POINT> positions;
	bool ok = false;

	DesktopListViewReader(HWND list_view) {
		if (list_view == nullptr) {
			return;
		}
		const int count = static_cast<int>(SendMessageW(list_view, LVM_GETITEMCOUNT, 0, 0));
		if (count <= 0) {
			return;
		}
		DWORD pid = 0;
		GetWindowThreadProcessId(list_view, &pid);
		if (pid == 0) {
			return;
		}
		HANDLE process = OpenProcess(PROCESS_VM_OPERATION | PROCESS_VM_READ | PROCESS_VM_WRITE | PROCESS_QUERY_INFORMATION, FALSE, pid);
		if (process == nullptr) {
			return;
		}
		constexpr int TEXT_MAX = 512;
		const SIZE_T lvitem_bytes = sizeof(LVITEMW);
		const SIZE_T text_bytes = static_cast<SIZE_T>(TEXT_MAX) * sizeof(wchar_t);
		const SIZE_T pos_bytes = static_cast<SIZE_T>(count) * sizeof(POINT);
		BYTE *remote = static_cast<BYTE *>(VirtualAllocEx(process, nullptr, lvitem_bytes + text_bytes + pos_bytes, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE));
		if (remote == nullptr) {
			CloseHandle(process);
			return;
		}
		LVITEMW *remote_lvitem = reinterpret_cast<LVITEMW *>(remote);
		wchar_t *remote_text = reinterpret_cast<wchar_t *>(remote + lvitem_bytes);
		POINT *remote_pos = reinterpret_cast<POINT *>(remote + lvitem_bytes + text_bytes);

		LVITEMW stub = {};
		stub.iSubItem = 0;
		stub.cchTextMax = TEXT_MAX;
		stub.pszText = remote_text;
		WriteProcessMemory(process, remote_lvitem, &stub, sizeof(stub), nullptr);

		names.assign(static_cast<size_t>(count), std::wstring());
		positions.assign(static_cast<size_t>(count), POINT{0, 0});

		std::vector<wchar_t> text_local(TEXT_MAX, L'\0');
		bool text_ok = true;
		for (int index = 0; index < count; ++index) {
			SendMessageW(list_view, LVM_GETITEMTEXTW, static_cast<WPARAM>(index), reinterpret_cast<LPARAM>(remote_lvitem));
			std::fill(text_local.begin(), text_local.end(), L'\0');
			SIZE_T read = 0;
			if (!ReadProcessMemory(process, remote_text, text_local.data(), text_bytes, &read)) {
				text_ok = false;
				break;
			}
			names[static_cast<size_t>(index)] = std::wstring(text_local.data());
		}

		bool pos_ok = false;
		if (text_ok) {
			for (int index = 0; index < count; ++index) {
				SendMessageW(list_view, LVM_GETITEMPOSITION, static_cast<WPARAM>(index), reinterpret_cast<LPARAM>(remote_pos + index));
			}
			SIZE_T read = 0;
			pos_ok = ReadProcessMemory(process, remote_pos, positions.data(), pos_bytes, &read) && read == pos_bytes;
		}

		VirtualFreeEx(process, remote, 0, MEM_RELEASE);
		CloseHandle(process);
		ok = text_ok && pos_ok;
	}
};

} // namespace

void WindowsWindowEnumerator::_bind_methods() {
	ClassDB::bind_method(D_METHOD("enumerate_windows", "max_count", "include_titles"), &WindowsWindowEnumerator::enumerate_windows, DEFVAL(0), DEFVAL(true));
	ClassDB::bind_method(D_METHOD("get_window_snapshot", "handle", "include_title"), &WindowsWindowEnumerator::get_window_snapshot, DEFVAL(true));
	ClassDB::bind_method(D_METHOD("get_foreground_window_snapshot", "include_title"), &WindowsWindowEnumerator::get_foreground_window_snapshot, DEFVAL(true));
	ClassDB::bind_method(D_METHOD("get_current_process_id"), &WindowsWindowEnumerator::get_current_process_id);
	ClassDB::bind_method(D_METHOD("get_self_window_z_order"), &WindowsWindowEnumerator::get_self_window_z_order);
	ClassDB::bind_method(D_METHOD("set_window_rect", "handle", "x", "y", "width", "height"), &WindowsWindowEnumerator::set_window_rect);
	ClassDB::bind_method(D_METHOD("atomic_replace_file", "temporary_path", "target_path"), &WindowsWindowEnumerator::atomic_replace_file);
	ClassDB::bind_method(D_METHOD("start_event_hook"), &WindowsWindowEnumerator::start_event_hook);
	ClassDB::bind_method(D_METHOD("stop_event_hook"), &WindowsWindowEnumerator::stop_event_hook);
	ClassDB::bind_method(D_METHOD("is_event_hook_active"), &WindowsWindowEnumerator::is_event_hook_active);
	ClassDB::bind_method(D_METHOD("consume_dirty_flag"), &WindowsWindowEnumerator::consume_dirty_flag);
	ClassDB::bind_method(D_METHOD("get_dirty_handle"), &WindowsWindowEnumerator::get_dirty_handle);
	ClassDB::bind_method(D_METHOD("set_event_hook_tracked_handles", "handles"), &WindowsWindowEnumerator::set_event_hook_tracked_handles);
	ClassDB::bind_method(D_METHOD("set_cursor_position", "x", "y"), &WindowsWindowEnumerator::set_cursor_position);
	ClassDB::bind_method(D_METHOD("set_cursor_visible", "visible"), &WindowsWindowEnumerator::set_cursor_visible);
	ClassDB::bind_method(D_METHOD("is_key_pressed", "vk"), &WindowsWindowEnumerator::is_key_pressed);
	ClassDB::bind_method(D_METHOD("start_cursor_capture"), &WindowsWindowEnumerator::start_cursor_capture);
	ClassDB::bind_method(D_METHOD("stop_cursor_capture"), &WindowsWindowEnumerator::stop_cursor_capture);
	ClassDB::bind_method(D_METHOD("is_cursor_capture_active"), &WindowsWindowEnumerator::is_cursor_capture_active);
	ClassDB::bind_method(D_METHOD("enumerate_desktop_icons"), &WindowsWindowEnumerator::enumerate_desktop_icons);
	ClassDB::bind_method(D_METHOD("set_desktop_icon_position", "name", "screen_x", "screen_y"), &WindowsWindowEnumerator::set_desktop_icon_position);
	ClassDB::bind_method(D_METHOD("desktop_listview_available"), &WindowsWindowEnumerator::desktop_listview_available);
}

Array WindowsWindowEnumerator::enumerate_windows(int32_t max_count, bool include_titles) const {
	EnumerationContext context;
	context.max_count = max_count > 0 ? max_count : 0;
	context.include_titles = include_titles;
	EnumWindows(collect_window, reinterpret_cast<LPARAM>(&context));
	self_z_order_ = context.self_z_order;
	return context.snapshots;
}

int32_t WindowsWindowEnumerator::get_self_window_z_order() const {
	return self_z_order_;
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

bool WindowsWindowEnumerator::start_event_hook() {
	if (g_event_hook.active.load()) {
		return true;
	}
	if (g_event_hook.worker.joinable()) {
		g_event_hook.worker.join();
	}
	g_event_hook.dirty = false;
	g_event_hook.last_handle = 0;
	g_event_hook.worker_thread_id = 0;
	g_event_hook.worker = std::thread(event_hook_worker);
	return true;
}

void WindowsWindowEnumerator::stop_event_hook() {
	shutdown_hook_worker();
	g_event_hook.dirty = false;
	g_event_hook.last_handle = 0;
}

bool WindowsWindowEnumerator::is_event_hook_active() const {
	return g_event_hook.active.load();
}

bool WindowsWindowEnumerator::consume_dirty_flag() {
	return g_event_hook.dirty.exchange(false);
}

int64_t WindowsWindowEnumerator::get_dirty_handle() const {
	return g_event_hook.last_handle.load();
}

void WindowsWindowEnumerator::set_event_hook_tracked_handles(const Array &handles) {
	std::lock_guard<std::mutex> lock(g_event_hook.tracked_mutex);
	g_event_hook.tracked.clear();
	g_event_hook.tracked.reserve(static_cast<size_t>(handles.size()));
	for (int64_t i = 0; i < handles.size(); ++i) {
		g_event_hook.tracked.push_back(static_cast<int64_t>(handles[i]));
	}
}

void WindowsWindowEnumerator::set_cursor_position(int32_t x, int32_t y) const {
	SetCursorPos(x, y);
}

void WindowsWindowEnumerator::set_cursor_visible(bool visible) const {
	// Force the system cursor's display counter negative/positive. Re-asserting
	// every frame is the caller's job (other apps may bump the counter back).
	if (visible) {
		while (ShowCursor(TRUE) < 0) {
		}
	} else {
		while (ShowCursor(FALSE) >= 0) {
		}
	}
}

bool WindowsWindowEnumerator::is_key_pressed(int32_t vk) const {
	return (GetAsyncKeyState(static_cast<int>(vk)) & 0x8000) != 0;
}

bool WindowsWindowEnumerator::start_cursor_capture() {
	if (g_cursor_capture.active.load()) {
		return true;
	}
	if (g_cursor_capture.worker.joinable()) {
		g_cursor_capture.worker.join();
	}
	if (!g_cursor_capture.installed.load()) {
		g_cursor_capture.worker_thread_id = 0;
		g_cursor_capture.worker = std::thread(cursor_capture_worker);
		for (int attempt = 0; attempt < 200 && !g_cursor_capture.installed.load(); ++attempt) {
			Sleep(1);
		}
		if (!g_cursor_capture.installed.load()) {
			return false;
		}
	}
	g_cursor_capture.active = true;
	return true;
}

void WindowsWindowEnumerator::stop_cursor_capture() {
	g_cursor_capture.active = false;
	shutdown_cursor_capture_worker();
}

bool WindowsWindowEnumerator::is_cursor_capture_active() const {
	return g_cursor_capture.active.load();
}

Array WindowsWindowEnumerator::enumerate_desktop_icons() const {
	Array result;
	HWND list_view = desktop_list_view();
	if (list_view == nullptr) {
		return result;
	}
	const POINT origin = desktop_listview_screen_origin(list_view);
	DesktopListViewReader reader(list_view);
	if (!reader.ok) {
		return result;
	}
	for (size_t index = 0; index < reader.names.size(); ++index) {
		const POINT position = reader.positions[index];
		if (position.x == 0 && position.y == 0) {
			continue; // slot never filled (icon removed mid-read)
		}
		Dictionary entry;
		entry["name"] = from_wide(reader.names[index]);
		entry["x"] = static_cast<int64_t>(position.x) + origin.x;
		entry["y"] = static_cast<int64_t>(position.y) + origin.y;
		result.push_back(entry);
	}
	return result;
}

bool WindowsWindowEnumerator::set_desktop_icon_position(const String &name, int32_t screen_x, int32_t screen_y) const {
	HWND list_view = desktop_list_view();
	if (list_view == nullptr) {
		return false;
	}
	const POINT origin = desktop_listview_screen_origin(list_view);
	const int client_x = screen_x - origin.x;
	const int client_y = screen_y - origin.y;
	DesktopListViewReader reader(list_view);
	if (!reader.ok) {
		return false;
	}
	const std::wstring target = to_wide(name);
	for (size_t index = 0; index < reader.names.size(); ++index) {
		if (_wcsicmp(reader.names[index].c_str(), target.c_str()) == 0) {
			return SendMessageW(list_view, LVM_SETITEMPOSITION, static_cast<WPARAM>(index), MAKELPARAM(client_x, client_y)) != FALSE;
		}
	}
	return false;
}

bool WindowsWindowEnumerator::desktop_listview_available() const {
	return desktop_list_view() != nullptr;
}

void stop_window_event_hook_global() {
	shutdown_hook_worker();
}

void stop_cursor_capture_global() {
	g_cursor_capture.active = false;
	shutdown_cursor_capture_worker();
}

} // namespace godot
