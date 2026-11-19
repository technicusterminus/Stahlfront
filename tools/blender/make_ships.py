"""Schiffe (Blender): Korvette, Kreuzer, Kanonenboot, Schlachtkreuzer, Kutter, Fregatte.

blender -b -P tools/blender/make_ships.py -- <projektordner> <corvette|cruiser|gunboat|battleship|skiff|frigate>
Ergebnis: models/units/<modell>.glb (vorne = -Y, Wasserlinie z 0). Bewegliche Teile: Turret, Barrel, Muzzle, Spin (Radar).
Flaggen, Besatzung, Rauch und Positionslichter setzt scripts/ships.gd (dress_custom) zur Laufzeit auf.
Die Maße sind in Godot-Koordinaten (vorne +Z, oben +Y) geschrieben und werden von den Hilfsfunktionen umgerechnet.
"""
import math, os, sys, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import sf_common as S
import sf_bld as B

which, P = B.setup(41)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH
TP = B.M("TeamPaint", (0.6, 0.62, 0.58), 0.35, 0.55, 0.5, 0.5)
OL = B.M("Olive", (0.25, 0.29, 0.2), 0.3, 0.7, 0.5, 0.7)
GLO = B.M("GlowOrange", (1.0, 0.55, 0.15), 0.0, 0.3, 0.0, 0.0, 7.0)
GLB = B.M("GlowBlue", (0.5, 0.8, 1.0), 0.0, 0.3, 0.0, 0.0, 5.0)
WHT = B.M("ShipWhite", (0.8, 0.84, 0.88), 0.5, 0.35, 0.45, 0.45)
DECKW = B.M("DeckWest", (0.2, 0.22, 0.25), 0.3, 0.7, 0.4, 0.5)
HULLR = B.M("HullRed", (0.34, 0.36, 0.34), 0.7, 0.5, 0.6, 0.6)
BANDR = B.M("BandRed", (0.5, 0.08, 0.06), 0.2, 0.6, 0.4, 0.5)
RUSTH = B.M("HullRust", (0.42, 0.22, 0.12), 0.4, 0.85, 0.8, 0.8)
DECKS = B.M("DeckShadow", (0.28, 0.2, 0.14), 0.0, 0.9, 0.3, 0.8)
BOARD = B.M("Board", (0.42, 0.3, 0.2), 0.0, 0.9, 0.3, 0.8)
PLATE = B.M("ShipPlate", (0.35, 0.37, 0.38), 0.5, 0.7, 0.6, 0.7)
BAND_DK = B.M("BandDark", (0.12, 0.1, 0.08), 0.0, 0.9, 0.2, 0.6)
CLOTH = B.M("ShipCloth", (0.3, 0.27, 0.2), 0.0, 0.95, 0.2, 0.6)
T = []
BR = []
SP = []
extras = []

# ---------------------------------------------------------------- Umrechnung Godot -> Blender
def _r(rot):
    return (rot[0], -rot[2], rot[1])

def bx(L, size, pos, mat, rot=(0, 0, 0), bevel=0.02):
    o = S.box("B", (size[0], size[2], size[1]), (pos[0], -pos[2], pos[1]), mat, bevel, rot=_r(rot))
    L.append(o)
    return o

def cy(L, rt, rb, h, pos, mat, rot=(0, 0, 0), seg=12):
    if abs(rt - rb) < 1e-6:
        o = S.cyl("C", rt, h, (pos[0], -pos[2], pos[1]), mat, seg, rot=_r(rot))
    else:
        o = S.cyl("C", rb, h, (pos[0], -pos[2], pos[1]), mat, seg, r2=rt, rot=_r(rot))
    L.append(o)
    return o

def sp(L, r, pos, mat, scl=(1, 1, 1)):
    o = S.sphere("S", r, (pos[0], -pos[2], pos[1]), mat, scale=(scl[0], scl[2], scl[1]), segs=14, rings=8)
    L.append(o)
    return o

def gp(pos):
    return (pos[0], -pos[2], pos[1])

# ---------------------------------------------------------------- Rumpf
def _prof(t, sharp):
    p = 1.0
    if t > 0.5:
        p = 1.0 - pow((t - 0.5) / 0.5, 1.7) * sharp
    sm = max(0.0, min(1.0, t / 0.3))
    return p * (0.88 + 0.12 * (sm * sm * (3 - 2 * sm)))

