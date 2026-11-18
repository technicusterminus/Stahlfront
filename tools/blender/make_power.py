"""Kraftwerke für alle drei Fraktionen (Blender).

blender -b -P tools/blender/make_power.py -- <projektordner> <west|red|shadow>
  Westbund      – Fusionsreaktor: stehender Plasmaring mit Leuchtkern, Kondensatorpylone, Kühlrippen, Leitstand
  Rote Allianz  – Kohlekraftwerk: Kühlturm, Kesselhaus aus Backstein, gestreifter Schlot, Kohlehalde, Förderband, Umspannfeld
  Schattenfront – Generatorenschuppen: Dieselaggregate unter Wellblech, Fässer, Kabelsalat, Schrott-Windrad, Solarplatten
"""
import math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S
import sf_bld as B

which, P = B.setup(11)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH

# ================================================================ WESTBUND
if which == "west":
    PW = B.M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
    PG = B.M("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
    TP = B.M("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
    PLASMA = B.M("Plasma", (0.5, 0.9, 1.0), 0.0, 0.2, 0.0, 0.0, 7.0)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CO, 0.03))
    P.append(S.cyl("Plinth", 2.3, 0.5, (0, 0.2, 0.4), PG, 36, 0.03))
    P.append(S.cyl("PlinthTop", 2.1, 0.1, (0, 0.2, 0.7), PW, 36))
    # Stehender Plasmaring: Doppelring mit Glaskern und Leuchtkugel
    P.append(B.ring("OuterRing", 1.65, 1.2, 0.7, (0, 0.2, 2.3), PW, 40, rot=(math.pi / 2, 0, 0)))
    P.append(B.ring("InnerRing", 1.25, 1.05, 0.45, (0, 0.2, 2.3), PG, 40, rot=(math.pi / 2, 0, 0)))
    P.append(B.ring("PlasmaRing", 1.07, 0.9, 0.18, (0, 0.2, 2.3), PLASMA, 40, rot=(math.pi / 2, 0, 0)))
    P.append(S.sphere("Core", 0.55, (0, 0.2, 2.3), PLASMA, segs=24, rings=14))
    for k in range(12):
        a = k * math.tau / 12
        P.append(S.box("RingBolt", (0.12, 0.76, 0.12), (math.cos(a) * 1.43, 0.2, 2.3 + math.sin(a) * 1.43), ST, 0.01, rot=(0, -a, 0)))
    for k in range(6):
        a = k * math.tau / 6 + 0.3
        P.append(S.box("Spoke", (0.06, 0.06, 0.62), (math.cos(a) * 0.82, 0.2, 2.3 + math.sin(a) * 0.82), LC, 0.0, rot=(0, -a + math.pi / 2, 0)))
    # Stützen, Anschlussrohre
    for sx in (-1.3, 1.3):
        P.append(S.box("Brace", (0.25, 0.5, 1.6), (sx, 0.2, 1.4), PG, 0.03))
    P.append(S.cyl("Feed", 0.22, 1.3, (0, 0.2, 0.85), ST, 14))
    # Vier Kondensatorpylone mit Leuchtspitze und Leitungen
    for (px, py) in ((-2.4, -2.2), (2.4, -2.2), (-2.4, 2.2), (2.4, 2.2)):
        P.append(S.cyl("PylonBase", 0.3, 0.4, (px, py, 0.35), PG, 12))
        P.append(S.cyl("Pylon", 0.14, 2.4, (px, py, 1.5), ST, 10))
        for j in range(3):
            P.append(S.cyl("Coil", 0.26 - j * 0.04, 0.12, (px, py, 1.0 + j * 0.55), PW, 14))
        P.append(S.sphere("PylonTip", 0.2, (px, py, 2.9), LC, segs=14, rings=8))
        dx, dy = -px * 0.62, -py * 0.62
        ln = math.hypot(dx, dy)
        P.append(S.cyl("Cable", 0.05, ln, (px + dx / 2, py + dy / 2, 0.32), LC, 8, rot=(math.pi / 2, 0, math.atan2(dy, dx) + math.pi / 2)))
    # Kühlrippenblock hinten
    for k in range(9):
        P.append(S.box("Fin", (2.4, 0.06, 1.2), (0, 2.5 - 0.0, 0.9) if False else (0.0, 2.15 + k * 0.1, 0.9), PW, 0.01))
    P.append(S.box("FinBase", (2.6, 1.1, 0.3), (0, 2.6, 0.3), PG, 0.03))
    P.append(S.box("FinGlow", (2.2, 0.05, 0.08), (0, 2.1, 1.55), LC, 0.0))
    # Leitstand vorne links mit Glasfront, Dachantenne
    P.append(S.box("Control", (1.5, 1.2, 1.1), (-2.0, -1.5, 0.85), PW, 0.03))
    P.append(S.box("ControlGlass", (1.3, 0.05, 0.55), (-2.0, -2.12, 1.0), GLS, 0.0))
    P.append(S.box("ControlRoof", (1.7, 1.4, 0.1), (-2.0, -1.5, 1.45), TP, 0.02))
    P.append(S.box("ControlStrip", (1.74, 1.44, 0.05), (-2.0, -1.5, 1.36), LC, 0.0))
    P.append(S.cyl("Mast", 0.03, 1.4, (-2.5, -1.2, 2.2), ST, 6))
    P.append(S.sphere("MastLight", 0.07, (-2.5, -1.2, 2.95), LR, segs=10, rings=6))
    P.append(S.box("Door", (0.5, 0.05, 0.85), (-1.5, -2.12, 0.72), GLW, 0.0))
    # Warnleuchten am Sockel, Fahnenmast, Lichtmasten
    for k in range(10):
        a = k * math.tau / 10
        P.append(S.sphere("BaseLight", 0.05, (math.cos(a) * 2.12, 0.2 + math.sin(a) * 2.12, 0.8), LC, segs=8, rings=4))
    P.append(S.cyl("FlagPole", 0.045, 3.0, (2.6, -2.7, 1.5), ST, 8))
    P.append(S.box("Flag", (0.04, 1.0, 0.65), (2.6, -2.2, 2.7), TP, 0.0))
    B.finish("power", "west", (-7.5, -9.5, 6.3), (0, 0.0, 1.5))

