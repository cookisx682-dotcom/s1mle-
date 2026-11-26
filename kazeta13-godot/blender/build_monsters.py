"""Kazeta 13 - the six monsters.

Each monster is built from a skin-modifier skeleton (with fingers), shaped by a
procedural sculpt pass (ribs, spine, collarbones, muscles, torn mouths), dressed
with lathe-built clothing / hard-surface props, then UV-unwrapped and its
procedural materials (veins, dirt, blood, cracks, rust) are baked into
color / normal / roughness textures and exported as GLB for Godot.

Run:  python3 build_monsters.py <out_dir> [name ...]   (bpy module)
Blender space here: x right, -y front, z up.
"""
import math
import os
import random
import sys
import tempfile

import bpy  # noqa: F401  (must be imported before bmesh)
import bmesh
from mathutils import Vector, noise

ARGS = [a for a in sys.argv[1:] if not a.endswith(".py")]
OUT = ARGS[0] if ARGS else "models"
ONLY = set(ARGS[1:])
TEX = tempfile.mkdtemp(prefix="k13tex_")
TEX_SIZE = 1024
os.makedirs(OUT, exist_ok=True)


# =========================================================================== scene utils
def clear():
    for coll in (bpy.data.objects, bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.images):
        for x in list(coll):
            coll.remove(x)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 1
    sc.cycles.device = "CPU"
    sc.render.bake.margin = 8


def link(o):
    bpy.context.scene.collection.objects.link(o)
    return o


def select_only(o):
    for x in bpy.context.scene.objects:
        x.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def apply_all(o):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
    o.modifiers.clear()
    old = o.data
    o.data = me
    if old.users == 0:
        bpy.data.meshes.remove(old)
    return o


def recalc(o, smooth=True):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(o.data)
    bm.free()
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    o.data.update()


