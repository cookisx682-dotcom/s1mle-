"""Kazeta 13 - title screen scene: an old TV in a dark forest clearing.

Run:  python3 build_menu.py <out_dir>   (bpy module)  or  blender -b -P build_menu.py -- <out_dir>
Exports <out_dir>/menu_scene.glb. Coordinates are Godot space (see build_models.G).
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_models as B  # noqa: E402
import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

G, M, box, cyl, sphere, bake, subsurf = B.G, B.M, B.box, B.cyl, B.sphere, B.bake, B.subsurf
random.seed(13)


def mats():
    def two_sided(m):
        m.use_backface_culling = False
        return m
    M("moss_ground", (0.07, 0.1, 0.04), 0.95)
    M("bark", (0.1, 0.08, 0.06), 0.95)
    M("leaves", (0.03, 0.06, 0.03), 0.9)
    two_sided(M("fern", (0.06, 0.16, 0.05), 0.7))
    two_sided(M("grass", (0.09, 0.17, 0.05), 0.7))
    M("rock", (0.22, 0.22, 0.2), 0.9)
    M("moss", (0.12, 0.2, 0.05), 1.0)
    M("cable", (0.015, 0.015, 0.015), 0.5)
    M("blood", (0.25, 0.01, 0.01), 0.3)
    M("tape_label", (0.9, 0.86, 0.77), 0.85)


def displaced(o, strength, size, seed=0):
    """Noise displacement applied directly to the vertices (along normals)."""
    me = o.data
    off = Vector((seed * 3.1, seed * 1.7, seed * 2.3))
    for v in me.vertices:
        n = noise.fractal((v.co * (1.0 / size)) + off, 0.5, 2.0, 4)
        v.co += v.normal * n * strength
    return o


def ground():
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=120, y_segments=120, size=15)
    for v in bm.verts:
        x, y = v.co.x, v.co.y
        h = noise.fractal(Vector((x * 0.25, y * 0.25, 0.3)), 0.5, 2.0, 4) * 0.25
        h += noise.noise(Vector((x * 1.6, y * 1.6, 1.1))) * 0.04
        # small mound under the TV, slope up into the back
        h += 0.12 * math.exp(-((x - 1.2) ** 2 + (y - 0.2) ** 2) / 0.8)
        h += max(0.0, y - 4) * 0.12
        v.co.z = h
    o = B._obj("ground", bm, "moss_ground", True)
    return o


def ground_h(x, z):
    """Matches ground(): Godot (x, z) -> height (Blender y = -z)."""
    y = -z
    h = noise.fractal(Vector((x * 0.25, y * 0.25, 0.3)), 0.5, 2.0, 4) * 0.25
    h += noise.noise(Vector((x * 1.6, y * 1.6, 1.1))) * 0.04
    h += 0.12 * math.exp(-((x - 1.2) ** 2 + (y - 0.2) ** 2) / 0.8)
    h += max(0.0, y - 4) * 0.12
    return h


def tree(x, z, h, r, roots=5, branches=3, lean=0.0):
    base = ground_h(x, z) - 0.15
    v, e, rad = [], [], []

    def add(p, rr, parent=None):
        v.append(p)
        rad.append(rr)
        i = len(v) - 1
        if parent is not None:
            e.append((parent, i))
        return i

    root = add((x, base, z), r * 1.15)
    prev = root
    segs = 7
    top = None
    for i in range(1, segs + 1):
        t = i / segs
        p = (x + math.sin(t * 2.2 + x) * 0.15 * r * 4 + lean * t * h, base + t * h, z + math.cos(t * 1.7 + z) * 0.12 * r * 4)
        prev = add(p, r * (1.0 - 0.6 * t), prev)
        if i == 3:
            mid = prev
        top = prev
    # roots spread on the ground
    for k in range(roots):
        a = k / roots * math.tau + random.uniform(-0.3, 0.3)
        L = r * random.uniform(3.5, 6.0)
        p1 = (x + math.cos(a) * L * 0.45, base + 0.22, z + math.sin(a) * L * 0.45)
        i1 = add(p1, r * 0.45, root)
        p2 = (x + math.cos(a) * L, ground_h(x + math.cos(a) * L, z + math.sin(a) * L) - 0.03, z + math.sin(a) * L)
        add(p2, r * 0.12, i1)
    # branches
    for k in range(branches):
        a = random.uniform(0, math.tau)
        sy = base + h * random.uniform(0.45, 0.85)
        L = h * random.uniform(0.25, 0.4)
        # attach to the nearest trunk vertex
        near = min(range(1, segs + 1), key=lambda i: abs(v[i][1] - sy))
        bx, by, bz = v[near]
        i1 = add((bx + math.cos(a) * L * 0.5, by + L * 0.35, bz + math.sin(a) * L * 0.5), r * 0.32, near)
        add((bx + math.cos(a) * L, by + L * 0.75, bz + math.sin(a) * L), r * 0.08, i1)
    body = B.skin_body("tree", v, e, rad, "bark")
    displaced(body, r * 0.12, 0.25, seed=int(x * 7 + z))
    return body, v[top]


def canopy(p, size, n=6):
    for i in range(n):
        q = (p[0] + random.uniform(-1, 1) * size, p[1] + random.uniform(-0.3, 0.6) * size, p[2] + random.uniform(-1, 1) * size)
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=size * random.uniform(0.5, 0.8))
        o = B._obj("leaves", bm, "leaves", True)
        o.location = G(*q)
        o.scale = (1.0, 1.0, 0.7)
        displaced(o, size * 0.35, size * 0.25, seed=i)


def rock(x, z, s, moss=True):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=s)
    o = B._obj("rock", bm, "rock", True)
    o.location = G(x, ground_h(x, z) + s * 0.25, z)
    o.scale = (1.0, random.uniform(0.7, 1.1), random.uniform(0.5, 0.75))
    o.rotation_euler = (0, 0, random.uniform(0, 6))
    displaced(o, s * 0.35, s * 0.6, seed=int(s * 100))
    if moss:
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=3, radius=s * 0.85)
        m = B._obj("moss", bm, "moss", True)
        m.location = G(x, ground_h(x, z) + s * 0.45, z)
        m.scale = (1.0, 0.95, 0.42)
        m.rotation_euler = o.rotation_euler
        displaced(m, s * 0.15, s * 0.3, seed=int(s * 50))


def fern(x, z, s):
    bm = bmesh.new()
    y0 = ground_h(x, z)
    n = random.randint(7, 10)
    for k in range(n):
        a = k / n * math.tau + random.uniform(-0.25, 0.25)
        L = s * random.uniform(0.7, 1.0)
        segs = 10
        prev = None
        dx, dz = math.cos(a), math.sin(a)
        px, pz = -dz, dx
        for i in range(segs + 1):
            t = i / segs
            w = s * 0.13 * math.sin(t * math.pi) * (1.0 - 0.3 * t)
            cx = x + dx * L * t
            cz = z + dz * L * t
            cy = y0 + math.sin(t * math.pi * 0.9) * L * 0.55 - t * t * L * 0.2
            # serrated leaflets: zigzag width
            ww = w * (1.0 if i % 2 == 0 else 0.55)
            l_ = bm.verts.new(G(cx + px * ww, cy, cz + pz * ww))
            r_ = bm.verts.new(G(cx - px * ww, cy + 0.01, cz - pz * ww))
            if prev:
                bm.faces.new((prev[0], prev[1], r_, l_))
            prev = (l_, r_)
    o = B._obj("fern", bm, "fern", True)
    return o


def grass(cx, cz, radius, count):
    bm = bmesh.new()
    for _ in range(count):
        a = random.uniform(0, math.tau)
        d = radius * math.sqrt(random.random())
        x = cx + math.cos(a) * d
        z = cz + math.sin(a) * d
        y = ground_h(x, z) - 0.01
        h = random.uniform(0.08, 0.3)
        w = random.uniform(0.008, 0.016)
        r = random.uniform(0, math.tau)
        bend = random.uniform(-0.08, 0.08)
        ox, oz = math.cos(r) * w, math.sin(r) * w
        v1 = bm.verts.new(G(x - ox, y, z - oz))
        v2 = bm.verts.new(G(x + ox, y, z + oz))
        v3 = bm.verts.new(G(x + math.sin(r) * bend, y + h, z - math.cos(r) * bend))
        bm.faces.new((v1, v2, v3))
    o = B._obj("grass", bm, "grass", True)
    return o


def crt(pos, ry, tilt):
    """CRT TV; children share one pivot so it can be rotated as a group."""
    pivot = bpy.data.objects.new("tv_pivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    pivot.location = G(*pos)
    pivot.rotation_euler = (0, tilt, ry)  # Blender: z = Godot yaw

    def p(o):
        o.parent = pivot
        return o
    y = 0.33
    p(box("bezel", (0.88, 0.66, 0.12), (0, y, 0.24), "plastic", 0.035, segs=3))
    p(box("shell", (0.76, 0.56, 0.36), (0, y + 0.01, 0.0), "plastic", 0.06, segs=3))
    p(box("tube", (0.5, 0.4, 0.22), (0, y + 0.02, -0.26), "plastic", 0.06, segs=3))
    p(box("inset", (0.7, 0.53, 0.02), (0, y + 0.02, 0.296), "black", 0.01))
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=24, y_segments=18, size=0.5)
    for v in bm.verts:
        x, yy = v.co.x, v.co.y
        v.co = Vector((x * 0.66, -0.018 * (1 - (2 * x) ** 2 * 0.6) * (1 - (2 * yy) ** 2 * 0.6), yy * 0.5))
    scr = B._obj("screen", bm, "screen", True)
    scr.location = G(0, y + 0.02, 0.3)
    uvl = scr.data.uv_layers.new(name="UVMap")
    for loop in scr.data.loops:
        co = scr.data.vertices[loop.vertex_index].co
        uvl.data[loop.index].uv = (co.x / 0.66 + 0.5, co.z / 0.5 + 0.5)
    p(scr)
    for yy in (y - 0.13, y - 0.05):
        p(cyl("knob", 0.022, 0.02, 0.025, (0.39, yy, 0.31), "metal", rot=(math.pi / 2, 0, 0), seg=16))
    p(cyl("ant_base", 0.05, 0.04, 0.03, (0.1, y + 0.345, -0.05), "plastic", seg=16))
    p(cyl("ant", 0.003, 0.002, 0.6, (0.24, y + 0.6, -0.05), "metal", rot=(0, 0, -0.5), seg=6))
    p(cyl("ant", 0.003, 0.002, 0.42, (0.0, y + 0.5, -0.05), "metal", rot=(0, 0, 0.9), seg=6))  # bent one
    # moss creeping over the top
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=3, radius=0.3)
    m = B._obj("moss", bm, "moss", True)
    m.location = G(-0.16, y + 0.3, -0.05)
    m.scale = (1.0, 0.8, 0.12)
    displaced(m, 0.05, 0.08, seed=3)
    p(m)
    # blood smear on the bezel
    bm = bmesh.new()
    for k in range(4):
        x0 = -0.36 + k * 0.035
        top = y + 0.2 - k * 0.02
        ln = random.uniform(0.18, 0.32)
        vs = [bm.verts.new(G(x0, top, 0.302)), bm.verts.new(G(x0 + 0.018, top, 0.302)),
              bm.verts.new(G(x0 + 0.012, top - ln, 0.302)), bm.verts.new(G(x0 + 0.004, top - ln, 0.302))]
        bm.faces.new(vs)
    bl = B._obj("blood", bm, "blood", False)
    p(bl)
    return pivot


def cable(points):
    cu = bpy.data.curves.new("cable", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.008
    cu.bevel_resolution = 2
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = G(*p)
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new("cable", cu)
    bpy.context.scene.collection.objects.link(o)
    cu.materials.append(B.MATS["cable"])
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg), depsgraph=dg)
    mo = bpy.data.objects.new("cable", me)
    bpy.context.scene.collection.objects.link(mo)
    bpy.data.objects.remove(o, do_unlink=True)
    for pl in me.polygons:
        pl.use_smooth = True
    return mo


def scene():
    B.reset()
    mats()
    ground()
    # the TV sits on an old stump in the clearing
    sx, sz = 1.25, 0.0
    sy = ground_h(sx, sz)
    st = cyl("stump", 0.36, 0.3, 0.42, (sx, sy + 0.12, sz), "bark", seg=20)
    displaced(st, 0.03, 0.08, seed=5)
    cyl("stump_top", 0.3, 0.3, 0.01, (sx, sy + 0.335, sz), "wood_dark", seg=20)
    for k in range(5):
        a = k / 5 * math.tau
        cyl("root", 0.09, 0.03, 0.5, (sx + math.cos(a) * 0.38, sy - 0.02, sz + math.sin(a) * 0.38), "bark",
            rot=(math.sin(a) * 1.25, 0, -math.cos(a) * 1.25), seg=10)
    crt((sx, sy + 0.34, sz), -0.42, 0.05)
    cable([(sx + 0.15, sy + 0.45, sz - 0.3), (sx + 0.5, sy + 0.05, sz - 0.6), (sx + 0.9, ground_h(sx + 0.9, -0.2) + 0.01, -0.2),
           (sx + 1.6, ground_h(sx + 1.6, 0.4) + 0.01, 0.4), (sx + 2.4, ground_h(sx + 2.4, -0.5) + 0.01, -0.5)])
    # tapes in the grass
    for (tx, tz, ry, tl) in [(0.55, 0.55, 0.4, 0.15), (0.75, 0.95, -0.9, 0.0), (1.85, 0.6, 1.4, 0.3), (0.95, 0.42, 2.2, 1.2)]:
        ty = ground_h(tx, tz)
        for o in [box("tape", (0.19, 0.026, 0.105), (tx, ty + 0.03, tz), "black", 0.004, rot=(tl, ry, 0)),
                  box("tape_label", (0.16, 0.003, 0.06), (tx, ty + 0.045, tz), "tape_label", 0, rot=(tl, ry, 0))]:
            pass
    # trees
    trees = [(-1.6, -2.6, 9, 0.42), (3.4, 0.8, 10, 0.5), (4.2, -3.5, 9, 0.38), (-0.4, -5.0, 9, 0.3),
             (2.3, -6.5, 10, 0.34), (-3.2, -1.0, 10, 0.45), (6.0, -1.0, 10, 0.4), (0.9, -9.0, 11, 0.36),
             (-2.6, -8.5, 10, 0.33), (5.0, -8.0, 11, 0.4), (-5.0, -4.5, 11, 0.4), (7.2, -5.0, 11, 0.42)]
    for (x, z, h, r) in trees:
        _, top = tree(x, z, h, r, roots=random.randint(4, 6), branches=3, lean=random.uniform(-0.05, 0.05))
        canopy(top, 1.6 + r * 2, 7)
    for (x, z, s) in [(0.2, -0.7, 0.35), (2.1, -0.6, 0.28), (2.7, 1.3, 0.4), (-0.6, 0.6, 0.22), (1.6, -1.6, 0.5), (-1.0, -1.8, 0.3)]:
        rock(x, z, s)
    for (x, z, s) in [(0.25, 0.9, 0.7), (2.4, 0.4, 0.8), (2.9, -0.8, 1.0), (-0.3, -0.3, 0.6), (0.6, -1.3, 0.8),
                      (3.0, 2.1, 0.9), (1.9, -2.4, 0.9), (-1.3, -0.6, 0.7), (4.0, -1.5, 1.0)]:
        fern(x, z, s)
    grass(1.2, 0.3, 2.3, 4500)
    grass(1.0, -2.5, 3.5, 1800)


if __name__ == "__main__":
    out = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "models"
    os.makedirs(out, exist_ok=True)
    B.OUT = out
    scene()
    B.export("menu_scene")
