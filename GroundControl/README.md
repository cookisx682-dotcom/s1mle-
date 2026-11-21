# GROUND CONTROL — demo v0.1
*1969 · · · 2069* — Decade I demo (1971, three night shifts)

A first-person story game in a space-agency control room. You never walk: you sit at your
desk and turn your head between five stations. Mia Halloran is alone on the Moon and you are
the only voice she hears. Something under the surface is transmitting.

## 1. Open & run
1. Install **Godot 4.3** or newer (standard build, GDScript — no .NET needed). Works on Linux (CachyOS) and Windows.
2. Unzip `GroundControl_v0.1.zip`, open Godot → **Import** → pick `project.godot`.
3. First import takes a few seconds. Press **F5** (main scene = `scenes/main_menu.tscn`).

Renderer: *Compatibility* (OpenGL 3.3) so it runs on almost any GPU. You can switch to
Forward+ in Project Settings → Rendering if you want; nothing depends on it.

## 2. Controls
| input | action |
|---|---|
| Mouse | look around (yaw ±160°, pitch ±35°, smoothed) |
| A / D or ← / → | jump to the neighbouring station |
| Left click | use the station you are looking at (camera zooms in) |
| Right click / ESC | leave the station (zoom out) |
| ESC (looking around) | pause menu |
| 1 / 2 / 3 | answer a crisis |
| SPACE / ENTER | continue dialogue, skip typing |

## 3. Stations & mechanics
| station | what you do |
|---|---|
| **Radio console** (front) | talk to Mia (branching choices change her *rapport* 0–100), system levers (heating, hab lights, rover, helmet cam), dictate repair steps, ping Mia |
| **Monitors** (front-left) | terrain map (click a cell to send Mia), life support (O2 / power / temperature), helmet camera, technical manual |
| **Evidence board** (left) | drag cards from the inbox onto the cork, click two pinned cards to tie red string. Correct pair → deduction card (can be chained). Wrong pair → −20 in-game minutes |
| **Hall window** (right) | colleagues / flight director show up with messages and orders |
| **Phone / fax** (back-right) | orders from HQ; some ask you to choose (comply or not) |

* **Resources** — oxygen and power drain all shift. Every system costs power; switch off what you
  don't need. Cold habitat → Mia uses more O2. No power → all systems shut down.
* **Navigation** — Mia describes a target relative to a landmark. With the helmet cam ON a green
  3×3 box narrows it down. Right cell = quick trip; wrong cell = wasted oxygen. Rover off = walking (slower, more O2).
* **Repairs** — the manual on the monitors lists steps in order; dictate them at the console.
* **Crises** — random timed emergencies (suit pressure, signal dropout, micrometeorite, power surge).
* **Side missions** — procedurally generated from templates (random landmarks, directions, briefs).
* **Shift** — 10–11 minutes of real time (20:00 → 04:00 in-game). Ends with a report and a grade.
  Near the end the clock *holds* while story items are still pending, so nothing important is skipped.
* **Saving** — `user://save.json` is written at the start of every shift (checkpoint) and whenever an
  achievement unlocks. *Continue* restarts the current shift. *New Game* keeps achievements.
  Settings live in `user://settings.json`.

## 4. Project structure
```
project.godot            autoloads, renderer, window
scenes/                  main_menu.tscn, game.tscn (thin roots — everything is built in code)
scripts/
  autoload/              GameState, TimeManager, DialogueManager, BoardManager, ResourceManager,
                         MissionGenerator, EventManager, AchievementManager, SaveSystem, AudioManager
  core/data_loader.gd    JSON helper
  world/                 control_room.gd (room from primitives, era styles), camera_rig.gd, interactable.gd
  ui/                    hud, crisis banner, menus, intro/ending cards, ui_theme.gd (palette + Theme)
  ui/overlays/           one overlay per station + daily report + board card/strings
  ui/screens/            custom-drawn CRT screens (shared by 3D monitors and overlays)
  game.gd, main_menu.gd
data/                    days, dialogues, cards, deductions, missions, events, achievements (JSON)
shaders/                 pixelate (post), crt (3D screens), crt_canvas (2D), outline, blur, cork
audio/                   sfx / music / ambience — empty, see README in each folder
```
Visual pipeline: the 3D room renders into a 480×270 SubViewport → scaled with nearest filter →
`pixelate.gdshader` (colour reduction, Bayer dithering, noise, vignette). Station UIs render at half
resolution in their own SubViewport (+ CRT shader on screen-type stations).

## 5. Adding content (JSON only)
All content is data-driven. Two building blocks are shared by every file:

**Effects** (lists of actions): `trust`, `flag`, `card`, `dialogue`, `say`, `fax`, `visitor`, `crisis`,
`mission`, `oxygen` (with `"waste": true`), `power`, `system`, `time`, `achievement`, `notify`, `event`,
`stat`, `sound`, `ending`, `end_day`, `delay` (`{"type":"delay","seconds":4,"effects":[...]}`).
Any effect may have `"if": <condition>`.

**Conditions**: `flag`, `not_flag`, `min_trust`, `max_trust`, `card`, `deduction`, `no_deduction`,
`min_day`, `any` (OR). Values may be a single id or a list.

### New day — `data/days.json`
Append an object to `"days"`:
```json
{
  "id": "day4", "date": "MARCH 6, 1971", "date_short": "06 MAR 1971",
  "title": "SHIFT 4 — ...", "era": "1970s", "shift_minutes": 10,
  "clock_start": "20:00", "clock_end": "04:00",
  "intro": ["line 1", "line 2"],
  "resources": {"oxygen": 100, "power": 90, "temperature": 20},
  "timeline": [ {"at": 0.05, "effects": [{"type": "dialogue", "id": "d4_intro"}]} ],
  "triggers": [ {"on": "deduction_found", "match": {"id": "ded_x"}, "effects": [...]} ],
  "random_crises": {"count": [1, 2], "pool": ["c_o2_spike"], "window": [0.3, 0.8]},
  "side_missions": {"count": [1, 1], "window": [0.3, 0.7]}
}
```
`at` is the fraction of the shift (0–1). `era` restyles the room (`"1970s"`, `"1980s"` — add more in
`control_room.gd::_palette`). Days run in array order; after the last one the ending from `"endings"`
plays (chosen with the `ending` effect).

### New card — `data/cards.json`
```json
"c_new_card": {"type": "measurement", "title": "Short title", "text": "Full text.", "day": 4}
```
Types: `report`, `measurement`, `photo`, `fax`, `sample`. Add `"optional": true` if it should not count
toward *Full Wall*. Give it to the player with `{"type": "card", "id": "c_new_card"}` (or `"card"` on a fax).

### New deduction — `data/deductions.json`
```json
{"id": "ded_new", "cards": ["c_a", "c_b"], "title": "...", "text": "...", "effects": [...]}
```
Either card may itself be a deduction id → chains.

### New achievement — `data/achievements.json`
```json
{"id": "my_ach", "icon": "**", "title": "Title", "description": "...", "trigger": {"on": "flag_set", "match": {"flag": "x"}}}
```
Events you can listen to: `day_started`, `day_report`, `card_discovered`, `card_pinned`, `board_full`,
`deduction_found`, `dialogue_finished`, `trust_changed`, `flag_set`, `crisis_started`, `crisis_resolved`,
`mission_started`, `mission_finished`, `navigation_success`, `fax_answered`, `visitor_acknowledged`,
`system_toggled`, `demo_complete` and any custom `{"type": "event"}`. `match` keys with `min_`/`max_`
compare numbers. You can also unlock directly: `{"type": "achievement", "id": "my_ach"}`.

### New mission — `data/missions.json`
* Procedural side mission: add a template with `"random": true` and a `weight`.
  Navigation briefs may use `{landmark}`, `{dir}`, `{dist}`, `{n}`.
* Repair: `"type": "repair"`, `"manual"`, ordered `"steps"`, wrong `"distractors"`, `"mistake_effects"`.
* Story mission: fixed `"landmarks"` + `"target"`, `"story": true`, start it with
  `{"type": "mission", "template": "id"}`. Hooks: `on_success`, `on_fail`, `on_complete`; `card_id` or a `card` template.

### New dialogue — `data/dialogues.json`
```json
"d4_intro": {"speaker": "MIA", "start": "start", "nodes": {
  "start": {"text": "...", "variants": [{"if": {"min_trust": 70}, "text": "..."}],
            "choices": [{"text": "...", "next": "a", "effects": [{"type": "trust", "value": 5}]}]},
  "a": {"text": "...", "end": true}
}}
```
Crises, colleagues at the window and faxes go into `data/events.json` (see existing entries).

## 6. Placeholders / known limitations (v0.1)
* **Audio** — no audio files ship; every SFX is a synthesized beep, the room tone is a generated hum,
  music is silent. See `audio/*/README.md` for names.
* **Art** — everything is primitives (boxes, cylinders, capsules). The colleague behind the window is a
  capsule figure; the helmet camera and the plot board are procedural drawings.
* **Font** — uses a system monospace font (DejaVu Sans Mono / Consolas…) instead of a bundled pixel font.
* **Saving** is a checkpoint at the start of each shift (not mid-shift).
* **1986 preview** is a short cinematic only (restyled room + captions), not playable.
* No voice acting, no localisation (texts are English), no gamepad support yet.
* Export: when exporting, add `*.json` to *Resources → Filters to export non-resource files*.
