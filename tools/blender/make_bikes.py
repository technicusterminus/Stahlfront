"""Leichte Fahrzeuge mit Besatzung (Blender): Motorrad der Schattenfront, Dünenbuggy des Westbunds.

blender -b -P tools/blender/make_bikes.py -- <projektordner> <bike|dunebuggy>
Ergebnis: models/units/<modell>.glb, Vorschau shots/<modell>_preview.png.
Maßstab: echte Größe; im Spiel wie die Soldaten um 1,3 vergrößert (Einheit "scale": 1.3).
Bewegliche Teile: Turret (Schütze samt Waffe), Muzzle, Räder als eigene Objekte Wheel* (drehen sich im Spiel um X).
Vorne = -Y, Boden = z 0.
"""
import math, os, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import sf_common as S
import sf_bld as B
import sf_crew as C

which, P = B.setup(31)
m = B.mats()
DK, ST, YE, GLS, LW, WD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.LW, m.WD, m.RS, m.RB, m.WH
TP = B.M("TeamPaint", (0.6, 0.62, 0.58), 0.35, 0.55, 0.5, 0.5)
AL = B.M("Alloy", (0.62, 0.63, 0.64), 0.85, 0.32, 0.3, 0.5)
SEAT = B.M("SeatLeather", (0.06, 0.055, 0.05), 0.0, 0.62, 0.3, 0.4)
PIPE = B.M("ExhaustPipe", (0.33, 0.27, 0.22), 0.8, 0.45, 0.6, 0.6)
OL = B.M("Olive", (0.25, 0.29, 0.2), 0.3, 0.7, 0.5, 0.7)
SAND = B.M("HullSand", (0.62, 0.55, 0.42), 0.25, 0.6, 0.5, 0.6)
CV = B.M("Canvas", (0.4, 0.38, 0.28), 0.0, 0.95, 0.2, 0.6)
RAG = B.M("Rag", (0.32, 0.12, 0.08), 0.0, 0.95, 0.2, 0.6)
GUN = B.M("Gunmetal", (0.09, 0.09, 0.1), 0.7, 0.45, 0.4, 0.3)
T = []         # Turm (Schütze und Waffe)
extras = []


# ---------------------------------------------------------------- Bausteine

