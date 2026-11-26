"""Kazeta 13 - 2D art (paintings, photos, drawings, decals) drawn with PIL. Run: python3 make_art.py <out_dir>"""
import math, random, sys, os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
os.makedirs(OUT, exist_ok=True)
FONTS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "fonts")
R = random.Random(7)
def marker(sz): return ImageFont.truetype(os.path.join(FONTS, "PermanentMarker-Regular.ttf"), sz)
def typew(sz): return ImageFont.truetype(os.path.join(FONTS, "SpecialElite-Regular.ttf"), sz)
def serif(sz): return ImageFont.truetype(os.path.join(FONTS, "SpecialElite-Regular.ttf"), sz)

def vgrad(w, h, stops):
    im = Image.new("RGB", (w, h))
    d = ImageDraw.Draw(im)
    for y in range(h):
        t = y / (h - 1)
        for i in range(len(stops) - 1):
            a, ca = stops[i]; b, cb = stops[i + 1]
            if a <= t <= b:
                k = (t - a) / max(1e-6, b - a)
                c = tuple(int(ca[j] + (cb[j] - ca[j]) * k) for j in range(3))
                d.line([(0, y), (w, y)], fill=c)
                break
    return im

def hexc(s):
    s = s.lstrip("#")
    if len(s) == 3: s = "".join(c * 2 for c in s)
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))

def speck(im, n, a, dark=True):
    px = im.load(); w, h = im.size
    for _ in range(n):
        x, y = R.randrange(w), R.randrange(h)
        c = px[x, y]
        k = (1 - a * R.random()) if dark else (1 + a * R.random())
        px[x, y] = tuple(max(0, min(255, int(v * k))) for v in c[:3])
    return im

def plate(d, w, h, num):
    d.rectangle([w / 2 - 34, h - 34, w / 2 + 34, h - 10], fill=hexc("b08d45"))
    d.text((w / 2, h - 22), num, fill=hexc("2a1c0c"), font=serif(18), anchor="mm")

def radial(d, cx, cy, r, c0, c1, steps=24):
    for i in range(steps, 0, -1):
        t = i / steps
        c = tuple(int(c0[j] + (c1[j] - c0[j]) * t) for j in range(3))
        d.ellipse([cx - r * t, cy - r * t, cx + r * t, cy + r * t], fill=c)

S = 2  # supersample
def save(im, name, w=None, h=None):
    if w: im = im.resize((w, h), Image.LANCZOS)
    im.save(os.path.join(OUT, name))

# ---------- paintings ----------
def paint1():
    w, h = 256, 320
    im = vgrad(w, h, [(0, hexc("3a0a08")), (.6, hexc("a2341c")), (1, hexc("1a0a06"))]); d = ImageDraw.Draw(im)
    pts = [(0, h * .78)] + [(x, h * .74 + math.sin(x * .05) * 10) for x in range(0, w + 1, 16)] + [(w, h), (0, h)]
    d.polygon(pts, fill=hexc("0d0806"))
    for x, y in [(50, 60), (120, 42), (190, 70), (80, 120), (160, 110), (210, 150), (110, 175)]:
        d.line([(x - 16, y - 6), (x - 7, y - 11), (x, y)], fill=hexc("050302"), width=4)
        d.line([(x, y), (x + 7, y - 11), (x + 16, y - 6)], fill=hexc("050302"), width=4)
    speck(im, 1500, .25); plate(d, w, h, "I"); save(im, "paint1.png")
def paint2():
    w, h = 256, 320
    im = Image.new("RGB", (w, h), hexc("22301e")); d = ImageDraw.Draw(im)
    d.rectangle([0, h * .62, w, h], fill=hexc("3a2a1a"))
    d.ellipse([w / 2 - 96, h * .66 - 26, w / 2 + 96, h * .66 + 26], fill=hexc("d8d0bc"))
    for x, y in [(95, 175), (150, 172), (124, 150)]:
        radial(d, x, y, 28, hexc("e06048"), hexc("6a0d08"))
        d.rectangle([x - 1, y - 34, x + 2, y - 24], fill=hexc("2a1a0a"))
    speck(im, 1500, .25); plate(d, w, h, "II"); save(im, "paint2.png")
