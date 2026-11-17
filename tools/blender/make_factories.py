"""Fabriken für alle drei Fraktionen (Blender).

blender -b -P tools/blender/make_factories.py -- <projektordner> <west|red|shadow>
Ergebnis: models/buildings/<fraktion>_factory.glb, shots/<fraktion>_factory_preview.png   (vorne = -Y)
  Westbund      – Gewölbehangar mit Rippen und Oberlicht, Bürotrakt, Portalkran, Drohnenlandefeld
  Rote Allianz  – Sheddach-Halle, gestreifte Schlote, Silo mit Rohrbrücke, Gleisanschluss
  Schattenfront – Wellblechschuppen auf Pfosten, Schrottberge, Schrottkran, Presse, Wracks
"""
import bpy, math, os, random, sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import sf_common as S

root_dir = sys.argv[sys.argv.index("--") + 1]
which = sys.argv[sys.argv.index("--") + 2]
S.reset()
random.seed(5)
P = []

def M(name, col, metal=0.0, rough=0.7, wear=0.5, dirt=0.5, emit=0.0):
    return S.material(name, col, metal, rough, wear, dirt, emit)

DK = M("Dark", (0.03, 0.03, 0.035), 0.3, 0.7, 0.2, 0.3)
ST = M("Steel", (0.42, 0.43, 0.46), 0.85, 0.35, 0.5, 0.4)
YE = M("Yellow", (0.95, 0.72, 0.08), 0.2, 0.5, 0.5, 0.4)
GLS = M("Glass", (0.07, 0.12, 0.17), 0.9, 0.05, 0.0, 0.15)
GLW = M("GlassLit", (1.0, 0.82, 0.5), 0.0, 0.3, 0.0, 0.0, 1.7)
LC = M("LightCyan", (0.4, 0.85, 1.0), 0.0, 0.3, 0.0, 0.0, 4.0)
LR = M("LightRed", (1.0, 0.12, 0.06), 0.0, 0.3, 0.0, 0.0, 6.0)
LW = M("LightWhite", (1.0, 0.95, 0.8), 0.0, 0.3, 0.0, 0.0, 8.0)
WD = M("Wood", (0.4, 0.28, 0.16), 0.0, 0.9, 0.3, 0.8)
WL = M("WoodLight", (0.55, 0.42, 0.25), 0.0, 0.9, 0.3, 0.8)

def windows(body, c, s, face, n, z, w=0.6, h=0.8, skip=()):
    """Fensteröffnungen (echte Laibungen) mit Glas, Rahmen und Sims auf einer Seite der Box."""
    for i in range(n):
        if i in skip:
            continue
        t = -0.5 + (i + 0.5) / n
        if face == "-y":
            x, y = c[0] + t * s[0] * 0.88, c[1] - s[1] / 2
            cut = S.box("cut", (w, 0.6, h), (x, y, z), None, 0.0)
            pane = (w - 0.06, 0.05, h - 0.06); ppos = (x, y + 0.14, z)
            frame = (w + 0.12, 0.06, 0.07); sill = (w + 0.25, 0.22, 0.08); spos = (x, y - 0.08, z - h / 2 - 0.09)
        else:  # +x / -x
            sx = 1 if face == "+x" else -1
            x, y = c[0] + sx * s[0] / 2, c[1] + t * s[1] * 0.88
            cut = S.box("cut", (0.6, w, h), (x, y, z), None, 0.0)
            pane = (0.05, w - 0.06, h - 0.06); ppos = (x - sx * 0.14, y, z)
            frame = (0.06, w + 0.12, 0.07); sill = (0.22, w + 0.25, 0.08); spos = (x + sx * 0.08, y, z - h / 2 - 0.09)
        S.cut(body, cut)
        lit = (i * 5 + int(abs(z) * 3) + len(face)) % 3 == 0
        P.append(S.box("Pane", pane, ppos, GLW if lit else GLS, 0.0))
        for dz in (h / 2 + 0.02, -h / 2 - 0.02):
            P.append(S.box("Frame", frame, (ppos[0], ppos[1], z + dz), ST, 0.0))
        P.append(S.box("Sill", sill, spos, CO, 0.01))

