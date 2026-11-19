"""Werften (Blender): Marinewerft (West), Schiffswerft (Rot), Schmugglerhafen (Schatten).

blender -b -P tools/blender/make_docks.py -- <projektordner> <west|red|shadow>
Ergebnis: models/buildings/<fraktion>_dock.glb. Vorne (zum Wasser) = -Y; Steg 9 m lang, Oberkante 0,31 m.
Bewegliches Teil "Spin" (Radarschuessel bzw. Drehkran). Besatzung, Flaggen, Rauch setzt models.gd zur Laufzeit.
Die Maße sind in Godot-Koordinaten (vorne +Z, oben +Y) geschrieben und werden umgerechnet.
"""
import math, os, sys, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
import sf_common as S
import sf_bld as B

which, P = B.setup(52)
m = B.mats()
DK, ST, GLS, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH, YE = m.DK, m.ST, m.GLS, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH, m.YE
TP = B.M("TeamPaint", (0.6, 0.62, 0.58), 0.35, 0.55, 0.5, 0.5)
GLO = B.M("GlowOrange", (1.0, 0.7, 0.3), 0.0, 0.3, 0.0, 0.0, 3.0)
PW = B.M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
PIERW = B.M("PierWest", (0.75, 0.8, 0.85), 0.5, 0.4, 0.4, 0.5)
PIERR = B.M("PierRed", (0.4, 0.4, 0.38), 0.2, 0.9, 0.3, 0.8)
PIERS = B.M("PierShadow", (0.4, 0.28, 0.17), 0.0, 0.92, 0.3, 0.8)
PILES = B.M("PileShadow", (0.25, 0.18, 0.12), 0.0, 0.95, 0.3, 0.8)
ROPE = B.M("Rope", (0.65, 0.58, 0.4), 0.0, 0.95, 0.2, 0.5)
REDP = B.M("RedPaint", (0.5, 0.08, 0.06), 0.3, 0.7, 0.4, 0.6)
BRICK = B.M("Brick", (0.34, 0.2, 0.16), 0.0, 0.9, 0.3, 0.8)
CLOTH = B.M("Cloth", (0.3, 0.27, 0.2), 0.0, 0.95, 0.2, 0.6)
GLASSD = B.M("GlassDark", (0.08, 0.16, 0.24), 0.9, 0.06, 0.0, 0.15)
SAWG = B.M("SawGlass", (0.5, 0.65, 0.7), 0.8, 0.1, 0.0, 0.2)
extras = []
W = 7.4
PIER = 9.0


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


def pier(wide, mat, pilem, tires):
    z0 = W * 0.5 + PIER * 0.5 - 0.3
    bx(P, (wide, 0.18, PIER), (0, 0.22, z0), mat)
    for k in range(int(PIER / 1.5) + 1):
        zz = W * 0.5 + 0.2 + k * 1.5
        for sx in (-1.0, 1.0):
            cy(P, 0.16, 0.16, 3.0, (sx * wide * 0.5, -1.0, zz), pilem, seg=8)
            bx(P, (0.3, 0.12, 0.3), (sx * wide * 0.5, 0.32, zz), DK)
            cy(P, 0.09, 0.11, 0.26, (sx * (wide * 0.5 - 0.1), 0.43, zz + 0.6), DK, seg=8)
            if tires:
                cy(P, 0.28, 0.28, 0.2, (sx * (wide * 0.5 + 0.2), 0.05, zz + 0.75), RB, rot=(0, 0, math.pi / 2), seg=10)
            else:
                cy(P, 0.16, 0.16, 0.7, (sx * (wide * 0.5 + 0.2), 0.05, zz + 0.75), RB, rot=(math.pi / 2, 0, 0), seg=8)
        if k > 0:
            for sx in (-1.0, 1.0):
                bx(P, (0.035, 0.035, 1.5), (sx * wide * 0.5, 0.52 + 0.1 * math.sin(k * 1.3), zz - 0.75), ROPE, bevel=0.0)
    for k in range(int(PIER / 0.55)):
        bx(P, (wide, 0.012, 0.03), (0, 0.315, W * 0.5 + 0.2 + k * 0.55), DK, bevel=0.0)
    for sx in (-0.3, 0.3):
        bx(P, (0.04, 1.4, 0.04), (sx, -0.4, W * 0.5 + PIER - 0.5), ST, bevel=0.0)
    for k in range(4):
        bx(P, (0.6, 0.03, 0.03), (0, 0.15 - k * 0.3, W * 0.5 + PIER - 0.5), ST, bevel=0.0)