def hwd(L_, beam, t, sharp):
    return beam * 0.5 * _prof(t, sharp)

def deck_y(deck, t):
    return deck + 0.55 * pow(t, 3.0)

def hull(length, beam, deck, keel, side, deck_m, sharp=0.9, band=None):
    n = 16
    tops, bots = [], []
    for i in range(n + 1):
        t = i / n
        z = -length * 0.5 + t * length
        hw = hwd(length, beam, t, sharp)
        top = deck_y(deck, t)
        bot = -keel * (1.0 - 0.45 * pow(t, 4.0))
        tops.append(((-hw, top, z), (hw, top, z)))
        bots.append(((-hw * 0.5, bot, z), (hw * 0.5, bot, z)))
    verts, faces, mats = [], [], []
    def V(p):
        verts.append((p[0], -p[2], p[1]))
        return len(verts) - 1
    for i in range(n):
        a, b, c, d = tops[i], tops[i + 1], bots[i], bots[i + 1]
        ia = [V(a[0]), V(a[1]), V(c[0]), V(c[1])]
        ib = [V(b[0]), V(b[1]), V(d[0]), V(d[1])]
        faces.append((ib[1], ia[1], ia[3], ib[3])); mats.append(0)
        faces.append((ia[0], ib[0], ib[2], ia[2])); mats.append(0)
        faces.append((ib[2], ib[3], ia[3], ia[2])); mats.append(0)
        faces.append((ia[0], ia[1], ib[1], ib[0])); mats.append(1)
        if band is not None:
            def sx(ts, bs, y):
                f = max(0.0, min(1.0, (y - bs[1][1]) / (ts[1][1] - bs[1][1])))
                return bs[1][0] + (ts[1][0] - bs[1][0]) * f + 0.012
            x00, x01 = sx(a, c, -0.12), sx(a, c, 0.26)
            x10, x11 = sx(b, d, -0.12), sx(b, d, 0.26)
            z0, z1 = a[1][2], b[1][2]
            q = [V((x11, 0.26, z1)), V((x01, 0.26, z0)), V((x00, -0.12, z0)), V((x10, -0.12, z1))]
            faces.append(tuple(q)); mats.append(2)
            q = [V((-x01, 0.26, z0)), V((-x11, 0.26, z1)), V((-x10, -0.12, z1)), V((-x00, -0.12, z0))]
            faces.append(tuple(q)); mats.append(2)
    s0 = [V(tops[0][1]), V(tops[0][0]), V(bots[0][0]), V(bots[0][1])]
    faces.append(tuple(s0)); mats.append(0)
    s1 = [V(tops[n][0]), V(tops[n][1]), V(bots[n][1]), V(bots[n][0])]
    faces.append(tuple(s1)); mats.append(0)
    me = bpy.data.meshes.new("HullMesh")
    me.from_pydata(verts, [], faces)
    for mt in (side, deck_m, band if band is not None else side):
        me.materials.append(mt)
    for p, mi in zip(me.polygons, mats):
        p.material_index = mi
        p.use_smooth = True
    me.update()
    ob = bpy.data.objects.new("HullShape", me)
    S.scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    P.append(ob)
    return ob

