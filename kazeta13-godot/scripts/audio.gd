extends Node
## Sound manager: one-shots (2D/3D), loops with smooth volume, microphone level.

var M
var sfx := {}
var loops := {}        # name -> AudioStreamPlayer(3D)
var target := {}       # name -> linear volume target
var rate := {}
var mic_player: AudioStreamPlayer
var mic_capture: AudioEffectCapture
var mic_on := false
var mic_level := 0.0


func build() -> void:
	sfx.step = Synth.step(0)
	for i in 5:
		sfx["step%d" % i] = Synth.step(i + 1)
	sfx.heart = Synth.heart()
	sfx.click = Synth.click()
	sfx.creak = Synth.creak()
	sfx.stinger = Synth.stinger()
	sfx.shriek = Synth.shriek()
	sfx.whisper = Synth.whisper()
	sfx.moan = Synth.moan()
	sfx.chop = Synth.chop()
	sfx.slam = Synth.slam()
	sfx.knock = Synth.knock()
	sfx.heavy = Synth.heavy()
	sfx.grunt = Synth.grunt()
	sfx.crack = Synth.crack()
	sfx.giggle = Synth.giggle()
	sfx.radio = Synth.radio()
	sfx.hurt = Synth.hurt()
	sfx.knife_hit = Synth.knife_hit()
	sfx.pant = Synth.pant()
	sfx.beep = Synth.beep()
	sfx.pick = Synth.pick()
	sfx.lock = Synth.lock()
	sfx.insert = Synth.insert()
	sfx.scream = Synth.scream()
	sfx.stab = Synth.stab()
	sfx.steps_above = Synth.steps_above()
	sfx.run_by = Synth.run_by()
	sfx.blow = Synth.blow()
	sfx.tick = Synth.tick(false)
	sfx.tick_back = Synth.tick(true)
	sfx.whoosh = Synth.whoosh(1.1)
	sfx.breath = Synth.breath()
	sfx.drone = Synth.drone()
	sfx.static = Synth.static_noise()
	sfx.music = Synth.music_box()
	sfx.chase = Synth.chase()
	sfx.hosthum = Synth.hum(38, 160)
	sfx.mainshum = Synth.hum(59.7, 400)
	sfx.room = Synth.room_tone()
	for k in ["drone", "music", "chase", "breath", "room", "mainshum", "tv"]:
		var p := AudioStreamPlayer.new()
		p.stream = sfx.static if k == "tv" else sfx[k]
		p.volume_db = -80
		add_child(p)
		loops[k] = p
		target[k] = 0.0
		rate[k] = 3.0
	_mic_setup()


func play(name: String, db := 0.0, pitch := 1.0) -> void:
	if not sfx.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = sfx[name]
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func play_at(name: String, pos: Vector3, db := 0.0, pitch := 1.0, unit := 3.0) -> void:
	if not sfx.has(name):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sfx[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = unit
	p.max_distance = 40.0
	p.attenuation_filter_cutoff_hz = 3500.0
	add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


## side: -1 left .. 1 right relative to the player
func play_side(name: String, side: float, db := 0.0, pitch := 1.0) -> void:
	var g = M.game
	var right := Vector3(cos(g.S.yaw), 0, -sin(g.S.yaw))
	var fw := Vector3(-sin(g.S.yaw), 0, -cos(g.S.yaw))
	play_at(name, Vector3(g.S.x, 1.6, g.S.z) + right * side * 2.5 + fw * 0.5, db, pitch, 4.0)


func set_loop(name: String, vol: float, r := 3.0) -> void:
	target[name] = vol
	rate[name] = r


func _process(dt: float) -> void:
	for k in loops:
		var p = loops[k]
		var cur := db_to_linear(p.volume_db) if p.volume_db > -79 else 0.0
		var nv := lerpf(cur, target[k], minf(1.0, dt * rate[k]))
		if nv < 0.0008:
			if p.playing:
				p.stop()
			p.volume_db = -80
		else:
			p.volume_db = linear_to_db(nv)
			if not p.playing:
				p.play()
	if mic_on and mic_capture:
		var frames := mic_capture.get_frames_available()
		if frames > 0:
			var buf := mic_capture.get_buffer(frames)
			var s := 0.0
			for v in buf:
				s += v.x * v.x
			mic_level = sqrt(s / maxf(1.0, buf.size()))


func _mic_setup() -> void:
	var idx := AudioServer.bus_count
	AudioServer.add_bus(idx)
	AudioServer.set_bus_name(idx, "Mic")
	AudioServer.set_bus_mute(idx, true)
	mic_capture = AudioEffectCapture.new()
	AudioServer.add_bus_effect(idx, mic_capture)
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Mic"
	add_child(mic_player)


func set_mic(on: bool) -> void:
	mic_on = on
	if on:
		mic_player.play()
	else:
		mic_player.stop()
		mic_level = 0.0


func speak(who: String, text: String) -> void:
	if not M.SET.voices:
		return
	var v = C.VOICES.get(who)
	if v == null and who == "" and text.begins_with("…"):
		v = [0.75, 0.8]
	if v == null:
		return
	var clean := text.replace("…", " ").replace("♪", " ").strip_edges()
	if clean == "":
		return
	var voices := DisplayServer.tts_get_voices_for_language("sk")
	if voices.is_empty():
		voices = DisplayServer.tts_get_voices_for_language("cs")
	if voices.is_empty():
		var all := DisplayServer.tts_get_voices()
		if all.is_empty():
			return
		voices = [all[0].id]
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(clean, voices[0], int(M.SET.vol * 100), v[1], v[0])
