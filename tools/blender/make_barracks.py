"""Kasernen für alle drei Fraktionen (Blender).

blender -b -P tools/blender/make_barracks.py -- <projektordner> <west|red|shadow>
Ergebnis: models/buildings/<fraktion>_barracks.glb, shots/<fraktion>_barracks_preview.png   (vorne = -Y)
  Westbund      – zwei Wohnkapseln, Glasfoyer, Hologramm-Trainingsring, Antennen
  Rote Allianz  – zwei Kasernenblöcke mit Satteldach, Torbogen mit Stern, Exerzierplatz, Wachturm
  Schattenfront – Zeltlager um die Feuerstelle, Baumstammbänke, Waffenständer, Übungspuppen
"""
import bpy, math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S

root_dir = sys.argv[sys.argv.index("--") + 1]
which = sys.argv[sys.argv.index("--") + 2]
S.reset()
random.seed(9)
P = []

def M(name, col, metal=0.0, rough=0.7, wear=0.5, dirt=0.5, emit=0.0):
    return S.material(name, col, metal, rough, wear, dirt, emit)

DK = M("Dark", (0.03, 0.03, 0.035), 0.3, 0.7, 0.2, 0.3)
ST = M("Steel", (0.42, 0.43, 0.46), 0.85, 0.35, 0.5, 0.4)
YE = M("Yellow", (0.95, 0.72, 0.08), 0.2, 0.5, 0.5, 0.4)
GLS = M("Glass", (0.07, 0.12, 0.17), 0.9, 0.05, 0.0, 0.15)
GLW = M("GlassLit", (1.0, 0.82, 0.5), 0.0, 0.3, 0.0, 0.0, 1.7)
LC = M("LightCyan", (0.4, 0.85, 1.0), 0.0, 0.3, 0.0, 0.0, 4.0)
LR = M("LightRed", (1.0, 0.12, 0.06), 0.0, 0.3, 0.0, 0.0, 6.0)
LW = M("LightWhite", (1.0, 0.95, 0.8), 0.0, 0.3, 0.0, 0.0, 8.0)
WD = M("Wood", (0.4, 0.28, 0.16), 0.0, 0.9, 0.3, 0.8)
WL = M("WoodLight", (0.55, 0.42, 0.25), 0.0, 0.9, 0.3, 0.8)
CO = M("Concrete", (0.5, 0.47, 0.43), 0.0, 0.88, 0.35, 0.8)

def windows(body, c, s, face, n, z, w=0.5, h=0.7, skip=(), mat_sill=None):
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
        P.append(S.box("Pane", pane, ppos, GLW if lit else GLS, 0.0))
        for dz in (h / 2 + 0.02, -h / 2 - 0.02):
            P.append(S.box("Frame", frame, (ppos[0], ppos[1], z + dz), ST, 0.0))
        P.append(S.box("Sill", sill, spos, mat_sill or CO, 0.01))

def finish(name, cam, tgt, ground=(0.3, 0.32, 0.25)):
    hull = P[0]
    S.join_into(hull, P[1:])
    hull.name = "Hull"
    tex = os.path.join(root_dir, "models", "source", "textures")
    S.bake(hull, 2048, tex)
    os.makedirs(os.path.join(root_dir, "models", "buildings"), exist_ok=True)
    S.export(os.path.join(root_dir, "models", "buildings", "%s_barracks.glb" % name), [hull])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root_dir, "models", "source", "%s_barracks.blend" % name))
    S.preview(os.path.join(root_dir, "shots", "%s_barracks_preview.png" % name), target=tgt, cam_loc=cam, lens=42, ground=ground)
    print("BARRACKS_OK", name)