def mesh_obj(name, bm, mats=(), smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = link(bpy.data.objects.new(name, me))
    for m in mats:
        me.materials.append(m)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    return o


def sub(o, lvl=1):
    m = o.modifiers.new("sub", "SUBSURF")
    m.levels = lvl
    return apply_all(o)


def solidify(o, t):
    m = o.modifiers.new("sol", "SOLIDIFY")
    m.thickness = t
    m.offset = 0
    return apply_all(o)


def gauss(co, c, r):
    d = (co - c).length
    return math.exp(-(d * d) / (r * r))


def deform(o, fn):
    me = o.data
    cos = [v.co.copy() for v in me.vertices]
    nos = [v.normal.copy() for v in me.vertices]
    for v, co, no in zip(me.vertices, cos, nos):
        v.co = fn(co, no)
    me.update()


def set_attr(o, name, fn):
    me = o.data
    a = me.attributes.get(name) or me.attributes.new(name, "FLOAT", "POINT")
    for i, v in enumerate(me.vertices):
        a.data[i].value = max(0.0, min(1.0, fn(v.co, v.normal)))


def add_attr(o, name, fn):
    me = o.data
    a = me.attributes.get(name) or me.attributes.new(name, "FLOAT", "POINT")
    for i, v in enumerate(me.vertices):
        a.data[i].value = max(0.0, min(1.0, a.data[i].value + fn(v.co, v.normal)))


def zone(o, fn):
    """fn(face_center) -> material index"""
    for p in o.data.polygons:
        p.material_index = fn(p.center)


# =========================================================================== materials
class Mat:
    def __init__(self, name):
        self.m = bpy.data.materials.new(name)
        self.m.use_nodes = True
        self.nt = self.m.node_tree
        self.b = self.nt.nodes["Principled BSDF"]
        self.co = self.nt.nodes.new("ShaderNodeTexCoord").outputs["Object"]
        self.bumps = []

    def _set(self, sock, v):
        if isinstance(v, bpy.types.NodeSocket):
            self.nt.links.new(v, sock)
        elif sock.type == "RGBA" and len(v) == 3:
            sock.default_value = (*lin(v), 1.0)
        else:
            sock.default_value = v

    def noise(self, scale, detail=6.0, rough=0.6, dist=0.0, color=False):
        n = self.nt.nodes.new("ShaderNodeTexNoise")
        self.nt.links.new(self.co, n.inputs["Vector"])
        n.inputs["Scale"].default_value = scale
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = dist
        return n.outputs["Color" if color else "Fac"]

    def edges(self, scale, rand=1.0):
        n = self.nt.nodes.new("ShaderNodeTexVoronoi")
        n.feature = "DISTANCE_TO_EDGE"
        self.nt.links.new(self.co, n.inputs["Vector"])
        n.inputs["Scale"].default_value = scale
        n.inputs["Randomness"].default_value = rand
        return n.outputs["Distance"]

    def wave(self, scale, axis="Z", dist=0.0, bands=True):
        n = self.nt.nodes.new("ShaderNodeTexWave")
        n.wave_type = "BANDS" if bands else "RINGS"
        n.bands_direction = axis
        self.nt.links.new(self.co, n.inputs["Vector"])
        n.inputs["Scale"].default_value = scale
        n.inputs["Distortion"].default_value = dist
        return n.outputs["Fac"]

    def ramp(self, x, a, b, lo=0.0, hi=1.0):
        n = self.nt.nodes.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        self._set(n.inputs["Value"], x)
        n.inputs["From Min"].default_value = a
        n.inputs["From Max"].default_value = b
        n.inputs["To Min"].default_value = lo
        n.inputs["To Max"].default_value = hi
        return n.outputs["Result"]

    def math(self, op, a, b=0.0):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation = op
        n.use_clamp = op not in ("SUBTRACT",)
        self._set(n.inputs[0], a)
        self._set(n.inputs[1], b)
        return n.outputs[0]

    def mix(self, a, b, f):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        self._set([s for s in n.inputs if s.name == "Factor" and s.type == "VALUE"][0], f)
        self._set([s for s in n.inputs if s.name == "A" and s.type == "RGBA"][0], a)
        self._set([s for s in n.inputs if s.name == "B" and s.type == "RGBA"][0], b)
        return [s for s in n.outputs if s.type == "RGBA"][0]

    def attr(self, name):
        n = self.nt.nodes.new("ShaderNodeAttribute")
        n.attribute_name = name
        return n.outputs["Fac"]

    def cavity(self):
        """1 in concave creases (cycles pointiness)."""
        g = self.nt.nodes.new("ShaderNodeNewGeometry")
        return self.ramp(g.outputs["Pointiness"], 0.5, 0.44)

    def bump(self, h, strength, dist=0.01):
        self.bumps.append((h, strength, dist))

    def done(self, color, rough):
        self._set(self.b.inputs["Base Color"], color)
        self._set(self.b.inputs["Roughness"], rough)
        self.b.inputs["Metallic"].default_value = 0.0
        prev = None
        for h, s, d in self.bumps:
            n = self.nt.nodes.new("ShaderNodeBump")
            self._set(n.inputs["Height"], h)
            n.inputs["Strength"].default_value = s
            n.inputs["Distance"].default_value = d
            if prev is not None:
                self.nt.links.new(prev, n.inputs["Normal"])
            prev = n.outputs["Normal"]
        if prev is not None:
            self.nt.links.new(prev, self.b.inputs["Normal"])
        return self.m


BLOOD = (0.42, 0.03, 0.025)
BLOOD_DRY = (0.2, 0.04, 0.03)


def lin(c):
    """Colors in this file are written in sRGB; Blender wants linear."""
    return tuple(x ** 2.2 for x in c)


def blood_layer(M, col, amount, scale=2.5, seed_scale=1.0):
    if amount <= 0:
        return col, None
    n = M.noise(scale * seed_scale, 12, 0.7, 0.6)
    splat = M.ramp(n, 0.66 - amount * 0.12, 0.69 - amount * 0.12)
    drip = M.ramp(M.wave(3.0 * seed_scale, "Z", 18.0), 0.75, 0.9)
    m = M.math("MAXIMUM", splat, M.math("MULTIPLY", drip, M.ramp(n, 0.55, 0.62)))
    m = M.math("MULTIPLY", m, min(1.0, amount * 1.4))
    dry = M.ramp(M.noise(9), 0.4, 0.7)
    bc = M.mix(BLOOD, BLOOD_DRY, dry)
    return M.mix(col, bc, m), m


def flesh(name, base, dark, vein=(0.25, 0.12, 0.16), vein_amt=0.6, blood=0.3, cavity_col=(0.1, 0.0, 0.0),
          porcelain=False, wet=0.45):
    M = Mat(name)
    n1 = M.noise(5, 6, 0.6)
    col = M.mix(base, dark, M.ramp(n1, 0.35, 0.8))
    blot = M.ramp(M.noise(1.6, 3), 0.5, 0.7)
    col = M.mix(col, dark, M.math("MULTIPLY", blot, 0.6))
    # veins
    ve = M.ramp(M.edges(3.5, 1.0), 0.0, 0.012, 1.0, 0.0)
    vmask = M.math("MULTIPLY", ve, M.ramp(M.noise(2.5), 0.45, 0.62))
    col = M.mix(col, vein, M.math("MULTIPLY", vmask, vein_amt))
    if porcelain:
        cr = M.ramp(M.edges(6.0, 1.0), 0.0, 0.006, 1.0, 0.0)
        crm = M.math("MULTIPLY", cr, M.ramp(M.noise(3.0), 0.5, 0.58))
        col = M.mix(col, (0.06, 0.05, 0.05), crm)
        M.bump(M.math("MULTIPLY", crm, -1.0), 0.5, 0.003)
        drip = M.attr("drip")
        col = M.mix(col, (0.015, 0.012, 0.012), drip)
    # grime in creases
    col = M.mix(col, (0.05, 0.035, 0.025), M.math("MULTIPLY", M.cavity(), 0.8))
    col, bm = blood_layer(M, col, blood)
    # torn mouths / wounds
    cav = M.attr("cavity")
    inner = M.mix(cavity_col, (0.012, 0.0, 0.0), M.ramp(cav, 0.55, 1.0))
    edge = M.ramp(cav, 0.0, 0.25)
    col = M.mix(col, (0.28, 0.03, 0.03), M.math("MULTIPLY", M.ramp(cav, 0.0, 0.12), 0.7))
    col = M.mix(col, inner, edge)
    gore = M.attr("gore")
    col = M.mix(col, BLOOD, gore)
    col = M.mix(col, (0.025, 0.018, 0.014), M.attr("dark"))
    rough = M.math("SUBTRACT", wet + 0.15, M.math("MULTIPLY", M.math("MAXIMUM", cav, gore), 0.55))
    if bm is not None:
        rough = M.math("SUBTRACT", rough, M.math("MULTIPLY", bm, 0.3))
    # skin relief
    M.bump(M.noise(140, 4), 0.12, 0.002)
    M.bump(M.noise(22, 8, 0.7, 2.0), 0.25, 0.006)
    M.bump(M.math("MULTIPLY", ve, 0.6), 0.25, 0.004)
    return M.done(col, rough)


def cloth(name, color, dirt=0.5, blood=0.3, stripe=None, weave=260, rough=0.85):
    M = Mat(name)
    col = M.mix(color, [c * 0.6 for c in color], M.ramp(M.noise(4, 4), 0.3, 0.8))
    if stripe:
        st = M.ramp(M.wave(stripe[1], "X"), 0.92, 0.97)
        col = M.mix(col, stripe[0], st)
    g = M.ramp(M.noise(1.8, 6), 0.45, 0.75)
    col = M.mix(col, (0.12, 0.1, 0.07), M.math("MULTIPLY", g, dirt))
    col = M.mix(col, (0.04, 0.03, 0.02), M.math("MULTIPLY", M.cavity(), 0.7))
    col, bm = blood_layer(M, col, blood, 2.0, 1.3)
    gore = M.attr("gore")
    col = M.mix(col, BLOOD, gore)
    r = rough if bm is None else M.math("SUBTRACT", rough, M.math("MULTIPLY", bm, 0.35))
    M.bump(M.wave(weave, "X"), 0.08, 0.002)
    M.bump(M.wave(weave, "Z"), 0.08, 0.002)
    M.bump(M.noise(12, 6, 0.7, 1.5), 0.25, 0.006)
    return M.done(col, r)


def leather(name, color, blood=0.3, cracks=0.6):
    M = Mat(name)
    col = M.mix(color, [c * 0.55 for c in color], M.ramp(M.noise(6, 8), 0.3, 0.75))
    cr = M.ramp(M.edges(14, 1.0), 0.0, 0.01, 1.0, 0.0)
    crm = M.math("MULTIPLY", cr, M.ramp(M.noise(4), 0.4, 0.6))
    col = M.mix(col, (0.03, 0.02, 0.015), M.math("MULTIPLY", crm, cracks))
    sc = M.ramp(M.wave(40, "Z", 25), 0.9, 0.95)
    col = M.mix(col, [min(1, c * 1.6) for c in color], M.math("MULTIPLY", sc, 0.4))
    col = M.mix(col, (0.03, 0.02, 0.01), M.math("MULTIPLY", M.cavity(), 0.8))
    col, bm = blood_layer(M, col, blood, 1.6, 0.8)
    r = M.math("SUBTRACT", 0.55, M.math("MULTIPLY", M.noise(3), 0.2))
    if bm is not None:
        r = M.math("SUBTRACT", r, M.math("MULTIPLY", bm, 0.3))
    M.bump(M.math("MULTIPLY", crm, -1.0), 0.4, 0.003)
    M.bump(M.noise(60, 6), 0.2, 0.003)
    return M.done(col, r)


def rust(name, blood=0.2):
    M = Mat(name)
    n = M.noise(3, 10, 0.65, 0.4)
    iron = M.mix((0.09, 0.085, 0.08), (0.04, 0.038, 0.036), M.ramp(M.noise(12), 0.3, 0.7))
    rc = M.mix((0.35, 0.13, 0.04), (0.16, 0.06, 0.025), M.ramp(M.noise(18, 6), 0.3, 0.75))
    rm = M.ramp(n, 0.42, 0.56)
    col = M.mix(iron, rc, rm)
    streak = M.ramp(M.wave(6, "Z", 30), 0.6, 0.95)
    col = M.mix(col, (0.22, 0.07, 0.02), M.math("MULTIPLY", streak, 0.5))
    col = M.mix(col, (0.03, 0.015, 0.01), M.math("MULTIPLY", M.cavity(), 0.9))
    col, bm = blood_layer(M, col, blood, 2.2, 0.9)
    r = M.ramp(rm, 0.0, 1.0, 0.45, 0.92)
    M.bump(M.noise(45, 8, 0.75), 0.45, 0.004)
    M.bump(M.math("MULTIPLY", rm, 1.0), 0.3, 0.006)
    return M.done(col, r)


def plain(name, color, rough=0.5, metal=0.0, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(color), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(color), 1)
        b.inputs["Emission Strength"].default_value = emit
    return m


# =========================================================================== baking
def bake(o, size=TEX_SIZE, metal=0.0, angle=66):
    select_only(o)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    mats = [s.material for s in o.material_slots if s.material]
    imgs = {}
    for kind in ("COL", "NRM", "RGH"):
        img = bpy.data.images.new("%s_%s" % (o.name, kind), size, size, alpha=False)
        if kind != "COL":
            img.colorspace_settings.name = "Non-Color"
        for m in mats:
            nt = m.node_tree
            tn = nt.nodes.get("BAKE") or nt.nodes.new("ShaderNodeTexImage")
            tn.name = "BAKE"
            tn.image = img
            nt.nodes.active = tn
        if kind == "COL":
            bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=8)
        elif kind == "NRM":
            bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=8)
        else:
            bpy.ops.object.bake(type="ROUGHNESS", margin=8)
        path = os.path.join(TEX, img.name + ".png")
        img.filepath_raw = path
        img.file_format = "PNG"
        img.save()
        imgs[kind] = img
    em = bpy.data.materials.new(o.name + "_baked")
    em.use_nodes = True
    nt = em.node_tree
    b = nt.nodes["Principled BSDF"]
    c = nt.nodes.new("ShaderNodeTexImage")
    c.image = imgs["COL"]
    nt.links.new(c.outputs["Color"], b.inputs["Base Color"])
    r = nt.nodes.new("ShaderNodeTexImage")
    r.image = imgs["RGH"]
    nt.links.new(r.outputs["Color"], b.inputs["Roughness"])
    n = nt.nodes.new("ShaderNodeTexImage")
    n.image = imgs["NRM"]
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(n.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Metallic"].default_value = metal
    o.data.materials.clear()
    o.data.materials.append(em)
    for p in o.data.polygons:
        p.material_index = 0
    for a in list(o.data.attributes):
        if a.name in ("cavity", "gore", "drip", "dark"):
            o.data.attributes.remove(a)
    return o


def export(name):
    for o in list(bpy.data.objects):
        if o.hide_render or o.name.startswith("_"):
            bpy.data.objects.remove(o, do_unlink=True)
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False, export_apply=True,
                              export_animations=False, export_yup=True, export_image_format="JPEG",
                              export_jpeg_quality=88)
    print("exported", path, os.path.getsize(path) // 1024, "KB")


# =========================================================================== anatomy
class Body:
    pass


def human(H=1.8, thin=1.0, bulk=1.0, arm=1.0, finger=1.0, neck=1.0, hunch=0.0, pose="hang",
          curl=0.35, grip_right=False, name="body"):
    s = H / 1.8
    V, E, R = [], [], []

    def add(p, r, parent=None):
        V.append(Vector(p) * s)
        rr = r if isinstance(r, tuple) else (r, r)
        R.append((rr[0] * s, rr[1] * s))
        if parent is not None:
            E.append((parent, len(V) - 1))
        return len(V) - 1

    t, b = thin, bulk
    tb = t * b
    pel = add((0, 0, 0.98), (0.125 * tb, 0.085 * tb))
    s1 = add((0, 0.004 + hunch * 0.02, 1.1), (0.112 * tb, 0.078 * tb), pel)
    s2 = add((0, 0.004 - hunch * 0.05, 1.24), (0.13 * tb, 0.088 * tb), s1)
    s3 = add((0, -hunch * 0.11, 1.37), (0.148 * t * b ** 1.15, 0.093 * tb), s2)
    nz = 1.47 + 0.07 * (neck - 1)
    nk = add((0, -hunch * 0.17 - 0.01, nz), 0.047 * max(t, 0.72) * b ** 0.6, s3)
    nk2 = add((0, -hunch * 0.21 - 0.015, nz + 0.06 * neck), 0.043 * max(t, 0.72) * b ** 0.5, nk)
    body = Body()
    body.s = s
    body.head = Vector((0, -hunch * 0.23 - 0.02, nz + 0.06 * neck + 0.1)) * s
    body.hands = {}
    for side in (-1, 1):
        sh = add((side * 0.175 * b ** 1.1, -hunch * 0.09, 1.42 - hunch * 0.02), 0.05 * t * b ** 1.2, s3)
        shz = 1.42 - hunch * 0.02
        if pose == "reach":
            el = (side * 0.23 * b, -0.17 - hunch * 0.1, shz - 0.2 * arm)
            wr = (side * 0.2 * b, -0.42 * arm - hunch * 0.1, shz - 0.27 * arm)
        elif pose == "hold" and side == 1:
            el = (side * (0.2 * b + 0.05), -0.02, shz - 0.29 * arm)
            wr = (side * (0.2 * b + 0.07), -0.1, shz - 0.52 * arm)
        else:
            el = (side * (0.19 * b + 0.045), 0.03, shz - 0.29 * arm)
            wr = (side * (0.19 * b + 0.065), 0.0 - hunch * 0.05, shz - 0.55 * arm)
        el_i = add(el, 0.038 * t * b ** 1.25, sh)
        wr_i = add(wr, 0.028 * max(t, 0.8) * b ** 0.8, el_i)
        d = (Vector(wr) - Vector(el)).normalized()
        palm_p = Vector(wr) + d * 0.055 * min(arm, 1.3)
        pa = add(tuple(palm_p), (0.032 * b ** 0.7, 0.014 * b ** 0.7), wr_i)
        spread = d.cross(Vector((0, 0, 1))) if abs(d.z) < 0.7 else d.cross(Vector((1, 0, 0)))
        spread.normalize()
        inward = Vector((-side, 0, 0)) if abs(d.z) >= 0.7 else Vector((0, 0, -1))
        c = 0.9 if (grip_right and side == 1) else curl
        fr = 0.0088 * min(1.15, max(t, 0.75)) * b ** 0.6
        for k, off in enumerate((-0.027, -0.009, 0.009, 0.026)):
            L = (0.042, 0.03, 0.022)
            lm = finger * (1.0 - abs(k - 1.3) * 0.08)
            p = palm_p + d * 0.032 + spread * off * b ** 0.6
            prev = add(tuple(p), fr * 1.08, pa)
            dd = d.copy()
            for j in range(3):
                dd = (dd + inward * c * 0.9).normalized()
                p = p + dd * L[j] * lm
                prev = add(tuple(p), fr * (0.95 - j * 0.12), prev)
        th = Vector(wr) + d * 0.02 + spread * -0.028 * b ** 0.6 + inward * 0.01
        tp = add(tuple(th), fr * 1.25, wr_i)
        dd = (d + spread * -0.7).normalized()
        p = th
        for j in range(3):
            dd = (dd + inward * c * 0.6).normalized()
            p = p + dd * (0.03, 0.026, 0.02)[j] * finger ** 0.7
            tp = add(tuple(p), fr * (1.1 - j * 0.15), tp)
        body.hands[side] = palm_p * s
        body.wrist_dir = d
    for side in (-1, 1):
        hp = add((side * 0.095 * b, 0, 0.93), 0.074 * tb, pel)
        kn = add((side * 0.1 * b ** 0.8, -0.012, 0.52), 0.046 * t * b ** 0.9, hp)
        an = add((side * 0.1 * b ** 0.8, 0.02, 0.09), 0.03 * max(t, 0.82) * b ** 0.5, kn)
        add((side * 0.11 * b ** 0.8, -0.13, 0.035), (0.038 * b ** 0.5, 0.02), an)
    me = bpy.data.meshes.new(name)
    me.from_pydata(V, E, [])
    o = link(bpy.data.objects.new(name, me))
    sk = o.modifiers.new("skin", "SKIN")
    sk.branch_smoothing = 0.6
    sk.use_smooth_shade = True
    for i, r in enumerate(R):
        me.skin_vertices[0].data[i].radius = r
    me.skin_vertices[0].data[0].use_root = True
    o.modifiers.new("sub", "SUBSURF").levels = 2
    apply_all(o)
    recalc(o)
    body.o = o
    return body


def skin_noise(o, amp, scale=18.0, seed=0.0):
    off = Vector((seed, seed * 1.3, seed * 0.7))

    def f(co, no):
        return co + no * noise.fractal(co * scale + off, 0.6, 2.0, 4) * amp
    deform(o, f)


def ribs(o, s, amp, z0=1.08, z1=1.42, count=8, xmax=0.17):
    def f(co, no):
        z = co.z / s
        if not (z0 < z < z1) or abs(co.x) / s > xmax or no.y > 0.6:
            return co
        ph = (z + abs(co.x) / s * 0.55 - z0) / (z1 - z0) * count * math.pi
        rib = max(0.0, math.sin(ph)) ** 2 - 0.35
        fade = min(1.0, (z - z0) / 0.05) * min(1.0, (z1 - z) / 0.05)
        sternum = min(1.0, abs(co.x) / s / 0.025)
        side = max(0.0, 1 - (abs(co.x) / s / xmax) ** 2) * min(1.0, max(0.0, 0.4 - no.y) / 0.4)
        return co + no * rib * amp * s * fade * sternum * side
    deform(o, f)


def push(o, center, radius, amount, s=1.0, front=None):
    c = Vector(center) * s

    def f(co, no):
        if front is not None and no.y * front < 0:
            return co
        return co + no * gauss(co, c, radius * s) * amount * s
    deform(o, f)


def spine_ridge(o, s, amp):
    def f(co, no):
        if no.y < 0.5 or abs(co.x) / s > 0.03 or not (1.0 < co.z / s < 1.48):
            return co
        k = (1 - abs(co.x) / s / 0.03) * (0.6 + 0.4 * abs(math.sin(co.z / s * 70)))
        return co + no * k * amp * s
    deform(o, f)


def collarbones(o, s, amp, z=1.44):
    def f(co, no):
        if no.y > 0 or not (0.02 < abs(co.x) / s < 0.17):
            return co
        zz = z - 0.02 + abs(co.x) / s * 0.08
        k = math.exp(-((co.z / s - zz) ** 2) / 0.00012)
        return co + no * k * amp * s
    deform(o, f)


def tear(o, center, w, h, depth, s=1.0, front=-1, attr="cavity", jag=0.25, lips=0.004):
    """Torn mouth/wound: an elliptic pocket pushed into the surface."""
    c = Vector(center) * s
    a = o.data.attributes.get(attr) or o.data.attributes.new(attr, "FLOAT", "POINT")
    me = o.data
    cos = [v.co.copy() for v in me.vertices]
    nos = [v.normal.copy() for v in me.vertices]
    for i, (v, co, no) in enumerate(zip(me.vertices, cos, nos)):
        if no.y * front < 0.15 or (co.y - c.y) * front < -0.06 * s:
            continue
        ww = w * s * (1 + jag * noise.noise(Vector((co.z * 40, 1.3, 0.2))))
        e = ((co.x - c.x) / ww) ** 2 + ((co.z - c.z) / (h * s)) ** 2
        if e < 1.0:
            m = (1 - e) ** 0.5
            v.co = co - no * depth * s * m
            a.data[i].value = max(a.data[i].value, m)
        elif e < 1.6:
            v.co = co + no * lips * s * (1 - (e - 1) / 0.6)
            a.data[i].value = max(a.data[i].value, 0.0)
    me.update()


def teeth_row(name, pts, normal_in, length, mat, rad=0.006):
    bm = bmesh.new()
    for p, dirv in pts:
        r = rad * random.uniform(0.7, 1.2)
        ln = length * random.uniform(0.6, 1.25)
        geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r, radius2=r * 0.12, depth=ln)
        vs = geom["verts"]
        q = Vector((0, 0, 1)).rotation_difference(dirv.normalized())
        bmesh.ops.rotate(bm, verts=vs, cent=Vector(), matrix=q.to_matrix())
        bmesh.ops.translate(bm, verts=vs, vec=p + dirv.normalized() * ln * 0.4)
    o = mesh_obj(name, bm, [mat], smooth=False)
    return o


