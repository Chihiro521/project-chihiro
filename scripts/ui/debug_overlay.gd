class_name PetDebugOverlay
extends PanelContainer

@export var label_path := NodePath("Text")

var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = get_node(label_path) as Label
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color("#e8f2e8"))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.88)
	style.border_color = Color(0.35, 0.9, 0.65, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)
	visible = false

func set_snapshot(snapshot: Dictionary) -> void:
	if _label == null:
		return
	var lines: Array[String] = []
	for key in ["state", "intent", "clip", "platform"]:
		if snapshot.has(key):
			lines.append("%s: %s" % [key, str(snapshot[key])])
	var world: Dictionary = snapshot.get("world", {})
	if not world.is_empty():
		lines.append("world: %d plat · %d body · %d wall" % [
			int(world.get("platforms", 0)),
			int(world.get("bodies", 0)),
			int(world.get("walls", 0)),
		])
	var needs: Dictionary = snapshot.get("needs", {})
	if not needs.is_empty():
		lines.append("E %.1f  B %.1f  C %.1f  I %.1f  A %.1f" % [
			float(needs.get("energy", 0.0)),
			float(needs.get("boredom", 0.0)),
			float(needs.get("curiosity", 0.0)),
			float(needs.get("irritation", 0.0)),
			float(needs.get("affection", 0.0)),
		])
	var scores: Array = snapshot.get("scores", [])
	for score in scores.slice(0, mini(3, scores.size())):
		if score is Dictionary:
			lines.append("  %s  %.2f" % [str(score.get("id", "?")), float(score.get("score", 0.0))])
	var bubble: Dictionary = snapshot.get("bubble", {})
	var dialogue: Dictionary = snapshot.get("dialogue", {})
	lines.append("bubble: %s%s" % [
		"visible" if bool(bubble.get("visible", false)) else "hidden",
		" · %s" % str(bubble.get("id", "")) if not str(bubble.get("id", "")).is_empty() else "",
	])
	lines.append("talk in %.1fs · event %.1fs" % [
		float(dialogue.get("ambient_seconds", 0.0)),
		float(dialogue.get("event_cooldown_seconds", 0.0)),
	])
	_label.text = "\n".join(lines)

func toggle() -> void:
	visible = not visible
