# Windows window-platform GDExtension

This Windows x64 extension exposes top-level window snapshots and an atomic file
replacement primitive to Godot. The GDScript platform service remains testable
with injected snapshots when the DLL is absent.

## Interface

The extension registers `WindowsWindowEnumerator`:

- `enumerate_windows(max_count := 0, include_titles := true) -> Array[Dictionary]`
  enumerates relevant HWNDs in front-to-back z order.
- `get_window_snapshot(handle: int, include_title := true) -> Dictionary`
  refreshes one HWND.
- `get_foreground_window_snapshot(include_title := true) -> Dictionary` uses
  the actual Win32 foreground HWND.
- `get_current_process_id() -> int` lets the Godot service exclude this pet.
- `set_window_rect(handle, x, y, width, height) -> bool` applies position and
  size through one Win32 `SetWindowPos` call so transparent-window resizing
  never exposes a half-updated rectangle.
- `atomic_replace_file(temporary_path, target_path) -> bool` uses
  `MoveFileExW(..., MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)`.

Each snapshot contains `handle`, `rect`, `z_order`, `title`, `process_name`,
`process_id`, `class_name`, `visible`, `minimized`, `maximized`, `cloaked`,
`shell_window`, `tool_window`, and `owner_handle`. Coordinates are physical
virtual-desktop coordinates and may be negative on secondary monitors.

## Build prerequisites

- Windows 11 x64
- Godot 4.7.1 x64
- Visual Studio 2022 Build Tools with the Desktop development with C++ workload
- `uv` (the build script runs SCons through `uvx`)
- The pinned official `godot-cpp` Git submodule

Initialize the fixed submodule after cloning:

```powershell
git submodule update --init --recursive
```

Build both targets with the repository script. It generates `extension_api.json`
from the installed Godot 4.7.1 binary when needed:

```powershell
& 'D:\workspace\project-chihiro\native\windows\build.ps1' -Target template_debug
& 'D:\workspace\project-chihiro\native\windows\build.ps1' -Target template_release
```

The expected outputs are:

```text
bin/little_chihiro_windows.windows.template_debug.x86_64.dll
bin/little_chihiro_windows.windows.template_release.x86_64.dll
```

After the DLL is present, Godot discovers `little_chihiro_windows.gdextension`
and `WindowPlatformService.new()` creates the native bridge automatically.
Call `refresh()` around every 500 ms for a capped 12-window z-order snapshot. Between
those refreshes, `track_platform()` uses `get_window_snapshot()` so a ridden
HWND can be followed at 30 Hz without re-enumerating the desktop each frame.
