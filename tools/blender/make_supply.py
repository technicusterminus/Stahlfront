"""Nachschubgebäude für alle drei Fraktionen (Blender).

blender -b -P tools/blender/make_supply.py -- <projektordner> <west|red|shadow>
  Westbund      – Logistikzentrum: Glashalle mit Regalen, Silos, Drohnenlandefeld, Containerstapel, Portalkran
  Rote Allianz  – Versorgungsdepot: Betonlager mit Rampe, zwei große Tanks, Laufkran, Waggon, Kisten
  Schattenfront – Umschlagplatz: U aus rostigen Containern unter Tarnplane, Schrottkran, Händlerbude, Paletten
"""
import math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S
import sf_bld as B

which, P = B.setup(12)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH

def container(x, y, z, mat, rot=0.0, l=2.4, w=1.0, h=0.95):
    P.append(S.box("Container", (w, l, h), (x, y, z), mat, 0.03, rot=(0, 0, rot)))
    for k in range(5):
        dx = (-w * 0.4 + k * w * 0.2)
        P.append(S.box("Corrugation", (0.04, l * 0.96, h * 0.9), (x + math.cos(rot) * dx, y + math.sin(rot) * dx, z), DK, 0.0, rot=(0, 0, rot)))

# ================================================================ WESTBUND
if which == "west":
    PW = B.M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
    PG = B.M("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
    TP = B.M("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
    CB = B.M("ContBlue", (0.25, 0.4, 0.7), 0.3, 0.5, 0.3, 0.4)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CO, 0.03))
    # Glashalle mit Regalzeilen, Dachlichtband und Rolltor
    P.append(S.box("Hall", (3.6, 3.0, 1.9), (-0.8, 0.9, 1.2), PW, 0.04))
    P.append(S.box("HallGlass", (3.2, 0.06, 1.1), (-0.8, -0.62, 1.2), GLS, 0.0))
    for k in range(5):
        P.append(S.box("HallFin", (0.07, 0.1, 1.7), (-2.2 + k * 0.7, -0.64, 1.2), PW, 0.01))
    P.append(S.box("HallRoof", (3.9, 3.3, 0.14), (-0.8, 0.9, 2.2), TP, 0.03))
    P.append(S.box("RoofStrip", (3.5, 0.12, 0.05), (-0.8, -0.72, 2.18), LC, 0.0))
    P.append(S.box("RoofLight", (2.8, 0.7, 0.08), (-0.8, 1.2, 2.33), GLS, 0.0))
    for k in range(4):
        P.append(S.box("Shelf", (0.9, 0.35, 0.05), (-1.9 + k * 0.7, -0.1, 0.55 + (k % 2) * 0.5), PG, 0.01))
        P.append(S.box("Parcel", (0.35, 0.28, 0.25), (-1.9 + k * 0.7, -0.1, 0.72 + (k % 2) * 0.5), CB if k % 2 else TP, 0.02))
    P.append(S.box("Gate", (1.2, 0.05, 1.4), (0.5, -0.64, 0.95), PG, 0.01))
    for k in range(6):
        P.append(S.box("GateSlat", (1.2, 0.06, 0.04), (0.5, -0.66, 0.4 + k * 0.22), ST, 0.0))
    # Zwei Silos (leuchtender Füllstand) mit Verbindungsrohr
    for i, sy in enumerate((0.3, 1.7)):
        P.append(S.cyl("SiloBase", 0.7, 0.3, (2.0, sy, 0.4), PG, 24))
        P.append(S.cyl("Silo", 0.62, 2.2, (2.0, sy, 1.55), PW, 24))
        P.append(S.sphere("SiloTop", 0.62, (2.0, sy, 2.65), PW, scale=(1, 1, 0.45), segs=24, rings=10))
        P.append(S.box("Level", (0.1, 0.05, 1.5), (2.0 - 0.62, sy, 1.5), LC, 0.0))
        P.append(S.cyl("SiloRing", 0.64, 0.08, (2.0, sy, 1.0 + i * 0.3), PG, 24))
    P.append(S.cyl("Link", 0.1, 1.4, (2.0, 1.0, 2.3), ST, 10, rot=(math.pi / 2, 0, 0)))
    # Containerstapel und Landefeld für Transportdrohnen
    for k in range(3):
        container(-2.4 + k * 1.05, 2.5, 0.55, CB if k != 1 else PW, 0.0, 1.0, 0.95)
    container(-1.9, 2.5, 1.5, PW, 0.0, 1.0, 0.95)
    P.append(S.cyl("PadBase", 1.0, 0.1, (-1.9, -2.0, 0.2), PG, 28))
    P.append(B.ring("PadRing", 0.85, 0.7, 0.04, (-1.9, -2.0, 0.26), LC, 28))
    P.append(S.box("PadH1", (0.12, 0.8, 0.03), (-2.1, -2.0, 0.27), LW, 0.0))
    P.append(S.box("PadH2", (0.12, 0.8, 0.03), (-1.7, -2.0, 0.27), LW, 0.0))
    P.append(S.box("PadH3", (0.4, 0.12, 0.03), (-1.9, -2.0, 0.27), LW, 0.0))
    # Portalkran über der Laderampe, Lichtmasten, Fahnenmast
    for sx in (0.4, 2.2):
        P.append(S.box("CraneLeg", (0.14, 0.14, 2.6), (sx, -1.9, 1.5), ST, 0.02))
    P.append(S.box("CraneBeam", (2.0, 0.2, 0.2), (1.3, -1.9, 2.8), YE, 0.02))
    P.append(S.box("Trolley", (0.4, 0.3, 0.2), (1.1, -1.9, 2.6), DK, 0.02))
    P.append(S.cyl("Hoist", 0.02, 1.0, (1.1, -1.9, 2.0), DK, 6))
    P.append(S.box("Crate", (0.5, 0.4, 0.4), (1.1, -1.9, 1.45), TP, 0.03))
    P.append(S.box("Ramp", (1.7, 1.2, 0.18), (1.3, -2.4, 0.3), CO, 0.02))
    for (lx, ly) in ((-2.8, -2.8), (2.8, -2.8)):
        P.append(S.cyl("Pole", 0.05, 2.6, (lx, ly, 1.3), ST, 8))
        P.append(S.box("Lamp", (0.55, 0.18, 0.07), (lx, ly - 0.15, 2.62), LW, 0.0))
    P.append(S.cyl("FlagPole", 0.045, 3.2, (2.8, 2.7, 1.6), ST, 8))
    P.append(S.box("Flag", (0.04, 1.0, 0.65), (2.8, 3.2, 2.9) if False else (2.8, 2.2, 2.9), TP, 0.0))
    B.finish("supply", "west", (-7.5, -9.5, 6.3), (0, 0.0, 1.3))