def fit(length, beam, deck, sharp, ports=True, rivets=False):
    """Reling, Bullaugen, Nieten, Poller, Anker."""
    for sd in (-1.0, 1.0):
        prev = None
        z = -length * 0.40
        while z <= length * 0.38:
            t = (z + length * 0.5) / length
            hw = hwd(length, beam, t, sharp) * 0.93
            y = deck_y(deck, t)
            p = (sd * hw, y, z)
            bx(P, (0.025, 0.36, 0.025), (p[0], p[1] + 0.18, p[2]), ST, bevel=0.0)
            if prev is not None:
                for hh in (0.34, 0.17):
                    a = (prev[0], prev[1] + hh, prev[2])
                    b = (p[0], p[1] + hh, p[2])
                    ln = math.hypot(b[0] - a[0], b[2] - a[2])
                    yaw = math.atan2(b[0] - a[0], b[2] - a[2])
                    bx(P, (0.02, 0.02, ln), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2), ST, rot=(0, yaw, 0), bevel=0.0)
            prev = p
            z += 0.8
        zz = -length * 0.36
        while zz <= length * 0.28:
            t2 = (zz + length * 0.5) / length
            hw2 = hwd(length, beam, t2, sharp)
            if ports:
                sp(P, 0.07, (sd * (hw2 * 0.84 + 0.03), deck * 0.6, zz), LC if which in ("corvette", "cruiser") else LW)
            if rivets:
                for k in range(2):
                    sp(P, 0.028, (sd * (hw2 * 0.9 + 0.012), deck * 0.85, zz + 0.25 + k * 0.28), ST)
            zz += 0.95
        for pz in (-length * 0.42, length * 0.33):
            tp = (pz + length * 0.5) / length
            hp = hwd(length, beam, tp, sharp) * 0.8
            cy(P, 0.09, 0.11, 0.24, (sd * hp, deck_y(deck, tp) + 0.12, pz), DK, seg=8)
    bx(P, (0.1, 0.34, 0.18), (0.0, deck_y(deck, 0.93) + 0.17, length * 0.43), ST)
    cy(P, 0.05, 0.05, 0.5, (0.0, deck_y(deck, 0.93) + 0.1, length * 0.4), DK, rot=(math.pi / 2, 0, 0), seg=6)

def lifeboat(pos, col, side):
    mt = B.M("Lifeboat%s" % col.__hash__(), col, 0.1, 0.6, 0.3, 0.4)
    sp(P, 0.5, pos, mt, (0.9, 0.55, 2.4))
    bx(P, (0.7, 0.05, 1.7), (pos[0], pos[1] + 0.22, pos[2]), B.M("Seat", (0.9, 0.85, 0.7), 0.0, 0.8, 0.2, 0.4))
    for dz in (-0.6, 0.6):
        bx(P, (0.05, 0.9, 0.05), (pos[0] + side * 0.35, pos[1] + 0.15, pos[2] + dz), ST, bevel=0.0)
        bx(P, (0.4, 0.05, 0.05), (pos[0] + side * 0.17, pos[1] + 0.62, pos[2] + dz), ST, bevel=0.0)

def deckbox(pos, rot, col):
    bx(P, (0.45, 0.34, 0.45), (pos[0], pos[1] + 0.17, pos[2]), B.M("DeckBox%s" % col.__hash__(), col, 0.2, 0.7, 0.4, 0.5), rot=(0, rot, 0))
    cy(P, 0.12, 0.12, 0.05, (pos[0], pos[1] + 0.36, pos[2]), DK, seg=8)

def hatch(pos, rr=0.3):
    cy(P, rr, rr, 0.06, (pos[0], pos[1] + 0.03, pos[2]), ST, seg=10)
    bx(P, (rr * 1.4, 0.04, 0.05), (pos[0], pos[1] + 0.08, pos[2]), DK)

def vent(pos):
    cy(P, 0.1, 0.1, 0.4, (pos[0], pos[1] + 0.2, pos[2]), DK, seg=8)
    sp(P, 0.17, (pos[0], pos[1] + 0.45, pos[2]), DK, (1, 0.6, 1))

def radar(pos, s):
    """Drehbares Radar als eigenes Teil (Spin)."""
    L = []
    cy(L, 0.05, 0.07, 0.25 * s, (pos[0], pos[1] + 0.12 * s, pos[2]), ST, seg=6)
    bx(L, (1.1 * s, 0.14 * s, 0.05), (pos[0], pos[1] + 0.3 * s, pos[2]), DK)
    bx(L, (1.0 * s, 0.05, 0.09), (pos[0], pos[1] + 0.38 * s, pos[2]), ST)
    o = B.part("Spin", L, gp(pos))
    extras.append(o)

def finish_unit(name, cam=(-12, -14, 8), tgt=(0, 0, 1.5)):
    hullo = P[0]
    S.join_into(hullo, P[1:])
    hullo.name = "Hull"
    root = B.root_dir
    tex = os.path.join(root, "models", "source", "textures")
    S.bake(hullo, 1024, tex)
    objs = [hullo] + list(extras)
    os.makedirs(os.path.join(root, "models", "units"), exist_ok=True)
    S.export(os.path.join(root, "models", "units", "%s.glb" % name), objs)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root, "models", "source", "%s.blend" % name))
    S.preview(os.path.join(root, "shots", "%s_preview.png" % name), target=tgt, cam_loc=cam, lens=48, ground=(0.1, 0.2, 0.3))
    print("SHIP_OK", name)

