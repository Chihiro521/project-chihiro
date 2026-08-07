class_name PetOffscreenMarker
extends Window

## Small top-edge marker shown while the pet is flung above the visible screen:
## an up-pointing arrow + the pet's head avatar, so the player can find the pet.

const SIZE := Vector2i(72, 92)
const COLOR_ARROW := Color("#c87539")
const EDGE_GAP := 6.0

var _surface: Control
var _avatar: TextureRect
var _arrow: Polygon2D


func _init() -> void:
	visible = false
	force_native = true
	transparent = true
	mouse_passthrough = true


func _ready() -> void:
	title = "千寻离屏标记"
	transparent_bg = true
	borderless = true
	always_on_top = true
	unfocusable = true
	min_size = SIZE
	max_size = SIZE
	size = SIZE
	_build_surface()
	hide()


func set_avatar_texture(texture: Texture2D) -> void:
	if _avatar != null and texture != null:
		_avatar.texture = texture


func update_marker(pet_x: float, screen: Rect2, pet_offscreen: bool) -> void:
	if not pet_offscreen:
		if visible:
			hide()
		return
	if not visible:
		show()
	var clamped_x := clampf(pet_x - SIZE.x * 0.5, screen.position.x + EDGE_GAP, screen.end.x - SIZE.x - EDGE_GAP)
	position = Vector2i(roundi(clamped_x), roundi(screen.position.y + EDGE_GAP))


func _build_surface() -> void:
	_surface = Control.new()
	_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	_avatar = TextureRect.new()
	_avatar.position = Vector2(12, 8)
	_avatar.size = Vector2(48, 48)
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_surface.add_child(_avatar)
	_arrow = Polygon2D.new()
	_arrow.polygon = PackedVector2Array([
		Vector2(24, 84), Vector2(48, 84), Vector2(36, 60),
	])
	_arrow.color = COLOR_ARROW
	_surface.add_child(_arrow)
