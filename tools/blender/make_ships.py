"""Schiffe (Blender): Korvette, Kreuzer, Kanonenboot, Schlachtkreuzer, Kutter, Fregatte.

blender -b -P tools/blender/make_ships.py -- <projektordner> <corvette|cruiser|gunboat|battleship|skiff|frigate>
Ergebnis: models/units/<modell>.glb (vorne = -Y, Wasserlinie z 0). Bewegliche Teile: Turret, Barrel, Muzzle, Spin (Radar).
Flaggen, Besatzung, Rauch und Positionslichter setzt scripts/ships.gd (dress_custom) zur Laufzeit auf.
Die Maße sind in Godot-Koordinaten (vorne +Z, oben +Y) geschrieben und werden von den Hilfsfunktionen umgerechnet.

Stile:  Westbund = glatt, weiß, geneigte Flächen, Radome, Hubschrauberdeck, Senkrechtstartzellen
        Rote Allianz = massig, grau, genietet, runde Türme, hohe Schlote, rote Wasserlinie
        Schattenfront = zusammengeschweißt: Rost, Schrottplatten, Planen, Container, Reifen
"""
import math, os, sys, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import sf_common as S
import sf_bld as B

which, P = B.setup(41)
random.seed(7)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH
TP = B.M("TeamPaint", (0.6, 0.62, 0.58), 0.35, 0.55, 0.5, 0.5)
OL = B.M("Olive", (0.25, 0.29, 0.2), 0.3, 0.7, 0.5, 0.7)
GLO = B.M("GlowOrange", (1.0, 0.55, 0.15), 0.0, 0.3, 0.0, 0.0, 7.0)
GLB = B.M("GlowBlue", (0.5, 0.8, 1.0), 0.0, 0.3, 0.0, 0.0, 5.0)
WHT = B.M("ShipWhite", (0.84, 0.87, 0.9), 0.35, 0.3, 0.4, 0.4)
WHT2 = B.M("ShipWhite2", (0.7, 0.74, 0.78), 0.4, 0.35, 0.4, 0.4)
DECKW = B.M("DeckWest", (0.2, 0.22, 0.25), 0.3, 0.7, 0.4, 0.5)
HULLR = B.M("HullRed", (0.32, 0.34, 0.33), 0.7, 0.5, 0.6, 0.6)
HULLR2 = B.M("HullRedLight", (0.42, 0.44, 0.42), 0.6, 0.5, 0.6, 0.6)
BANDR = B.M("BandRed", (0.5, 0.08, 0.06), 0.2, 0.6, 0.4, 0.5)
RUSTH = B.M("HullRust", (0.42, 0.22, 0.12), 0.4, 0.85, 0.8, 0.8)
RUST2 = B.M("RustPatch", (0.3, 0.3, 0.28), 0.5, 0.8, 0.8, 0.8)
RUST3 = B.M("RustBlue", (0.2, 0.3, 0.38), 0.4, 0.8, 0.7, 0.8)
DECKS = B.M("DeckShadow", (0.28, 0.2, 0.14), 0.0, 0.9, 0.3, 0.8)
BOARD = B.M("Board", (0.42, 0.3, 0.2), 0.0, 0.9, 0.3, 0.8)
PLATE = B.M("ShipPlate", (0.35, 0.37, 0.38), 0.5, 0.7, 0.6, 0.7)
BAND_DK = B.M("BandDark", (0.12, 0.1, 0.08), 0.0, 0.9, 0.2, 0.6)
CLOTH = B.M("ShipCloth", (0.3, 0.27, 0.2), 0.0, 0.95, 0.2, 0.6)
ORANGE = B.M("LifeOrange", (1.0, 0.45, 0.1), 0.0, 0.6, 0.3, 0.4)
RINGM = B.M("PadRing", (0.85, 0.85, 0.8), 0.0, 0.6, 0.3, 0.5)
T = []
BR = []
extras = []
HL, HD, HB, HS, KEEL = 10.0, 1.0, 2.7, 0.9, 0.8   # Rumpflänge, Deckhöhe, Breite, Spitze, Kiel (für dk()/sidex())


def _r(rot):
    return (rot[0], -rot[2], rot[1])


def bx(L, size, pos, mat, rot=(0, 0, 0), bevel=0.02):
    o = S.box("B", (size[0], size[2], size[1]), (pos[0], -pos[2], pos[1]), mat, bevel, rot=_r(rot))
    L.append(o)
    return o


def rbx(L, size, pos, mat, rot=(0, 0, 0), r=0.12):
    """Weich gerundeter Quader."""
    return bx(L, size, pos, mat, rot, bevel=min(r, min(size) * 0.45))


def cy(L, rt, rb, h, pos, mat, rot=(0, 0, 0), seg=14):
    if abs(rt - rb) < 1e-6:
        o = S.cyl("C", rt, h, (pos[0], -pos[2], pos[1]), mat, seg, rot=_r(rot))
    else:
        o = S.cyl("C", rb, h, (pos[0], -pos[2], pos[1]), mat, seg, r2=rt, rot=_r(rot))
    L.append(o)
    return o


def sp(L, r, pos, mat, scl=(1, 1, 1)):
    o = S.sphere("S", r, (pos[0], -pos[2], pos[1]), mat, scale=(scl[0], scl[2], scl[1]), segs=16, rings=10)
    L.append(o)
    return o


def gp(pos):
    return (pos[0], -pos[2], pos[1])


def sb(L, prof, halfw, mat, x=0.0, bevel=0.1):
    """Seitenprofil (z, y in Godot-Maßen) quer zur Fahrtrichtung ausgezogen, Breite 2*halfw."""
    pts = [(-gz, gy) for gz, gy in prof]
    o = S.prism_xz("SB", pts, halfw * 2.0, (x, 0, 0), mat, bevel, rot=(0, 0, math.pi / 2))
    L.append(o)
    return o


def dk(z):
    t = max(0.0, min(1.0, (z + HL * 0.5) / HL))
    return HD + 0.55 * min(1.0, HD) * pow(t, 3.0)


# ---------------------------------------------------------------- Rumpf
def _prof(t, sharp):
    p = 1.0
    if t > 0.5:
        p = 1.0 - pow((t - 0.5) / 0.5, 1.7) * sharp
    sm = max(0.0, min(1.0, t / 0.3))
    return p * (0.88 + 0.12 * (sm * sm * (3 - 2 * sm)))


def hwd(t):
    return HB * 0.5 * _prof(t, HS)


def sidex(t, y, keel=None):
    keel = KEEL if keel is None else keel
    hw = hwd(t)
    top = dk(-HL * 0.5 + t * HL)
    u = max(0.0, min(1.0, (y + keel) / (top + keel)))
    return hw * (0.38 + 0.62 * math.sqrt(max(0.0, 1.0 - (1.0 - u) ** 2 * 0.92)))


def hull(length, beam, deck, keel, side, deck_m, sharp=0.9, band=None):
    global HL, HD, HB, HS, KEEL
    HL, HD, HB, HS, KEEL = length, deck, beam, sharp, keel
    n = 22
    idx = []
    verts, faces, mats = [], [], []
    for i in range(n + 1):
        t = i / n
        z = -length * 0.5 + t * length
        top = dk(z)
        bot = -keel * (1.0 - 0.45 * pow(t, 4.0))
        ys = [top, 0.26, -0.12, bot * 0.45, bot]
        pts = [(-sidex(t, y), y, z) for y in ys] + [(sidex(t, y), y, z) for y in reversed(ys)]
        row = []
        for p in pts:
            verts.append((p[0], -p[2], p[1]))
            row.append(len(verts) - 1)
        idx.append(row)
    k = len(idx[0])
    for i in range(n):
        for j in range(k):
            j2 = (j + 1) % k
            faces.append((idx[i][j], idx[i + 1][j], idx[i + 1][j2], idx[i][j2]))
            if j == k - 1:
                mats.append(1)
            elif band is not None and j in (1, k - 3):
                mats.append(2)
            else:
                mats.append(0)
    faces.append(tuple(idx[0]))
    mats.append(0)
    faces.append(tuple(reversed(idx[n])))
    mats.append(0)
    me = bpy.data.meshes.new("HullMesh")
    me.from_pydata(verts, [], faces)
    for mt in (side, deck_m, band if band is not None else side):
        me.materials.append(mt)
    for p, mi in zip(me.polygons, mats):
        p.material_index = mi
        p.use_smooth = (mi != 1)
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


