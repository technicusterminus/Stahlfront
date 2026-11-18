"""Superwaffen für alle drei Fraktionen (Blender).

blender -b -P tools/blender/make_super.py -- <projektordner> <west|red|shadow>
  Westbund      – Orbitalkanone: Kristallturm, drehende Sendeschüssel, Energiepylone, Leuchtring, Leitstand
  Rote Allianz  – Atomsilo: Rundbunker mit Warnstreifen, Silotore, Rakete auf Montageturm, Tanks, Wachtürme
  Schattenfront – Giftraketen-Silo: Rostsilo mit grünem Gift, Raketen auf Holzschienen, Gerüst, Fässer, Totenkopf
"""
import math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S
import sf_bld as B

which, P = B.setup(16)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH

# ================================================================ WESTBUND
if which == "west":
    PW = B.M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
    PG = B.M("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
    TP = B.M("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
    CRY = B.M("Crystal", (0.5, 0.9, 1.0), 0.0, 0.15, 0.0, 0.0, 7.0)
    P.append(S.box("Slab", (9.0, 8.6, 0.3), (0, 0, 0.0), CO, 0.03))
    P.append(S.cyl("Platform", 3.4, 0.5, (0.0, 0.5, 0.5), PG, 40, 0.03))
    P.append(S.cyl("PlatformTop", 3.2, 0.08, (0.0, 0.5, 0.78), PW, 40))
    P.append(B.ring("PlatformRing", 3.3, 3.12, 0.05, (0.0, 0.5, 0.78), LC, 40))
    # Zentraler Turm aus Segmenten mit Kristall
    for k, (r, h) in enumerate(((1.2, 0.8), (0.95, 1.0), (0.75, 1.1), (0.55, 1.0))):
        P.append(S.cyl("TowerSeg", r, h, (0.0, 0.5, 1.2 + sum(x[1] for x in ((1.2, 0.8), (0.95, 1.0), (0.75, 1.1), (0.55, 1.0))[:k]) + h / 2), PW if k % 2 == 0 else PG, 24, 0.02, r2=r * 0.9))
        P.append(B.ring("TowerBand", r + 0.04, r - 0.02, 0.08, (0.0, 0.5, 1.2 + sum(x[1] for x in ((1.2, 0.8), (0.95, 1.0), (0.75, 1.1), (0.55, 1.0))[:k]) + h), LC, 24))
    P.append(S.cyl("CrystalLow", 0.42, 0.9, (0.0, 0.5, 5.35), CRY, 8, r2=0.0, rot=(math.pi, 0, 0)))
    P.append(S.cyl("CrystalHigh", 0.42, 1.2, (0.0, 0.5, 6.4), CRY, 8, r2=0.0))
    # Drehende Sendeschüssel auf Seitenmast (Spin)
    P.append(S.cyl("DishMast", 0.14, 2.0, (-2.4, 2.2, 1.9), ST, 10))
    dish = [S.sphere("Dish", 1.1, (-2.4, 2.2, 3.4), PW, scale=(1, 1, 0.25), segs=24, rings=10), S.cyl("DishFeed", 0.04, 0.9, (-2.4, 2.2, 3.85), ST, 6), S.sphere("DishTip", 0.12, (-2.4, 2.2, 4.35), CRY, segs=10, rings=6)]
    dish[0].rotation_euler = (0.5, 0, 0)
    spin = B.part("Spin", dish, (-2.4, 2.2, 3.2))
    # Vier Pylone mit Energiebögen
    for (px, py) in ((-2.7, -1.5), (2.7, -1.5), (-2.7, 2.2), (2.7, 2.2)):
        P.append(S.cyl("PylonBase", 0.35, 0.4, (px, py, 0.35), PG, 12))
        P.append(S.cyl("Pylon", 0.15, 2.8, (px, py, 1.7), ST, 10))
        for j in range(4):
            P.append(S.cyl("Coil", 0.28 - j * 0.03, 0.1, (px, py, 0.9 + j * 0.55), PW, 14))
        P.append(S.sphere("PylonTip", 0.24, (px, py, 3.25), LC, segs=14, rings=8))
        dx, dy = -px, 0.5 - py
        ln = math.hypot(dx, dy) * 0.58
        P.append(S.cyl("Cable", 0.05, ln, (px + dx * 0.29, py + dy * 0.29, 0.35), LC, 8, rot=(math.pi / 2, 0, math.atan2(dy, dx) + math.pi / 2)))
    # Leitstand mit Glasfront und Treppe vorn
    P.append(S.box("Control", (2.6, 1.6, 1.2), (0.0, -3.3, 0.9), PW, 0.04))
    P.append(S.box("ControlGlass", (2.3, 0.05, 0.6), (0.0, -4.12, 1.05), GLS, 0.0))
    P.append(S.box("ControlRoof", (2.8, 1.8, 0.1), (0.0, -3.3, 1.55), TP, 0.02))
    P.append(S.box("ControlStrip", (2.84, 1.84, 0.05), (0.0, -3.3, 1.46), LC, 0.0))
    for k in range(3):
        P.append(S.box("Stair", (2.0, 0.3, 0.07 * (3 - k)), (0, -4.3 - k * 0.3, 0.15 + 0.035 * (3 - k)), CO, 0.01))
    for k in range(12):
        a = k * math.tau / 12
        P.append(S.cyl("LightPost", 0.04, 0.7, (math.cos(a) * 3.6, 0.5 + math.sin(a) * 3.6, 0.5), ST, 6))
        P.append(S.sphere("LightBall", 0.07, (math.cos(a) * 3.6, 0.5 + math.sin(a) * 3.6, 0.9), LC, segs=8, rings=4))
    P.append(S.cyl("FlagPole", 0.045, 3.0, (4.0, -3.7, 1.5), ST, 8))
    P.append(S.box("Flag", (0.04, 1.0, 0.65), (4.0, -3.2, 2.7), TP, 0.0))
    B.finish("super", "west", (-11.0, -13.0, 8.8), (0, 0.5, 2.6), extras=(spin,))

# ================================================================ ROTE ALLIANZ
elif which == "red":
    TP = B.M("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
    GD = B.M("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
    RD = B.M("RedBanner", (0.65, 0.08, 0.06), 0.0, 0.8, 0.2, 0.5)
    OL = B.M("OliveBox", (0.28, 0.32, 0.2), 0.3, 0.7, 0.5, 0.7)
    MIS = B.M("Missile", (0.8, 0.8, 0.76), 0.5, 0.4, 0.4, 0.4)
    P.append(S.box("Slab", (9.0, 8.6, 0.3), (0, 0, 0.0), CD, 0.03))
    # Rundbunker mit Warnstreifenring und zwei Silotoren
    P.append(S.cyl("SiloBase", 3.1, 0.6, (-0.6, 0.6, 0.55), CD, 40, 0.03))
    P.append(S.cyl("SiloBody", 2.9, 1.0, (-0.6, 0.6, 1.3), CO, 40, 0.03))
    for k in range(24):
        a = k * math.tau / 24
        P.append(S.box("Hazard", (0.5, 0.06, 0.28), (-0.6 + math.cos(a) * 2.93, 0.6 + math.sin(a) * 2.93, 1.0), YE if k % 2 else DK, 0.0, rot=(0, 0, a + math.pi / 2)))
    P.append(S.cyl("SiloRoof", 2.7, 0.3, (-0.6, 0.6, 1.95), CD, 40, 0.03))
    for sx in (-1, 1):
        P.append(S.box("SiloDoor", (1.3, 2.4, 0.22), (-0.6 + sx * 0.67, 0.6, 2.2), DK, 0.03))
        for k in range(5):
            P.append(S.box("DoorHazard", (0.2, 2.3, 0.04), (-0.6 + sx * (0.17 + k * 0.25), 0.6, 2.33), YE if k % 2 else DK, 0.0))
    P.append(S.box("DoorSeam", (0.06, 2.5, 0.26), (-0.6, 0.6, 2.2), RD, 0.0))
    P.append(B.star(0.08, (-0.6, -2.3, 1.4), GD))
    P[-1].rotation_euler = (math.pi / 2, 0, 0)
    P[-1].scale = (2.0, 2.0, 2.0)
    for k in range(10):
        a = k * math.tau / 10
        P.append(S.sphere("WarnLight", 0.09, (-0.6 + math.cos(a) * 2.6, 0.6 + math.sin(a) * 2.6, 2.4), LR, segs=8, rings=5))
    # Rakete auf Montageturm (Gitterturm, Rakete mit Spitze und Sternen)
    P.append(S.box("Pad", (2.0, 2.0, 0.2), (3.0, 1.0, 0.3), CD, 0.03))
    P.append(S.cyl("Missile", 0.38, 3.8, (3.0, 1.0, 2.3), MIS, 18))
    P.append(S.cyl("MissileNose", 0.38, 1.2, (3.0, 1.0, 4.8), RD, 18, r2=0.06))
    for k in range(4):
        a = k * math.pi / 2
        P.append(S.box("Fin", (0.06, 0.8, 0.9), (3.0 + math.cos(a) * 0.55, 1.0 + math.sin(a) * 0.55, 0.8), RD, 0.01, rot=(0, 0, a)))
    P.append(S.cyl("MissileBand", 0.4, 0.2, (3.0, 1.0, 3.3), RD, 18))
    for lx in (2.4, 3.6):
        for ly in (0.4, 1.6):
            P.append(S.box("GantryLeg", (0.1, 0.1, 5.0), (lx, ly, 2.8), ST, 0.01))
    for k in range(6):
        z = 0.9 + k * 0.8
        P.append(S.box("GantryBarX", (1.3, 0.05, 0.05), (3.0, 0.4, z), ST, 0.0))
        P.append(S.box("GantryBarY", (0.05, 1.3, 0.05), (2.4, 1.0, z), ST, 0.0))
        P.append(S.box("GantryBarX2", (1.3, 0.05, 0.05), (3.0, 1.6, z), ST, 0.0))
    P.append(S.box("GantryArm", (0.9, 0.12, 0.12), (2.75, 1.0, 3.9), YE, 0.01))
    # Tanks, Rohre, Warnschilder, Wachtürme, Fahnen
    for k in range(2):
        P.append(S.cyl("Tank", 0.6, 1.8, (-3.9, -1.8 + k * 1.5, 1.1), OL, 20))
        P.append(S.sphere("TankTop", 0.6, (-3.9, -1.8 + k * 1.5, 2.0), OL, scale=(1, 1, 0.4), segs=20, rings=8))
        P.append(S.cyl("TankBand", 0.62, 0.12, (-3.9, -1.8 + k * 1.5, 1.2), YE, 20))
    P.append(S.cyl("Pipe", 0.12, 3.0, (-2.5, -1.0, 0.45), ST, 10, rot=(0, math.pi / 2, 0)))
    for (tx, ty) in ((-3.9, 3.4), (3.9, -3.4)):
        for sx in (-0.3, 0.3):
            for sy in (-0.3, 0.3):
                P.append(S.box("TowerLeg", (0.1, 0.1, 3.0), (tx + sx, ty + sy, 1.8), CD, 0.02))
        P.append(S.box("TowerCab", (1.0, 1.0, 0.7), (tx, ty, 3.5), OL, 0.03))
        P.append(S.box("TowerRoof", (1.3, 1.3, 0.1), (tx, ty, 3.95), TP, 0.02))
        P.append(S.cyl("Searchlight", 0.15, 0.25, (tx, ty - 0.55, 3.55), ST, 10, rot=(math.radians(70), 0, 0)))
    for k in range(3):
        P.append(S.prism_xz("Sign", [(-0.3, 0), (0.3, 0), (0, 0.5)], 0.04, (-2.0 + k * 1.2, -3.7, 0.9), YE, 0.0))
        P.append(S.cyl("SignPost", 0.03, 0.8, (-2.0 + k * 1.2, -3.7, 0.45), ST, 6))
    for sx in (-4.0, 4.0):
        P.append(S.cyl("FlagPole", 0.05, 3.6, (sx, -0.4, 1.8), ST, 8))
        P.append(S.box("Flag", (0.04, 1.2, 0.8), (sx, 0.1, 3.2), RD, 0.0))
    B.finish("super", "red", (-11.0, -13.0, 8.8), (0, 0.6, 2.2))

# ================================================================ SCHATTENFRONT
else:
    CV = B.M("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
    TP = B.M("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
    GD = B.M("Ground", (0.42, 0.36, 0.25), 0.0, 1.0, 0.1, 0.8)
    TIN = B.M("Tin", (0.55, 0.52, 0.47), 0.7, 0.6, 0.6, 0.7)
    TOX = B.M("Toxic", (0.4, 1.0, 0.25), 0.0, 0.2, 0.0, 0.0, 5.0)
    TXB = B.M("ToxBarrel", (0.3, 0.45, 0.2), 0.4, 0.6, 0.6, 0.7)
    GM = B.M("GreenMissile", (0.35, 0.4, 0.28), 0.5, 0.6, 0.6, 0.7)
    P.append(S.box("Yard", (9.0, 8.6, 0.14), (0, 0, 0.0), GD, 0.0))
    # Rostsilo aus Altmetall mit offenem Top und grünem Gift
    P.append(S.cyl("Silo", 1.7, 2.8, (-1.4, 0.8, 1.5), RS, 24))
    for k in range(4):
        P.append(S.cyl("SiloBand", 1.74, 0.12, (-1.4, 0.8, 0.5 + k * 0.7), DK, 24))
    for k in range(6):
        P.append(S.box("SiloPatch", (0.7, 0.05, 0.6), (-1.4 + math.cos(k * 1.0) * 1.72, 0.8 + math.sin(k * 1.0) * 1.72, 1.0 + (k % 3) * 0.6), TIN, 0.01, rot=(0, 0, k * 1.0 + math.pi / 2)))
    P.append(B.ring("SiloRim", 1.75, 1.45, 0.14, (-1.4, 0.8, 2.95), RS, 24))
    P.append(S.cyl("Poison", 1.45, 0.06, (-1.4, 0.8, 2.85), TOX, 24))
    for k in range(6):
        P.append(S.sphere("Bubble", 0.12 + (k % 3) * 0.04, (-1.4 + math.cos(k * 1.3) * 0.7, 0.8 + math.sin(k * 1.3) * 0.7, 2.95), TOX, segs=8, rings=5))
    P.append(S.cyl("DrainPipe", 0.15, 2.2, (-0.1, -0.4, 0.8), ST, 8, rot=(0, math.pi / 2 * 0.0, 0.0)))
    # Holzgerüst mit Leiter, Seil, Totenkopf-Schild
    for sx in (-3.4, -1.6):
        for sy in (2.4, 3.6):
            P.append(S.cyl("ScaffPost", 0.08, 3.4, (sx, sy, 1.7), WD, 6))
    for z in (1.0, 2.0, 3.0):
        P.append(S.box("ScaffBeamX", (1.9, 0.08, 0.08), (-2.5, 2.4, z), WL, 0.01))
        P.append(S.box("ScaffBeamY", (0.08, 1.3, 0.08), (-1.6, 3.0, z), WL, 0.01))
    P.append(S.box("ScaffDeck", (1.9, 1.3, 0.08), (-2.5, 3.0, 3.0), WL, 0.01))
    for k in range(7):
        P.append(S.box("Rung", (0.4, 0.03, 0.03), (-3.45, 3.0, 0.4 + k * 0.45), WD, 0.0))
    P.append(S.sphere("Skull", 0.3, (-2.5, 1.75, 2.0), WH, segs=12, rings=8))
    P.append(S.box("SkullJaw", (0.3, 0.2, 0.15), (-2.5, 1.75, 1.7), WH, 0.02))
    for sx in (-0.12, 0.12):
        P.append(S.sphere("SkullEye", 0.07, (-2.5 + sx, 1.5, 2.05), DK, segs=8, rings=4))
    P.append(S.box("SkullBoard", (1.0, 0.06, 0.9), (-2.5, 1.82, 1.9), WD, 0.02))
    # Drei Raketen auf Holzschienen mit Giftgrünen Köpfen, Stützböcke
    for k, rx in enumerate((1.4, 2.4, 3.4)):
        P.append(S.box("RailL", (0.1, 2.8, 0.1), (rx - 0.25, 0.6, 1.3), WD, 0.02, rot=(-0.55, 0, 0)))
        P.append(S.box("RailR", (0.1, 2.8, 0.1), (rx + 0.25, 0.6, 1.3), WD, 0.02, rot=(-0.55, 0, 0)))
        P.append(S.cyl("Rocket", 0.22, 2.4, (rx, 0.4, 1.7), GM, 12, rot=(-0.55 + math.pi / 2 - math.pi / 2 + 0.0, 0, 0) if False else (math.pi / 2 - 0.55, 0, 0)))
        P.append(S.sphere("Warhead", 0.24, (rx, -0.55, 2.35), TOX, segs=12, rings=8))
        P.append(S.box("RocketFin", (0.4, 0.04, 0.4), (rx, 1.3, 1.0), RS, 0.01, rot=(-0.55, 0, 0)))
        P.append(S.box("Trestle", (0.7, 0.1, 1.0), (rx, 1.7, 0.7), WD, 0.02, rot=(0, 0, 0.0)))
    # Giftfässer, Kisten, Gasmasken-Schild, Krane und grüne Lampen
    for k in range(8):
        P.append(S.cyl("ToxBarrel", 0.27, 0.85, (-3.6 + (k % 4) * 0.6, -2.4 - (k // 4) * 0.62, 0.55), TXB if k % 3 else RS, 12))
        P.append(S.box("ToxMark", (0.2, 0.03, 0.2), (-3.6 + (k % 4) * 0.6, -2.4 - (k // 4) * 0.62 - 0.27, 0.65), YE, 0.0))
    for k in range(3):
        P.append(S.box("Crate", (0.55, 0.42, 0.4), (1.6 + k * 0.6, -2.6, 0.35), WL if k % 2 else RS, 0.03, rot=(0, 0, random.uniform(-0.2, 0.2))))
    P.append(S.cyl("CraneMast", 0.1, 3.4, (3.8, -1.2, 1.7), RS, 10))
    P.append(S.box("CraneArm", (0.1, 2.6, 0.12), (3.8, -2.4, 3.3), RS, 0.02, rot=(0.2, 0, 0)))
    P.append(S.cyl("CraneRope", 0.02, 1.4, (3.8, -3.6, 2.6), DK, 6))
    P.append(S.box("CraneBarrel", (0.4, 0.4, 0.5), (3.8, -3.6, 1.8), TXB, 0.04))
    for (lx, ly) in ((-3.9, -3.6), (0.4, -3.8), (4.0, 0.8)):
        P.append(S.cyl("LampPost", 0.04, 1.9, (lx, ly, 0.95), WD, 6))
        P.append(S.sphere("GreenLamp", 0.14, (lx, ly, 2.0), TOX, segs=10, rings=6))
    for k in range(4):
        P.append(S.cyl("Tire", 0.34, 0.2, (4.0, 2.8, 0.2 + k * 0.2), RB, 14))
    P.append(S.cyl("FlagPole", 0.045, 2.6, (-4.0, -0.2, 1.3), WD, 8))
    P.append(S.box("Flag", (0.04, 0.9, 0.55), (-4.0, 0.2, 2.3), B.M("BlackFlag", (0.05, 0.05, 0.05), 0.0, 0.9, 0.2, 0.5), 0.0))
    B.finish("super", "shadow", (-11.0, -13.0, 8.4), (0, 0.4, 1.8), ground=(0.45, 0.38, 0.27))