def lathe(name, rings, segs=72, a0=0.0, a1=math.tau, folds=0, fold_amp=0.0, hem_jag=0.0, mats=(), seed=1.0):
    """rings: list of (z, rx, ry, cx, cy) from top to bottom."""
    bm = bmesh.new()
    closed = abs(a1 - a0 - math.tau) < 1e-4
    cols = segs if closed else segs + 1
    grid = []
    n = len(rings)
    for i, (z, rx, ry, cx, cy) in enumerate(rings):
        t = i / (n - 1)
        row = []
        for j in range(cols):
            a = a0 + (a1 - a0) * j / segs
            f = 1 + fold_amp * t ** 1.3 * (math.sin(folds * a + noise.noise(Vector((a * 2, seed, t))) * 2.0))
            zz = z
            if i == n - 1 and hem_jag:
                zz += hem_jag * (noise.noise(Vector((a * 4, seed + 3, 0))) + 0.6 * abs(noise.noise(Vector((a * 15, seed, 1)))))
            row.append(bm.verts.new((cx + math.cos(a) * rx * f, cy + math.sin(a) * ry * f, zz)))
        grid.append(row)
    for i in range(n - 1):
        for j in range(segs):
            j2 = (j + 1) % cols
            bm.faces.new((grid[i][j], grid[i][j2], grid[i + 1][j2], grid[i + 1][j]))
    return mesh_obj(name, bm, mats)