def lamp(pos, mat):
    cy(P, 0.04, 0.05, 2.2, (pos[0], pos[1] + 1.1, pos[2]), DK, seg=6)
    bx(P, (0.05, 0.05, 0.4), (pos[0], pos[1] + 2.2, pos[2] + 0.15), DK, bevel=0.0)
    sp(P, 0.1, (pos[0], pos[1] + 2.15, pos[2] + 0.34), mat)


def base(mat, ext=0.4):
    bx(P, (W + ext, 3.0, W + ext), (0, -1.3, 0), mat, bevel=0.03)


def spin_part(parts, pivot):
    o = B.part("Spin", parts, gp(pivot))
    extras.append(o)


def finish_dock():
    B.finish("dock", which, cam=(-12, -14, 8), tgt=(0, -3, 2), size=1024, extras=extras)


if which == "west":
    base(CO)
    bx(P, (W + 0.9, 0.14, W + 0.9), (0, 0.02, 0), DK)
    pier(3.4, PIERW, ST, False)
    bx(P, (W * 0.9, 1.8, W * 0.55), (0, 0.9, -W * 0.22), PW)
    bx(P, (W * 0.86, 1.2, 0.08), (0, 1.0, -W * 0.22 + W * 0.28), GLASSD, bevel=0.0)
    sp(P, 1.0, (0, 1.8, -W * 0.22), TP, (W * 0.46, 0.5, W * 0.29))
    for k in range(5):
        bx(P, (0.06, 0.06, W * 0.56), (-W * 0.35 + k * W * 0.175, 2.1, -W * 0.22), ST, bevel=0.0)
    for k in range(4):
        bx(P, (0.06, 1.3, 0.06), (-W * 0.36 + k * W * 0.24, 1.0, -W * 0.22 + W * 0.285), ST, bevel=0.0)
    bx(P, (W * 0.88, 0.06, 0.1), (0, 0.55, -W * 0.22 + W * 0.28 + 0.05), LC, bevel=0.0)
    bx(P, (1.6, 1.3, 0.06), (0, 0.75, -W * 0.22 + W * 0.285), DK, bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.18, 3.6, 0.18), (sx * 1.9, 1.8, W * 0.5 + 2.4), ST)
        bx(P, (0.1, 3.2, 0.08), (sx * 1.9, 1.8, W * 0.5 + 2.9), ST, bevel=0.0)
    bx(P, (4.2, 0.22, 0.3), (0, 3.65, W * 0.5 + 2.4), TP)
    bx(P, (0.5, 0.25, 0.4), (0.6, 3.5, W * 0.5 + 2.4), DK)
    cy(P, 0.02, 0.02, 1.3, (0.6, 2.8, W * 0.5 + 2.4), DK, seg=4)
    bx(P, (0.3, 0.2, 0.3), (0.6, 2.1, W * 0.5 + 2.4), DK)
    for k in range(4):
        sp(P, 0.1, (0, 0.45, W * 0.5 + 1.0 + k * 2.2), LC)
    lamp((-1.5, 0.3, W * 0.5 + 4.5), LC)
    lamp((1.5, 0.3, W * 0.5 + 7.5), LC)
    cb = B.M("ContBlue", (0.25, 0.4, 0.7), 0.3, 0.5, 0.3, 0.4)
    for k in range(3):
        bx(P, (1.0, 0.8, 2.2), (W * 0.3, 0.7 + (k % 2) * 0.82, W * 0.5 - 1.6), cb if k != 1 else TP, rot=(0, 0.04 * k, 0))
    cy(P, 0.08, 0.1, 1.2, (-W * 0.3, 3.3, -W * 0.3), ST, seg=6)
    L = []
    sp(L, 0.6, (-W * 0.3, 3.9, -W * 0.3), WH, (1, 0.4, 1))
    bx(L, (0.05, 0.05, 0.7), (-W * 0.3, 4.2, -W * 0.3 + 0.3), ST, bevel=0.0)
    spin_part(L, (-W * 0.3, 3.9, -W * 0.3))
    finish_dock()

