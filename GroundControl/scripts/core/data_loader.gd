extends RefCounted
## Tiny helper for reading JSON data files from res://data.
## Returns `fallback` when the file is missing or invalid, so a broken data file
## prints an error instead of crashing the game.


static func load_json(path: String, fallback: Variant = {}) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("Data file not found: %s" % path)
		return fallback
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open data file: %s" % path)
		return fallback
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed == null:
		push_error("Invalid JSON in %s" % path)
		return fallback
	return parsed


## Accepts a single value or an Array and always returns an Array.
static func as_list(v: Variant) -> Array:
	if v == null:
		return []
	if v is Array:
		return v
	return [v]
