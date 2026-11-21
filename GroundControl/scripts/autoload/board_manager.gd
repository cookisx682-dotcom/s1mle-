extends Node
## BoardManager (autoload)
## The evidence board. Every discovered fact becomes a card (res://data/cards.json).
## The player pins cards and ties two of them with red string. If the pair matches a
## deduction (res://data/deductions.json) a new deduction card appears — deduction cards can
## be tied again, so deductions can chain. A wrong pair costs in-game time.

signal card_discovered(card_id: String)
signal board_changed
signal link_created(a: String, b: String, deduction_id: String)
signal link_failed(a: String, b: String)
signal deduction_found(deduction_id: String)

const DataLoader = preload("res://scripts/core/data_loader.gd")
const CARDS_PATH := "res://data/cards.json"
const DEDUCTIONS_PATH := "res://data/deductions.json"

var static_cards: Dictionary = {}     # id -> card data from cards.json
var dynamic_cards: Dictionary = {}    # id -> card data created at runtime (missions, deductions)
var deductions_db: Array = []
var wrong_penalty_minutes := 20.0

var discovered: Array = []            # card ids in discovery order
var pinned: Dictionary = {}           # card id -> Vector2 (board coordinates)
var links: Array = []                 # [card_a, card_b, deduction_id]
var deductions_found: Array = []
var failed_pairs: Array = []          # "a|b" keys already tried (no double penalty)
var _full_wall_sent := false


func _ready() -> void:
	var c: Variant = DataLoader.load_json(CARDS_PATH, {})
	if c is Dictionary:
		static_cards = (c as Dictionary).get("cards", {})
	var d: Variant = DataLoader.load_json(DEDUCTIONS_PATH, {})
	if d is Dictionary:
		deductions_db = (d as Dictionary).get("deductions", [])
		wrong_penalty_minutes = float((d as Dictionary).get("wrong_link_penalty_minutes", 20.0))


func reset() -> void:
	dynamic_cards = {}
	discovered = []
	pinned = {}
	links = []
	deductions_found = []
	failed_pairs = []
	_full_wall_sent = false
	board_changed.emit()


# ---------------------------------------------------------------- cards

func get_card(card_id: String) -> Dictionary:
	if dynamic_cards.has(card_id):
		return dynamic_cards[card_id]
	return static_cards.get(card_id, {})


func has_card(card_id: String) -> bool:
	return static_cards.has(card_id) or dynamic_cards.has(card_id)


func discover(card_id: String) -> void:
	if card_id == "" or discovered.has(card_id):
		return
	if not has_card(card_id):
		push_warning("Unknown card '%s'" % card_id)
		return
	discovered.append(card_id)
	var card := get_card(card_id)
	GameState.add_stat("cards")
	GameState.post_notify("NEW CARD → BOARD: %s" % str(card.get("title", card_id)), "card")
	AudioManager.play_sfx("paper")
	card_discovered.emit(card_id)
	GameState.emit_event("card_discovered", {"id": card_id, "type": str(card.get("type", ""))})
	board_changed.emit()


## Runtime cards (e.g. procedural mission results). They never count toward "Full Wall".
func add_dynamic_card(card_id: String, data: Dictionary) -> void:
	var d := data.duplicate(true)
	d["optional"] = true
	dynamic_cards[card_id] = d


func inbox() -> Array:
	var result: Array = []
	for id in discovered:
		if not pinned.has(id):
			result.append(id)
	return result


func pin(card_id: String, pos: Vector2) -> void:
	if not discovered.has(card_id):
		return
	var first_time := not pinned.has(card_id)
	pinned[card_id] = pos
	if first_time:
		AudioManager.play_sfx("card_pin")
		GameState.emit_event("card_pinned", {"id": card_id})
	board_changed.emit()
	_check_full_wall()


func get_pin_pos(card_id: String) -> Vector2:
	var p: Variant = pinned.get(card_id, Vector2.ZERO)
	return p if p is Vector2 else Vector2.ZERO


## Static, non-optional cards — the set needed for the "Full Wall" achievement.
func required_cards() -> Array:
	var result: Array = []
	for id in static_cards.keys():
		var c: Dictionary = static_cards[id]
		if not bool(c.get("optional", false)):
			result.append(str(id))
	return result


