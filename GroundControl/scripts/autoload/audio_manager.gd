extends Node
## AudioManager (autoload)
## Looks up sounds in res://audio/<kind>/<name>.(ogg|wav|mp3).
## When a file does not exist, sound effects fall back to a tiny synthesized placeholder
## and music simply stays silent — the game never errors because audio is missing.
## See res://audio/*/README.md for the list of expected file names.

const EXTENSIONS := ["ogg", "wav", "mp3"]
const MIX_RATE := 22050
const SFX_VOICES := 10

## Placeholder recipes: name -> [frequencies (Hz, one per segment), duration (s), waveform, volume]
const FALLBACK := {
	"ui_click": [[1400.0], 0.03, "square", 0.16],
	"ui_hover": [[900.0], 0.02, "square", 0.06],
	"radio_beep": [[880.0, 1320.0], 0.22, "sine", 0.3],
	"radio_static": [[0.0], 0.35, "noise", 0.12],
	"typewriter": [[2200.0], 0.012, "square", 0.04],
	"alarm": [[660.0, 440.0, 660.0, 440.0], 0.9, "square", 0.2],
	"phone_ring": [[1150.0, 1400.0, 1150.0, 1400.0, 0.0, 0.0], 1.0, "sine", 0.22],
	"fax": [[0.0], 0.6, "noise", 0.08],
	"knock": [[140.0, 0.0, 140.0], 0.3, "sine", 0.5],
	"switch": [[0.0], 0.04, "noise", 0.3],
	"card_pin": [[220.0], 0.06, "sine", 0.4],
	"string_ok": [[523.0, 784.0, 1046.0], 0.35, "sine", 0.3],
	"string_fail": [[220.0, 155.0], 0.35, "square", 0.18],
	"achievement": [[523.0, 659.0, 784.0, 1046.0], 0.6, "square", 0.16],
	"crisis_ok": [[660.0, 990.0], 0.3, "sine", 0.3],
	"crisis_fail": [[300.0, 200.0, 150.0], 0.5, "square", 0.18],
	"nav_ok": [[700.0, 1050.0], 0.25, "sine", 0.25],
	"nav_fail": [[260.0], 0.25, "square", 0.16],
	"signal": [[110.0, 220.0, 165.0, 110.0], 1.6, "sine", 0.35],
	"paper": [[0.0], 0.18, "noise", 0.12],
}

var _sfx_players: Array = []
var _next_voice := 0
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _cache: Dictionary = {}
var _music_name := ""
var _ambience_name := ""
var _last_play_time: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	_music = _make_player("Music")
	_ambience = _make_player("Music")
	for i in SFX_VOICES:
		_sfx_players.append(_make_player("SFX"))


# ---------------------------------------------------------------- public API

## Plays a one-shot sound effect. Very frequent calls of the same sound are rate-limited.
func play_sfx(sound_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if sound_name == "":
		return
	var now := Time.get_ticks_msec()
	if now - int(_last_play_time.get(sound_name, -1000)) < 30:
		return
	_last_play_time[sound_name] = now
	var stream := _get_sfx(sound_name)
	if stream == null:
		return
	var p: AudioStreamPlayer = _sfx_players[_next_voice]
	_next_voice = (_next_voice + 1) % _sfx_players.size()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


## Music only plays if a real file exists (no synthesized fallback).
func play_music(track_name: String) -> void:
	if track_name == _music_name and _music.playing:
		return
	var s := _find_file("music", track_name)
	_music_name = track_name
	if s == null:
		_music.stop()
		return
	_music.stream = s
	_music.play()


func stop_music() -> void:
	_music_name = ""
	_music.stop()


## Ambience loops. "room_tone" has a synthesized fallback (low hum + air noise).
func play_ambience(ambience_name: String) -> void:
	if ambience_name == _ambience_name and _ambience.playing:
		return
	_ambience_name = ambience_name
	var s := _find_file("ambience", ambience_name)
	if s == null and ambience_name == "room_tone":
		if not _cache.has("_room_tone"):
			_cache["_room_tone"] = _synth_room_tone()
		s = _cache["_room_tone"]
	if s == null:
		_ambience.stop()
		return
	_ambience.stream = s
	_ambience.volume_db = -8.0
	_ambience.play()


func stop_ambience() -> void:
	_ambience_name = ""
	_ambience.stop()


func apply_volumes() -> void:
	_set_bus_volume("Master", float(SaveSystem.get_setting("master_volume", 0.8)))
	_set_bus_volume("Music", float(SaveSystem.get_setting("music_volume", 0.7)))
	_set_bus_volume("SFX", float(SaveSystem.get_setting("sfx_volume", 0.8)))


# ---------------------------------------------------------------- internals

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func _make_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


func _find_file(kind: String, sound_name: String) -> AudioStream:
	if sound_name == "":
		return null
	for ext in EXTENSIONS:
		var path := "res://audio/%s/%s.%s" % [kind, sound_name, ext]
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is AudioStream:
				return res as AudioStream
	return null


func _get_sfx(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var s := _find_file("sfx", sound_name)
	if s == null:
		var recipe: Array = FALLBACK.get(sound_name, FALLBACK["ui_click"])
		s = _synth(recipe[0], float(recipe[1]), str(recipe[2]), float(recipe[3]))
	_cache[sound_name] = s
	return s


## Generates a short mono 16-bit tone/noise burst with a simple envelope.
func _synth(freqs: Array, duration: float, wave: String, volume: float) -> AudioStreamWAV:
	var n := int(MIX_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	var segs := maxi(1, freqs.size())
	var noise_val := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var seg := mini(int(t / duration * segs), segs - 1)
		var f := float(freqs[seg])
		phase = fmod(phase + f / MIX_RATE, 1.0)
		var s := 0.0
		if wave == "noise":
			noise_val = lerpf(noise_val, randf_range(-1.0, 1.0), 0.6)
			s = noise_val
		elif f > 0.0:
			if wave == "square":
				s = 1.0 if phase < 0.5 else -1.0
			else:
				s = sin(phase * TAU)
		var env := minf(1.0, t * 300.0) * clampf((duration - t) / (duration * 0.35), 0.0, 1.0)
		bytes.encode_s16(i * 2, int(clampf(s * env * volume, -1.0, 1.0) * 32767.0))
	return _make_wav(bytes, false, n)


## Seamless 4 second loop: mains hum (55/110 Hz) + soft filtered air noise.
func _synth_room_tone() -> AudioStreamWAV:
	var dur := 4.0
	var n := int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var brown := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		brown = clampf(brown + randf_range(-0.02, 0.02), -1.0, 1.0) * 0.998
		var s := 0.35 * sin(TAU * 55.0 * t) + 0.12 * sin(TAU * 110.0 * t) + 0.5 * brown
		bytes.encode_s16(i * 2, int(clampf(s * 0.22, -1.0, 1.0) * 32767.0))
	return _make_wav(bytes, true, n)


func _make_wav(bytes: PackedByteArray, loop: bool, frames: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = frames
	return wav
