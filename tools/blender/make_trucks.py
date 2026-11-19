"""Nachschub-Lkw je Fraktion (Blender): west_truck, red_truck, shadow_truck.

blender -b -P tools/blender/make_trucks.py -- <projektordner> <west|red|shadow>
Ergebnis: models/units/<fraktion>_truck.glb (vorne = -Y, Boden = z 0). Die Fraktionsfassung hat Vorrang vor truck.glb.
  Westbund      - aerodynamischer Kofferlaster: Fahrerhaus mit Pfeilform, Panoramascheibe, Containerkoffer mit Rolltor, Seitenschuerzen
  Rote Allianz  - schwerer Armeelaster: Haubenfahrerhaus, 3 Achsen, Radkaesten, Planenaufbau mit Spriegeln, Reserverad, Seilwinde
  Schattenfront - Schrott-Pickup: Kabine mit Panzerplatten, Ueberrollkaefig, offene Ladeflaeche mit Beute, Reifenstapel, Planen
"""
import math, os, sys, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy
import sf_common as S
import sf_bld as B

which, P = B.setup(33)
random.seed(5)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH
TP = B.M("TeamPaint", (0.6, 0.62, 0.58), 0.35, 0.55, 0.5, 0.5)
OL = B.M("Olive", (0.25, 0.29, 0.2), 0.3, 0.7, 0.5, 0.7)
CV = B.M("Canvas", (0.36, 0.38, 0.27), 0.0, 0.95, 0.3, 0.7)
CV2 = B.M("CanvasShadow", (0.38, 0.33, 0.24), 0.0, 0.95, 0.3, 0.8)
GLO = B.M("GlowOrange", (1.0, 0.55, 0.15), 0.0, 0.3, 0.0, 0.0, 7.0)
WHT = B.M("TruckWhite", (0.84, 0.87, 0.9), 0.35, 0.3, 0.4, 0.4)
WHT2 = B.M("TruckGrey", (0.55, 0.58, 0.62), 0.5, 0.4, 0.4, 0.5)
RED = B.M("TruckRedPaint", (0.5, 0.08, 0.06), 0.3, 0.6, 0.4, 0.5)
RUSTA = B.M("TruckRust", (0.42, 0.22, 0.12), 0.4, 0.85, 0.8, 0.8)
RUSTB = B.M("TruckRustGrey", (0.3, 0.3, 0.28), 0.5, 0.8, 0.8, 0.8)
RUSTC = B.M("TruckRustBlue", (0.2, 0.3, 0.38), 0.4, 0.8, 0.7, 0.8)
PL = B.M("TruckPlate", (0.35, 0.37, 0.38), 0.5, 0.7, 0.6, 0.7)
ROPE = B.M("TruckRope", (0.6, 0.55, 0.38), 0.0, 0.95, 0.2, 0.6)
extras = []


def add(o):
    P.append(o)
    return o


def box(size, loc, mat, bevel=0.03, rot=(0, 0, 0)):
    return add(S.box("B", size, loc, mat, min(bevel, min(size) * 0.45), rot=rot))


def cyl(r, h, loc, mat, seg=14, rot=(0, 0, 0), r2=None):
    return add(S.cyl("C", r, h, loc, mat, seg, r2=r2, rot=rot))


def sph(r, loc, mat, scl=(1, 1, 1)):
    return add(S.sphere("S", r, loc, mat, scale=scl, segs=14, rings=8))


def sidep(prof, width, loc_x, mat, bevel=0.1):
    """Seitenprofil (y vorwärts negativ, z hoch) quer ausgezogen."""
    o = S.prism_xz("SP", [(y, z) for y, z in prof], width, (loc_x, 0, 0), mat, min(bevel, width * 0.3), rot=(0, 0, math.pi / 2))
    return add(o)


def wheel(x, y, r=0.5, w=0.4, tread=True):
    add(S.cyl("Tire", r, w, (x, y, r), RB, 22, rot=(0, math.pi / 2, 0)))
    add(S.cyl("Rim", r * 0.58, w + 0.04, (x, y, r), ST, 14, rot=(0, math.pi / 2, 0)))
    add(S.cyl("Hub", r * 0.22, w + 0.1, (x, y, r), DK, 8, rot=(0, math.pi / 2, 0)))
    side = 1 if x > 0 else -1
    for k in range(8):
        a = math.tau * k / 8.0
        add(S.sphere("Bolt", 0.03, (x + side * (w / 2 + 0.05), y + math.cos(a) * r * 0.36, r + math.sin(a) * r * 0.36), ST, segs=6, rings=4))
    if tread:
        for k in range(14):
            a = math.tau * k / 14.0
            add(S.box("Lug", (w * 1.02, 0.1, 0.07), (x, y + math.cos(a) * r, r + math.sin(a) * r), RB, 0.0, rot=(a + math.pi / 2, 0, 0)))