def body_profile(o, z, xlim, s):
    xs, yf, yb = [], [], []
    for v in o.data.vertices:
        if abs(v.co.z - z) < 0.02 * s and abs(v.co.x) < xlim * s:
            xs.append(abs(v.co.x))
            yf.append(v.co.y)
    if not xs:
        return 0.1 * s, 0.08 * s, 0.0
    return max(xs), (max(yf) - min(yf)) / 2, (max(yf) + min(yf)) / 2


def garment(name, body, z_top, z_bottom, xlim, flare, mats, folds=9, fold_amp=0.06, hem=0.03, a0=0.0, a1=math.tau,
            extra=0.012, rings=16, seed=1.0):
    s = body.s
    out = []
    for i in range(rings):
        t = i / (rings - 1)
        z = (z_top + (z_bottom - z_top) * t) * s
        if z > 0.9 * s or i == 0:
            rx, ry, cy = body_profile(body.o, z, xlim, s)
        rx2 = rx + extra * s + flare * s * max(0.0, t - 0.25) ** 1.4
        ry2 = ry + extra * s + flare * 0.8 * s * max(0.0, t - 0.25) ** 1.4
        out.append((z, rx2, ry2, 0.0, cy))
    o = lathe(name, out, folds=folds, fold_amp=fold_amp, hem_jag=hem * s, mats=mats, a0=a0, a1=a1, seed=seed)
    o = solidify(o, 0.006 * s)
    return sub(o, 1)


def hair(name, center, r, count, length, mat, front_cover=0.0, spread=1.0, seed=3, wave=0.01, top_only=0.0):
    random.seed(seed)
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.0024
    cu.bevel_resolution = 0
    cu.resolution_u = 2
    c = Vector(center)
    for k in range(count):
        # direction on the upper skull
        while True:
            d = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(top_only - 0.1, 1)))
            if 0.2 < d.length <= 1.0:
                break
        d.normalize()
        if d.y < -0.2 and random.random() > front_cover:
            d.y = abs(d.y) * 0.5
            d.normalize()
        root = c + Vector((d.x * r * 0.95, d.y * r, d.z * r * 1.05))
        sp = cu.splines.new("POLY")
        segs = 9
        sp.points.add(segs - 1)
        L = length * random.uniform(0.75, 1.1)
        p = root.copy()
        out = Vector((d.x, d.y, 0)) * spread
        if d.y < -0.2:
            out.y -= 0.6
        for i in range(segs):
            t = i / (segs - 1)
            sp.points[i].co = (*p, 1.0)
            fall = Vector((0, 0, -1)) * (L / segs)
            drift = out * (L / segs) * 0.45 * (1 - t) ** 1.5
            wig = Vector((noise.noise(Vector((k, t * 4, 1))), noise.noise(Vector((k, t * 4, 2))), 0)) * wave
            p = p + fall + drift + wig
            # keep strands outside the skull
            v = p - c
            if v.length < r * 1.04 and v.z > -r * 0.5:
                p = c + v.normalized() * r * 1.05
    o = link(bpy.data.objects.new(name, cu))
    cu.materials.append(mat)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
    mo = link(bpy.data.objects.new(name, me))
    bpy.data.objects.remove(o, do_unlink=True)
    for p in me.polygons:
        p.use_smooth = True
    return mo