def pipe(a, b, r, mat):
    d = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    L = math.sqrt(d[0] ** 2 + d[1] ** 2 + d[2] ** 2)
    mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
    ob = S.cyl("Pipe", r, L, mid, mat, 10)
    rot_y = math.acos(d[2] / L)
    rot_z = math.atan2(d[1], d[0])
    ob.rotation_euler = (0, rot_y, rot_z)
    P.append(ob)
    P.append(S.sphere("Joint", r * 1.3, a, mat, segs=8, rings=4))
    P.append(S.sphere("Joint", r * 1.3, b, mat, segs=8, rings=4))

def bands(x, y, r, h0, h1, n, m1, m2, base=0.0):
    z = h0
    k = 0
    step = (h1 - h0) / n
    while z < h1 - 1e-6:
        P.append(S.cyl("Band", r, step, (x, y, z + step / 2), m1 if k % 2 == 0 else m2, 14))
        z += step
        k += 1

def finish(name, cam, tgt, ground=(0.3, 0.32, 0.25)):
    hull = P[0]
    S.join_into(hull, P[1:])
    hull.name = "Hull"
    tex = os.path.join(root_dir, "models", "source", "textures")
    S.bake(hull, 2048, tex)
    os.makedirs(os.path.join(root_dir, "models", "buildings"), exist_ok=True)
    S.export(os.path.join(root_dir, "models", "buildings", "%s_factory.glb" % name), [hull])
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root_dir, "models", "source", "%s_factory.blend" % name))
    S.preview(os.path.join(root_dir, "shots", "%s_factory_preview.png" % name), target=tgt, cam_loc=cam, lens=42, ground=ground)
    print("FACTORY_OK", name)