elif which == "red":
    base(CO)
    bx(P, (W + 0.9, 0.14, W + 0.9), (0, 0.02, 0), DK)
    pier(3.6, PIERR, CO, False)
    bx(P, (W * 0.92, 2.2, W * 0.58), (0, 1.1, -W * 0.2), WL)
    for k in range(3):
        zz = -W * 0.2 - W * 0.2 + k * W * 0.2
        bx(P, (W * 0.94, 0.9, 0.12), (0, 2.65, zz - 0.4), TP, rot=(0.45, 0, 0))
        bx(P, (W * 0.9, 0.5, 0.06), (0, 2.6, zz - 0.15), SAWG, bevel=0.0)
    bx(P, (W * 0.46, 1.8, 0.1), (0, 0.95, -W * 0.2 + W * 0.29), DK, bevel=0.0)
    for k in range(6):
        bx(P, (W * 0.46, 0.05, 0.12), (0, 0.3 + k * 0.3, -W * 0.2 + W * 0.295), ST, bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.5, 0.45, 0.06), (sx * W * 0.36, 1.4, -W * 0.2 + W * 0.295), GLO, bevel=0.0)
    cy(P, 0.3, 0.42, 5.2, (W * 0.36, 2.6, -W * 0.38), BRICK, seg=10)
    cy(P, 0.4, 0.4, 0.14, (W * 0.36, 4.6, -W * 0.38), WH, seg=10)
    cy(P, 0.2, 0.26, 3.2, (-2.0, 1.6, W * 0.5 + 0.8), REDP, seg=8)
    L = []
    bx(L, (0.18, 0.18, 4.4), (-2.0, 3.3, W * 0.5 + 0.8 + 1.7), REDP, rot=(-0.15, 0, 0))
    bx(L, (0.14, 0.7, 0.14), (-2.0, 3.5, W * 0.5 + 0.8 - 0.5), DK)
    bx(L, (0.7, 0.5, 0.5), (-2.0, 3.2, W * 0.5 + 0.8 - 0.7), DK)
    cy(L, 0.015, 0.015, 1.8, (-2.0, 2.4, W * 0.5 + 0.8 + 3.6), DK, seg=4)
    spin_part(L, (-2.0, 3.2, W * 0.5 + 0.8))
    bx(P, (1.4, 0.05, 1.0), (0, 2.0, -W * 0.2 + W * 0.3 + 0.1), GLO, bevel=0.0)
    for k in range(3):
        cy(P, 0.16, 0.16, 0.4, (1.4 + k * 0.45, 0.45, W * 0.5 + 0.9), REDP if k % 2 == 0 else WH, seg=8)
    for k in range(2):
        bx(P, (0.7, 0.45, 0.45), (1.5 + k * 0.1, 0.55 + k * 0.45, W * 0.5 + 2.2), B.M("AmmoBox", (0.28, 0.32, 0.22), 0.3, 0.7, 0.4, 0.6), rot=(0, 0.1 * k, 0))
    lamp((1.6, 0.3, W * 0.5 + 4.5), GLO)
    lamp((-1.6, 0.3, W * 0.5 + 7.5), GLO)
    finish_dock()