def turret_parts(pivot_g, barrel_pivot_g, muzzle_g):
    turret = B.part("Turret", T, gp(pivot_g))
    parts = [turret]
    if BR:
        barrel = B.part("Barrel", BR, gp(barrel_pivot_g), parent=turret)
        parts.append(barrel)
    mz = S.empty("Muzzle", gp(muzzle_g), turret)
    parts.append(mz)
    extras.extend(parts)

# ---------------------------------------------------------------- Schiffe

if which == "corvette":
    hull(9.6, 2.7, 1.0, 0.85, WHT, DECKW, 0.88, TP)
    for sx in (-1.0, 1.0):
        bx(P, (0.04, 0.06, 6.0), (sx * 1.28, 0.55, 0.0), LC, bevel=0.0)
    fit(9.6, 2.7, 1.0, 0.88)
    bx(P, (1.8, 0.7, 2.4), (0, 1.4, -1.0), WHT)
    bx(P, (1.72, 0.42, 2.0), (0, 1.58, -0.9), GLS, bevel=0.0)
    for k in range(4):
        bx(P, (0.05, 0.5, 0.05), (-0.8 + k * 0.53, 1.58, 0.1), WHT, bevel=0.0)
    bx(P, (1.4, 0.2, 2.1), (0, 1.9, -1.0), TP)
    radar((0, 2.0, -1.5), 1.0)
    for sx in (-1.0, 1.0):
        cy(P, 0.03, 0.03, 0.8, (sx * 0.6, 2.4, -1.9), DK, seg=4)
    sp(P, 0.32, (0, 1.3, -3.6), GLB)
    for k in range(2):
        cy(P, 0.4 + k * 0.1, 0.4 + k * 0.1, 0.03, (0, 1.05 + k * 0.15, -3.6), GLB, seg=14)
    cy(P, 0.12, 0.2, 0.4, (0, 1.0, -3.6), ST, seg=8)
    cy(P, 0.28, 0.28, 0.5, (0.7, 1.35, -2.8), B.M("Raft", (1.0, 0.5, 0.1), 0.0, 0.7, 0.2, 0.3), rot=(0, 0, math.pi / 2), seg=10)
    deckbox((-0.7, 1.0, -2.9), 0.3, Color := (0.55, 0.6, 0.65))
    vent((-0.6, 1.0, 0.9))
    cy(T, 0.5, 0.55, 0.35, (0, 1.2, 2.6), TP, seg=12)
    sp(T, 0.06, (0.45, 1.45, 2.4), LR)
    for sx in (-0.28, 0.28):
        bx(BR, (0.42, 0.4, 1.5), (sx, 1.55 + 0.17, 2.6 + 0.47), DK, rot=(-0.35, 0, 0))
        bx(BR, (0.46, 0.05, 1.4), (sx, 1.55 + 0.38, 2.6 + 0.43), WHT, rot=(-0.35, 0, 0))
        sp(BR, 0.1, (sx, 1.55 + 0.2, 2.6 + 1.25), GLB)
    turret_parts((0, 1.1, 2.6), (0, 1.55, 2.6), (0, 1.85, 4.1))
    finish_unit("corvette", cam=(-10, -12, 7), tgt=(0, 0, 1.2))