# ================================================================ ROTE ALLIANZ
elif which == "red":
    BK = B.M("Brick", (0.5, 0.27, 0.2), 0.0, 0.9, 0.4, 0.8)
    TP = B.M("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
    GD = B.M("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
    COAL = B.M("Coal", (0.03, 0.03, 0.03), 0.1, 0.95, 0.2, 0.6)
    RD = B.M("RedBand", (0.65, 0.08, 0.06), 0.0, 0.8, 0.2, 0.5)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CD, 0.03))
    # Kühlturm (Hyperboloid aus drei Kegeln), mit Zierband
    P.append(S.cyl("TowerLow", 1.45, 1.4, (-1.3, 1.4, 0.95), CO, 36, r2=1.05, smooth=True))
    P.append(S.cyl("TowerMid", 1.05, 1.0, (-1.3, 1.4, 2.15), CO, 36, r2=1.05))
    P.append(S.cyl("TowerHigh", 1.05, 1.5, (-1.3, 1.4, 3.4), CO, 36, r2=1.3, smooth=True))
    P.append(B.ring("TowerLip", 1.34, 1.18, 0.12, (-1.3, 1.4, 4.2), CD, 36))
    P.append(S.cyl("TowerBand", 1.18, 0.16, (-1.3, 1.4, 2.7), RD, 36))
    for k in range(10):
        a = k * math.tau / 10
        P.append(S.box("TowerPier", (0.18, 0.18, 0.9), (-1.3 + math.cos(a) * 1.35, 1.4 + math.sin(a) * 1.35, 0.55), CD, 0.02, rot=(0, 0, a)))
    P.append(S.box("TowerDoor", (0.6, 0.1, 0.7), (-1.3, 1.4 - 1.5, 0.45), DK, 0.02))
    # Kesselhaus aus Backstein mit Fenstern, Sheddach und Schlot
    body = S.box("Boiler", (2.6, 2.0, 2.2), (1.4, 1.6, 1.3), BK, 0.03)
    B.windows(body, (1.4, 1.6), (2.6, 2.0), "-y", 3, 1.6, 0.45, 0.7, mats_=m)
    B.windows(body, (1.4, 1.6), (2.6, 2.0), "+x", 2, 1.6, 0.45, 0.7, mats_=m)
    P.append(body)
    P.append(S.box("BoilerPlinth", (2.75, 2.15, 0.35), (1.4, 1.6, 0.4), CD, 0.02))
    P.append(S.box("BoilerRoof", (2.75, 2.15, 0.14), (1.4, 1.6, 2.5), TP, 0.02, rot=(0.08, 0, 0)))
    for k in range(4):
        P.append(S.box("Shed", (2.6, 0.12, 0.45), (1.4, 0.9 + k * 0.5, 2.78), TP, 0.02, rot=(0.5, 0, 0)))
    P.append(S.cyl("Stack", 0.4, 4.6, (2.1, 2.3, 3.4), BK, 14, r2=0.3))
    for k in range(3):
        P.append(S.cyl("StackBand", 0.34 - k * 0.012, 0.28, (2.1, 2.3, 4.4 + k * 0.55), WH if k % 2 == 0 else RD, 14))
    P.append(S.cyl("StackCap", 0.34, 0.1, (2.1, 2.3, 5.75), DK, 14))
    # Kohlehalde, Förderband, Kranlader, Rohrbrücke zum Kühlturm
    P.append(S.sphere("CoalPile", 1.0, (1.9, -1.4, 0.3), COAL, scale=(1.5, 1.1, 0.7)))
    for k in range(6):
        P.append(S.sphere("Lump", 0.12, (1.1 + k * 0.28, -1.4 + random.uniform(-0.5, 0.5), 0.15), COAL, segs=8, rings=5))
    belt = S.box("Belt", (0.45, 2.8, 0.14), (1.9, -0.1, 1.15), DK, 0.02, rot=(0.0, 0.0, 0.0))
    belt.rotation_euler = (math.radians(24), 0, 0)
    P.append(belt)
    for sy in (-1.2, 0.0, 1.2):
        P.append(S.box("BeltLeg", (0.1, 0.1, 1.0 + sy * 0.25 + 0.3), (1.9, -0.1 + sy * 0.95, 0.6 + sy * 0.15), ST, 0.01))
    P.append(S.cyl("Pipe", 0.17, 3.2, (0.2, 1.0, 2.1), ST, 12, rot=(0, math.pi / 2, 0)))
    P.append(S.cyl("PipeDrop", 0.17, 1.4, (-0.55, 1.0, 1.4), ST, 12))
    for k in range(4):
        P.append(S.cyl("PipeFlange", 0.22, 0.08, (-0.4 + k * 0.9, 1.0, 2.1), DK, 12, rot=(0, math.pi / 2, 0)))
    # Umspannfeld mit Isolatoren, Warnstreifen
    P.append(S.box("Yard", (1.6, 1.2, 0.08), (-2.2, -1.9, 0.26), CO, 0.01))
    for k in range(3):
        P.append(S.cyl("Insul", 0.1, 1.1, (-2.7 + k * 0.5, -1.9, 0.85), WH, 10))
        for j in range(4):
            P.append(S.cyl("InsulDisc", 0.16, 0.05, (-2.7 + k * 0.5, -1.9, 0.5 + j * 0.2), RB if j % 2 else WH, 12))
    P.append(S.box("TransBox", (0.8, 0.6, 0.9), (-1.7, -2.3, 0.7), CD, 0.03))
    for k in range(5):
        P.append(S.box("Stripe", (0.14, 0.04, 0.6), (-2.7 + k * 0.45, -1.2, 0.27), YE if k % 2 else DK, 0.0))
    # Fahne, Stern, Lautsprecher, Lampe
    P.append(B.star(0.08, (1.4, 0.55, 1.9), GD))
    P[-1].rotation_euler = (math.pi / 2, 0, 0)
    P.append(S.cyl("FlagPole", 0.045, 3.4, (2.7, -2.5, 1.7), ST, 8))
    P.append(S.box("Flag", (0.04, 1.1, 0.75), (2.7, -2.0, 3.0), RD, 0.0))
    P.append(S.cyl("PoleSpeaker", 0.04, 2.4, (0.0, -2.5, 1.2), ST, 6))
    P.append(S.cyl("Horn", 0.18, 0.4, (0.0, -2.7, 2.35), ST, 12, r2=0.06, rot=(math.radians(90), 0, 0)))
    B.finish("power", "red", (-7.5, -9.5, 6.5), (0, 0.6, 2.0))