# ================================================================ WESTBUND
if which == "west":
    PW = M("PanelWhite", (0.8, 0.82, 0.84), 0.2, 0.42, 0.45, 0.45)
    PG = M("PanelGrey", (0.36, 0.38, 0.42), 0.55, 0.38, 0.5, 0.4)
    CO = M("Concrete", (0.56, 0.55, 0.53), 0.0, 0.88, 0.3, 0.7)
    TP = M("TeamPaint", (0.7, 0.72, 0.76), 0.4, 0.4, 0.5, 0.3)
    AS = M("Asphalt", (0.11, 0.115, 0.12), 0.0, 0.85, 0.2, 0.3)
    BL = M("BlueConduit", (0.15, 0.4, 0.75), 0.6, 0.4, 0.3, 0.3)
    MK = M("Marking", (0.9, 0.9, 0.86), 0.0, 0.6, 0.3, 0.3)
    globals()["CO"] = CO
    P.append(S.box("Slab", (9.0, 8.6, 0.3), (0, 0, 0.0), CO, 0.03))
    # Hangar: Sockel + Gewölbe mit Rippen
    hx, hy = -1.3, 0.0
    P.append(S.box("HangarBase", (5.8, 7.4, 1.3), (hx, hy, 0.8), PW, 0.04))
    vault = S.cyl("Vault", 2.95, 7.4, (hx, hy, 1.45), PW, 40, 0.0, rot=(math.pi / 2, 0, 0))
    vault.scale = (1, 1, 1)
    vault.dimensions = (5.9, 0.0 + 4.4, 7.4)  # Breite x, Höhe z' (nach Rotation y), Länge
    P.append(vault)
    for k in range(8):
        y = -3.45 + k * 0.985
        rib = S.cyl("Rib", 3.0, 0.14, (hx, y, 1.45), TP, 40, rot=(math.pi / 2, 0, 0))
        rib.dimensions = (6.0, 0.14, 4.5)
        P.append(rib)
    P.append(S.box("Skylight", (0.9, 6.6, 0.08), (hx, hy, 3.6), GLS, 0.0))
    for k in range(7):
        P.append(S.box("SkyBar", (1.0, 0.07, 0.1), (hx, -3.0 + k * 1.0, 3.64), ST, 0.0))
    for k in range(6):
        P.append(S.box("SkyLight", (0.1, 0.1, 0.05), (hx + 0.6, -2.8 + k * 1.1, 3.62), LC, 0.0))
    # Tor mit Rahmen, halb offen, Panzer-Silhouette dahinter
    fy = hy - 3.7
    P.append(S.box("Door", (3.4, 0.12, 2.7), (hx, fy, 1.6), DK, 0.02))
    P.append(S.box("DoorFrame", (3.7, 0.2, 0.2), (hx, fy - 0.02, 3.0), PG, 0.02))
    for sx in (-1.8, 1.8):
        P.append(S.box("DoorPost", (0.2, 0.2, 2.9), (hx + sx, fy - 0.02, 1.55), PG, 0.02))
    P.append(S.box("DoorStrip", (3.6, 0.06, 0.07), (hx, fy - 0.12, 3.12), LC, 0.0))
    for k in range(6):
        P.append(S.box("Shutter", (3.3, 0.06, 0.12), (hx, fy - 0.08, 2.75 - k * 0.0 + 0.0 + k * 0.0 + (k * 0.0)), DK, 0.0)) if False else None
    for sx in (-1.4, 1.4):
        P.append(S.box("Bollard", (0.18, 0.18, 0.7), (hx + sx * 1.1, fy - 0.9, 0.65), YE, 0.03))
    P.append(S.box("Apron", (4.2, 2.6, 0.06), (hx, fy - 1.4, 0.18), AS, 0.0))
    for k in range(5):
        P.append(S.box("Hatch", (0.14, 0.9, 0.02), (hx - 1.2 + k * 0.6, fy - 1.4, 0.22), YE, 0.0))
    # Bürotrakt mit Fenstern
    ox, oy, ow, od, oh = 3.35, -0.9, 2.6, 5.4, 3.3
    office = S.box("Office", (ow, od, oh), (ox, oy, 0.15 + oh / 2), PW, 0.04)
    windows(office, (ox, oy), (ow, od), "+x", 4, 1.2)
    windows(office, (ox, oy), (ow, od), "+x", 4, 2.45)
    windows(office, (ox, oy), (ow, od), "-y", 2, 2.4, 0.55, 0.7)
    P.append(office)
    P.append(S.box("OfficeRoof", (ow + 0.3, od + 0.3, 0.16), (ox, oy, 0.15 + oh + 0.08), TP, 0.03))
    P.append(S.box("OfficeBand", (ow + 0.04, od + 0.04, 0.08), (ox, oy, 0.15 + oh - 0.55), LC, 0.0))
    door = S.box("OfficeDoor", (0.95, 0.12, 1.9), (ox, oy - od / 2 - 0.02, 1.1), PG, 0.02)
    P.append(door)
    P.append(S.box("OfficeGlass", (0.8, 0.08, 1.75), (ox, oy - od / 2 - 0.08, 1.05), GLW, 0.0))
    P.append(S.box("Awning", (1.6, 0.9, 0.08), (ox, oy - od / 2 - 0.45, 2.15), TP, 0.02))
    # Dach Bürotrakt: Landefeld für Drohnen, Klimageräte, Lüfter
    rz = 0.15 + oh + 0.16
    P.append(S.cyl("Pad", 0.95, 0.07, (ox - 0.1, oy - 1.1, rz + 0.03), AS, 24))
    for k in range(8):
        a = k * math.tau / 8
        P.append(S.sphere("PadLight", 0.05, (ox - 0.1 + math.cos(a) * 1.0, oy - 1.1 + math.sin(a) * 1.0, rz + 0.08), LC, segs=8, rings=4))
    P.append(S.cyl("PadH", 0.6, 0.03, (ox - 0.1, oy - 1.1, rz + 0.09), MK, 24))
    for (ax, ay) in ((ox - 0.4, oy + 1.4), (ox + 0.6, oy + 1.8)):
        P.append(S.box("AC", (0.9, 0.7, 0.55), (ax, ay, rz + 0.3), PW, 0.04))
        P.append(S.cyl("Fan", 0.24, 0.04, (ax, ay, rz + 0.6), DK, 16))
    P.append(S.cyl("Stack", 0.2, 1.3, (ox + 0.7, oy + 0.3, rz + 0.65), ST, 12))
    P.append(S.cyl("StackCap", 0.28, 0.08, (ox + 0.7, oy + 0.3, rz + 1.34), PG, 12))
    # Rohre und Leitungen an der Hangar-Westseite
    for (y0, y1, r, m, z) in ((-3.3, 3.3, 0.1, ST, 0.55), (-3.3, 3.3, 0.07, BL, 0.9)):
        P.append(S.cyl("Conduit", r, y1 - y0, (hx - 3.05, 0.0, z), m, 10, rot=(math.pi / 2, 0, 0)))
    for k in range(5):
        P.append(S.box("Bracket", (0.12, 0.1, 0.55), (hx - 3.02, -3.0 + k * 1.5, 0.72), PG, 0.01))
    # Portalkran (klein) seitlich vor dem Hangar, lässt das Tor frei
    kx, ky = hx + 3.7, fy - 1.2
    for sy in (-0.9, 0.9):
        P.append(S.box("CraneLeg", (0.18, 0.18, 3.2), (kx, ky + sy, 1.75), PW, 0.03))
        P.append(S.box("CraneFoot", (0.4, 0.4, 0.12), (kx, ky + sy, 0.2), DK, 0.02))
    P.append(S.box("CraneBeam", (0.3, 2.4, 0.3), (kx, ky, 3.4), PW, 0.03))
    P.append(S.box("CraneStripe", (0.32, 2.4, 0.06), (kx, ky, 3.22), YE, 0.0))
    P.append(S.box("Trolley", (0.5, 0.5, 0.25), (kx, ky - 0.3, 3.1), DK, 0.02))
    P.append(S.cyl("Cable", 0.015, 1.4, (kx, ky - 0.3, 2.35), DK, 6))
    P.append(S.box("Load", (0.6, 0.6, 0.45), (kx, ky - 0.3, 1.5), TP, 0.03))    # Lichtmasten und Wartungsleiter
    for (lx, ly) in ((-4.3, -3.6), (4.3, -3.6), (4.3, 3.6)):
        P.append(S.cyl("Pole", 0.05, 3.4, (lx, ly, 1.7), ST, 8))
        P.append(S.box("Lamp", (0.7, 0.2, 0.08), (lx, ly - 0.2, 3.42), LW, 0.0))
    finish("west", (-11, -14, 9.5), (0, -0.5, 1.8))

