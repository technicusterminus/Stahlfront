"""Rote Allianz – Hauptquartier: gestufter Sichtbetonbau mit Säulenportikus, Giebel, Stern,
Fensterreihen mit Laibungen, Sockel, Treppe, Fahnenmasten, Funkturm und Scheinwerfern.

blender -b -P tools/blender/make_red_hq.py -- <projektordner>
Ergebnis: models/buildings/red_hq.glb, shots/red_hq_preview.png   (vorne = -Y)
"""
import bpy, math, os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S

root_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
S.reset()

CO = S.material("Concrete", (0.5, 0.47, 0.43), 0.0, 0.88, 0.35, 0.8)
CD = S.material("ConcreteDark", (0.3, 0.28, 0.26), 0.0, 0.9, 0.3, 0.8)
TP = S.material("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
GL = S.material("Glass", (0.08, 0.1, 0.12), 0.8, 0.1, 0.0, 0.2)
GW = S.material("GlassLit", (1.0, 0.8, 0.45), 0.0, 0.3, 0.0, 0.0, 1.8)
ST = S.material("Steel", (0.38, 0.38, 0.4), 0.85, 0.4, 0.5, 0.6)
GD = S.material("Gold", (0.95, 0.75, 0.2), 0.9, 0.3, 0.1, 0.2, 0.0)
GE = S.material("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
RD = S.material("RedBanner", (0.65, 0.08, 0.06), 0.0, 0.8, 0.2, 0.5)
LR = S.material("LightRed", (1.0, 0.12, 0.06), 0.0, 0.3, 0.0, 0.0, 6.0)
LW = S.material("LightWhite", (1.0, 0.95, 0.8), 0.0, 0.3, 0.0, 0.0, 8.0)
BR = S.material("Bronze", (0.45, 0.32, 0.16), 0.85, 0.35, 0.2, 0.3)

P = []

# ------------------------------------------------------------------ Sockel mit Treppe
P.append(S.box("Plinth", (9.0, 8.0, 0.55), (0, 0.0, -0.1), CD, 0.04))
for i in range(5):
    P.append(S.box("Step%d" % i, (5.6, 0.34, 0.1 * (5 - i)), (0, -4.15 - i * 0.3, 0.05 * (5 - i) - 0.1), CO, 0.015))

# ------------------------------------------------------------------ Drei Stufen mit Fensterreihen
tiers = [  # (Breite, Tiefe, Höhe, y-Versatz)
    (8.4, 6.6, 2.5, 0.2),
    (6.4, 5.0, 2.3, 0.5),
    (4.0, 3.2, 2.1, 0.8),
]
z = 0.2
for ti, (tw, td, th, yoff) in enumerate(tiers):
    body = S.box("Tier%d" % ti, (tw, td, th), (0, yoff, z + th / 2), CO, 0.03)
    # Fensteröffnungen vorne und seitlich (Boolean für echte Laibungen)
    n = max(2, int(tw / 1.15))
    cutters = []
    for i in range(n):
        x = -tw / 2 + tw * (i + 0.5) / n
        if ti == 0 and abs(x) < 2.0:
            continue  # Portikus bleibt frei
        cutters.append((x, yoff - td / 2, z + th * 0.55, 0.55, 0.5, 1.05))
    ns = max(2, int(td / 1.2))
    for sx in (-1, 1):
        for i in range(ns):
            y = yoff - td / 2 + td * (i + 0.5) / ns
            cutters.append((sx * tw / 2, y, z + th * 0.55, 0.5, 0.55, 1.05))
    for (cx, cy, cz, w1, d1, h1) in cutters:
        side = abs(cx) > tw / 2 - 0.01
        size = (d1, w1, h1) if side else (w1, d1, h1)
        c = S.box("cut", size, (cx, cy, cz), None, 0.0)
        S.cut(body, c)
    P.append(body)
    for (cx, cy, cz, w1, d1, h1) in cutters:
        side = abs(cx) > tw / 2 - 0.01
        lit = (int(cx * 5) + int(cy * 3) + ti) % 3 == 0
        gsz = (0.04, w1 - 0.06, h1 - 0.06) if side else (w1 - 0.06, 0.04, h1 - 0.06)
        gx = cx + (0.12 if cx < 0 else -0.12) * (1 if side else 0)
        gy = cy + (0 if side else 0.14)
        P.append(S.box("Pane", gsz, (gx, gy, cz), GW if lit else GL, 0.0))
        fsz = (0.06, w1 + 0.1, 0.06) if side else (w1 + 0.1, 0.06, 0.06)
        for dz in (h1 / 2 + 0.04, -h1 / 2 - 0.02):
            P.append(S.box("Frame", fsz, (gx, gy, cz + dz), ST, 0.0))
        ssz = (0.2, w1 + 0.25, 0.08) if side else (w1 + 0.25, 0.2, 0.08)
        sy = cy - 0.08 if not side else cy
        sx2 = cx - (0.08 if cx > 0 else -0.08) * (1 if side else 0)
        P.append(S.box("Sill", ssz, (sx2 + (0.08 if side and cx > 0 else (-0.08 if side else 0)), sy, cz - h1 / 2 - 0.08), CD, 0.01))
    # Gesims und Absatz
    P.append(S.box("Cornice%d" % ti, (tw + 0.3, td + 0.3, 0.16), (0, yoff, z + th + 0.08), TP, 0.02))
    P.append(S.box("Band%d" % ti, (tw + 0.06, td + 0.06, 0.12), (0, yoff, z + 0.14), CD, 0.015))
    # Eckpilaster
    for sx in (-1, 1):
        for sy in (-1, 1):
            P.append(S.box("Pilaster", (0.32, 0.32, th), (sx * (tw / 2 - 0.1), yoff + sy * (td / 2 - 0.1), z + th / 2), CD, 0.03))
    z += th + 0.16

# ------------------------------------------------------------------ Säulenportikus
fy = 0.2 - 6.6 / 2 - 0.1   # Vorderkante unterste Stufe
for k in range(6):
    x = -2.4 + k * 0.96
    P.append(S.cyl("Column", 0.2, 2.5, (x, fy - 1.05, 1.45), CO, 20, 0.0))
    P.append(S.cyl("Capital", 0.27, 0.16, (x, fy - 1.05, 2.78), CD, 20))
    P.append(S.cyl("ColBase", 0.26, 0.14, (x, fy - 1.05, 0.28), CD, 20))
P.append(S.box("Entablature", (5.9, 1.75, 0.34), (0, fy - 0.6, 2.95), CO, 0.03))
P.append(S.box("EntabBand", (6.0, 1.82, 0.1), (0, fy - 0.6, 2.75), TP, 0.01))
# Giebel
P.append(S.prism_xz("Pediment", [(-3.0, 0), (3.0, 0), (0, 1.15)], 1.75, (0, fy - 0.6, 3.12), CO, 0.03))
P.append(S.prism_xz("PedimentInner", [(-2.5, 0.08), (2.5, 0.08), (0, 0.95)], 0.12, (0, fy - 1.42, 3.12), CD, 0.0))
# Stern im Giebel
star_pts = []
for i in range(10):
    a = math.pi / 2 + i * math.tau / 10
    r = 0.55 if i % 2 == 0 else 0.23
    star_pts.append((math.cos(a) * r, math.sin(a) * r))
P.append(S.prism_xz("Star", star_pts, 0.1, (0, fy - 1.5, 3.55), GE, 0.0))
# Portal
P.append(S.box("Portal", (1.9, 0.3, 2.3), (0, fy + 0.05, 1.3), CD, 0.04))
P.append(S.box("Doors", (1.7, 0.06, 2.1), (0, fy - 0.12, 1.25), BR, 0.02))
P.append(S.box("DoorSplit", (0.05, 0.08, 2.1), (0, fy - 0.15, 1.25), CD, 0.0))
for dx in (-0.42, 0.42):
    P.append(S.sphere("Handle", 0.05, (dx * 0.5 + (0.1 if dx > 0 else -0.1), fy - 0.17, 1.2), GD, segs=8, rings=4))
# Laternen am Portal
for sx in (-1.0, 1.0):
    P.append(S.cyl("LampPole", 0.04, 1.3, (sx * 1.3, fy - 0.25, 1.15), ST, 8))
    P.append(S.box("Lamp", (0.2, 0.2, 0.3), (sx * 1.3, fy - 0.25, 1.9), LW, 0.02))

# ------------------------------------------------------------------ Großer Stern an oberster Stufe
P.append(S.prism_xz("StarTop", [(p[0] * 1.3, p[1] * 1.3) for p in star_pts], 0.1, (0, 0.8 - 3.2 / 2 - 0.1, z - 1.1), GE, 0.0))

# ------------------------------------------------------------------ Dach: Aufbauten, Mast, Fahnen
for k in range(3):
    P.append(S.cyl("Vent", 0.2, 0.5, (-1.4 + k * 1.1, 1.1, z + 0.4), ST, 12))
    P.append(S.cyl("VentCap", 0.28, 0.06, (-1.4 + k * 1.1, 1.1, z + 0.68), CD, 12))
P.append(S.box("Penthouse", (1.8, 1.6, 0.9), (0.9, 0.3, z + 0.45), CO, 0.03))
# Funkturm (Gitter)
tx, ty = 1.7, 0.9
for cx in (-0.25, 0.25):
    for cy in (-0.25, 0.25):
        P.append(S.cyl("Leg", 0.03, 6.0, (tx + cx, ty + cy, z + 3.0), RD, 6))
for i in range(8):
    zz = z + 0.4 + i * 0.75
    for a in (0, 1):
        P.append(S.box("Brace", (0.72, 0.03, 0.03), (tx, ty + (0.25 if a else -0.25), zz), ST if i % 2 else RD, 0.0, rot=(0, 0.9 if i % 2 else -0.9, 0)))
        P.append(S.box("Brace", (0.03, 0.72, 0.03), (tx + (0.25 if a else -0.25), ty, zz), ST if i % 2 else RD, 0.0, rot=(0.9 if i % 2 else -0.9, 0, 0)))
P.append(S.sphere("TowerLight", 0.1, (tx, ty, z + 6.1), LR, segs=10, rings=6))
P.append(S.sphere("TowerLight2", 0.1, (tx, ty - 0.3, z + 3.2), LR, segs=10, rings=6))
# Fahnenmasten mit Fahnen
for sx in (-2.4, 2.4):
    P.append(S.cyl("FlagPole", 0.045, 3.2, (sx, 0.9, z + 1.6), ST, 8))
    P.append(S.sphere("FlagTop", 0.07, (sx, 0.9, z + 3.2), GD, segs=8, rings=4))
    P.append(S.box("Flag", (0.04, 1.3, 0.85), (sx, 0.9 + 0.65, z + 2.7), RD, 0.0))

# ------------------------------------------------------------------ Denkmal und Scheinwerfer auf dem Vorplatz
P.append(S.box("MonBase", (1.2, 1.2, 1.1), (-4.1, -3.4, 0.45), CO, 0.03))
P.append(S.box("MonCap", (1.0, 1.0, 0.1), (-4.1, -3.4, 1.05), BR, 0.01))
P.append(S.cyl("MonBody", 0.2, 0.9, (-4.1, -3.4, 1.55), BR, 12))
P.append(S.sphere("MonHead", 0.17, (-4.1, -3.4, 2.15), BR, segs=12, rings=8))
P.append(S.cyl("MonArm", 0.06, 0.8, (-3.9, -3.4, 2.1), BR, 8, rot=(0, math.radians(35), 0)))
for sx in (-1, 1):
    P.append(S.cyl("SLPole", 0.07, 2.2, (sx * 4.2, 3.0, 1.0), ST, 8))
    P.append(S.cyl("SLHead", 0.3, 0.32, (sx * 4.2, 3.0, 2.2), ST, 12, rot=(math.radians(60), 0, 0)))
    P.append(S.cyl("SLLens", 0.26, 0.03, (sx * 4.2, 2.84, 2.1), LW, 12, rot=(math.radians(60), 0, 0)))

# ------------------------------------------------------------------ Zusammenführen, backen, exportieren
hull = P[0]
S.join_into(hull, P[1:])
hull.name = "Hull"
tex = os.path.join(root_dir, "models", "source", "textures")
S.bake(hull, 2048, tex)
os.makedirs(os.path.join(root_dir, "models", "buildings"), exist_ok=True)
S.export(os.path.join(root_dir, "models", "buildings", "red_hq.glb"), [hull])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root_dir, "models", "source", "red_hq.blend"))
S.preview(os.path.join(root_dir, "shots", "red_hq_preview.png"), target=(0, -0.5, 2.8), cam_loc=(-11, -15, 9.0), lens=42)
print("HQ_OK")