def fit(ports=True, rivets=False, rail=True, port_mat=None, bulwark=False):
    """Reling bzw. Schanzkleid, Bullaugen, Nieten, Poller, Anker, Ankerklüsen."""
    length = HL
    for sd in (-1.0, 1.0):
        prev = None
        z = -length * 0.40
        while z <= length * 0.38 and rail:
            t = (z + length * 0.5) / length
            hw = sidex(t, dk(z)) * 0.95
            y = dk(z)
            p = (sd * hw, y, z)
            if bulwark:
                if prev is not None:
                    ln = math.hypot(p[0] - prev[0], p[2] - prev[2]) + 0.02
                    yaw = math.atan2(p[0] - prev[0], p[2] - prev[2])
                    bx(P, (0.05, 0.38, ln), ((p[0] + prev[0]) / 2, y + 0.19, (p[2] + prev[2]) / 2), PLATE, rot=(0, yaw, 0), bevel=0.01)
            else:
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
            if ports:
                sp(P, 0.07, (sd * (sidex(t2, HD * 0.6) + 0.01), HD * 0.6, zz), port_mat or LC)
            if rivets:
                for kk in range(2):
                    sp(P, 0.028, (sd * (sidex(t2, HD * 0.85) + 0.005), HD * 0.85, zz + 0.25 + kk * 0.28), ST)
            zz += 0.95
        for pz in (-length * 0.42, length * 0.33):
            tp = (pz + length * 0.5) / length
            hp = sidex(tp, dk(pz)) * 0.8
            cy(P, 0.09, 0.11, 0.24, (sd * hp, dk(pz) + 0.12, pz), DK, seg=8)
        zb = length * 0.4
        tb = (zb + length * 0.5) / length
        sp(P, 0.1, (sd * (sidex(tb, dk(zb) - 0.2) + 0.02), dk(zb) - 0.2, zb), DK)
    ab = length * 0.43
    bx(P, (0.1, 0.34, 0.18), (0.0, dk(ab) + 0.17, ab), ST)
    cy(P, 0.05, 0.05, 0.5, (0.0, dk(length * 0.4) + 0.1, length * 0.4), DK, rot=(math.pi / 2, 0, 0), seg=6)
    cy(P, 0.17, 0.17, 0.18, (0.0, dk(length * 0.36) + 0.1, length * 0.36), DK, seg=10)


def lifeboat(pos, col, side):
    mt = B.M("Lifeboat%s" % col.__hash__(), col, 0.1, 0.6, 0.3, 0.4)
    sp(P, 0.5, pos, mt, (0.9, 0.55, 2.4))
    bx(P, (0.7, 0.05, 1.7), (pos[0], pos[1] + 0.22, pos[2]), B.M("Seat", (0.9, 0.85, 0.7), 0.0, 0.8, 0.2, 0.4))
    for dz in (-0.6, 0.6):
        bx(P, (0.05, 0.9, 0.05), (pos[0] + side * 0.35, pos[1] + 0.15, pos[2] + dz), ST, bevel=0.0)
        bx(P, (0.4, 0.05, 0.05), (pos[0] + side * 0.17, pos[1] + 0.62, pos[2] + dz), ST, bevel=0.0)


def deckbox(pos, rot, col):
    rbx(P, (0.45, 0.34, 0.45), (pos[0], pos[1] + 0.17, pos[2]), B.M("DeckBox%s" % col.__hash__(), col, 0.2, 0.7, 0.4, 0.5), rot=(0, rot, 0), r=0.05)
    cy(P, 0.12, 0.12, 0.05, (pos[0], pos[1] + 0.36, pos[2]), DK, seg=8)


def hatch(pos, rr=0.3):
    cy(P, rr, rr, 0.06, (pos[0], pos[1] + 0.03, pos[2]), ST, seg=12)
    bx(P, (rr * 1.4, 0.04, 0.05), (pos[0], pos[1] + 0.08, pos[2]), DK)


def vent(pos):
    cy(P, 0.1, 0.1, 0.4, (pos[0], pos[1] + 0.2, pos[2]), DK, seg=10)
    sp(P, 0.17, (pos[0], pos[1] + 0.45, pos[2]), DK, (1, 0.6, 1))


def radar(pos, s):
    """Drehbares Radar als eigenes Teil (Spin)."""
    L = []
    cy(L, 0.05, 0.07, 0.25 * s, (pos[0], pos[1] + 0.12 * s, pos[2]), ST, seg=8)
    rbx(L, (1.1 * s, 0.14 * s, 0.05), (pos[0], pos[1] + 0.3 * s, pos[2]), DK, r=0.02)
    bx(L, (1.0 * s, 0.05, 0.09), (pos[0], pos[1] + 0.38 * s, pos[2]), ST)
    o = B.part("Spin", L, gp(pos))
    extras.append(o)


def whip(pos, h):
    cy(P, 0.012, 0.02, h, (pos[0], pos[1] + h / 2, pos[2]), DK, seg=5)


def lattice(pos, h, wd, mat, levels=6):
    """Gittermast: vier Streben und Querstreben."""
    for sx in (-1, 1):
        for sz in (-1, 1):
            cy(P, 0.025, 0.035, h, (pos[0] + sx * wd, pos[1] + h / 2, pos[2] + sz * wd), mat, seg=5)
    for k in range(levels):
        y = pos[1] + 0.2 + k * (h - 0.3) / levels
        for sx in (-1, 1):
            bx(P, (0.02, 0.02, wd * 2), (pos[0] + sx * wd, y, pos[2]), mat, bevel=0.0)
        for sz in (-1, 1):
            bx(P, (wd * 2, 0.02, 0.02), (pos[0], y, pos[2] + sz * wd), mat, bevel=0.0)


def vls(pos, cols, rows, mat):
    """Feld senkrechter Startzellen mit Deckeln."""
    for gx in range(cols):
        for gz in range(rows):
            x = pos[0] + (gx - (cols - 1) / 2) * 0.34
            z = pos[2] + gz * 0.34
            y = dk(z) + 0.02
            bx(P, (0.3, 0.05, 0.3), (x, y + 0.025, z), mat, bevel=0.012)
            bx(P, (0.2, 0.012, 0.2), (x, y + 0.055, z), DK, bevel=0.0)


def ciws(pos, mat):
    cy(P, 0.2, 0.26, 0.4, (pos[0], pos[1] + 0.2, pos[2]), WHT2, seg=14)
    sp(P, 0.3, (pos[0], pos[1] + 0.58, pos[2]), mat, (1, 1.05, 1))
    bx(P, (0.08, 0.08, 0.5), (pos[0], pos[1] + 0.55, pos[2] + 0.35), DK)
    sp(P, 0.06, (pos[0] + 0.12, pos[1] + 0.7, pos[2] + 0.2), LR)


def patch(x, y, z, sx, sy, mat, face=1):
    """Aufgeschweißte Schrottplatte an der Bordwand (face=±1 für Steuerbord/Backbord)."""
    bx(P, (0.05, sy, sx), (x, y, z), mat, bevel=0.012)
    for dz in (-sx * 0.38, sx * 0.38):
        for dy in (-sy * 0.38, sy * 0.38):
            sp(P, 0.02, (x + face * 0.03, y + dy, z + dz), ST)


def helipad(z, r, y=None):
    y = dk(z) if y is None else y
    cy(P, r, r, 0.05, (0, y + 0.02, z), DECKW, seg=30)
    for k in range(20):
        a = math.tau * k / 20.0
        sp(P, 0.05, (math.cos(a) * r * 0.92, y + 0.06, z + math.sin(a) * r * 0.92), LC)
    for dx in (-r * 0.28, r * 0.28):
        bx(P, (0.12, 0.012, r * 0.8), (dx, y + 0.05, z), RINGM, bevel=0.0)
    bx(P, (r * 0.56, 0.012, 0.12), (0, y + 0.05, z), RINGM, bevel=0.0)