def paint3():
    w, h = 256, 320
    im = Image.new("RGB", (w, h), hexc("120e14")); d = ImageDraw.Draw(im)
    d.rectangle([48, 170, 208, 240], fill=hexc("e2d0c0")); d.rectangle([48, 166, 208, 178], fill=hexc("c4506a"))
    for i in range(9):
        x = 62 + i * 16.5
        d.rectangle([x, 128, x + 6, 168], fill=hexc(["6ad", "d66", "dd6"][i % 3]))
        radial(d, x + 3, 118, 14, (255, 230, 140), (60, 30, 20), 10)
    d.rectangle([200, 40, 222, 180], fill=(10, 8, 10)); d.ellipse([198, 18, 224, 54], fill=(10, 8, 10))
    speck(im, 1500, .25); plate(d, w, h, "III"); save(im, "paint3.png")
def paint4():
    w, h = 256, 320
    im = Image.new("RGB", (w, h), hexc("ece6d6")); d = ImageDraw.Draw(im)
    d.line([(0, h * .8), (w, h * .8)], fill=hexc("2e7d32"), width=6)
    d.ellipse([108, 42, 148, 98], fill=hexc("111")); d.rectangle([114, 95, 142, 245], fill=hexc("111"))
    d.line([(116, 110), (70, 220)], fill=hexc("111"), width=7); d.line([(140, 110), (186, 220)], fill=hexc("111"), width=7)
    d.text((128, 266), "HOSŤ", fill=hexc("b71c1c"), font=marker(30), anchor="mm")
    plate(d, w, h, "IV"); save(im, "paint4.png")

# ---------- family photo ----------
def fam(fake):
    w, h = 256, 200
    im = vgrad(w, h, [(0, hexc("8a7a5c")), (1, hexc("4b3f2c"))]); d = ImageDraw.Draw(im)
    def fig(x, hh, c):
        d.ellipse([x - hh * .12, h - hh - 6 - hh * .14, x + hh * .12, h - hh - 6 + hh * .14], fill=c)
        d.polygon([(x - hh * .2, h), (x - hh * .21, h - hh * .55), (x, h - hh * .82), (x + hh * .21, h - hh * .55), (x + hh * .2, h)], fill=c)
    fig(70, 150, hexc("2b221a")); fig(118, 138, hexc("3a2a22")); fig(160, 96, hexc("322820")); fig(196, 80, hexc("2a241d"))
    if fake:
        d.ellipse([218, 0, 246, 44], fill=hexc("0a0908")); d.rectangle([222, 40, 244, h], fill=hexc("0a0908"))
    speck(im, 1500, .3); d.rectangle([0, 0, w - 1, h - 1], outline=hexc("efe6d2"), width=10)
    save(im, "family_fake.png" if fake else "family.png")

# ---------- Lucia photos (youngest -> oldest) ----------
def photos():
    w, h = 160, 200
    def base(c): im = Image.new("RGB", (w, h), hexc(c)); return im, ImageDraw.Draw(im)
    im, d = base("d8cbb0"); d.rectangle([20, 110, 140, 170], fill=hexc("8a6d4a"))
    for i in range(7): d.rectangle([24 + i * 18, 80, 29 + i * 18, 120], fill=hexc("8a6d4a"))
    d.ellipse([66, 94, 94, 122], fill=hexc("e8c9b0")); d.rectangle([56, 118, 104, 138], fill=hexc("f4efe6"))
    d.text((10, 182), "Lucia", fill=hexc("5a4632"), font=typew(12)); speck(im, 800, .2); save(im, "photo0.png")
    im, d = base("cdbf9e"); d.rectangle([64, 104, 96, 148], fill=hexc("4a6a8a")); d.ellipse([66, 78, 94, 106], fill=hexc("e8c9b0"))
    d.ellipse([96, 118, 120, 142], fill=hexc("7a5232")); d.ellipse([100, 106, 116, 122], fill=hexc("7a5232"))
    d.rectangle([66, 148, 74, 168], fill=hexc("e8c9b0")); d.rectangle([86, 148, 94, 168], fill=hexc("e8c9b0")); speck(im, 800, .2); save(im, "photo1.png")
    im, d = base("c2b391"); d.rectangle([60, 74, 100, 138], fill=hexc("8a2c2c")); d.rectangle([96, 80, 114, 120], fill=hexc("2e4a6a"))
    d.ellipse([65, 45, 95, 75], fill=hexc("e8c9b0")); d.rectangle([64, 44, 96, 54], fill=hexc("6a4a2a"))
    d.rectangle([64, 138, 73, 178], fill=hexc("e8c9b0")); d.rectangle([87, 138, 96, 178], fill=hexc("e8c9b0")); speck(im, 800, .2); save(im, "photo2.png")
    im, d = base("b5a684"); d.rectangle([58, 62, 102, 132], fill=hexc("6a2a3a")); d.ellipse([65, 31, 95, 61], fill=hexc("e8c9b0"))
    for i in range(9):
        x = 64 + R.random() * 30; y = 32 + R.random() * 10
        d.line([(x, y), (x + 2 + R.random() * 4, y + 20 + R.random() * 14)], fill=hexc("111"), width=3)
    d.rectangle([40, 140, 120, 164], fill=hexc("e2d0c0"))
    for i in range(9): d.rectangle([44 + i * 8, 128, 47 + i * 8, 140], fill=hexc("dd6"))
    d.rectangle([64, 132, 73, 172], fill=hexc("e8c9b0")); d.rectangle([87, 132, 96, 172], fill=hexc("e8c9b0")); speck(im, 800, .2); save(im, "photo3.png")

