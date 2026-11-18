"""Flugfelder für alle drei Fraktionen (Blender).

blender -b -P tools/blender/make_airfield.py -- <projektordner> <west|red|shadow>
  Westbund      – Flugfeld: Landeplätze mit Leuchtring, Glasturm mit Radar, Hangar, Tankkugeln, Windsack
  Rote Allianz  – Hubschrauberbasis: Betonvorfeld mit Kreisen, Walmdach-Hangars, Backsteinturm, Tankwagen, Tarnnetz
  Schattenfront – Schotterpiste: Fasslinie, Zelthangar, Holzturm mit Scheinwerfer, Flugzeugwrack, Windsack aus Stoff
"""
import math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S
import sf_bld as B

which, P = B.setup(15)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH

def windsock(x, y, h, mat_pole, mat_sock, mat_band):
    P.append(S.cyl("SockPole", 0.05, h, (x, y, h / 2), mat_pole, 8))
    P.append(S.cyl("SockRing", 0.22, 0.05, (x, y - 0.05, h), mat_pole, 12, rot=(math.pi / 2, 0, 0)))
    for k in range(4):
        P.append(S.cyl("Sock%d" % k, 0.2 - k * 0.035, 0.28, (x + 0.0 + k * 0.0, y - 0.3 - k * 0.27, h - k * 0.02), mat_sock if k % 2 == 0 else mat_band, 12, rot=(math.pi / 2, 0, 0)))