def davit_boat(x, z, y, side, mat):
    for dz in (-0.55, 0.55):
        cy(P, 0.04, 0.05, 1.0, (x, y + 0.5, z + dz), ST, seg=6)
        bx(P, (0.42, 0.05, 0.05), (x - side * 0.2, y + 1.0, z + dz), ST, bevel=0.0)
    sp(P, 0.42, (x - side * 0.4, y + 0.55, z), mat, (0.9, 0.5, 2.2))
    bx(P, (0.55, 0.04, 1.4), (x - side * 0.4, y + 0.74, z), WHT2, bevel=0.0)


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
    # Westbund: glatte, weiße Stealth-Korvette mit geneigten Aufbauten, Radom, Hubschrauberdeck
    hull(9.6, 2.7, 1.0, 0.85, WHT, DECKW, 0.88, TP)
    for sx in (-1.0, 1.0):
        bx(P, (0.04, 0.06, 6.0), (sx * 1.2, 0.55, 0.0), LC, bevel=0.0)
    fit(ports=True, rail=True, port_mat=LC)
    sb(P, [(-2.5, 1.02), (-2.1, 2.0), (0.0, 2.1), (1.0, 1.35), (1.2, 1.02)], 0.85, WHT, bevel=0.14)
    sb(P, [(-1.9, 2.0), (-1.6, 2.5), (-0.2, 2.5), (0.4, 2.0)], 0.62, WHT2, bevel=0.1)
    bx(P, (1.15, 0.28, 0.07), (0, 2.28, 0.5), GLS, rot=(-0.55, 0, 0), bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.07, 0.3, 1.5), (sx * 0.64, 2.3, -0.8), GLS, bevel=0.0)
    for k in range(5):
        bx(P, (0.05, 0.3, 0.05), (-0.5 + k * 0.25, 2.28, 0.53), WHT, rot=(-0.55, 0, 0), bevel=0.0)
    cy(P, 0.07, 0.1, 1.0, (0, 3.0, -1.0), WHT2, seg=10)
    sp(P, 0.38, (0, 3.65, -1.0), WHT, (1, 0.9, 1))
    radar((0, 2.5, -1.9), 1.0)
    whip((0.5, 2.1, -2.2), 1.6)
    whip((-0.55, 2.1, -2.0), 1.1)
    for sx in (-1.0, 1.0):
        sp(P, 0.06, (sx * 0.85, 2.0, 0.1), LC)
    helipad(-3.3, 1.05)
    sp(P, 0.3, (0, 1.55, -2.6), GLB, (1, 0.7, 1))
    for k in range(2):
        cy(P, 0.4 + k * 0.12, 0.4 + k * 0.12, 0.03, (0, 1.4 + k * 0.1, -2.6), GLB, seg=18)
    cy(P, 0.13, 0.2, 0.4, (0, 1.2, -2.6), ST, seg=10)
    vls((0, 0, 1.55), 3, 3, ST)
    ciws((0.8, 1.0, 0.85), WHT)
    davit_boat(1.16, -0.6, 1.0, 1.0, ORANGE)
    cy(P, 0.28, 0.28, 0.5, (-0.8, 1.35, 0.1), ORANGE, rot=(0, 0, math.pi / 2), seg=12)
    vent((-0.9, 1.0, 0.9))
    cy(T, 0.5, 0.58, 0.3, (0, 1.22, 2.7), TP, seg=18)
    sp(T, 0.52, (0, 1.38, 2.7), TP, (1, 0.55, 1.1))
    sp(T, 0.06, (0.4, 1.55, 2.5), LR)
    for sx in (-0.26, 0.26):
        rbx(BR, (0.34, 0.34, 1.5), (sx, 1.6, 3.35), WHT, rot=(-0.3, 0, 0), r=0.09)
        cy(BR, 0.1, 0.1, 0.06, (sx, 1.63, 4.07), GLB, rot=(math.pi / 2 - 0.3, 0, 0), seg=12)
    turret_parts((0, 1.1, 2.7), (0, 1.55, 2.7), (0, 1.75, 4.2))
    finish_unit("corvette", cam=(-10, -12, 7), tgt=(0, 0, 1.4))

elif which == "cruiser":
    # Westbund: Aegis-Kreuzer, glatt, mit Radarflächen, Hangar und Hubschrauberdeck, Startzellenfeld
    hull(14.0, 3.9, 1.1, 0.95, WHT, DECKW, 0.86, TP)
    for sx in (-1.0, 1.0):
        bx(P, (0.04, 0.06, 10.0), (sx * 1.8, 0.6, 0.0), LC, bevel=0.0)
    fit(ports=True, rail=True, port_mat=LC)
    sb(P, [(-3.2, 1.12), (-2.8, 2.4), (-0.2, 2.6), (1.2, 1.7), (1.5, 1.12)], 1.25, WHT, bevel=0.16)
    sb(P, [(-2.5, 2.4), (-2.1, 3.3), (-0.6, 3.4), (0.4, 2.6)], 1.0, WHT2, bevel=0.14)
    sb(P, [(-2.0, 3.3), (-1.7, 3.9), (-0.9, 3.95), (-0.3, 3.4)], 0.78, WHT, bevel=0.12)
    bx(P, (1.6, 0.32, 0.08), (0, 3.55, -0.3), GLS, rot=(-0.6, 0, 0), bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.08, 0.34, 1.6), (sx * 0.8, 3.55, -1.3), GLS, bevel=0.0)
        # Radarflächen: geneigte dunkle Platten an den Seiten des Mittelaufbaus
        rbx(P, (0.07, 0.9, 1.0), (sx * 1.04, 2.9, -1.3), DK, rot=(0, 0, sx * 0.18), r=0.03)
        rbx(P, (0.05, 0.8, 0.9), (sx * 1.27, 1.95, -0.2), DK, rot=(0, 0, sx * 0.25), r=0.03)
    cy(P, 0.1, 0.14, 1.4, (0, 4.6, -1.3), ST, seg=10)
    sp(P, 0.42, (0, 5.4, -1.3), WHT, (1, 0.85, 1))
    radar((0, 3.95, -2.3), 1.4)
    whip((0.5, 3.9, -2.0), 2.0)
    whip((-0.5, 3.9, -1.6), 1.5)
    # Heck: Hangar mit Rolltor, darauf Hubschrauberdeck
    sb(P, [(-6.9, 1.12), (-6.9, 2.3), (-5.2, 2.3), (-4.9, 1.12)], 1.35, WHT2, bevel=0.14)
    bx(P, (2.1, 1.0, 0.06), (0, 1.75, -4.88), DK, bevel=0.0)
    for k in range(5):
        bx(P, (2.1, 0.03, 0.08), (0, 1.35 + k * 0.2, -4.86), ST, bevel=0.0)
    cy(P, 1.45, 1.45, 0.05, (0, 2.34, -6.0), DECKW, seg=30)
    for dx in (-0.4, 0.4):
        bx(P, (0.12, 0.012, 1.2), (dx, 2.375, -6.0), RINGM, bevel=0.0)
    bx(P, (0.8, 0.012, 0.12), (0, 2.375, -6.0), RINGM, bevel=0.0)
    for k in range(14):
        a = math.tau * k / 14.0
        sp(P, 0.06, (math.cos(a) * 1.35, 2.38, -6.0 + math.sin(a) * 1.35), LC)
    vls((0, 0, 1.9), 4, 5, ST)
    ciws((1.25, 1.1, 1.5), WHT)
    ciws((-1.25, 1.1, 1.5), WHT)
    for sx in (-1.0, 1.0):
        davit_boat(sx * 1.78, -1.4, 1.1, sx, ORANGE)
    hatch((0.9, 1.1, 0.6))
    vent((-0.9, 1.1, 0.5))
    cy(T, 0.7, 0.8, 0.35, (0, 1.38, 4.4), TP, seg=22)
    sp(T, 0.78, (0, 1.58, 4.4), TP, (1, 0.5, 1.1))
    sp(T, 0.07, (0.65, 1.8, 4.1), LR)
    for sx in (-0.28, 0.28):
        rbx(BR, (0.4, 0.4, 2.1), (sx, 1.8, 5.1), WHT, rot=(-0.35, 0, 0), r=0.12)
        cy(BR, 0.1, 0.1, 0.06, (sx, 1.98, 6.1), GLB, rot=(math.pi / 2 - 0.35, 0, 0), seg=12)
    turret_parts((0, 1.15, 4.4), (0, 1.8, 4.4), (0, 2.1, 6.2))
    finish_unit("cruiser", cam=(-14, -16, 9), tgt=(0, 0, 1.8))