def drawing():
    w, h = 320, 240
    im = Image.new("RGB", (w, h), hexc("efe9da")); d = ImageDraw.Draw(im)
    d.rectangle([30, 40, 290, 190], outline=hexc("335"), width=4)
    d.text((100, 8), "POISTKY", fill=hexc("b71c1c"), font=marker(22))
    for i, u in enumerate([1, 0, 1, 1, 0]):
        x = 62 + i * 50
        d.rectangle([x - 6, 70, x + 6, 160], fill=hexc("333"))
        if u: d.polygon([(x, 64), (x - 14, 92), (x + 14, 92)], fill=hexc("2e7d32"))
        else: d.polygon([(x, 168), (x - 14, 140), (x + 14, 140)], fill=hexc("b71c1c"))
    d.text((22, 206), "otec mi ukázal. hore dole hore hore dole", fill=hexc("355"), font=marker(15))
    save(im, "drawing.png")

def granny():
    w, h = 200, 260
    im = Image.new("RGB", (w, h), hexc("2a221a")); d = ImageDraw.Draw(im)
    d.ellipse([10, 160, 190, 340], fill=hexc("3a3026")); d.ellipse([52, 48, 148, 172], fill=hexc("bfae96"))
    d.pieslice([46, 36, 154, 96], 180, 360, fill=hexc("d8d2c6"))
    for s in (-1, 1):
        for i in range(7):
            x = 100 + s * 18 - 8 + R.random() * 16
            d.line([(x, 96 + R.random() * 6), (x + R.random() * 4 - 2, 110 + R.random() * 6)], fill=hexc("100"), width=4)
    d.rectangle([88, 140, 112, 143], fill=hexc("4a1a14")); speck(im, 1500, .3); save(im, "granny.png")

def blood(name, seed, w=512):
    rr = random.Random(seed)
    im = Image.new("RGBA", (w, w), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    for i in range(30, 0, -1):
        t = i / 30; a = int(220 * (1 - t) ** 0.6)
        d.ellipse([w / 2 - w * .45 * t, w / 2 - w * .4 * t, w / 2 + w * .45 * t, w / 2 + w * .4 * t], fill=(70, 6, 4, a))
    for i in range(26):
        x = w / 2 + (rr.random() - .5) * w * .85; y = w / 2 + (rr.random() - .5) * w * .85; r = 3 + rr.random() * 14
        d.ellipse([x - r, y - r, x + r, y + r], fill=(70, 6, 4, 210))
    im = im.filter(ImageFilter.GaussianBlur(1.2)); im.save(os.path.join(OUT, name))

def handprints():
    w, h = 256, 360
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
    def hand(x, y, rot, s):
        layer = Image.new("RGBA", (200, 260), (0, 0, 0, 0)); g = ImageDraw.Draw(layer)
        g.ellipse([60, 120, 140, 216], fill=(90, 8, 5, 220))
        for i in range(4): g.rectangle([66 + i * 19, 30, 78 + i * 19, 130], fill=(90, 8, 5, 220))
        g.rectangle([136, 120, 148, 175], fill=(90, 8, 5, 220))
        for k in range(4): g.rectangle([70 + k * 16, 200, 73 + k * 16, 200 + R.random() * 60], fill=(80, 6, 4, 200))
        layer = layer.rotate(math.degrees(rot), expand=True).resize((int(200 * s), int(260 * s)))
        im.alpha_composite(layer, (int(x), int(y)))
    hand(10, 10, -.2, .7); hand(110, 90, .25, .6); hand(50, 190, .05, .55)
    im.save(os.path.join(OUT, "hands.png"))

def tvframe_noise():
    pass

paint1(); paint2(); paint3(); paint4(); fam(False); fam(True); photos(); drawing(); granny()
blood("blood1.png", 1); blood("blood2.png", 2); handprints()
print("art done")