def fender(x, y, r, mat, w=0.5):
    """Radlauf: halbrunder Bogen aus drei Kanten über dem Rad."""
    side = 1 if x > 0 else -1
    for k in range(7):
        a = math.pi * (0.1 + 0.8 * k / 6.0)
        add(S.box("Arch", (w, 0.17, 0.05), (x, y - math.cos(a) * (r + 0.1), r + math.sin(a) * (r + 0.1)), mat, 0.01, rot=(math.pi / 2 - a + math.pi / 2 * 0 + 0.0, 0, 0)))


def headlights(y, z, hw, mat=LW, r=0.11):
    for sx in (-1, 1):
        add(S.sphere("Lamp", r, (sx * hw, y, z), mat, segs=10, rings=6))


def finish_truck():
    hull = P[0]
    S.join_into(hull, P[1:])
    hull.name = "Hull"
    root = B.root_dir
    tex = os.path.join(root, "models", "source", "textures")
    S.bake(hull, 1024, tex)
    os.makedirs(os.path.join(root, "models", "units"), exist_ok=True)
    S.export(os.path.join(root, "models", "units", "%s_truck.glb" % which), [hull] + list(extras))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "models", "source", "%s_truck.blend" % which))
    S.preview(os.path.join(root, "shots", "%s_truck_preview.png" % which), target=(0, 0, 1.3), cam_loc=(-9, -11, 6), lens=48, ground=(0.3, 0.32, 0.25))
    print("TRUCK_OK", which)


if which == "west":
    # Fahrgestell, drei leichte Achsen, Seitenschürzen
    box((1.9, 5.0, 0.35), (0, 0.1, 0.75), DK, 0.04)
    for y in (-1.5, 1.0, 2.1):
        for sx in (-1, 1):
            wheel(sx * 0.98, y, 0.48, 0.36)
        cyl(0.07, 1.96, (0, y, 0.48), DK, 8, rot=(0, math.pi / 2, 0))
    for sx in (-1, 1):
        box((0.06, 3.9, 0.3), (sx * 1.02, 0.5, 0.85), WHT2, 0.02)
        box((0.06, 1.0, 0.1), (sx * 1.03, 0.5, 0.65), B.M("LightCyan", (0.4, 0.85, 1.0), 0.0, 0.3, 0.0, 0.0, 4.0), 0.0)
        for y in (-1.5, 1.0, 2.1):
            box((0.5, 1.0, 0.07), (sx * 0.98, y, 1.0), WHT, 0.03)
    # Fahrerhaus: Pfeilform, Frontscheibe, Dach mit Windleitblech
    sidep([(-2.45, 0.8), (-2.45, 1.45), (-1.9, 2.25), (-0.9, 2.5), (0.0, 2.5), (0.0, 0.8)], 1.9, 0, WHT, 0.16)
    box((1.7, 0.06, 0.62), (0, -2.0, 1.95), GLS, 0.0, rot=(0.0, 0, 0))
    box((1.7, 0.7, 0.07), (0, -1.55, 2.3), GLS, 0.0, rot=(0.32, 0, 0))
    for sx in (-1, 1):
        box((0.06, 0.95, 0.55), (sx * 0.96, -1.15, 1.95), GLS, 0.0)
        box((0.07, 0.9, 1.15), (sx * 0.97, -1.0, 1.35), WHT2, 0.0)
        add(S.cyl("Handle", 0.025, 0.2, (sx * 1.0, -0.65, 1.4), ST, 6, rot=(math.pi / 2, 0, 0)))
        box((0.1, 0.16, 0.28), (sx * 1.1, -1.85, 2.0), DK, 0.03)
    box((1.9, 0.06, 0.2), (0, -2.43, 1.2), DK, 0.0)
    box((1.3, 0.05, 0.45), (0, -2.47, 1.35), DK, 0.0)
    for sx in (-1, 1):
        box((0.4, 0.06, 0.1), (sx * 0.65, -2.46, 1.05), B.M("LightCyan", (0.4, 0.85, 1.0), 0.0, 0.3, 0.0, 0.0, 4.0), 0.0)
        sph(0.1, (sx * 0.82, -2.44, 1.55), LW)
    box((1.9, 0.5, 0.18), (0, -1.0, 2.6), WHT2, 0.05, rot=(-0.12, 0, 0))
    for sx in (-0.5, 0.0, 0.5):
        sph(0.06, (sx, -1.55, 2.42), B.M("LightCyan", (0.4, 0.85, 1.0), 0.0, 0.3, 0.0, 0.0, 4.0))
    # Koffer: Containeraufbau mit Rolltor, Lüftungsschlitzen und Kühlaggregat
    box((2.1, 3.3, 1.7), (0, 1.55, 1.95), WHT, 0.1)
    box((2.14, 3.34, 0.1), (0, 1.55, 2.82), TP, 0.03)
    box((2.14, 3.34, 0.1), (0, 1.55, 1.15), WHT2, 0.03)
    for k in range(9):
        box((2.16, 0.025, 1.45), (0, -0.05 + k * 0.38, 1.95), WHT2, 0.0)
    for sx in (-1, 1):
        box((0.06, 2.6, 0.4), (sx * 1.07, 1.7, 2.4), TP, 0.02)
        for k in range(6):
            box((0.08, 0.34, 0.07), (sx * 1.08, 0.8 + k * 0.38, 1.55), DK, 0.0)
    box((1.7, 0.06, 1.3), (0, 3.22, 1.95), WHT2, 0.0)
    for k in range(7):
        box((1.7, 0.07, 0.04), (0, 3.26, 1.35 + k * 0.17), ST, 0.0)
    box((1.0, 0.5, 0.7), (0, -0.2, 2.9), WHT2, 0.06)
    for k in range(5):
        box((0.9, 0.05, 0.04), (0, -0.46, 2.7 + k * 0.1), DK, 0.0)
    cyl(0.025, 1.4, (0.9, -0.2, 3.5), DK, 6)
    box((0.5, 0.04, 0.4), (-0.7, 0.8, 3.1), WHT, 0.01, rot=(0, 0, 0.1))
    cyl(0.09, 0.12, (-0.7, 0.8, 2.9), ST, 8)
    box((1.9, 0.12, 0.08), (0, 3.28, 0.9), RED if False else DK, 0.0)
    for sx in (-1, 1):
        sph(0.07, (sx * 0.95, 3.26, 1.0), LR)