# ================================================================ SCHATTENFRONT
else:
    CV = B.M("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
    CV2 = B.M("CanvasGreen", (0.35, 0.37, 0.24), 0.0, 0.95, 0.2, 0.6)
    TP = B.M("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
    TIN = B.M("Tin", (0.55, 0.52, 0.47), 0.7, 0.6, 0.6, 0.7)
    GN = B.M("GenGreen", (0.28, 0.33, 0.22), 0.4, 0.7, 0.6, 0.7)
    SOL = B.M("Solar", (0.06, 0.09, 0.2), 0.8, 0.2, 0.2, 0.4)
    GD = B.M("Ground", (0.4, 0.33, 0.22), 0.0, 1.0, 0.1, 0.8)
    P.append(S.box("Yard", (6.0, 6.0, 0.14), (0, 0, 0.0), GD, 0.0))
    # Schuppen aus Pfosten mit schrägem Wellblechdach
    for sx in (-2.3, 0.0, 2.3):
        for sy in (-0.2, 2.4):
            P.append(S.cyl("Post", 0.1, 2.3 if sy < 1 else 1.7, (sx, sy, 1.2), WD, 8))
    for k in range(7):
        P.append(S.box("Sheet", (0.72, 3.2, 0.05), (-2.2 + k * 0.72, 1.1, 2.2), TIN if k % 2 else RS, 0.01, rot=(0.14, 0, 0)))
        P.append(S.box("Rib", (0.05, 3.25, 0.06), (-2.2 + k * 0.72 + 0.34, 1.1, 2.23), DK, 0.0, rot=(0.14, 0, 0)))
    P.append(S.box("BackWall", (5.2, 0.12, 1.6), (0, 2.5, 1.0), WD, 0.02))
    for k in range(8):
        P.append(S.box("Board", (0.55, 0.14, 1.5), (-2.4 + k * 0.7, 2.52, 1.0), WL if k % 2 else WD, 0.02))
    # Drei Dieselaggregate mit Abgasrohren und Kühlern
    for i, gx in enumerate((-1.8, -0.1, 1.6)):
        P.append(S.box("GenBase", (1.2, 1.5, 0.22), (gx, 1.1, 0.3), CD if False else B.M("GenBase", (0.18, 0.17, 0.16), 0.2, 0.9, 0.4, 0.8), 0.02))
        P.append(S.box("GenBody", (1.0, 1.2, 0.8), (gx, 1.1, 0.8), GN if i != 1 else RS, 0.04))
        P.append(S.box("GenRad", (0.9, 0.12, 0.7), (gx, 1.78, 0.8), ST, 0.01))
        for k in range(5):
            P.append(S.box("RadFin", (0.8, 0.04, 0.6), (gx, 1.86 + k * 0.0, 0.8), DK, 0.0)) if False else P.append(S.box("RadFin", (0.86, 0.03, 0.62), (gx, 1.84 + k * 0.03, 0.8), DK, 0.0))
        P.append(S.cyl("Exhaust", 0.07, 1.6, (gx + 0.3, 0.9, 1.9), ST, 8))
        P.append(S.cyl("ExhaustCap", 0.11, 0.06, (gx + 0.3, 0.9, 2.72), DK, 8))
        P.append(S.sphere("Gauge", 0.08, (gx - 0.25, 0.48, 1.0), LW if i == 0 else LR, segs=8, rings=5))
    # Fässer, Kanister, Reifenstapel, Batteriebank
    for k in range(7):
        P.append(S.cyl("Barrel", 0.27, 0.85, (-2.6 + (k % 4) * 0.6, -1.6 - (k // 4) * 0.62, 0.55), RS if k % 3 == 0 else GN if k % 3 == 1 else B.M("BarrelBlue", (0.2, 0.3, 0.38), 0.5, 0.7, 0.6, 0.7), 12))
    for k in range(3):
        P.append(S.box("Jerry", (0.3, 0.14, 0.38), (-0.5 + k * 0.38, -1.8, 0.3), GN, 0.03))
    for k in range(5):
        P.append(S.cyl("Tire", 0.34, 0.2, (2.6, -1.5, 0.2 + k * 0.2), RB, 14))
    for k in range(4):
        P.append(S.box("Battery", (0.35, 0.25, 0.28), (1.2 + k * 0.4, -1.7, 0.3), DK, 0.02))
        P.append(S.cyl("Terminal", 0.04, 0.1, (1.1 + k * 0.4, -1.7, 0.5), LR, 6))
    # Kabelsalat zum Verteilerkasten
    P.append(S.box("Switch", (0.55, 0.25, 0.8), (0.9, -0.4, 0.6), TIN, 0.03))
    for k in range(5):
        P.append(S.cyl("Cable", 0.03, 1.4 + k * 0.1, (0.0 + k * 0.1, -0.2 - k * 0.05, 0.2), DK, 6, rot=(0, math.pi / 2, 0.15 * k)))
    # Schrott-Windrad auf Mast, Solarplatten auf dem Dach
    P.append(S.cyl("TurbineMast", 0.07, 4.2, (2.6, 2.3, 2.1), WD, 8))
    hub = S.sphere("Hub", 0.14, (2.6, 2.05, 4.1), ST, segs=10, rings=6)
    P.append(hub)
    for k in range(3):
        a = k * math.tau / 3 + 0.4
        P.append(S.box("Blade", (0.12, 0.03, 1.1), (2.6 + math.sin(a) * 0.55, 1.95, 4.1 + math.cos(a) * 0.55), TIN, 0.0, rot=(0, a, 0)))
    for k in range(3):
        P.append(S.box("Solar", (0.95, 0.7, 0.05), (-1.6 + k * 1.0, 0.0, 2.55), SOL, 0.01, rot=(-0.5, 0, 0)))
        P.append(S.box("SolarFrame", (1.0, 0.75, 0.04), (-1.6 + k * 1.0, 0.0, 2.52), ST, 0.01, rot=(-0.5, 0, 0)))
    # Tarnnetz, Laterne
    P.append(S.box("Tarp", (1.8, 1.2, 0.04), (-1.3, -0.6, 1.7), CV2, 0.0, rot=(0.12, 0.0, -0.1)))
    for (px, py) in ((-2.1, -1.2), (-0.5, -1.2), (-2.1, 0.0)):
        P.append(S.cyl("TarpPole", 0.04, 1.8, (px, py, 0.9), WD, 6))
    P.append(S.cyl("LampPost", 0.04, 1.8, (-2.7, -0.4, 0.9), WD, 6))
    P.append(S.box("Lamp", (0.2, 0.2, 0.28), (-2.7, -0.4, 1.9), LW, 0.03))
    B.finish("power", "shadow", (-7.5, -9.5, 6.0), (0, 0.4, 1.4), ground=(0.45, 0.38, 0.27))