# ================================================================ ROTE ALLIANZ
elif which == "red":
    TP = B.M("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
    GD = B.M("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
    RD = B.M("RedBanner", (0.65, 0.08, 0.06), 0.0, 0.8, 0.2, 0.5)
    TK = B.M("Tank", (0.4, 0.43, 0.38), 0.6, 0.5, 0.6, 0.7)
    OL = B.M("OliveBox", (0.28, 0.32, 0.2), 0.3, 0.7, 0.5, 0.7)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CD, 0.03))
    # Betonlager mit Sheddach, Rampe und Rolltor
    body = S.box("Depot", (3.4, 3.0, 2.0), (-0.9, 1.0, 1.25), CO, 0.03)
    B.windows(body, (-0.9, 1.0), (3.4, 3.0), "-y", 3, 1.85, 0.4, 0.4, mats_=m)
    B.windows(body, (-0.9, 1.0), (3.4, 3.0), "-x", 2, 1.85, 0.4, 0.4, mats_=m)
    P.append(body)
    P.append(S.box("DepotPlinth", (3.55, 3.15, 0.35), (-0.9, 1.0, 0.4), CD, 0.02))
    P.append(S.box("DepotRoof", (3.6, 3.2, 0.14), (-0.9, 1.0, 2.35), TP, 0.02))
    for k in range(3):
        P.append(S.box("RoofShed", (3.4, 0.12, 0.5), (-0.9, 0.2 + k * 0.8, 2.65), TP, 0.02, rot=(0.55, 0, 0)))
    P.append(S.box("RollDoor", (1.5, 0.08, 1.4), (-0.4, -0.52, 0.95), DK, 0.02))
    for k in range(6):
        P.append(S.box("DoorSlat", (1.5, 0.1, 0.05), (-0.4, -0.55, 0.35 + k * 0.22), ST, 0.0))
    P.append(S.box("Ramp", (1.9, 1.3, 0.3), (-0.4, -1.15, 0.3), CD, 0.02))
    P.append(B.star(0.08, (-1.8, -0.52, 1.7), GD))
    P[-1].rotation_euler = (math.pi / 2, 0, 0)
    # Zwei große Tanks mit Leiter, Rohrverbindung und Warnband
    for i, ty in enumerate((-0.2, 1.7)):
        P.append(S.cyl("TankBase", 0.85, 0.3, (2.0, ty, 0.4), CD, 24))
        P.append(S.cyl("Tank", 0.78, 2.1, (2.0, ty, 1.5), TK, 24))
        P.append(S.sphere("TankTop", 0.78, (2.0, ty, 2.55), TK, scale=(1, 1, 0.4), segs=24, rings=10))
        P.append(S.cyl("TankBand", 0.8, 0.14, (2.0, ty, 1.6), RD, 24))
        P.append(S.box("Ladder", (0.05, 0.3, 2.3), (2.0 - 0.8, ty + 0.2, 1.4), ST, 0.0))
        for k in range(8):
            P.append(S.box("Rung", (0.04, 0.3, 0.03), (2.0 - 0.8, ty + 0.2, 0.45 + k * 0.28), ST, 0.0))
        P.append(S.cyl("Valve", 0.14, 0.1, (2.0 + 0.78, ty, 0.7), RD, 12, rot=(0, math.pi / 2, 0)))
    P.append(S.cyl("Pipe", 0.12, 1.9, (2.0, 0.75, 0.55), ST, 10, rot=(math.pi / 2, 0, 0)))
    # Laufkran über dem Hof, Waggon auf Gleis, Kisten
    for sy in (-2.2, -0.6):
        P.append(S.box("CraneLeg", (0.16, 0.16, 2.9), (-2.8 if False else 0.8, sy, 1.55), ST, 0.02))
    P.append(S.box("CraneBeam", (0.2, 1.8, 0.24), (0.8, -1.4, 3.0), YE, 0.02))
    P.append(S.box("Hook", (0.2, 0.3, 0.2), (0.8, -1.3, 2.7), DK, 0.02))
    P.append(S.cyl("Cable", 0.02, 0.8, (0.8, -1.3, 2.9), DK, 6))
    P.append(S.box("RailL", (6.0, 0.08, 0.1), (0, -2.55, 0.28), ST, 0.01))
    P.append(S.box("RailR", (6.0, 0.08, 0.1), (0, -2.1, 0.28), ST, 0.01))
    for k in range(10):
        P.append(S.box("Sleeper", (0.12, 0.8, 0.07), (-2.8 + k * 0.62, -2.33, 0.25), WD, 0.01))
    P.append(S.box("Wagon", (2.2, 0.9, 0.7), (-1.6, -2.33, 0.85), OL, 0.04))
    P.append(S.box("WagonFloor", (2.4, 1.0, 0.1), (-1.6, -2.33, 0.45), DK, 0.02))
    for k in range(2):
        for sx in (-0.7, 0.7):
            P.append(S.cyl("Wheel", 0.18, 0.08, (-1.6 + sx, -2.33 + (-0.45 if k else 0.45), 0.33), DK, 14, rot=(math.pi / 2, 0, 0)))
    P.append(B.star(0.04, (-1.6, -2.8, 0.9), GD))
    P[-1].rotation_euler = (math.pi / 2, 0, 0)
    for k in range(5):
        P.append(S.box("Crate", (0.55, 0.42, 0.4), (-2.6 + (k % 3) * 0.6, 2.7 + (k // 3) * 0.46 - 0.2, 0.45 + (k // 3) * 0.0), OL if k % 2 else WD, 0.03, rot=(0, 0, random.uniform(-0.15, 0.15))))
    P.append(S.cyl("FlagPole", 0.05, 3.6, (2.8, -2.7, 1.8), ST, 8))
    P.append(S.box("Flag", (0.04, 1.2, 0.8), (2.8, -2.1, 3.2), RD, 0.0))
    P.append(S.cyl("PoleLamp", 0.04, 2.6, (-2.8, 2.6, 1.3), ST, 6))
    P.append(S.box("Lamp", (0.5, 0.2, 0.08), (-2.8, 2.45, 2.6), LW, 0.0))
    B.finish("supply", "red", (-7.5, -9.5, 6.3), (0, 0.4, 1.5))

# ================================================================ SCHATTENFRONT
else:
    TP = B.M("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
    CV = B.M("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
    CV2 = B.M("CanvasGreen", (0.35, 0.37, 0.24), 0.0, 0.95, 0.2, 0.6)
    GD = B.M("Ground", (0.4, 0.33, 0.22), 0.0, 1.0, 0.1, 0.8)
    TIN = B.M("Tin", (0.55, 0.52, 0.47), 0.7, 0.6, 0.6, 0.7)
    C1 = B.M("ContRust", (0.45, 0.2, 0.1), 0.4, 0.8, 0.8, 0.8)
    C2 = B.M("ContBlue", (0.2, 0.3, 0.38), 0.4, 0.8, 0.7, 0.8)
    C3 = B.M("ContGreen", (0.3, 0.37, 0.2), 0.4, 0.8, 0.7, 0.8)
    C4 = B.M("ContYellow", (0.6, 0.45, 0.14), 0.4, 0.8, 0.7, 0.8)
    P.append(S.box("Yard", (6.0, 6.0, 0.14), (0, 0, 0.0), GD, 0.0))
    # U aus Containern (links, hinten, rechts), teils gestapelt
    cm = [C1, C2, C3, C4]
    for k in range(3):
        container(-2.4, -1.2 + k * 2.1, 0.62, cm[k % 4], math.pi / 2 * 0.0 + 0.0, 2.2, 1.0, 1.0)
    container(-2.4, 0.9, 1.6, cm[3], 0.0, 2.2, 1.0, 0.95)
    for k in range(3):
        container(-1.2 + k * 1.25, 2.6, 0.62, cm[(k + 1) % 4], math.pi / 2, 2.2, 1.0, 1.0)
    container(2.4, 1.6, 0.62, cm[2], 0.0, 2.2, 1.0, 1.0)
    container(2.4, 1.6, 1.6, cm[0], 0.0, 2.2, 1.0, 0.95)
    # Tarnplane auf Stangen über dem Hof
    P.append(S.box("Tarp", (3.6, 2.8, 0.05), (0.0, 0.6, 2.35), CV2, 0.0, rot=(0.1, 0.0, -0.06)))
    for (px, py) in ((-1.7, -0.6), (1.7, -0.6), (-1.7, 1.9), (1.7, 1.9)):
        P.append(S.cyl("TarpPole", 0.05, 2.4, (px, py, 1.2), WD, 8))
    P.append(S.box("TarpPatch", (1.0, 0.8, 0.06), (0.8, 0.4, 2.4), CV, 0.0, rot=(0.1, 0.0, -0.06)))
    # Schrottkran mit Seil und Haken
    P.append(S.cyl("CraneMast", 0.12, 3.8, (2.6, -0.9, 1.9), RS, 10))
    P.append(S.box("CraneArm", (0.12, 2.8, 0.14), (2.6, -2.1, 3.6), RS, 0.02, rot=(0.2, 0.0, 0.0)))
    P.append(S.box("CraneStay", (0.04, 2.4, 0.04), (2.6, -1.5, 3.4), DK, 0.0, rot=(-0.45, 0, 0)))
    P.append(S.cyl("CraneRope", 0.02, 1.7, (2.6, -3.2, 2.6), DK, 6))
    P.append(S.box("Hook", (0.12, 0.12, 0.2), (2.6, -3.2, 1.75), DK, 0.02))
    P.append(S.box("Hanging", (0.5, 0.4, 0.4), (2.6, -3.2, 1.5), WD, 0.03))
    # Händlerbude am Eingang mit Tresen und Laterne
    P.append(S.box("Shack", (1.4, 1.2, 1.5), (0.0, -1.3, 0.85), WD, 0.03))
    for k in range(5):
        P.append(S.box("Board", (0.26, 1.24, 1.4), (-0.6 + k * 0.3, -1.3, 0.85), WL if k % 2 else WD, 0.02))
    P.append(S.box("ShackRoof", (1.7, 1.5, 0.08), (0.0, -1.3, 1.65), TIN, 0.01, rot=(0.14, 0, 0)))
    P.append(S.box("Counter", (1.1, 0.35, 0.1), (0.0, -2.0, 0.85), WL, 0.02))
    for sx in (-0.5, 0.5):
        P.append(S.box("CounterLeg", (0.08, 0.08, 0.8), (sx, -2.0, 0.45), WD, 0.01))
    P.append(S.box("Scale", (0.3, 0.2, 0.2), (-0.2, -2.0, 1.0), ST, 0.02))
    P.append(S.box("Goods", (0.4, 0.28, 0.25), (0.3, -2.0, 1.0), TP, 0.03))
    P.append(S.box("Lamp", (0.2, 0.2, 0.28), (0.0, -2.1, 1.75), LW, 0.03))
    # Paletten, Fässer, Säcke, Handwagen
    for k in range(3):
        P.append(S.box("Pallet", (1.0, 0.8, 0.14), (-1.0, -2.4 + k * 0.0, 0.2 + k * 0.5) if False else (-1.2 + k * 0.0, -2.4, 0.2), WD, 0.02)) if k == 0 else None
    for k in range(5):
        P.append(S.box("Sack", (0.55, 0.35, 0.22), (-1.3 + (k % 3) * 0.6, -2.5, 0.3 + (k // 3) * 0.22), CV, 0.07, rot=(0, 0, random.uniform(-0.2, 0.2))))
    for k in range(4):
        P.append(S.cyl("Barrel", 0.27, 0.85, (1.4 + (k % 2) * 0.6, -2.4 - (k // 2) * 0.1 + (k // 2) * 0.62 - 0.4, 0.55), C1 if k % 2 else C2, 12))
    P.append(S.box("Cart", (0.9, 0.55, 0.12), (0.7, 2.0, 0.45), WD, 0.02))
    for sy in (-0.3, 0.3):
        P.append(S.cyl("CartWheel", 0.28, 0.07, (0.7, 2.0 + sy, 0.3), WD, 12, rot=(0, math.pi / 2, 0)))
    P.append(S.cyl("CartHandle", 0.03, 1.0, (0.2, 2.0, 0.65), WD, 6, rot=(0, math.pi / 2, 0.2)))
    # Seil mit Wimpeln, Schild
    P.append(S.cyl("SignPole", 0.05, 2.0, (-2.9, -2.6, 1.0), WD, 6))
    P.append(S.box("Sign", (0.04, 1.1, 0.5), (-2.9, -2.1, 1.8), WL, 0.01))
    for k in range(6):
        P.append(S.box("Pennant", (0.04, 0.2, 0.28), (-2.4 + k * 0.55, -0.7, 2.25 - 0.05 * math.sin(k)), TP if k % 2 else C1, 0.0))
    B.finish("supply", "shadow", (-7.5, -9.5, 6.0), (0, 0.0, 1.3), ground=(0.45, 0.38, 0.27))