elif which == "red":
    # Schwerer Armeelaster: 3 Achsen, Haubenfahrerhaus, Planenaufbau
    box((1.8, 5.6, 0.4), (0, 0.2, 0.8), DK, 0.04)
    for y in (-2.0, 0.55, 1.95):
        for sx in (-1, 1):
            wheel(sx * 1.05, y, 0.58, 0.46)
        cyl(0.09, 2.1, (0, y, 0.58), DK, 8, rot=(0, math.pi / 2, 0))
        for sx in (-1, 1):
            box((0.62, 1.3, 0.08), (sx * 1.02, y, 1.38), OL, 0.04)
            box((0.08, 1.3, 0.28), (sx * 1.3, y, 1.28), OL, 0.04)
    # Motorhaube lang und rund, dahinter Kabine mit Dachluke
    box((1.5, 1.7, 0.95), (0, -2.55, 1.45), OL, 0.18)
    box((1.6, 0.2, 0.95), (0, -3.4, 1.4), OL, 0.1)
    box((1.15, 0.06, 0.55), (0, -3.5, 1.4), DK, 0.0)
    for k in range(6):
        box((1.15, 0.05, 0.03), (0, -3.52, 1.2 + k * 0.1), ST, 0.0)
    for sx in (-1, 1):
        cyl(0.15, 0.2, (sx * 0.6, -3.5, 1.7), ST, 14, rot=(math.pi / 2, 0, 0))
        sph(0.1, (sx * 0.6, -3.62, 1.7), LW)
        for k in range(3):
            add(S.cyl("Guard", 0.012, 0.3, (sx * 0.6 - 0.15 + k * 0.15, -3.55, 1.7), ST, 5, rot=(0, math.pi / 2, 0)))
        box((0.2, 0.9, 0.08), (sx * 0.78, -2.5, 1.95), OL, 0.02)
    box((2.0, 0.28, 0.32), (0, -3.6, 0.9), DK, 0.08)
    cyl(0.22, 0.2, (0, -3.7, 0.9), ST, 14, rot=(math.pi / 2, 0, 0))
    cyl(0.04, 1.2, (0.55, -3.6, 0.88), RUSTB, 8, rot=(0, math.pi / 2, 0))
    box((1.9, 1.5, 1.4), (0, -1.0, 1.9), OL, 0.14)
    box((1.74, 0.06, 0.6), (0, -1.76, 2.15), GLS, 0.0)
    for sx in (-1, 1):
        box((0.06, 1.0, 0.55), (sx * 0.96, -1.0, 2.15), GLS, 0.0)
        box((0.07, 1.0, 0.95), (sx * 0.97, -1.0, 1.55), CD, 0.0)
        box((0.1, 0.2, 0.34), (sx * 1.12, -1.7, 2.0), DK, 0.03)
        box((0.05, 0.4, 0.4), (sx * 0.98, -1.0, 1.6), RED, 0.0)
    box((1.9, 1.5, 0.1), (0, -1.0, 2.62), OL, 0.04)
    cyl(0.35, 0.1, (0, -1.0, 2.7), DK, 14)
    cyl(0.03, 1.2, (0.7, -0.3, 3.2), DK, 6)
    cyl(0.1, 1.6, (-0.95, -0.6, 2.5), ST, 10)
    # Pritsche mit Planenaufbau auf Spriegeln
    box((2.0, 3.4, 0.16), (0, 1.4, 1.15), DK, 0.03)
    for sx in (-1, 1):
        box((0.06, 3.4, 0.45), (sx * 0.98, 1.4, 1.5), OL, 0.02)
    box((2.0, 0.06, 0.45), (0, 3.1, 1.5), OL, 0.02)
    for k in range(6):
        y = 0.0 + k * 0.62
        for sx in (-1, 1):
            box((0.05, 0.05, 1.3), (sx * 0.94, y, 2.05), ST, 0.0)
        box((1.9, 0.05, 0.05), (0, y, 2.72), ST, 0.0)
    cv = box((2.0, 3.4, 1.3), (0, 1.4, 2.1), CV, 0.22)
    for k in range(5):
        box((2.02, 0.03, 1.1), (0, 0.3 + k * 0.62, 2.1), CD, 0.0)
    box((1.4, 0.08, 0.3), (0, 3.12, 2.2), CV, 0.0)
    # Reserverad, Kanister, Seil, Heckleuchten
    wheel(0.0, 0.15, 0.5, 0.36, tread=False) if False else None
    cyl(0.5, 0.34, (0.0, 1.4, 0.9), RB, 18, rot=(math.pi / 2, 0, 0)) if False else None
    cyl(0.52, 0.32, (-0.62, 3.35, 1.1), RB, 18, rot=(math.pi / 2, 0, 0))
    cyl(0.3, 0.34, (-0.62, 3.35, 1.1), ST, 12, rot=(math.pi / 2, 0, 0))
    for sx in (-1, 1):
        box((0.35, 0.3, 0.45), (sx * 1.0, 1.0, 1.0), OL if sx > 0 else CD, 0.04)
        sph(0.07, (sx * 0.9, 3.15, 1.2), LR)
    cyl(0.14, 0.4, (0.9, 3.28, 1.1), B.M("JerryRed", (0.5, 0.1, 0.06), 0.3, 0.7, 0.4, 0.5), 10)
    # roter Stern
    for sx in (-1, 1):
        o = B.star(0.05, (sx * 1.005, -1.0, 1.55), RED, 0.28, 0.11)
        o.rotation_euler = (math.pi / 2, 0, math.pi / 2)

