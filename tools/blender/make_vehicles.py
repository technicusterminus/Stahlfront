"""Fahrzeuge und Luftfahrzeuge (Blender): Lkw, Flak, Artillerie, Raketenwerfer, Scud-Träger, Koloss, Hubschrauber, Jäger.

blender -b -P tools/blender/make_vehicles.py -- <projektordner> <modell>
  Modelle: truck aa artillery rocketlauncher scud heavy_tank west_heli red_heli west_jet red_jet
Ergebnis: models/units/<modell>.glb (vorne = -Y, Boden = z 0; Flugzeuge um den Ursprung).
Bewegliche Teile als eigene Objekte: Turret, Barrel, Muzzle, Rotor, TailRotor.
"""
import math, os, sys, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy
import sf_common as S
import sf_bld as B

which, P = B.setup(21)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH
TP = B.M("TeamPaint", (0.6, 0.62, 0.58), 0.35, 0.55, 0.5, 0.5)
OL = B.M("Olive", (0.25, 0.29, 0.2), 0.3, 0.7, 0.5, 0.7)
CV = B.M("Canvas", (0.4, 0.38, 0.28), 0.0, 0.95, 0.2, 0.6)
GLO = B.M("GlowOrange", (1.0, 0.55, 0.15), 0.0, 0.3, 0.0, 0.0, 7.0)
GLB = B.M("GlowBlue", (0.5, 0.8, 1.0), 0.0, 0.3, 0.0, 0.0, 7.0)
LAN = B.M("GlowGreen", (0.4, 1.0, 0.2), 0.0, 0.3, 0.0, 0.0, 3.0)
T = []    # Turm
BR = []   # Rohr
RO = []   # Rotor
TR = []   # Heckrotor
extras = []

def wheel(x, y, r=0.5, w=0.38, z=None):
    z = r if z is None else z
    P.append(S.cyl("Tire", r, w, (x, y, z), RB, 18, rot=(0, math.pi / 2, 0)))
    P.append(S.cyl("Rim", r * 0.55, w + 0.04, (x, y, z), ST, 12, rot=(0, math.pi / 2, 0)))
    P.append(S.cyl("Hub", r * 0.2, w + 0.08, (x, y, z), DK, 8, rot=(0, math.pi / 2, 0)))

def axles(ys, half_w=1.0, r=0.5):
    for y in ys:
        for sx in (-1, 1):
            wheel(sx * half_w, y, r)
        P.append(S.cyl("Axle", 0.08, half_w * 2, (0, y, r), DK, 8, rot=(0, math.pi / 2, 0)))
    for y in ys:
        for sx in (-1, 1):
            P.append(S.box("Fender", (0.5, r * 2.4, 0.08), (sx * half_w, y, r * 2.05), TP, 0.02))

def tracks(x, length, w=0.8, h=0.85):
    P.append(S.box("Track", (w, length, h), (x, 0, h / 2 + 0.05), DK, 0.08))
    n = int(length / 0.75)
    for i in range(n):
        y = -length / 2 + 0.45 + i * (length - 0.9) / max(n - 1, 1)
        side = 1 if x > 0 else -1
        P.append(S.cyl("RoadWheel", 0.3, 0.12, (x + side * (w / 2 + 0.02), y, 0.36), ST, 12, rot=(0, math.pi / 2, 0)))
    P.append(S.box("Skirt", (w + 0.12, length * 0.92, 0.14), (x, 0, h + 0.1), TP, 0.03))
    for ey in (-length / 2, length / 2):
        side = 1 if x > 0 else -1
        P.append(S.cyl("Sprocket", 0.42, 0.14, (x + side * (w / 2 + 0.03), ey * 0.94, 0.45), DK, 12, rot=(0, math.pi / 2, 0)))

def barrel_cyl(parts, p0, elev, length, r, mat, dx=0.0):
    """Zylinder entlang der Richtung (0, -cos e, sin e) ab p0 (Blender: vorne = -Y)."""
    d = (0.0, -math.cos(elev), math.sin(elev))
    c = (p0[0] + dx, p0[1] + d[1] * length / 2, p0[2] + d[2] * length / 2)
    parts.append(S.cyl("Tube", r, length, c, mat, 10, rot=(math.pi / 2 - elev, 0, 0)))
    return (p0[0] + dx, p0[1] + d[1] * length, p0[2] + d[2] * length)

