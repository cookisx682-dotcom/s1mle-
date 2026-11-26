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

## Soft footstep on old wooden floor: heel + toe thump, low-passed, slight board creak.
static func step(variant := 0) -> AudioStreamWAV:
	seed(1000 + variant)
	var n := int(RATE * 0.22)
	var b := PackedFloat32Array(); b.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var toe := int(RATE * randf_range(0.045, 0.07))
	var body_f := randf_range(85.0, 115.0)
	var creak_f := randf_range(380.0, 620.0)
	var creak_a := randf_range(0.0, 0.05)
	for i in n:
		var t := float(i) / RATE
		var e := 0.0
		if t < 0.003:
			e = t / 0.003
		else:
			e = exp(-(t - 0.003) / 0.035)
		if i >= toe:
			var tt := float(i - toe) / RATE
			e += 0.55 * (minf(1.0, tt / 0.003)) * exp(-tt / 0.03)
		var x := randf_range(-1, 1)
		lp1 += (x - lp1) * 0.09
		lp2 += (lp1 - lp2) * 0.09
		var thump := sin(t * TAU * body_f) * exp(-t / 0.05) * 0.6
		var creak := sin(t * TAU * (creak_f + sin(t * 40.0) * 20.0)) * creak_a * exp(-t / 0.08)
		b[i] = (lp2 * 3.2 + thump) * e * 0.55 + creak
	return _wav(b)

## Breathing loop: inhale (higher, airy) and exhale (lower, longer), band-passed noise.
static func breath() -> AudioStreamWAV:
	seed(77)
	var n := int(RATE * 2.6)
	var b := PackedFloat32Array(); b.resize(n)
	var lo1 := 0.0
	var lo2 := 0.0
	var hi := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := 0.0
		var bright := 0.0
		if t < 0.95:
			env = sin(t / 0.95 * PI) * 0.8
			bright = 0.55
		elif t > 1.15 and t < 2.45:
			env = pow(sin((t - 1.15) / 1.3 * PI), 0.8)
			bright = 0.32
		var x := randf_range(-1, 1)
		lo1 += (x - lo1) * bright
		lo2 += (lo1 - lo2) * bright
		hi = lo1 - lo2
		b[i] = hi * env * 0.9
	return _wav(b, true)

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

# ---------------------------------------------------------------- generic builders
static func _noise_burst(dur: float, cutoff: float, attack: float, decay: float, gain := 0.8, brown := false, f2 := -1.0) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var b := PackedFloat32Array(); b.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	var br := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := randf_range(-1, 1)
		if brown:
			br = (br + 0.02 * x) / 1.02
			x = br * 3.5
		var fc := cutoff if f2 < 0 else cutoff * pow(f2 / cutoff, t / dur)
		var a := clampf(fc / RATE * 6.28, 0.001, 1.0)
		lp += (x - lp) * a
		lp2 += (lp - lp2) * a
		var e := t / attack if t < attack else exp(-(t - attack) / maxf(decay, 0.001))
		b[i] = lp2 * e * gain * 2.0
	return b

static func _band(dur: float, f: float, q: float, attack: float, decay: float, gain := 0.6) -> PackedFloat32Array:
	# two-pole resonator on white noise
	var n := int(RATE * dur)
	var b := PackedFloat32Array(); b.resize(n)
	var w := TAU * f / RATE
	var r := clampf(1.0 - w / (2.0 * q), 0.5, 0.9995)
	var c1 := 2.0 * r * cos(w)
	var c2 := -r * r
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var y := randf_range(-1, 1) * (1.0 - r) * 2.0 + c1 * y1 + c2 * y2
		y2 = y1
		y1 = y
		var e := t / attack if t < attack else exp(-(t - attack) / maxf(decay, 0.001))
		b[i] = y * e * gain
	return b

static func _tone(dur: float, f: float, f2: float, wave: String, attack: float, decay: float, gain := 0.5) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var b := PackedFloat32Array(); b.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var fr := f * pow(f2 / f, t / dur)
		ph += fr / RATE
		var p := fposmod(ph, 1.0)
		var v := 0.0
		match wave:
			"saw": v = p * 2.0 - 1.0
			"square": v = 1.0 if p < 0.5 else -1.0
			"tri": v = 1.0 - absf(p * 4.0 - 2.0)
			_: v = sin(p * TAU)
		var e := t / attack if t < attack else exp(-(t - attack) / maxf(decay, 0.001))
		b[i] = v * e * gain
	return b

