extends Node

## All sound effects are tiny procedurally-synthesized tones (simple
## sine/square sweeps baked into AudioStreamWAV buffers at startup) - no
## external audio assets needed, matching the rest of the game's
## "everything drawn/generated in code" placeholder style.
##
## Registered as the "SoundManager" autoload in project.godot, reached
## directly by that name from anywhere.

const MIX_RATE: int = 22050

var _shoot: AudioStreamWAV
var _enemy_shoot: AudioStreamWAV
var _monster_death: AudioStreamWAV
var _player_hit: AudioStreamWAV
var _level_start: AudioStreamWAV
var _portal: AudioStreamWAV
var _game_over: AudioStreamWAV
var _wall_alter: AudioStreamWAV
var _resource_pickup: AudioStreamWAV
var _resource_spawn: AudioStreamWAV
var _bomb_place: AudioStreamWAV
var _explosion: AudioStreamWAV

func _ready() -> void:
	_shoot = _make_tone(900, 500, 0.08, 0.22, true)
	_enemy_shoot = _make_tone(500, 250, 0.10, 0.20, true)
	_monster_death = _make_tone(500, 120, 0.25, 0.30, true)
	_player_hit = _make_tone(300, 70, 0.35, 0.35, true)
	_level_start = _make_tone(300, 720, 0.50, 0.28, false)
	_portal = _make_tone(500, 1100, 0.40, 0.30, true)
	_game_over = _make_tone(400, 70, 0.90, 0.32, false)
	_wall_alter = _make_tone(650, 900, 0.12, 0.22, false)
	_resource_pickup = _make_tone(700, 1400, 0.28, 0.28, false)
	# A two-note "ding-ding" chime rather than a sweep, so it reads as a
	# distinct notification cue instead of just another laser/hit sound -
	# used to call attention to a new resource cache appearing somewhere
	# on the maze.
	_resource_spawn = _make_chime(520, 780, 0.09, 0.30)
	_bomb_place = _make_tone(220, 160, 0.10, 0.26, true)
	_explosion = _make_tone(160, 40, 0.45, 0.38, true)

func play_shoot() -> void: _play(_shoot)
func play_enemy_shoot() -> void: _play(_enemy_shoot)
func play_monster_death() -> void: _play(_monster_death)
func play_player_hit() -> void: _play(_player_hit)
func play_level_start() -> void: _play(_level_start)
func play_portal() -> void: _play(_portal)
func play_game_over() -> void: _play(_game_over)
func play_wall_alter() -> void: _play(_wall_alter)
func play_resource_pickup() -> void: _play(_resource_pickup)
func play_resource_spawn() -> void: _play(_resource_spawn)
func play_bomb_place() -> void: _play(_bomb_place)
func play_explosion() -> void: _play(_explosion)

func _play(stream: AudioStreamWAV) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## Synthesizes a short mono 16-bit PCM tone that sweeps linearly from
## freq_start to freq_end over "duration" seconds, with a linear fade-out
## envelope so it doesn't click at the end.
func _make_tone(freq_start: float, freq_end: float, duration: float, volume: float, square: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = _tone_samples(freq_start, freq_end, duration, volume, square)
	return stream

## Two short flat notes back-to-back (with a tiny silent gap between them)
## instead of one sweep - reads as a distinct "ding-ding" notification
## rather than another laser/impact sound.
func _make_chime(note_a: float, note_b: float, note_duration: float, volume: float) -> AudioStreamWAV:
	var a: PackedByteArray = _tone_samples(note_a, note_a, note_duration, volume, false)
	var gap := PackedByteArray()
	gap.resize(int(0.03 * MIX_RATE) * 2)
	gap.fill(0)
	var b: PackedByteArray = _tone_samples(note_b, note_b, note_duration, volume, false)

	var combined := PackedByteArray()
	combined.append_array(a)
	combined.append_array(gap)
	combined.append_array(b)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = combined
	return stream

func _tone_samples(freq_start: float, freq_end: float, duration: float, volume: float, square: bool) -> PackedByteArray:
	var sample_count: int = maxi(1, int(duration * MIX_RATE))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var dt: float = 1.0 / MIX_RATE
	var phase: float = 0.0

	for i in range(sample_count):
		var freq: float = lerpf(freq_start, freq_end, float(i) / sample_count)
		phase += TAU * freq * dt

		var raw: float = signf(sin(phase)) if square else sin(phase)
		var envelope: float = 1.0 - float(i) / sample_count
		var sample: float = raw * volume * envelope

		var s16: int = clampi(int(sample * 32767.0), -32768, 32767)
		data[i * 2] = s16 & 0xFF
		data[i * 2 + 1] = (s16 >> 8) & 0xFF

	return data
