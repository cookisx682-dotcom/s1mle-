# Kazeta 13 – Godot demo (deň 1)

3D verzia hry Kazeta 13 v Godote 4.3.

- `blender/build_models.py` – všetky modely (nábytok, dvere, postavy, ruka s baterkou, plachty cez cloth simuláciu)
- `blender/build_menu.py` – scéna hlavného menu (les, televízor GOOD LUCK)
- `models/` – vyexportované `.glb`
- `scripts/main.gd` – hra, `scripts/tex.gd` – textúry, `scripts/synth.gd` – zvuky

Modely znova vygeneruješ:

```
blender -b -P blender/build_models.py -- models
blender -b -P blender/build_menu.py -- models
```

Export: Godot → Project → Export → Windows Desktop / Linux.

Ovládanie: WASD, myš, E použiť, F baterka, Shift beh, Esc pauza.
