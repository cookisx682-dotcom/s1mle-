"""Kazeta 13 - builds all 3D models in Blender and exports them as .glb for Godot.

Run:  blender --background --python build_models.py -- <out_dir>
  or: python3 build_models.py <out_dir>   (with the bpy module installed)

All coordinates below are written in Godot space (x right, y up, -z forward)
and converted to Blender space by G()/S().
"""
import math
import os
import sys

import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh
from mathutils import Matrix, Vector

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "models"
os.makedirs(OUT, exist_ok=True)


def G(x, y, z):
    return Vector((x, -z, y))


def S(x, y, z):
    return Vector((x, z, y))


# ---------------------------------------------------------------- materials
MATS = {}


def M(name, color=(0.5, 0.5, 0.5), rough=0.8, metal=0.0, emit=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    MATS[name] = m
    return m


def default_mats():
    # names that match Tex.mat() keys are re-textured procedurally in Godot
    M("wood", (0.29, 0.19, 0.12), 0.5)
    M("wood_dark", (0.16, 0.10, 0.06), 0.45)
    M("fabric", (0.40, 0.31, 0.19), 1.0)
    M("sheet", (0.78, 0.75, 0.69), 0.97)
    M("cream", (0.82, 0.79, 0.71), 0.35)
    M("plastic", (0.09, 0.09, 0.085), 0.4)
    M("metal", (0.6, 0.6, 0.58), 0.35, 0.8)
    M("brass", (0.69, 0.55, 0.27), 0.3, 0.9)
    M("ceramic", (0.88, 0.86, 0.80), 0.12)
    M("black", (0.02, 0.02, 0.02), 1.0)
    M("glass_dark", (0.03, 0.035, 0.04), 0.05, 0.6)
    M("clock_face", (0.86, 0.83, 0.74), 0.5)
    M("screen", (0.1, 0.1, 0.1), 0.2)
    M("linen", (0.85, 0.84, 0.80), 0.9)
    M("blanket_blue", (0.24, 0.35, 0.50), 0.95)
    M("blanket_red", (0.38, 0.10, 0.10), 0.95)
    M("lens", (1.0, 0.95, 0.85), 0.1, 0.0, 2.0)


# ---------------------------------------------------------------- helpers
def reset():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    MATS.clear()
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    default_mats()


def _obj(name, bm, mat, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    me.materials.append(MATS[mat] if isinstance(mat, str) else mat)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return o


def bevel(o, w, segs=2):
    m = o.modifiers.new("bevel", "BEVEL")
    m.width = w
    m.segments = segs
    m.limit_method = "ANGLE"
    return o


def subsurf(o, lvl=2):
    m = o.modifiers.new("subsurf", "SUBSURF")
    m.levels = lvl
    m.render_levels = lvl
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def box(name, size, pos, mat, bev=0.008, rot=(0, 0, 0), segs=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    s = S(*size)
    bmesh.ops.scale(bm, vec=s, verts=bm.verts)
    o = _obj(name, bm, mat)
    o.location = G(*pos)
    o.rotation_euler = (rot[0], -rot[2], rot[1])
    if bev > 0:
        bevel(o, min(bev, min(size) * 0.45), segs)
    return o


def cyl(name, r1, r2, h, pos, mat, rot=(0, 0, 0), seg=24, caps=True, smooth=True):
    """Cylinder along Godot Y (r1 = bottom, r2 = top)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=h)
    o = _obj(name, bm, mat, smooth)
    o.location = G(*pos)
    o.rotation_euler = (rot[0], -rot[2], rot[1])
    return o


def sphere(name, r, pos, mat, scale=(1, 1, 1), seg=24):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=r)
    o = _obj(name, bm, mat, True)
    o.location = G(*pos)
    o.scale = S(*scale)
    return o


def boolean(o, cutter):
    m = o.modifiers.new("bool", "BOOLEAN")
    m.object = cutter
    m.operation = "DIFFERENCE"
    m.solver = "EXACT"
    cutter.hide_render = True
    cutter.hide_viewport = True
    return o


def bake(o):
    """Apply all modifiers of o (incl. cloth at the current frame)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    o.modifiers.clear()
    old = o.data
    o.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return o


def export(name):
    for o in list(bpy.data.objects):
        if o.hide_viewport:
            bpy.data.objects.remove(o, do_unlink=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False,
                              export_apply=True, export_animations=False, export_yup=True)
    print("exported", path)


# ---------------------------------------------------------------- furniture
def sofa(w=2.2, name="sofa"):
    parts = []
    parts.append(box("base", (w - 0.2, 0.2, 0.8), (0, 0.2, 0), "fabric", 0.03))
    for sx in (-1, 1):
        for sz in (-1, 1):
            cyl("leg", 0.02, 0.028, 0.1, (sx * (w / 2 - 0.12), 0.05, sz * 0.32), "wood_dark", seg=12)
    n = 3 if w > 1.5 else 1
    cw = (w - 0.44) / n
    for i in range(n):
        x = -((w - 0.44) / 2) + cw * (i + 0.5)
        c = box("seat", (cw - 0.02, 0.16, 0.66), (x, 0.38, -0.05), "fabric", 0.04, segs=1)
        subsurf(c)
        b = box("back", (cw - 0.02, 0.46, 0.2), (x, 0.66, 0.26), "fabric", 0.05, rot=(-0.18, 0, 0), segs=1)
        subsurf(b)
    box("frame", (w, 0.62, 0.2), (0, 0.55, 0.34), "fabric", 0.05)
    for s in (-1, 1):
        a = box("arm", (0.2, 0.6, 0.86), (s * (w / 2 - 0.1), 0.32, 0), "fabric", 0.07, segs=1)
        subsurf(a)
    return parts


def cloth_sheet(w, d, height, name, sofa_w):
    """Drop a sheet over a sofa-shaped collision proxy (cloth simulation)."""
    for o in list(bpy.context.scene.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    proxies = [box("p_seat", (sofa_w, 0.46, 0.86), (0, 0.23, 0), "black", 0.04),
               box("p_back", (sofa_w, 0.9, 0.24), (0, 0.45, 0.33), "black", 0.05),
               box("p_arm_l", (0.22, 0.64, 0.86), (-sofa_w / 2 + 0.11, 0.32, 0), "black", 0.06),
               box("p_arm_r", (0.22, 0.64, 0.86), (sofa_w / 2 - 0.11, 0.32, 0), "black", 0.06)]
    for o in proxies:
        bake(o)
        o.modifiers.new("col", "COLLISION")
        o.collision.thickness_outer = 0.025
        o.collision.cloth_friction = 15
    floor = box("floor", (6, 0.1, 6), (0, -0.05, 0), "black", 0)
    floor.modifiers.new("col", "COLLISION")
    bm = bmesh.new()
    res = 0.045
    bmesh.ops.create_grid(bm, x_segments=int(w / res), y_segments=int(d / res), size=0.5)
    bmesh.ops.scale(bm, vec=Vector((w, d, 1)), verts=bm.verts)
    sh = _obj(name, bm, "sheet", True)
    sh.location = G(0, height, 0)
    cl = sh.modifiers.new("cloth", "CLOTH")
    cl.settings.quality = 12
    cl.collision_settings.collision_quality = 5
    cl.settings.mass = 0.3
    cl.settings.tension_stiffness = 8
    cl.settings.compression_stiffness = 8
    cl.settings.bending_stiffness = 0.2
    cl.settings.air_damping = 1.0
    cl.collision_settings.distance_min = 0.012
    cl.collision_settings.use_self_collision = False
    sc = bpy.context.scene
    sc.frame_start = 1
    sc.frame_end = 80
    cl.point_cache.frame_end = 80
    for f in range(1, 61):
        sc.frame_set(f)
    bake(sh)
    so = sh.modifiers.new("solid", "SOLIDIFY")
    so.thickness = 0.008
    subsurf(sh, 1)
    bake(sh)
    for o in list(bpy.context.scene.objects):
        if o != sh:
            bpy.data.objects.remove(o, do_unlink=True)


def chair():
    box("seat", (0.44, 0.045, 0.44), (0, 0.45, 0), "wood", 0.012)
    for a in (-1, 1):
        for b in (-1, 1):
            cyl("leg", 0.022, 0.016, 0.43, (a * 0.18, 0.215, b * 0.18), "wood", seg=10)
    for a in (-1, 1):
        cyl("post", 0.02, 0.018, 0.5, (a * 0.19, 0.72, -0.2), "wood", seg=10)
    for y in (0.66, 0.8):
        box("slat", (0.38, 0.04, 0.02), (0, y, -0.2), "wood", 0.006)
    box("top", (0.44, 0.08, 0.035), (0, 0.95, -0.2), "wood", 0.015)
    for a in (-1, 1):
        box("stretcher", (0.02, 0.02, 0.34), (a * 0.18, 0.12, 0), "wood", 0)


def table():
    box("top", (1.6, 0.045, 0.9), (0, 0.75, 0), "wood", 0.012, segs=3)
    box("apron", (1.42, 0.1, 0.74), (0, 0.67, 0), "wood", 0.005)
    for a in (-1, 1):
        for b in (-1, 1):
            cyl("leg", 0.035, 0.024, 0.71, (a * 0.71, 0.355, b * 0.36), "wood", seg=4, smooth=False)


def tv():
    # cabinet
    box("cab", (1.5, 0.5, 0.55), (0, 0.25, 0), "wood_dark", 0.01)
    for x in (-0.37, 0.37):
        box("door_line", (0.006, 0.4, 0.004), (x, 0.25, 0.276), "black", 0)
        cyl("knob", 0.012, 0.012, 0.02, (x + (0.05 if x < 0 else -0.05), 0.3, 0.285), "brass", rot=(math.pi / 2, 0, 0), seg=10)
    # CRT
    box("bezel", (0.88, 0.66, 0.12), (0, 0.83, 0.24), "plastic", 0.035, segs=3)
    sh = box("shell", (0.76, 0.56, 0.36), (0, 0.84, 0.0), "plastic", 0.06, segs=3)
    box("tube", (0.5, 0.4, 0.22), (0, 0.85, -0.26), "plastic", 0.06, segs=3)
    # recessed screen area and curved screen
    box("inset", (0.7, 0.53, 0.02), (0, 0.85, 0.296), "black", 0.01)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=24, y_segments=18, size=0.5)
    for v in bm.verts:
        x, y = v.co.x, v.co.y
        v.co = Vector((x * 0.66, 0, y * 0.5))
        v.co.y = -0.018 * (1 - (2 * x) ** 2 * 0.6) * (1 - (2 * y) ** 2 * 0.6)
    scr = _obj("screen", bm, "screen", True)
    scr.location = G(0, 0.85, 0.3)
    # uv for the static shader
    uvl = scr.data.uv_layers.new(name="UVMap")
    for loop in scr.data.loops:
        co = scr.data.vertices[loop.vertex_index].co
        uvl.data[loop.index].uv = (co.x / 0.66 + 0.5, co.z / 0.5 + 0.5)
    for i, y in enumerate((0.72, 0.8)):
        cyl("knob", 0.022, 0.02, 0.025, (0.39, y, 0.31), "metal", rot=(math.pi / 2, 0, 0), seg=16)
    box("led", (0.02, 0.01, 0.01), (0.39, 0.63, 0.3), MATS["lens"], 0)
    # VCR
    box("vcr", (0.42, 0.09, 0.3), (-0.5, 0.545, 0.05), "plastic", 0.01)
    box("slot", (0.24, 0.018, 0.01), (-0.52, 0.56, 0.2), "black", 0.002)
    box("vcr_disp", (0.08, 0.02, 0.006), (-0.36, 0.56, 0.2), "glass_dark", 0)
    # rabbit ears antenna
    cyl("ant_base", 0.05, 0.04, 0.03, (0.1, 1.175, -0.05), "plastic", seg=16)
    for s in (-1, 1):
        cyl("ant", 0.003, 0.002, 0.6, (0.1 + s * 0.14, 1.43, -0.05), "metal", rot=(0, 0, s * -0.5), seg=6)


def fridge():
    b = box("body", (0.72, 1.8, 0.66), (0, 0.9, 0), "cream", 0.07, segs=4)
    box("gap", (0.7, 0.008, 0.01), (0, 1.2, 0.332), "black", 0)
    for y in (1.45, 0.75):
        box("handle", (0.03, 0.22, 0.04), (0.28, y, 0.36), "metal", 0.01)
    box("badge", (0.12, 0.025, 0.005), (0, 1.66, 0.333), "metal", 0)
    for x in (-0.3, 0.3):
        box("foot", (0.06, 0.04, 0.06), (x, 0.02, 0.25), "black", 0)


def stove():
    box("body", (0.76, 0.86, 0.62), (0, 0.45, 0), "cream", 0.02)
    box("top", (0.78, 0.03, 0.64), (0, 0.885, 0), "metal", 0.005)
    for x in (-0.18, 0.18):
        for z in (-0.13, 0.13):
            cyl("burner", 0.09, 0.08, 0.02, (x, 0.905, z), "black", seg=20)
    box("oven", (0.56, 0.36, 0.01), (0, 0.42, 0.312), "glass_dark", 0.004)
    box("bar", (0.5, 0.025, 0.03), (0, 0.66, 0.33), "metal", 0.008)
    for i in range(4):
        cyl("knob", 0.02, 0.018, 0.03, (-0.24 + i * 0.16, 0.78, 0.32), "black", rot=(math.pi / 2, 0, 0), seg=12)


def counter():
    box("base", (4.8, 0.84, 0.6), (0, 0.42, 0), "wood_dark", 0.006)
    box("top", (4.84, 0.04, 0.64), (0, 0.88, 0), "cream", 0.006)
    for i in range(8):
        x = -2.1 + i * 0.6
        box("door", (0.56, 0.62, 0.02), (x, 0.42, 0.31), "wood", 0.01)
        box("handle", (0.012, 0.1, 0.02), (x + 0.22, 0.6, 0.33), "metal", 0.004)
    box("upper", (4.8, 0.7, 0.34), (0, 1.85, -0.16), "wood_dark", 0.006)
    for i in range(8):
        x = -2.1 + i * 0.6
        box("udoor", (0.56, 0.62, 0.02), (x, 1.85, 0.02), "wood", 0.01)
    # sink
    b = box("sink", (0.6, 0.04, 0.45), (1.2, 0.885, 0), "metal", 0.0)
    cut = box("cut", (0.5, 0.3, 0.36), (1.2, 0.8, 0), "metal", 0)
    boolean(b, cut)
    box("basin", (0.5, 0.01, 0.36), (1.2, 0.72, 0), "metal", 0)
    cyl("tap", 0.015, 0.012, 0.25, (1.2, 1.0, -0.22), "metal", seg=12)
    box("spout", (0.025, 0.025, 0.18), (1.2, 1.12, -0.14), "metal", 0.01)


def wardrobe():
    box("body", (1.1, 2.0, 0.6), (0, 1.0, 0), "wood", 0.012)
    box("crown", (1.18, 0.08, 0.66), (0, 2.02, 0.01), "wood_dark", 0.02, segs=3)
    box("plinth", (1.12, 0.1, 0.62), (0, 0.05, 0.01), "wood_dark", 0.01)
    for s in (-1, 1):
        x = s * 0.275
        box("door", (0.53, 1.8, 0.025), (x, 1.0, 0.31), "wood", 0.01)
        for y in (0.55, 1.4):
            box("panel", (0.4, 0.62, 0.02), (x, y, 0.326), "wood_dark", 0.02, segs=3)
        cyl("knob", 0.016, 0.016, 0.03, (s * 0.04, 1.05, 0.34), "brass", rot=(math.pi / 2, 0, 0), seg=12)


def bed(width=1.0, length=2.0, blanket="blanket_blue"):
    hz = length / 2
    box("frame", (width + 0.06, 0.25, length + 0.06), (0, 0.17, 0), "wood_dark", 0.015)
    box("head", (width + 0.1, 0.95, 0.06), (0, 0.48, -hz - 0.02), "wood_dark", 0.02, segs=3)
    box("foot", (width + 0.1, 0.55, 0.06), (0, 0.28, hz + 0.02), "wood_dark", 0.02, segs=3)
    m = box("mattress", (width - 0.02, 0.16, length - 0.04), (0, 0.38, 0), "linen", 0.04, segs=1)
    subsurf(m)
    pc = 2 if width > 1.4 else 1
    for i in range(pc):
        x = 0 if pc == 1 else (-0.45 + i * 0.9)
        p = box("pillow", (0.6, 0.12, 0.38), (x, 0.52, -hz + 0.3), "linen", 0.05, segs=1)
        subsurf(p)
    b = box("blanket", (width + 0.04, 0.06, length * 0.66), (0, 0.48, hz - length * 0.33), blanket, 0.03, segs=1)
    subsurf(b)
    box("fold", (width + 0.04, 0.03, 0.18), (0, 0.52, hz - length * 0.66), "linen", 0.015)


def clock():
    box("case", (0.46, 1.45, 0.34), (0, 0.78, 0), "wood_dark", 0.015)
    box("base", (0.56, 0.12, 0.42), (0, 0.06, 0), "wood_dark", 0.02)
    box("hood", (0.56, 0.6, 0.42), (0, 1.75, 0), "wood_dark", 0.02)
    box("cap", (0.62, 0.06, 0.46), (0, 2.08, 0), "wood_dark", 0.02, segs=3)
    for s in (-1, 1):
        sphere("finial", 0.035, (s * 0.24, 2.15, 0.1), "brass")
    sphere("finial", 0.045, (0, 2.16, 0.1), "brass")
    box("window", (0.26, 0.8, 0.01), (0, 0.85, 0.172), "glass_dark", 0)
    cyl("face", 0.19, 0.19, 0.012, (0, 1.75, 0.212), "clock_face", rot=(math.pi / 2, 0, 0), seg=32)
    cyl("ring", 0.205, 0.205, 0.01, (0, 1.75, 0.208), "brass", rot=(math.pi / 2, 0, 0), seg=32)
    for i in range(12):
        a = i / 12 * math.tau
        box("tick", (0.008, 0.03, 0.004), (math.sin(a) * 0.16, 1.75 + math.cos(a) * 0.16, 0.22), "black", 0, rot=(0, 0, -a))


def shelf():
    box("side_l", (0.03, 2.0, 0.4), (-0.635, 1.0, 0), "wood_dark", 0.005)
    box("side_r", (0.03, 2.0, 0.4), (0.635, 1.0, 0), "wood_dark", 0.005)
    box("back", (1.3, 2.0, 0.02), (0, 1.0, -0.19), "wood_dark", 0)
    for i in range(5):
        box("board", (1.26, 0.025, 0.38), (0, 0.04 + i * 0.48, 0), "wood_dark", 0.004)
    import random
    random.seed(7)
    cols = [(0.35, 0.1, 0.08), (0.12, 0.18, 0.25), (0.2, 0.22, 0.12), (0.3, 0.25, 0.18), (0.15, 0.12, 0.1), (0.4, 0.33, 0.22)]
    for s in range(4):
        x = -0.6
        while x < 0.55:
            w = random.uniform(0.03, 0.07)
            h = random.uniform(0.24, 0.38)
            tilt = 0.25 if random.random() < 0.06 else 0
            c = random.choice(cols)
            mn = "book%d" % cols.index(c)
            M(mn, c, 0.75)
            box("book", (w, h, random.uniform(0.2, 0.28)), (x + w / 2, 0.053 + s * 0.48 + h / 2, 0.02), mn, 0.004, rot=(0, 0, tilt))
            x += w + 0.004 + (0.05 if tilt else 0)


def bathtub():
    t = box("tub", (2.0, 0.56, 0.76), (0, 0.32, 0), "ceramic", 0.0)
    cut = box("cut", (1.86, 0.6, 0.62), (0, 0.6, 0), "ceramic", 0)
    boolean(t, cut)
    bake(t)
    bevel(t, 0.03, 3)
    for sx in (-1, 1):
        for sz in (-1, 1):
            sphere("foot", 0.05, (sx * 0.85, 0.04, sz * 0.28), "brass", (1, 0.8, 1))
    M("water", (0.05, 0.04, 0.03), 0.02, 0.2)
    box("water", (1.86, 0.01, 0.62), (0, 0.42, 0), "water", 0)
    cyl("tap", 0.015, 0.015, 0.2, (-0.9, 0.7, 0), "metal", seg=12)


def sink_bath():
    b = box("bowl", (0.5, 0.14, 0.42), (0, 0.85, 0), "ceramic", 0.0)
    cut = box("cut", (0.4, 0.14, 0.32), (0, 0.9, 0), "ceramic", 0)
    boolean(b, cut)
    bake(b)
    bevel(b, 0.02, 3)
    cyl("ped", 0.06, 0.09, 0.78, (0, 0.39, 0), "ceramic", seg=20)
    cyl("tap", 0.012, 0.012, 0.14, (0, 0.98, -0.17), "metal", seg=10)


def dresser():
    box("body", (1.4, 0.9, 0.5), (0, 0.45, 0), "wood_dark", 0.012)
    for i in range(3):
        y = 0.18 + i * 0.27
        box("drawer", (1.3, 0.23, 0.02), (0, y, 0.255), "wood", 0.01)
        for s in (-1, 1):
            cyl("knob", 0.015, 0.015, 0.025, (s * 0.35, y, 0.275), "brass", rot=(math.pi / 2, 0, 0), seg=10)


def door():
    w, h, t = 0.94, 2.1, 0.05
    box("slab", (w, h, t), (w / 2, h / 2, 0), "wood", 0.006)
    for s in (-1, 1):
        for y in (0.55, 1.5):
            box("panel", (0.32, 0.72 if y > 1 else 0.7, 0.012), (w / 2 + s * 0.2, y, s * 0 + 0.028), "wood", 0.02, segs=3)
            box("panel", (0.32, 0.72 if y > 1 else 0.7, 0.012), (w / 2 + s * 0.2, y, -0.028), "wood", 0.02, segs=3)
    for z in (-1, 1):
        cyl("knob", 0.03, 0.03, 0.06, (w - 0.09, 1.0, z * 0.05), "brass", rot=(math.pi / 2, 0, 0), seg=16)
        sphere("knob_h", 0.032, (w - 0.09, 1.0, z * 0.085), "brass")
        box("plate", (0.04, 0.16, 0.006), (w - 0.09, 1.0, z * 0.028), "brass", 0.004)
    for y in (0.3, 1.8):
        cyl("hinge", 0.012, 0.012, 0.1, (0.0, y, 0.0), "brass", seg=8)


def floor_lamp():
    cyl("base", 0.14, 0.13, 0.03, (0, 0.015, 0), "metal", seg=24)
    cyl("pole", 0.012, 0.012, 1.42, (0, 0.73, 0), "metal", seg=10)
    cyl("socket", 0.025, 0.02, 0.06, (0, 1.42, 0), "black", seg=12)


def shade(r1=0.28, r2=0.13, h=0.24):
    M("lampshade", (1.0, 0.8, 0.55), 0.9)
    o = cyl("shade", r1, r2, h, (0, 0, 0), "lampshade", caps=False, seg=32)
    s = o.modifiers.new("solid", "SOLIDIFY")
    s.thickness = 0.006
    cyl("rim", r1 + 0.004, r1 + 0.004, 0.01, (0, -h / 2, 0), "brass", seg=32, caps=False)
    sphere("bulb", 0.04, (0, -0.04, 0), "lampshade")


def flashlight():
    # points down -Z (Godot forward)
    cyl("body", 0.022, 0.022, 0.18, (0, 0, 0), "plastic", rot=(math.pi / 2, 0, 0), seg=20)
    for i in range(3):
        cyl("grip", 0.0228, 0.0228, 0.004, (0, 0, 0.07 - i * 0.012), "black", rot=(math.pi / 2, 0, 0), seg=20)
    cyl("head", 0.023, 0.034, 0.06, (0, 0, -0.12), "metal", rot=(math.pi / 2, 0, 0), seg=24)
    cyl("lens", 0.03, 0.03, 0.004, (0, 0, -0.151), "lens", rot=(math.pi / 2, 0, 0), seg=24)
    cyl("cap", 0.022, 0.02, 0.02, (0, 0, 0.1), "metal", rot=(math.pi / 2, 0, 0), seg=16)
    box("switch", (0.012, 0.008, 0.02), (0, 0.024, -0.04), "black", 0.003)


def hand_flashlight():
    """First-person right hand gripping the flashlight (flashlight points -Z)."""
    flashlight()
    M("hand_skin", (0.42, 0.25, 0.17), 0.6)
    M("jacket", (0.05, 0.055, 0.05), 0.85)
    M("cuff", (0.06, 0.06, 0.06), 0.9)

    def around(theta_deg, r, z):
        t = math.radians(theta_deg)
        return (math.cos(t) * r, math.sin(t) * r, z)

    v, e, rad = [], [], []

    def add(p, rr, parent=None):
        v.append(p)
        rad.append(rr)
        i = len(v) - 1
        if parent is not None:
            e.append((parent, i))
        return i

    wrist = add((0.055, -0.04, 0.085), (0.026, 0.018))
    palm = add((0.045, -0.016, 0.03), (0.034, 0.02), wrist)
    # four fingers wrap from the right side, under the body, up the left side
    for k, z in enumerate((-0.036, -0.013, 0.01, 0.031)):
        r0 = 0.0102 - k * 0.0007
        kn = add(around(8, 0.04, z + 0.004), r0 * 1.15, palm)
        a = add(around(-45, 0.034, z), r0, kn)
        b = add(around(-105, 0.032, z - 0.002), r0 * 0.92, a)
        add(around(-150 - k * 6, 0.03, z - 0.004), r0 * 0.8, b)
    # thumb over the top
    t0 = add((0.05, -0.028, 0.05), 0.012, wrist)
    t1 = add(around(40, 0.036, 0.02), 0.0105, t0)
    t2 = add(around(80, 0.033, -0.005), 0.0095, t1)
    add(around(108, 0.031, -0.024), 0.0085, t2)
    hand = skin_body("hand", [B_(p) for p in v], e, rad, "hand_skin")
    # sleeve and cuff
    cyl_between("cuff", (0.06, -0.05, 0.1), (0.075, -0.065, 0.14), 0.033, 0.035, "cuff")
    cyl_between("sleeve", (0.072, -0.062, 0.13), (0.16, -0.16, 0.34), 0.042, 0.055, "jacket")


def B_(p):
    return p


def cyl_between(name, a, b, r1, r2, mat):
    a, b = Vector(a), Vector(b)
    d = b - a
    o = cyl(name, r1, r2, d.length, tuple((a + b) / 2), mat, seg=20)
    # orient Godot +Y (Blender +Z) along d (in Blender space)
    db = G(*d)
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(db.normalized())
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def tape():
    box("shell", (0.19, 0.026, 0.105), (0, 0, 0), "black", 0.004)
    M("tape_label", (0.9, 0.86, 0.77), 0.85)
    box("label", (0.16, 0.002, 0.06), (0, 0.0135, 0.0), "tape_label", 0)
    for s in (-1, 1):
        cyl("reel", 0.018, 0.018, 0.028, (s * 0.045, 0.0, 0.02), "glass_dark", seg=16)


# ---------------------------------------------------------------- people (skin modifier)
def skin_body(name, verts, edges, radii, mat):
    me = bpy.data.meshes.new(name)
    me.from_pydata([G(*v) for v in verts], edges, [])
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    sk = o.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = True
    for i, r in enumerate(radii):
        rr = r if isinstance(r, tuple) else (r, r)
        me.skin_vertices[0].data[i].radius = rr
    me.skin_vertices[0].data[0].use_root = True
    sub = o.modifiers.new("subsurf", "SUBSURF")
    sub.levels = 2
    me.materials.append(MATS[mat] if isinstance(mat, str) else mat)
    bake(o)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def person(h, cloth, skin, thin=1.0, arm_len=0.36, seated=False, hair=None, host=False):
    leg = h * 0.48
    sw = h * 0.12 * thin   # shoulder half width
    hw = h * 0.06 * thin   # hip half width
    if seated:
        hip_y = 0.5
        knee = lambda s: (s * hw, 0.53, leg * 0.5)
        foot = lambda s: (s * hw, 0.05, leg * 0.52)
    else:
        hip_y = leg
        knee = lambda s: (s * hw * 0.95, leg * 0.5, 0.01)
        foot = lambda s: (s * hw * 0.9, 0.06, 0.0)
    pel = (0, hip_y, 0)
    belly = (0, hip_y + h * 0.1, 0.0)
    chest = (0, hip_y + h * 0.22, 0.0)
    neck = (0, hip_y + h * 0.31, 0.0)
    v = [pel, belly, chest, neck]
    e = [(0, 1), (1, 2), (2, 3)]
    r = [(h * 0.075 * thin, h * 0.05 * thin), (h * 0.07 * thin, h * 0.05 * thin), (h * 0.085 * thin, h * 0.055 * thin), h * 0.028]
    for s in (-1, 1):
        base = len(v)
        v += [(s * hw, hip_y, 0), knee(s), foot(s)]
        e += [(0, base), (base, base + 1), (base + 1, base + 2)]
        r += [h * 0.045 * thin, h * 0.032 * thin, h * 0.026]
    for s in (-1, 1):
        base = len(v)
        sh = (s * sw, hip_y + h * 0.28, 0)
        if seated:
            el = (s * (sw + 0.02), hip_y + h * 0.13, 0.12)
            ha = (s * sw * 0.6, 0.8, 0.32)
        elif host:
            el = (s * (sw + 0.03), sh[1] - h * arm_len * 0.5, 0.03)
            ha = (s * (sw + 0.05), sh[1] - h * arm_len, 0.08)
        else:
            el = (s * (sw + 0.02), sh[1] - h * arm_len * 0.5, -0.02)
            ha = (s * (sw + 0.03), sh[1] - h * arm_len, 0.03)
        v += [sh, el, ha]
        e += [(2, base), (base, base + 1), (base + 1, base + 2)]
        r += [h * 0.032 * thin, h * 0.022 * thin, h * 0.018 * (0.8 if host else 1)]
    body = skin_body("body", v, e, r, cloth)
    # head
    hy = neck[1] + h * 0.075
    if host:
        hd = sphere("head", h * 0.06, (0.02, hy + 0.06, 0.01), skin, (0.86, 1.55, 0.97), seg=32)
        hd.rotation_euler = (0, -0.0, 0.28)
        M("socket", (0.0, 0.0, 0.0), 1.0)
        for s in (-1, 1):
            sphere("eye", h * 0.016, (s * h * 0.022 + 0.03, hy + 0.1, h * 0.05), "socket", (1, 1.6, 0.6))
        box("mouth", (h * 0.03, h * 0.05, 0.01), (0.035, hy - 0.04, h * 0.055), "socket", 0.003)
        # long fingers
        for s in (-1, 1):
            hx = s * (sw + 0.05)
            hyy = neck[1] - h * 0.03 - h * arm_len
            for f in range(4):
                cyl("finger", 0.006, 0.004, 0.16, (hx + s * 0.012 * (f - 1.5), hyy - 0.08, 0.08 + (f - 1.5) * 0.01), skin, seg=6)
    else:
        sphere("head", h * 0.066, (0, hy, 0), skin, (0.92, 1.12, 1.0), seg=32)
        if hair:
            hr = sphere("hair", h * 0.07, (0, hy + h * 0.012, -h * 0.008), hair, (0.95, 1.05, 1.02), seg=24)
        M("eyes", (0.06, 0.04, 0.03), 0.4)
        for s in (-1, 1):
            sphere("eye", h * 0.008, (s * h * 0.02, hy + h * 0.01, h * 0.058), "eyes")
    return body


def build_people():
    def save(name, fn):
        reset()
        fn()
        export(name)

    M_ = M
    save("host", lambda: (M_("host_cloth", (0.03, 0.03, 0.035), 0.95), M_("host_skin", (0.72, 0.71, 0.68), 0.55),
                          person(2.3, "host_cloth", "host_skin", 0.78, 0.5, host=True)))
    save("mama", lambda: (M_("mama_cloth", (0.42, 0.16, 0.16), 0.9), M_("skin", (0.79, 0.67, 0.57), 0.6), M_("hair_brown", (0.18, 0.11, 0.06), 0.8),
                          person(1.68, "mama_cloth", "skin", 1.0, seated=True, hair="hair_brown")))
    save("otec", lambda: (M_("otec_cloth", (0.3, 0.26, 0.21), 0.9), M_("skin", (0.79, 0.67, 0.57), 0.6), M_("hair_dark", (0.08, 0.06, 0.05), 0.8),
                          person(1.82, "otec_cloth", "skin", 1.05, seated=True, hair="hair_dark")))
    save("kid_sit", lambda: (M_("kid_cloth", (0.45, 0.52, 0.62), 0.9), M_("skin", (0.83, 0.72, 0.63), 0.6), M_("hair_dark", (0.12, 0.08, 0.05), 0.8),
                             person(1.2, "kid_cloth", "skin", 0.95, seated=True, hair="hair_dark")))
    save("kid_stand", lambda: (M_("kid_cloth", (0.6, 0.66, 0.72), 0.9), M_("skin", (0.83, 0.72, 0.63), 0.6), M_("hair_dark", (0.12, 0.08, 0.05), 0.8),
                               person(1.2, "kid_cloth", "skin", 0.95, seated=False, hair="hair_dark")))
    save("mama_hosp", lambda: (M_("mama2_cloth", (0.25, 0.27, 0.32), 0.9), M_("skin", (0.79, 0.67, 0.57), 0.6), M_("hair_brown", (0.18, 0.11, 0.06), 0.8),
                               person(1.68, "mama2_cloth", "skin", 1.0, seated=True, hair="hair_brown")))
    save("lucia", lambda: (M_("lucia_cloth", (0.25, 0.37, 0.54), 0.9), M_("skin", (0.83, 0.72, 0.63), 0.6), M_("hair_blond", (0.55, 0.42, 0.2), 0.8),
                           person(1.32, "lucia_cloth", "skin", 0.95, seated=True, hair="hair_blond")))


def main():
    items = [
        ("sofa", lambda: sofa(2.2)),
        ("armchair", lambda: sofa(0.9)),
        ("chair", chair),
        ("table", table),
        ("tv", tv),
        ("fridge", fridge),
        ("stove", stove),
        ("counter", counter),
        ("wardrobe", wardrobe),
        ("bed_kid", lambda: bed(1.0, 2.0, "blanket_blue")),
        ("bed_double", lambda: bed(1.7, 2.1, "blanket_red")),
        ("clock", clock),
        ("shelf", shelf),
        ("bathtub", bathtub),
        ("sink", sink_bath),
        ("dresser", dresser),
        ("door", door),
        ("floor_lamp", floor_lamp),
        ("shade", shade),
        ("flashlight", flashlight),
        ("tape", tape),
        ("hand_flashlight", hand_flashlight),
    ]
    for name, fn in items:
        reset()
        fn()
        export(name)
    # sheets draped over furniture with a cloth simulation
    reset()
    cloth_sheet(2.9, 1.7, 1.15, "sheet", 2.2)
    export("sofa_sheet")
    reset()
    cloth_sheet(1.5, 1.5, 1.1, "sheet", 0.9)
    export("armchair_sheet")
    build_people()


if __name__ == "__main__":
    main()