else:
    base(WD, 0.2)
    pier(3.0, PIERS, PILES, True)
    bx(P, (W * 0.8, 1.9, W * 0.5), (0, 0.95, -W * 0.22), PIERS)
    for k in range(7):
        bx(P, (0.04, 1.9, W * 0.52), (-W * 0.36 + k * W * 0.12, 0.95, -W * 0.22), B.M("PlankDark", (0.3, 0.2, 0.12), 0.0, 0.95, 0.3, 0.8), bevel=0.0)
    bx(P, (W * 0.9, 0.12, W * 0.62), (0, 2.05, -W * 0.22), RS, rot=(0.12, 0, 0.05))
    for k in range(6):
        bx(P, (0.06, 0.05, W * 0.64), (-W * 0.4 + k * W * 0.16, 2.12, -W * 0.22), B.M("TinRib", (0.55, 0.28, 0.14), 0.4, 0.8, 0.8, 0.8), rot=(0.12, 0, 0.05), bevel=0.0)
    bx(P, (1.3, 1.5, 0.08), (W * 0.1, 0.8, -W * 0.22 + W * 0.25), DK, bevel=0.0)
    for sx in (-1.0, 1.0):
        bx(P, (0.6, 0.6, 0.06), (W * 0.1 + sx * 1.6, 1.2, -W * 0.22 + W * 0.255), GLO, bevel=0.0)
        bx(P, (0.34, 0.62, 0.05), (W * 0.1 + sx * 1.6 + sx * 0.38, 1.2, -W * 0.22 + W * 0.26), PIERS, rot=(0, sx * -0.5, 0), bevel=0.0)
    cy(P, 0.14, 0.16, 1.4, (W * 0.3, 2.7, -W * 0.4), ST, seg=8)
    bx(P, (2.6, 0.06, 2.0), (-1.2, 2.3, W * 0.5 + 0.5), CLOTH, rot=(0.15, 0.1, 0.0), bevel=0.0)
    for sx in (-2.3, -0.1):
        cy(P, 0.05, 0.06, 2.3, (sx, 1.15, W * 0.5 + 1.4), DK, seg=6)
    for k in range(4):
        cy(P, 0.28, 0.28, 0.6, (1.4 + (k % 2) * 0.6, 0.5, W * 0.5 + 0.4 + (k // 2) * 0.6), B.M("Barrel%d" % (k % 2), (0.5, 0.25, 0.12) if k % 2 == 0 else (0.2, 0.3, 0.38), 0.3, 0.8, 0.6, 0.7), seg=10)
    cr = B.M("Crate", (0.5, 0.4, 0.25), 0.0, 0.9, 0.3, 0.8)
    bx(P, (0.9, 0.6, 0.7), (1.6, 0.55, W * 0.5 + 2.2), cr, rot=(0, 0.3, 0))
    bx(P, (0.7, 0.5, 0.6), (1.55, 1.05, W * 0.5 + 2.2), cr, rot=(0, -0.2, 0))
    sp(P, 0.7, (-1.5, 0.5, W * 0.5 + 3.2), B.M("Net", (0.35, 0.35, 0.3), 0.0, 0.95, 0.2, 0.6), (1.3, 0.5, 1.0))
    for k in range(3):
        sp(P, 0.12, (-1.9 + k * 0.5, 0.75, W * 0.5 + 3.0 + k * 0.1), B.M("Float", (0.8, 0.8, 0.7), 0.0, 0.9, 0.3, 0.5))
    sp(P, 0.5, (-W * 0.42, 0.3, W * 0.1), B.M("Dinghy", (0.35, 0.25, 0.16), 0.0, 0.9, 0.3, 0.8), (0.9, 0.55, 2.2))
    cy(P, 0.06, 0.09, 4.2, (-W * 0.3, 2.1, -W * 0.3), DK, seg=6)
    bx(P, (0.9, 0.08, 0.9), (-W * 0.3, 4.2, -W * 0.3), PIERS)
    for sx in (-0.4, 0.4):
        bx(P, (0.04, 0.4, 0.04), (-W * 0.3 + sx, 4.4, -W * 0.3), DK, bevel=0.0)
    sp(P, 0.14, (-W * 0.3, 4.45, -W * 0.3), GLO)
    lamp((1.5, 0.3, W * 0.5 + 4.5), GLO)
    lamp((-1.5, 0.3, W * 0.5 + 7.5), GLO)
    finish_dock()