def make_head(name, pos, r, mats, elong=1.0, width=1.0, sockets=0.012, nose=0.016, brow=0.008, jaw=1.0, seg=56, gaunt=0.0):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg * 2 // 3, radius=r)
    o = mesh_obj(name, bm, mats)
    s = r / 0.11

    def shape(co, no):
        x, y, z = co.x * 0.82 * width, co.y * 0.95, co.z * 1.08 * elong
        if z < 0:
            k = min(1.0, -z / (r * 0.9))
            x *= 1 - 0.22 * k * jaw
            y *= 1 - 0.06 * k
            z *= 1 + 0.12 * k * jaw
        if y > 0 and z > -0.02 * s:
            y *= 1.08
        return Vector((x, y, z))
    deform(o, shape)
    recalc(o)
    S = s
    feats = [((0.0, -0.105, 0.03), 0.045, brow), ((0.0, -0.1, -0.012), 0.016, nose), ((0.0, -0.1, -0.03), 0.012, nose * 0.5)]
    for side in (-1, 1):
        feats += [((side * 0.034, -0.095, 0.008), 0.021, -sockets), ((side * 0.05, -0.078, -0.02), 0.024, 0.006),
                  ((side * 0.075, -0.01, -0.005), 0.025, 0.004),
                  ((side * 0.052, -0.07, -0.045), 0.028, -0.012 * gaunt), ((side * 0.07, -0.03, 0.035), 0.025, -0.006 * gaunt),
                  ((side * 0.04, -0.085, -0.075), 0.02, 0.004 * gaunt)]
    for c, rad, amt in feats:
        push(o, (c[0] * S, c[1] * S, c[2] * S * elong), rad * S, amt * S, front=-1 if c[1] < -0.05 else None)
    o.location = pos
    return o


def eyeball(name, pos, r, mat_white, mat_pupil, look=Vector((0, -1, 0))):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=14, radius=r)
    e = mesh_obj(name, bm, [mat_white])
    e.location = pos
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=r * 0.3)
    p = mesh_obj(name + "_p", bm, [mat_pupil])
    p.location = Vector(pos) + look.normalized() * r * 0.85
    p.scale = (1, 0.4, 1)
    return e, p


def parent_keep(child, parent):
    bpy.context.view_layer.update()
    mw = child.matrix_world.copy()
    child.parent = parent
    child.matrix_world = mw


def tube(name, pts, r, mat, res=6):
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 2
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    cu.resolution_u = res
    o = link(bpy.data.objects.new(name, cu))
    cu.materials.append(mat)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
    mo = link(bpy.data.objects.new(name, me))
    bpy.data.objects.remove(o, do_unlink=True)
    for p in me.polygons:
        p.use_smooth = True
    return mo