static func _mix(parts: Array, offsets := []) -> PackedFloat32Array:
	var n := 0
	for i in parts.size():
		var off := int(RATE * (offsets[i] if i < offsets.size() else 0.0))
		n = maxi(n, off + parts[i].size())
	var b := PackedFloat32Array(); b.resize(n)
	for i in parts.size():
		var off := int(RATE * (offsets[i] if i < offsets.size() else 0.0))
		var p: PackedFloat32Array = parts[i]
		for k in p.size():
			b[off + k] += p[k]
	return b

static func slam() -> AudioStreamWAV:
	return _wav(_mix([_noise_burst(0.7, 300, 0.003, 0.18, 1.2, true), _tone(0.6, 55, 35, "sine", 0.003, 0.2, 0.6)]))

static func knock() -> AudioStreamWAV:
	var parts := []
	var offs := []
	for i in 3:
		parts.append(_noise_burst(0.15, 380, 0.002, 0.04, 1.1, true)); offs.append(i * 0.32)
		parts.append(_tone(0.12, 110, 70, "sine", 0.002, 0.04, 0.35)); offs.append(i * 0.32)
	return _wav(_mix(parts, offs))

static func heavy() -> AudioStreamWAV:
	return _wav(_mix([_noise_burst(0.3, 260, 0.004, 0.08, 1.0, true), _tone(0.25, 52, 38, "sine", 0.003, 0.08, 0.45)]))

static func grunt() -> AudioStreamWAV:
	return _wav(_mix([_tone(0.6, 85, 60, "saw", 0.05, 0.2, 0.3), _band(0.55, 420, 3, 0.05, 0.18, 0.5)]))

static func crack() -> AudioStreamWAV:
	var parts := []
	var offs := []
	for i in 3:
		parts.append(_band(0.06, 2600 + randf() * 1500, 1.5, 0.001, 0.012, 0.7)); offs.append(i * 0.06 + randf() * 0.03)
	return _wav(_mix(parts, offs))

static func giggle() -> AudioStreamWAV:
	var parts := []
	var offs := []
	for i in 4:
		parts.append(_tone(0.16, 1050 - i * 40 + randf() * 60, 980 - i * 40, "tri", 0.01, 0.05, 0.12)); offs.append(i * 0.16)
		parts.append(_band(0.1, 2800, 4, 0.005, 0.03, 0.15)); offs.append(i * 0.16)
	return _wav(_mix(parts, offs))

static func radio() -> AudioStreamWAV:
	var parts := []
	var offs := []
	for i in 6:
		var f := 200 + randf() * 500
		parts.append(_tone(0.1, f, f, "square", 0.005, 0.04, 0.06)); offs.append(i * 0.1)
	parts.append(_band(0.7, 2400, 2, 0.01, 0.25, 0.25)); offs.append(0.0)
	return _wav(_mix(parts, offs))

static func hurt() -> AudioStreamWAV:
	return _wav(_mix([_noise_burst(0.35, 600, 0.003, 0.1, 1.0, true), _tone(0.4, 240, 120, "saw", 0.005, 0.12, 0.25), _band(0.3, 1200, 2, 0.005, 0.08, 0.4)], [0, 0, 0.05]))

static func knife_hit() -> AudioStreamWAV:
	return _wav(_mix([_band(0.15, 1800, 2, 0.001, 0.04, 0.9), _noise_burst(0.25, 500, 0.002, 0.06, 0.9, true)], [0, 0.03]))

static func pant() -> AudioStreamWAV:
	return _wav(_mix([_band(0.4, 900, 1.5, 0.12, 0.12, 0.35), _band(0.35, 1300, 2, 0.08, 0.1, 0.22)], [0, 0.4]))

static func beep() -> AudioStreamWAV:
	return _wav(_tone(0.15, 1000, 1000, "sine", 0.003, 0.05, 0.12))

static func tick(back := false) -> AudioStreamWAV:
	return _wav(_band(0.05, 2400.0 if back else 3600.0, 6, 0.001, 0.012, 0.35))

static func pick() -> AudioStreamWAV:
	return _wav(_mix([_band(0.09, 1500, 2, 0.002, 0.025, 0.4), _tone(0.1, 420, 420, "sine", 0.003, 0.03, 0.1)]))

static func lock() -> AudioStreamWAV:
	return _wav(_mix([_band(0.06, 2400, 1, 0.001, 0.015, 0.5), _band(0.1, 900, 3, 0.002, 0.03, 0.4), _band(0.18, 500, 2, 0.003, 0.05, 0.6)], [0, 0.06, 0.12]))