def headlights(y, z, hw):
    for sx in (-1, 1):
        P.append(S.sphere("Lamp", 0.11, (sx * hw, y, z), LW, segs=10, rings=6))

def finish_unit(name, cam=(-9, -11, 6), tgt=(0, 0, 1.3)):
    hull = P[0]
    S.join_into(hull, P[1:])
    hull.name = "Hull"
    root = B.root_dir
    tex = os.path.join(root, "models", "source", "textures")
    S.bake(hull, 1024, tex)
    objs = [hull] + list(extras)
    os.makedirs(os.path.join(root, "models", "units"), exist_ok=True)
    S.export(os.path.join(root, "models", "units", "%s.glb" % name), objs)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "models", "source", "%s.blend" % name))
    S.preview(os.path.join(root, "shots", "%s_preview.png" % name), target=tgt, cam_loc=cam, lens=48, ground=(0.3, 0.32, 0.25))
    print("VEHICLE_OK", name)

# ---------------------------------------------------------------- Bodenfahrzeuge

if which == "truck":
    P.append(S.box("Chassis", (1.9, 4.4, 0.4), (0, 0, 0.75), DK, 0.04))
    axles([-1.5, 0.35, 1.5], 1.0, 0.5)
    P.append(S.box("Cab", (2.0, 1.3, 1.3), (0, -1.5, 1.55), TP, 0.08))
    P.append(S.box("CabRoof", (2.05, 1.35, 0.08), (0, -1.5, 2.22), TP, 0.03))
    P.append(S.box("Windshield", (1.8, 0.05, 0.55), (0, -2.17, 1.85), GLS, 0.0))
    for sx in (-1, 1):
        P.append(S.box("SideWindow", (0.05, 0.6, 0.5), (sx * 1.01, -1.6, 1.85), GLS, 0.0))
        P.append(S.box("Door", (0.04, 0.9, 1.0), (sx * 1.02, -1.5, 1.45), CD, 0.0))
        P.append(S.box("Mirror", (0.08, 0.14, 0.3), (sx * 1.2, -2.0, 1.9), DK, 0.02))
        P.append(S.box("Step", (0.3, 0.4, 0.06), (sx * 1.1, -1.5, 0.95), ST, 0.01))
        P.append(S.cyl("FuelTank", 0.28, 1.1, (sx * 1.0, 0.1, 0.75), ST, 12, rot=(math.pi / 2, 0, 0)))
    P.append(S.box("Grille", (1.5, 0.06, 0.5), (0, -2.19, 1.2), DK, 0.0))
    P.append(S.box("Bumper", (2.0, 0.2, 0.25), (0, -2.25, 0.85), ST, 0.03))
    headlights(-2.2, 1.0, 0.7)
    P.append(S.cyl("Exhaust", 0.07, 1.6, (0.95, -0.85, 2.0), ST, 8))
    P.append(S.box("LightBar", (1.2, 0.18, 0.1), (0, -1.5, 2.3), DK, 0.02))
    for sx in (-0.4, 0, 0.4):
        P.append(S.sphere("BarLight", 0.06, (sx, -1.5, 2.36), GLO, segs=8, rings=4))
    # Ladefläche mit Brettern, Pfosten, Kisten und Netz
    P.append(S.box("Bed", (2.0, 2.7, 0.14), (0, 0.85, 1.0), DK, 0.02))
    for sx in (-1, 1):
        P.append(S.box("SideBoard", (0.06, 2.7, 0.6), (sx * 0.98, 0.85, 1.35), OL, 0.02))
    P.append(S.box("TailBoard", (2.0, 0.06, 0.6), (0, 2.2, 1.35), OL, 0.02))
    P.append(S.box("HeadBoard", (2.0, 0.06, 0.9), (0, -0.5, 1.5), OL, 0.02))
    for i in range(6):
        P.append(S.box("Crate", (0.7, 0.6, 0.6), (-0.45 + (i % 2) * 0.9, 0.2 + (i // 2) * 0.8, 1.45 + (i // 4) * 0.1), WL if i % 3 else RS, 0.04, rot=(0, 0, random.uniform(-0.15, 0.15))))
    P.append(S.box("Net", (1.9, 2.2, 0.03), (0, 0.9, 2.05), CV, 0.0))
    P.append(S.cyl("Antenna", 0.012, 2.0, (-0.9, -0.7, 3.1), DK, 6))
    P.append(S.box("Pennant", (0.02, 0.5, 0.25), (-0.9, -0.95, 4.0), TP, 0.0))
    finish_unit("truck")

elif which == "aa":
    tracks(-1.1, 4.0)
    tracks(1.1, 4.0)
    P.append(S.box("Hull", (2.0, 3.7, 0.8), (0, 0, 1.0), TP, 0.08))
    P.append(S.box("Glacis", (1.8, 0.8, 0.5), (0, -1.9, 1.1), TP, 0.05, rot=(0.4, 0, 0)))
    P.append(S.box("Engine", (1.6, 0.8, 0.3), (0, 1.5, 1.5), DK, 0.04))
    for k in range(5):
        P.append(S.box("Louver", (1.4, 0.04, 0.04), (0, 1.2 + k * 0.17, 1.66), ST, 0.0))
    P.append(S.box("Radar", (0.9, 0.1, 0.5), (-0.7, 0.9, 1.95), DK, 0.02))
    headlights(-2.25, 1.15, 0.7)
    for sx in (-1, 1):
        P.append(S.cyl("Smoke", 0.08, 0.35, (sx * 1.05, -1.5, 1.55), DK, 8, rot=(0, math.pi / 2, 0)))
    P.append(S.cyl("Antenna", 0.012, 2.0, (0.85, 1.7, 2.5), DK, 6))
    T.append(S.cyl("TBase", 0.75, 0.4, (0, 0.3, 1.65), TP, 20, 0.02))
    T.append(S.box("TBody", (1.3, 1.1, 0.7), (0, 0.3, 2.1), TP, 0.08))
    T.append(S.box("TArmor", (1.5, 0.12, 0.7), (0, -0.35, 2.15), CD, 0.04, rot=(0.3, 0, 0)))
    T.append(S.box("Sight", (0.45, 0.5, 0.3), (0, 0.5, 2.6), DK, 0.04))
    T.append(S.sphere("SightEye", 0.07, (0, 0.2, 2.6), LR, segs=8, rings=5))
    for sx in (-0.5, 0.5):
        T.append(S.box("Magazine", (0.35, 0.8, 0.4), (sx, 0.9, 2.0), OL, 0.04))
    e = 0.35
    tip = None
    for sx in (-0.45, 0.45):
        for sz in (0.0, 0.3):
            tip = barrel_cyl(BR, (sx, -0.2, 2.15 + sz), e, 1.8, 0.055, ST)
            BR.append(S.cyl("Flash", 0.085, 0.22, (tip[0], tip[1] + 0.05, tip[2] - 0.02), DK, 8, rot=(math.pi / 2 - e, 0, 0)))
    turret = B.part("Turret", T, (0, 0.3, 1.7))
    barrel = B.part("Barrel", BR, (0, 0.0, 2.2), parent=turret)
    mz = S.empty("Muzzle", (0, tip[1] - 0.2, tip[2]), turret)
    extras.extend([turret, barrel, mz])
    finish_unit("aa")

elif which == "artillery":
    tracks(-1.15, 4.4, 0.7, 0.8)
    tracks(1.15, 4.4, 0.7, 0.8)
    P.append(S.box("Hull", (2.0, 4.2, 0.8), (0, 0, 1.0), TP, 0.08))
    P.append(S.box("Glacis", (1.8, 0.9, 0.5), (0, -2.0, 1.1), TP, 0.05, rot=(0.4, 0, 0)))
    for sx in (-1, 1):
        P.append(S.box("Stowage", (0.3, 1.4, 0.35), (sx * 0.95, 1.4, 1.55), OL, 0.04))
    P.append(S.box("Spade", (2.0, 0.15, 0.9), (0, 2.25, 0.7), DK, 0.03, rot=(-0.4, 0, 0)))
    for sx in (-0.7, 0.7):
        P.append(S.box("SpadeArm", (0.14, 0.9, 0.14), (sx, 2.0, 1.0), ST, 0.02))
    headlights(-2.3, 1.15, 0.7)
    P.append(S.cyl("Antenna", 0.012, 2.4, (0.85, 1.6, 2.6), DK, 6))
    T.append(S.box("TBody", (1.9, 2.4, 1.0), (0, 0.5, 1.9), TP, 0.1))
    T.append(S.box("TTop", (1.6, 1.8, 0.1), (0, 0.6, 2.45), CD, 0.03))
    T.append(S.box("Cupola", (0.5, 0.5, 0.25), (-0.5, 1.0, 2.55), DK, 0.04))
    T.append(S.cyl("Hatch", 0.28, 0.08, (0.55, 1.0, 2.55), ST, 12))
    T.append(S.box("Mantlet", (0.9, 0.5, 0.7), (0, -0.7, 2.0), CD, 0.06))
    for sx in (-1, 1):
        T.append(S.box("Rack", (0.14, 0.9, 0.5), (sx * 1.0, 0.6, 1.9), OL, 0.04))
    e = 0.4
    tip = barrel_cyl(BR, (0, -0.9, 2.0), e, 4.4, 0.14, ST)
    BR.append(S.cyl("Evac", 0.22, 0.8, (0, -0.9 - math.cos(e) * 1.9, 2.0 + math.sin(e) * 1.9), DK, 12, rot=(math.pi / 2 - e, 0, 0)))
    BR.append(S.cyl("Brake", 0.24, 0.5, (tip[0], tip[1] + math.cos(e) * 0.2, tip[2] - math.sin(e) * 0.2), DK, 12, rot=(math.pi / 2 - e, 0, 0)))
    turret = B.part("Turret", T, (0, 0.5, 1.5))
    barrel = B.part("Barrel", BR, (0, -0.9, 2.0), parent=turret)
    mz = S.empty("Muzzle", (tip[0], tip[1] - 0.2, tip[2]), turret)
    extras.extend([turret, barrel, mz])
    finish_unit("artillery", cam=(-10, -12, 7))

elif which == "rocketlauncher":
    P.append(S.box("Chassis", (2.0, 4.6, 0.5), (0, 0, 0.85), DK, 0.04))
    axles([-1.4, 0.4, 1.5], 1.0, 0.52)
    P.append(S.box("Cab", (2.0, 1.2, 1.2), (0, -1.7, 1.6), TP, 0.08))
    P.append(S.box("Windshield", (1.8, 0.05, 0.5), (0, -2.31, 1.85), GLS, 0.0))
    for sx in (-1, 1):
        P.append(S.box("Mirror", (0.08, 0.14, 0.3), (sx * 1.2, -2.1, 1.9), DK, 0.02))
        P.append(S.box("OutriggerArm", (0.9, 0.2, 0.2), (sx * 1.4, 1.6, 0.9), ST, 0.02))
        P.append(S.cyl("OutriggerFoot", 0.2, 0.08, (sx * 1.85, 1.6, 0.55), DK, 10))
    headlights(-2.32, 1.1, 0.7)
    P.append(S.box("Bumper", (2.0, 0.2, 0.25), (0, -2.35, 0.9), ST, 0.03))
    P.append(S.cyl("Antenna", 0.012, 2.2, (-0.9, -1.2, 3.0), DK, 6))
    P.append(S.box("Pennant", (0.02, 0.5, 0.25), (-0.9, -1.45, 3.8), TP, 0.0))
    # Drehbare Lafette mit Werferkasten
    T.append(S.cyl("TBase", 0.8, 0.3, (0, 0.9, 1.25), TP, 18, 0.02))
    e = 0.45
    c = (0, 0.9 + (-math.cos(e)) * 1.0, 1.4 + math.sin(e) * 1.0)
    T.append(S.box("Pod", (1.7, 2.4, 0.9), c, TP, 0.08, rot=(-e, 0, 0)))
    for sx in (-0.65, 0.65):
        T.append(S.box("PodRail", (0.12, 2.5, 0.12), (sx, c[1], c[2] - 0.5), DK, 0.02, rot=(-e, 0, 0)))
    nose = (0.0, c[1] - math.cos(e) * 1.2, c[2] + math.sin(e) * 1.2)
    for ix in range(4):
        for iy in range(2):
            lx = -0.6 + ix * 0.4
            lz = -0.2 + iy * 0.4
            px = nose[0] + lx
            py = nose[1] + math.sin(e) * lz - 0.05
            pz = nose[2] + math.cos(e) * lz
            T.append(S.cyl("Tube", 0.14, 0.14, (px, py, pz), DK, 10, rot=(math.pi / 2 - e, 0, 0)))
            T.append(S.sphere("Rocket", 0.09, (px, py - math.cos(e) * 0.06, pz + math.sin(e) * 0.06), YE, segs=8, rings=5))
    T.append(S.box("PodStrap", (1.74, 0.12, 0.94), (c[0], c[1] + 0.3, c[2]), CD, 0.0, rot=(-e, 0, 0)))
    turret = B.part("Turret", T, (0, 0.9, 1.3))
    mz = S.empty("Muzzle", (nose[0], nose[1] - 0.5, nose[2] + 0.2), turret)
    extras.extend([turret, mz])
    finish_unit("rocketlauncher", cam=(-10, -12, 7))

elif which == "scud":
    P.append(S.box("Chassis", (2.1, 6.0, 0.5), (0, 0, 0.9), DK, 0.04))
    axles([-2.4, -0.9, 0.9, 2.2], 1.05, 0.55)
    P.append(S.box("Cab", (2.1, 1.4, 1.3), (0, -2.4, 1.75), TP, 0.08))
    P.append(S.box("Windshield", (1.9, 0.05, 0.5), (0, -3.11, 2.0), GLS, 0.0))
    for sx in (-1, 1):
        P.append(S.box("Mirror", (0.08, 0.14, 0.3), (sx * 1.25, -2.9, 2.0), DK, 0.02))
        P.append(S.box("OutriggerArm", (1.0, 0.2, 0.2), (sx * 1.5, 1.8, 1.0), ST, 0.02))
        P.append(S.cyl("OutriggerFoot", 0.22, 0.08, (sx * 2.0, 1.8, 0.6), DK, 10))
    headlights(-3.1, 1.2, 0.75)
    P.append(S.box("Bumper", (2.1, 0.2, 0.25), (0, -3.15, 0.95), ST, 0.03))
    P.append(S.cyl("Exhaust", 0.07, 1.6, (1.0, -1.7, 2.3), ST, 8))
    P.append(S.cyl("Antenna", 0.012, 2.2, (-0.95, -1.8, 3.2), DK, 6))
    P.append(S.box("Pennant", (0.02, 0.5, 0.25), (-0.95, -2.05, 4.0), TP, 0.0))
    # Drehbarer Raketenträger: Schiene, Rakete mit Giftspitze
    e = 0.25
    T.append(S.cyl("TBase", 0.9, 0.3, (0, 0.4, 1.3), TP, 18, 0.02))
    base = (0.0, 1.0, 1.7)
    for sx in (-0.5, 0.5):
        barrel_cyl(T, (sx, base[1], base[2] - 0.15), e, 4.4, 0.06, ST)
    T.append(S.box("Rail", (0.7, 4.4, 0.2), (0, base[1] - math.cos(e) * 2.2, base[2] + math.sin(e) * 2.2 - 0.15), ST, 0.03, rot=(-e, 0, 0)))
    tip = barrel_cyl(T, (0, base[1], base[2] + 0.3), e, 3.8, 0.38, B.M("MissileBody", (0.72, 0.74, 0.68), 0.5, 0.4, 0.5, 0.5))
    T.append(S.cyl("Nose", 0.38, 0.9, (tip[0], tip[1] - math.cos(e) * 0.45, tip[2] + math.sin(e) * 0.45), LAN, 14, r2=0.04, rot=(math.pi / 2 - e, 0, 0)))
    for k in range(3):
        T.append(S.cyl("Band", 0.4, 0.14, (0, base[1] - math.cos(e) * (0.8 + k * 1.2), base[2] + 0.3 + math.sin(e) * (0.8 + k * 1.2)), RS if k % 2 else YE, 14, rot=(math.pi / 2 - e, 0, 0)))
    T.append(S.box("Cradle", (0.7, 0.25, 0.7), (0, base[1] + 0.4, base[2] - 0.1), DK, 0.04))
    turret = B.part("Turret", T, (0, 0.4, 1.3))
    mz = S.empty("Muzzle", (0, tip[1] - 0.9, tip[2] + 0.2), turret)
    extras.extend([turret, mz])
    finish_unit("scud", cam=(-11, -13, 7))

elif which == "heavy_tank":
    tracks(-1.5, 4.8, 0.9, 1.0)
    tracks(1.5, 4.8, 0.9, 1.0)
    P.append(S.box("Hull", (2.6, 4.4, 0.85), (0, 0.1, 1.15), TP, 0.1))
    P.append(S.box("Glacis", (2.6, 1.0, 0.5), (0, -2.3, 1.05), TP, 0.06, rot=(0.45, 0, 0)))
    P.append(S.box("Engine", (2.0, 1.0, 0.35), (0, 1.8, 1.7), DK, 0.05))
    for k in range(6):
        P.append(S.box("Louver", (1.8, 0.04, 0.04), (0, 1.4 + k * 0.17, 1.9), ST, 0.0))
    for sx in (-1, 1):
        P.append(S.cyl("Drum", 0.3, 1.4, (sx * 1.0, 1.9, 1.85), OL, 12, rot=(math.pi / 2, 0, 0)))
        P.append(S.box("ERA", (0.1, 3.0, 0.5), (sx * 1.32, 0, 1.3), CD, 0.02))
    headlights(-2.5, 1.2, 0.9)
    P.append(S.box("Tow", (0.5, 0.2, 0.3), (0, -2.45, 0.8), ST, 0.03))
    T.append(S.box("TBody", (2.1, 2.4, 0.75), (0, 0.3, 1.98), TP, 0.12))
    T.append(S.box("TGlacis", (1.8, 0.7, 0.4), (0, -1.1, 1.95), TP, 0.06, rot=(0.5, 0, 0)))
    T.append(S.box("TRoof", (1.9, 2.0, 0.08), (0, 0.4, 2.4), CD, 0.02))
    T.append(S.box("Cupola", (0.6, 0.6, 0.35), (-0.6, 0.4, 2.6), DK, 0.05))
    T.append(S.cyl("Hatch", 0.3, 0.08, (0.6, 0.6, 2.46), ST, 12))
    T.append(S.box("Bustle", (1.8, 0.7, 0.6), (0, 1.8, 1.95), OL, 0.06))
    for sx in (-0.35, 0.35):
        barrel_cyl(BR, (sx, -1.2, 2.0), 0.0, 3.0, 0.11, ST)
        BR.append(S.cyl("Brake", 0.16, 0.35, (sx, -4.35, 2.0), DK, 10, rot=(math.pi / 2, 0, 0)))
        BR.append(S.cyl("Evac", 0.17, 0.7, (sx, -2.0, 2.0), DK, 10, rot=(math.pi / 2, 0, 0)))
    T.append(S.box("Mantlet", (1.5, 0.4, 0.7), (0, -1.2, 2.0), CD, 0.06))
    turret = B.part("Turret", T, (0, 0.3, 1.6))
    barrel = B.part("Barrel", BR, (0, -1.2, 2.0), parent=turret)
    mz = S.empty("Muzzle", (0, -4.6, 2.0), turret)
    extras.extend([turret, barrel, mz])
    finish_unit("heavy_tank", cam=(-10, -12, 6.5))

# ---------------------------------------------------------------- Luftfahrzeuge

elif which in ("west_heli", "red_heli"):
    west = which == "west_heli"
    P.append(S.sphere("Body", 1.0, (0, -0.2, 0.0), TP, scale=(0.85, 2.1, 0.8), segs=28, rings=14))
    P.append(S.sphere("Cockpit", 0.6, (0, -1.6, 0.2), GLS, scale=(0.95, 1.3, 0.85), segs=18, rings=10))
    for sx in (-1, 1):
        P.append(S.box("CockpitFrame", (0.05, 1.0, 0.05), (sx * 0.5, -1.4, 0.45), DK, 0.0, rot=(0.3, 0, sx * 0.2)))
    P.append(S.cyl("Boom", 0.3, 3.6, (0, 2.8, 0.25), TP, 12, r2=0.12, rot=(-math.pi / 2, 0, 0)))
    P.append(S.box("Fin", (0.1, 0.8, 1.2), (0, 4.5, 0.8), TP, 0.03, rot=(-0.3, 0, 0)))
    P.append(S.box("Stabilizer", (1.5, 0.5, 0.08), (0, 4.2, 0.3), TP, 0.02))
    P.append(S.box("Wing", (3.0, 0.7, 0.12), (0, 0.0, -0.1), TP, 0.04))
    P.append(S.cyl("Mast", 0.14, 0.7, (0, 0, 0.95), DK, 10))
    P.append(S.box("Engine", (0.8, 1.6, 0.5), (0, 0.3, 0.75), DK, 0.1))
    for sx in (-0.3, 0.3):
        P.append(S.cyl("Exhaust", 0.14, 0.4, (sx, 1.2, 0.75), ST, 10, rot=(math.pi / 2, 0, 0)))
    for sx in (-0.7, 0.7):
        P.append(S.cyl("Skid", 0.06, 2.8, (sx, -0.1, -1.0), DK, 8, rot=(math.pi / 2, 0, 0)))
        for sy in (-0.7, 0.9):
            P.append(S.cyl("Strut", 0.05, 0.9, (sx * 0.85, sy, -0.55), DK, 6, rot=(0, sx * 0.3, 0)))
    if west:
        for sx in (-1.35, 1.35):
            P.append(S.cyl("Pod", 0.22, 1.1, (sx, -0.2, -0.35), OL, 12, rot=(math.pi / 2, 0, 0)))
            P.append(S.cyl("PodNose", 0.22, 0.2, (sx, -0.85, -0.35), DK, 12, r2=0.08, rot=(math.pi / 2, 0, 0)))
            for k in range(4):
                P.append(S.sphere("RocketHead", 0.06, (sx + math.cos(k * 1.57) * 0.1, -0.95, -0.35 + math.sin(k * 1.57) * 0.1), GLB, segs=6, rings=4))
        P.append(S.sphere("ShieldNode", 0.18, (0, 0.2, 1.05), GLB, segs=10, rings=6))
        P.append(S.box("Strip", (0.04, 2.4, 0.05), (0.78, -0.2, 0.0), GLB, 0.0))
        P.append(S.box("Strip", (0.04, 2.4, 0.05), (-0.78, -0.2, 0.0), GLB, 0.0))
        mz_loc = (1.35, -1.0, -0.35)
    else:
        P.append(S.cyl("Gatling", 0.1, 0.9, (0, -1.8, -0.6), ST, 8, rot=(math.pi / 2, 0, 0)))
        for k in range(6):
            a = k * math.tau / 6
            P.append(S.cyl("GatBarrel", 0.025, 0.9, (math.cos(a) * 0.08, -2.25, -0.6 + math.sin(a) * 0.08), ST, 6, rot=(math.pi / 2, 0, 0)))
        P.append(S.box("GunMount", (0.4, 0.6, 0.3), (0, -1.5, -0.45), DK, 0.04))
        for sx in (-1.3, 1.3):
            P.append(S.box("FuelTank", (0.4, 1.0, 0.3), (sx, -0.1, -0.3), OL, 0.06))
        import sf_bld
        P.append(sf_bld.star(0.04, (0.86, -0.4, 0.2), YE))
        P[-1].rotation_euler = (math.pi / 2, 0, math.pi / 2)
        mz_loc = (0, -2.7, -0.6)
    P.append(S.sphere("NavR", 0.07, (-1.45, 0, -0.1), LR, segs=8, rings=4))
    P.append(S.sphere("NavG", 0.07, (1.45, 0, -0.1), LAN, segs=8, rings=4))
    P.append(S.sphere("Beacon", 0.08, (0, 0.4, 1.3), LR, segs=8, rings=4))
    P.append(S.box("Antenna", (0.02, 0.02, 0.5), (0.3, 3.2, 0.6), DK, 0.0))
    # Hauptrotor (Kreuz aus vier Blättern, Nabe) und Heckrotor als eigene Objekte
    RO.append(S.cyl("Hub", 0.22, 0.2, (0, 0, 1.3), DK, 12))
    for k in range(4):
        a = k * math.pi / 2
        RO.append(S.box("Blade", (0.3, 3.9, 0.05), (math.sin(a) * 2.05, -math.cos(a) * 2.05, 1.3), DK, 0.0, rot=(0, 0, a)))
        RO.append(S.box("BladeTip", (0.32, 0.5, 0.055), (math.sin(a) * 3.8, -math.cos(a) * 3.8, 1.3), YE, 0.0, rot=(0, 0, a)))
    rotor = B.part("Rotor", RO, (0, 0, 1.3))
    TR.append(S.cyl("THub", 0.1, 0.1, (0.15, 4.5, 0.8), DK, 8, rot=(0, math.pi / 2, 0)))
    for k in range(2):
        TR.append(S.box("TBlade", (0.03, 0.15, 0.7), (0.15, 4.5, 0.8 + (0.35 if k == 0 else -0.35)), DK, 0.0))
    trot = B.part("TailRotor", TR, (0.15, 4.5, 0.8))
    mz = S.empty("Muzzle", mz_loc, None)
    extras.extend([rotor, trot, mz])
    finish_unit(which, cam=(-9, -10, 5), tgt=(0, 1, 0.3))

elif which in ("west_jet", "red_jet"):
    west = which == "west_jet"
    P.append(S.sphere("Fuselage", 1.0, (0, 0, 0), TP, scale=(0.55, 3.0, 0.5), segs=28, rings=14))
    P.append(S.cyl("Nose", 0.5, 2.0, (0, -3.4, 0), TP, 14, r2=0.02, rot=(math.pi / 2, 0, 0)))
    P.append(S.sphere("Canopy", 0.4, (0, -1.1, 0.38), GLS, scale=(0.7, 2.1, 0.65), segs=16, rings=8))
    sweep = 0.5 if west else 0.35
    for sx in (-1, 1):
        P.append(S.box("Wing", (2.9, 1.7 if west else 1.3, 0.08), (sx * 1.75, 0.4, -0.06), TP, 0.03, rot=(0, sx * 0.04, sx * sweep)))
        P.append(S.box("WingTip", (0.06, 1.1, 0.06), (sx * 2.2, 0.2, -0.12), ST, 0.01))
        P.append(S.cyl("Missile", 0.07, 1.3, (sx * 1.7, -0.1, -0.3), ST, 8, rot=(math.pi / 2, 0, 0)))
        P.append(S.cyl("MissileNose", 0.07, 0.3, (sx * 1.7, -0.85, -0.3), DK, 8, r2=0.0, rot=(math.pi / 2, 0, 0)))
        P.append(S.box("MissileFin", (0.3, 0.2, 0.02), (sx * 1.7, 0.4, -0.3), DK, 0.0))
        if west:
            P.append(S.box("TailFin", (0.07, 1.0, 0.8), (sx * 0.4, 2.3, 0.5), TP, 0.02, rot=(0, 0, sx * 0.55)))
            P.append(S.box("Stab", (1.3, 0.8, 0.06), (sx * 0.9, 2.6, 0.0), TP, 0.02, rot=(0, 0, -sx * 0.4)))
        else:
            P.append(S.box("TailFin", (0.07, 1.2, 1.0), (sx * 0.55, 2.3, 0.6), TP, 0.02))
            P.append(S.box("Stab", (1.4, 0.8, 0.06), (sx * 0.9, 2.6, 0.0), TP, 0.02, rot=(0, 0, -sx * 0.25)))
        P.append(S.cyl("Intake", 0.3, 1.2, (sx * 0.3, 2.4, -0.05), DK, 12, rot=(math.pi / 2, 0, 0)))
        P.append(S.sphere("Afterburner", 0.26, (sx * 0.3, 3.1, -0.05), GLB if west else GLO, scale=(1, 1.4, 1), segs=10, rings=6))
        P.append(S.box("IntakeLip", (0.3, 0.5, 0.25), (sx * 0.5, -0.9, -0.1), DK, 0.04))
        P.append(S.sphere("NavLight", 0.05, (sx * 3.15, 0.8, -0.1), LR if sx < 0 else LAN, segs=8, rings=4))
    P.append(S.box("Spine", (0.6, 0.3, 0.07), (0, -1.7, 0.05), DK, 0.02))
    import sf_bld
    for sx in (-1, 1):
        P.append(sf_bld.star(0.03, (sx * 1.4, 0.4, 0.0), YE if not west else WH))
    mz = S.empty("Muzzle", (0, -2.4, -0.3), None)
    extras.append(mz)
    finish_unit(which, cam=(-8, -9, 5), tgt=(0, 0, 0))