def rbox(name, size, pos, mats, bev=0.01, segs=3, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    o = mesh_obj(name, bm, mats, smooth=False)
    if bev:
        m = o.modifiers.new("bev", "BEVEL")
        m.width = bev
        m.segments = segs
        m.limit_method = "ANGLE"
        apply_all(o)
    o.location = pos
    o.rotation_euler = rot
    return o


def join(objs, name):
    """Join meshes (materials kept)."""
    bpy.context.view_layer.update()
    bm = bmesh.new()
    mats = []
    for o in objs:
        me = o.data.copy()
        me.transform(o.matrix_world)
        idx_map = []
        for m in o.data.materials:
            if m not in mats:
                mats.append(m)
            idx_map.append(mats.index(m))
        for p in me.polygons:
            p.material_index = idx_map[p.material_index] if idx_map else 0
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    for o in objs:
        bpy.data.objects.remove(o, do_unlink=True)
    c = Vector()
    for v in bm.verts:
        c += v.co
    c /= max(1, len(bm.verts))
    bmesh.ops.translate(bm, verts=bm.verts, vec=-c)
    out = mesh_obj(name, bm, mats, smooth=True)
    out.location = c
    return out


# =========================================================================== monsters
def m_host():
    """HOSŤ - starved, too tall, a mouth torn from the jaw down into the chest."""
    H = 2.32
    b = human(H, thin=0.6, bulk=0.95, arm=1.42, finger=1.9, neck=1.7, hunch=0.18, curl=0.25)
    s, o = b.s, b.o
    ribs(o, s, 0.016, count=9)
    spine_ridge(o, s, 0.012)
    collarbones(o, s, 0.012)
    push(o, (0, -0.06, 1.04), 0.07, -0.028, s, front=-1)       # sunken belly
    for side in (-1, 1):
        push(o, (side * 0.1, -0.05, 0.99), 0.03, 0.012, s)       # hip bones
        push(o, (side * 0.1, -0.05, 0.53), 0.035, 0.01, s)       # knees
        push(o, (side * 0.085, 0.05, 1.33), 0.05, 0.012, s)      # shoulder blades
    tear(o, (0, -0.07, 1.3), 0.042, 0.13, 0.032, s, jag=0.7, lips=0.008)
    for side in (-1, 1):
        push(o, (side * 0.27, 0.02, 1.13), 0.025, 0.01, s)       # elbows
        push(o, (side * 0.1, 0.03, 0.33), 0.05, 0.008, s)        # calves
    push(o, (0, -0.09, 1.2), 0.02, 0.006, s, front=-1)           # sternum
    skin_noise(o, 0.0022 * s, 22)
    set_attr(o, "gore", lambda co, no: 0.0)
    add_attr(o, "gore", lambda co, no: 0.8 * max(0.0, 1 - abs(co.x) / (0.05 * s)) * (1.0 if 0.95 * s < co.z < 1.16 * s and no.y < 0 else 0.0)
             * (0.5 + 0.5 * noise.noise(co * 30)))
    skin = flesh("host_skin", (0.56, 0.47, 0.35), (0.26, 0.2, 0.14), vein=(0.3, 0.16, 0.2), vein_amt=0.8, blood=0.35)
    ribs(o, s, 0.012, count=9)
    o.data.materials.append(skin)
    hp = b.head
    head = make_head("head", hp, 0.125 * s, [skin], elong=1.45, width=0.92, sockets=0.026, nose=-0.004, brow=0.014, jaw=1.3, gaunt=1.6)
    # the jaw hangs open, tearing down the throat
    hl0 = Vector((0, 0, 0))
    deform(head, lambda co, no: co + Vector((0, 0, -0.06)) * max(0.0, min(1.0, (-co.z - 0.02) / 0.08)) * max(0.0, -no.y + 0.2))
    recalc(head)
    tear(head, (0, -0.07, -0.075), 0.036, 0.1, 0.075, 1.0, jag=0.35, lips=0.006)
    skin_noise(head, 0.0018, 30, 2)
    set_attr(head, "gore", lambda co, no: 0.0)
    set_attr(head, "dark", lambda co, no: max(0.0, 1 - min((co - Vector((sd * 0.031, -0.085, 0.015))).length for sd in (-1, 1)) / 0.024) * 1.3)
    eyes = []
    wh = plain("eye_y", (0.62, 0.55, 0.3), 0.08)
    pu = plain("pupil", (0.01, 0.01, 0.01), 0.1)
    for side in (-1, 1):
        e, p = eyeball("eye", head.location + Vector((side * 0.031, -0.08, 0.015)), 0.013, wh, pu)
        eyes += [e, p]
    # teeth around the mouth and the chest tear
    bone = plain("teeth", (0.55, 0.47, 0.32), 0.35)
    pts = []
    for k in range(14):
        t = k / 13
        a = math.pi * (0.15 + 0.7 * t)
        for side in (-1, 1):
            x = side * 0.03 * math.sin(a)
            z = -0.06 + 0.07 * math.cos(a) * (1 if k % 2 else -1) * 0.95
            p = head.location + Vector((x, -0.085 + abs(x) * 0.6, z))
            pts.append((p, Vector((-side * 0.6, 0.6, 0))))
    head_teeth = teeth_row("teeth", pts, None, 0.022, bone, 0.0045)
    pts = []
    for k in range(11):
        z = (1.19 + 0.22 * k / 10 + random.uniform(-0.008, 0.008)) * s
        for side in (-1, 1):
            w = 0.04 * s * math.sqrt(max(0.0, 1 - ((z / s - 1.3) / 0.13) ** 2))
            pts.append((Vector((side * w, -0.072 * s, z)), Vector((-side, 0.4, random.uniform(-0.4, 0.4)))))
    chest_teeth = teeth_row("chest_teeth", pts, None, 0.03, bone, 0.007)
    # long tongue hanging out of the throat
    tongue = tube("tongue", [head.location + Vector((0, -0.07, -0.08)), Vector((0, -0.14, 1.62)) * s,
                             Vector((0.02, -0.16, 1.48)) * s, Vector((0.0, -0.12, 1.36)) * s], 0.012, plain("tongue", (0.25, 0.04, 0.05), 0.2))
    # loincloth rag
    rag = garment("rag", b, 0.99, 0.78, 0.2, 0.06, [cloth("host_rag", (0.2, 0.18, 0.15), 0.9, 0.5)], folds=7, fold_amp=0.12, hem=0.06, extra=0.008, rings=8)
    for x in [o, head, rag]:
        bake(x)
    for x in eyes + [head_teeth]:
        parent_keep(x, head)
    head.rotation_euler = (0.22, 0.16, 0.0)
    export("m_host")


def m_butcher():
    """MÄSIAR - a wall of meat in a riveted iron can, with a cleaver."""
    H = 2.12
    b = human(H, thin=1.0, bulk=1.42, arm=1.0, finger=1.0, neck=0.8, hunch=0.12, pose="hold", grip_right=True, curl=0.45)
    s, o = b.s, b.o
    for side in (-1, 1):
        push(o, (side * 0.075, -0.1, 1.33), 0.085, 0.03, s, front=-1)    # pecs
        push(o, (side * 0.22, -0.01, 1.4), 0.075, 0.03, s)               # deltoids
        push(o, (side * 0.1, 0.01, 1.47), 0.07, 0.03, s)                  # traps
        push(o, (side * 0.24, -0.04, 1.27), 0.05, 0.022, s)              # biceps
        push(o, (side * 0.27, -0.04, 1.03), 0.05, 0.016, s)              # forearms
        push(o, (side * 0.11, -0.03, 0.72), 0.08, 0.02, s)               # thighs
    push(o, (0, -0.13, 1.07), 0.14, 0.055, s, front=-1)                   # gut
    skin_noise(o, 0.003 * s, 14)
    # scars
    for k in range(6):
        c = Vector((random.uniform(-0.15, 0.15), -0.12, random.uniform(1.1, 1.4))) * s
        deform(o, lambda co, no, c=c: co - no * 0.004 * s * gauss(Vector((co.x, co.y, c.z + (co.x - c.x) * 0.5)), c, 0.012 * s)
               * (1.0 if abs(co.x - c.x) < 0.07 * s else 0.0))
    set_attr(o, "gore", lambda co, no: 0.0)
    skin = flesh("butcher_skin", (0.58, 0.46, 0.38), (0.32, 0.22, 0.18), vein=(0.3, 0.15, 0.18), vein_amt=0.35, blood=0.5)
    pants = cloth("butcher_pants", (0.12, 0.11, 0.1), 0.7, 0.4)
    boots = leather("butcher_boots", (0.08, 0.06, 0.045), 0.3)
    glove = leather("butcher_glove", (0.04, 0.04, 0.04), 0.6, 0.3)
    for m in (skin, pants, boots, glove):
        o.data.materials.append(m)

    def zf(c):
        z = c.z / s
        if z < 0.14:
            return 2
        if z < 0.95 and abs(c.x) / s < 0.22:
            return 1
        if z < 1.06 and abs(c.x) / s > 0.24:
            return 3
        return 0
    zone(o, zf)
    # leather apron with straps and buckles
    apron_m = leather("apron", (0.3, 0.2, 0.12), 0.85, 0.7)
    apron = garment("apron", b, 1.44, 0.5, 0.21, 0.05, [apron_m], folds=5, fold_amp=0.025, hem=0.02,
                    a0=math.radians(-90 - 82), a1=math.radians(-90 + 82), extra=0.018, rings=18, seed=4)
    metal = rust("buckle", 0.1)
    straps = []
    neck_r = 0.065 * s
    straps.append(tube("strap_neck", [Vector((-0.11, -0.12, 1.44)) * s, Vector((-0.07, 0.02, 1.56)) * s, Vector((0.0, 0.06, 1.58)) * s,
                                       Vector((0.07, 0.02, 1.56)) * s, Vector((0.11, -0.12, 1.44)) * s], 0.008 * s, apron_m))
    rx, ry, cy = body_profile(o, 1.05 * s, 0.22, s)
    belt = lathe("belt", [(1.08 * s, rx + 0.022 * s, ry + 0.022 * s, 0, cy), (1.03 * s, rx + 0.022 * s, ry + 0.022 * s, 0, cy)], segs=64, mats=[apron_m])
    belt = solidify(belt, 0.008 * s)
    for k, (x, z) in enumerate([(-0.1, 1.42), (0.1, 1.42), (0.0, 1.055)]):
        bx = rbox("buckle", (0.05 * s, 0.012 * s, 0.045 * s), Vector((x, 0, z)) * s + Vector((0, cy - ry - 0.035 * s, 0)), [metal], 0.004)
        straps.append(bx)
    # helmet: riveted iron can welded shut, one slit to see
    hp = b.head
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.17 * s, radius2=0.15 * s, depth=0.44 * s)
    helm = mesh_obj("helmet", bm, [rust("helmet_rust", 0.35)], smooth=False)
    helm.location = hp + Vector((0, 0, 0.06 * s))
    m = helm.modifiers.new("bev", "BEVEL")
    m.width = 0.012 * s
    m.segments = 2
    apply_all(helm)
    slit = rbox("_slit", (0.24 * s, 0.2 * s, 0.018 * s), hp + Vector((0, -0.14 * s, 0.07 * s)), [], 0)
    bo = helm.modifiers.new("b", "BOOLEAN")
    bo.object = slit
    bo.operation = "DIFFERENCE"
    apply_all(helm)
    slit.hide_render = True
    # dents
    helm = sub(helm, 0)
    rivets = []
    rm = helm.data.materials[0]
    for zz in (-0.19, 0.2):
        for k in range(20):
            a = k / 20 * math.tau
            rr = (0.17 if zz < 0 else 0.153) * s + 0.004 * s
            bm = bmesh.new()
            bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.009 * s)
            rv = mesh_obj("rivet", bm, [rm])
            rv.location = helm.location + Vector((math.cos(a) * rr, math.sin(a) * rr, zz * s))
            rivets.append(rv)
    seam = rbox("seam", (0.02 * s, 0.02 * s, 0.42 * s), helm.location + Vector((0, 0.165 * s, 0)), [rm], 0.006)
    bolts = []
    for side in (-1, 1):
        bolts.append(rbox("bolt", (0.06 * s, 0.03 * s, 0.03 * s), helm.location + Vector((side * 0.17 * s, 0, 0.05 * s)), [rm], 0.006))
    helm_all = join([helm, seam] + rivets + bolts, "helmet")
    # cleaver
    hand = b.hands[1]
    blade_len, blade_w = 0.78 * s, 0.24 * s
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((0.014 * s, blade_w, blade_len)), verts=bm.verts)
    for v in bm.verts:
        if v.co.y < 0:      # sharpened edge
            v.co.x *= 0.15
        if v.co.z < 0 and v.co.y > 0:
            v.co.y -= 0.03 * s
    blade = mesh_obj("cleaver", bm, [rust("cleaver_rust", 0.8)], smooth=False)
    blade = sub(blade, 0)
    m = blade.modifiers.new("bev", "BEVEL")
    m.width = 0.003 * s
    m.segments = 2
    apply_all(blade)
    # chips in the edge
    for k in range(5):
        z = random.uniform(-0.35, 0.3) * blade_len
        ch = rbox("_chip", (0.05 * s, 0.03 * s, 0.025 * s), Vector((0, -blade_w / 2, z)), [], 0, rot=(random.uniform(-0.5, 0.5), 0, 0))
        bo = blade.modifiers.new("b", "BOOLEAN")
        bo.object = ch
        bo.operation = "DIFFERENCE"
        apply_all(blade)
        ch.hide_render = True
    hole = rbox("_hole", (0.05 * s, 0.04 * s, 0.04 * s), Vector((0, blade_w * 0.25, -blade_len * 0.38)), [], 0)
    bo = blade.modifiers.new("b", "BOOLEAN")
    bo.object = hole
    bo.operation = "DIFFERENCE"
    apply_all(blade)
    hole.hide_render = True
    blade.location = hand + Vector((0.0, -0.02 * s, -blade_len / 2 - 0.12 * s))
    handle = tube("handle", [hand + Vector((0, 0.0, 0.07 * s)), hand + Vector((0, 0.0, -0.13 * s))], 0.02 * s, leather("handle", (0.18, 0.11, 0.06), 0.4))
    blade.rotation_euler = (0.12, 0, 0.75)
    for x in (o, apron, belt):
        bake(x)
    bake(helm_all, metal=0.35)
    bake(blade, metal=0.4)
    bake(handle, 512)
    for x in straps:
        if x.name.startswith("strap"):
            bake(x, 256)
        else:
            bake(x, 256, metal=0.5)
    export("m_butcher")


