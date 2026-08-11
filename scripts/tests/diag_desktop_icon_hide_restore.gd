extends SceneTree

## Diagnostic: verify the desktop-icon hide/restore round-trip against the real
## Explorer SysListView32. Hides the first rendered icon via the shell's
## SHCNE_DELETE notification, polls until it is gone (desktop_icon_present),
## brings it back (light SHChangeNotify refresh in pass A, forced SSF_HIDEICONS
## toggle in pass B), polls until it is back, restores its exact position, and
## asserts the explorer PID never changed
## (i.e. explorer did not crash and restart mid-test).
##
## Run with the pet CLOSED (the pet and this diag would fight over the ListView):
##   godot --headless --path . --script res://scripts/tests/diag_desktop_icon_hide_restore.gd

class Poller extends Node:
	var bridge: Variant = null
	var pass_idx := 0                # 0 = light refresh, 1 = force fallback
	var icon_name := ""
	var icon_x := 0
	var icon_y := 0
	var pid := 0
	var state := "start"         # start → hide → wait_gone → restore → wait_back → done
	var next_ms := 0
	var deadline_ms := 0
	var started_ms := 0
	var failed := false

	const STEP_MS := 150.0
	const TIMEOUT_MS := 20000.0

	func _process(_delta: float) -> void:
		var now := Time.get_ticks_msec()
		if now < next_ms:
			return
		next_ms = now + STEP_MS
		if bridge == null:
			get_tree().quit(1)
			return
		if not bridge.desktop_listview_available():
			# Transient unavailability at boot is fine; only give up after a timeout.
			if started_ms == 0:
				started_ms = now
				return
			if now - started_ms < TIMEOUT_MS:
				return
			print("FAIL: desktop ListView never became available")
			_fail()
			return
		match state:
			"start":
				_start_pass()
			"hide":
				_hide_icon()
			"wait_gone":
				_wait_gone()
			"restore":
				_restore_icon()
			"wait_back":
				_wait_back()
			"done":
				_done_pass()

	func _start_pass() -> void:
		started_ms = 0
		var items: Array = bridge.enumerate_desktop_icons()
		if items.is_empty():
			print("FAIL: no desktop icons enumerated")
			_fail()
			return
		var item: Dictionary = items[0]
		icon_name = str(item.get("name", ""))
		icon_x = int(item.get("x", 0))
		icon_y = int(item.get("y", 0))
		pid = int(bridge.desktop_explorer_process_id())
		print("[pass_idx %d] target '%s' at (%d, %d)   explorer pid=%d" % [pass_idx + 1, icon_name, icon_x, icon_y, pid])
		if pid <= 0:
			print("FAIL: could not resolve explorer pid")
			_fail()
			return
		state = "hide"

	func _hide_icon() -> void:
		if not bridge.hide_desktop_icon(icon_name):
			print("FAIL: hide_desktop_icon returned false for '%s'" % icon_name)
			_fail()
			return
		print("[pass_idx %d] hidden '%s'" % [pass_idx + 1, icon_name])
		deadline_ms = Time.get_ticks_msec() + TIMEOUT_MS
		state = "wait_gone"

	func _wait_gone() -> void:
		if not bridge.desktop_icon_present(icon_name):
			print("[pass_idx %d] confirmed gone after %.1fs" % [pass_idx + 1, (Time.get_ticks_msec() - (deadline_ms - TIMEOUT_MS)) / 1000.0])
			state = "restore"
			return
		if Time.get_ticks_msec() > deadline_ms:
			print("FAIL: icon still present after hide timeout")
			_fail()

	func _restore_icon() -> void:
		if pass_idx == 0:
			bridge.refresh_desktop_icons()
			print("[pass_idx 1] issued light refresh (SHChangeNotify)")
		else:
			bridge.force_desktop_icon_refresh()
			print("[pass_idx 2] issued force refresh (SSF_HIDEICONS toggle)")
		deadline_ms = Time.get_ticks_msec() + TIMEOUT_MS
		state = "wait_back"

	func _wait_back() -> void:
		if bridge.desktop_icon_present(icon_name):
			print("[pass_idx %d] '%s' reappeared after %.1fs" % [pass_idx + 1, icon_name, (Time.get_ticks_msec() - (deadline_ms - TIMEOUT_MS)) / 1000.0])
			if not bridge.set_desktop_icon_position(icon_name, icon_x, icon_y):
				print("WARN: set_desktop_icon_position returned false")
			state = "done"
			return
		if Time.get_ticks_msec() > deadline_ms:
			print("FAIL: icon did not reappear after restore (pass_idx %d)" % (pass_idx + 1))
			_fail()

	func _done_pass() -> void:
		var pid_now := int(bridge.desktop_explorer_process_id())
		if pid_now != pid:
			print("FAIL: explorer pid changed %d -> %d (explorer crashed and restarted?)" % [pid, pid_now])
			_fail()
			return
		print("[pass_idx %d] OK   pid stable=%d   ListView still usable" % [pass_idx + 1, pid_now])
		pass_idx += 1
		if pass_idx < 2:
			state = "start"
		else:
			print("DIAG PASSED: hide/restore round-trip works on both paths; explorer pid stable")
			get_tree().quit(0)

	func _fail() -> void:
		if failed:
			return
		failed = true
		if icon_name != "" and bridge != null:
			# Best effort so a mid-test failure never leaves the desktop missing an icon.
			print("best-effort restore issued (force refresh)")
			bridge.force_desktop_icon_refresh()
		get_tree().quit(1)

func _initialize() -> void:
	var bridge: Variant = null
	if ClassDB.class_exists("WindowsWindowEnumerator"):
		bridge = ClassDB.instantiate("WindowsWindowEnumerator")
	if bridge == null:
		print("FAIL: WindowsWindowEnumerator class is MISSING (editor/headless not using the template_debug DLL?)")
		quit(1)
		return
	print("native bridge OK; waiting for the desktop ListView to be ready...")
	var poller := Poller.new()
	poller.bridge = bridge
	root.add_child(poller)