else:
    # Schattenfront: Schrott-Pickup — kurze Kabine mit Platten, Überrollkäfig, offene Ladefläche
    box((1.8, 4.6, 0.3), (0, 0.3, 0.85), DK, 0.04)
    for y in (-1.45, 1.55):
        for sx in (-1, 1):
            wheel(sx * 1.0, y, 0.6, 0.5)
        cyl(0.08, 2.0, (0, y, 0.6), DK, 8, rot=(0, math.pi / 2, 0))
    for sx in (-1, 1):
        box((0.55, 1.1, 0.07), (sx * 1.0, -1.45, 1.52), RUSTB if sx > 0 else RUSTC, 0.03, rot=(0, 0, sx * 0.05))
        box((0.55, 1.1, 0.07), (sx * 1.0, 1.55, 1.52), RUSTA, 0.03)
    # Motorhaube mit Beulen und Gittern
    box((1.6, 1.3, 0.55), (0, -2.1, 1.5), RUSTA, 0.15)
    box((1.4, 0.08, 0.45), (0, -2.75, 1.45), DK, 0.0)
    for k in range(4):
        box((1.3, 0.05, 0.03), (0, -2.8, 1.3 + k * 0.1), ST, 0.0)
    box((1.4, 0.6, 0.06), (0.2, -2.0, 1.82), RUSTB, 0.02, rot=(0.0, 0, 0.12))
    cyl(0.07, 0.8, (-0.6, -2.3, 2.05), RUSTB, 8)
    for sx in (-1, 1):
        sph(0.12, (sx * 0.62, -2.75, 1.58), GLO if sx > 0 else LW)
    box((2.0, 0.22, 0.22), (0, -2.85, 0.95), ST, 0.05)
    for k in range(5):
        cyl(0.02, 0.3, (-0.6 + k * 0.3, -2.95, 0.95), ST, 5, rot=(math.pi / 2, 0, 0))
    # Kabine aus Blech, dazu Plattenpanzerung und Fensterschlitze
    box((1.8, 1.4, 1.1), (0, -0.9, 1.75), RUSTC, 0.12)
    box((1.6, 0.06, 0.4), (0, -1.6, 2.0), GLS, 0.0)
    for sx in (-1, 1):
        box((0.06, 0.8, 0.35), (sx * 0.91, -0.9, 2.0), GLS, 0.0)
        box((0.08, 1.0, 0.7), (sx * 0.93, -0.9, 1.55), RUSTA if sx > 0 else PL, 0.0)
        for dy in (-0.3, 0.3):
            for dz in (-0.2, 0.2):
                add(S.sphere("Bolt", 0.025, (sx * 0.98, -0.9 + dy, 1.55 + dz), ST, segs=6, rings=4))
    box((1.9, 1.5, 0.08), (0, -0.9, 2.33), RUSTA, 0.03, rot=(0.04, 0, 0))
    box((1.2, 0.3, 0.3), (0, -1.65, 1.55), PL, 0.04)
    # Überrollkäfig und Scheinwerfer
    for sx in (-1, 1):
        cyl(0.045, 1.5, (sx * 0.85, 0.5, 2.0), ST, 8)
        cyl(0.045, 1.7, (sx * 0.85, 0.5, 2.75), ST, 8, rot=(math.pi / 2, 0, 0))
        cyl(0.045, 1.0, (sx * 0.85, 1.35, 2.5), ST, 8, rot=(0.6, 0, 0))
    cyl(0.045, 1.7, (0, 0.5, 2.75), ST, 8, rot=(0, math.pi / 2, 0))
    for sx in (-0.45, 0.45):
        cyl(0.12, 0.2, (sx, 0.5, 2.95), DK, 12, rot=(math.pi / 2, 0, 0))
        sph(0.1, (sx, 0.38, 2.95), LW)
    # Ladefläche: offen, Wände aus Brettern und Blech, Beute
    box((2.0, 2.6, 0.12), (0, 1.55, 1.15), DK, 0.02)
    for sx in (-1, 1):
        box((0.07, 2.6, 0.5), (sx * 0.98, 1.55, 1.5), RUSTA if sx > 0 else WD, 0.02)
        box((0.07, 1.0, 0.5), (sx * 0.98, 2.2, 1.55), RUSTB, 0.02)
    box((2.0, 0.07, 0.5), (0, 2.85, 1.5), WD, 0.02)
    for k in range(4):
        sx = (-0.5, 0.5)[k % 2]
        box((0.7, 0.6, 0.5), (sx, 1.2 + (k // 2) * 0.8, 1.5 + (k // 3) * 0.3), WL if k % 2 else RUSTA, 0.04, rot=(0, 0, random.uniform(-0.2, 0.2)))
    sph(0.7, (0.0, 2.15, 1.55), CV2, (1.2, 0.9, 0.55))
    for k in range(3):
        cyl(0.2, 0.2, (-0.55, 2.4 - k * 0.0, 1.65 + k * 0.2), RB, 12)
    for k in range(3):
        cyl(0.17, 0.4, (0.6 + 0.0, 2.45 - k * 0.35, 1.5), B.M("Barrel%d" % (k % 2), (0.5, 0.25, 0.12) if k % 2 == 0 else (0.2, 0.3, 0.38), 0.3, 0.8, 0.6, 0.7), 10)
    # Reifenstapel am Heck, Ketten, Antenne mit Lumpenfahne
    for k in range(3):
        cyl(0.45, 0.2, (0.0, 3.1, 1.15 + k * 0.2), RB, 18, rot=(math.pi / 2, 0, 0))
    cyl(0.012, 2.2, (-0.9, 3.0, 3.0), DK, 6)
    box((0.02, 0.5, 0.25), (-0.9, 3.25, 4.0), B.M("Rag", (0.06, 0.06, 0.06), 0.0, 0.95, 0.2, 0.5), 0.0)
    for sx in (-1, 1):
        box((0.1, 0.06, 0.06), (sx * 0.9, 3.02, 1.02), RUSTB, 0.0)
        sph(0.07, (sx * 0.85, 3.0, 1.3), LR)

finish_truck()