def m_mother():
    """MATKA - blind, bandaged eyes, hair over the face, a gown that drags."""
    H = 2.05
    b = human(H, thin=0.68, bulk=0.9, arm=1.3, finger=1.6, neck=1.35, hunch=0.22, pose="reach", curl=0.55)
    s, o = b.s, b.o
    ribs(o, s, 0.008, count=8)
    collarbones(o, s, 0.012)
    skin_noise(o, 0.0018 * s, 26)
    set_attr(o, "gore", lambda co, no: 0.0)
    skin = flesh("mother_skin", (0.62, 0.6, 0.56), (0.35, 0.33, 0.32), vein=(0.22, 0.2, 0.32), vein_amt=0.8, blood=0.15)
    o.data.materials.append(skin)
    gown = garment("gown", b, 1.45, 0.0, 0.17, 0.26, [cloth("gown", (0.62, 0.6, 0.55), 0.8, 0.45)], folds=11,
                   fold_amp=0.09, hem=0.06, extra=0.01, rings=22, seed=7)
    head = make_head("head", b.head, 0.112 * s, [skin], elong=1.12, width=0.92, sockets=0.008, jaw=1.15)
    tear(head, (0, -0.08, -0.05), 0.024, 0.032, 0.03, 1.0, jag=0.2)
    set_attr(head, "gore", lambda co, no: 0.0)
    add_attr(head, "gore", lambda co, no: 0.9 * max(0.0, 1 - abs(co.x) / 0.018) if co.z < -0.07 and no.y < -0.3 else 0.0)
    # bandage over the eyes
    hl = head.location
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=48, radius1=0.103 * s, radius2=0.1 * s, depth=0.045 * s)
    band = mesh_obj("bandage", bm, [cloth("bandage", (0.75, 0.72, 0.64), 0.6, 0.7, weave=400)])
    band.location = hl + Vector((0, 0.0, 0.012 * s))
    band.scale = (0.84, 0.98, 1.0)
    band = solidify(apply_scale(band), 0.004)
    set_attr(band, "gore", lambda co, no: 0.85 * max(0.0, 1 - ((abs(co.x) - 0.032 * s) / (0.018 * s)) ** 2) if co.y < -0.05 * s else 0.0)
    band = sub(band, 1)
    # long black hair falling over the face
    hairm = plain("hair_black", (0.012, 0.011, 0.01), 0.45)
    hr = hair("hair", hl + Vector((0, 0.005, 0.02)), 0.108 * s, 380, 0.75 * s, hairm, front_cover=0.55, spread=0.6, seed=5, wave=0.012)
    for x in (o, gown, head, band):
        bake(x)
    export("m_mother")


def apply_scale(o):
    me = o.data
    from mathutils import Matrix
    me.transform(Matrix.Diagonal((*o.scale, 1.0)))
    o.scale = (1, 1, 1)
    me.update()
    return o


def m_sister():
    """SESTRA - a cracked porcelain child, black tears, head bent too far."""
    H = 1.3
    b = human(H, thin=0.85, bulk=0.82, arm=0.98, finger=0.9, neck=1.0, curl=0.5)
    s, o = b.s, b.o
    skin_noise(o, 0.0012 * s, 30)
    set_attr(o, "gore", lambda co, no: 0.0)
    skin = flesh("sister_skin", (0.86, 0.83, 0.79), (0.6, 0.58, 0.56), vein=(0.45, 0.4, 0.5), vein_amt=0.25, blood=0.12,
                 porcelain=True, wet=0.25)
    o.data.materials.append(skin)
    set_attr(o, "drip", lambda co, no: 0.0)
    dress = garment("dress", b, 1.4, 0.56, 0.15, 0.2, [cloth("dress", (0.32, 0.4, 0.52), 0.75, 0.35)], folds=10,
                    fold_amp=0.07, hem=0.035, extra=0.012, rings=16, seed=9)
    head = make_head("head", b.head + Vector((0, 0, 0.02 * s)), 0.15 * s, [skin], elong=1.0, width=1.0, sockets=0.03, nose=0.008)
    hl = head.location
    # empty black eye sockets that drip down the cheeks
    set_attr(head, "drip", lambda co, no: 0.0)
    S = 0.15 * s / 0.11
    for side in (-1, 1):
        ec = Vector((side * 0.034, -0.095, 0.008)) * S
        add_attr(head, "drip", lambda co, no, ec=ec: (1.0 if (co - ec).length < 0.03 else 0.0) +
                 (0.95 if abs(co.x - ec.x - 0.004 * math.sin(co.z * 200)) < 0.0055 and ec.z - 0.11 < co.z < ec.z and co.y < -0.05 else 0.0))
    tear(head, (0, -0.1 * S, -0.045 * S), 0.02, 0.012, 0.012, 1.0, jag=0.1)
    set_attr(head, "gore", lambda co, no: 0.0)
    for side in (-1, 1):
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=12, v_segments=8, radius=0.022)
        sock = mesh_obj("socket", bm, [plain("void", (0.0, 0.0, 0.0), 1.0)])
        sock.location = hl + Vector((side * 0.034, -0.083, 0.008)) * S
        parent_keep(sock, head)
    hr = hair("hair", hl + Vector((0, 0.01, 0.025)), 0.15 * s, 320, 0.32, plain("hair_brown", (0.12, 0.08, 0.05), 0.5),
              front_cover=0.1, spread=0.15, seed=11, wave=0.006, top_only=0.05)
    for x in (o, dress, head):
        bake(x)
    head.rotation_euler = (0.1, 0.55, 0.0)
    parent_keep(hr, head)
    export("m_sister")