static func insert() -> AudioStreamWAV:
	return _wav(_mix([_band(0.15, 700, 2, 0.003, 0.04, 0.6), _tone(0.12, 90, 90, "sine", 0.003, 0.04, 0.4), _band(0.5, 3500, 1, 0.2, 0.15, 0.2)], [0, 0.15, 0.3]))

static func whoosh(d := 1.1) -> AudioStreamWAV:
	return _wav(_band(d, 3000, 0.6, d * 0.3, d * 0.3, 0.6))

static func scream() -> AudioStreamWAV:
	return _wav(_mix([_tone(1.6, 780, 420, "saw", 0.08, 0.6, 0.12), _tone(1.6, 820, 440, "saw", 0.08, 0.6, 0.1), _band(1.3, 1600, 1, 0.1, 0.45, 0.15)]))

static func stab() -> AudioStreamWAV:
	return _wav(_mix([_noise_burst(0.4, 7000, 0.002, 0.1, 0.9), _tone(0.5, 1100, 260, "saw", 0.003, 0.15, 0.25), _tone(0.5, 1130, 270, "saw", 0.003, 0.15, 0.2), _tone(0.45, 55, 35, "sine", 0.003, 0.15, 0.6)]))

static func steps_above() -> AudioStreamWAV:
	var parts := []
	var offs := []
	for i in 7:
		parts.append(_noise_burst(0.2, 180, 0.004, 0.06, 0.8, true)); offs.append(i * 0.55)
	return _wav(_mix(parts, offs))

static func run_by() -> AudioStreamWAV:
	var parts := []
	var offs := []
	for i in 9:
		parts.append(_noise_burst(0.14, 520, 0.003, 0.04, 0.8, true)); offs.append(i * 0.21)
		parts.append(_tone(0.08, 70, 70, "sine", 0.002, 0.03, 0.1)); offs.append(i * 0.21)
	return _wav(_mix(parts, offs))

static func blow() -> AudioStreamWAV:
	return _wav(_band(0.8, 900, 0.5, 0.15, 0.25, 0.5))

## chase music loop: low drum pulse + dissonant swell
static func chase() -> AudioStreamWAV:
	var beat := 0.21
	var steps := 16
	var parts := []
	var offs := []
	var pad := PackedFloat32Array(); pad.resize(int(RATE * beat * steps))
	var phs := [0.0, 0.0, 0.0, 0.0, 0.0]
	var fr := [110.0, 116.5, 155.6, 164.8, 233.0]
	var lp := 0.0
	for i in pad.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in 5:
			phs[k] += fr[k] / RATE
			v += (fposmod(phs[k], 1.0) * 2.0 - 1.0) * 0.09
		lp += (v - lp) * 0.25
		pad[i] = lp * (0.75 + 0.25 * sin(t * TAU * 11.0))
	parts.append(pad); offs.append(0.0)
	for k in steps:
		if k % 4 == 0:
			parts.append(_tone(0.3, 72, 38, "sine", 0.003, 0.1, 0.9)); offs.append(k * beat)
			parts.append(_noise_burst(0.22, 300, 0.003, 0.06, 0.6, true)); offs.append(k * beat)
		if k % 4 == 2:
			parts.append(_band(0.18, 1900, 0.8, 0.003, 0.05, 0.4)); offs.append(k * beat)
		parts.append(_band(0.05, 7000, 0.7, 0.001, 0.01, 0.08)); offs.append(k * beat)
		if k == 8:
			parts.append(_tone(0.7, 1700, 1150, "saw", 0.01, 0.25, 0.07)); offs.append(k * beat)
	var b := _mix(parts, offs)
	b.resize(int(RATE * beat * steps))
	return _wav(b, true)

static func hum(f := 38.0, cutoff := 160.0) -> AudioStreamWAV:
	var n := RATE * 2
	var b := PackedFloat32Array(); b.resize(n)
	var ph := 0.0
	var lp := 0.0
	for i in n:
		ph += f / RATE
		lp += ((fposmod(ph, 1.0) * 2.0 - 1.0) - lp) * (cutoff / RATE * 6.28)
		b[i] = lp * 0.8
	return _wav(b, true)

static func room_tone() -> AudioStreamWAV:
	var n := RATE * 3
	var b := PackedFloat32Array(); b.resize(n)
	var br := 0.0
	var lp := 0.0
	for i in n:
		br = (br + 0.02 * randf_range(-1, 1)) / 1.02
		lp += (br * 3.5 - lp) * 0.045
		b[i] = lp * 1.2
	return _wav(b, true)
