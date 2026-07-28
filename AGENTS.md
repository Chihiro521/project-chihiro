# Project Codex Instructions

## Godot runtime

- Use the user's standalone Godot 4.7.1 console executable for all CLI work:
  `D:\godot\引擎版本\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe`
- Use the sibling `Godot_v4.7.1-stable_win64.exe` only when the graphical editor is required.
- Never invoke the `godot` Scoop shim or anything under `D:\Dev\Tools\Scoop\apps\godot` for this project.
- Every command that executes Godot must run with `sandbox_permissions: "require_escalated"`. Godot writes editor and project data outside the workspace; running it in the restricted sandbox triggers a native access violation at shutdown (`read 0x58`, RVA `0x3E15854`).
- Pass an explicit project path and workspace log path. Logs are ignored by Git. The standard test command is:
  `& 'D:\godot\引擎版本\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe' --headless --path 'D:\workspace\project-chihiro' --log-file 'D:\workspace\project-chihiro\godot-tests.log' --script res://scripts/tests/run_tests.gd`
- Do not change project code or Godot settings to work around this permissions-only crash.