elif which == "gunboat":
    # Rote Allianz: massives graues Kanonenboot, genietet, runder Kommandoturm, Schlot, Wasserbomben
    hull(8.6, 2.9, 1.0, 0.8, HULLR, BAND_DK, 0.8, BANDR)
    fit(ports=False, rivets=True, bulwark=True)
    sb(P, [(-2.4, 1.02), (-2.4, 1.7), (0.8, 1.7), (1.3, 1.02)], 1.05, HULLR2, bevel=0.14)
    cy(P, 0.62, 0.72, 0.9, (0, 2.1, -0.4), HULLR2, seg=26)
    cy(P, 0.66, 0.66, 0.07, (0, 2.58, -0.4), DK, seg=26)
    for k in range(10):
        a = math.tau * k / 10.0 - 1.2
        if math.sin(a) > -0.3:
            bx(P, (0.2, 0.2, 0.05), (math.cos(a) * 0.66, 2.2, -0.4 + math.sin(a) * 0.66), GLS, rot=(0, -a + math.pi / 2, 0), bevel=0.0)
    cy(P, 0.4, 0.5, 0.45, (0, 2.82, -0.4), HULLR2, seg=20)
    sp(P, 0.4, (0, 3.08, -0.4), HULLR2, (1, 0.7, 1))
    radar((0, 3.35, -0.4), 0.8)
    cy(P, 0.03, 0.04, 1.3, (0.0, 3.9, -0.4), DK, seg=6)
    cy(P, 0.4, 0.46, 1.5, (0, 2.5, -2.4), HULLR, seg=20)
    cy(P, 0.42, 0.42, 0.18, (0, 3.18, -2.4), BANDR, seg=20)
    cy(P, 0.36, 0.36, 0.06, (0, 3.28, -2.4), DK, seg=20)
    for k in range(4):
        cy(P, 0.17, 0.17, 0.42, (-0.5 + (k % 2) * 1.0, 1.2, -3.4 + (k // 2) * 0.5), DK, seg=12)
    for sx in (-1.0, 1.0):
        cy(P, 0.14, 0.14, 1.1, (sx * 0.75, 1.15, -1.7), ST, rot=(math.pi / 2, 0, 0.0), seg=12)
        cy(P, 0.17, 0.17, 0.08, (sx * 0.75, 1.15, -1.1), DK, rot=(math.pi / 2, 0, 0.0), seg=12)
    cy(P, 0.3, 0.3, 0.22, (-0.9, 1.12, -2.6), B.M("RopeCoil", (0.55, 0.5, 0.35), 0.0, 0.95, 0.3, 0.6), seg=14)
    lifeboat((1.0, 1.1, -3.2), (0.75, 0.2, 0.12), -1.0)
    deckbox((-0.95, 1.0, -2.1), 0.2, (0.3, 0.34, 0.24))
    hatch((0.5, 1.0, 1.0))
    cy(T, 0.72, 0.8, 0.5, (0, 1.4, 2.3), TP, seg=26)
    cy(T, 0.5, 0.66, 0.3, (0, 1.78, 2.3), TP, seg=26)
    bx(T, (0.12, 0.5, 0.5), (0.5, 1.55, 2.5), DK)
    cy(BR, 0.1, 0.11, 2.2, (0, 1.6, 3.8), ST, rot=(math.pi / 2, 0, 0), seg=14)
    cy(BR, 0.15, 0.15, 0.32, (0, 1.6, 4.9), DK, rot=(math.pi / 2, 0, 0), seg=14)
    turret_parts((0, 1.1, 2.3), (0, 1.6, 2.3), (0, 1.6, 5.1))
    finish_unit("gunboat", cam=(-9, -11, 7), tgt=(0, 0, 1.4))

elif which == "battleship":
    # Rote Allianz: Schlachtkreuzer — Turmbrücke aus runden Ebenen, zwei Schlote, drei Geschütztürme, Bordflugzeug
    hull(14.6, 4.6, 1.3, 1.0, HULLR, BAND_DK, 0.84, BANDR)
    fit(ports=True, rivets=True, bulwark=True, port_mat=LW)
    sb(P, [(-3.2, 1.32), (-3.2, 2.0), (1.4, 2.0), (2.0, 1.32)], 1.7, HULLR2, bevel=0.16)
    cy(P, 1.2, 1.4, 0.9, (0, 2.45, -0.6), HULLR2, seg=30)
    cy(P, 1.3, 1.3, 0.1, (0, 2.95, -0.6), DK, seg=30)
    cy(P, 0.95, 1.1, 0.8, (0, 3.35, -0.6), HULLR2, seg=26)
    cy(P, 1.02, 1.02, 0.1, (0, 3.8, -0.6), DK, seg=26)
    for k in range(12):
        a = math.tau * k / 12.0 - 1.4
        if math.sin(a) > -0.5:
            bx(P, (0.34, 0.26, 0.05), (math.cos(a) * 1.08, 3.4, -0.6 + math.sin(a) * 1.08), GLS, rot=(0, -a + math.pi / 2, 0), bevel=0.0)
    cy(P, 0.65, 0.75, 0.55, (0, 4.1, -0.6), HULLR2, seg=22)
    cy(P, 0.8, 0.8, 0.08, (0, 4.42, -0.6), DK, seg=22)
    lattice((0, 4.45, -0.6), 2.4, 0.22, ST, 6)
    radar((0, 6.9, -0.6), 1.5)
    for sx in (-1.0, 1.0):
        cy(P, 0.2, 0.2, 0.3, (sx * 1.0, 3.95, -0.6), DK, rot=(math.pi / 2, 0, 0), seg=12)
        sp(P, 0.14, (sx * 1.0, 3.95, -0.4), LW)
    whip((0.5, 4.4, -0.9), 1.6)
    for k in range(2):
        z = -2.9 - k * 1.7
        cy(P, 0.55, 0.7, 2.2, (0, 2.9, z), HULLR, seg=24)
        cy(P, 0.58, 0.58, 0.22, (0, 3.9, z), BANDR, seg=24)
        cy(P, 0.5, 0.5, 0.06, (0, 4.04, z), DK, seg=24)
        for kk in range(6):
            a = math.tau * kk / 6.0
            bx(P, (0.04, 0.4, 0.04), (math.cos(a) * 0.5, 3.1, z + math.sin(a) * 0.5), ST, bevel=0.0)
    for sx in (-1.0, 1.0):
        for k in range(3):
            z = 0.8 + k * 0.9
            cy(P, 0.24, 0.26, 0.2, (sx * 1.95, dk(z) + 0.1, z), HULLR2, seg=16)
            sp(P, 0.24, (sx * 1.95, dk(z) + 0.24, z), HULLR2, (1, 0.7, 1))
            cy(P, 0.04, 0.04, 0.6, (sx * 1.95, dk(z) + 0.28, z + 0.38), DK, rot=(math.pi / 2, 0, 0), seg=8)
        lifeboat((sx * 1.95, 2.15, -1.0), (0.75, 0.2, 0.12), -sx)
    # Heck: Bordflugzeug auf Katapult, Kran
    cy(P, 0.55, 0.55, 0.35, (0, 1.5, -6.0), HULLR2, seg=20)
    bx(P, (0.18, 0.1, 2.8), (0, 1.8, -5.9), ST)
    bx(P, (1.6, 0.04, 0.3), (0, 1.95, -5.7), BANDR)
    rbx(P, (0.22, 0.22, 1.2), (0, 1.95, -5.9), WHT2, r=0.08)
    bx(P, (0.7, 0.03, 0.2), (0, 1.97, -5.95), WHT2, bevel=0.0)
    cy(P, 0.07, 0.09, 1.9, (1.0, 2.2, -6.4), ST, seg=8)
    bx(P, (0.08, 0.08, 1.9), (1.0, 3.1, -5.5), ST, rot=(0.5, 0, 0), bevel=0.0)
    for k in range(3):
        hatch((-0.9 + k * 0.9, 1.3, -6.7))
    vent((1.4, 1.3, -4.6))

    def big_turret(L, BL, cz, cyy, zdir):
        cy(L, 0.95, 1.05, 0.45, (0, cyy + 0.22, cz), HULLR2, seg=26)
        sp(L, 1.05, (0, cyy + 0.5, cz), HULLR2, (1, 0.55, 1.15))
        rbx(L, (1.5, 0.5, 1.6), (0, cyy + 0.78, cz + zdir * 0.15), HULLR2, rot=(-0.1 * zdir, 0, 0), r=0.2)
        sp(L, 0.07, (0.95, cyy + 0.95, cz - zdir * 0.5), LR)
        for sx in (-0.38, 0.38):
            cy(BL, 0.12, 0.14, 2.8, (sx, cyy + 0.55, cz + zdir * 1.9), ST, rot=(math.pi / 2, 0, 0), seg=14)
            cy(BL, 0.18, 0.18, 0.34, (sx, cyy + 0.55, cz + zdir * 3.3), DK, rot=(math.pi / 2, 0, 0), seg=14)
    big_turret(P, P, 2.5, 1.9, 1.0)
    big_turret(T, BR, 4.9, 1.67, 1.0)
    turret_parts((0, 1.45, 4.9), (0, 2.22, 4.9), (0, 2.22, 8.5))
    finish_unit("battleship", cam=(-15, -17, 10), tgt=(0, 0, 2.5))

elif which == "skiff":
    # Schattenfront: zusammengenagelter Kutter, Bretter, Schrottplatten, Plane, Außenborder, Reifen, MG
    hull(6.3, 2.2, 0.55, 0.5, RUSTH, BOARD, 0.75, BAND_DK)
    fit(ports=False, rivets=True, rail=True)
    for sx in (-1.0, 1.0):
        bx(P, (0.08, 0.3, 4.2), (sx * 0.95, 0.8, -0.4), BOARD, rot=(0, 0, sx * 0.04))
        bx(P, (0.1, 0.22, 0.7), (sx * 0.97, 0.85, 0.3), RUST2, rot=(0, 0, sx * 0.04))
    for k in range(3):
        bx(P, (1.9, 0.07, 0.12), (0, 0.62, -2.6 + k * 1.3), BOARD)
    for i in range(7):
        sd = 1 if i % 2 == 0 else -1
        z = -2.4 + i * 0.75
        t = (z + HL * 0.5) / HL
        mt = (RUST2, RUST3, RUSTH, PLATE)[i % 4]
        patch(sd * (sidex(t, 0.4) + 0.03), 0.4, z, 0.6 + (i % 3) * 0.12, 0.34 + (i % 2) * 0.1, mt, sd)
    rbx(P, (1.3, 0.7, 1.3), (0, 1.0, -1.5), PLATE, r=0.05)
    bx(P, (1.34, 0.28, 0.06), (0, 1.12, -0.82), GLS, bevel=0.0)
    bx(P, (1.7, 0.06, 1.7), (0, 1.43, -1.5), RUSTH, rot=(0.08, 0.0, 0.06))
    for k in range(5):
        bx(P, (0.05, 0.05, 1.72), (-0.7 + k * 0.35, 1.47, -1.5), RUST3, rot=(0.08, 0, 0.06), bevel=0.0)
    cy(P, 0.1, 0.12, 0.7, (0.5, 1.7, -1.9), RUST2, seg=8)
    rbx(P, (0.4, 0.55, 0.5), (0, 0.8, -3.3), DK, r=0.06)
    rbx(P, (0.24, 0.1, 0.5), (0, 1.12, -3.25), BANDR, r=0.03)
    cy(P, 0.04, 0.05, 0.9, (0, 0.3, -3.5), ST, seg=6)
    cy(P, 0.2, 0.2, 0.04, (0, -0.15, -3.55), ST, rot=(0, 0, math.pi / 2), seg=10)
    rbx(P, (0.5, 0.35, 0.5), (0.55, 0.78, -0.2), B.M("Crate2", (0.5, 0.45, 0.3), 0.0, 0.9, 0.3, 0.6), rot=(0, 0.3, 0), r=0.03)
    for k in range(2):
        cy(P, 0.14, 0.14, 0.4, (-0.5 + k * 0.3, 0.78, -0.3), B.M("Jerry2", (0.55, 0.3, 0.12), 0.3, 0.7, 0.4, 0.6), seg=10)
    sp(P, 0.4, (0.35, 0.5, 0.4), B.M("Net", (0.35, 0.35, 0.3), 0.0, 0.95, 0.2, 0.6), (1.3, 0.5, 1.0))
    sp(P, 0.55, (-0.4, 0.75, 0.9), CLOTH, (1.2, 0.5, 1.5))
    for k in range(4):
        sd = -1 if k % 2 else 1
        t = ((-2.3 + k * 1.3) + HL * 0.5) / HL
        cy(P, 0.2, 0.2, 0.2, (sd * (sidex(t, 0.2) + 0.12), 0.2, -2.3 + k * 1.3), RB, rot=(0, 0, math.pi / 2), seg=12)
    cy(T, 0.06, 0.06, 0.5, (0, 0.95, 1.4), DK, seg=8)
    rbx(T, (0.3, 0.26, 0.5), (0, 1.3, 1.4), DK, r=0.04)
    rbx(T, (0.4, 0.38, 0.08), (0, 1.36, 1.7), PLATE, r=0.02)
    rbx(T, (0.24, 0.2, 0.3), (0.27, 1.25, 1.35), OL, r=0.03)
    cy(BR, 0.04, 0.04, 1.0, (0, 1.3, 2.2), DK, rot=(math.pi / 2, 0, 0), seg=8)
    turret_parts((0, 1.0, 1.4), (0, 1.3, 1.4), (0, 1.3, 2.75))
    finish_unit("skiff", cam=(-8, -9, 5), tgt=(0, 0, 0.7))

elif which == "frigate":
    # Schattenfront: Fregatte aus Frachter — Containerstapel, Schrottpanzerung, Fässerschlote, Kran, Raketenrack
    hull(11.8, 3.5, 1.0, 0.85, RUSTH, DECKS, 0.82, BAND_DK)
    fit(ports=False, rivets=True, rail=True)
    for k in range(7):
        for sd in (-1.0, 1.0):
            z = -4.4 + k * 1.35 + (0.2 if sd > 0 else 0.0)
            t = (z + HL * 0.5) / HL
            mt = (PLATE, BANDR, RUST2, RUST3)[(k + (0 if sd > 0 else 1)) % 4]
            patch(sd * (sidex(t, 0.55) + 0.04), 0.55, z, 1.0, 0.55 + 0.1 * (k % 2), mt, sd)
    for k in range(5):
        sz = -4.0 + k * 2.0
        for sx in (-1.0, 1.0):
            t = (sz + 1.0 + HL * 0.5) / HL
            cy(P, 0.3, 0.3, 0.22, (sx * (sidex(t, 0.2) + 0.14), 0.2, sz + 1.0), RB, rot=(0, 0, math.pi / 2), seg=14)
    cols = [(0.45, 0.2, 0.12), (0.2, 0.3, 0.38), (0.32, 0.38, 0.2), (0.5, 0.36, 0.14)]
    for row in range(2):
        for lvl in range(2 if row == 0 else 1):
            cx = -0.75 + row * 1.5
            cyc = 1.4 + lvl * 0.82
            cm = B.M("FrigCont%d" % ((row * 2 + lvl) % 4), cols[(row * 2 + lvl) % 4], 0.3, 0.8, 0.7, 0.7)
            rbx(P, (1.0, 0.8, 2.2), (cx, cyc, -1.2 + lvl * 0.15), cm, rot=(0, 0.03 * lvl, 0), r=0.05)
            for kk in range(5):
                bx(P, (0.03, 0.74, 2.0), (cx - 0.35 + kk * 0.18, cyc, -1.2 + lvl * 0.15), DK, rot=(0, 0.03 * lvl, 0), bevel=0.0)
            bx(P, (0.9, 0.7, 0.04), (cx, cyc, -0.08 + lvl * 0.15), DK, bevel=0.0)
    sp(P, 0.9, (0.4, 2.8, -1.3), CLOTH, (1.5, 0.28, 1.6))
    rbx(P, (1.8, 1.1, 1.6), (0, 1.55, -3.5), PLATE, r=0.08)
    bx(P, (1.6, 0.18, 0.05), (0, 1.85, -2.68), GLO, bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.06, 0.8, 1.2), (sx * 0.95, 1.55, -3.5), RUST3, bevel=0.0)
    bx(P, (2.0, 0.1, 1.8), (0, 2.15, -3.5), RUSTH, rot=(0.05, 0, 0.03))
    for z, xx in ((-4.0, 0.6), (-4.1, -0.5)):
        for k in range(3):
            cy(P, 0.18, 0.18, 0.4, (xx, 2.2 + k * 0.4, z), (RUSTH, RUST3, RUST2)[k % 3], seg=12)
        cy(P, 0.14, 0.18, 0.1, (xx, 3.45, z), DK, seg=12)
    cy(P, 0.07, 0.09, 2.4, (-1.3, 2.2, 1.4), DK, seg=8)
    bx(P, (0.08, 0.08, 2.0), (-1.3, 3.3, 2.1), DK, rot=(0.2, 0, 0), bevel=0.0)
    cy(P, 0.2, 0.2, 0.3, (-1.3, 1.2, 1.1), B.M("Winch", (0.4, 0.35, 0.3), 0.4, 0.7, 0.5, 0.6), rot=(0, 0, math.pi / 2), seg=12)
    deckbox((1.2, 1.0, 2.3), 0.4, (0.4, 0.3, 0.18))
    cy(P, 0.3, 0.3, 0.5, (1.2, 1.25, 1.5), RB, seg=12)
    cy(T, 0.6, 0.7, 0.3, (0, 1.15, 3.0), PLATE, seg=14)
    for sx in (-0.4, 0.0, 0.4):
        for sy in (0.0, 0.34):
            cy(BR, 0.13, 0.13, 1.5, (sx, 1.45 + sy, 3.7), B.M("RackTube", (0.3, 0.32, 0.3), 0.4, 0.7, 0.5, 0.6), rot=(math.pi / 2 - 0.3, 0, 0), seg=10)
            cy(BR, 0.0, 0.09, 0.3, (sx, 1.65 + sy, 4.45), RS, rot=(math.pi / 2 - 0.3, 0, 0), seg=10)
    bx(BR, (1.4, 0.05, 0.06), (0, 1.65, 3.2), DK, bevel=0.0)
    turret_parts((0, 1.0, 3.0), (0, 1.45, 3.0), (0, 1.9, 4.5))
    finish_unit("frigate", cam=(-12, -14, 8), tgt=(0, 0, 1.6))

elif which == "speedboat":
    # Rote Allianz: Raketen-Schnellboot — flach, keilförmig, Torpedorohre, Raketenpaar, Doppelmotor
    hull(6.4, 1.9, 0.62, 0.45, HULLR, BAND_DK, 0.9, BANDR)
    fit(ports=False, rivets=True, rail=False)
    # Schanzkleid-Bug und geduckter Brückenaufbau mit Neigung
    sb(P, [(-1.7, 0.64), (-1.5, 1.2), (-0.2, 1.3), (0.5, 0.95), (0.7, 0.66)], 0.55, HULLR2, bevel=0.1)
    bx(P, (0.95, 0.22, 0.06), (0, 1.12, 0.52), GLS, rot=(-0.6, 0, 0), bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.05, 0.22, 0.9), (sx * 0.56, 1.12, -0.7), GLS, bevel=0.0)
    cy(P, 0.04, 0.05, 1.0, (0.2, 1.85, -1.0), DK, seg=6)
    radar((0, 1.3, -1.2), 0.6)
    # Heck: zwei Außenborder-Gondeln mit Auspuff, Schraubenschutz
    for sx in (-0.45, 0.45):
        rbx(P, (0.42, 0.5, 0.7), (sx, 0.8, -3.0), DK, r=0.08)
        cy(P, 0.12, 0.12, 0.5, (sx, 0.45, -3.3), ST, rot=(math.pi / 2, 0, 0), seg=10)
        cy(P, 0.17, 0.17, 0.05, (sx, 0.2, -3.45), ST, rot=(0, 0, math.pi / 2), seg=10)
    # Torpedorohre seitlich, schräg nach vorn, mit roten Spitzen
    for sx in (-1.0, 1.0):
        cy(P, 0.13, 0.13, 1.5, (sx * 0.62, 0.85, -0.5), ST, rot=(math.pi / 2 - 0.08, 0, 0), seg=12)
        cy(P, 0.0, 0.12, 0.25, (sx * 0.62, 0.8, 0.35), BANDR, rot=(math.pi / 2 - 0.08, 0, 0), seg=12)
        bx(P, (0.08, 0.1, 0.3), (sx * 0.62, 0.7, -1.0), DK)
    deckbox((-0.3, 0.62, -2.0), 0.3, (0.3, 0.34, 0.24))
    hatch((0.0, 0.62, -0.2), 0.22)
    # Bugwaffe: kleiner Drehturm mit Raketenpaar
    cy(T, 0.38, 0.45, 0.22, (0, 0.8, 1.7), TP, seg=18)
    sp(T, 0.36, (0, 0.92, 1.7), TP, (1, 0.6, 1.1))
    for sx in (-0.2, 0.2):
        rbx(BR, (0.22, 0.22, 1.1), (sx, 1.05, 2.1), HULLR2, rot=(-0.2, 0, 0), r=0.06)
        cy(BR, 0.0, 0.08, 0.2, (sx, 1.1, 2.7), BANDR, rot=(math.pi / 2 - 0.2, 0, 0), seg=10)
    turret_parts((0, 0.72, 1.7), (0, 1.05, 1.7), (0, 1.1, 2.8))
    finish_unit("speedboat", cam=(-7, -8, 5), tgt=(0, 0, 0.6))

elif which == "jetski":
    # Schattenfront: Jetski-Räuber — Schrottlack, Sitzbank, Lenker, MG vorn, Plattenschutz
    hull(2.8, 0.95, 0.38, 0.25, RUSTH, BOARD, 0.8, BAND_DK)
    for i, (z, sd) in enumerate(((-0.7, 1), (0.1, -1), (0.7, 1))):
        t_ = (z + HL * 0.5) / HL
        patch(sd * (sidex(t_, 0.2) + 0.03), 0.2, z, 0.5, 0.2, (RUST2, RUST3, PLATE)[i], sd)
    # Sitzbank, Heckhöcker, Lenkersäule mit Lenker und Scheibe
    rbx(P, (0.46, 0.2, 1.1), (0, 0.55, -0.55), DK, r=0.07)
    rbx(P, (0.4, 0.28, 0.4), (0, 0.6, -1.15), RUSTH, r=0.08)
    cy(P, 0.05, 0.06, 0.55, (0, 0.65, 0.35), DK, rot=(0.3, 0, 0), seg=8)
    bx(P, (0.62, 0.05, 0.05), (0, 0.92, 0.45), ST, bevel=0.0)
    for sx in (-1, 1):
        cy(P, 0.025, 0.025, 0.18, (sx * 0.31, 0.92, 0.45), RB, rot=(0, 0, math.pi / 2), seg=6)
    bx(P, (0.34, 0.2, 0.03), (0, 0.98, 0.55), GLS, rot=(-0.6, 0, 0), bevel=0.0)
    # Düse mit Ring, Seitenwülste aus Reifenstücken, Fahnenstock mit Lumpen
    cy(P, 0.17, 0.2, 0.3, (0, 0.28, -1.5), ST, rot=(math.pi / 2, 0, 0), seg=12)
    cy(P, 0.13, 0.13, 0.05, (0, 0.28, -1.68), DK, rot=(math.pi / 2, 0, 0), seg=12)
    for sx in (-1, 1):
        cy(P, 0.1, 0.1, 1.0, (sx * 0.5, 0.28, -0.4), RB, rot=(math.pi / 2, 0, 0), seg=10)
    cy(P, 0.012, 0.015, 1.1, (0.2, 1.0, -1.15), DK, seg=5)
    bx(P, (0.02, 0.35, 0.16), (0.2, 1.45, -1.3), B.M("Rag", (0.06, 0.06, 0.06), 0.0, 0.95, 0.2, 0.5), bevel=0.0)
    # MG mit Schild vorn
    cy(T, 0.05, 0.05, 0.3, (0, 0.5, 0.85), DK, seg=8)
    rbx(T, (0.2, 0.18, 0.34), (0, 0.72, 0.85), DK, r=0.03)
    rbx(T, (0.3, 0.26, 0.05), (0, 0.76, 1.02), PLATE, r=0.015)
    cy(BR, 0.025, 0.025, 0.7, (0, 0.72, 1.3), DK, rot=(math.pi / 2, 0, 0), seg=6)
    turret_parts((0, 0.45, 0.85), (0, 0.72, 0.85), (0, 0.72, 1.7))
    finish_unit("jetski", cam=(-4, -5, 3), tgt=(0, 0, 0.4))

elif which in ("submarine", "minisub"):
    # U-Boote: zigarrenförmiger Druckkörper (Drehkörper um die Längsachse), Turm, Ruder, Tauchflächen, Schraube
    big = which == "submarine"
    L_, R_, Y0 = (13.0, 1.25, -0.28) if big else (7.2, 0.78, -0.2)
    HL, HD, HB = L_, R_ * 0.9, R_ * 2.0

    def tube(length, rad, y0, mat_side, mat_band, nose=0.12, tail=0.26, rings=48, segs=30):
        verts, faces, mats = [], [], []
        for i in range(rings + 1):
            t = i / rings
            if t < nose:
                r = rad * math.sqrt(max(0.0, 1.0 - ((nose - t) / nose) ** 2))
                r = max(r, rad * 0.04)
            elif t > 1.0 - tail:
                u = (t - (1.0 - tail)) / tail
                r = rad * (1.0 - 0.86 * (u ** 1.5))
            else:
                r = rad
            z = -length * 0.5 + t * length
            for j in range(segs):
                a = math.tau * j / segs
                x = math.cos(a) * r * 1.0
                yy = y0 + math.sin(a) * r * 0.96
                verts.append((x, -z, yy))
        for i in range(rings):
            for j in range(segs):
                j2 = (j + 1) % segs
                a_, b_ = i * segs + j, (i + 1) * segs + j
                faces.append((a_, b_, (i + 1) * segs + j2, i * segs + j2))
                ang = math.tau * (j + 0.5) / segs
                low = math.sin(ang) * rad
                mats.append(1 if (mat_band is not None and 0.0 < low - (-y0) + 0.28 and low - (-y0) < 0.28 + 0.34 and abs(low - (-y0)) < 0.5) else 0)
        faces.append(tuple(range(segs - 1, -1, -1)))
        mats.append(0)
        faces.append(tuple(range(rings * segs, (rings + 1) * segs)))
        mats.append(0)
        me = bpy.data.meshes.new("SubMesh")
        me.from_pydata(verts, [], faces)
        for mt in (mat_side, mat_band if mat_band is not None else mat_side):
            me.materials.append(mt)
        for p_, mi in zip(me.polygons, mats):
            p_.material_index = mi
            p_.use_smooth = True
        me.update()
        ob = bpy.data.objects.new("HullShape", me)
        S.scene.collection.objects.link(ob)
        bm_ = bmesh.new()
        bm_.from_mesh(me)
        bmesh.ops.recalc_face_normals(bm_, faces=bm_.faces)
        bm_.to_mesh(me)
        bm_.free()
        P.append(ob)

    if big:
        tube(L_, R_, Y0, HULLR, BANDR)
        # Deckskasko: schmaler, dunkler Gehwegstreifen mit Ablaufschlitzen
        bx(P, (0.7, 0.05, 9.5), (0, Y0 + R_ * 0.96 + 0.01, -0.5), DK, bevel=0.01)
        for k in range(20):
            bx(P, (0.7, 0.012, 0.03), (0, Y0 + R_ * 0.96 + 0.045, -5.0 + k * 0.5), HULLR2, bevel=0.0)
        for k in range(14):
            for sd in (-1, 1):
                bx(P, (0.025, 0.06, 0.2), (sd * 0.18, Y0 + R_ * 0.98 + 0.08, -4.8 + k * 0.7), ST, bevel=0.005)
        # Turm: Seitenprofil mit abgerundeter Front, Brückenrand, Periskope, Funkmast, Schnorchel, Radar
        sb(P, [(-1.7, 0.7), (-1.5, 2.1), (-0.7, 2.25), (0.9, 2.2), (1.25, 1.6), (1.6, 0.7)], 0.5, HULLR2, bevel=0.14)
        bx(P, (1.04, 0.1, 2.8), (0, 2.28, -0.4), DK, bevel=0.03)
        bx(P, (0.8, 0.06, 0.06), (0, 2.18, 1.0), DK, bevel=0.0)
        for sx in (-1, 1):
            cy(P, 0.04, 0.05, 1.4, (sx * 0.2, 3.0, 0.1), ST, seg=8)
        cy(P, 0.06, 0.07, 1.0, (0.3, 2.85, -1.0), DK, seg=8)
        sp(P, 0.09, (0.3, 3.38, -1.0), ST)
        cy(P, 0.03, 0.04, 1.2, (-0.3, 2.9, -0.9), ST, seg=6)
        radar((0.0, 3.5, 0.6), 0.9)
        # roter Stern auf dem Turm (beide Seiten)
        for sx in (-1, 1):
            o = B.star(0.04, (0, 0, 0), BANDR, 0.34, 0.13)
            o.location = (sx * 0.505, -0.0, 1.55)
            o.rotation_euler = (math.pi / 2, 0, math.pi / 2)
            P.append(o)
        # Bug: Hydrophonkuppel, Torpedoklappen, Bugruder; Heck: Kreuzruder und Schraube
        sp(P, 0.35, (0, Y0 - 0.2, 6.1), DK, (1.0, 0.6, 0.8))
        for sd in (-1, 1):
            bx(P, (0.04, 0.1, 0.45), (sd * 0.5, Y0 + 0.2, 5.5), HULLR2, rot=(0, 0, sd * 0.2))
            bx(P, (0.7, 0.04, 0.35), (sd * 0.8, Y0 + 0.2, 3.7), HULLR2)
        for k in range(4):
            sx = (-0.3, 0.3)[k % 2]
            bx(P, (0.34, 0.34, 0.04), (sx, Y0 + (0.25 if k < 2 else -0.25), 6.34), DK)
        for a in (0.0, 1.571):
            bx(P, (1.7, 0.05, 0.7) if a == 0 else (0.05, 1.7, 0.7), (0, Y0, -5.7), HULLR2, bevel=0.01)
        cy(P, 0.14, 0.14, 0.5, (0, Y0, -6.7), DK, rot=(math.pi / 2, 0, 0), seg=10)
        for k in range(5):
            a = math.tau * k / 5.0
            bx(P, (0.05, 0.62, 0.22), (math.cos(a) * 0.3, Y0 + math.sin(a) * 0.3, -7.0), ST, rot=(0, a, 0), bevel=0.0)
        rivet_z = [(-5.0 + k * 0.62) for k in range(17)]
        for z in rivet_z:
            for sd in (-1, 1):
                sp(P, 0.022, (sd * (R_ + 0.0) * 0.998, Y0 + 0.2, z), ST)
        sp(T, 0.01, (0, 0.0, 0.0), DK) if False else None
        S.empty("Muzzle", (0, -6.3, Y0 + 0.2))
        extras.append(bpy.data.objects["Muzzle"])
        finish_unit("submarine", cam=(-11, -13, 6), tgt=(0, 0, 0.6))
    else:
        tube(L_, R_, Y0, RUST3, BAND_DK)
        # Schrottplatten, Fässer als Ballast, Plane, Tau
        for i in range(8):
            sd = 1 if i % 2 == 0 else -1
            z = -2.6 + i * 0.7
            patch(sd * R_ * 0.96, Y0 + 0.15, z, 0.55, 0.32, (RUST2, RUSTH, PLATE)[i % 3], sd)
        for sd in (-1, 1):
            for k in range(3):
                cy(P, 0.2, 0.2, 0.7, (sd * (R_ + 0.12), Y0 - 0.05, -1.6 + k * 1.6), (RUSTH, RUST3, RUST2)[k], rot=(math.pi / 2, 0, 0), seg=12)
            bx(P, (0.1, 0.06, 0.3), (sd * (R_ - 0.05), Y0 + 0.05, -1.5), RUST2)
        # kleiner Turm: Eimer-Aufbau mit Luke, Schnorchelrohr, Periskop aus Rohr, Lumpenfahne
        rbx(P, (0.7, 0.8, 1.2), (0, Y0 + R_ * 0.9 + 0.35, 0.3), PLATE, r=0.07)
        cy(P, 0.3, 0.3, 0.08, (0, Y0 + R_ * 0.9 + 0.78, 0.3), RUSTH, seg=14)
        cy(P, 0.07, 0.08, 1.3, (0.2, Y0 + R_ * 0.9 + 1.3, -0.1), RUST2, seg=8)
        cy(P, 0.035, 0.04, 1.0, (-0.18, Y0 + R_ * 0.9 + 1.2, 0.6), DK, seg=6)
        sp(P, 0.05, (-0.18, Y0 + R_ * 0.9 + 1.72, 0.6), GLO)
        cy(P, 0.012, 0.015, 1.1, (0.0, Y0 + R_ * 0.9 + 1.4, 0.0), DK, seg=5)
        bx(P, (0.02, 0.3, 0.14), (0.0, Y0 + R_ * 0.9 + 1.9, -0.18), B.M("Rag", (0.06, 0.06, 0.06), 0.0, 0.95, 0.2, 0.5), bevel=0.0)
        sp(P, 0.5, (0, Y0 + R_ * 0.9 + 0.15, -1.6), CLOTH, (1.1, 0.4, 1.6))
        # Bug/Heck: Rohrhalterung für Torpedo, Ruder, Außenborder-Schraube
        for sd in (-1, 1):
            bx(P, (0.55, 0.04, 0.3), (sd * 0.5, Y0, -3.1), RUSTH)
        bx(P, (0.05, 0.9, 0.5), (0, Y0 + 0.3, -3.3), RUSTH)
        cy(P, 0.1, 0.1, 0.4, (0, Y0, -3.9), DK, rot=(math.pi / 2, 0, 0), seg=10)
        for k in range(4):
            a = math.tau * k / 4.0 + 0.4
            bx(P, (0.04, 0.4, 0.14), (math.cos(a) * 0.2, Y0 + math.sin(a) * 0.2, -4.15), ST, rot=(0, a, 0), bevel=0.0)
        S.empty("Muzzle", (0, -3.45, Y0 + 0.1))
        extras.append(bpy.data.objects["Muzzle"])
        finish_unit("minisub", cam=(-7, -8, 4), tgt=(0, 0, 0.4))

elif which == "carrier":
    # Westbund: Flugzeugträger — Flugdeck mit Schrägdeck, Katapulten, Aufzügen, Brückeninsel, Hangar, geparkte Jäger
    hull(20.0, 5.2, 1.5, 1.2, WHT, DECKW, 0.62, TP)
    for sx in (-1.0, 1.0):
        bx(P, (0.04, 0.06, 14.0), (sx * 2.6, 0.7, 0.0), LC, bevel=0.0)
    fit(ports=True, rail=False, port_mat=LC)
    DECKG = B.M("FlightDeck", (0.17, 0.18, 0.2), 0.3, 0.8, 0.4, 0.6)
    MARK = B.M("DeckMark", (0.9, 0.9, 0.84), 0.0, 0.7, 0.3, 0.5)
    YELLOW = B.M("DeckYellow", (0.95, 0.75, 0.1), 0.0, 0.6, 0.3, 0.4)
    # Hangarzone unter dem Flugdeck
    rbx(P, (5.6, 0.7, 15.0), (0, 1.7, -0.5), WHT2, r=0.1)
    for k in range(7):
        for sd in (-1, 1):
            bx(P, (0.06, 0.4, 1.4), (sd * 2.82, 1.7, -6.5 + k * 2.1), DK, bevel=0.0)
            bx(P, (0.07, 0.05, 1.4), (sd * 2.82, 1.5, -6.5 + k * 2.1), LC, bevel=0.0)
    # Flugdeck: Grundriss mit Schrägdeck-Ausleger links, spitz zulaufender Bug
    prof = [(-3.5, -9.7), (3.5, -9.7), (3.8, -2.0), (3.5, 5.0), (2.2, 9.0), (0.0, 9.9), (-2.2, 9.0), (-3.5, 5.0), (-3.9, -1.5), (-5.0, -4.5), (-4.4, -8.6)]
    o = S.prism_xz("FlightDeck", prof, 0.32, (0, 0, 2.15), DECKG, 0.04, rot=(math.pi / 2, 0, 0))
    P.append(o)
    # Stützen unter dem Ausleger
    for z in (-3.5, -6.5):
        bx(P, (0.18, 0.5, 0.18), (-4.3, 1.8, z), ST)
        bx(P, (0.9, 0.12, 0.12), (-4.0, 1.55, z), ST, rot=(0, 0, 0.5))
    y0 = 2.33
    # Markierungen: Mittellinie, Schrägdeck-Landestreifen mit Fangseilen, Katapultbahnen, Bugnummer, Randlinien
    for k in range(14):
        bx(P, (0.14, 0.012, 0.9), (0, y0, -9.0 + k * 1.35), MARK, bevel=0.0)
    for sd in (-1, 1):
        bx(P, (0.08, 0.012, 18.5), (sd * 3.35, y0, 0.0), MARK, bevel=0.0)
    ang = 0.19
    for sd in (-0.7, 0.7):
        bx(P, (0.1, 0.012, 11.0), (-2.2 + sd * 0.8, y0, -3.2), MARK, rot=(0, -ang, 0), bevel=0.0)
    for k in range(5):
        bx(P, (1.6, 0.014, 0.05), (-2.2 - 0.05 * k, y0 + 0.004, -8.0 + k * 1.2), DK, rot=(0, -ang, 0), bevel=0.0)
    for sd in (-0.8, 0.8):
        bx(P, (0.12, 0.014, 9.0), (sd, y0, 4.2), DK, bevel=0.0)
        bx(P, (0.3, 0.03, 0.3), (sd, y0 + 0.01, -0.2), ST)
        for k in range(8):
            bx(P, (0.35, 0.012, 0.08), (sd, y0 + 0.006, 0.3 + k * 1.0), YELLOW, bevel=0.0)
    for dz in (-0.55, 0.55):
        bx(P, (0.35, 0.012, 0.9), (dz * 1.2 + 0.0, y0, 9.0), MARK, rot=(0, 0.0, 0), bevel=0.0) if False else None
    bx(P, (0.7, 0.012, 1.6), (-0.1, y0, 7.2), MARK, bevel=0.0)
    bx(P, (0.5, 0.012, 1.0), (0.0, y0, 7.2), DECKG, bevel=0.0)
    # Strahlabweiser hinter den Katapulten
    for sd in (-0.8, 0.8):
        bx(P, (1.0, 0.45, 0.06), (sd, y0 + 0.2, -1.4), ST, rot=(-0.9, 0, 0), bevel=0.01)
    # Flugdeckaufzüge mit gelber Kante
    for z, x in ((-1.0, -2.6), (4.6, 2.5)):
        bx(P, (1.9, 0.018, 3.1), (x, y0, z), B.M("ElevatorPlate", (0.3, 0.32, 0.34), 0.4, 0.7, 0.4, 0.6), bevel=0.0)
        for sdx in (-1, 1):
            bx(P, (0.05, 0.02, 3.1), (x + sdx * 0.95, y0, z), YELLOW, bevel=0.0)
        for sdz in (-1, 1):
            bx(P, (1.9, 0.02, 0.05), (x, y0, z + sdz * 1.55), YELLOW, bevel=0.0)
    # Geparkte Jäger auf dem Heckdeck
    def jet(x, z, col=WHT2):
        rbx(P, (0.42, 0.3, 1.9), (x, y0 + 0.25, z), col, r=0.1)
        cy(P, 0.0, 0.2, 0.7, (x, y0 + 0.25, z + 1.25), col, rot=(math.pi / 2, 0, 0), seg=12)
        sp(P, 0.2, (x, y0 + 0.42, z + 0.4), GLS, (0.9, 0.9, 2.0))
        bx(P, (1.7, 0.05, 0.8), (x, y0 + 0.22, z - 0.15), col, rot=(0, 0, 0.0))
        for sdx in (-1, 1):
            bx(P, (0.04, 0.45, 0.4), (x + sdx * 0.22, y0 + 0.5, z - 0.85), col, rot=(0, 0, sdx * 0.25))
            bx(P, (0.55, 0.04, 0.3), (x + sdx * 0.4, y0 + 0.22, z - 0.9), col)
        cy(P, 0.16, 0.13, 0.25, (x, y0 + 0.25, z - 1.05), DK, rot=(math.pi / 2, 0, 0), seg=10)
        bx(P, (0.44, 0.02, 0.3), (x, y0 + 0.41, z + 0.0), TP, bevel=0.0)
    for x, z in ((1.9, -6.6), (-0.4, -7.4), (-1.5, -5.4), (1.6, -3.6)):
        jet(x, z)
    # Hubschrauber vorn
    rbx(P, (0.5, 0.45, 1.5), (1.9, y0 + 0.3, 1.0), WHT, r=0.15)
    cy(P, 0.04, 0.05, 0.3, (1.9, y0 + 0.7, 1.0), DK, seg=6)
    bx(P, (2.2, 0.02, 0.1), (1.9, y0 + 0.88, 1.0), DK, bevel=0.0)
    bx(P, (0.1, 0.1, 0.9), (1.9, y0 + 0.35, 0.0 - 0.6), WHT, bevel=0.02)
    # Brückeninsel (Steuerbord): geneigtes Profil, Brücke mit Panoramafenstern, Radarflächen, Radom, Mast
    sb(P, [(-2.4, y0), (-2.1, 3.9), (-0.9, 4.5), (1.0, 4.3), (1.8, 3.4), (2.3, y0)], 0.75, WHT, x=2.95, bevel=0.14)
    sb(P, [(-1.5, 4.5), (-1.2, 5.4), (-0.2, 5.5), (0.7, 4.8)], 0.6, WHT2, x=3.0, bevel=0.1)
    bx(P, (1.1, 0.34, 0.07), (2.4, 5.0, 0.55), GLS, rot=(-0.55, 0, 0), bevel=0.0)
    bx(P, (0.07, 0.34, 1.3), (2.36, 5.0, -0.7), GLS, bevel=0.0)
    for sdz in (-0.55, 0.65):
        rbx(P, (0.07, 0.95, 0.95), (2.23, 3.7, -0.9 + sdz * 0.2), DK, rot=(0, 0, 0.12), r=0.03)
    cy(P, 0.1, 0.14, 1.6, (3.0, 6.4, -0.7), ST, seg=10)
    sp(P, 0.42, (3.0, 7.4, -0.7), WHT, (1, 0.85, 1))
    radar((3.1, 5.55, -1.3), 1.4)
    whip((3.3, 5.5, 0.1), 2.0)
    whip((2.7, 5.5, -1.7), 1.6)
    for sdx in (-1, 1):
        sp(P, 0.07, (3.0 + sdx * 0.35, 5.1, 0.9), LC)
    # Randsponsone mit Nahbereichsabwehr (Turret rechts hinten), Lichtbänder, Rettungsboote, Kran
    for x, z in ((3.55, 7.0), (-3.5, 6.0), (3.7, -8.4)):
        cy(P, 0.3, 0.4, 0.4, (x, 2.0, z), WHT2, seg=14)
        ciws((x, 2.1, z), WHT)
    for k in range(10):
        for sd in (-1, 1):
            sp(P, 0.05, (sd * 3.5, y0 + 0.04, -8.0 + k * 1.9), LC)
    davit_boat(-3.2, 2.0, 1.7, -1.0, ORANGE)
    cy(P, 0.07, 0.09, 1.4, (3.65, 3.3, -3.0), ST, seg=8)
    bx(P, (0.08, 0.08, 1.4), (3.4, 3.9, -2.4), ST, rot=(0.5, 0, 0), bevel=0.0)
    vent((1.3, y0, -9.0))
    # Geschütz: Nahbereichsabwehrgeschütz (CIWS) als drehendes Teil am Bug
    cy(T, 0.34, 0.4, 0.35, (-3.0, y0 + 0.2, 6.0), WHT2, seg=16)
    sp(T, 0.36, (-3.0, y0 + 0.55, 6.0), WHT, (1, 1.1, 1))
    bx(BR, (0.1, 0.1, 0.9), (-3.0, y0 + 0.55, 6.5), DK)
    sp(T, 0.06, (-2.85, y0 + 0.72, 6.0), LR)
    turret_parts((-3.0, y0, 6.0), (-3.0, y0 + 0.55, 6.0), (-3.0, y0 + 0.55, 7.0))
    finish_unit("carrier", cam=(-19, -22, 14), tgt=(0, 0, 1.5))
