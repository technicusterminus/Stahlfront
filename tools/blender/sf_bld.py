"""Gemeinsame Bausteine für die Gebäudeskripte (Kraftwerke, Nachschub, Flugfelder, Abwehr, Forschung, Superwaffen).

Aufruf der Skripte:  blender -b -P tools/blender/make_power.py -- <projektordner> <west|red|shadow>
Vorne = -Y, Boden = z 0. Ergebnis: models/buildings/<fraktion>_<rolle>.glb, shots/<fraktion>_<rolle>_preview.png
"""
import bpy, math, os, random, sys
from types import SimpleNamespace
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S

root_dir = ""
which = ""
P = []

def setup(seed):
    global root_dir, which, P
    root_dir = sys.argv[sys.argv.index("--") + 1]
    which = sys.argv[sys.argv.index("--") + 2]
    S.reset()
    random.seed(seed)
    P = []
    return which, P

def M(name, col, metal=0.0, rough=0.7, wear=0.5, dirt=0.5, emit=0.0):
    return S.material(name, col, metal, rough, wear, dirt, emit)

def mats():
    return SimpleNamespace(
        DK=M("Dark", (0.03, 0.03, 0.035), 0.3, 0.7, 0.2, 0.3),
        ST=M("Steel", (0.42, 0.43, 0.46), 0.85, 0.35, 0.5, 0.4),
        YE=M("Yellow", (0.95, 0.72, 0.08), 0.2, 0.5, 0.5, 0.4),
        GLS=M("Glass", (0.07, 0.12, 0.17), 0.9, 0.05, 0.0, 0.15),
        GLW=M("GlassLit", (1.0, 0.82, 0.5), 0.0, 0.3, 0.0, 0.0, 1.7),
        LC=M("LightCyan", (0.4, 0.85, 1.0), 0.0, 0.3, 0.0, 0.0, 4.0),
        LR=M("LightRed", (1.0, 0.12, 0.06), 0.0, 0.3, 0.0, 0.0, 6.0),
        LW=M("LightWhite", (1.0, 0.95, 0.8), 0.0, 0.3, 0.0, 0.0, 8.0),
        WD=M("Wood", (0.4, 0.28, 0.16), 0.0, 0.9, 0.3, 0.8),
        WL=M("WoodLight", (0.55, 0.42, 0.25), 0.0, 0.9, 0.3, 0.8),
        CO=M("Concrete", (0.5, 0.47, 0.43), 0.0, 0.88, 0.35, 0.8),
        CD=M("ConcreteDark", (0.3, 0.28, 0.26), 0.0, 0.9, 0.3, 0.8),
        RS=M("Rust", (0.4, 0.2, 0.09), 0.5, 0.75, 0.8, 0.8),
        RB=M("Rubber", (0.04, 0.04, 0.04), 0.0, 0.9, 0.2, 0.5),
        WH=M("White", (0.85, 0.85, 0.82), 0.0, 0.7, 0.4, 0.6),
    )

def windows(body, c, s, face, n, z, w=0.5, h=0.7, skip=(), mats_=None):
    m = mats_ or mats()
    for i in range(n):
        if i in skip:
            continue
        t = -0.5 + (i + 0.5) / n
        if face in ("-y", "+y"):
            sy = -1 if face == "-y" else 1
            x, y = c[0] + t * s[0] * 0.86, c[1] + sy * s[1] / 2
            cut = S.box("cut", (w, 0.6, h), (x, y, z), None, 0.0)
            pane = (w - 0.06, 0.05, h - 0.06); ppos = (x, y - sy * 0.14, z)
            frame = (w + 0.12, 0.06, 0.07); sill = (w + 0.25, 0.2, 0.08); spos = (x, y + sy * 0.07, z - h / 2 - 0.09)
        else:
            sx = 1 if face == "+x" else -1
            x, y = c[0] + sx * s[0] / 2, c[1] + t * s[1] * 0.86
            cut = S.box("cut", (0.6, w, h), (x, y, z), None, 0.0)
            pane = (0.05, w - 0.06, h - 0.06); ppos = (x - sx * 0.14, y, z)
            frame = (0.06, w + 0.12, 0.07); sill = (0.2, w + 0.25, 0.08); spos = (x + sx * 0.07, y, z - h / 2 - 0.09)
        S.cut(body, cut)
        lit = (i * 5 + int(abs(z) * 3) + len(face)) % 3 == 0
        P.append(S.box("Pane", pane, ppos, m.GLW if lit else m.GLS, 0.0))
        for dz in (h / 2 + 0.02, -h / 2 - 0.02):
            P.append(S.box("Frame", frame, (ppos[0], ppos[1], z + dz), m.ST, 0.0))
        P.append(S.box("Sill", sill, spos, m.CO, 0.01))

def ring(name, r_out, r_in, depth, loc, mat, verts=32, rot=(0, 0, 0)):
    """Scheibe mit Loch (Reaktorring, Reifen, Brunnenrand)."""
    r = S.cyl(name, r_out, depth, loc, mat, verts, rot=rot)
    c = S.cyl("cut", r_in, depth * 2.0, loc, None, verts, rot=rot)
    S.cut(r, c)
    return r

def star(depth, loc, mat, r_out=0.3, r_in=0.12):
    pts = []
    for i in range(10):
        a = math.pi / 2 + i * math.tau / 10
        r = r_out if i % 2 == 0 else r_in
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return S.prism_xz("Star", pts, depth, loc, mat, 0.0)

def part(name, parts, pivot, parent=None, bake=0):
    """Eigenes bewegliches Teil (Turret, Barrel, Spin): Teile verschmelzen, Ursprung auf den Drehpunkt setzen."""
    o = parts[0]
    if len(parts) > 1:
        S.join_into(o, parts[1:])
    o.name = name
    S.activate(o)
    bpy.context.scene.cursor.location = pivot
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    if bake:
        S.bake(o, bake, os.path.join(root_dir, "models", "source", "textures"))
    if parent is not None:
        S.parent(o, parent)
    return o

def finish(role, name, cam, tgt, ground=(0.3, 0.32, 0.25), size=2048, extras=()):
    hull = P[0]
    S.join_into(hull, P[1:])
    hull.name = "Hull"
    tex = os.path.join(root_dir, "models", "source", "textures")
    S.bake(hull, size, tex)
    os.makedirs(os.path.join(root_dir, "models", "buildings"), exist_ok=True)
    S.export(os.path.join(root_dir, "models", "buildings", "%s_%s.glb" % (name, role)), [hull] + list(extras))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root_dir, "models", "source", "%s_%s.blend" % (name, role)))
    S.preview(os.path.join(root_dir, "shots", "%s_%s_preview.png" % (name, role)), target=tgt, cam_loc=cam, lens=42, ground=ground)
    print("BUILDING_OK", role, name)