# ================================================================ ROTE ALLIANZ
elif which == "red":
    CO = M("Concrete", (0.5, 0.47, 0.43), 0.0, 0.88, 0.35, 0.8)
    CD = M("ConcreteDark", (0.3, 0.28, 0.26), 0.0, 0.9, 0.3, 0.8)
    TP = M("TeamPaint", (0.75, 0.6, 0.6), 0.3, 0.55, 0.5, 0.6)
    BK = M("Brick", (0.5, 0.27, 0.2), 0.0, 0.9, 0.4, 0.8)
    GD = M("GoldGlow", (1.0, 0.8, 0.15), 0.0, 0.4, 0.0, 0.0, 1.6)
    RS = M("Rust", (0.4, 0.2, 0.09), 0.5, 0.75, 0.8, 0.8)
    WH = M("White", (0.85, 0.85, 0.82), 0.0, 0.7, 0.4, 0.6)
    globals()["CO"] = CO
    P.append(S.box("Slab", (9.0, 8.6, 0.3), (0, 0, 0.0), CD, 0.03))
    # Halle (Ziegel/Beton) mit Pilastern, Fenstern, Sockel
    bx, by, bw, bd, bh = -0.4, 0.5, 7.4, 6.2, 3.6
    body = S.box("Hall", (bw, bd, bh), (bx, by, 0.15 + bh / 2), BK, 0.03)
    windows(body, (bx, by), (bw, bd), "+x", 4, 2.3, 0.9, 0.8)
    windows(body, (bx, by), (bw, bd), "-x", 4, 2.3, 0.9, 0.8)
    windows(body, (bx, by), (bw, bd), "-y", 4, 2.9, 0.7, 0.55, skip=(1, 2))
    P.append(body)
    P.append(S.box("Plinth", (bw + 0.3, bd + 0.3, 0.7), (bx, by, 0.5), CD, 0.03))
    for k in range(5):
        for sx in (-1, 1):
            P.append(S.box("Pilaster", (0.32, 0.38, bh), (bx + sx * (bw / 2 - 0.02), by - bd / 2 + 0.5 + k * (bd - 1.0) / 4, 0.15 + bh / 2), CO, 0.03))
    for k in range(5):
        P.append(S.box("PilasterF", (0.34, 0.36, bh), (bx - bw / 2 + 0.3 + k * (bw - 0.6) / 4, by - bd / 2, 0.15 + bh / 2), CO, 0.03))
    P.append(S.box("Cornice", (bw + 0.4, bd + 0.4, 0.22), (bx, by, 0.15 + bh + 0.11), TP, 0.03))
    # Sheddach mit Glasflächen
    for k in range(5):
        z0 = 0.15 + bh + 0.22
        y = by - bd / 2 + 0.6 + k * (bd - 0.4) / 5
        P.append(S.prism_xz("Shed", [(-0.45, 0), (0.55, 0), (-0.45, 1.0)], bw - 0.2, (bx, y, z0), TP, 0.02, rot=(0, 0, math.pi / 2)) if False else S.box("ShedSlab", (bw - 0.3, 1.05, 0.12), (bx, y, z0 + 0.5), TP, 0.02, rot=(math.radians(32), 0, 0)))
        P.append(S.box("ShedGlass", (bw - 0.5, 0.06, 0.8), (bx, y + 0.5, z0 + 0.5), GLS, 0.0, rot=(0, 0, 0)))
    # Rolltor mit Lamellen, Torbogen, Stern
    fy = by - bd / 2
    P.append(S.box("GateFrame", (3.0, 0.4, 3.0), (bx, fy - 0.1, 1.65), CD, 0.04))
    P.append(S.box("GateDark", (2.6, 0.2, 2.7), (bx, fy - 0.2, 1.55), DK, 0.0))
    for k in range(9):
        P.append(S.box("Slat", (2.6, 0.08, 0.1), (bx, fy - 0.3, 2.65 - k * 0.0 + 0.0 - 0.0 + (k * 0.11)), ST, 0.0)) if k < 4 else None
    P.append(S.box("GateTop", (3.4, 0.5, 0.36), (bx, fy - 0.15, 3.35), CO, 0.03))
    star = []
    for i in range(10):
        a = math.pi / 2 + i * math.tau / 10
        r = 0.34 if i % 2 == 0 else 0.14
        star.append((math.cos(a) * r, math.sin(a) * r))
    P.append(S.prism_xz("Star", star, 0.08, (bx, fy - 0.44, 3.35), GD, 0.0))
    for sx in (-1.9, 1.9):
        P.append(S.box("LampBox", (0.22, 0.22, 0.3), (bx + sx, fy - 0.4, 2.8), LW, 0.02))
    # Verladerampe vorn, Fahrbahnmarkierung
    P.append(S.box("Ramp", (4.2, 1.8, 0.28), (bx, fy - 1.4, 0.16), CD, 0.02))
    for k in range(4):
        P.append(S.box("RampStripe", (0.3, 1.8, 0.02), (bx - 1.6 + k * 1.1, fy - 1.4, 0.31), YE, 0.0))
    # Zwei Schlote mit Bändern, Leitern und Warnlicht
    for (sx, sy) in ((3.0, 3.0), (2.0, 3.3)):
        P.append(S.cyl("Chimney", 0.5, 6.8, (bx + sx, sy, 3.9), RS if False else BK, 16, r2=0.38))
        bands(bx + sx, sy, 0.42, 4.6, 7.2, 5, WH, TP)
        P.append(S.cyl("Cap", 0.45, 0.14, (bx + sx, sy, 7.3), DK, 16))
        P.append(S.sphere("Warn", 0.09, (bx + sx, sy, 7.5), LR, segs=10, rings=6))
        for k in range(14):
            P.append(S.box("Rung", (0.3, 0.03, 0.03), (bx + sx, sy - 0.52, 0.6 + k * 0.46), ST, 0.0))
    # Silo mit Rohrbrücke
    sx0, sy0 = -3.9, -3.0
    P.append(S.cyl("Silo", 0.95, 3.8, (sx0, sy0, 2.1), ST, 24))
    P.append(S.cyl("SiloTop", 0.95, 0.75, (sx0, sy0, 4.35), ST, 24, r2=0.18))
    for k in range(6):
        P.append(S.cyl("SiloRing", 0.97, 0.07, (sx0, sy0, 0.7 + k * 0.62), CD, 24))
    for k in range(10):
        P.append(S.box("SiloRung", (0.28, 0.03, 0.03), (sx0 + 0.98, sy0, 0.6 + k * 0.38), ST, 0.0))
    pipe((sx0, sy0 + 0.3, 3.5), (bx - bw / 2, sy0 + 0.3, 3.5), 0.12, RS)
    pipe((sx0, sy0 + 0.3, 3.0), (bx - bw / 2 - 0.0, sy0 + 0.3, 3.0), 0.08, ST)
    # Gleisanschluss rechts mit Flachwagen und Prellbock
    gx = 3.95
    for k in range(14):
        P.append(S.box("Tie", (1.6, 0.18, 0.08), (gx, -4.0 + k * 0.6, 0.2), WD, 0.0))
    for sx in (-0.5, 0.5):
        P.append(S.box("Rail", (0.07, 8.4, 0.1), (gx + sx, 0.0, 0.28), ST, 0.0))
    car = S.box("Flatcar", (1.5, 2.8, 0.18), (gx, -0.8, 0.6), CD, 0.02)
    P.append(car)
    for yy in (-1.8, -0.2):
        for sx in (-0.55, 0.55):
            P.append(S.cyl("Wheel", 0.17, 0.08, (gx + sx, yy, 0.38), DK, 14, rot=(0, math.pi / 2, 0)))
    P.append(S.box("Cargo", (1.1, 1.4, 0.9), (gx, -0.8, 1.15), TP, 0.03))
    P.append(S.box("StopBuffer", (1.4, 0.3, 0.5), (gx, 3.9, 0.4), YE, 0.03))
    # Fässer, Kisten, Stern am Giebel
    for k in range(4):
        P.append(S.cyl("Barrel", 0.27, 0.85, (-4.0 + (k % 2) * 0.6, 0.8 + (k // 2) * 0.6, 0.6), RS if k % 2 else TP, 12))
    finish("red", (-11, -14, 9.5), (0, 0.0, 2.6))

# ================================================================ SCHATTENFRONT
else:
    RK = M("Rock", (0.42, 0.37, 0.3), 0.0, 0.95, 0.2, 0.9)
    CV = M("Canvas", (0.5, 0.45, 0.3), 0.0, 0.95, 0.2, 0.6)
    TIN = M("Tin", (0.5, 0.47, 0.42), 0.65, 0.55, 0.7, 0.6)
    TIN2 = M("TinRust", (0.42, 0.22, 0.1), 0.45, 0.8, 0.8, 0.8)
    RS = M("Rust", (0.4, 0.2, 0.09), 0.5, 0.75, 0.8, 0.8)
    TP = M("TeamPaint", (0.7, 0.62, 0.45), 0.0, 0.9, 0.3, 0.6)
    SB = M("Sandbag", (0.55, 0.47, 0.32), 0.0, 1.0, 0.1, 0.9)
    BL = M("Blue", (0.12, 0.2, 0.35), 0.5, 0.6, 0.5, 0.5)
    RB = M("Rubber", (0.04, 0.04, 0.04), 0.0, 0.9, 0.2, 0.5)
    WELD = M("Weld", (0.75, 0.88, 1.0), 0.0, 0.3, 0.0, 0.0, 10.0)
    GD = M("Ground", (0.4, 0.33, 0.22), 0.0, 1.0, 0.1, 0.8)
    P.append(S.box("Yard", (9.0, 8.6, 0.2), (0, 0, 0.0), GD, 0.0))
    # Schuppen auf Holzpfosten, Wände aus Brettern
    sx0, sy0, sw, sd = -1.0, 0.5, 5.8, 5.2
    for (px, py) in ((-1, -1), (1, -1), (-1, 1), (1, 1), (0, -1), (0, 1)):
        P.append(S.box("Post", (0.3, 0.3, 3.0), (sx0 + px * sw / 2, sy0 + py * sd / 2, 1.6), WD, 0.03, rot=(0, py * 0.01, 0)))
    P.append(S.box("BackWall", (sw, 0.12, 2.5), (sx0, sy0 + sd / 2, 1.35), WL, 0.01))
    P.append(S.box("SideWallL", (0.12, sd, 2.5), (sx0 - sw / 2, sy0, 1.35), WL, 0.01))
    for k in range(18):
        P.append(S.box("Plank", (0.02, 0.01, 0.01), (0, 0, -5), WL, 0.0)) if False else None
    for k in range(10):
        P.append(S.box("PlankSeam", (sw, 0.14, 0.04), (sx0, sy0 + sd / 2 - 0.0, 0.4 + k * 0.25), WD, 0.0))
    # Wellblechdach: Bahnen mit Rost, leicht geneigt, Überstand
    n = 13
    for k in range(n):
        x = sx0 - sw / 2 - 0.25 + k * (sw + 0.5) / (n - 1)
        P.append(S.box("Sheet", (0.46, sd + 0.9, 0.05), (x, sy0 - 0.2, 3.2 + (k % 2) * 0.05), TIN if k % 3 != 1 else TIN2, 0.0, rot=(0.14, 0, 0)))
        for j in range(6):
            P.append(S.box("Corr", (0.04, sd + 0.9, 0.04), (x - 0.15 + j * 0.06, sy0 - 0.2, 3.26 + (k % 2) * 0.05), TIN, 0.0, rot=(0.14, 0, 0)))
    for k in range(4):
        P.append(S.box("Rafter", (sw + 0.4, 0.12, 0.14), (sx0, sy0 - sd / 2 + 0.2 + k * 1.6, 3.12), WD, 0.0, rot=(0.14, 0, 0)))
    P.append(S.cyl("Flue", 0.16, 1.3, (sx0 + 1.8, sy0 + 1.2, 3.8), ST, 10))
    # Halbfertiger Buggy auf Böcken, Schweißer mit Funken
    bx, by = sx0, sy0 - 0.6
    P.append(S.box("BuggyFrame", (1.5, 2.6, 0.18), (bx, by, 0.95), ST, 0.03))
    P.append(S.box("BuggySeat", (0.5, 0.5, 0.3), (bx, by + 0.3, 1.2), RS, 0.04))
    for sx in (-0.65, 0.65):
        for sy in (-0.9, 0.9):
            P.append(S.cyl("Wheel", 0.35, 0.28, (bx + sx * 1.2, by + sy * 1.1, 0.45), RB, 16, rot=(0, math.pi / 2, 0)))
    P.append(S.box("RollBarL", (0.08, 0.08, 0.9), (bx - 0.6, by + 0.5, 1.5), ST, 0.01))
    P.append(S.box("RollBarR", (0.08, 0.08, 0.9), (bx + 0.6, by + 0.5, 1.5), ST, 0.01))
    P.append(S.box("RollBarTop", (1.3, 0.08, 0.08), (bx, by + 0.5, 1.95), ST, 0.01))
    for sx in (-0.5, 0.5):
        P.append(S.box("Trestle", (0.2, 0.2, 0.85), (bx + sx, by - 0.5, 0.5), WD, 0.02))
        P.append(S.box("Trestle2", (0.2, 0.2, 0.85), (bx + sx, by + 0.7, 0.5), WD, 0.02))
    P.append(S.sphere("Spark", 0.07, (bx + 0.9, by - 0.4, 1.1), WELD, segs=8, rings=4))
    # Werkbank mit Schraubstock und Kisten
    P.append(S.box("Bench", (2.0, 0.7, 0.12), (sx0 + 1.8, sy0 + 1.9, 1.0), WD, 0.02))
    for sx in (-0.9, 0.9):
        P.append(S.box("BenchLeg", (0.1, 0.1, 0.95), (sx0 + 1.8 + sx, sy0 + 1.9, 0.5), WD, 0.01))
    P.append(S.box("Vise", (0.25, 0.25, 0.2), (sx0 + 2.4, sy0 + 1.9, 1.17), ST, 0.02))
    P.append(S.box("Toolchest", (0.5, 0.35, 0.4), (sx0 + 1.1, sy0 + 1.9, 1.25), RS, 0.03))
    # Schrottberge aus Wracks
    def wreck(x, y, z, rot):
        P.append(S.box("WreckBody", (1.8, 3.0, 0.7), (x, y, z + 0.4), TIN2, 0.04, rot=rot))
        P.append(S.box("WreckCab", (1.3, 1.3, 0.55), (x, y - 0.2, z + 0.95), RS, 0.04, rot=rot))
        P.append(S.cyl("WreckPipe", 0.07, 1.8, (x + 0.2, y + 0.6, z + 1.0), ST, 8, rot=(math.pi / 2 - 0.3, 0.2, rot[2])))
        P.append(S.cyl("WreckWheel", 0.33, 0.26, (x + 0.9, y - 1.0, z + 0.3), RB, 14, rot=(0, math.pi / 2, 0)))
    wreck(3.4, -2.8, 0.0, (0.05, 0.1, 0.4))
    wreck(3.5, -2.5, 0.75, (-0.12, 0.2, 1.9))
    wreck(2.7, 3.1, 0.0, (0.1, -0.05, 2.5))
    for i in range(10):
        P.append(S.box("Scrap", (random.uniform(0.3, 0.9), random.uniform(0.2, 0.7), 0.12), (3.4 + random.uniform(-1.3, 1.1), -2.8 + random.uniform(-1.4, 1.4), 0.15 + random.uniform(0, 0.6)), TIN2 if i % 2 else TIN, 0.01, rot=(random.uniform(-0.4, 0.4), random.uniform(-0.4, 0.4), random.uniform(0, 3))))
    # Schrottkran mit Greifer
    kx, ky = 3.9, 0.3
    P.append(S.box("CraneBase", (0.9, 0.9, 0.5), (kx, ky, 0.4), RS, 0.03))
    P.append(S.box("CraneMast", (0.34, 0.34, 4.6), (kx, ky, 2.7), RS, 0.03))
    P.append(S.box("CraneJib", (3.8, 0.26, 0.26), (kx - 1.5, ky, 4.9), RS, 0.03, rot=(0, -0.07, 0)))
    P.append(S.box("CraneBrace", (2.4, 0.1, 0.1), (kx - 0.7, ky, 4.1), RS, 0.01, rot=(0, 0.7, 0)))
    P.append(S.cyl("Rope", 0.02, 2.3, (kx - 3.2, ky, 3.7), DK, 6))
    P.append(S.cyl("Magnet", 0.45, 0.22, (kx - 3.2, ky, 2.5), DK, 18))
    P.append(S.box("Cab", (0.8, 0.8, 0.8), (kx - 0.15, ky + 0.7, 4.3), TIN, 0.04))
    P.append(S.box("CabGlass", (0.6, 0.05, 0.4), (kx - 0.15, ky + 0.3, 4.4), GLW, 0.0))
    # Schrottpresse
    px, py = -3.9, 3.2
    P.append(S.box("PressBase", (1.7, 1.7, 0.9), (px, py, 0.55), DK, 0.03))
    for sx in (-0.7, 0.7):
        P.append(S.box("PressPost", (0.2, 0.2, 2.5), (px + sx, py, 1.7), RS, 0.02))
    P.append(S.box("PressHead", (1.7, 0.4, 0.4), (px, py, 2.9), RS, 0.03))
    P.append(S.box("PressRam", (1.2, 1.2, 0.3), (px, py, 1.9), ST, 0.03))
    P.append(S.cyl("PressCyl", 0.14, 1.0, (px, py, 2.4), ST, 12))
    # Reifenstapel, Fässer, Sandsäcke
    for st in range(3):
        for i in range(4):
            ob = S.cyl("Tire", 0.36, 0.22, (-4.1 + st * 0.0, -2.3 + st * 0.0 + 0.0, 0.25 + i * 0.23), RB, 16)
            ob.location = (-4.1, -2.3 + st * 0.0 - 0.0 + (st - 1) * 0.0, 0.2 + i * 0.22)
            P.append(ob)
            break
    for i in range(5):
        P.append(S.cyl("Tire", 0.36, 0.22, (-4.1, -2.3, 0.2 + i * 0.22), RB, 16, bevel=0.0))
    for i, (bx2, by2) in enumerate([(-4.2, -0.5), (-4.2, 0.2), (-3.5, -0.2), (3.6, 1.6)]):
        P.append(S.cyl("Barrel", 0.28, 0.9, (bx2, by2, 0.65), BL if i == 2 else RS, 14))
    for r in range(3):
        for i in range(5):
            P.append(S.box("Bag", (0.62, 0.34, 0.2), (-2.4 + i * 0.64 + (0.3 if r % 2 else 0), -4.1, 0.2 + r * 0.19), SB, 0.07, rot=(0, 0, random.uniform(-0.08, 0.08))))
    # Tarnnetz in Teamfarbe über dem Eingang, Laternen
    P.append(S.box("Net", (4.2, 2.2, 0.05), (sx0, sy0 - sd / 2 - 0.8, 3.0), TP, 0.0, rot=(0.22, 0.05, 0)))
    for sx in (-1.0, 1.0):
        P.append(S.cyl("LampPost", 0.04, 1.6, (sx0 + sx * 3.0, sy0 - sd / 2 - 1.2, 0.8), WD, 6))
        P.append(S.box("Lamp", (0.2, 0.2, 0.28), (sx0 + sx * 3.0, sy0 - sd / 2 - 1.2, 1.75), WELD, 0.03))
    finish("shadow", (-11, -14, 9.0), (0, 0.0, 1.6), ground=(0.45, 0.38, 0.27))