def m_double():
    """DVOJNÍK - wears your jacket. No eyes. A grin from ear to ear."""
    H = 1.8
    b = human(H, thin=0.95, bulk=1.0, arm=1.05, finger=1.1, curl=0.3)
    s, o = b.s, b.o
    skin_noise(o, 0.0015 * s, 20)
    set_attr(o, "gore", lambda co, no: 0.0)
    skin = flesh("double_skin", (0.7, 0.58, 0.5), (0.45, 0.35, 0.3), vein_amt=0.3, blood=0.1)
    jacket = cloth("jacket", (0.06, 0.065, 0.06), 0.5, 0.15, weave=180, rough=0.75)
    jeans = cloth("jeans", (0.08, 0.11, 0.17), 0.5, 0.1, weave=300)
    shoes = leather("shoes", (0.05, 0.045, 0.04), 0.05)
    for m in (skin, jacket, jeans, shoes):
        o.data.materials.append(m)
    push(o, (0, -0.02, 1.25), 0.25, 0.012, s)   # jacket thickness

    def zf(c):
        z = c.z / s
        if z < 0.12:
            return 3
        if z < 0.96 and abs(c.x) / s < 0.22:
            return 2
        if z > 1.47 or (abs(c.x) / s > 0.22 and z < 0.94):
            return 0
        return 1
    zone(o, zf)
    head = make_head("head", b.head, 0.112 * s, [skin], elong=1.08, sockets=-0.004, nose=0.012)
    hl = head.location
    # the grin: a thin slit stretched far around the face
    tear(head, (0, -0.1, -0.042), 0.07, 0.011, 0.025, 1.0, jag=0.05, lips=0.003)
    set_attr(head, "gore", lambda co, no: 0.0)
    pts = []
    for k in range(26):
        t = (k / 25) * 2 - 1
        x = t * 0.064
        y = -0.1 + abs(t) ** 2 * 0.045
        for up in (1, -1):
            pts.append((hl + Vector((x, y - 0.002, -0.042 + up * 0.007 + abs(t) ** 2 * 0.012)), Vector((0, 0.3, -up))))
    teeth = teeth_row("teeth", pts, None, 0.012, plain("teeth_w", (0.8, 0.77, 0.7), 0.25), 0.0042)
    hr = hair("hair", hl + Vector((0, 0.008, 0.03)), 0.108 * s, 300, 0.09, plain("hair_dark", (0.03, 0.025, 0.02), 0.5),
              front_cover=0.0, spread=0.2, seed=17, wave=0.004, top_only=0.1)
    collar = lathe("collar", [(1.52 * s, 0.07 * s, 0.065 * s, 0, 0.005 * s), (1.46 * s, 0.085 * s, 0.08 * s, 0, 0.0)], segs=40, mats=[jacket])
    collar = solidify(collar, 0.006 * s)
    for x in (o, head, collar):
        bake(x)
    export("m_double")


def m_announcer():
    """HLÁSATEĽ - a man in a funeral suit with a television for a head."""
    H = 1.86
    b = human(H, thin=0.85, bulk=1.0, arm=1.12, finger=1.25, neck=0.9, hunch=0.14, curl=0.4)
    s, o = b.s, b.o
    skin_noise(o, 0.0015 * s, 20)
    set_attr(o, "gore", lambda co, no: 0.0)
    skin = flesh("announcer_skin", (0.55, 0.55, 0.53), (0.3, 0.3, 0.3), vein=(0.2, 0.2, 0.28), vein_amt=0.6, blood=0.2)
    suit = cloth("suit", (0.07, 0.07, 0.075), 0.4, 0.25, stripe=((0.2, 0.2, 0.2), 40), weave=320, rough=0.7)
    shirt = cloth("shirt", (0.72, 0.7, 0.64), 0.6, 0.55, weave=400)
    tie = cloth("tie", (0.3, 0.04, 0.04), 0.3, 0.2, weave=500, rough=0.5)
    shoes = leather("shoes2", (0.02, 0.02, 0.02), 0.0, 0.3)
    for m in (skin, suit, shirt, tie, shoes):
        o.data.materials.append(m)
    push(o, (0, -0.02, 1.25), 0.25, 0.01, s)

    def zf(c):
        z = c.z / s
        if z < 0.12:
            return 4
        if z > 1.47:
            return 0
        if abs(c.x) / s > 0.22 and z < 0.96:
            return 0
        if c.y < 0 and 1.12 < z < 1.47 and abs(c.x) / s < 0.07 * (z - 1.05) / 0.42 + 0.005:
            return 3 if abs(c.x) / s < 0.016 + (1.47 - z) * 0.02 and z < 1.44 else 2
        return 1
    zone(o, zf)
    hp = b.head + Vector((0, -0.02 * s, 0.02 * s))
    pl = leather("tv_casing", (0.16, 0.1, 0.06), 0.35, 0.3)
    shell = rbox("tv", (0.42 * s, 0.38 * s, 0.32 * s), hp + Vector((0, 0.03 * s, 0)), [pl], 0.03 * s)
    back = rbox("tv_back", (0.3 * s, 0.2 * s, 0.24 * s), hp + Vector((0, 0.24 * s, 0)), [pl], 0.03 * s)
    bezel = rbox("tv_bezel", (0.44 * s, 0.04 * s, 0.34 * s), hp + Vector((0, -0.16 * s, 0)), [pl], 0.02 * s)
    tvall = join([shell, back, bezel], "tv")
    # curved screen
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=20, y_segments=16, size=0.5)
    for v in bm.verts:
        x, y = v.co.x, v.co.y
        v.co = Vector((x * 0.32 * s, -0.012 * s * (1 - (2 * x) ** 2 * 0.6) * (1 - (2 * y) ** 2 * 0.6), y * 0.25 * s))
    scr = mesh_obj("screen", bm, [plain("screen", (0.3, 0.32, 0.35), 0.15, 0, 0.6)])
    uvl = scr.data.uv_layers.new(name="UVMap")
    for loop in scr.data.loops:
        co = scr.data.vertices[loop.vertex_index].co
        uvl.data[loop.index].uv = (co.x / (0.32 * s) + 0.5, co.z / (0.25 * s) + 0.5)
    scr.location = hp + Vector((0, -0.182 * s, 0))
    ants = [tube("antenna", [hp + Vector((0.05 * s, 0.05 * s, 0.19 * s)), hp + Vector((0.25 * s, 0.05 * s, 0.5 * s))], 0.003 * s, plain("chrome", (0.6, 0.6, 0.6), 0.25, 1.0)),
            tube("antenna", [hp + Vector((-0.02 * s, 0.05 * s, 0.19 * s)), hp + Vector((-0.12 * s, 0.1 * s, 0.32 * s)), hp + Vector((-0.3 * s, 0.05 * s, 0.33 * s))], 0.003 * s, plain("chrome", (0.6, 0.6, 0.6), 0.25, 1.0))]
    cab = plain("cable_b", (0.015, 0.015, 0.015), 0.4)
    cables = []
    for k in range(3):
        a = (k - 1) * 0.06 * s
        cables.append(tube("cable", [hp + Vector((a, 0.05 * s, -0.16 * s)), Vector((a * 1.5, 0.06 * s, 1.47 * s)),
                                     Vector((a * 2 + 0.03 * s, 0.11 * s, 1.3 * s)), Vector((a * 2, 0.13 * s, 1.18 * s))], 0.006 * s, cab))
    collar = lathe("collar", [(1.5 * s, 0.07 * s, 0.065 * s, 0, 0.005 * s), (1.44 * s, 0.085 * s, 0.08 * s, 0, 0.0)], segs=40, mats=[shirt])
    collar = solidify(collar, 0.006 * s)
    for x in (o, collar):
        bake(x)
    bake(tvall, metal=0.2)
    tvall.rotation_euler = (0.06, -0.12, 0.08)
    for x in [scr] + ants:
        parent_keep(x, tvall)
    export("m_announcer")


BUILD = [("m_host", m_host), ("m_butcher", m_butcher), ("m_mother", m_mother), ("m_sister", m_sister),
         ("m_double", m_double), ("m_announcer", m_announcer)]

if __name__ == "__main__":
    for name, fn in BUILD:
        if ONLY and name not in ONLY:
            continue
        random.seed(13)
        clear()
        fn()