def dummy(x, y, rot, mat_body, mat_pole=WD):
    P.append(S.cyl("DPole", 0.05, 1.5, (x, y, 0.75), mat_pole, 8))
    P.append(S.box("DBody", (0.4, 0.22, 0.6), (x, y, 1.1), mat_body, 0.05, rot=(0, 0, rot)))
    P.append(S.sphere("DHead", 0.15, (x, y, 1.55), mat_body, segs=10, rings=6))
    P.append(S.box("DArm", (0.7, 0.1, 0.1), (x, y, 1.25), mat_pole, 0.02, rot=(0, 0, rot)))

# ================================================================ WESTBUND
if which == "west":
    PW = M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
    PG = M("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
    TP = M("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
    AS = M("Asphalt", (0.11, 0.115, 0.12), 0.0, 0.85, 0.2, 0.3)
    HOLO = M("Holo", (0.35, 0.8, 1.0), 0.0, 0.3, 0.0, 0.0, 2.5)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CO, 0.03))
    # Zwei Wohnkapseln (liegende Zylinder) mit Sockel, Fensterreihe, Oberlicht, Lüftern
    for sx in (-1, 1):
        cx = sx * 1.85
        P.append(S.box("PodBase", (1.9, 4.4, 0.55), (cx, 0.4, 0.45), PG, 0.04))
        pod = S.cyl("Pod", 1.0, 4.4, (cx, 0.4, 1.35), PW, 28, 0.0, rot=(math.pi / 2, 0, 0))
        pod.dimensions = (2.0, 4.4, 1.9)
        P.append(pod)
        for k in range(5):
            P.append(S.cyl("PodRib", 1.03, 0.1, (cx, -1.5 + k * 0.95, 1.35), TP, 28, rot=(math.pi / 2, 0, 0)))
            P[-1].dimensions = (2.06, 0.1, 1.96)
        for k in range(4):
            y = -1.1 + k * 0.95
            P.append(S.box("Win", (0.05, 0.56, 0.42), (cx + sx * 0.96, y, 1.45), GLW if (k + sx) % 2 else GLS, 0.0, rot=(0, 0, 0)))
            P.append(S.box("WinFrame", (0.07, 0.66, 0.52), (cx + sx * 0.95, y, 1.45), ST, 0.01))
        P.append(S.box("RoofLight", (0.24, 3.8, 0.06), (cx, 0.4, 2.27), LC, 0.0))
        P.append(S.cyl("Vent", 0.2, 0.3, (cx - sx * 0.3, 1.9, 2.3), ST, 12))
        P.append(S.cyl("VentFan", 0.16, 0.03, (cx - sx * 0.3, 1.9, 2.47), DK, 12))
    # Verbindendes Glasfoyer mit Vordach und Schiebetür
    P.append(S.box("Foyer", (1.7, 2.3, 1.6), (0, -1.55, 0.95), GLS, 0.03))
    for k in range(4):
        P.append(S.box("FoyerFin", (0.07, 2.4, 1.7), (-0.82 + k * 0.55, -1.55, 0.95), PW, 0.01))
    P.append(S.box("FoyerRoof", (2.0, 2.6, 0.14), (0, -1.55, 1.84), TP, 0.03))
    P.append(S.box("FoyerStrip", (2.04, 2.64, 0.05), (0, -1.55, 1.74), LC, 0.0))
    P.append(S.box("Door", (0.9, 0.06, 1.35), (0, -2.74, 0.9), GLW, 0.0))
    P.append(S.box("DoorFrame", (1.1, 0.1, 1.5), (0, -2.76, 0.92), PG, 0.02))
    P.append(S.box("Canopy", (2.6, 1.0, 0.08), (0, -3.15, 1.75), GLS, 0.0))
    for sx in (-1.25, 1.25):
        P.append(S.cyl("CanopyCol", 0.05, 1.6, (sx, -3.55, 0.9), ST, 8))
    for k in range(3):
        P.append(S.box("Stair", (2.0, 0.28, 0.07 * (3 - k)), (0, -3.0 - k * 0.28, 0.12 + 0.035 * (3 - k)), CO, 0.01))
    # Hologramm-Trainingsring vorne rechts mit Zielscheiben
    hx, hy = 1.9, -2.9
    P.append(S.cyl("HoloBase", 0.85, 0.08, (hx, hy, 0.15), PG, 28))
    ring = S.cyl("HoloRing", 0.8, 0.03, (hx, hy, 0.22), HOLO, 32)
    inner = S.cyl("cut", 0.68, 0.2, (hx, hy, 0.22), None, 32)
    S.cut(ring, inner)
    P.append(ring)
    for k in range(3):
        a = k * math.tau / 3
        P.append(S.cyl("HoloTarget", 0.2, 0.02, (hx + math.cos(a) * 0.5, hy + math.sin(a) * 0.5, 0.75), HOLO, 14, rot=(math.pi / 2, 0, 0)))
        P.append(S.cyl("HoloPost", 0.015, 0.5, (hx + math.cos(a) * 0.5, hy + math.sin(a) * 0.5, 0.4), HOLO, 6))
    # Antenne, Fahnenmast, Lichtmasten, Technikschrank
    P.append(S.cyl("Antenna", 0.04, 3.4, (-1.1, 2.3, 2.9), ST, 8))
    for j in range(3):
        P.append(S.box("AntBar", (0.5 - j * 0.12, 0.03, 0.03), (-1.1, 2.3, 2.5 + j * 0.45), ST, 0.0))
    P.append(S.sphere("AntLight", 0.08, (-1.1, 2.3, 4.6), LR, segs=10, rings=6))
    P.append(S.cyl("FlagPole", 0.045, 3.2, (2.6, -0.6, 1.6), ST, 8))
    P.append(S.box("Flag", (0.04, 1.0, 0.65), (2.6, -0.1, 2.9), TP, 0.0))
    for (lx, ly) in ((-2.7, -2.7), (2.7, 2.2)):
        P.append(S.cyl("Pole", 0.05, 2.6, (lx, ly, 1.3), ST, 8))
        P.append(S.box("Lamp", (0.55, 0.18, 0.07), (lx, ly - 0.15, 2.62), LW, 0.0))
    P.append(S.box("Cabinet", (0.6, 0.4, 0.9), (-2.7, 1.8, 0.5), PG, 0.03))
    P.append(S.sphere("CabLight", 0.04, (-2.7, 1.58, 0.85), LC, segs=8, rings=4))
    finish("west", (-7.5, -9.5, 6.3), (0, -0.2, 1.2))