elif which == "cruiser":
    hull(14.0, 3.9, 1.1, 0.95, WHT, DECKW, 0.86, TP)
    for sx in (-1.0, 1.0):
        bx(P, (0.04, 0.06, 10.0), (sx * 1.9, 0.6, 0.0), LC, bevel=0.0)
    fit(14.0, 3.9, 1.1, 0.86)
    bx(P, (2.4, 0.05, 3.9), (0, 1.15, 3.3), DK)
    for gx in range(3):
        for gz in range(5):
            bx(P, (0.5, 0.06, 0.5), (-0.7 + gx * 0.7, 1.19 + 0.02 * gz, 2.0 + gz * 0.65), ST)
            sp(P, 0.05, (-0.7 + gx * 0.7, 1.25 + 0.02 * gz, 2.0 + gz * 0.65), LC)
    bx(P, (2.4, 1.0, 3.0), (0, 1.7, -1.4), WHT)
    bx(P, (2.2, 0.5, 2.7), (0, 2.35, -1.3), GLS, bevel=0.0)
    for k in range(6):
        bx(P, (0.05, 0.55, 2.74), (-1.0 + k * 0.4, 2.35, -1.3), WHT, bevel=0.0)
    bx(P, (1.9, 0.9, 1.8), (0, 2.9, -1.4), WHT)
    bx(P, (1.8, 0.4, 1.5), (0, 3.0, -1.3), GLS, bevel=0.0)
    bx(P, (2.0, 0.14, 2.0), (0, 3.42, -1.4), TP)
    radar((0, 3.5, -1.9), 1.5)
    cy(P, 0.1, 0.12, 1.8, (0, 4.3, -0.9), ST, seg=6)
    sp(P, 0.35, (0, 5.2, -0.9), WHT, (1, 0.8, 1))
    cy(P, 1.5, 1.5, 0.05, (0, 1.17, -5.0), DECKW, seg=24)
    cy(P, 1.25, 1.25, 0.03, (0, 1.2, -5.0), WH, seg=24)
    for dx in (-0.3, 0.3):
        bx(P, (0.14, 0.02, 0.9), (dx, 1.24, -5.0), DK, bevel=0.0)
    bx(P, (0.74, 0.02, 0.14), (0, 1.24, -5.0), DK, bevel=0.0)
    for i in range(8):
        a = math.tau * i / 8.0
        sp(P, 0.06, (math.cos(a) * 1.4, 1.22, -5.0 + math.sin(a) * 1.4), LC)
    bx(P, (2.4, 1.0, 1.2), (0, 1.65, -3.5), WHT)
    bx(P, (2.0, 0.7, 0.05), (0, 1.6, -2.88), DK, bevel=0.0)
    for sx in (-1.0, 1.0):
        cy(P, 0.06, 0.1, 1.2, (sx * 1.5, 1.6, -3.2), ST, seg=6)
        sp(P, 0.2, (sx * 1.5, 2.25, -3.2), GLB)
        lifeboat((sx * 1.55, 1.45, 0.3), (1.0, 0.55, 0.12), -sx)
    hatch((0.9, 1.1, 1.0))
    vent((-0.9, 1.1, 0.8))
    cy(T, 0.7, 0.8, 0.4, (0, 1.35, 4.2), TP, seg=14)
    sp(T, 0.07, (0.65, 1.65, 3.9), LR)
    for sx in (-0.3, 0.3):
        bx(BR, (0.5, 0.5, 2.0), (sx, 1.65 + 0.1, 4.2 + 0.6), DK, rot=(-0.45, 0, 0))
        bx(BR, (0.54, 0.05, 1.9), (sx, 1.65 + 0.36, 4.2 + 0.55), WHT, rot=(-0.45, 0, 0))
        sp(BR, 0.14, (sx, 1.65 + 0.55, 4.2 + 1.5), GLB)
    turret_parts((0, 1.15, 4.2), (0, 1.65, 4.2), (0, 2.65, 6.0))
    finish_unit("cruiser", cam=(-14, -16, 9), tgt=(0, 0, 1.8))

