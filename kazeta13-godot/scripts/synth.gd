class_name Synth
extends RefCounted
## Generates all game sounds procedurally as AudioStreamWAV.

const RATE := 22050

static func _wav(buf: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

static func _env(i: int, n: int, a: float, d: float) -> float:
	var t := float(i) / RATE
	var total := float(n) / RATE
	if t < a:
		return t / a
	return exp(-(t - a) / maxf(d, 0.001)) * clampf((total - t) / 0.02, 0.0, 1.0)

static func step() -> AudioStreamWAV:
	var n := int(RATE * 0.18)
	var b := PackedFloat32Array(); b.resize(n)
	var lp := 0.0
	for i in n:
		lp += (randf_range(-1, 1) - lp) * 0.08
		b[i] = (lp * 2.2 + sin(i * TAU * 70.0 / RATE) * 0.25) * _env(i, n, 0.004, 0.045)
	return _wav(b)

static func heart() -> AudioStreamWAV:
	var n := int(RATE * 0.5)
	var b := PackedFloat32Array(); b.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for k in [0.0, 0.18]:
			var tt: float = t - k
			if tt >= 0.0:
				v += sin(tt * TAU * (52.0 - tt * 60.0)) * exp(-tt * 18.0) * (1.0 if k == 0.0 else 0.75)
		b[i] = v * 0.9
	return _wav(b)

static func click() -> AudioStreamWAV:
	var n := int(RATE * 0.08)
	var b := PackedFloat32Array(); b.resize(n)
	var hp := 0.0
	var last := 0.0
	for i in n:
		var x := randf_range(-1, 1)
		hp = 0.7 * (hp + x - last)
		last = x
		b[i] = hp * _env(i, n, 0.001, 0.012) * 0.8
	return _wav(b)

static func creak() -> AudioStreamWAV:
	var n := int(RATE * 1.1)
	var b := PackedFloat32Array(); b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 110.0 + 60.0 * sin(t * 3.0) + randf_range(-8, 8)
		ph += f / RATE
		var saw := fposmod(ph, 1.0) * 2.0 - 1.0
		b[i] = saw * 0.18 * sin(t / 1.1 * PI)
	return _wav(b)

static func stinger() -> AudioStreamWAV:
	var n := int(RATE * 1.3)
	var b := PackedFloat32Array(); b.resize(n)
	var phs := [0.0, 0.0, 0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var e := exp(-t * 2.2)
		var v := randf_range(-1, 1) * 0.5 * exp(-t * 4.0)
		for k in 4:
			var f: float = (620.0 + k * 93.0) * pow(0.25, t / 1.2)
			phs[k] += f / RATE
			v += (fposmod(phs[k], 1.0) * 2.0 - 1.0) * 0.16
		v += sin(t * TAU * (48.0 - t * 15.0)) * 0.5
		b[i] = v * e
	return _wav(b)

static func shriek() -> AudioStreamWAV:
	var n := int(RATE * 0.9)
	var b := PackedFloat32Array(); b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1500.0 - t * 700.0 + sin(t * 40.0) * 60.0
		ph += f / RATE
		b[i] = ((fposmod(ph, 1.0) * 2.0 - 1.0) * 0.35 + randf_range(-1, 1) * 0.25) * _env(i, n, 0.02, 0.35)
	return _wav(b)

static func whisper() -> AudioStreamWAV:
	var n := int(RATE * 1.6)
	var b := PackedFloat32Array(); b.resize(n)
	var bp1 := 0.0
	var bp2 := 0.0
	var seg := 0
	var gain := 0.0
	for i in n:
		if i % int(RATE * 0.16) == 0:
			seg += 1
			gain = randf_range(0.2, 1.0) if randf() < 0.8 else 0.0
		var x := randf_range(-1, 1)
		bp1 += (x - bp1) * 0.45
		bp2 += (bp1 - bp2) * 0.45
		var hpv := bp1 - bp2
		var t := float(i % int(RATE * 0.16)) / (RATE * 0.16)
		b[i] = hpv * gain * sin(t * PI) * 0.9
	return _wav(b)

static func moan() -> AudioStreamWAV:
	var n := int(RATE * 2.4)
	var b := PackedFloat32Array(); b.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 95.0 - t * 10.0 + sin(t * 31.0) * 3.0
		ph += f / RATE
		var saw := fposmod(ph, 1.0) * 2.0 - 1.0
		lp += (saw - lp) * (0.08 + 0.05 * sin(t * 2.0))
		b[i] = lp * sin(t / 2.4 * PI) * 0.7
	return _wav(b)

static func drone() -> AudioStreamWAV:
	var n := RATE * 6
	var b := PackedFloat32Array(); b.resize(n)
	var phs := [0.0, 0.0, 0.0]
	var fr := [43.65, 44.15, 65.4]
	var lp := 0.0
	for i in n:
		var v := 0.0
		for k in 3:
			phs[k] += fr[k] / RATE
			v += fposmod(phs[k], 1.0) * 2.0 - 1.0
		lp += (v * 0.33 - lp) * 0.03
		b[i] = lp * 0.9
	return _wav(b, true)

static func static_noise() -> AudioStreamWAV:
	var n := RATE * 2
	var b := PackedFloat32Array(); b.resize(n)
	var last := 0.0
	for i in n:
		var x := randf_range(-1, 1)
		b[i] = (x - last * 0.6) * 0.35
		last = x
	return _wav(b, true)

static func music_box() -> AudioStreamWAV:
	var notes := [659, 784, 988, 880, 784, 659, 587, 659, 523, 587, 659, 494, 523, 440]
	var step_len := int(RATE * 0.52)
	var n := step_len * notes.size()
	var b := PackedFloat32Array(); b.resize(n)
	for k in notes.size():
		var f: float = notes[k] * randf_range(0.985, 0.995)
		for j in int(RATE * 1.2):
			var i := k * step_len + j
			if i >= n:
				break
			var t := float(j) / RATE
			b[i] += (sin(t * TAU * f) * 0.6 + sin(t * TAU * f * 2.0) * 0.2) * exp(-t * 3.0) * 0.35
	return _wav(b, true)

static func chop() -> AudioStreamWAV:
	var n := int(RATE * 0.25)
	var b := PackedFloat32Array(); b.resize(n)
	var lp := 0.0
	for i in n:
		lp += (randf_range(-1, 1) - lp) * 0.25
		var t := float(i) / RATE
		b[i] = (lp * 1.8 + sin(t * TAU * (95.0 - t * 200.0)) * 0.6) * _env(i, n, 0.002, 0.06)
	return _wav(b)
