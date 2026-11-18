"""Forschungsgebäude für alle drei Fraktionen (Blender).

blender -b -P tools/blender/make_tech.py -- <projektordner> <west|red|shadow>
  Westbund      – Forschungszentrum: Glaskuppel mit Leuchtkern, Hologrammring, Schildpylone, Leitstand, drehende Antenne
  Rote Allianz  – Propagandazentrum: Säulenhalle, Gitterturm mit drehenden Lautsprechern, Stern, Büste, Banner
  Schattenfront – Schwarzmarkt: Marktstände mit Planen, Großzelt, Laternen, Waage, Tresor, Münzhaufen
"""
import math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S
import sf_bld as B

which, P = B.setup(14)
m = B.mats()
DK, ST, YE, GLS, GLW, LC, LR, LW, WD, WL, CO, CD, RS, RB, WH = m.DK, m.ST, m.YE, m.GLS, m.GLW, m.LC, m.LR, m.LW, m.WD, m.WL, m.CO, m.CD, m.RS, m.RB, m.WH

# ================================================================ WESTBUND
if which == "west":
    PW = B.M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
    PG = B.M("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
    TP = B.M("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
    HOLO = B.M("Holo", (0.35, 0.8, 1.0), 0.0, 0.3, 0.0, 0.0, 2.5)
    GRN = B.M("Leaf", (0.2, 0.4, 0.15), 0.0, 0.85, 0.1, 0.3)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CO, 0.03))
    # Laborsockel, Glaskuppel mit Rippen, Leuchtkern auf Sockel
    P.append(S.cyl("LabBase", 2.2, 0.6, (0.3, 0.6, 0.55), PG, 36, 0.03))
    P.append(S.cyl("LabBand", 2.24, 0.1, (0.3, 0.6, 0.8), LC, 36))
    P.append(S.sphere("Dome", 1.95, (0.3, 0.6, 0.85), GLS, scale=(1, 1, 0.85), segs=32, rings=16))
    for k in range(8):
        a = k * math.pi / 8
        rib = S.cyl("DomeRib", 1.97, 0.06, (0.3, 0.6, 0.85), PW, 32, rot=(math.pi / 2, 0, a))
        rib.scale = (1.0, 1.0, 1.0)
        P.append(rib)
    P.append(S.cyl("DomeCap", 0.3, 0.2, (0.3, 0.6, 2.5), PW, 16))
    P.append(S.cyl("CorePed", 0.5, 0.6, (0.3, 0.6, 1.05), PG, 20))
    P.append(S.sphere("Core", 0.55, (0.3, 0.6, 1.8), LC, segs=24, rings=14))
    for k in range(3):
        P.append(B.ring("HoloRing", 0.9 + k * 0.28, 0.82 + k * 0.28, 0.03, (0.3, 0.6, 1.3 + k * 0.45), HOLO, 36))
    for sx in (-1, 1):
        P.append(S.box("Door", (0.5, 0.06, 0.9), (0.3 + sx * 0.0, -1.6, 0.9), GLW, 0.0)) if False else None
    # Leitstand/Anbau vorn links mit Dachantenne (Spin)
    P.append(S.box("Annex", (1.8, 1.4, 1.1), (-2.0, -1.8, 0.85), PW, 0.04))
    P.append(S.box("AnnexGlass", (1.5, 0.05, 0.55), (-2.0, -2.52, 1.0), GLS, 0.0))
    P.append(S.box("AnnexRoof", (2.0, 1.6, 0.1), (-2.0, -1.8, 1.45), TP, 0.02))
    P.append(S.box("AnnexStrip", (2.04, 1.64, 0.05), (-2.0, -1.8, 1.36), LC, 0.0))
    P.append(S.box("AnnexDoor", (0.5, 0.05, 0.85), (-1.4, -2.52, 0.72), GLW, 0.0))
    P.append(S.cyl("DishMast", 0.06, 0.8, (-2.4, -1.5, 1.9), ST, 8))
    dish = [S.sphere("Dish", 0.55, (-2.4, -1.5, 2.45), PW, scale=(1, 1, 0.3), segs=16, rings=8), S.cyl("Feed", 0.03, 0.55, (-2.4, -1.5, 2.65), ST, 6), S.sphere("FeedTip", 0.07, (-2.4, -1.5, 2.95), LR, segs=8, rings=5)]
    spin = B.part("Spin", dish, (-2.4, -1.5, 2.3))
    # Schildpylone, Laufring, Planter
    for (px, py) in ((2.4, -1.8), (2.5, 1.9), (-2.4, 2.0)):
        P.append(S.cyl("PylonBase", 0.3, 0.4, (px, py, 0.35), PG, 12))
        P.append(S.cyl("Pylon", 0.14, 2.3, (px, py, 1.45), ST, 10))
        for j in range(3):
            P.append(S.cyl("Coil", 0.26 - j * 0.04, 0.1, (px, py, 0.95 + j * 0.5), PW, 14))
        P.append(S.sphere("PylonTip", 0.2, (px, py, 2.7), LC, segs=14, rings=8))
    for (px, py) in ((-2.7, 0.2), (2.7, 0.1)):
        P.append(S.cyl("Planter", 0.45, 0.45, (px, py, 0.45), CO, 12))
        P.append(S.cyl("Trunk", 0.06, 1.0, (px, py, 1.1), WD, 6))
        P.append(S.sphere("Crown", 0.6, (px, py, 1.9), GRN, scale=(1, 1, 0.85), segs=12, rings=8))
    for k in range(10):
        a = k * math.tau / 10
        P.append(S.sphere("PathLight", 0.05, (0.3 + math.cos(a) * 2.35, 0.6 + math.sin(a) * 2.35, 0.3), LC, segs=8, rings=4))
    P.append(S.cyl("FlagPole", 0.045, 3.0, (2.8, -2.7, 1.5), ST, 8))
    P.append(S.box("Flag", (0.04, 1.0, 0.65), (2.8, -2.2, 2.7), TP, 0.0))
    B.finish("tech", "west", (-7.5, -9.5, 6.3), (0, 0.2, 1.5), extras=(spin,))

