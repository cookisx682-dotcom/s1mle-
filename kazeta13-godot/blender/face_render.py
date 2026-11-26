"""Renders a close-up of Hosť's face for jumpscares: face_render.py <models_dir> <out.png>"""
import math, sys
import bpy
from mathutils import Vector
a = [x for x in sys.argv[1:] if not x.endswith(".py")]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a[0] + "/m_host.glb")
head = bpy.data.objects["head"]
bpy.context.view_layer.update()
hc = head.matrix_world.translation.copy()
sc = bpy.context.scene
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 38
cam.location = hc + Vector((0.04, -0.62, -0.02))
cam.rotation_euler = (hc + Vector((0, 0, -0.03)) - cam.location).to_track_quat("-Z", "Y").to_euler()
def light(loc, e, col, size):
    l = bpy.data.lights.new("l", "AREA"); l.energy = e; l.color = col; l.size = size
    o = bpy.data.objects.new("l", l); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (hc - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
light(hc + Vector((0.0, -0.6, -0.5)), 14, (1.0, 0.9, 0.75), 0.3)    # flashlight from below
light(hc + Vector((0.4, 0.3, 0.3)), 6, (0.9, 0.2, 0.15), 0.5)
w = bpy.data.worlds.new("w"); sc.world = w; w.color = (0, 0, 0)
sc.render.engine = "CYCLES"; sc.cycles.samples = 48; sc.cycles.use_denoising = True
sc.render.resolution_x = 640; sc.render.resolution_y = 800
sc.view_settings.view_transform = "Standard"
sc.render.filepath = a[1]
bpy.ops.render.render(write_still=True)
