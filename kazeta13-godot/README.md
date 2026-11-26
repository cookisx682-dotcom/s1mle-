# Kazeta 13 – Godot

Celá hra Kazeta 13 v 3D (Godot 4.3): 7 dní, 6 príšer, kazety, hádanky, 3 konce.

- `blender/build_models.py` – všetky modely (nábytok, dvere, postavy, ruka s baterkou, plachty cez cloth simuláciu)
- `blender/build_menu.py` – scéna hlavného menu (les, televízor GOOD LUCK)
- `blender/build_monsters.py` – 6 príšer (Hosť, Mäsiar, Matka, Sestra, Dvojník, Hlásateľ) so zapečenými textúrami
- `blender/preview.py` – náhľad modelu v Cycles
- `models/` – vyexportované `.glb`
- `scripts/main.gd` – menu, galéria, nastavenia, ukladanie
- `scripts/world.gd` – dom, pivnica, nemocnica, svety kaziet
- `scripts/game.gd` – hráč, dni, kazety, príšery, strašenie, konce
- `scripts/ui.gd` – HUD, taška, denník, mapa, hádanky, návod, titulky
- `scripts/audio.gd`, `scripts/synth.gd` – zvuky, `scripts/tex.gd` – textúry
- `art/make_art.py` – obrazy, fotky, kresby

Modely znova vygeneruješ:

```
blender -b -P blender/build_models.py -- models
blender -b -P blender/build_menu.py -- models
blender -b -P blender/build_monsters.py -- models
```

Export: Godot → Project → Export → Windows Desktop / Linux.

Ovládanie: WASD, myš, E použiť, F baterka, Shift beh, Esc pauza.