elif which == "gunboat":
    hull(8.6, 2.9, 1.0, 0.8, HULLR, BAND_DK, 0.8, BANDR)
    fit(8.6, 2.9, 1.0, 0.8, ports=True, rivets=True)
    bx(P, (1.9, 1.0, 2.2), (0, 1.5, -1.0), TP)
    bx(P, (1.7, 0.3, 0.05), (0, 1.75, 0.12), GLS, bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.05, 0.3, 1.2), (sx * 0.96, 1.75, -0.8), GLS, bevel=0.0)
    bx(P, (2.1, 0.12, 2.4), (0, 2.05, -1.0), DK)
    cy(P, 0.4, 0.46, 1.4, (0, 2.0, -2.6), DK, seg=12)
    cy(P, 0.42, 0.42, 0.2, (0, 2.6, -2.6), BANDR, seg=12)
    radar((0, 2.1, -0.5), 0.8)
    for sx in (-1.0, 1.0):
        cy(P, 0.28, 0.28, 0.07, (sx * 1.35, 1.1, -2.2), WH, rot=(0, 0, math.pi / 2), seg=12)
    lifeboat((1.0, 1.1, -2.9), (0.75, 0.2, 0.12), -1.0)
    deckbox((-0.95, 1.0, -2.4), 0.2, (0.3, 0.34, 0.24))
    hatch((0.5, 1.0, 1.0))
    cy(T, 0.62, 0.7, 0.55, (0, 1.38, 2.3), TP, seg=12)
    bx(T, (0.9, 0.5, 0.8), (0, 1.5, 2.6), TP, rot=(-0.2, 0, 0))
    bx(T, (0.12, 0.5, 0.5), (0.48, 1.6, 2.4), DK)
    cy(BR, 0.09, 0.11, 2.2, (0, 1.55, 3.8), ST, rot=(math.pi / 2, 0, 0), seg=10)
    cy(BR, 0.14, 0.14, 0.3, (0, 1.55, 4.9), DK, rot=(math.pi / 2, 0, 0), seg=10)
    turret_parts((0, 1.1, 2.3), (0, 1.55, 2.3), (0, 1.55, 5.1))
    finish_unit("gunboat", cam=(-9, -11, 7), tgt=(0, 0, 1.2))

elif which == "battleship":
    hull(14.6, 4.6, 1.3, 1.0, HULLR, BAND_DK, 0.84, BANDR)
    fit(14.6, 4.6, 1.3, 0.84, ports=True, rivets=True)
    bx(P, (3.0, 1.2, 3.6), (0, 2.0, -0.6), TP)
    bx(P, (3.05, 0.1, 3.65), (0, 2.6, -0.6), DK)
    bx(P, (2.6, 0.9, 2.6), (0, 3.05, -0.6), TP)
    bx(P, (2.5, 0.3, 0.05), (0, 3.2, 0.72), GLS, bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.05, 0.3, 1.8), (sx * 1.3, 3.2, -0.6), GLS, bevel=0.0)
    bx(P, (2.0, 0.7, 1.7), (0, 3.85, -0.6), TP)
    bx(P, (2.2, 0.12, 1.9), (0, 4.25, -0.6), DK)
    for k in range(2):
        cy(P, 0.55, 0.65, 2.0, (0, 2.7, -2.8 - k * 1.5), DK, seg=12)
        cy(P, 0.58, 0.58, 0.24, (0, 3.62, -2.8 - k * 1.5), BANDR, seg=12)
        cy(P, 0.5, 0.5, 0.08, (0, 3.76, -2.8 - k * 1.5), TP, seg=12)
    radar((0, 4.35, -0.9), 1.5)
    cy(P, 0.06, 0.08, 2.0, (0, 5.3, -0.2), DK, seg=6)
    for sx in (-1.0, 1.0):
        cy(P, 0.12, 0.14, 0.5, (sx * 1.9, 1.55, 1.8), ST, seg=6)
        for k in range(2):
            cy(P, 0.04, 0.04, 0.9, (sx * 1.9 + (k - 0.5) * 0.18, 2.0, 2.1), DK, rot=(math.pi / 2 - 0.5, 0, 0), seg=6)
        lifeboat((sx * 1.95, 1.8, -1.0), (0.75, 0.2, 0.12), -sx)
        lifeboat((sx * 1.95, 1.8, -2.8), (0.75, 0.2, 0.12), -sx)
    for k in range(3):
        hatch((-0.9 + k * 0.9, 1.3, -6.0))
    vent((1.4, 1.3, -4.6))
    vent((-1.4, 1.3, -4.9))
    # zwei Doppelgeschütze vorn (vorderstes drehbar), eines achtern als feste Deko
    for cz, cyy, rotate in ((2.7, 1.9, False), (-5.0, 1.45, True)):
        cy(P, 0.9, 1.0, 0.45, (0, cyy + 0.22, cz), TP, seg=14)
        bx(P, (1.5, 0.55, 1.5), (0, cyy + 0.55, cz + 0.1), TP, rot=(-0.1, 0, 0))
        bx(P, (1.4, 0.1, 1.2), (0, cyy + 0.88, cz - 0.1), DK)
        for sx in (-0.34, 0.34):
            zz = -1.0 if rotate else 1.0
            cy(P, 0.1, 0.12, 2.8, (sx, cyy + 0.55, cz + zz * 1.9), ST, rot=(math.pi / 2, 0, 0), seg=10)
            cy(P, 0.15, 0.15, 0.3, (sx, cyy + 0.55, cz + zz * 3.3), DK, rot=(math.pi / 2, 0, 0), seg=10)
    cy(T, 0.9, 1.0, 0.45, (0, 1.67, 4.9), TP, seg=14)
    bx(T, (1.5, 0.55, 1.5), (0, 2.0, 5.0), TP, rot=(-0.1, 0, 0))
    bx(T, (1.4, 0.1, 1.2), (0, 2.33, 4.8), DK)
    for sx in (-0.8, 0.8):
        bx(T, (0.05, 0.4, 1.2), (sx, 1.95, 4.9), ST)
    for sx in (-0.34, 0.34):
        cy(BR, 0.1, 0.12, 2.8, (sx, 2.0, 6.8), ST, rot=(math.pi / 2, 0, 0), seg=10)
        cy(BR, 0.15, 0.15, 0.3, (sx, 2.0, 8.2), DK, rot=(math.pi / 2, 0, 0), seg=10)
    turret_parts((0, 1.45, 4.9), (0, 2.0, 4.9), (0, 2.0, 8.45))
    finish_unit("battleship", cam=(-15, -17, 10), tgt=(0, 0, 2.0))