# ================================================================ ROTE ALLIANZ
elif which == "red":
    BK = B.M("Brick", (0.5, 0.27, 0.2), 0.0, 0.9, 0.4, 0.8)
    TP = B.M("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
    GD = B.M("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
    RD = B.M("RedBanner", (0.65, 0.08, 0.06), 0.0, 0.8, 0.2, 0.5)
    BZ = B.M("Bronze", (0.5, 0.36, 0.18), 0.8, 0.4, 0.4, 0.5)
    P.append(S.box("Slab", (6.0, 6.0, 0.24), (0, 0, 0.0), CD, 0.03))
    # Halle mit Säulenportikus, Giebel, Fensterreihen, Treppe
    body = S.box("Hall", (4.2, 3.0, 2.1), (-0.3, 1.0, 1.3), CO, 0.03)
    B.windows(body, (-0.3, 1.0), (4.2, 3.0), "-y", 4, 1.6, 0.45, 0.8, mats_=m)
    B.windows(body, (-0.3, 1.0), (4.2, 3.0), "-x", 2, 1.6, 0.45, 0.8, mats_=m)
    P.append(body)
    P.append(S.box("HallPlinth", (4.4, 3.2, 0.35), (-0.3, 1.0, 0.4), CD, 0.02))
    P.append(S.box("HallRoof", (4.4, 3.2, 0.16), (-0.3, 1.0, 2.45), TP, 0.02))
    P.append(S.box("Cornice", (4.5, 3.3, 0.12), (-0.3, 1.0, 2.3), CD, 0.02))
    P.append(S.prism_xz("Pediment", [(-1.4, 0), (1.4, 0), (0, 0.75)], 0.3, (-0.3, -0.7, 2.55), CO, 0.02))
    P.append(B.star(0.06, (-0.3, -0.88, 2.78), GD))
    P[-1].rotation_euler = (math.pi / 2, 0, 0)
    for k in range(5):
        P.append(S.cyl("Column", 0.15, 1.9, (-1.4 + k * 0.7, -0.75, 1.35), CO, 14))
        P.append(S.box("ColBase", (0.4, 0.4, 0.12), (-1.4 + k * 0.7, -0.75, 0.46), CD, 0.01))
        P.append(S.box("ColCap", (0.4, 0.4, 0.12), (-1.4 + k * 0.7, -0.75, 2.3), CD, 0.01))
    for k in range(4):
        P.append(S.box("Step", (3.2, 0.3, 0.1), (-0.3, -1.0 - k * 0.3, 0.32 - k * 0.07), CD, 0.01))
    # Gitterturm mit drehbaren Lautsprecherhörnern (Spin) und Stern
    for lx in (-0.3, 0.3):
        for ly in (-0.3, 0.3):
            P.append(S.box("TowerLeg", (0.1, 0.1, 5.2), (1.9 + lx, 2.0 + ly, 2.7), RS if False else B.M("TowerRed", (0.7, 0.2, 0.15), 0.5, 0.5, 0.5, 0.5), 0.01, rot=(-ly * 0.04, lx * 0.04, 0)))
    for k in range(5):
        z = 0.8 + k * 0.95
        P.append(S.box("TowerBarX", (0.6, 0.05, 0.05), (1.9, 2.3, z), ST, 0.0))
        P.append(S.box("TowerBarY", (0.05, 0.6, 0.05), (1.6, 2.0, z) if False else (1.9, 2.0, z + 0.4), ST, 0.0, rot=(0, 0, math.pi / 2)))
    P.append(S.box("TowerTopPlatform", (0.9, 0.9, 0.08), (1.9, 2.0, 4.0), DK, 0.01))
    horns = []
    for k in range(4):
        a = k * math.pi / 2
        horns.append(S.cyl("Horn", 0.34, 0.5, (1.9 + math.cos(a) * 0.62, 2.0 + math.sin(a) * 0.62, 4.35), ST, 14, r2=0.1, rot=(0, math.pi / 2, a) if False else (0, 0, 0)))
        horns[-1].rotation_euler = (0, math.pi / 2, a)
        horns.append(S.cyl("HornDriver", 0.12, 0.3, (1.9 + math.cos(a) * 0.3, 2.0 + math.sin(a) * 0.3, 4.35), DK, 10, rot=(0, math.pi / 2, a)))
    horns.append(S.cyl("HornHub", 0.2, 0.3, (1.9, 2.0, 4.35), DK, 12))
    spin = B.part("Spin", horns, (1.9, 2.0, 4.35))
    P.append(S.cyl("TowerMastTop", 0.05, 1.2, (1.9, 2.0, 4.9), ST, 8))
    P.append(B.star(0.12, (1.9, 2.0, 5.6), GD))
    P[-1].rotation_euler = (math.pi / 2, 0, 0)
    P[-1].scale = (2.2, 2.2, 2.2)
    # Büste auf Sockel, Banner, Scheinwerfer, Lampen
    P.append(S.box("BustPlinth", (0.8, 0.8, 0.9), (-2.4, -2.2, 0.7), CO, 0.03))
    P.append(S.box("BustBody", (0.5, 0.3, 0.5), (-2.4, -2.2, 1.4), BZ, 0.05))
    P.append(S.sphere("BustHead", 0.22, (-2.4, -2.2, 1.85), BZ, segs=14, rings=8))
    for sx in (-2.8, 2.8):
        P.append(S.cyl("BannerPole", 0.04, 3.2, (sx, -2.5, 1.6), ST, 8))
        P.append(S.box("Banner", (0.04, 0.8, 1.7), (sx, -2.5, 2.2), RD, 0.0))
    P.append(S.cyl("Searchlight", 0.2, 0.3, (-2.7, 2.3, 1.3), ST, 12, rot=(math.radians(60), 0, 0)))
    P.append(S.cyl("SearchPole", 0.05, 1.2, (-2.7, 2.3, 0.7), ST, 8))
    for k in range(4):
        P.append(S.sphere("PlazaLamp", 0.07, (-1.3 + k * 0.9, -2.75, 0.9), LW, segs=8, rings=5))
        P.append(S.cyl("PlazaPost", 0.03, 0.8, (-1.3 + k * 0.9, -2.75, 0.45), ST, 6))
    B.finish("tech", "red", (-7.5, -9.5, 6.5), (0, 0.3, 2.0), extras=(spin,))

# ================================================================ SCHATTENFRONT
else:
    CV = B.M("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
    CV2 = B.M("CanvasGreen", (0.35, 0.37, 0.24), 0.0, 0.95, 0.2, 0.6)
    CV3 = B.M("CanvasRed", (0.5, 0.2, 0.15), 0.0, 0.95, 0.2, 0.6)
    TP = B.M("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
    GD = B.M("Ground", (0.4, 0.33, 0.22), 0.0, 1.0, 0.1, 0.8)
    TIN = B.M("Tin", (0.55, 0.52, 0.47), 0.7, 0.6, 0.6, 0.7)
    GOLD = B.M("CoinGold", (1.0, 0.8, 0.2), 0.9, 0.3, 0.1, 0.2, 0.8)
    LAN = B.M("Lantern", (1.0, 0.7, 0.3), 0.0, 0.4, 0.0, 0.0, 6.0)
    P.append(S.box("Yard", (6.0, 6.0, 0.14), (0, 0, 0.0), GD, 0.0))
    # Großzelt hinten mit Giebelbanner
    P.append(S.prism_xz("BigTent", [(-1.6, 0), (1.6, 0), (0, 2.2)], 3.0, (0.0, 1.7, 0.1), CV2, 0.0))
    P.append(S.box("TentFlap", (1.2, 0.05, 1.6), (0.0, 0.2, 0.9), DK, 0.0))
    P.append(S.cyl("TentPoleF", 0.06, 2.8, (0.0, 0.2, 1.5), WD, 8))
    P.append(S.box("TentBanner", (0.04, 1.1, 0.7), (0.0, 0.5, 2.7) if False else (0.0, 1.7, 2.6), TP, 0.0))
    P.append(S.sphere("TentOrb", 0.1, (0.0, 1.7, 2.45), LAN, segs=8, rings=5))
    # Drei Marktstände mit Planen, Tischen, Ware
    stalls = [(-2.0, -0.6, CV3, 0.0), (2.0, -0.7, CV, 0.0), (-1.9, 1.5, CV, 0.0)]
    for (sx, sy, cm, rot) in stalls:
        for (dx, dy) in ((-0.65, -0.5), (0.65, -0.5), (-0.65, 0.5), (0.65, 0.5)):
            P.append(S.cyl("StallPole", 0.045, 2.0 if dy < 0 else 1.7, (sx + dx, sy + dy, 1.0), WD, 6))
        P.append(S.box("Awning", (1.6, 1.4, 0.05), (sx, sy, 1.95), cm, 0.0, rot=(0.17, 0, 0)))
        for k in range(6):
            P.append(S.box("AwningStripe", (0.1, 1.42, 0.055), (sx - 0.7 + k * 0.28, sy, 1.96), TP if k % 2 else DK, 0.0, rot=(0.17, 0, 0)))
        P.append(S.box("Table", (1.3, 0.6, 0.08), (sx, sy - 0.1, 0.8), WL, 0.02))
        for dx in (-0.55, 0.55):
            P.append(S.box("TableLeg", (0.08, 0.08, 0.75), (sx + dx, sy - 0.1, 0.42), WD, 0.01))
        for k in range(3):
            P.append(S.box("Ware", (0.28, 0.2, 0.18), (sx - 0.4 + k * 0.4, sy - 0.1, 0.94), [TIN, RS, TP][k], 0.03))
        P.append(S.sphere("Lantern", 0.09, (sx, sy + 0.1, 1.75), LAN, segs=8, rings=5))
        P.append(S.cyl("LanternChain", 0.01, 0.2, (sx, sy + 0.1, 1.88), DK, 4))
    # Waage, Tresor, Münzhaufen, Waffenständer, Reifensperre, Fass
    P.append(S.box("Scale", (0.3, 0.2, 0.06), (1.85, -0.8, 0.88), ST, 0.01))
    P.append(S.cyl("ScalePost", 0.02, 0.3, (1.85, -0.8, 1.05), ST, 6))
    P.append(S.box("ScaleBar", (0.5, 0.03, 0.03), (1.85, -0.8, 1.2), ST, 0.0))
    P.append(S.box("Safe", (0.7, 0.6, 0.8), (2.5, 0.9, 0.5), DK, 0.03))
    P.append(S.cyl("SafeWheel", 0.14, 0.05, (2.5, 0.58, 0.55), ST, 12, rot=(math.pi / 2, 0, 0)))
    for k in range(7):
        P.append(S.cyl("Coin", 0.1, 0.03, (2.0 + (k % 3) * 0.14, 1.9 - (k // 3) * 0.14, 0.17 + (k // 4) * 0.04), GOLD, 10))
    P.append(S.box("RackBase", (1.0, 0.3, 0.1), (0.8, -2.4, 0.2), WD, 0.02))
    P.append(S.box("RackTop", (1.0, 0.08, 0.1), (0.8, -2.4, 1.1), WD, 0.02))
    for sx in (-0.45, 0.45):
        P.append(S.box("RackPost", (0.1, 0.1, 1.0), (0.8 + sx, -2.4, 0.7), WD, 0.02))
    for k in range(4):
        P.append(S.box("Rifle", (0.05, 0.05, 1.0), (0.45 + k * 0.23, -2.4, 0.7), DK, 0.01, rot=(0.1, 0.0, 0)))
    for k in range(5):
        P.append(S.cyl("Tire", 0.34, 0.2, (-2.7, -2.4, 0.2 + k * 0.2), RB, 14))
    P.append(S.cyl("FireBarrel", 0.3, 0.8, (-0.8, -2.3, 0.5), RS, 12))
    P.append(S.box("Embers", (0.4, 0.4, 0.06), (-0.8, -2.3, 0.92), LAN, 0.0))
    # Schild, Wimpelleine, Laterne am Eingang
    P.append(S.cyl("SignPole", 0.05, 2.4, (0.0, -2.9, 1.2), WD, 6))
    P.append(S.box("Sign", (0.05, 1.2, 0.5), (0.0, -2.9, 2.2), WL, 0.01, rot=(0, 0, 0)))
    P.append(S.box("SignGlow", (0.06, 0.9, 0.18), (0.05, -2.9, 2.2), LAN, 0.0))
    for k in range(6):
        P.append(S.box("Pennant", (0.04, 0.2, 0.28), (-2.4 + k * 0.95, 0.6, 2.2 - 0.05 * math.sin(k)), TP if k % 2 else CV3, 0.0))
    B.finish("tech", "shadow", (-7.5, -9.5, 6.0), (0, 0.3, 1.4), ground=(0.45, 0.38, 0.27))
