"""Cycles turntable-style preview of exported monsters: preview.py <glb> <out.png> [angle_deg]"""
import math, sys
import bpy
from mathutils import Vector
a = [x for x in sys.argv[1:] if not x.endswith("preview.py")]
glb, out = a[0], a[1]
ang = math.radians(float(a[2])) if len(a) > 2 else 0.35
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
ctr = (mn + mx) / 2; h = mx.z - mn.z
zoom = float(a[3]) if len(a) > 3 else 1.0
if zoom > 1.0:
    ctr.z = mx.z - h / zoom * 0.5; h = h / zoom
sc = bpy.context.scene
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
d = h * 1.75
cam.location = ctr + Vector((math.sin(ang) * d, -math.cos(ang) * d, h * 0.05))
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
def light(kind, loc, energy, color=(1, 1, 1), size=1.0):
    l = bpy.data.lights.new(kind, kind); l.energy = energy; l.color = color
    if kind == "AREA": l.size = size
    o = bpy.data.objects.new(kind, l); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (ctr - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
light("AREA", ctr + Vector((-1.5, -2.0, 1.2)), 120, (1.0, 0.85, 0.65), 1.5)
light("AREA", ctr + Vector((2.0, 1.5, 0.8)), 90, (0.5, 0.6, 1.0), 1.0)
light("AREA", ctr + Vector((1.2, -1.5, -0.5)), 20, (1, 1, 1), 1.0)
w = bpy.data.worlds.new("w"); sc.world = w; w.color = (0.015, 0.015, 0.018)
sc.render.engine = "CYCLES"; sc.cycles.samples = 24; sc.cycles.use_denoising = True
sc.render.resolution_x = 520; sc.render.resolution_y = 760
sc.view_settings.view_transform = "AgX"
sc.render.filepath = out
bpy.ops.render.render(write_still=True)