# ================================================================ WESTBUND
if which == "west":
    PW = B.M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
    PG = B.M("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
    TP = B.M("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
    AS = B.M("Asphalt", (0.11, 0.115, 0.12), 0.0, 0.85, 0.2, 0.3)
    OR = B.M("Orange", (1.0, 0.45, 0.1), 0.0, 0.6, 0.2, 0.3)
    P.append(S.box("Slab", (9.0, 8.6, 0.3), (0, 0, 0.0), CO, 0.03))
    P.append(S.box("Apron", (8.4, 5.0, 0.12), (-0.2, -1.5, 0.22), AS, 0.01))
    # Zwei Landeplätze mit Leuchtring, Mittelkreuz, Randfeuer
    for px in (-2.4, 0.6):
        P.append(S.cyl("PadBase", 1.55, 0.06, (px, -2.0, 0.3), PG, 36))
        P.append(B.ring("PadRing", 1.45, 1.3, 0.04, (px, -2.0, 0.34), LC, 36))
        P.append(S.box("PadH1", (0.16, 1.0, 0.03), (px - 0.3, -2.0, 0.34), LW, 0.0))
        P.append(S.box("PadH2", (0.16, 1.0, 0.03), (px + 0.3, -2.0, 0.34), LW, 0.0))
        P.append(S.box("PadH3", (0.76, 0.16, 0.03), (px, -2.0, 0.34), LW, 0.0))
        for k in range(8):
            a = k * math.tau / 8
            P.append(S.sphere("PadLight", 0.06, (px + math.cos(a) * 1.6, -2.0 + math.sin(a) * 1.6, 0.34), LC, segs=8, rings=4))
    # Leuchtstreifen am Rollweg
    for k in range(9):
        P.append(S.box("TaxiLight", (0.4, 0.06, 0.03), (-3.4 + k * 0.9, -4.0, 0.3), LC if k % 2 else LW, 0.0))
    # Gewölbehangar mit Rippen, Tor, Dachlicht
    P.append(S.cyl("Hangar", 1.9, 3.6, (2.5, 2.0, 1.0), PW, 28, rot=(math.pi / 2, 0, 0)))
    P[-1].dimensions = (3.8, 3.6, 2.2) if False else P[-1].dimensions
    P.append(S.box("HangarBase", (3.8, 3.7, 0.5), (2.5, 2.0, 0.4), PG, 0.03))
    P.append(S.box("HangarDoor", (2.8, 0.06, 1.6), (2.5, 0.2, 1.1), DK, 0.02))
    for k in range(5):
        P.append(B.ring("HangarRib", 1.93, 1.86, 0.1, (2.5, 0.5 + k * 0.75, 1.0), TP, 28, rot=(math.pi / 2, 0, 0)))
    P.append(S.box("HangarLight", (0.5, 3.0, 0.05), (2.5, 2.0, 2.92), LC, 0.0))
    # Glasturm mit Radar (Spin) und Leitstand
    P.append(S.cyl("TowerShaft", 0.5, 3.6, (-3.4, 2.4, 1.9), PW, 12))
    P.append(S.cyl("TowerBand", 0.54, 0.1, (-3.4, 2.4, 2.4), LC, 12))
    P.append(S.cyl("TowerCab", 0.95, 0.9, (-3.4, 2.4, 4.0), GLS, 12, r2=1.2))
    P.append(S.cyl("TowerRoof", 1.3, 0.14, (-3.4, 2.4, 4.52), TP, 12))
    P.append(S.cyl("DishMast", 0.05, 0.5, (-3.4, 2.4, 4.8), ST, 8))
    bar = [S.box("RadarBar", (1.3, 0.1, 0.45), (-3.4, 2.4, 5.1), PW, 0.02), S.box("RadarFeed", (0.12, 0.12, 0.28), (-3.4, 2.4, 4.92), ST, 0.01)]
    spin = B.part("Spin", bar, (-3.4, 2.4, 5.0))
    P.append(S.box("TowerBase", (1.8, 1.4, 0.8), (-3.4, 2.4, 0.6), PG, 0.03))
    # Tankkugeln, Betankungsportal, Windsack, Pylone
    for k, ty in enumerate((2.5, 3.4)):
        P.append(S.sphere("Tank", 0.55, (-1.6 + k * 0.0, ty, 0.95) if False else (-1.2, 2.0 + k * 1.2, 0.95), PW, segs=20, rings=12))
        for j in range(3):
            a = j * math.tau / 3
            P.append(S.cyl("TankLeg", 0.05, 0.6, (-1.2 + math.cos(a) * 0.38, 2.0 + k * 1.2 + math.sin(a) * 0.38, 0.5), ST, 6))
        P.append(S.cyl("TankBand", 0.56, 0.06, (-1.2, 2.0 + k * 1.2, 0.95), LC, 20))
    P.append(S.cyl("Hose", 0.04, 1.8, (-1.2, 1.3, 0.5), OR, 6, rot=(math.pi / 2, 0, 0)))
    for sx in (-0.0, 1.6):
        P.append(S.box("GantryLeg", (0.14, 0.14, 1.8), (sx - 1.0, -0.5, 1.2), ST, 0.01))
    P.append(S.box("GantryBeam", (1.9, 0.18, 0.18), (-0.2, -0.5, 2.2), YE, 0.02))
    windsock(4.0, -3.6, 2.4, ST, OR, WH)
    for (lx, ly) in ((-4.2, -4.0), (4.2, -4.0)):
        P.append(S.cyl("Pole", 0.05, 2.6, (lx, ly, 1.3), ST, 8))
        P.append(S.box("Lamp", (0.55, 0.18, 0.07), (lx, ly - 0.15, 2.62), LW, 0.0))
    P.append(S.cyl("FlagPole", 0.045, 3.0, (4.1, -1.0, 1.5), ST, 8))
    P.append(S.box("Flag", (0.04, 1.0, 0.65), (4.1, -0.5, 2.7), TP, 0.0))
    B.finish("airfield", "west", (-11.0, -13.0, 8.6), (0, 0.0, 1.3), extras=(spin,))

# ================================================================ ROTE ALLIANZ
elif which == "red":
    BK = B.M("Brick", (0.5, 0.27, 0.2), 0.0, 0.9, 0.4, 0.8)
    TP = B.M("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
    GD = B.M("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
    RD = B.M("RedBanner", (0.65, 0.08, 0.06), 0.0, 0.8, 0.2, 0.5)
    OL = B.M("OliveBox", (0.28, 0.32, 0.2), 0.3, 0.7, 0.5, 0.7)
    CN = B.M("CamoNet", (0.3, 0.36, 0.2), 0.0, 0.95, 0.2, 0.6)
    P.append(S.box("Slab", (9.0, 8.6, 0.3), (0, 0, 0.0), CD, 0.03))
    # Vorfeld mit gelben Landekreisen und Hubschrauber-Markierung
    for px in (-2.2, 0.8):
        P.append(B.ring("PadRing", 1.5, 1.38, 0.03, (px, -2.0, 0.32), YE, 36))
        P.append(S.box("PadBar1", (0.14, 1.0, 0.03), (px - 0.3, -2.0, 0.32), YE, 0.0))
        P.append(S.box("PadBar2", (0.14, 1.0, 0.03), (px + 0.3, -2.0, 0.32), YE, 0.0))
        P.append(S.box("PadBar3", (0.74, 0.14, 0.03), (px, -2.0, 0.32), YE, 0.0))
    # Zwei Walmdach-Hangars mit Sternen, Rolltoren, Oberlicht
    for hx in (-2.6, 1.0):
        P.append(S.box("Hangar", (3.0, 2.6, 1.7), (hx, 2.5, 1.15), CO, 0.03))
        P.append(S.box("HangarPlinth", (3.15, 2.75, 0.3), (hx, 2.5, 0.4), CD, 0.02))
        P.append(S.prism_xz("HangarRoof", [(-1.6, 0), (1.6, 0), (0, 1.0)], 2.9, (hx, 2.5, 2.0), TP, 0.02, rot=(0, 0, math.pi / 2)) if False else S.prism_xz("HangarRoof", [(-1.6, 0), (1.6, 0), (0, 1.0)], 2.9, (hx, 2.5, 2.0), TP, 0.02))
        P.append(S.box("HangarDoor", (2.2, 0.08, 1.3), (hx, 1.17, 1.05), DK, 0.02))
        for k in range(6):
            P.append(S.box("DoorSlat", (2.2, 0.1, 0.05), (hx, 1.14, 0.45 + k * 0.2), ST, 0.0))
        P.append(B.star(0.06, (hx, 1.12, 1.95), GD))
        P[-1].rotation_euler = (math.pi / 2, 0, 0)
        for k in range(3):
            P.append(S.box("Skylight", (0.5, 0.4, 0.06), (hx - 0.8 + k * 0.8, 2.5, 2.6 + (0.5 if k == 1 else 0.3)), GLS, 0.0))
    # Backsteinturm mit Glaskanzel, Treppe, Scheinwerfer
    P.append(S.box("TowerBody", (1.3, 1.3, 2.4), (3.3, -0.3, 1.5), BK, 0.03))
    P.append(S.box("TowerCab", (1.7, 1.7, 0.8), (3.3, -0.3, 3.1), GLS, 0.03))
    for k in range(4):
        P.append(S.box("CabPost", (0.07, 0.07, 0.85), (3.3 + (-0.8 if k % 2 else 0.8), -0.3 + (-0.8 if k < 2 else 0.8), 3.1), CD, 0.0))
    P.append(S.box("TowerRoof", (2.0, 2.0, 0.14), (3.3, -0.3, 3.55), TP, 0.02))
    P.append(S.cyl("Searchlight", 0.2, 0.28, (3.3, -1.3, 3.2), ST, 12, rot=(math.radians(70), 0, 0)))
    P.append(S.cyl("TowerMast", 0.04, 1.4, (3.3, -0.3, 4.3), ST, 6))
    P.append(S.sphere("TowerLight", 0.08, (3.3, -0.3, 5.0), LR, segs=10, rings=6))
    for k in range(7):
        P.append(S.box("Rung", (0.4, 0.03, 0.03), (3.3, -1.0, 0.5 + k * 0.4), ST, 0.0))
    # Tanklager mit Tankwagen, Fässer, Tarnnetz über Abstellplatz
    P.append(S.cyl("FuelTank", 0.6, 1.4, (-4.0, 0.6, 1.0), OL, 20))
    P.append(S.sphere("FuelTankTop", 0.6, (-4.0, 0.6, 1.7), OL, scale=(1, 1, 0.4), segs=20, rings=8))
    P.append(S.cyl("FuelBand", 0.62, 0.1, (-4.0, 0.6, 1.1), RD, 20))
    P.append(S.box("Truck", (0.9, 2.0, 0.8), (-4.0, -1.5, 0.75), OL, 0.04))
    P.append(S.cyl("TruckTank", 0.4, 1.4, (-4.0, -1.3, 1.35), TP, 16, rot=(math.pi / 2, 0, 0)))
    P.append(S.box("TruckCab", (0.85, 0.7, 0.75), (-4.0, -2.3, 1.0), OL, 0.04))
    for sy in (-2.1, -0.9):
        for sx in (-4.45, -3.55):
            P.append(S.cyl("TruckWheel", 0.22, 0.14, (sx, sy, 0.35), RB, 12, rot=(0, math.pi / 2, 0)))
    for k in range(4):
        P.append(S.cyl("Barrel", 0.26, 0.8, (-4.2 + (k % 2) * 0.55, 3.0 - (k // 2) * 0.6, 0.55), RS if k % 2 else OL, 12))
    for (px, py) in ((-4.0, 3.6), (-2.6, 3.6)):
        pass
    # Windsack, Fahne, Lampen, Zaun
    windsock(4.0, -3.4, 2.4, ST, RD, B.M("WhiteSock", (0.85, 0.85, 0.82), 0.0, 0.8, 0.2, 0.4))
    P.append(S.cyl("FlagPole", 0.05, 3.6, (-4.2, -3.6, 1.8), ST, 8))
    P.append(S.box("Flag", (0.04, 1.2, 0.8), (-4.2, -3.1, 3.2), RD, 0.0))
    for k in range(10):
        P.append(S.cyl("FencePost", 0.04, 0.9, (-3.9 + k * 0.86, -4.15, 0.5), WD, 6))
    for z in (0.5, 0.8):
        P.append(S.box("Wire", (7.6, 0.02, 0.02), (-0.2, -4.15, z), DK, 0.0))
    for (lx, ly) in ((-3.9, 2.0), (3.9, 3.4)):
        P.append(S.cyl("Pole", 0.05, 2.6, (lx, ly, 1.3), ST, 8))
        P.append(S.box("Lamp", (0.55, 0.18, 0.07), (lx, ly - 0.15, 2.62), LW, 0.0))
    B.finish("airfield", "red", (-11.0, -13.0, 8.8), (0, 0.4, 1.4))

# ================================================================ SCHATTENFRONT
else:
    CV = B.M("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
    CV2 = B.M("CanvasGreen", (0.35, 0.37, 0.24), 0.0, 0.95, 0.2, 0.6)
    CV3 = B.M("CanvasRed", (0.5, 0.2, 0.15), 0.0, 0.95, 0.2, 0.6)
    TP = B.M("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
    GD = B.M("Ground", (0.42, 0.36, 0.25), 0.0, 1.0, 0.1, 0.8)
    GV = B.M("Gravel", (0.5, 0.45, 0.36), 0.0, 1.0, 0.1, 0.9)
    TIN = B.M("Tin", (0.55, 0.52, 0.47), 0.7, 0.6, 0.6, 0.7)
    P.append(S.box("Yard", (9.0, 8.6, 0.14), (0, 0, 0.0), GD, 0.0))
    P.append(S.box("Strip", (8.4, 3.0, 0.08), (0, -2.2, 0.14), GV, 0.0))
    # Fasslinie am Pistenrand, Brettermarkierungen
    for k in range(10):
        P.append(S.cyl("EdgeBarrel", 0.2, 0.5, (-3.8 + k * 0.85, -3.8, 0.4), RS if k % 3 else B.M("BarrelBlue", (0.2, 0.3, 0.38), 0.5, 0.7, 0.6, 0.7), 10))
        P.append(S.cyl("EdgeBarrel2", 0.2, 0.5, (-3.8 + k * 0.85, -0.6, 0.4), RS if (k + 1) % 3 else B.M("BarrelBlue", (0.2, 0.3, 0.38), 0.5, 0.7, 0.6, 0.7), 10))
    for k in range(7):
        P.append(S.box("Mark", (0.6, 0.15, 0.03), (-3.0 + k * 1.0, -2.2, 0.2), WH, 0.0))
    # Großes Zelt als Hangar mit Planenklappe
    P.append(S.prism_xz("HangarTent", [(-2.1, 0), (2.1, 0), (0, 2.4)], 3.4, (2.3, 2.5, 0.1), CV2, 0.0))
    P.append(S.box("TentFlap", (1.6, 0.05, 1.7), (2.3, 0.8, 0.95), DK, 0.0))
    P.append(S.prism_xz("TentPatch", [(-0.8, 0), (0.8, 0), (0, 0.9)], 0.06, (2.9, 1.6, 0.55), CV3, 0.0))
    for sx in (-2.0, 2.0):
        P.append(S.cyl("TentPeg", 0.03, 0.4, (2.3 + sx, 0.9, 0.2), WD, 5, rot=(0.5, 0, 0)))
        P.append(S.cyl("TentRope", 0.012, 1.4, (2.3 + sx * 0.8, 0.7, 0.8), DK, 4, rot=(0.7, 0, 0)))
    # Holzturm mit Ausguck, Leiter, Scheinwerfer
    for sx in (-0.4, 0.4):
        for sy in (-0.4, 0.4):
            P.append(S.cyl("TowerLeg", 0.07, 3.6, (-3.4 + sx, 2.4 + sy, 1.8), WD, 6, rot=(-sy * 0.05, sx * 0.05, 0)))
    for k in range(3):
        P.append(S.box("BraceX", (1.0, 0.04, 0.05), (-3.4, 2.0, 0.8 + k * 1.0), WD, 0.0, rot=(0, 0.6, 0)))
        P.append(S.box("BraceY", (0.04, 1.0, 0.05), (-3.0, 2.4, 0.8 + k * 1.0), WD, 0.0, rot=(0, 0, 0.0)))
    P.append(S.box("Lookout", (1.4, 1.4, 0.1), (-3.4, 2.4, 3.6), WL, 0.02))
    for sx in (-0.65, 0.65):
        P.append(S.box("LookoutRail", (0.05, 1.3, 0.5), (-3.4 + sx, 2.4, 3.9), WD, 0.0))
    P.append(S.box("LookoutRailF", (1.3, 0.05, 0.5), (-3.4, 1.75, 3.9), WD, 0.0))
    P.append(S.box("LookoutRoof", (1.7, 1.7, 0.06), (-3.4, 2.4, 4.6), TIN, 0.01, rot=(0.1, 0, 0)))
    P.append(S.cyl("Spot", 0.2, 0.3, (-3.4, 1.8, 4.1), ST, 12, rot=(math.radians(80), 0, 0)))
    for k in range(8):
        P.append(S.box("Rung", (0.4, 0.03, 0.03), (-2.95, 2.0, 0.4 + k * 0.4), WD, 0.0))
    # Flugzeugwrack (Rumpf, Flügelstumpf, Leitwerk) und Fässerstapel, Schrott-Windsack
    P.append(S.cyl("WreckBody", 0.4, 3.0, (-1.0, 2.6, 0.6), RS, 12, rot=(math.pi / 2, 0, 0.3)))
    P.append(S.box("WreckWing", (3.0, 0.7, 0.08), (-1.1, 2.6, 0.85), TIN, 0.02, rot=(0.0, 0.0, 0.3)))
    P.append(S.box("WreckTail", (0.08, 0.6, 0.9), (-0.1, 4.0, 1.0), RS, 0.01, rot=(0.0, 0.0, 0.3)))
    P.append(S.box("WreckStrut", (0.06, 0.06, 0.6), (-1.8, 2.5, 0.5), DK, 0.0))
    for k in range(6):
        P.append(S.cyl("Barrel", 0.26, 0.8, (1.0 + (k % 3) * 0.55, -0.1 + (k // 3) * 0.1 - 0.4, 0.55) if False else (-0.2 + (k % 3) * 0.55, 0.8 + (k // 3) * 0.55, 0.55), RS if k % 2 else CV2, 12))
    windsock(3.8, -3.3, 2.2, WD, CV3, WH)
    P.append(S.cyl("FlagPole", 0.045, 2.6, (-3.7, -3.7, 1.3), WD, 8))
    P.append(S.box("Flag", (0.04, 0.9, 0.55), (-3.7, -3.3, 2.3), B.M("BlackFlag", (0.05, 0.05, 0.05), 0.0, 0.9, 0.2, 0.5), 0.0))
    for k in range(5):
        P.append(S.cyl("Tire", 0.34, 0.2, (4.0, -0.2, 0.2 + k * 0.2), RB, 14))
    P.append(S.cyl("LampPost", 0.04, 1.8, (-1.5, -4.0, 0.9), WD, 6))
    P.append(S.box("Lamp", (0.2, 0.2, 0.28), (-1.5, -4.0, 1.9), LW, 0.03))
    B.finish("airfield", "shadow", (-11.0, -13.0, 8.4), (0, 0.2, 1.2), ground=(0.45, 0.38, 0.27))
