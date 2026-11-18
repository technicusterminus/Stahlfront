"""Abwehrbauten für alle drei Fraktionen (Blender) mit drehbarem Aufbau (Turret/Barrel/Muzzle).

blender -b -P tools/blender/make_defense.py -- <projektordner> <west|red|shadow>
  Westbund      – Patriot-Batterie: Betonsockel, drehbare Lafette mit vier Lenkflugkörpern, Schildpylone, Radar
  Rote Allianz  – Gatling-Bunker: Sechseck-Bunker mit Panzerschrägen, drehbarer Gatling, Panzersperren, Stacheldraht
  Schattenfront – Stinger-Stellung: Sandsackring, Raketenständer auf Schrottdreibein, Tarnnetz, Funkgerät
"""
import math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S
import sf_bld as B

which, P = B.setup(13)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH
T = []    # Teile des drehbaren Aufbaus
BR = []   # Rohre/Werfer (Rückstoss)

# ================================================================ WESTBUND
if which == "west":
    PW = B.M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
    PG = B.M("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
    TP = B.M("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CO, 0.03))
    # Sockelbunker mit Wartungsluke, Leuchtband, Kabelkanal
    P.append(S.box("Bunker", (3.2, 3.2, 0.8), (0, 0.2, 0.55), PG, 0.05))
    P.append(S.box("BunkerSkirt", (3.4, 3.4, 0.14), (0, 0.2, 0.2), CD if False else PW, 0.02))
    P.append(S.box("BunkerStrip", (3.24, 3.24, 0.05), (0, 0.2, 0.8), LC, 0.0))
    P.append(S.box("Hatch", (0.8, 0.05, 0.6), (0.6, -1.42, 0.55), DK, 0.02))
    P.append(S.box("HatchFrame", (0.95, 0.07, 0.75), (0.6, -1.43, 0.55), ST, 0.02))
    for k in range(4):
        P.append(S.box("Vent", (0.5, 0.04, 0.05), (-0.9, -1.42, 0.38 + k * 0.12), DK, 0.0))
    P.append(S.cyl("TurntableRing", 1.35, 0.14, (0, 0.2, 1.02), ST, 32))
    # Schildpylone vorn links/rechts
    for sx in (-2.3, 2.3):
        P.append(S.cyl("PylonBase", 0.3, 0.4, (sx, -1.6, 0.35), PG, 12))
        P.append(S.cyl("Pylon", 0.14, 2.2, (sx, -1.6, 1.4), ST, 10))
        for j in range(3):
            P.append(S.cyl("Coil", 0.26 - j * 0.04, 0.1, (sx, -1.6, 0.9 + j * 0.5), PW, 14))
        P.append(S.sphere("PylonTip", 0.2, (sx, -1.6, 2.6), LC, segs=14, rings=8))
    # Radarturm hinten mit drehender Antenne (Spin)
    P.append(S.cyl("RadarMast", 0.14, 2.6, (-2.2, 2.2, 1.5), ST, 10))
    P.append(S.box("RadarCab", (0.6, 0.6, 0.45), (-2.2, 2.2, 2.9), PW, 0.04))
    spin = [S.box("RadarBar", (1.5, 0.12, 0.5), (-2.2, 2.2, 3.35), PW, 0.03), S.box("RadarFeed", (0.14, 0.14, 0.3), (-2.2, 2.2, 3.1), ST, 0.01), S.box("RadarBack", (1.4, 0.05, 0.4), (-2.2, 2.28, 3.35), PG, 0.01)]
    spin_o = B.part("Spin", spin, (-2.2, 2.2, 3.3))
    # Munitionscontainer, Kabeltrommel, Lichtmast, Fahnenmast
    for k in range(2):
        P.append(S.box("AmmoBox", (1.0, 0.6, 0.55), (2.0, 2.1 - k * 0.8, 0.55), PW, 0.04))
        P.append(S.box("AmmoStripe", (1.02, 0.62, 0.08), (2.0, 2.1 - k * 0.8, 0.7), TP, 0.0))
    P.append(S.cyl("Reel", 0.4, 0.3, (0.7, 2.5, 0.45), PG, 16, rot=(0, math.pi / 2, 0)))
    P.append(S.cyl("Pole", 0.05, 2.6, (-2.8, -2.7, 1.3), ST, 8))
    P.append(S.box("Lamp", (0.55, 0.18, 0.07), (-2.8, -2.85, 2.62), LW, 0.0))
    P.append(S.cyl("FlagPole", 0.045, 3.0, (2.8, 2.7, 1.5), ST, 8))
    P.append(S.box("Flag", (0.04, 1.0, 0.65), (2.8, 2.2, 2.7), TP, 0.0))
    # Drehbare Lafette: Sockel, Gehäuse, Sensorkuppel, vier Flugkörper (Barrel)
    T.append(S.cyl("TTable", 1.15, 0.3, (0, 0.2, 1.25), PW, 32, 0.02))
    T.append(S.box("TBody", (1.5, 1.3, 0.7), (0, 0.45, 1.75), PW, 0.06))
    T.append(S.box("TStrip", (1.54, 1.34, 0.05), (0, 0.45, 1.55), LC, 0.0))
    for sx in (-0.78, 0.78):
        T.append(S.box("TArmor", (0.1, 1.1, 0.55), (sx, 0.35, 1.75), PG, 0.03))
    T.append(S.sphere("SensorDome", 0.28, (0.0, 0.8, 2.25), GLS, segs=16, rings=8))
    T.append(S.sphere("SensorEye", 0.08, (0.0, 0.58, 2.28), LR, segs=8, rings=5))
    T.append(S.box("Hood", (1.0, 0.6, 0.12), (0, -0.05, 2.15), TP, 0.03))
    for sx in (-0.4, 0.4):
        for sz in (0.0, 0.42):
            BR.append(S.box("Canister", (0.34, 1.7, 0.34), (sx, -0.65, 2.0 + sz * 0.3 + 0.25), ST, 0.04, rot=(-0.5, 0, 0)))
            BR.append(S.box("CanisterCap", (0.38, 0.1, 0.38), (sx, -1.4 - sz * 0.0, 2.35 + sz * 0.3 + 0.1), DK, 0.02, rot=(-0.5, 0, 0)))
            BR.append(S.sphere("Seeker", 0.1, (sx, -1.45, 2.38 + sz * 0.3 + 0.1), LC, segs=8, rings=5))
    turret = B.part("Turret", T, (0, 0.2, 1.4))
    barrel = B.part("Barrel", BR, (0, 0.0, 2.2), parent=turret)
    mz = S.empty("Muzzle", (0, -1.6, 2.5), turret)
    B.finish("defense", "west", (-7.5, -9.5, 6.3), (0, 0.0, 1.6), extras=(turret, barrel, mz, spin_o))

# ================================================================ ROTE ALLIANZ
elif which == "red":
    BK = B.M("Brick", (0.5, 0.27, 0.2), 0.0, 0.9, 0.4, 0.8)
    TP = B.M("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
    GD = B.M("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
    RD = B.M("RedBanner", (0.65, 0.08, 0.06), 0.0, 0.8, 0.2, 0.5)
    OL = B.M("OliveBox", (0.28, 0.32, 0.2), 0.3, 0.7, 0.5, 0.7)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CD, 0.03))
    # Sechseckbunker mit Schrägpanzerung, Schießscharten und Dachluke
    P.append(S.ngon_prism("Bunker", 6, 2.1, 1.3, (0, 0.3, 0.9), CO, 0.05))
    P.append(S.cyl("BunkerSlope", 2.1, 0.7, (0, 0.3, 1.9), CO, 6, r2=1.5, rot=(0, 0, math.pi / 6)))
    P.append(S.ngon_prism("BunkerPlinth", 6, 2.3, 0.35, (0, 0.3, 0.4), CD, 0.03))
    P.append(S.box("Slit", (1.2, 0.08, 0.16), (0.0, -1.55, 1.3), DK, 0.0))
    P.append(S.box("SlitFrame", (1.4, 0.1, 0.26), (0.0, -1.54, 1.3), CD, 0.02))
    for sx in (-1.45, 1.45):
        P.append(S.box("SideSlit", (0.08, 0.9, 0.16), (sx, -0.2, 1.25), DK, 0.0, rot=(0, 0, -0.5 * (1 if sx > 0 else -1))))
    P.append(S.box("Door", (0.7, 0.08, 1.1), (0.0, 2.3, 0.85), DK, 0.02))
    P.append(B.star(0.08, (0, -1.6, 0.85), GD))
    P[-1].rotation_euler = (math.pi / 2, 0, 0)
    for k in range(6):
        P.append(S.box("Stripe", (0.22, 0.04, 0.4), (-1.0 + k * 0.4, -1.88, 0.27), YE if k % 2 else DK, 0.0))
    # Panzersperren (Igel), Stacheldraht, Sandsack-Stapel, Munitionskisten
    for (hx, hy) in ((-2.4, -1.9), (2.4, -1.9), (-2.6, 1.4), (2.6, 1.4)):
        for k in range(3):
            rot = [(0, 0, 0), (math.pi / 2, 0, 0), (0, math.pi / 2, 0)][k]
            P.append(S.box("Hedgehog", (0.14, 0.14, 1.0), (hx, hy, 0.6), ST, 0.01, rot=(rot[0] + 0.5, rot[1], rot[2] + k * 0.7)))
    for k in range(7):
        P.append(S.cyl("Post", 0.04, 0.9, (-2.7 + k * 0.9, -2.75, 0.5), WD, 6))
    for z in (0.4, 0.7, 0.95):
        P.append(S.box("Wire", (5.4, 0.02, 0.02), (0, -2.75, z), DK, 0.0))
    for k in range(12):
        P.append(S.box("WireSpike", (0.03, 0.03, 0.1), (-2.5 + k * 0.45, -2.75, 0.75), DK, 0.0))
    for r in range(2):
        for k in range(4):
            P.append(S.box("Bag", (0.6, 0.34, 0.2), (2.0 + (0.28 if r else 0), 2.2 - k * 0.0, 0.2 + r * 0.19) if False else (-2.4 + k * 0.62 + (0.3 if r else 0), 2.45, 0.2 + r * 0.19), B.M("Sandbag", (0.5, 0.45, 0.32), 0.0, 1.0, 0.1, 0.9), 0.07))
    for k in range(3):
        P.append(S.box("Crate", (0.6, 0.45, 0.4), (2.4, 2.0 - k * 0.5, 0.45), OL if k % 2 else WD, 0.03, rot=(0, 0, random.uniform(-0.2, 0.2))))
    P.append(S.cyl("Searchlight", 0.2, 0.28, (-1.7, 1.2, 2.2), ST, 12, rot=(math.radians(70), 0, 0)))
    P.append(S.cyl("SearchPole", 0.05, 1.5, (-1.7, 1.2, 1.5), ST, 8))
    P.append(S.cyl("FlagPole", 0.045, 3.2, (2.8, -2.4, 1.6), ST, 8))
    P.append(S.box("Flag", (0.04, 1.0, 0.7), (2.8, -1.9, 2.9), RD, 0.0))
    # Drehbare Gatling: Drehkranz, Gehäuse mit Schild, Munitionsgurt; Rohrbündel (Barrel)
    T.append(S.cyl("TTable", 0.85, 0.3, (0, 0.3, 2.0), TP, 24, 0.02))
    T.append(S.box("TBody", (1.2, 1.0, 0.6), (0, 0.4, 2.4), TP, 0.05))
    T.append(S.box("TShield", (1.5, 0.12, 0.8), (0, -0.2, 2.45), CD, 0.04))
    T.append(S.box("AmmoDrum", (0.5, 0.5, 0.45), (0.55, 0.85, 2.35), OL, 0.04))
    for k in range(5):
        T.append(S.box("Belt", (0.1, 0.5, 0.06), (0.5 - k * 0.0, 0.55 - k * 0.08, 2.2 + k * 0.03), YE, 0.0))
    T.append(S.sphere("Eye", 0.07, (-0.4, -0.3, 2.65), LR, segs=8, rings=5))
    for k in range(6):
        a = k * math.tau / 6
        BR.append(S.cyl("GatBarrel", 0.055, 1.7, (math.cos(a) * 0.17, -0.85, 2.45 + math.sin(a) * 0.17), ST, 8, rot=(math.pi / 2, 0, 0)))
    BR.append(S.cyl("GatRingFront", 0.27, 0.1, (0, -1.5, 2.45), DK, 12, rot=(math.pi / 2, 0, 0)))
    BR.append(S.cyl("GatRingMid", 0.25, 0.08, (0, -0.8, 2.45), DK, 12, rot=(math.pi / 2, 0, 0)))
    turret = B.part("Turret", T, (0, 0.3, 2.2))
    barrel = B.part("Barrel", BR, (0, -0.2, 2.45), parent=turret)
    mz = S.empty("Muzzle", (0, -1.8, 2.45), turret)
    B.finish("defense", "red", (-7.5, -9.5, 6.3), (0, 0.2, 1.6), extras=(turret, barrel, mz))

# ================================================================ SCHATTENFRONT
else:
    CV = B.M("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
    CV2 = B.M("CanvasGreen", (0.35, 0.37, 0.24), 0.0, 0.95, 0.2, 0.6)
    TP = B.M("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
    SB = B.M("Sandbag", (0.55, 0.47, 0.32), 0.0, 1.0, 0.1, 0.9)
    GD = B.M("Ground", (0.4, 0.33, 0.22), 0.0, 1.0, 0.1, 0.8)
    TIN = B.M("Tin", (0.55, 0.52, 0.47), 0.7, 0.6, 0.6, 0.7)
    P.append(S.box("Yard", (6.0, 6.0, 0.14), (0, 0, 0.0), GD, 0.0))
    # Sandsackring (zwei Lagen, offen nach vorn), Stützpfosten
    for ring in range(3):
        n = 18 if ring < 2 else 16
        for i in range(n):
            a = math.pi * 0.28 + i * (math.tau - math.pi * 0.56) / n
            R = 2.1
            P.append(S.box("Bag", (0.7, 0.4, 0.22), (math.cos(a + math.pi / 2) * R, 0.2 + math.sin(a + math.pi / 2) * R, 0.2 + ring * 0.2), SB, 0.08, rot=(0, 0, a + math.pi / 2 + math.pi / 2 + random.uniform(-0.06, 0.06))))
    # Schrott-Dreibein als Lafettenbock und Podest aus Brettern
    P.append(S.cyl("Podium", 1.0, 0.18, (0, 0.2, 0.25), WD, 16))
    for k in range(3):
        a = k * math.tau / 3 + 0.5
        P.append(S.cyl("Leg", 0.06, 1.5, (math.cos(a) * 0.5, 0.2 + math.sin(a) * 0.5, 0.95), RS, 8, rot=(math.sin(a) * 0.35, -math.cos(a) * 0.35, 0)))
    # Tarnnetz über der hinteren Hälfte, Zelt, Funkgerät, Munition
    for (px, py) in ((-1.8, 1.4), (1.8, 1.4), (-1.8, 2.7), (1.8, 2.7)):
        P.append(S.cyl("NetPole", 0.05, 2.0, (px, py, 1.0), WD, 6))
    P.append(S.box("Net", (3.8, 1.5, 0.04), (0, 2.05, 2.0), CV2, 0.0, rot=(0.12, 0, 0)))
    P.append(S.box("NetPatch", (1.0, 0.7, 0.05), (-0.8, 2.0, 2.05), TP, 0.0, rot=(0.12, 0, 0)))
    P.append(S.box("RadioTable", (1.0, 0.5, 0.1), (-1.3, 2.2, 0.75), WL, 0.02))
    for sx in (-1.7, -0.9):
        P.append(S.box("TableLeg", (0.08, 0.08, 0.7), (sx, 2.2, 0.4), WD, 0.01))
    P.append(S.box("Radio", (0.5, 0.3, 0.3), (-1.3, 2.2, 0.95), B.M("RadioGreen", (0.3, 0.35, 0.22), 0.4, 0.7, 0.5, 0.7), 0.03))
    P.append(S.cyl("RadioAntenna", 0.015, 1.8, (-1.15, 2.3, 1.8), DK, 6))
    P.append(S.sphere("RadioLight", 0.04, (-1.45, 2.04, 1.0), LR, segs=8, rings=4))
    for k in range(4):
        P.append(S.box("Crate", (0.55, 0.42, 0.4), (1.5 + (k % 2) * 0.6, 2.2 - (k // 2) * 0.5, 0.35), RS if k % 3 == 0 else WL, 0.03, rot=(0, 0, random.uniform(-0.2, 0.2))))
    for k in range(3):
        P.append(S.box("Missile", (0.14, 1.0, 0.14), (1.4 + k * 0.2, 1.7, 0.75 + k * 0.0), WH, 0.02, rot=(0, 0, 0.0)))
    for k in range(5):
        P.append(S.cyl("Tire", 0.34, 0.2, (-2.5, -1.2, 0.2 + k * 0.2), RB, 14))
    for k in range(3):
        P.append(S.cyl("Jerry", 0.12, 0.38, (2.5, -1.5 + k * 0.3, 0.3), B.M("GenGreen", (0.28, 0.33, 0.22), 0.4, 0.7, 0.6, 0.7), 8))
    P.append(S.cyl("LampPost", 0.04, 1.8, (2.6, -2.0, 0.9), WD, 6))
    P.append(S.box("Lamp", (0.2, 0.2, 0.28), (2.6, -2.0, 1.9), LW, 0.03))
    P.append(S.cyl("FlagPole", 0.045, 2.6, (-2.7, -2.2, 1.3), WD, 8))
    P.append(S.box("Flag", (0.04, 0.9, 0.55), (-2.7, -1.8, 2.3), B.M("BlackFlag", (0.05, 0.05, 0.05), 0.0, 0.9, 0.2, 0.5), 0.0))
    # Drehbarer Raketenständer: Schwenkgabel, Rohr mit Visier, Zielfernrohr, Schulterstütze
    T.append(S.cyl("TPivot", 0.28, 0.3, (0, 0.2, 1.75), RS, 12))
    T.append(S.box("TFork", (0.9, 0.2, 0.6), (0, 0.3, 2.0), RS, 0.03))
    T.append(S.box("TSeat", (0.45, 0.45, 0.1), (0, 0.9, 1.5), WD, 0.02))
    T.append(S.cyl("TSeatPost", 0.05, 0.6, (0, 0.9, 1.2), WD, 6))
    T.append(S.box("TGrip", (0.12, 0.5, 0.3), (0.0, 0.75, 2.05), DK, 0.03))
    BR.append(S.cyl("Tube", 0.16, 2.0, (0, -0.4, 2.2), B.M("TubeGreen", (0.3, 0.35, 0.25), 0.5, 0.6, 0.6, 0.7), 12, rot=(math.pi / 2 + 0.2, 0, 0)))
    BR.append(S.cyl("TubeFront", 0.21, 0.35, (0, -1.35, 2.38), DK, 12, rot=(math.pi / 2 + 0.2, 0, 0)))
    BR.append(S.cyl("TubeRear", 0.2, 0.3, (0, 0.55, 2.03), DK, 12, rot=(math.pi / 2 + 0.2, 0, 0)))
    BR.append(S.box("Sight", (0.12, 0.35, 0.14), (-0.2, -0.2, 2.45), DK, 0.02))
    BR.append(S.sphere("Lens", 0.05, (-0.2, -0.4, 2.45), LC, segs=8, rings=5))
    turret = B.part("Turret", T, (0, 0.2, 2.0))
    barrel = B.part("Barrel", BR, (0, 0.0, 2.2), parent=turret)
    mz = S.empty("Muzzle", (0, -1.6, 2.4), turret)
    B.finish("defense", "shadow", (-7.5, -9.5, 6.0), (0, 0.2, 1.4), ground=(0.45, 0.38, 0.27), extras=(turret, barrel, mz))
