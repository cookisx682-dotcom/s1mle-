class_name Tex
extends RefCounted
## Procedural textures and PBR materials for the house.

static var _cache := {}

static func _noise(seed_v: int, freq: float, octaves := 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = octaves
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n

static func _normal_from_noise(seed_v: int, freq: float, strength: float) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = strength
	t.noise = _noise(seed_v, freq)
	return t

static func _img_tex(img: Image) -> ImageTexture:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func wallpaper() -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var stain := _noise(11, 0.012)
	var fine := _noise(12, 0.2, 2)
	for y in s:
		for x in s:
			var u := float(x) / s
			var v := float(y) / s
			var c := Color(0.33, 0.35, 0.27)
			# vertical stripes
			if int(x / 16) % 2 == 0:
				c = c.lightened(0.04)
			# damask motif: diamond-ish lobes
			var mx := fposmod(u * 2.0 + (0.5 if int(v * 4.0) % 2 == 1 else 0.0), 1.0) - 0.5
			var my := fposmod(v * 4.0, 1.0) - 0.5
			var d := absf(mx) * 1.6 + absf(my) * 1.0
			var ring := absf(d - 0.32)
			if ring < 0.035 or (d < 0.12 and d > 0.08):
				c = c.lerp(Color(0.78, 0.74, 0.58), 0.28)
			# age stains and grime
			var st := stain.get_noise_2d(x, y)
			c = c.darkened(clampf(st * 0.35 + 0.08, 0.0, 0.4))
			c = c.darkened(fine.get_noise_2d(x, y) * 0.06 + 0.03)
			# drip streaks from the top
			if fposmod(float(x) * 0.137, 1.0) < 0.02 and v < 0.6:
				c = c.darkened(0.12 * (1.0 - v / 0.6))
			img.set_pixel(x, y, c)
	return _img_tex(img)

static func planks() -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var grain := _noise(21, 0.05, 3)
	var dirt := _noise(22, 0.01)
	var cols := [Color(0.36, 0.24, 0.15), Color(0.31, 0.21, 0.13), Color(0.40, 0.27, 0.17), Color(0.29, 0.19, 0.12), Color(0.34, 0.23, 0.14), Color(0.38, 0.26, 0.16)]
	var n := 6
	var ph := s / n
	for y in s:
		var row := int(y / ph)
		var base: Color = cols[row % cols.size()]
		var joint := (row * 97) % s
		for x in s:
			var g := grain.get_noise_2d(x * 0.15, y * 3.0)
			var c := base.darkened(g * 0.25 + 0.05)
			if y % ph < 2 or absi(x - joint) < 1:
				c = Color(0.05, 0.03, 0.02)
			c = c.darkened(clampf(dirt.get_noise_2d(x, y) * 0.3, 0.0, 0.25))
			img.set_pixel(x, y, c)
	return _img_tex(img)

static func bark() -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var n := _noise(70, 0.03, 4)
	var f := _noise(71, 0.3, 2)
	for y in s:
		for x in s:
			var v := n.get_noise_2d(x * 3.0, y * 0.3)
			var ridge := 1.0 - absf(v) * 3.0
			var c := Color(0.13, 0.1, 0.075).darkened(clampf(0.6 - ridge * 0.7, 0.0, 0.8))
			c = c.lightened(clampf(f.get_noise_2d(x, y) * 0.15, 0.0, 0.15))
			img.set_pixel(x, y, c)
	return _img_tex(img)

static func tiles(a: Color, b: Color, n := 4) -> ImageTexture:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var dirt := _noise(31, 0.02)
	var t := s / n
	for y in s:
		for x in s:
			var c: Color = a if (int(x / t) + int(y / t)) % 2 == 0 else b
			if x % t < 3 or y % t < 3:
				c = Color(0.16, 0.16, 0.14)
			c = c.darkened(clampf(dirt.get_noise_2d(x, y) * 0.35, 0.0, 0.3))
			img.set_pixel(x, y, c)
	return _img_tex(img)

static func noise_color(seed_v: int, base: Color, amount: float, freq := 0.05) -> ImageTexture:
	var s := 128
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var n := _noise(seed_v, freq)
	var f := _noise(seed_v + 1, 0.4, 1)
	for y in s:
		for x in s:
			var c := base.darkened(clampf(n.get_noise_2d(x, y) * amount + f.get_noise_2d(x, y) * amount * 0.5, -0.2, 0.6))
			img.set_pixel(x, y, c)
	return _img_tex(img)

static func mat(key: String) -> StandardMaterial3D:
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE
	match key:
		"wall":
			m.albedo_texture = wallpaper()
			m.roughness = 0.92
			m.normal_enabled = true
			m.normal_texture = _normal_from_noise(41, 0.03, 2.0)
			m.normal_scale = 0.4
			m.uv1_scale = Vector3(0.9, 0.9, 0.9)
		"wainscot":
			m.albedo_texture = noise_color(42, Color(0.23, 0.15, 0.09), 0.5, 0.03)
			m.roughness = 0.55
			m.normal_enabled = true
			m.normal_texture = _normal_from_noise(43, 0.08, 4.0)
			m.normal_scale = 0.6
		"floor":
			m.albedo_texture = planks()
			m.roughness = 0.55
			m.normal_enabled = true
			m.normal_texture = _normal_from_noise(44, 0.06, 3.0)
			m.normal_scale = 0.5
			m.uv1_scale = Vector3(0.8, 0.8, 0.8)
		"tile":
			m.albedo_texture = tiles(Color(0.65, 0.63, 0.55), Color(0.33, 0.40, 0.35))
			m.roughness = 0.25
			m.metallic_specular = 0.7
			m.uv1_scale = Vector3(0.8, 0.8, 0.8)
		"tile2":
			m.albedo_texture = tiles(Color(0.82, 0.83, 0.80), Color(0.78, 0.80, 0.78), 8)
			m.roughness = 0.2
		"carpet":
			m.albedo_texture = noise_color(45, Color(0.15, 0.19, 0.29), 0.6, 0.3)
			m.roughness = 1.0
		"carpet2":
			m.albedo_texture = noise_color(46, Color(0.29, 0.11, 0.12), 0.6, 0.3)
			m.roughness = 1.0
		"ceiling":
			m.albedo_texture = noise_color(47, Color(0.5, 0.48, 0.44), 0.18, 0.02)
			m.roughness = 0.95
		"concrete":
			m.albedo_texture = noise_color(48, Color(0.36, 0.35, 0.33), 0.7, 0.03)
			m.roughness = 0.95
			m.normal_enabled = true
			m.normal_texture = _normal_from_noise(49, 0.05, 6.0)
		"wood":
			m.albedo_texture = noise_color(50, Color(0.29, 0.19, 0.12), 0.5, 0.08)
			m.roughness = 0.5
		"wood_dark":
			m.albedo_texture = noise_color(51, Color(0.16, 0.10, 0.06), 0.5, 0.08)
			m.roughness = 0.45
		"fabric":
			m.albedo_texture = noise_color(52, Color(0.40, 0.31, 0.19), 0.4, 0.5)
			m.roughness = 1.0
		"sheet":
			m.albedo_texture = noise_color(53, Color(0.78, 0.75, 0.69), 0.35, 0.04)
			m.roughness = 0.97
		"cream":
			m.albedo_color = Color(0.82, 0.79, 0.71)
			m.roughness = 0.35
		"plastic":
			m.albedo_color = Color(0.09, 0.09, 0.085)
			m.roughness = 0.4
		"metal":
			m.albedo_color = Color(0.6, 0.6, 0.58)
			m.metallic = 0.8
			m.roughness = 0.35
		"brass":
			m.albedo_color = Color(0.69, 0.55, 0.27)
			m.metallic = 0.9
			m.roughness = 0.3
		"ceramic":
			m.albedo_color = Color(0.88, 0.86, 0.80)
			m.roughness = 0.12
		"black":
			m.albedo_color = Color(0.02, 0.02, 0.02)
			m.roughness = 1.0
		"rug":
			m.albedo_texture = noise_color(54, Color(0.35, 0.12, 0.10), 0.5, 0.15)
			m.roughness = 1.0
		"moss_ground":
			m.albedo_texture = noise_color(60, Color(0.08, 0.11, 0.045), 0.9, 0.08)
			m.roughness = 1.0
			m.normal_enabled = true
			m.normal_texture = _normal_from_noise(61, 0.08, 6.0)
			m.uv1_scale = Vector3(0.6, 0.6, 0.6)
		"bark":
			m.albedo_texture = bark()
			m.roughness = 0.95
			m.normal_enabled = true
			m.normal_texture = _normal_from_noise(62, 0.12, 8.0)
			m.normal_scale = 1.2
			m.uv1_scale = Vector3(1.4, 0.5, 1.4)
		"rock":
			m.albedo_texture = noise_color(63, Color(0.25, 0.25, 0.23), 0.8, 0.06)
			m.roughness = 0.9
			m.normal_enabled = true
			m.normal_texture = _normal_from_noise(64, 0.06, 6.0)
		"moss":
			m.albedo_texture = noise_color(65, Color(0.13, 0.22, 0.05), 0.7, 0.3)
			m.roughness = 1.0
			m.normal_enabled = true
			m.normal_texture = _normal_from_noise(66, 0.2, 5.0)
		_:
			m.albedo_color = Color(1, 0, 1)
	_cache[key] = m
	return m

const KEYS := ["wall", "wainscot", "floor", "tile", "tile2", "carpet", "carpet2", "ceiling", "concrete", "wood", "wood_dark", "fabric", "sheet", "cream", "plastic", "metal", "brass", "ceramic", "black", "rug", "moss_ground", "bark", "rock", "moss"]

static func has(key: String) -> bool:
	return key in KEYS

## Same material but with object-space triplanar mapping (for models that move or rotate).
static func mat_local(key: String) -> StandardMaterial3D:
	var k := key + "#local"
	if _cache.has(k):
		return _cache[k]
	var m: StandardMaterial3D = mat(key).duplicate()
	m.uv1_world_triplanar = false
	m.uv1_scale = m.uv1_scale * 1.6
	_cache[k] = m
	return m

static func flat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var k := "flat_%s_%s_%s" % [c.to_html(), rough, metal]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_cache[k] = m
	return m

static func emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

static func label_texture(big: String, small: String) -> ImageTexture:
	# cream VHS label with a red stripe; text is drawn by a Label3D on top
	var img := Image.create(64, 24, false, Image.FORMAT_RGB8)
	img.fill(Color(0.90, 0.86, 0.77))
	for y in 4:
		for x in 64:
			img.set_pixel(x, y, Color(0.72, 0.25, 0.18))
	return _img_tex(img)
