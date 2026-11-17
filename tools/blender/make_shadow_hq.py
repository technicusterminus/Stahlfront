"""Schattenfront – Versteck: Felsmassiv mit Tunnel, Holzrahmen, Wachturm mit Leiter,
Tarnnetze auf Masten, Sandsäcke, Fässer, Kisten, Lampen und Zelt.

blender -b -P tools/blender/make_shadow_hq.py -- <projektordner>
Ergebnis: models/buildings/shadow_hq.glb, shots/shadow_hq_preview.png   (vorne = -Y)
"""
import bpy, math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S

root_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
S.reset()
random.seed(7)

RK = S.material("Rock", (0.42, 0.37, 0.3), 0.0, 0.95, 0.2, 0.9)
RD = S.material("RockDark", (0.25, 0.22, 0.18), 0.0, 0.95, 0.2, 0.9)
WD = S.material("Wood", (0.36, 0.25, 0.14), 0.0, 0.9, 0.3, 0.8)
WL = S.material("WoodLight", (0.55, 0.42, 0.25), 0.0, 0.9, 0.3, 0.8)
TP = S.material("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
NT = S.material("Netting", (0.3, 0.33, 0.2), 0.0, 0.95, 0.2, 0.7)
SB = S.material("Sandbag", (0.55, 0.47, 0.32), 0.0, 1.0, 0.1, 0.9)
ST = S.material("Steel", (0.4, 0.38, 0.35), 0.7, 0.5, 0.7, 0.8)
RS = S.material("Rust", (0.4, 0.2, 0.09), 0.5, 0.75, 0.8, 0.8)
CV = S.material("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
DK = S.material("Dark", (0.02, 0.02, 0.02), 0.0, 1.0, 0.0, 0.0)
LO = S.material("Lantern", (1.0, 0.65, 0.25), 0.0, 0.4, 0.0, 0.0, 6.0)
FR = S.material("Fire", (1.0, 0.45, 0.1), 0.0, 0.4, 0.0, 0.0, 6.0)
BL = S.material("Blue", (0.12, 0.2, 0.35), 0.5, 0.6, 0.5, 0.5)

P = []

def rock(name, loc, scale, mat=RK, seed=0):
    ob = S.sphere(name, 1.0, loc, mat, scale=scale, segs=28, rings=16)
    for p in ob.data.polygons:
        p.use_smooth = True
    tex = bpy.data.textures.new("tx" + name, "CLOUDS")
    tex.noise_scale = 1.1 + 0.3 * (seed % 3)
    m = ob.modifiers.new("D", "DISPLACE")
    m.texture = tex
    m.strength = 0.5
    m.mid_level = 0.45
    sub = ob.modifiers.new("S", "SUBSURF")
    sub.levels = 1
    return ob

# ------------------------------------------------------------------ Felsmassiv mit Tunnel
big = rock("RockBig", (-0.3, 1.2, 0.2), (3.6, 3.0, 2.7), RK, 1)
P.append(big)
P.append(rock("RockR", (3.0, 0.4, 0.0), (1.8, 1.9, 1.7), RK, 2))
P.append(rock("RockL", (-3.8, 0.6, -0.1), (1.6, 1.8, 1.4), RK, 3))
P.append(rock("RockBack", (0.5, 3.0, 0.3), (2.6, 1.8, 2.2), RD, 4))
for i in range(7):
    a = random.uniform(0, math.tau)
    r = random.uniform(3.4, 4.5)
    P.append(rock("Stone%d" % i, (math.cos(a) * r, math.sin(a) * r * 0.9 + 0.3, -0.1), (random.uniform(0.35, 0.8),) * 3, RK if i % 2 else RD, i))
# Tunneleingang: Aussparung im Fels
tun = S.box("cut", (2.2, 3.5, 2.1), (0, -1.6, 1.0), None, 0.0)
S.cut(big, tun)
P.append(S.box("Tunnel", (2.3, 2.6, 0.06), (0, -0.4, 0.0), DK, 0.0))
P.append(S.box("TunnelBack", (2.0, 0.06, 2.0), (0, 0.8, 1.0), DK, 0.0))
# Holzrahmen und Stützbalken
P.append(S.box("PostL", (0.28, 0.28, 2.4), (-1.3, -2.15, 1.2), WD, 0.03, rot=(0, 0, 0.03)))
P.append(S.box("PostR", (0.28, 0.28, 2.4), (1.3, -2.15, 1.2), WD, 0.03, rot=(0, 0, -0.03)))
P.append(S.box("Lintel", (3.2, 0.34, 0.3), (0, -2.15, 2.45), WD, 0.03))
P.append(S.box("LintelCap", (3.5, 0.5, 0.1), (0, -2.15, 2.65), WL, 0.02))
for sx in (-1, 1):
    P.append(S.box("Brace", (0.14, 0.14, 0.9), (sx * 1.0, -2.15, 2.0), WD, 0.02, rot=(0, sx * 0.8, 0)))
for k in range(4):
    P.append(S.box("Plank", (0.22, 0.1, 1.9), (-0.3 + k * 0.2, -2.12, 0.95), WL, 0.01))
# Laternen
for sx in (-1.5, 1.5):
    P.append(S.cyl("LampPost", 0.04, 1.2, (sx, -2.5, 0.6), WD, 6))
    P.append(S.box("Lamp", (0.2, 0.2, 0.28), (sx, -2.5, 1.35), LO, 0.03))
    P.append(S.box("LampCap", (0.26, 0.26, 0.05), (sx, -2.5, 1.52), ST, 0.01))

# ------------------------------------------------------------------ Wachturm mit Leiter und Dach
wx, wy = 4.1, -1.7
for sx in (-0.55, 0.55):
    for sy in (-0.55, 0.55):
        P.append(S.box("TowerLeg", (0.16, 0.16, 4.2), (wx + sx, wy + sy, 2.1), WD, 0.02, rot=(sy * 0.06, -sx * 0.06, 0)))
for z in (1.2, 2.5):
    for (sx, sy, lx, ly) in ((0, -0.55, 1.2, 0.1), (0, 0.55, 1.2, 0.1), (-0.55, 0, 0.1, 1.2), (0.55, 0.0, 0.1, 1.2)):
        P.append(S.box("TowerBeam", (lx, ly, 0.12), (wx + sx, wy + sy, z), WD, 0.01))
    P.append(S.box("Cross", (1.5, 0.08, 0.08), (wx, wy - 0.58, z + 0.6), WD, 0.0, rot=(0, 0.7, 0)))
P.append(S.box("Floor", (1.6, 1.6, 0.14), (wx, wy, 3.8), WL, 0.02))
for (sx, sy, lx, ly) in ((0, -0.78, 1.6, 0.08), (0, 0.78, 1.6, 0.08), (-0.78, 0, 0.08, 1.6)):
    P.append(S.box("Rail", (lx, ly, 0.6), (wx + sx, wy + sy, 4.15), WL, 0.01))
P.append(S.prism_xz("Roof", [(-1.2, 0), (1.2, 0), (0, 0.75)], 1.9, (wx, wy, 4.75), TP, 0.02))
for sx in (-0.7, 0.7):
    for sy in (-0.7, 0.7):
        P.append(S.box("RoofPost", (0.08, 0.08, 0.95), (wx + sx, wy + sy, 4.3), WD, 0.0))
for k in range(9):
    P.append(S.box("Rung", (0.5, 0.05, 0.05), (wx, wy - 0.78, 0.35 + k * 0.42), WD, 0.0))
P.append(S.box("RailL", (0.06, 0.05, 3.9), (wx - 0.26, wy - 0.78, 2.0), WD, 0.0))
P.append(S.box("RailR", (0.06, 0.05, 3.9), (wx + 0.26, wy - 0.78, 2.0), WD, 0.0))
P.append(S.box("Searchlight", (0.35, 0.5, 0.35), (wx + 0.6, wy + 0.2, 4.05), ST, 0.03))
P.append(S.box("SLLens", (0.28, 0.05, 0.28), (wx + 0.6, wy - 0.08, 4.05), LO, 0.0))

# ------------------------------------------------------------------ Tarnnetze auf Masten
for (px, py, h) in ((-3.2, -2.6, 3.6), (-0.2, -3.6, 3.2), (2.5, -3.2, 3.4)):
    P.append(S.cyl("NetPole", 0.06, h, (px, py, h / 2), WD, 8))
nets = [((-3.2, -2.6, 3.6), (-0.2, -3.6, 3.2), (-1.7, -0.5)), ((-0.2, -3.6, 3.2), (2.5, -3.2, 3.4), (1.2, 0.3))]
for a, b, _ in nets:
    mx, my, mz = (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2
    ln = math.hypot(b[0] - a[0], b[1] - a[1])
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    net = S.box("Net", (ln, 2.6, 0.05), (mx, my + 0.4, mz - 0.1), NT, 0.0, rot=(0, 0, ang))
    P.append(net)
    P.append(S.box("NetTeam", (ln * 0.4, 1.1, 0.06), (mx, my + 0.35, mz - 0.07), TP, 0.0, rot=(0, 0, ang)))
    P.append(S.box("NetEdge", (ln, 0.06, 0.07), (mx, my - 0.9, mz - 0.1), WD, 0.0, rot=(0, 0, ang)))

# ------------------------------------------------------------------ Vorplatz: Sandsäcke, Fässer, Kisten, Zelt, Feuerstelle
def sandbag_wall(cx, cy, count, rows, ang):
    for r in range(rows):
        for i in range(count):
            off = (i - count / 2 + (0.5 if r % 2 else 0)) * 0.62
            x = cx + math.cos(ang) * off
            y = cy + math.sin(ang) * off
            bag = S.box("Bag", (0.62, 0.34, 0.2), (x, y, 0.1 + r * 0.19), SB, 0.07, rot=(0, 0, ang + random.uniform(-0.08, 0.08)))
            P.append(bag)
sandbag_wall(-3.4, -3.5, 5, 3, 0.1)
sandbag_wall(3.3, -3.7, 4, 2, -0.15)
for i, (bx, by) in enumerate([(-4.7, -1.2), (-5.2, -0.5), (-4.6, -0.2)]):
    P.append(S.cyl("Barrel", 0.28, 0.9, (bx, by, 0.45), RS if i != 1 else BL, 14, 0.0))
    P.append(S.cyl("BarrelRim", 0.29, 0.05, (bx, by, 0.9), ST, 14))
for i, (bx, by, bs) in enumerate([(-1.9, -4.0, 0.7), (-1.1, -4.1, 0.55), (-1.5, -4.0, 0.5)]):
    P.append(S.box("Crate", (bs, bs, bs), (bx, by, bs / 2 + (0.7 if i == 2 else 0) * 0.0 + (bs if i == 2 else 0) * 0), WL, 0.03, rot=(0, 0, random.uniform(-0.2, 0.2))))
# Zelt
P.append(S.prism_xz("Tent", [(-1.1, 0), (1.1, 0), (0, 1.5)], 2.4, (4.9, 1.4, 0.0), CV, 0.0, rot=(0, 0, 0.4)))
P.append(S.box("TentDoor", (0.7, 0.05, 1.1), (4.9 + 0.2, 0.2, 0.55), DK, 0.0, rot=(0, 0, 0.4)))
# Feuerstelle
for i in range(8):
    a = i * math.tau / 8
    P.append(S.box("FireStone", (0.22, 0.16, 0.16), (-2.3 + math.cos(a) * 0.42, -3.1 + math.sin(a) * 0.42, 0.08), RD, 0.04, rot=(0, 0, a)))
# Flammen kommen als Partikel im Spiel (scripts/fx.gd)
for i in range(3):
    P.append(S.cyl("Log", 0.06, 0.6, (-2.3, -3.1, 0.1), WD, 8, rot=(math.pi / 2, 0, i * 1.05)))

# ------------------------------------------------------------------ Zusammenführen, backen, exportieren
hull = P[0]
S.join_into(hull, P[1:])
hull.name = "Hull"
tex = os.path.join(root_dir, "models", "source", "textures")
S.bake(hull, 2048, tex)
os.makedirs(os.path.join(root_dir, "models", "buildings"), exist_ok=True)
S.export(os.path.join(root_dir, "models", "buildings", "shadow_hq.glb"), [hull])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root_dir, "models", "source", "shadow_hq.blend"))
S.preview(os.path.join(root_dir, "shots", "shadow_hq_preview.png"), target=(0.2, -0.5, 1.4), cam_loc=(-10, -14, 8.5), lens=42, ground=(0.45, 0.38, 0.27))
print("HQ_OK")