# ================================================================ ROTE ALLIANZ
elif which == "red":
    BK = M("Brick", (0.5, 0.27, 0.2), 0.0, 0.9, 0.4, 0.8)
    CD = M("ConcreteDark", (0.3, 0.28, 0.26), 0.0, 0.9, 0.3, 0.8)
    TP = M("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
    GD = M("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
    RS = M("Rust", (0.4, 0.2, 0.09), 0.5, 0.75, 0.8, 0.8)
    WH = M("White", (0.85, 0.85, 0.82), 0.0, 0.7, 0.4, 0.6)
    RD = M("RedBanner", (0.65, 0.08, 0.06), 0.0, 0.8, 0.2, 0.5)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CD, 0.03))
    # Zwei lange Blöcke mit Satteldach (Dachziegel-Optik per Latten), Fensterreihen, Sockel
    for sx in (-1, 1):
        bx = sx * 1.75
        body = S.box("Block", (1.8, 4.6, 1.9), (bx, 0.25, 1.2), BK, 0.03)
        windows(body, (bx, 0.25), (1.8, 4.6), "+x" if sx > 0 else "-x", 5, 1.4, 0.5, 0.65)
        windows(body, (bx, 0.25), (1.8, 4.6), "-y", 1, 1.4, 0.5, 0.65)
        P.append(body)
        P.append(S.box("Plinth", (1.95, 4.75, 0.35), (bx, 0.25, 0.4), CD, 0.02))
        P.append(S.prism_xz("Roof", [(-1.15, 0), (1.15, 0), (0, 1.0)], 4.9, (bx, 0.25, 2.15), TP, 0.02))
        for k in range(9):
            P.append(S.box("Batten", (2.3, 0.05, 0.05), (bx, -2.0 + k * 0.55, 2.15 + 0.02), CD, 0.0, rot=(0, 0, 0)) if False else S.box("Batten", (1.2, 0.04, 0.05), (bx - sx * 0.0, -2.0 + k * 0.55, 2.62), CD, 0.0))
        P.append(S.cyl("Chimney", 0.2, 1.1, (bx + sx * 0.3, 1.6, 3.0), BK, 10))
        P.append(S.box("ChimneyCap", (0.5, 0.5, 0.08), (bx + sx * 0.3, 1.6, 3.58), CD, 0.01))
        P.append(S.box("Door", (0.7, 0.1, 1.3), (bx, -2.07, 0.95), DK, 0.02))
        P.append(S.box("DoorTop", (1.0, 0.25, 0.14), (bx, -2.1, 1.7), CD, 0.02))
    # Torbogen mit Stern und Fahnen am Eingang zwischen den Blöcken
    P.append(S.box("GatePostL", (0.4, 0.4, 2.6), (-0.9, -2.7, 1.5), CD, 0.04))
    P.append(S.box("GatePostR", (0.4, 0.4, 2.6), (0.9, -2.7, 1.5), CD, 0.04))
    arch = S.cyl("Arch", 1.0, 0.4, (0, -2.7, 2.65), CD, 28, 0.0, rot=(math.pi / 2, 0, 0))
    cutter = S.cyl("cut", 0.75, 0.8, (0, -2.7, 2.65), None, 28, rot=(math.pi / 2, 0, 0))
    S.cut(arch, cutter)
    P.append(arch)
    P.append(S.box("ArchBlock", (2.2, 0.4, 0.3), (0, -2.7, 3.55), CD, 0.03))
    star = []
    for i in range(10):
        a = math.pi / 2 + i * math.tau / 10
        r = 0.3 if i % 2 == 0 else 0.12
        star.append((math.cos(a) * r, math.sin(a) * r))
    P.append(S.prism_xz("Star", star, 0.08, (0, -2.95, 3.55), GD, 0.0))
    for sx in (-1.7, 1.7):
        P.append(S.cyl("Pole", 0.04, 3.0, (sx, -3.2, 1.5), ST, 8))
        P.append(S.box("Banner", (0.04, 0.9, 1.6), (sx, -2.7 if sx > 0 else -2.7, 1.9), RD, 0.0))
        P[-1].location = (sx, -3.2 + 0.0, 2.3)
        P[-1].dimensions = (0.04, 0.8, 1.5)
    # Exerzierplatz-Markierungen, Fahnenmast, Hindernisbahn
    for k in range(4):
        P.append(S.box("Line", (2.6, 0.08, 0.02), (0, -1.2 + k * 0.0 - 0.5 * k, 0.26), WH, 0.0)) if False else P.append(S.box("Line", (1.8, 0.07, 0.02), (0, -1.9 + k * -0.0 - 0.0, 0.26 + 0.0), WH, 0.0)) if k == 0 else None
    for k in range(3):
        P.append(S.box("Line", (1.6, 0.07, 0.02), (0, -1.0 + k * 1.2, 0.26), WH, 0.0))
    P.append(S.cyl("FlagPole", 0.05, 3.6, (0, 0.5, 1.8), ST, 8))
    P.append(S.box("Flag", (0.04, 1.2, 0.8), (0, 1.05, 3.2), RD, 0.0))
    P.append(S.sphere("FlagTop", 0.08, (0, 0.5, 3.62), GD, segs=8, rings=4))
    # Wachturm hinten mit Scheinwerfer
    wx, wy = 0, 2.65
    for sx in (-0.3, 0.3):
        for sy in (-0.3, 0.3):
            P.append(S.box("TowerLeg", (0.1, 0.1, 3.2), (wx + sx, wy + sy, 1.8), CD, 0.02))
    P.append(S.box("TowerCab", (1.0, 1.0, 0.7), (wx, wy, 3.5), BK, 0.03))
    P.append(S.box("TowerGlass", (0.8, 0.05, 0.35), (wx, wy - 0.52, 3.55), GLS, 0.0))
    P.append(S.prism_xz("TowerRoof", [(-0.7, 0), (0.7, 0), (0, 0.5)], 1.2, (wx, wy, 3.88), TP, 0.02))
    P.append(S.cyl("SLight", 0.16, 0.2, (wx + 0.55, wy - 0.4, 3.5), ST, 12, rot=(math.radians(70), 0, 0)))
    for k in range(7):
        P.append(S.box("Rung", (0.4, 0.03, 0.03), (wx, wy - 0.34, 0.5 + k * 0.42), ST, 0.0))
    # Munitionskisten, Fässer
    for k in range(4):
        P.append(S.box("Crate", (0.55, 0.4, 0.38), (-2.7 + (k % 2) * 0.6, 2.2 + (k // 2) * 0.45, 0.45), RS if k % 3 == 0 else WD, 0.03, rot=(0, 0, random.uniform(-0.15, 0.15))))
    finish("red", (-7.5, -9.5, 6.3), (0, 0.0, 1.5))

# ================================================================ SCHATTENFRONT
else:
    CV = M("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
    CV2 = M("CanvasGreen", (0.35, 0.37, 0.24), 0.0, 0.95, 0.2, 0.6)
    TP = M("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
    SB = M("Sandbag", (0.55, 0.47, 0.32), 0.0, 1.0, 0.1, 0.9)
    RS = M("Rust", (0.4, 0.2, 0.09), 0.5, 0.75, 0.8, 0.8)
    RB = M("Rubber", (0.04, 0.04, 0.04), 0.0, 0.9, 0.2, 0.5)
    RD = M("RockDark", (0.25, 0.22, 0.18), 0.0, 0.95, 0.2, 0.9)
    GD = M("Ground", (0.4, 0.33, 0.22), 0.0, 1.0, 0.1, 0.8)
    HAY = M("Hay", (0.65, 0.55, 0.28), 0.0, 1.0, 0.1, 0.7)
    P.append(S.box("Yard", (6.0, 6.0, 0.14), (0, 0, 0.0), GD, 0.0))
    def tent(x, y, rot, mat, sc=1.0):
        w, h, l = 2.4 * sc, 1.7 * sc, 2.8 * sc
        P.append(S.prism_xz("Tent", [(-w / 2, 0), (w / 2, 0), (0, h)], l, (x, y, 0.1), mat, 0.0, rot=(0, 0, rot)))
        P.append(S.box("TentFlap", (0.7 * sc, 0.04, 1.2 * sc), (x + math.sin(rot) * (-l / 2) * 0, y - l / 2 * math.cos(rot) * 1.0 + 0.0, 0.7 * sc), DK, 0.0, rot=(0, 0, rot)))
        P.append(S.cyl("TentPole", 0.05, h + 0.4, (x - math.sin(rot) * l / 2 * 0, y - l / 2 * math.cos(rot), h / 2 + 0.2), WD, 6))
        for k in range(2):
            P.append(S.cyl("TentPeg", 0.02, 0.35, (x + (w / 2 + 0.2) * (1 if k else -1) * math.cos(rot), y + (w / 2 + 0.2) * (1 if k else -1) * math.sin(rot), 0.15), WD, 5, rot=(0.5, 0, 0)))
    tent(-1.9, 0.5, 0.0, CV, 1.0)
    tent(1.9, 0.7, 0.0, CV2, 0.95)
    tent(0.0, 2.4, math.pi / 2 * 0.0, CV, 0.8)
    # Tarnnetz in Teamfarbe über Mittelbereich auf Stangen
    for (px, py) in ((-0.9, -1.0), (0.9, -1.0), (-0.9, 0.2), (0.9, 0.2)):
        P.append(S.cyl("NetPole", 0.04, 2.2, (px, py, 1.1), WD, 6))
    P.append(S.box("Net", (2.0, 1.4, 0.04), (0, -0.4, 2.2), TP, 0.0, rot=(0.08, 0.0, 0.03)))
    # Feuerstelle (Flammen im Spiel) mit Steinring und Baumstammbänken
    fx, fy = 0.0, -1.4
    for i in range(9):
        a = i * math.tau / 9
        P.append(S.box("Stone", (0.24, 0.18, 0.16), (fx + math.cos(a) * 0.46, fy + math.sin(a) * 0.46, 0.16), RD, 0.04, rot=(0, 0, a)))
    for i in range(3):
        P.append(S.cyl("Log", 0.06, 0.6, (fx, fy, 0.2), WD, 8, rot=(math.pi / 2, 0, i * 1.05)))
    for i in range(3):
        a = i * math.tau / 3 + 0.5
        P.append(S.cyl("Bench", 0.14, 1.3, (fx + math.cos(a) * 1.15, fy + math.sin(a) * 1.15, 0.28), WD, 10, rot=(math.pi / 2, 0, a + math.pi / 2)))
    P.append(S.cyl("Tripod1", 0.025, 1.4, (fx - 0.2, fy, 0.9), WD, 6, rot=(0.0, 0.3, 0)))
    P.append(S.cyl("Tripod2", 0.025, 1.4, (fx + 0.2, fy, 0.9), WD, 6, rot=(0.0, -0.3, 0)))
    P.append(S.cyl("Pot", 0.17, 0.2, (fx, fy, 0.55), DK, 12))
    # Waffenständer, Übungspuppen, Munition
    P.append(S.box("RackBase", (1.3, 0.3, 0.1), (2.3, -2.3, 0.2), WD, 0.02))
    P.append(S.box("RackTop", (1.3, 0.08, 0.1), (2.3, -2.3, 1.1), WD, 0.02))
    for sx in (-0.6, 0.6):
        P.append(S.box("RackPost", (0.1, 0.1, 1.0), (2.3 + sx, -2.3, 0.7), WD, 0.02))
    for k in range(4):
        P.append(S.box("Rifle", (0.05, 0.05, 1.1), (1.85 + k * 0.3, -2.3, 0.7), DK, 0.01, rot=(0.1, 0.0, 0)))
    dummy(-2.2, -2.2, 0.3, CV)
    dummy(-1.4, -2.7, -0.2, CV2)
    for k in range(4):
        P.append(S.box("Crate", (0.5, 0.4, 0.35), (-2.5 + (k % 2) * 0.55, 2.3 + (k // 2) * 0.42, 0.3 + (k // 2) * 0.0), WL if k % 2 else RS, 0.03, rot=(0, 0, random.uniform(-0.2, 0.2))))
    # Sandsäcke, Reifen, Laternen
    for r in range(2):
        for i in range(5):
            P.append(S.box("Bag", (0.62, 0.34, 0.2), (-1.5 + i * 0.64 + (0.3 if r % 2 else 0), -3.1, 0.2 + r * 0.19), SB, 0.07, rot=(0, 0, random.uniform(-0.08, 0.08))))
    for i in range(4):
        P.append(S.cyl("Tire", 0.34, 0.2, (2.7, 2.2, 0.2 + i * 0.2), RB, 14))
    for (lx, ly) in ((-2.7, -1.0), (2.6, 0.0)):
        P.append(S.cyl("LampPost", 0.04, 1.7, (lx, ly, 0.85), WD, 6))
        P.append(S.box("Lamp", (0.2, 0.2, 0.28), (lx, ly, 1.85), LW, 0.03))
    finish("shadow", (-7.5, -9.5, 6.0), (0, -0.2, 1.0), ground=(0.45, 0.38, 0.27))