func _check_full_wall() -> void:
	if _full_wall_sent:
		return
	for id in required_cards():
		if not pinned.has(id):
			return
	_full_wall_sent = true
	GameState.emit_event("board_full", {})


# ---------------------------------------------------------------- links / deductions

func total_deductions() -> int:
	return deductions_db.size()


func is_linked(a: String, b: String) -> bool:
	for l in links:
		if (l[0] == a and l[1] == b) or (l[0] == b and l[1] == a):
			return true
	return false


## Tries to tie two pinned cards. Returns the deduction id, or "" when the link is wrong.
func try_connect(a: String, b: String) -> String:
	if a == b or a == "" or b == "":
		return ""
	if is_linked(a, b):
		return "already"
	for d in deductions_db:
		var pair: Array = d.get("cards", [])
		if pair.size() != 2:
			continue
		var match_pair := (str(pair[0]) == a and str(pair[1]) == b) or (str(pair[0]) == b and str(pair[1]) == a)
		if not match_pair:
			continue
		var did := str(d.get("id", ""))
		if deductions_found.has(did):
			return "already"
		if not GameState.check_condition(d.get("if", null)):
			continue
		_create_deduction(d, a, b)
		return did
	# wrong link
	var key := a + "|" + b if a < b else b + "|" + a
	link_failed.emit(a, b)
	AudioManager.play_sfx("string_fail")
	if not failed_pairs.has(key):
		failed_pairs.append(key)
		GameState.add_stat("wrong_links")
		TimeManager.add_penalty_minutes(wrong_penalty_minutes)
	return ""


func _create_deduction(d: Dictionary, a: String, b: String) -> void:
	var did := str(d.get("id", ""))
	deductions_found.append(did)
	links.append([a, b, did])
	dynamic_cards[did] = {
		"type": "deduction",
		"title": str(d.get("title", "Deduction")),
		"text": str(d.get("text", "")),
		"optional": true,
	}
	discovered.append(did)
	# place the new card between its two parents
	var pa := get_pin_pos(a)
	var pb := get_pin_pos(b)
	var mid := (pa + pb) * 0.5 + Vector2(0, 46)
	pinned[did] = Vector2(clampf(mid.x, 0.0, 530.0), clampf(mid.y, 0.0, 200.0))
	GameState.add_stat("deductions")
	AudioManager.play_sfx("string_ok")
	GameState.post_notify("DEDUCTION: %s" % str(d.get("title", "")), "story")
	link_created.emit(a, b, did)
	deduction_found.emit(did)
	board_changed.emit()
	GameState.emit_event("deduction_found", {"id": did})
	GameState.apply_effects(d.get("effects", []))


# ---------------------------------------------------------------- save / load

func serialize() -> Dictionary:
	var pins := {}
	for id in pinned.keys():
		var p := get_pin_pos(str(id))
		pins[id] = [p.x, p.y]
	return {
		"discovered": discovered.duplicate(),
		"pinned": pins,
		"links": links.duplicate(true),
		"deductions_found": deductions_found.duplicate(),
		"dynamic_cards": dynamic_cards.duplicate(true),
		"failed_pairs": failed_pairs.duplicate(),
		"full_wall": _full_wall_sent,
	}


func deserialize(d: Dictionary) -> void:
	reset()
	discovered = (d.get("discovered", []) as Array).duplicate()
	links = (d.get("links", []) as Array).duplicate(true)
	deductions_found = (d.get("deductions_found", []) as Array).duplicate()
	dynamic_cards = (d.get("dynamic_cards", {}) as Dictionary).duplicate(true)
	failed_pairs = (d.get("failed_pairs", []) as Array).duplicate()
	_full_wall_sent = bool(d.get("full_wall", false))
	var pins: Dictionary = d.get("pinned", {})
	for id in pins.keys():
		var arr: Array = pins[id]
		if arr.size() >= 2:
			pinned[str(id)] = Vector2(float(arr[0]), float(arr[1]))
	board_changed.emit()
