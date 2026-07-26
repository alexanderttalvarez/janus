## AudioManager — Centralized audio control for music, SFX, and ambient sounds.
## Registered as autoload "AudioManager" in project settings.
##
## Responsibilities:
## - Play/stop music with crossfade
## - Play one-shot SFX
## - Volume control per bus (Master, Music, SFX, Ambient)
## - Volume persistence via SaveManager
##
## This autoload is process mode ALWAYS so audio continues while paused.
extends Node

## Emitted when a volume setting changes.
signal volume_changed(bus_name: String, volume: float)

## Audio bus names used by the game.
const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_AMBIENT := "Ambient"

## Currently playing music stream (for crossfade).
var _current_music_player: AudioStreamPlayer
var _next_music_player: AudioStreamPlayer

## Crossfade duration in seconds.
const CROSSFADE_DURATION := 2.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_music_players()


## Set up two AudioStreamPlayers for music crossfading.
func _setup_music_players() -> void:
	_current_music_player = AudioStreamPlayer.new()
	_current_music_player.name = "CurrentMusic"
	_current_music_player.bus = BUS_MUSIC
	add_child(_current_music_player)

	_next_music_player = AudioStreamPlayer.new()
	_next_music_player.name = "NextMusic"
	_next_music_player.bus = BUS_MUSIC
	add_child(_next_music_player)


## Play a one-shot sound effect.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_SFX
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


## Play ambient sound (loops until stopped).
func play_ambient(stream: AudioStream, volume_db: float = -10.0) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = BUS_AMBIENT
	player.volume_db = volume_db
	player.stream.loop = true
	add_child(player)
	player.play()
	return player


## Play music with crossfade from current track.
func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if _current_music_player.stream == stream and _current_music_player.playing:
		return

	_next_music_player.stream = stream
	_next_music_player.volume_db = volume_db
	_next_music_player.play()

	# Fade out current, fade in next.
	var fade_tween := create_tween()
	fade_tween.tween_property(_current_music_player, "volume_db", -40.0, CROSSFADE_DURATION)
	fade_tween.parallel().tween_property(_next_music_player, "volume_db", volume_db, CROSSFADE_DURATION)
	fade_tween.finished.connect(_swap_music_players.bind(volume_db))


## Stop all music with a fade-out.
func stop_music() -> void:
	if _current_music_player.playing:
		var fade_tween := create_tween()
		fade_tween.tween_property(_current_music_player, "volume_db", -40.0, CROSSFADE_DURATION)
		fade_tween.finished.connect(_current_music_player.stop)


## Set volume for a specific bus (0.0 to 1.0 linear scale).
func set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		push_warning("AudioManager: Bus '%s' not found." % bus_name)
		return
	var db := linear_to_db(clampf(linear_volume, 0.0, 1.0))
	AudioServer.set_bus_volume_db(bus_idx, db)
	volume_changed.emit(bus_name, linear_volume)


## Get volume for a specific bus (returns 0.0 to 1.0 linear scale).
func get_bus_volume(bus_name: String) -> float:
	var bus_idx := AudioServer.get_bus_index(bus_name)
	if bus_idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(bus_idx))


## Swap the current and next music players after crossfade.
func _swap_music_players(volume_db: float) -> void:
	_current_music_player.stop()
	var temp := _current_music_player
	_current_music_player = _next_music_player
	_next_music_player = temp
	_current_music_player.volume_db = volume_db
	_next_music_player.stream = null
