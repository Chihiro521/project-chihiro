class_name PetSfxPlayer
extends Node

const PATHS := {
	"bubble": "res://assets/sfx/bubble.ogg",
	"step": "res://assets/sfx/step.ogg",
	"cloth": "res://assets/sfx/cloth.ogg",
	"bag": "res://assets/sfx/bag.ogg",
	"sit": "res://assets/sfx/sit.ogg",
	"land": "res://assets/sfx/land.ogg",
	"umbrella_open": "res://assets/sfx/umbrella_open.ogg",
	"umbrella_close": "res://assets/sfx/umbrella_close.ogg",
	"window_hop": "res://assets/sfx/window_hop.ogg",
}

var enabled := true
var volume := 0.72
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player := 0

func _ready() -> void:
	for index in range(3):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		add_child(player)
		_players.append(player)

func configure(next_enabled: bool, next_volume: float) -> void:
	enabled = next_enabled
	volume = clampf(next_volume, 0.0, 1.0)

func play(name: String, pitch_variation := 0.035) -> bool:
	if not enabled or _players.is_empty() or not PATHS.has(name):
		return false
	var stream := _stream(name)
	if stream == null:
		return false
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.001, volume))
	player.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
	player.play()
	return true

func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := str(PATHS[name])
	if not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path, "AudioStream")
	if resource is AudioStream:
		_streams[name] = resource
		return resource
	return null
