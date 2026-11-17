"""Westbund-Kommandozentrale: gestaffelter Achteckturm mit echten Fensterlaibungen,
Pfeilern, Lichtband, Glasbrüstung, Vorhangfassade, Dachlandeplatz, Technik und Radar.

blender -b -P tools/blender/make_west_hq.py -- <projektordner>
Ergebnis: models/buildings/west_hq.glb, shots/west_hq_preview.png
"""
import bpy, math, os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import importlib
import sf_common as S
importlib.reload(S)

root_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
S.reset()

PW = S.material("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
PG = S.material("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
CO = S.material("Concrete", (0.56, 0.55, 0.53), 0.0, 0.88, 0.3, 0.7)
TP = S.material("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
GL = S.material("Glass", (0.05, 0.11, 0.17), 0.9, 0.05, 0.0, 0.15)
GW = S.material("GlassLit", (0.95, 0.85, 0.6), 0.0, 0.3, 0.0, 0.0, 1.6)
ST = S.material("Steel", (0.42, 0.44, 0.47), 0.9, 0.3, 0.4, 0.3)
AS = S.material("Asphalt", (0.11, 0.115, 0.12), 0.0, 0.85, 0.2, 0.3)
MK = S.material("Marking", (0.9, 0.9, 0.86), 0.0, 0.6, 0.3, 0.3)
YE = S.material("Yellow", (0.95, 0.72, 0.08), 0.2, 0.5, 0.4, 0.3)
LC = S.material("LightCyan", (0.4, 0.85, 1.0), 0.0, 0.3, 0.0, 0.0, 4.0)
LR = S.material("LightRed", (1.0, 0.12, 0.06), 0.0, 0.3, 0.0, 0.0, 6.0)
PL = S.material("Plant", (0.17, 0.34, 0.12), 0.0, 0.85, 0.0, 0.2)
BK = S.material("Bark", (0.3, 0.2, 0.12), 0.0, 0.9, 0.0, 0.3)
SO = S.material("Soil", (0.18, 0.12, 0.08), 0.0, 1.0, 0.0, 0.0)

def ang(k):
    return k * math.pi / 4  # Flächennormalen des Achtecks

def face_pos(apo, a, z, along=0.0, inward=0.0):
    """Punkt auf der Achteckfläche mit Normale a (vorne = -Y bei a = -90°)."""
    nx, ny = math.cos(a), math.sin(a)
    tx, ty = -ny, nx
    return ((apo - inward) * nx + along * tx, (apo - inward) * ny + along * ty, z)

parts = []

# ------------------------------------------------------------------ Sockel und Treppe
pod = S.ngon_prism("Podium", 8, 4.65, 2.1, (0, 0, -0.55), CO, 0.05)
parts.append(pod)
parts.append(S.ngon_prism("PodiumEdge", 8, 4.72, 0.12, (0, 0, 0.47), PG, 0.02))
for i in range(4):
    parts.append(S.box("Step%d" % i, (3.4, 0.34, 0.5 - i * 0.12), (0, -4.45 - i * 0.0 - (3 - i) * 0.0 - 0.17 - (0 if i == 0 else 0), 0.25 - i * 0.06), CO, 0.02))
for i in range(3):
    parts.append(S.box("Stair%d" % i, (3.0, 0.3, 0.13 * (3 - i)), (0, -4.35 - i * 0.3, 0.065 * (3 - i)), CO, 0.015))

# ------------------------------------------------------------------ Etage 1 mit Fensterlaibungen
R1 = 3.5
apo1 = R1 * math.cos(math.pi / 8)
t1 = S.ngon_prism("Tier1", 8, R1, 2.7, (0, 0, 1.85), PW, 0.03)
windows = []
for k in range(8):
    a = ang(k)
    front = abs(a - 3 * math.pi / 2) < 0.01 or k == 6
    for along in ([-0.75, 0.75] if not front else [-1.25, 1.25]):
        x, y, z = face_pos(apo1, a, 1.95, along)
        c = S.box("cut", (1.0, 0.7, 1.3), (x, y, z), None, 0.0, rot=(0, 0, a + math.pi / 2))
        S.cut(t1, c)
        windows.append((a, along))
parts.append(t1)
for a, along in windows:
    gx, gy, gz = face_pos(apo1, a, 1.95, along, inward=0.18)
    lit = (int(a * 10) + int(along * 3)) % 3 == 0
    parts.append(S.box("Pane", (0.95, 0.04, 1.25), (gx, gy, gz), GW if lit else GL, 0.0, rot=(0, 0, a + math.pi / 2)))
    for dz, h in ((0.66, 0.07), (-0.66, 0.07)):
        fx, fy, fz = face_pos(apo1, a, 1.95 + dz, along, inward=-0.02)
        parts.append(S.box("Frame", (1.12, 0.1, h), (fx, fy, fz), PG, 0.01, rot=(0, 0, a + math.pi / 2)))
    sx, sy, sz = face_pos(apo1, a, 1.24, along, inward=-0.1)
    parts.append(S.box("Sill", (1.2, 0.24, 0.07), (sx, sy, sz), CO, 0.01, rot=(0, 0, a + math.pi / 2)))
    mx, my, mz = face_pos(apo1, a, 1.95, along, inward=0.16)
    parts.append(S.box("Mullion", (0.05, 0.06, 1.25), (mx, my, mz), PG, 0.0, rot=(0, 0, a + math.pi / 2)))
# Eckpfeiler
for k in range(8):
    a = ang(k) + math.pi / 8
    r = R1 * 0.995
    parts.append(S.box("Pillar", (0.34, 0.34, 2.85), (math.cos(a) * r, math.sin(a) * r, 1.9), PG, 0.04, rot=(0, 0, a)))
parts.append(S.ngon_prism("Cornice1", 8, 3.78, 0.24, (0, 0, 3.3), TP, 0.03))
parts.append(S.ngon_prism("Strip1", 8, 3.8, 0.06, (0, 0, 3.12), LC, 0.0))
parts.append(S.ngon_prism("Base1", 8, 3.62, 0.18, (0, 0, 0.6), PG, 0.02))

# Glasbrüstung um die Dachterrasse
for k in range(8):
    a = ang(k)
    x, y, z = face_pos(3.42, a, 3.85, 0.0)
    parts.append(S.box("Rail", (2.65, 0.04, 0.75), (x, y, z), GL, 0.0, rot=(0, 0, a + math.pi / 2)))
    x2, y2, z2 = face_pos(3.42, a, 4.24, 0.0)
    parts.append(S.box("RailTop", (2.7, 0.08, 0.06), (x2, y2, z2), ST, 0.01, rot=(0, 0, a + math.pi / 2)))
for k in range(8):
    a = ang(k) + math.pi / 8
    r = 3.6
    parts.append(S.cyl("Post", 0.035, 0.85, (math.cos(a) * r, math.sin(a) * r, 3.85), ST, 8))

# ------------------------------------------------------------------ Etage 2: Vorhangfassade
R2 = 2.45
parts.append(S.ngon_prism("Tier2Core", 8, R2 - 0.08, 2.4, (0, 0, 4.62), PW, 0.02))
parts.append(S.ngon_prism("Curtain", 8, R2, 1.7, (0, 0, 4.7), GL, 0.0))
for k in range(16):
    a = k * math.pi / 8
    parts.append(S.box("Fin", (0.08, 0.22, 2.1), (math.cos(a) * (R2 + 0.03), math.sin(a) * (R2 + 0.03), 4.65), PW, 0.01, rot=(0, 0, a)))
parts.append(S.ngon_prism("Band2", 8, R2 + 0.06, 0.12, (0, 0, 4.7), PG, 0.01))
parts.append(S.ngon_prism("Roof2", 8, 2.75, 0.28, (0, 0, 5.95), TP, 0.04))
parts.append(S.ngon_prism("Strip2", 8, 2.78, 0.05, (0, 0, 5.78), LC, 0.0))

# ------------------------------------------------------------------ Dachlandeplatz
parts.append(S.cyl("Pad", 2.25, 0.12, (0, 0, 6.15), AS, 32, 0.01, smooth=False))
ring = S.cyl("PadRing", 2.0, 0.03, (0, 0, 6.22), YE, 48, smooth=False)
inner = S.cyl("cut", 1.86, 0.2, (0, 0, 6.22), None, 48, smooth=False)
S.cut(ring, inner)
parts.append(ring)
for (sx, sy, sz, lx, ly) in ((-0.42, 0, 6.225, 0.18, 1.3), (0.42, 0, 6.225, 0.18, 1.3), (0, 0, 6.225, 0.7, 0.18)):
    parts.append(S.box("H", (lx, ly, 0.02), (sx, sy, sz), MK, 0.0))
for k in range(12):
    a = k * math.tau / 12
    parts.append(S.sphere("PadLight", 0.06, (math.cos(a) * 2.15, math.sin(a) * 2.15, 6.24), LC, segs=8, rings=4))

# ------------------------------------------------------------------ Technik auf der Terrasse
for i, (x, y) in enumerate([(-2.4, 1.6), (-1.0, 2.6), (2.5, 1.2)]):
    parts.append(S.box("AC", (0.9, 0.6, 0.55), (x, y, 3.7), PW, 0.03, rot=(0, 0, math.atan2(y, x))))
    fan = S.cyl("ACFan", 0.2, 0.04, (x, y, 4.0), PG, 16)
    parts.append(fan)
    for j in range(5):
        parts.append(S.box("Louver", (0.8, 0.02, 0.05), (x, y, 3.5 + j * 0.08), PG, 0.0, rot=(0, 0, math.atan2(y, x))))
# Antennenmast mit Querstreben und Warnlicht
mx, my = -1.6, -2.6
parts.append(S.cyl("Mast", 0.05, 3.8, (mx, my, 5.3), ST, 8))
for j in range(4):
    parts.append(S.box("MastBar", (0.6 - j * 0.1, 0.03, 0.03), (mx, my, 4.2 + j * 0.8), ST, 0.0))
parts.append(S.sphere("MastLight", 0.09, (mx, my, 7.25), LR, segs=10, rings=6))
# Fallrohre
for a in (math.pi * 0.6, math.pi * 0.9):
    parts.append(S.cyl("Downpipe", 0.06, 2.6, (math.cos(a) * 3.62, math.sin(a) * 3.62, 1.85), PG, 10))

# ------------------------------------------------------------------ Eingang
ey = -apo1
parts.append(S.box("DoorFrame", (2.2, 0.2, 2.3), (0, ey - 0.02, 1.75), PG, 0.03))
door = S.box("cut", (1.9, 0.6, 2.1), (0, ey - 0.02, 1.65), None, 0.0)
S.cut(parts[-1], door)
parts.append(S.box("Door", (1.88, 0.05, 2.08), (0, ey + 0.05, 1.65), GW, 0.0))
parts.append(S.box("DoorSplit", (0.05, 0.07, 2.08), (0, ey + 0.02, 1.65), ST, 0.0))
parts.append(S.box("Canopy", (3.8, 2.0, 0.1), (0, ey - 1.0, 2.95), GL, 0.0))
parts.append(S.box("CanopyFrameF", (3.9, 0.12, 0.16), (0, ey - 2.0, 2.95), ST, 0.02))
for sx in (-1.85, 1.85):
    parts.append(S.box("CanopyFrameS", (0.12, 2.0, 0.16), (sx, ey - 1.0, 2.95), ST, 0.02))
    parts.append(S.cyl("CanopyCol", 0.07, 2.4, (sx, ey - 1.9, 1.7), ST, 10))
parts.append(S.cyl("Emblem", 0.45, 0.08, (0, ey - 0.15, 3.25), TP, 32, rot=(math.pi / 2, 0, 0)))
parts.append(S.box("EmblemChevron", (0.5, 0.04, 0.12), (0, ey - 0.2, 3.3), LC, 0.0, rot=(0, 0.6, 0)))
parts.append(S.box("EmblemChevron2", (0.5, 0.04, 0.12), (0, ey - 0.2, 3.3), LC, 0.0, rot=(0, -0.6, 0)))
# Pflanzkübel mit Bäumchen
for sx in (-2.9, 2.9):
    parts.append(S.cyl("Planter", 0.65, 0.55, (sx, -3.4, 0.78), CO, 16, 0.03))
    parts.append(S.cyl("PlanterSoil", 0.58, 0.05, (sx, -3.4, 1.05), SO, 16))
    parts.append(S.cyl("Trunk", 0.06, 1.1, (sx, -3.4, 1.6), BK, 8, r2=0.04))
    for j, (ox, oy, oz, r) in enumerate([(0, 0, 2.35, 0.55), (0.25, 0.1, 2.15, 0.4), (-0.2, -0.15, 2.2, 0.42), (0.05, 0.2, 2.6, 0.35)]):
        parts.append(S.sphere("Crown", r, (sx + ox, -3.4 + oy, oz), PL, segs=10, rings=6))

# ------------------------------------------------------------------ Radar (dreht sich im Spiel)
spin = S.empty("Spin", (2.3, 2.3, 3.6))
radar_parts = []
radar_parts.append(S.cyl("RadarBase", 0.25, 0.4, (2.3, 2.3, 3.8), PG, 16))
dish = S.sphere("Dish", 0.85, (2.3, 2.3, 4.6), PW, scale=(1, 1, 0.35), segs=24, rings=12)
cutter = S.box("cut", (2.0, 2.0, 1.0), (2.3, 2.3, 5.1), None, 0.0)
S.cut(dish, cutter)
dish.rotation_euler = (math.radians(-55), 0, 0)
radar_parts.append(dish)
radar_parts.append(S.cyl("Horn", 0.03, 0.8, (2.3, 2.0, 4.85), ST, 6, rot=(math.radians(-55), 0, 0)))

# ------------------------------------------------------------------ Zusammenführen, backen, exportieren
hull = parts[0]
S.join_into(hull, parts[1:])
hull.name = "Hull"
radar = radar_parts[0]
S.join_into(radar, radar_parts[1:])
radar.name = "Radar"
S.parent(radar, spin)
tex = os.path.join(root_dir, "models", "source", "textures")
S.bake(hull, 2048, tex)
S.bake(radar, 512, tex)
os.makedirs(os.path.join(root_dir, "models", "buildings"), exist_ok=True)
S.export(os.path.join(root_dir, "models", "buildings", "west_hq.glb"), [hull, radar, spin])
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root_dir, "models", "source", "west_hq.blend"))
S.preview(os.path.join(root_dir, "shots", "west_hq_preview.png"), target=(0, 0, 2.6), cam_loc=(-11, -14, 9.5), lens=42)
print("HQ_OK")