elif which == "skiff":
    hull(6.3, 2.2, 0.55, 0.5, RUSTH, BOARD, 0.75, BAND_DK)
    fit(6.3, 2.2, 0.55, 0.75, ports=False, rivets=True)
    for sx in (-1.0, 1.0):
        bx(P, (0.08, 0.3, 4.2), (sx * 0.95, 0.8, -0.4), BOARD, rot=(0, 0, sx * 0.04))
        bx(P, (0.1, 0.22, 0.7), (sx * 0.97, 0.85, 0.3), RS, rot=(0, 0, sx * 0.04))
    for k in range(3):
        bx(P, (1.9, 0.07, 0.12), (0, 0.62, -2.6 + k * 1.3), BOARD)
    bx(P, (0.4, 0.55, 0.5), (0, 0.8, -3.3), DK)
    bx(P, (0.24, 0.1, 0.5), (0, 1.12, -3.25), BANDR)
    cy(P, 0.04, 0.05, 0.9, (0, 0.3, -3.5), ST, seg=6)
    cy(P, 0.2, 0.2, 0.04, (0, -0.15, -3.55), ST, rot=(0, 0, math.pi / 2), seg=8)
    bx(P, (1.6, 0.5, 1.5), (0, 0.95, -1.5), CLOTH)
    bx(P, (1.7, 0.06, 0.1), (0, 1.22, -1.5), DK)
    bx(P, (0.5, 0.35, 0.5), (0.55, 0.78, -0.2), B.M("Crate2", (0.5, 0.45, 0.3), 0.0, 0.9, 0.3, 0.6), rot=(0, 0.3, 0))
    for k in range(2):
        cy(P, 0.14, 0.14, 0.4, (-0.5 + k * 0.3, 0.78, -0.3), B.M("Jerry2", (0.55, 0.3, 0.12), 0.3, 0.7, 0.4, 0.6), seg=8)
    sp(P, 0.4, (0.35, 0.5, 0.4), B.M("Net", (0.35, 0.35, 0.3), 0.0, 0.95, 0.2, 0.6), (1.3, 0.5, 1.0))
    for k in range(3):
        cy(P, 0.2, 0.2, 0.2, (1.05, 0.2, 1.2 - k * 1.1), RB, rot=(0, 0, math.pi / 2), seg=10)
    cy(T, 0.06, 0.06, 0.5, (0, 0.95, 1.4), DK, seg=6)
    bx(T, (0.3, 0.26, 0.5), (0, 1.3, 1.4), DK)
    bx(T, (0.36, 0.34, 0.08), (0, 1.35, 1.7), ST)
    bx(T, (0.24, 0.2, 0.3), (0.27, 1.25, 1.35), OL)
    cy(BR, 0.04, 0.04, 1.0, (0, 1.3, 2.2), DK, rot=(math.pi / 2, 0, 0), seg=6)
    turret_parts((0, 1.0, 1.4), (0, 1.3, 1.4), (0, 1.3, 2.75))
    finish_unit("skiff", cam=(-8, -9, 5), tgt=(0, 0, 0.6))