def tube(name, a, b, r, mat, verts=10, parts=None):
    """Gerades Rohr von a nach b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    ob = S.cyl(name, r, d.length, tuple((a + b) * 0.5), mat, verts)
    ob.rotation_mode = "QUATERNION"
    ob.rotation_quaternion = d.to_track_quat("Z", "Y")
    (P if parts is None else parts).append(ob)
    return ob


def _fillet(pts, rad, n=5):
    pts = [Vector(p) for p in pts]
    out = [pts[0]]
    for i in range(1, len(pts) - 1):
        p0, p1, p2 = pts[i - 1], pts[i], pts[i + 1]
        u1 = p1 - p0
        u2 = p2 - p1
        d = min(rad, u1.length * 0.45, u2.length * 0.45)
        a = p1 - u1.normalized() * d
        c = p1 + u2.normalized() * d
        for k in range(n + 1):
            t = k / n
            out.append((1 - t) ** 2 * a + 2 * (1 - t) * t * p1 + t ** 2 * c)
    out.append(pts[-1])
    return out


def bent(name, pts, r, mat, rad=0.08, sides=8, parts=None):
    """Gebogenes Rohr durch die Punkte, Ecken mit Biegeradius (Rahmen, Lenker, Auspuff, Käfig)."""
    q = _fillet(pts, rad)
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    sp = cu.splines.new("POLY")
    sp.points.add(len(q) - 1)
    for i, p in enumerate(q):
        sp.points[i].co = (p.x, p.y, p.z, 1.0)
    cu.bevel_depth = r
    cu.bevel_resolution = max(0, sides // 4 - 1)
    cu.use_fill_caps = True
    ob = bpy.data.objects.new(name, cu)
    S.scene.collection.objects.link(ob)
    S.activate(ob)
    bpy.ops.object.convert(target="MESH")
    ob = bpy.context.active_object
    ob.name = name
    S._finish(ob, mat, 0.0, smooth=True)
    (P if parts is None else parts).append(ob)
    return ob


def tire(parts, c, r_out, width, knob_rows=3, n=22, block=False):
    """Geländereifen: runder Querschnitt (Torus um die X-Achse) mit Stollen in versetzten Reihen."""
    bpy.ops.mesh.primitive_torus_add(major_radius=r_out - width * 0.5, minor_radius=width * 0.5,
                                     major_segments=30, minor_segments=8, location=(0, 0, 0))
    t = bpy.context.active_object
    t.name = "Tire"
    t.rotation_euler = (0, math.pi / 2, 0)
    t.location = c
    S._finish(t, RB, 0.0, smooth=True)
    parts.append(t)
    x, y, z = c
    rows = [(0.0, 0.0)] if knob_rows == 1 else [(-0.36, 0.0), (0.0, 0.5), (0.36, 0.0)]
    if block:
        rows = [(-0.3, 0.0), (0.3, 0.5)]
    for dx, phase in rows:
        rr = r_out - (0.12 if abs(dx) > 0.2 and not block else 0.0) * width
        for i in range(n):
            a = (i + phase) / n * math.tau
            kw = width * (0.3 if not block else 0.42)
            kl = r_out * math.tau / n * (0.42 if not block else 0.55)
            kh = width * (0.16 if not block else 0.2)
            loc = (x + dx * width, y + math.cos(a) * rr, z + math.sin(a) * rr)
            parts.append(S.box("Knob", (kw, kl, kh), loc, RB, 0.0, rot=(a - math.pi / 2, 0, 0)))


def spoked_wheel(name, c, r_out, width, rim_r, spokes=16, disc=None, sprocket=None):
    """Speichenrad als eigenes Objekt (dreht sich im Spiel): Stollenreifen, Felge, Speichen, Nabe, Bremsscheibe."""
    W = []
    tire(W, c, r_out, width)
    x, y, z = c
    bpy.ops.mesh.primitive_torus_add(major_radius=rim_r, minor_radius=0.013, major_segments=28, minor_segments=5, location=(0, 0, 0))
    rim = bpy.context.active_object
    rim.name = "Rim"
    rim.rotation_euler = (0, math.pi / 2, 0)
    rim.location = c
    S._finish(rim, AL, 0.0, smooth=True)
    W.append(rim)
    W.append(S.cyl("Hub", 0.045, 0.13, c, AL, 14, rot=(0, math.pi / 2, 0)))
    for i in range(spokes):
        a = i / spokes * math.tau
        side = 1 if i % 2 == 0 else -1
        a2 = a + (0.35 if side > 0 else -0.35)
        tube("Spoke", (x + side * 0.05, y + math.cos(a) * 0.04, z + math.sin(a) * 0.04),
             (x + side * 0.008, y + math.cos(a2) * (rim_r - 0.01), z + math.sin(a2) * (rim_r - 0.01)), 0.0035, ST, 4, W)
    if disc is not None:
        W.append(S.cyl("Disc", disc, 0.006, (x + 0.068, y, z), ST, 28, rot=(0, math.pi / 2, 0)))
        W.append(S.cyl("DiscHub", 0.06, 0.012, (x + 0.07, y, z), AL, 12, rot=(0, math.pi / 2, 0)))
    if sprocket is not None:
        sp = S.cyl("Sprocket", sprocket, 0.008, (x - 0.072, y, z), DK, 36, rot=(0, math.pi / 2, 0))
        W.append(sp)
    wheel = B.part(name, W, c)
    extras.append(wheel)
    return wheel


def block_wheel(name, c, r_out, width, rim_r):
    """Breiter Buggy-Reifen mit Blockprofil und Stahlfelge mit Beadlock-Ring."""
    W = []
    tire(W, c, r_out, width, n=20, block=True)
    x, y, z = c
    sx = 1 if x > 0 else -1
    W.append(S.cyl("Rim", rim_r, width * 0.9, c, ST, 24, rot=(0, math.pi / 2, 0)))
    W.append(S.cyl("Beadlock", rim_r * 1.04, 0.025, (x + sx * width * 0.42, y, z), AL, 24, rot=(0, math.pi / 2, 0)))
    W.append(S.cyl("RimDish", rim_r * 0.75, 0.03, (x + sx * width * 0.36, y, z), DK, 18, rot=(0, math.pi / 2, 0)))
    for i in range(8):
        a = i / 8 * math.tau
        W.append(S.cyl("Bolt", 0.012, 0.03, (x + sx * width * 0.46, y + math.cos(a) * rim_r * 0.95, z + math.sin(a) * rim_r * 0.95), AL, 6, rot=(0, math.pi / 2, 0)))
    W.append(S.cyl("Hub", 0.07, width * 1.05, c, AL, 12, rot=(0, math.pi / 2, 0)))
    wheel = B.part(name, W, c)
    extras.append(wheel)
    return wheel


def coilover(a, b, r=0.035, parts=None):
    """Federbein: Dämpferrohr mit Schraubenfeder."""
    a, b = Vector(a), Vector(b)
    tube("Damper", a, b, r * 0.55, AL, 10, parts)
    d = (b - a)
    for k in range(7):
        p = a + d * (0.2 + k * 0.09)
        ring = S.cyl("Coil", r, 0.012, tuple(p), YE, 14)
        ring.rotation_mode = "QUATERNION"
        ring.rotation_quaternion = d.to_track_quat("Z", "Y")
        (P if parts is None else parts).append(ring)


def finish_unit(name, cam, tgt, bake=1024, preview_yaw=0.0):
    hull = P[0]
    S.join_into(hull, P[1:])
    hull.name = "Hull"
    root = B.root_dir
    S.bake(hull, bake, os.path.join(root, "models", "source", "textures"))
    objs = [hull] + list(extras)
    S.export(os.path.join(root, "models", "units", "%s.glb" % name), objs)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "models", "source", "%s.blend" % name))
    for ob in extras:
        if ob.name == "Turret":
            ob.rotation_euler = (0, 0, preview_yaw)
    S.preview(os.path.join(root, "shots", "%s_preview.png" % name), target=tgt, cam_loc=cam, lens=50, ground=(0.45, 0.4, 0.32))
    print("VEHICLE_OK", name)


# ---------------------------------------------------------------- Motorrad (Schattenfront: Kradräuber)

if which == "bike":
    FW = (0.0, -0.74, 0.34)     # Vorderachse
    RW = (0.0, 0.74, 0.335)     # Hinterachse
    HEAD = Vector((0.0, -0.40, 1.0))   # Lenkkopf
    # Rahmen: Rückgrat, Doppelschleife unter dem Motor, Heckrahmen
    P.append(S.box("FrameNeck", (0.07, 0.1, 0.18), tuple(HEAD - Vector((0, 0, 0.05))), DK, 0.02, rot=(-0.44, 0, 0)))
    bent("Backbone", [HEAD + Vector((0, 0.03, 0.02)), (0, 0.05, 0.86), (0, 0.16, 0.62), (0, 0.16, 0.42)], 0.026, DK, rad=0.1)
    for sx in (-1, 1):
        bent("Cradle", [HEAD + Vector((0, 0.02, -0.1)), (sx * 0.05, -0.28, 0.42), (sx * 0.06, -0.18, 0.2), (sx * 0.06, 0.12, 0.2), (sx * 0.07, 0.17, 0.42)], 0.017, DK, rad=0.09)
        bent("SubFrame", [(sx * 0.03, 0.08, 0.84), (sx * 0.08, 0.42, 0.86), (sx * 0.08, 0.86, 0.9)], 0.013, DK, rad=0.08)
        tube("SubStay", (sx * 0.07, 0.2, 0.46), (sx * 0.08, 0.6, 0.86), 0.011, DK, 8)
        # Schwinge und Fußrasten
        tube("Swingarm", (sx * 0.07, 0.17, 0.42), (sx * 0.085, 0.74, 0.335), 0.022, AL, 10)
        P.append(S.box("Peg", (0.1, 0.04, 0.025), (sx * 0.17, 0.1, 0.38), ST, 0.008))
        P.append(S.box("PegPass", (0.08, 0.035, 0.022), (sx * 0.16, 0.5, 0.54), ST, 0.008))
        tube("PegPassMount", (sx * 0.08, 0.46, 0.62), (sx * 0.13, 0.5, 0.54), 0.01, DK, 6)
    P.append(S.box("SwingBrace", (0.17, 0.08, 0.05), (0, 0.32, 0.39), AL, 0.01))
    coilover((0, 0.12, 0.86), (0, 0.36, 0.48), 0.034)
    # Gabel: zwei Standrohre, Tauchrohre, Gabelbrücken, Achsklemmen
    up = (HEAD - Vector(FW)).normalized()
    for sx in (-1, 1):
        bot = Vector(FW) + Vector((sx * 0.085, 0, 0))
        tube("ForkLeg", bot - up * 0.02, bot + up * 0.4, 0.03, DK, 12)
        tube("Stanchion", bot + up * 0.38, Vector((sx * 0.085, 0, 0)) + HEAD + up * 0.08, 0.022, AL, 12)
        P.append(S.box("ForkGuard", (0.03, 0.06, 0.2), tuple(bot + up * 0.2 + Vector((sx * 0.02, -0.03, 0))), TP, 0.01, rot=(-0.44, 0, 0)))
    for k, dz in ((0, -0.06), (1, 0.1)):
        c = HEAD + up * dz
        P.append(S.box("TripleClamp", (0.24, 0.08, 0.035), tuple(c), AL, 0.012, rot=(-0.44, 0, 0)))
    # Lenker mit Griffen, Hebeln, Polster
    bar = [(-0.4, -0.31, 1.15), (-0.3, -0.36, 1.14), (-0.12, -0.38, 1.1), (0.12, -0.38, 1.1), (0.3, -0.36, 1.14), (0.4, -0.31, 1.15)]
    bent("Handlebar", bar, 0.012, ST, rad=0.06)
    P.append(S.box("BarPad", (0.18, 0.05, 0.05), (0, -0.38, 1.13), RS, 0.02))
    for sx in (-1, 1):
        tube("Grip", (sx * 0.3, -0.355, 1.14), (sx * 0.42, -0.305, 1.155), 0.019, RB, 10)
        tube("Lever", (sx * 0.24, -0.38, 1.13), (sx * 0.38, -0.42, 1.12), 0.006, AL, 6)
        P.append(S.box("HandGuard", (0.13, 0.03, 0.06), (sx * 0.36, -0.4, 1.17), TP, 0.012, rot=(0, 0, sx * 0.3)))
    # Scheinwerfermaske, Kotflügel, Tank, Kühlerverkleidungen, Sitzbank, Heck
    P.append(S.box("NumberPlate", (0.22, 0.03, 0.24), (0, -0.53, 0.98), TP, 0.03, rot=(0.44, 0, 0)))
    P.append(S.sphere("Headlight", 0.055, (0, -0.56, 0.98), LW, scale=(1, 0.4, 1), segs=14, rings=8))
    P.append(S.box("FrontFender", (0.13, 0.46, 0.02), (0, -0.82, 0.76), TP, 0.008, rot=(-0.12, 0, 0)))
    P.append(S.sphere("Tank", 1.0, (0, -0.17, 0.97), TP, scale=(0.15, 0.27, 0.11), segs=20, rings=10))
    P.append(S.cyl("TankCap", 0.03, 0.02, (0, -0.2, 1.08), AL, 12))
    for sx in (-1, 1):
        P.append(S.box("Shroud", (0.03, 0.34, 0.22), (sx * 0.16, -0.22, 0.86), TP, 0.012, rot=(0.15, sx * 0.12, 0)))
        P.append(S.box("SidePanel", (0.025, 0.3, 0.14), (sx * 0.12, 0.62, 0.84), TP, 0.01, rot=(-0.2, 0, 0)))
        P.append(S.box("Radiator", (0.03, 0.16, 0.2), (sx * 0.12, -0.26, 0.74), DK, 0.006))
    P.append(S.box("Seat", (0.2, 0.86, 0.075), (0, 0.33, 0.97), SEAT, 0.03, rot=(-0.04, 0, 0)))
    P.append(S.box("SeatBase", (0.18, 0.84, 0.03), (0, 0.33, 0.925), DK, 0.008, rot=(-0.04, 0, 0)))
    P.append(S.box("RearFender", (0.16, 0.5, 0.02), (0, 0.96, 0.93), TP, 0.008, rot=(-0.22, 0, 0)))
    P.append(S.box("TailLight", (0.07, 0.02, 0.04), (0, 1.15, 0.97), m.LR, 0.005))
    P.append(S.box("RearPlate", (0.14, 0.01, 0.1), (0, 1.17, 0.9), WH, 0.004, rot=(-0.4, 0, 0)))
    # Motor: Kurbelgehäuse, Zylinder mit Kühlrippen, Kopf, Vergaser, Luftfilter, Seitendeckel
    P.append(S.box("Crankcase", (0.2, 0.34, 0.24), (0, -0.04, 0.38), AL, 0.04))
    for sx in (-1, 1):
        P.append(S.cyl("CaseCover", 0.1, 0.03, (sx * 0.11, -0.02 + sx * 0.04, 0.38), AL, 20, rot=(0, math.pi / 2, 0)))
    for k in range(7):
        P.append(S.box("Fin", (0.2, 0.17, 0.012), (0, -0.14 + k * 0.002, 0.53 + k * 0.03), DK, 0.004, rot=(0.12, 0, 0)))
    P.append(S.box("Cylinder", (0.11, 0.11, 0.22), (0, -0.135, 0.62), AL, 0.02, rot=(0.12, 0, 0)))
    P.append(S.box("CylHead", (0.17, 0.15, 0.08), (0, -0.15, 0.76), AL, 0.02, rot=(0.12, 0, 0)))
    P.append(S.cyl("Carb", 0.035, 0.12, (0.0, -0.02, 0.66), AL, 10, rot=(math.pi / 2, 0, 0)))
    P.append(S.box("Airbox", (0.16, 0.18, 0.16), (0, 0.18, 0.72), DK, 0.03))
    tube("Chain", (-0.075, -0.0, 0.38), (-0.085, 0.74, 0.335), 0.008, DK, 6)
    tube("Chain", (-0.075, 0.0, 0.29), (-0.085, 0.74, 0.25), 0.008, DK, 6)
    P.append(S.box("ChainGuard", (0.02, 0.4, 0.05), (-0.1, 0.45, 0.4), DK, 0.006))
    P.append(S.box("SkidPlate", (0.2, 0.42, 0.02), (0, -0.04, 0.2), AL, 0.008))
    # Auspuff: Krümmer vorn aus dem Kopf, rechts am Rahmen entlang, Schalldämpfer hoch am Heck
    bent("Header", [(0.03, -0.22, 0.74), (0.06, -0.3, 0.62), (0.12, -0.24, 0.46), (0.15, 0.05, 0.5), (0.17, 0.38, 0.68)], 0.022, PIPE, rad=0.07)
    tube("Muffler", (0.17, 0.36, 0.68), (0.16, 0.92, 0.86), 0.045, AL, 14)
    P.append(S.cyl("MufflerTip", 0.028, 0.06, (0.16, 0.95, 0.875), DK, 10, rot=(math.pi / 2 - 0.3, 0, 0)))
    P.append(S.box("HeatShield", (0.02, 0.24, 0.07), (0.185, 0.02, 0.5), PIPE, 0.01))
    # Räuberausstattung: Gepäckträger mit Kanister, Lumpenfahne, Patronengurt
    P.append(S.box("Rack", (0.2, 0.22, 0.015), (0, 0.98, 1.0), DK, 0.004))
    P.append(S.box("Jerrycan", (0.1, 0.2, 0.26), (0.0, 1.0, 1.14), OL, 0.02))
    tube("Antenna", (-0.08, 1.0, 1.0), (-0.1, 1.06, 2.25), 0.006, DK, 5)
    P.append(S.box("Rag", (0.01, 0.32, 0.18), (-0.1, 1.22, 2.12), RAG, 0.0))
    P.append(S.box("BarRag", (0.015, 0.05, 0.16), (-0.33, -0.36, 1.05), RAG, 0.0, rot=(0.2, 0, 0)))

    # Räder (drehen sich im Spiel)
    spoked_wheel("WheelF", FW, 0.34, 0.085, 0.265, 18, disc=0.12)
    spoked_wheel("WheelR", RW, 0.335, 0.12, 0.23, 18, sprocket=0.11)

    # Fahrer: sitzt vorn, Hände am Lenker, Füße auf den Rasten, leicht nach vorn gebeugt
    lo, hi, _ = C.figure("shadow", "rider", pelvis=(0, 0.12, 1.13),
                         feet={"L": (0.17, 0.08, 0.46), "R": (-0.17, 0.08, 0.46)},
                         hands={"L": (0.34, -0.34, 1.17), "R": (-0.34, -0.34, 1.17)},
                         pose={"spine": (16, 0, 0), "chest": (10, 0, 0), "neck": (-8, 0, 0), "head": (-14, 0, 0)},
                         foot_pitch=0)
    P.extend(lo + hi)
    # Sozius: Beine auf den hinteren Rasten (Rumpf), Oberkörper mit Gewehr dreht sich als Turret
    lo, hi, pts = C.figure("shadow", "inf", pelvis=(0, 0.55, 1.17),
                           feet={"L": (0.16, 0.44, 0.6), "R": (-0.16, 0.44, 0.6)},
                           pose={"spine": (6, 0, 0), "chest": (2, 0, 0), "upperarm.R": (-40, 0, 18), "forearm.R": (-38, 0, 0), "hand.R": (78, 0, 0),
                                 "upperarm.L": (-58, 0, -22), "forearm.L": (-22, 0, 0), "head": (8, 0, 0)},
                           split_upper=True, marks={"muzzle": ("hand.R", (-0.05, -0.87, 1.12))}, foot_pitch=0)
    P.extend(lo)
    T.extend(hi)
    pivot = (0, 0.55, 1.17)
    turret = B.part("Turret", T, pivot)
    S.bake(turret, 512, os.path.join(B.root_dir, "models", "source", "textures"))
    mz = S.empty("Muzzle", tuple(pts["muzzle"]), turret)
    extras.extend([turret, mz])
    finish_unit("bike", cam=(-3.4, -3.6, 2.2), tgt=(0, 0.1, 0.85), preview_yaw=-1.0)

# ---------------------------------------------------------------- Dünenbuggy (Westbund: Sandviper)

elif which == "dunebuggy":
    WB, TW, WR = 1.15, 0.82, 0.4          # halber Radstand, halbe Spurweite, Radradius
    FLOOR = 0.52
    # Bodenrahmen und Bodenblech
    for sx in (-1, 1):
        bent("Rail", [(sx * 0.32, -1.62, 0.62), (sx * 0.45, -1.2, 0.5), (sx * 0.52, -0.6, FLOOR - 0.04), (sx * 0.52, 0.9, FLOOR - 0.04), (sx * 0.45, 1.5, 0.62)], 0.035, DK, rad=0.15)
    P.append(S.box("Floor", (1.0, 2.0, 0.03), (0, 0.1, FLOOR - 0.06), DK, 0.01))
    for y in (-1.2, -0.6, 0.0, 0.6, 1.2):
        tube("CrossBar", (-0.5, y, FLOOR - 0.04), (0.5, y, FLOOR - 0.04), 0.026, DK, 8)
    # Überrollkäfig: Haupt- und Frontbügel, Dachholme, Diagonalen, Heckstreben
    for sx in (-1, 1):
        bent("MainHoop", [(sx * 0.6, 0.15, FLOOR), (sx * 0.62, 0.15, 1.35), (sx * 0.5, 0.15, 1.62), (0, 0.15, 1.66)], 0.032, DK, rad=0.18)
        bent("APillar", [(sx * 0.5, -0.95, 0.72), (sx * 0.52, -0.55, 1.3), (sx * 0.5, -0.32, 1.6), (sx * 0.5, 0.15, 1.62)], 0.03, DK, rad=0.16)
        tube("Diagonal", (sx * 0.6, 0.15, FLOOR + 0.05), (sx * 0.5, -0.6, 1.25), 0.022, DK, 8)
        bent("RearStrut", [(sx * 0.5, 0.15, 1.6), (sx * 0.52, 0.9, 1.05), (sx * 0.48, 1.45, 0.75)], 0.026, DK, rad=0.12)
        tube("NerfBar", (sx * 0.62, -0.7, FLOOR + 0.05), (sx * 0.64, 0.85, FLOOR + 0.05), 0.025, DK, 8)
    tube("RoofBar", (-0.5, -0.32, 1.6), (0.5, -0.32, 1.6), 0.026, DK, 8)
    tube("CageX", (-0.5, 0.15, 1.62), (0.5, -0.32, 1.6), 0.02, DK, 8)
    # Vorbau: Stoßfänger, Rammschutz, Haube, Scheinwerfer, Seilwinde
    bent("Bumper", [(-0.55, -1.55, 0.6), (-0.4, -1.72, 0.62), (0.4, -1.72, 0.62), (0.55, -1.55, 0.6)], 0.035, DK, rad=0.15)
    for sx in (-1, 1):
        tube("BumperPost", (sx * 0.3, -1.68, 0.62), (sx * 0.3, -1.25, 0.9), 0.025, DK, 8)
    P.append(S.box("Hood", (0.9, 0.8, 0.04), (0, -1.15, 0.92), TP, 0.03, rot=(-0.18, 0, 0)))
    P.append(S.box("HoodNose", (0.7, 0.3, 0.2), (0, -1.55, 0.78), SAND, 0.05))
    P.append(S.box("Winch", (0.36, 0.14, 0.14), (0, -1.72, 0.74), DK, 0.02))
    for sx in (-1, 1):
        P.append(S.cyl("Spot", 0.075, 0.07, (sx * 0.28, -0.4, 1.7), DK, 14, rot=(math.pi / 2, 0, 0)))
        P.append(S.cyl("SpotGlass", 0.06, 0.012, (sx * 0.28, -0.44, 1.7), LW, 14, rot=(math.pi / 2, 0, 0)))
    # Sitze: Fahrer links, rechts Gepäck und Munition
    for sx, mat in ((-1, CV), (1, CV)):
        P.append(S.box("SeatPan", (0.46, 0.46, 0.08), (sx * 0.3, -0.12, FLOOR + 0.05), mat, 0.03))
        P.append(S.box("SeatBack", (0.46, 0.08, 0.55), (sx * 0.3, 0.12, FLOOR + 0.35), mat, 0.03, rot=(0.15, 0, 0)))
    P.append(S.box("AmmoBox", (0.3, 0.22, 0.22), (0.3, -0.18, FLOOR + 0.2), OL, 0.02))
    P.append(S.box("AmmoBox", (0.28, 0.2, 0.2), (0.32, -0.15, FLOOR + 0.41), OL, 0.02))
    P.append(S.box("Radio", (0.24, 0.16, 0.2), (0.32, 0.25, FLOOR + 0.6), DK, 0.02))
    # Lenkung
    P.append(S.cyl("Column", 0.02, 0.6, (-0.3, -0.75, 0.88), ST, 8, rot=(-0.95, 0, 0)))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.17, minor_radius=0.014, major_segments=24, minor_segments=6, location=(0, 0, 0))
    sw = bpy.context.active_object
    sw.name = "SteeringWheel"
    sw.rotation_euler = (math.pi / 2 - 0.95, 0, 0)
    sw.location = (-0.3, -0.55, 1.06)
    S._finish(sw, RB, 0.0, smooth=True)
    P.append(sw)
    P.append(S.box("Dash", (0.9, 0.12, 0.18), (0, -0.85, 0.95), DK, 0.02, rot=(-0.3, 0, 0)))
    # Heck: offener Motor, Luftfilter, Krümmer, Kühler, Kanister, Reserverad
    P.append(S.box("Engine", (0.6, 0.55, 0.4), (0, 1.15, 0.8), AL, 0.05))
    P.append(S.box("Valvecover", (0.5, 0.2, 0.1), (0, 1.12, 1.05), DK, 0.03))
    P.append(S.cyl("AirFilter", 0.12, 0.18, (0.2, 1.0, 1.15), RS, 16))
    for sx in (-1, 1):
        bent("Exhaust", [(sx * 0.32, 1.1, 0.8), (sx * 0.42, 1.3, 0.85), (sx * 0.35, 1.62, 0.95)], 0.03, PIPE, rad=0.08)
    P.append(S.box("Radiator", (0.5, 0.06, 0.35), (0, 0.72, 1.1), DK, 0.02))
    P.append(S.box("RearRack", (0.9, 0.35, 0.03), (0, 1.45, 1.05), DK, 0.008))
    for sx in (-0.3, 0.0, 0.3):
        P.append(S.box("Jerrycan", (0.14, 0.28, 0.34), (sx, 1.45, 1.23), SAND if sx == 0.0 else OL, 0.02))
    tube("Whip", (0.55, 0.9, 1.1), (0.6, 1.1, 3.0), 0.007, DK, 5)
    # Fahrwerk: Querlenker vorn, Längslenker hinten, Federbeine, Kotflügel
    for sx in (-1, 1):
        fx = sx * TW
        for dz in (-0.08, 0.1):
            tube("ArmA", (sx * 0.35, -WB - 0.18, 0.5 + dz), (fx - sx * 0.12, -WB, WR + dz * 0.6), 0.022, ST, 8)
            tube("ArmB", (sx * 0.35, -WB + 0.18, 0.5 + dz), (fx - sx * 0.12, -WB, WR + dz * 0.6), 0.022, ST, 8)
        coilover((sx * 0.4, -WB + 0.05, 1.05), (fx - sx * 0.14, -WB, WR + 0.05), 0.045)
        tube("Trailing", (sx * 0.45, 0.6, 0.5), (fx - sx * 0.14, WB, WR), 0.035, ST, 10)
        coilover((sx * 0.45, 0.85, 1.25), (fx - sx * 0.16, WB - 0.05, WR + 0.08), 0.05)
        P.append(S.box("FenderF", (0.32, 0.6, 0.025), (fx, -WB - 0.05, WR * 2 + 0.12), TP, 0.01, rot=(-0.1, 0, 0)))
        P.append(S.box("SidePanel", (0.03, 0.9, 0.28), (sx * 0.56, -0.15, FLOOR + 0.25), TP, 0.015))
    block_wheel("WheelFL", (-TW, -WB, WR), WR, 0.28, 0.22)
    block_wheel("WheelFR", (TW, -WB, WR), WR, 0.28, 0.22)
    block_wheel("WheelRL", (-TW, WB, WR + 0.02), WR + 0.02, 0.32, 0.22)
    block_wheel("WheelRR", (TW, WB, WR + 0.02), WR + 0.02, 0.32, 0.22)
    # Ringlafette hinter dem Hauptbügel (Rumpf): Pfosten und Plattform
    P.append(S.box("GunnerDeck", (0.8, 0.62, 0.04), (0, 0.75, 0.98), DK, 0.01))
    for sx in (-1, 1):
        tube("DeckPost", (sx * 0.3, 0.6, FLOOR), (sx * 0.3, 0.6, 0.98), 0.025, DK, 8)
        tube("RingPost", (sx * 0.44, 0.75, 0.98), (sx * 0.44, 0.75, 1.85), 0.022, DK, 8)
    tube("RingPost", (0, 1.19, 0.98), (0, 1.19, 1.85), 0.022, DK, 8)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.44, minor_radius=0.03, major_segments=32, minor_segments=8, location=(0, 0, 0))
    rg = bpy.context.active_object
    rg.name = "Ring"
    rg.location = (0, 0.75, 1.85)
    S._finish(rg, DK, 0.0, smooth=True)
    P.append(rg)

    # Fahrer
    lo, hi, _ = C.figure("west", "rider", pelvis=(-0.3, -0.02, FLOOR + 0.25),
                         feet={"L": (-0.2, -0.7, FLOOR + 0.12), "R": (-0.4, -0.7, FLOOR + 0.12)},
                         hands={"L": (-0.16, -0.58, 1.1), "R": (-0.44, -0.58, 1.1)},
                         pose={"spine": (-6, 0, 0), "chest": (4, 0, 0), "head": (2, 0, 0)}, foot_pitch=-10)
    P.extend(lo + hi)
    # Schütze steht im Ring, schwenkt mit dem schweren MG
    gp = (0, 0.75, 1.85)
    MG = []
    tube("CradlePost", (0, 0.31, 1.85), (0, 0.16, 2.06), 0.035, GUN, 10, MG)
    MG.append(S.box("Cradle", (0.12, 0.22, 0.1), (0, 0.12, 2.06), GUN, 0.015))
    MG.append(S.box("Receiver", (0.13, 0.42, 0.15), (0, 0.1, 2.16), GUN, 0.015))
    MG.append(S.box("FeedCover", (0.1, 0.3, 0.03), (0, 0.12, 2.25), GUN, 0.01))
    tube("Barrel", (0, -0.1, 2.17), (0, -1.2, 2.17), 0.022, GUN, 10, MG)
    tube("BarrelJacket", (0, -0.1, 2.17), (0, -0.42, 2.17), 0.04, GUN, 12, MG)
    tube("FlashHider", (0, -1.2, 2.17), (0, -1.3, 2.17), 0.032, GUN, 10, MG)
    MG.append(S.box("AmmoCan", (0.14, 0.26, 0.18), (-0.16, 0.12, 2.08), OL, 0.015))
    tube("AmmoBelt", (-0.1, 0.12, 2.15), (-0.065, 0.12, 2.2), 0.02, YE, 8, MG)
    MG.append(S.box("Shield", (0.62, 0.03, 0.4), (0, -0.2, 2.14), TP, 0.02, rot=(0.1, 0, 0)))
    for sx in (-1, 1):
        tube("Spade", (sx * 0.045, 0.3, 2.16), (sx * 0.065, 0.34, 2.1), 0.016, RB, 8, MG)
    lo, hi, pts = C.figure("west", "rider", pelvis=gp,
                           feet={"L": (0.12, 0.8, 1.05), "R": (-0.12, 0.82, 1.05)},
                           hands={"L": (0.07, 0.33, 2.12), "R": (-0.07, 0.33, 2.12)},
                           pose={"spine": (12, 0, 0), "chest": (8, 0, 0), "head": (-14, 0, 0)}, foot_pitch=0)
    T.extend(MG + lo + hi)
    turret = B.part("Turret", T, gp)
    S.bake(turret, 1024, os.path.join(B.root_dir, "models", "source", "textures"))
    mz = S.empty("Muzzle", (0, -1.32, 2.17), turret)
    extras.extend([turret, mz])
    finish_unit("dunebuggy", cam=(-5.6, -6.2, 3.6), tgt=(0, 0, 1.0))