elif which == "frigate":
    hull(11.8, 3.5, 1.0, 0.85, RUSTH, DECKS, 0.82, BAND_DK)
    fit(11.8, 3.5, 1.0, 0.82, ports=False, rivets=True)
    for k in range(5):
        sz = -4.0 + k * 2.0
        for sx in (-1.0, 1.0):
            bx(P, (0.05, 0.5, 0.9), (sx * (1.36 - 0.03 * (k % 2)), 0.45, sz + (k % 3) * 0.1), PLATE if k % 2 == 0 else BANDR)
            cy(P, 0.3, 0.3, 0.22, (sx * 1.42, 0.2, sz + 1.0), RB, rot=(0, 0, math.pi / 2), seg=12)
            cy(P, 0.15, 0.15, 0.24, (sx * 1.42, 0.2, sz + 1.0), DK, rot=(0, 0, math.pi / 2), seg=8)
    cols = [(0.45, 0.2, 0.12), (0.2, 0.3, 0.38), (0.32, 0.38, 0.2), (0.5, 0.36, 0.14)]
    for row in range(2):
        for lvl in range(2 if row == 0 else 1):
            cx = -0.75 + row * 1.5
            cyc = 1.4 + lvl * 0.82
            cm = B.M("FrigCont%d" % ((row * 2 + lvl) % 4), cols[(row * 2 + lvl) % 4], 0.3, 0.8, 0.7, 0.7)
            bx(P, (1.0, 0.8, 2.2), (cx, cyc, -1.2 + lvl * 0.15), cm, rot=(0, 0.03 * lvl, 0))
            bx(P, (0.9, 0.7, 0.04), (cx, cyc, -0.08 + lvl * 0.15), DK, bevel=0.0)
    bx(P, (2.9, 0.1, 2.5), (0.1, 2.9, -1.1), DECKS, rot=(0, 0.1, 0.08))
    bx(P, (1.8, 1.1, 1.6), (0, 1.55, -3.5), PLATE)
    bx(P, (1.6, 0.18, 0.05), (0, 1.85, -2.68), GLO, bevel=0.0)
    bx(P, (2.0, 0.1, 1.8), (0, 2.15, -3.5), RUSTH)
    cy(P, 0.18, 0.2, 1.0, (0.6, 2.7, -4.0), RUSTH, seg=8)
    cy(P, 0.14, 0.16, 0.7, (-0.5, 2.5, -4.1), PLATE, seg=8)
    cy(P, 0.07, 0.09, 2.4, (-1.3, 2.2, 1.4), DK, seg=6)
    bx(P, (0.08, 0.08, 2.0), (-1.3, 3.3, 2.1), DK, rot=(0.2, 0, 0), bevel=0.0)
    cy(P, 0.2, 0.2, 0.3, (-1.3, 1.2, 1.1), B.M("Winch", (0.4, 0.35, 0.3), 0.4, 0.7, 0.5, 0.6), rot=(0, 0, math.pi / 2), seg=10)
    deckbox((1.2, 1.0, 2.3), 0.4, (0.4, 0.3, 0.18))
    cy(T, 0.6, 0.7, 0.3, (0, 1.15, 3.0), PLATE, seg=10)
    for sx in (-0.4, 0.0, 0.4):
        for sy in (0.0, 0.34):
            cy(BR, 0.13, 0.13, 1.5, (sx, 1.45 + sy, 3.7), B.M("RackTube", (0.3, 0.32, 0.3), 0.4, 0.7, 0.5, 0.6), rot=(math.pi / 2 - 0.3, 0, 0), seg=8)
            cy(BR, 0.0, 0.09, 0.3, (sx, 1.65 + sy, 4.45), RS, rot=(math.pi / 2 - 0.3, 0, 0), seg=8)
    bx(BR, (1.4, 0.05, 0.06), (0, 1.65, 3.2), DK, bevel=0.0)
    turret_parts((0, 1.0, 3.0), (0, 1.45, 3.0), (0, 1.9, 4.5))
    finish_unit("frigate", cam=(-12, -14, 8), tgt=(0, 0, 1.5))
