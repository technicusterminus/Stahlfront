"""Soldaten für Stahlfront: organischer Körper (Skin-Modifier), Rig, Ausrüstung, Animationen.

Aufruf:
  blender -b -P tools/blender/make_soldier.py -- <projektordner> [fraktion] [variante]
  fraktion: west | red | shadow | all (Standard: all)
  variante: inf | inf_at | worker | all (Standard: all)
Ergebnis: models/units/<fraktion>_<variante>.glb, Vorschau shots/soldier_<fraktion>.png

Konventionen: vorne = Blender -Y, Z oben, Ursprung zwischen den Füßen.
Materialname "TeamUniform" wird im Spiel durch das Tarnmuster der Fraktion ersetzt.
Animationen: Idle, Walk, Shoot, Die.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Euler

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
root_dir = argv[0] if argv else os.getcwd()
FACTIONS = ["west", "red", "shadow"] if len(argv) < 2 or argv[1] == "all" else [argv[1]]
VARIANTS = ["inf", "inf_at", "worker"] if len(argv) < 3 or argv[2] == "all" else [argv[2]]
SCALE = 1.3   # im Spiel etwas größer für Lesbarkeit aus der RTS-Kamera
FPS = 24

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS

def material(name, color, metal=0.0, rough=0.7, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    return m

def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

# ------------------------------------------------------------------ Körper
# Gelenkpunkte (x, y, z) und Skin-Radien
J = {
    "pelvis": ((0, 0, 0.95), 0.165), "spine": ((0, 0.01, 1.15), 0.14), "chest": ((0, 0.0, 1.36), 0.19),
    "neck": ((0, 0.0, 1.53), 0.06), "head": ((0, -0.01, 1.68), 0.12), "headtop": ((0, 0.0, 1.8), 0.08),
    "hip.L": ((0.1, 0, 0.9), 0.115), "knee.L": ((0.11, -0.01, 0.52), 0.085), "ankle.L": ((0.115, 0.02, 0.1), 0.065), "toe.L": ((0.115, -0.13, 0.04), 0.05),
    "hip.R": ((-0.1, 0, 0.9), 0.115), "knee.R": ((-0.11, -0.01, 0.52), 0.085), "ankle.R": ((-0.115, 0.02, 0.1), 0.065), "toe.R": ((-0.115, -0.13, 0.04), 0.05),
    "shoulder.L": ((0.21, 0.0, 1.44), 0.088), "elbow.L": ((0.3, -0.05, 1.18), 0.066), "wrist.L": ((0.24, -0.25, 1.06), 0.052), "hand.L": ((0.2, -0.32, 1.05), 0.05),
    "shoulder.R": ((-0.21, 0.0, 1.44), 0.088), "elbow.R": ((-0.26, 0.02, 1.16), 0.066), "wrist.R": ((-0.16, -0.12, 1.02), 0.052), "hand.R": ((-0.1, -0.18, 1.02), 0.05),
}
EDGES = [("pelvis", "spine"), ("spine", "chest"), ("chest", "neck"), ("neck", "head"), ("head", "headtop"),
         ("pelvis", "hip.L"), ("hip.L", "knee.L"), ("knee.L", "ankle.L"), ("ankle.L", "toe.L"),
         ("pelvis", "hip.R"), ("hip.R", "knee.R"), ("knee.R", "ankle.R"), ("ankle.R", "toe.R"),
         ("chest", "shoulder.L"), ("shoulder.L", "elbow.L"), ("elbow.L", "wrist.L"), ("wrist.L", "hand.L"),
         ("chest", "shoulder.R"), ("shoulder.R", "elbow.R"), ("elbow.R", "wrist.R"), ("wrist.R", "hand.R")]

# Gliedmaßen werden fein unterteilt, damit Knie und Ellbogen sauber knicken.
# Profil: (t entlang des Knochens, Radiusfaktor, Vorschub nach vorne in m)
PROFILES = {
    ("hip", "knee"):       [(0.2, 1.02, 0.0), (0.45, 0.98, -0.008), (0.7, 0.88, -0.004), (0.88, 0.8, 0.0)],
    ("knee", "ankle"):     [(0.08, 0.98, -0.012), (0.3, 1.04, 0.012), (0.55, 0.92, 0.01), (0.8, 0.78, 0.0)],
    ("shoulder", "elbow"): [(0.25, 1.0, 0.0), (0.5, 1.03, -0.006), (0.82, 0.86, 0.0)],
    ("elbow", "wrist"):    [(0.12, 1.0, 0.008), (0.4, 1.02, 0.0), (0.75, 0.86, 0.0)],
}

def _limb_kind(a, b):
    for (ka, kb), prof in PROFILES.items():
        if a.startswith(ka) and b.startswith(kb):
            return prof
    return None

def build_body(mat_uniform, mat_skin, mat_boot):
    verts = []
    radii = []
    index = {}
    for n, (p, r) in J.items():
        index[n] = len(verts)
        q = Vector(p)
        if n.startswith("knee"):
            q += Vector((0, -0.018, 0))      # Kniescheibe
        if n.startswith("elbow"):
            q += Vector((0, 0.012, 0))       # Ellbogenspitze
        verts.append(q)
        if n in ("chest", "spine"):
            radii.append((r * 1.25, r * 0.85))
        elif n == "pelvis":
            radii.append((r * 1.15, r * 0.9))
        else:
            radii.append((r, r))
    edges = []
    for a, b in EDGES:
        prof = _limb_kind(a, b)
        if prof is None:
            edges.append((index[a], index[b]))
            continue
        pa, ra = Vector(J[a][0]), J[a][1]
        pb, rb = Vector(J[b][0]), J[b][1]
        prev = index[a]
        for t, k, fwd in prof:
            v = pa.lerp(pb, t) + Vector((0, fwd, 0))
            rr = (ra + (rb - ra) * t) * k
            verts.append(v)
            radii.append((rr, rr))
            edges.append((prev, len(verts) - 1))
            prev = len(verts) - 1
        edges.append((prev, index[b]))
    me = bpy.data.meshes.new("Body")
    me.from_pydata([tuple(v) for v in verts], edges, [])
    ob = bpy.data.objects.new("Body", me)
    bpy.context.scene.collection.objects.link(ob)
    activate(ob)
    sk = ob.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    for i, rr in enumerate(radii):
        me.skin_vertices[0].data[i].radius = rr
    me.skin_vertices[0].data[index["pelvis"]].use_root = True
    sub = ob.modifiers.new("Sub", "SUBSURF")
    sub.levels = 1
    sub.render_levels = 1
    bpy.ops.object.modifier_apply(modifier="Skin")
    bpy.ops.object.modifier_apply(modifier="Sub")
    # Materialzonen: Kopf/Hals = Haut, Füße = Stiefel, Rest = Uniform
    ob.data.materials.append(mat_uniform)
    ob.data.materials.append(mat_skin)
    ob.data.materials.append(mat_boot)
    for p in ob.data.polygons:
        c = p.center
        if c.z > 1.5 or (c.z > 0.98 and c.z < 1.12 and abs(c.x) > 0.16 and c.y < -0.1):
            p.material_index = 1
        elif abs(c.x) > 0.16 and c.z < 1.12 and c.y < -0.2:
            p.material_index = 1  # Hände
        elif c.z < 0.26:
            p.material_index = 2
        p.use_smooth = True
    return ob

# ------------------------------------------------------------------ Rig
BONES = [
    ("root", "pelvis", None, (0, 0, 0.55)),
    ("spine", "pelvis", "spine", None), ("chest", "spine", "chest", None), ("neck", "chest", "neck", None), ("head", "neck", "headtop", None),
    ("thigh.L", "hip.L", "knee.L", None), ("shin.L", "knee.L", "ankle.L", None), ("foot.L", "ankle.L", "toe.L", None),
    ("thigh.R", "hip.R", "knee.R", None), ("shin.R", "knee.R", "ankle.R", None), ("foot.R", "ankle.R", "toe.R", None),
    ("upperarm.L", "shoulder.L", "elbow.L", None), ("forearm.L", "elbow.L", "wrist.L", None), ("hand.L", "wrist.L", "hand.L", None),
    ("upperarm.R", "shoulder.R", "elbow.R", None), ("forearm.R", "elbow.R", "wrist.R", None), ("hand.R", "wrist.R", "hand.R", None),
]
PARENT = {"spine": "root", "chest": "spine", "neck": "chest", "head": "neck", "thigh.L": "root", "shin.L": "thigh.L", "foot.L": "shin.L",
          "thigh.R": "root", "shin.R": "thigh.R", "foot.R": "shin.R", "upperarm.L": "chest", "forearm.L": "upperarm.L", "hand.L": "forearm.L",
          "upperarm.R": "chest", "forearm.R": "upperarm.R", "hand.R": "forearm.R"}

def build_rig():
    arm = bpy.data.armatures.new("Rig")
    ob = bpy.data.objects.new("Rig", arm)
    bpy.context.scene.collection.objects.link(ob)
    activate(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.edit_bones
    for name, a, b, tail in BONES:
        bone = eb.new(name)
        bone.head = Vector(J[a][0])
        bone.tail = Vector(J[b][0]) if b else Vector(J[a][0]) + Vector((0, 0.0, -0.3))
        if name == "root":
            bone.head = Vector((0, 0, 0.95))
            bone.tail = Vector((0, 0, 0.6))
    for c, p in PARENT.items():
        eb[c].parent = eb[p]
        eb[c].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob

def skin_to(rig, body):
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")

def attach(ob, rig, bone):
    """Objekt fest an einen Knochen hängen (bleibt in Weltlage)."""
    mw = ob.matrix_world.copy()
    ob.parent = rig
    ob.parent_type = "BONE"
    ob.parent_bone = bone
    ob.matrix_world = mw

# ------------------------------------------------------------------ Ausrüstung
def prim(kind, name, loc, scale, mat, rot=(0, 0, 0), **kw):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(radius=0.5, depth=1, vertices=kw.get("v", 12), location=loc)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.5, segments=16, ring_count=8, location=loc)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.rotation_euler = rot
    bpy.ops.object.transform_apply(scale=True, rotation=False)
    ob.data.materials.append(mat)
    if kw.get("bevel", 0) > 0:
        m = ob.modifiers.new("B", "BEVEL")
        m.width = kw["bevel"]
        m.segments = 2
        bpy.ops.object.modifier_apply(modifier="B")
    for p in ob.data.polygons:
        p.use_smooth = kind != "cube"
    return ob


def _chain(pos, ang, yaw, seglen, curl, thick, mat, name, objs, bone):
    """Ein Fingerglied als kleiner Quader entlang der Greifrichtung, nach unten gekrümmt."""
    a = ang + curl
    c = Vector(pos) + _rz(yaw, Vector((0, seglen * 0.5 * math.cos(a), -seglen * 0.5 * math.sin(a))))
    o = prim("cube", name, tuple(c), (thick, seglen, thick), mat, rot=(-a, 0, yaw), bevel=0.003)
    objs.append((o, bone))
    end = Vector(pos) + _rz(yaw, Vector((0, seglen * math.cos(a), -seglen * math.sin(a))))
    return end, a

def _rz(yaw, v):
    cs, sn = math.cos(yaw), math.sin(yaw)
    return Vector((v.x * cs - v.y * sn, v.x * sn + v.y * cs, v.z))

def hand_parts(side, M, objs):
    """Hand: Handfläche, vier Finger mit je zwei Gliedern und Daumen, dazu Handgelenkmanschette."""
    wr = Vector(J["wrist." + side][0])
    hd = Vector(J["hand." + side][0])
    d = Vector((hd.x - wr.x, hd.y - wr.y, 0)).normalized()
    yaw = math.atan2(-d.x, d.y)
    bone = "hand." + side
    palm_c = hd + Vector((d.x, d.y, 0)) * 0.015
    objs.append((prim("cube", "Palm", tuple(palm_c), (0.082, 0.085, 0.034), M["skin"], rot=(0, 0, yaw), bevel=0.01), bone))
    lx = _rz(yaw, Vector((1, 0, 0)))
    inward = Vector((-1 if side == "L" else 1, 0, 0))
    tsign = 1 if lx.dot(inward) > 0 else -1
    lens = (0.04, 0.045, 0.042, 0.034)
    for i, x in enumerate((-0.03, -0.01, 0.01, 0.03)):
        base = palm_c + _rz(yaw, Vector((x, 0.043, 0.0)))
        pos, ang = _chain(base, 0.0, yaw, lens[i] * 0.55, 0.35, 0.016, M["skin"], "Finger", objs, bone)
        pos, ang = _chain(pos, ang, yaw, lens[i] * 0.5, 0.7, 0.014, M["skin"], "Finger", objs, bone)
        objs.append((prim("cube", "Nail", tuple(pos + Vector((0, 0, 0.007))), (0.011, 0.014, 0.004), M["nail"], rot=(-ang, 0, yaw), bevel=0.001), bone))
    tb = palm_c + _rz(yaw, Vector((tsign * 0.04, 0.0, 0.004)))
    pos, ang = _chain(tb, -0.2, yaw + tsign * -0.5, 0.034, 0.3, 0.017, M["skin"], "Thumb", objs, bone)
    _chain(pos, ang, yaw + tsign * -0.5, 0.028, 0.5, 0.015, M["skin"], "Thumb", objs, bone)
    objs.append((prim("sphere", "Cuff", tuple(wr + (hd - wr) * -0.1), (0.1, 0.1, 0.1), M["team"] if M.get("cuff") is None else M["cuff"]), "forearm." + side))

def boot_parts(side, M, objs):
    """Stiefel: Sohle, Absatz, Kappe, Schaft mit Zunge, Schnürung und Hosensaum."""
    x = J["ankle." + side][0][0]
    fb, sb = "foot." + side, "shin." + side
    objs.append((prim("cube", "Sole", (x, -0.045, 0.017), (0.112, 0.285, 0.034), M["sole"], bevel=0.008), fb))
    objs.append((prim("cube", "Heel", (x, 0.07, 0.036), (0.098, 0.085, 0.05), M["sole"], bevel=0.01), fb))
    objs.append((prim("sphere", "Upper", (x, -0.04, 0.07), (0.115, 0.255, 0.115), M["boot"]), fb))
    objs.append((prim("sphere", "ToeCap", (x, -0.145, 0.05), (0.105, 0.11, 0.075), M["boot"]), fb))
    objs.append((prim("cube", "ToeBumper", (x, -0.178, 0.025), (0.1, 0.03, 0.04), M["sole"], bevel=0.01), fb))
    objs.append((prim("cyl", "Shaft", (x, 0.025, 0.17), (0.125, 0.12, 0.2), M["boot"], v=14), sb))
    objs.append((prim("cube", "Tongue", (x, -0.045, 0.17), (0.06, 0.02, 0.15), M["boot"], bevel=0.006), sb))
    for k in range(5):
        z = 0.1 + k * 0.034
        objs.append((prim("cube", "Lace", (x, -0.056, z), (0.075, 0.012, 0.01), M["lace"], bevel=0.002), sb))
        for dx in (-0.034, 0.034):
            objs.append((prim("cyl", "Eyelet", (x + dx, -0.056, z), (0.012, 0.012, 0.012), M["metal"], rot=(math.pi / 2, 0, 0), v=6), sb))
    objs.append((prim("cyl", "Hem", (x, 0.022, 0.25), (0.15, 0.145, 0.07), M["team"], v=14), sb))
    objs.append((prim("cyl", "BootTop", (x, 0.025, 0.268), (0.13, 0.125, 0.02), M["sole"], v=14), sb))


HEAD_C = Vector((0.0, -0.004, 1.69))
HEAD_A = Vector((0.1, 0.118, 0.132))

def _G(x, z, x0, z0, sx, sz):
    return math.exp(-((x - x0) / sx) ** 2 - ((z - z0) / sz) ** 2)

def head_shape(nx, ny, nz):
    """Menschliche Kopfform aus einer Kugel: Kiefer, Nase, Brauenwulst, Augenhöhlen, Wangenknochen, Lippen, Kinn."""
    x, y, z = nx, ny, nz
    if z < -0.2:
        t = (-z - 0.2) / 0.8
        x *= 1.0 - 0.34 * t ** 1.1
    front = max(0.0, -y)
    dy = 0.0
    for sg in (-1, 1):
        dy += 0.11 * _G(x, z, 0.45 * sg, 0.1, 0.2, 0.1)        # Augenhöhlen (nach innen)
        dy -= 0.06 * _G(x, z, 0.55 * sg, -0.15, 0.2, 0.15)     # Wangenknochen
        dy -= 0.12 * _G(x, z, 0.19 * sg, -0.22, 0.09, 0.07)    # Nasenflügel
    dy -= 0.34 * _G(x, z, 0.0, -0.22, 0.13, 0.1)               # Nasenspitze
    dy -= 0.14 * _G(x, z, 0.0, 0.05, 0.07, 0.24)               # Nasenrücken
    dy -= 0.08 * _G(x, z, 0.0, 0.31, 0.6, 0.08)                # Brauenwulst
    dy += 0.06 * _G(x, z, 0.0, -0.5, 0.3, 0.03)                # Mundspalte
    dy -= 0.09 * _G(x, z, 0.0, -0.435, 0.26, 0.05)             # Oberlippe
    dy -= 0.09 * _G(x, z, 0.0, -0.575, 0.22, 0.055)            # Unterlippe
    dy -= 0.1 * _G(x, z, 0.0, -0.82, 0.3, 0.1)                 # Kinn
    y = y + dy * front
    return x, y, z

def make_head(name, scale, mat_skin, mat_lip, keep=None, smooth=0):
    """Kopfnetz. keep(nx,ny,nz) wählt Flächen (für Haar-/Bartschalen); ohne keep: ganzer Kopf mit Lippenmaterial."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=80, v_segments=52, radius=1.0)
    for v in bm.verts:
        v.co.x, v.co.y, v.co.z = head_shape(v.co.x, v.co.y, v.co.z)
    if keep is not None:
        dele = []
        for f in bm.faces:
            c = f.calc_center_median()
            if not keep(c.x, c.y, c.z):
                dele.append(f)
        bmesh.ops.delete(bm, geom=dele, context="FACES")
    for v in bm.verts:
        v.co = Vector((v.co.x * HEAD_A.x * scale, v.co.y * HEAD_A.y * scale, v.co.z * HEAD_A.z * scale)) + HEAD_C
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(mat_skin)
    if mat_lip is not None:
        me.materials.append(mat_lip)
        for p in me.polygons:
            c = (p.center - HEAD_C)
            nx, ny, nz = c.x / HEAD_A.x, c.y / HEAD_A.y, c.z / HEAD_A.z
            if ny < -0.4 and (nx / 0.27) ** 2 + ((nz + 0.505) / 0.115) ** 2 < 1.0:
                p.material_index = 1
    for p in me.polygons:
        p.use_smooth = True
    if smooth > 0:
        # Schalen (Haar, Bart, Lippen) weich runden, damit die Ränder nicht stufig sind
        activate(ob)
        md = ob.modifiers.new("Soft", "SUBSURF")
        md.levels = smooth
        md.render_levels = smooth
        md.boundary_smooth = "ALL"
        bpy.ops.object.modifier_apply(modifier="Soft")
        for p in ob.data.polygons:
            p.use_smooth = True
    return ob

def gear(faction, variant, rig, M):
    objs = []
    # Kopfbedeckung
    if variant == "worker" and faction == "shadow":
        # Kopftuch statt Helm, Schutzbrille auf der Stirn, Tuch vor dem Mund
        objs.append((prim("sphere", "Headscarf", (0, 0.01, 1.8), (0.265, 0.28, 0.15), M["cloth"]), "head"))
        objs.append((prim("cube", "Knot", (0.0, 0.14, 1.76), (0.07, 0.05, 0.08), M["cloth"], bevel=0.015), "head"))
        objs.append((prim("cube", "GoggleBand", (0, -0.0, 1.775), (0.255, 0.25, 0.026), M["gear"]), "head"))
        for sx in (-0.05, 0.05):
            objs.append((prim("cyl", "Goggle", (sx, -0.125, 1.775), (0.07, 0.07, 0.03), M["visor"], rot=(math.pi / 2, 0, 0), v=12), "head"))
        objs.append((prim("cube", "Mask", (0, -0.075, 1.575), (0.2, 0.1, 0.06), M["scarf"], bevel=0.02), "head"))
    elif variant == "worker":
        h = prim("sphere", "Helmet", (0, 0.0, 1.79), (0.255, 0.275, 0.15), M["hard"])
        objs.append((h, "head"))
        objs.append((prim("cube", "Brim", (0, -0.115, 1.775), (0.17, 0.06, 0.014), M["hard"], rot=(-0.12, 0, 0), bevel=0.005), "head"))
        objs.append((prim("cube", "Ridge", (0, 0.0, 1.865), (0.035, 0.24, 0.016), M["hard"], bevel=0.008), "head"))
        if faction != "west":
            objs.append((prim("sphere", "Star", (0, -0.135, 1.81), (0.04, 0.018, 0.04), M["gold"]), "head"))
    elif faction == "west":
        h = prim("sphere", "Helmet", (0, 0.01, 1.79), (0.26, 0.285, 0.17), M["team"])
        objs.append((h, "head"))
        objs.append((prim("cube", "Visor", (0, -0.125, 1.775), (0.15, 0.026, 0.04), M["visor"], bevel=0.01), "head"))
        objs.append((prim("cube", "NV", (0, -0.1, 1.88), (0.06, 0.06, 0.05), M["gear"], bevel=0.01), "head"))
    elif faction == "red":
        objs.append((prim("cyl", "Cap", (0, 0.01, 1.8), (0.24, 0.24, 0.12), M["team"], v=16), "head"))
        objs.append((prim("cube", "Peak", (0, -0.125, 1.77), (0.17, 0.07, 0.016), M["gear"], rot=(-0.1, 0, 0)), "head"))
        objs.append((prim("sphere", "Star", (0, -0.12, 1.815), (0.035, 0.016, 0.035), M["gold"]), "head"))
        objs.append((prim("cyl", "Collar", (0, 0.0, 1.5), (0.22, 0.2, 0.08), M["team"], v=14), "chest"))
    else:
        objs.append((prim("sphere", "Turban", (0, 0.01, 1.8), (0.265, 0.27, 0.155), M["cloth"]), "head"))
        objs.append((prim("cube", "Scarf", (0, -0.06, 1.545), (0.2, 0.12, 0.07), M["scarf"], bevel=0.02), "head"))
        objs.append((prim("cube", "Bandolier", (0, -0.13, 1.3), (0.06, 0.04, 0.42), M["gear"], rot=(0, 0.6, 0)), "chest"))
    # Gesicht: modellierter Kopf mit Augen, Brauen, Ohren; Haar und Bart als Schalen
    hide_hair = variant == "worker" and faction == "shadow"
    iris = {"west": "iris_blue", "red": "iris_grey", "shadow": "iris_brown"}[faction]
    objs.append((make_head("Head", 1.0, M["skin"], None), "head"))
    objs.append((make_head("Lips", 1.012, M["lip"], None, keep=lambda x, y, z: y < -0.4 and (x / 0.27) ** 2 + ((z + 0.505) / 0.115) ** 2 < 1.0, smooth=1), "head"))
    for sx in (-0.043, 0.043):
        sg = 1 if sx > 0 else -1
        objs.append((prim("sphere", "EyeW", (sx, -0.094, 1.7), (0.031, 0.026, 0.023), M["eyew"]), "head"))
        objs.append((prim("sphere", "Iris", (sx, -0.105, 1.7), (0.018, 0.01, 0.018), M[iris]), "head"))
        objs.append((prim("sphere", "Pupil", (sx, -0.11, 1.7), (0.008, 0.006, 0.008), M["pupil"]), "head"))
        objs.append((prim("sphere", "LidUp", (sx, -0.095, 1.711), (0.035, 0.028, 0.01), M["skin"]), "head"))
        objs.append((prim("cube", "Brow", (sx, -0.115, 1.735), (0.052, 0.014, 0.013), M["hair"], rot=(0, 0, 0.18 * sg), bevel=0.004), "head"))
        objs.append((prim("sphere", "Ear", (sx * 2.5, 0.012, 1.682), (0.016, 0.034, 0.05), M["skin"]), "head"))
        objs.append((prim("sphere", "EarInner", (sx * 2.38, 0.008, 1.682), (0.008, 0.02, 0.032), M["skin_dark"]), "head"))
    objs.append((prim("sphere", "AdamsApple", (0, -0.045, 1.52), (0.022, 0.024, 0.026), M["skin"]), "head"))
    if not hide_hair:
        if faction == "west":
            # kurzer Seitenscheitel: Schale über Stirn, Scheitel und Hinterkopf
            hair = make_head("Hair", 1.045, M["hair"], None, keep=lambda x, y, z: z > 0.5 or (y > -0.05 and z > -0.25) or (abs(x) > 0.7 and z > 0.15), smooth=1)
        elif faction == "red":
            hair = make_head("Hair", 1.025, M["hair"], None, keep=lambda x, y, z: z > 0.6 or (y > 0.0 and z > -0.2), smooth=1)
        else:
            hair = make_head("Hair", 1.07, M["hair"], None, keep=lambda x, y, z: z > 0.45 or (y > -0.1 and z > -0.45) or (abs(x) > 0.75 and z > -0.1), smooth=1)
        objs.append((hair, "head"))
    if faction == "red" and variant != "worker" or (faction == "red" and variant == "worker"):
        objs.append((make_head("Stubble", 1.012, M["hair"], None, keep=lambda x, y, z: z < -0.4 and z > -0.9 and y < 0.0 and (abs(x) > 0.18 or z < -0.62 or z > -0.42), smooth=1), "head"))
    if faction == "shadow":
        objs.append((make_head("Beard", 1.04, M["hair"], None, keep=lambda x, y, z: z < -0.15 and z > -0.95 and y < 0.2 and not ((x / 0.3) ** 2 + ((z + 0.505) / 0.12) ** 2 < 1.0 and y < -0.3), smooth=1), "head"))
    # Reißverschluss mit Zipper, Werkzeuggürtel (Arbeiter)
    objs.append((prim("cube", "Zip", (0, -0.171, 1.28), (0.012, 0.008, 0.3), M["metal"]), "chest"))
    objs.append((prim("cube", "ZipPull", (0, -0.176, 1.4), (0.02, 0.008, 0.04), M["metal"], bevel=0.003), "chest"))
    if variant == "worker":
        for sx in (-0.13, 0.13):
            objs.append((prim("cube", "ToolPouch", (sx, -0.14, 0.95), (0.075, 0.05, 0.095), M["gear"], bevel=0.01), "spine"))
        objs.append((prim("cyl", "HammerHandle", (-0.2, -0.04, 0.84), (0.022, 0.022, 0.3), M["wood"], v=8), "spine"))
        objs.append((prim("cube", "HammerHead", (-0.2, -0.04, 0.99), (0.075, 0.03, 0.04), M["metal"], bevel=0.004), "spine"))
    # Gürtel und Knieschützer
    objs.append((prim("cyl", "Belt", (0, 0, 0.98), (0.36, 0.3, 0.07), M["gear"], v=16), "spine"))
    objs.append((prim("cube", "Buckle", (0, -0.15, 0.98), (0.06, 0.02, 0.05), M["metal"]), "spine"))
    for side, x in (("L", 0.11), ("R", -0.11)):
        objs.append((prim("sphere", "Knee" + side, (x, -0.07, 0.52), (0.13, 0.08, 0.13), M["gear"]), "shin." + side))
    # Weste/Rucksack
    if variant != "worker":
        objs.append((prim("cube", "Vest", (0, -0.03, 1.3), (0.38, 0.27, 0.3), M["gear"] if faction != "shadow" else M["cloth"], bevel=0.04), "chest"))
        for sx in (-0.09, 0.09):
            objs.append((prim("cube", "Pouch", (sx, -0.17, 1.2), (0.08, 0.05, 0.09), M["gear"], bevel=0.015), "chest"))
        objs.append((prim("cube", "Pack", (0, 0.17, 1.3), (0.26, 0.13, 0.32), M["pack"], bevel=0.03), "chest"))
    else:
        objs.append((prim("cube", "Vest", (0, -0.02, 1.32), (0.37, 0.26, 0.25), M["hiviz"], bevel=0.03), "chest"))
    # Waffe in den Händen
    if variant == "inf":
        g = prim("cube", "Rifle", (-0.05, -0.38, 1.1), (0.05, 0.62, 0.08), M["gun"], bevel=0.01)
        objs.append((g, "hand.R"))
        objs.append((prim("cube", "Mag", (-0.05, -0.36, 1.02), (0.035, 0.06, 0.12), M["gun"]), "hand.R"))
        objs.append((prim("cube", "Stock", (-0.08, -0.03, 1.12), (0.05, 0.16, 0.1), M["gun"]), "hand.R"))
        objs.append((prim("cyl", "Barrel", (-0.05, -0.75, 1.12), (0.022, 0.022, 0.22), M["metal"], rot=(math.pi / 2, 0, 0), v=8), "hand.R"))
    elif variant == "inf_at":
        t = prim("cyl", "Launcher", (-0.16, -0.15, 1.5), (0.1, 0.1, 1.15), M["launcher"], rot=(math.pi / 2, 0, 0), v=14)
        objs.append((t, "chest"))
        objs.append((prim("cyl", "Warhead", (-0.16, -0.78, 1.5), (0.12, 0.12, 0.22), M["metal"], rot=(math.pi / 2, 0, 0), v=12), "chest"))
        objs.append((prim("cube", "Grip", (-0.16, -0.25, 1.4), (0.04, 0.06, 0.12), M["gun"]), "chest"))
    else:
        objs.append((prim("cube", "Toolbox", (-0.15, -0.2, 0.95), (0.28, 0.12, 0.18), M["tool"], bevel=0.01), "hand.R"))
    # Schuhe und Hände mit allen Einzelheiten
    for side in ("L", "R"):
        boot_parts(side, M, objs)
        hand_parts(side, M, objs)
    # Kleidungsdetails: Kragen, Taschen, Gürtelschlaufen, Nähte, Uhr
    objs.append((prim("cyl", "Collar2", (0, 0.0, 1.52), (0.17, 0.16, 0.05), M["team"], v=14), "chest"))
    for sx in (-0.095, 0.095):
        objs.append((prim("cube", "ChestPocket", (sx, -0.163, 1.33), (0.09, 0.012, 0.085), M["team"], bevel=0.004), "chest"))
        objs.append((prim("cube", "PocketFlap", (sx, -0.168, 1.365), (0.095, 0.012, 0.03), M["gear"], bevel=0.004), "chest"))
        objs.append((prim("cube", "PocketBtn", (sx, -0.176, 1.365), (0.015, 0.008, 0.015), M["metal"]), "chest"))
        objs.append((prim("cube", "BackPocket", (sx, 0.115, 0.9), (0.1, 0.012, 0.1), M["team"], bevel=0.004), "spine"))
    for side, xx in (("L", 0.175), ("R", -0.175)):
        objs.append((prim("cube", "CargoPocket", (xx, -0.03, 0.7), (0.034, 0.12, 0.14), M["team"], bevel=0.01), "thigh." + side))
        objs.append((prim("cube", "CargoFlap", (xx + (0.002 if side == "L" else -0.002), -0.03, 0.765), (0.036, 0.125, 0.03), M["gear"], bevel=0.005), "thigh." + side))
    for k in range(8):
        a = math.tau * k / 8.0 + 0.2
        objs.append((prim("cube", "BeltLoop", (math.cos(a) * 0.178, math.sin(a) * 0.15, 0.985), (0.02, 0.015, 0.06), M["team"], rot=(0, 0, a + math.pi / 2), bevel=0.003), "spine"))
    wl = Vector(J["wrist.L"][0])
    objs.append((prim("cyl", "WatchStrap", tuple(wl + Vector((-0.002, 0.02, 0.0))), (0.12, 0.12, 0.03), M["gear"], v=10), "forearm.L"))
    objs.append((prim("cyl", "WatchFace", tuple(wl + Vector((0.0, 0.02, 0.05))), (0.05, 0.05, 0.012), M["metal"], v=12), "forearm.L"))
    for ob, bone in objs:
        attach(ob, rig, bone)
    return [o for o, b in objs]

# ------------------------------------------------------------------ Animationen
# Posen in Armature-Achsen (Grad): um X = Scharnier vorne/hinten, um Y = seitlich kippen, um Z = drehen.
#   Oberschenkel/Oberarm um -X: nach vorne, um +X: nach hinten.
#   Unterschenkel um +X: Knie beugt (Ferse nach hinten) – nie negativ.
#   Unterarm um -X: Ellbogen beugt (Hand nach oben/vorne).
#   Fuß um +X: Spitze nach unten, um -X: Spitze nach oben.
ALL_BONES = [b[0] for b in BONES]

def _q(rig, bname, deg):
    pb = rig.pose.bones[bname]
    rest = pb.bone.matrix_local.to_quaternion()
    q = Euler([math.radians(a) for a in deg], "XYZ").to_quaternion()
    return rest.inverted() @ q @ rest

def key_pose(rig, frame, pose, root_loc=(0, 0, 0)):
    for b in ALL_BONES:
        pb = rig.pose.bones[b]
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = _q(rig, b, pose.get(b, (0, 0, 0)))
        pb.keyframe_insert("rotation_quaternion", frame=frame)
    root = rig.pose.bones["root"]
    rest = root.bone.matrix_local.to_quaternion()
    root.location = rest.inverted() @ Vector(root_loc)
    root.keyframe_insert("location", frame=frame)

def new_action(rig, name):
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    return act

def _leg(t):
    """Ein Bein im Gangzyklus (t in Radiant). Gibt (Oberschenkel, Knie, Fuß) zurück."""
    thigh = -24.0 * math.sin(t)
    swing = max(0.0, math.cos(t + 0.3)) ** 1.5           # Schwungphase: Knie stark gebeugt
    load = max(0.0, math.sin(t)) * max(0.0, -math.cos(t))  # nach Fersenaufsatz: leichte Federung
    knee = 5.0 + 55.0 * swing + 14.0 * load
    toe_off = max(0.0, -math.sin(t)) * max(0.0, math.cos(t)) # Abstoßen mit dem Ballen
    foot = -(thigh + knee) * 0.9 + 22.0 * toe_off - 6.0 * swing
    return thigh, knee, foot

def make_anims(rig, variant):
    worker = variant == "worker"
    acts = []

    # ---------- Idle: Atmen, Gewicht verlagern, Umschauen (2 s)
    a = new_action(rig, "Idle")
    for f in range(1, 50, 4):
        t = (f - 1) / 48.0 * math.tau
        shift = math.sin(t)
        pose = {
            "root": (0, 2.0 * shift, 0),
            "thigh.L": (-3, -2.0 * shift, 0), "shin.L": (4 + 2 * max(0, shift), 0, 0), "foot.L": (-1, 0, 0),
            "thigh.R": (3, -2.0 * shift, 0), "shin.R": (4 + 2 * max(0, -shift), 0, 0), "foot.R": (-7, 0, 0),
            "spine": (1.5 * math.sin(2 * t), -1.5 * shift, 0), "chest": (1.5 * math.sin(2 * t), 0, 0),
            "head": (2 * math.sin(2 * t + 1), 0, 18 * math.sin(t * 0.5 + 0.4)),
        }
        if worker:
            pose.update({"upperarm.L": (4, 0, 4), "upperarm.R": (4, 0, -4), "forearm.L": (-10, 0, 0), "forearm.R": (-10, 0, 0)})
        key_pose(rig, f, pose, (0.006 * shift, 0, -0.006 + 0.004 * math.sin(2 * t)))
    acts.append(a)

    # ---------- Walk: 13 Posen pro Schritt-Paar (1 s)
    a = new_action(rig, "Walk")
    for f in range(1, 26, 2):
        t = (f - 1) / 24.0 * math.tau
        tl, kl, fl = _leg(t)
        tr, kr, fr = _leg(t + math.pi)
        pose = {
            "thigh.L": (tl, 0, 0), "shin.L": (kl, 0, 0), "foot.L": (fl, 0, 0),
            "thigh.R": (tr, 0, 0), "shin.R": (kr, 0, 0), "foot.R": (fr, 0, 0),
            "root": (3, 3.0 * math.sin(t), 6.0 * math.sin(t)),
            "spine": (4, 0, -5.0 * math.sin(t)), "chest": (2, 0, -3.0 * math.sin(t)),
            "neck": (0, 0, 3.0 * math.sin(t)), "head": (-3 + 2 * math.cos(2 * t), 0, 2.0 * math.sin(t)),
        }
        if worker:
            pose.update({"upperarm.L": (22 * math.sin(t), 0, 5), "upperarm.R": (-22 * math.sin(t), 0, -5),
                         "forearm.L": (-12 - 10 * max(0, -math.sin(t)), 0, 0), "forearm.R": (-12 - 10 * max(0, math.sin(t)), 0, 0)})
        else:
            pose.update({"upperarm.R": (-3 * math.sin(t), 0, 0), "upperarm.L": (3 * math.sin(t), 0, 0)})
        key_pose(rig, f, pose, (0, 0, 0.022 * math.cos(2 * t) - 0.012))
    acts.append(a)

    # ---------- Shoot: Gewehr an die Schulter, Rückstoß (0,5 s)
    a = new_action(rig, "Shoot")
    stance = {"thigh.L": (-14, 0, 0), "shin.L": (14, 0, 0), "foot.L": (0, 0, 0),
              "thigh.R": (10, 0, 0), "shin.R": (12, 0, 0), "foot.R": (-22, 0, 0),
              "root": (0, 0, -12), "spine": (6, 0, 6), "chest": (2, 0, 8)}
    if variant == "inf_at":
        aim = {"upperarm.R": (-70, 0, 15), "forearm.R": (-60, 0, 0), "upperarm.L": (-80, 0, -15), "forearm.L": (-30, 0, 0), "head": (6, 8, 4)}
        kick = 9
    else:
        aim = {"upperarm.R": (-40, 0, 18), "forearm.R": (-38, 0, 0), "hand.R": (78, 0, 0),
               "upperarm.L": (-58, 0, -22), "forearm.L": (-22, 0, 0), "head": (8, 6, 4)}
        kick = 5
    base = {**stance, **aim}
    key_pose(rig, 1, base, (0, 0, -0.04))
    recoil = dict(base)
    recoil["chest"] = (2 + kick, 0, 8)
    recoil["upperarm.R"] = (aim["upperarm.R"][0] + kick * 0.6, aim["upperarm.R"][1], aim["upperarm.R"][2])
    key_pose(rig, 3, recoil, (0, 0.02, -0.04))
    key_pose(rig, 7, base, (0, 0, -0.04))
    key_pose(rig, 13, base, (0, 0, -0.04))
    acts.append(a)

    # ---------- Die: Knie knicken ein, Fall nach hinten (1 s)
    a = new_action(rig, "Die")
    key_pose(rig, 1, {}, (0, 0, 0))
    key_pose(rig, 7, {"thigh.L": (-38, 0, 0), "shin.L": (72, 0, 0), "foot.L": (-30, 0, 0),
                      "thigh.R": (-30, 0, 0), "shin.R": (64, 0, 0), "foot.R": (-30, 0, 0),
                      "spine": (18, 0, 6), "chest": (10, 0, 0), "head": (20, 0, 0),
                      "upperarm.L": (12, 0, -10), "upperarm.R": (12, 0, 10)}, (0, 0, -0.3))
    lie = {"root": (-82, 0, 6), "thigh.L": (58, 0, 6), "shin.L": (22, 0, 0), "foot.L": (-25, 0, 0),
           "thigh.R": (48, 0, -8), "shin.R": (38, 0, 0), "foot.R": (-25, 0, 0),
           "spine": (-6, 0, 0), "head": (-12, 0, 28),
           "upperarm.L": (-120, 0, -45), "forearm.L": (-20, 0, 0), "upperarm.R": (-100, 0, 55), "forearm.R": (-40, 0, 0)}
    key_pose(rig, 15, lie, (0, 0.35, -0.8))
    bounce = dict(lie)
    bounce["root"] = (-86, 0, 6)
    key_pose(rig, 18, bounce, (0, 0.38, -0.76))
    key_pose(rig, 24, lie, (0, 0.38, -0.8))
    acts.append(a)
    rig.animation_data.action = acts[0]
    return acts
# ------------------------------------------------------------------ Aufbau je Fraktion/Variante
def build(faction, variant):
    reset()
    team_col = {"west": (0.5, 0.52, 0.55), "red": (0.32, 0.36, 0.25), "shadow": (0.6, 0.52, 0.38)}[faction]
    M = {
        "team": material("TeamUniform", team_col, 0.0, 0.85),
        "skin": material("Skin", (0.72, 0.53, 0.4), 0.0, 0.6),
        "boot": material("Boots", (0.08, 0.07, 0.06), 0.0, 0.7),
        "gear": material("Gear", (0.15, 0.16, 0.13), 0.0, 0.8),
        "pack": material("Pack", (0.22, 0.22, 0.17), 0.0, 0.9),
        "gun": material("Gun", (0.06, 0.06, 0.065), 0.5, 0.5),
        "metal": material("Metal", (0.35, 0.36, 0.38), 0.85, 0.35),
        "launcher": material("Launcher", (0.25, 0.3, 0.2), 0.3, 0.6),
        "visor": material("Visor", (0.2, 0.7, 1.0), 0.0, 0.1, 2.0),
        "gold": material("Gold", (0.95, 0.75, 0.2), 0.9, 0.3),
        "cloth": material("Cloth", (0.55, 0.47, 0.33), 0.0, 0.95),
        "scarf": material("Scarf", (0.5, 0.15, 0.12), 0.0, 0.9),
        "hard": material("HardHat", (0.95, 0.75, 0.1), 0.1, 0.4),
        "hiviz": material("HiViz", (1.0, 0.45, 0.05), 0.0, 0.6, 0.3),
        "tool": material("Toolbox", (0.7, 0.1, 0.08), 0.4, 0.5),
        "skin_dark": material("SkinDark", (0.45, 0.28, 0.22), 0.0, 0.7),
        "iris_blue": material("IrisBlue", (0.25, 0.5, 0.75), 0.0, 0.3),
        "iris_grey": material("IrisGrey", (0.45, 0.5, 0.52), 0.0, 0.3),
        "iris_brown": material("IrisBrown", (0.3, 0.17, 0.08), 0.0, 0.3),
        "nail": material("Nail", (0.85, 0.7, 0.65), 0.0, 0.4),
        "wood": material("Wood", (0.45, 0.3, 0.16), 0.0, 0.8),
        "sole": material("Sole", (0.04, 0.04, 0.04), 0.0, 0.9),
        "lace": material("Lace", (0.75, 0.72, 0.6), 0.0, 0.8),
        "eyew": material("EyeWhite", (0.9, 0.9, 0.88), 0.0, 0.3),
        "pupil": material("Pupil", (0.05, 0.05, 0.06), 0.0, 0.2),
        "hair": material("Hair", (0.14, 0.1, 0.07) if faction != "west" else (0.32, 0.22, 0.12), 0.0, 0.85),
        "lip": material("Lip", (0.5, 0.25, 0.22), 0.0, 0.6),
    }
    if variant == "worker":
        # Arbeitskleidung je Fraktion
        wk = {"west": ((0.72, 0.75, 0.8), (0.92, 0.94, 0.97), (0.75, 0.95, 0.15)),
              "red": ((0.27, 0.3, 0.22), (0.72, 0.1, 0.08), (0.2, 0.22, 0.17)),
              "shadow": ((0.44, 0.35, 0.24), (0.55, 0.47, 0.33), (0.3, 0.26, 0.18))}[faction]
        M["hard"] = material("HardHat", wk[1], 0.1, 0.4)
        M["hiviz"] = material("HiViz", wk[2], 0.0, 0.6, 0.3 if faction == "west" else 0.0)
    uniform = M["team"] if variant != "worker" else material("Overall", {"west": (0.72, 0.75, 0.8), "red": (0.27, 0.3, 0.22), "shadow": (0.44, 0.35, 0.24)}[faction], 0.0, 0.85)
    if variant == "worker":
        M["team"] = uniform   # Saum, Taschen, Manschetten in Arbeitskleidung, nicht in Teamfarbe
    body = build_body(uniform, M["skin"], M["boot"])
    rig = build_rig()
    skin_to(rig, body)
    parts = gear(faction, variant, rig, M)
    make_anims(rig, variant)
    # Größe für das Spiel
    rig.scale = (SCALE, SCALE, SCALE)
    out = os.path.join(root_dir, "models", "units", "%s_%s.glb" % (faction, variant))
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=False, export_yup=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_skins=True, export_def_bones=False)
    print("SOLDIER_OK", out)
    return rig

def preview(faction):
    rig = build(faction, "inf")
    rig.animation_data.action = bpy.data.actions["Walk"]
    bpy.context.scene.frame_set(7)
    bpy.ops.mesh.primitive_plane_add(size=10)
    g = bpy.context.active_object
    g.data.materials.append(material("Ground", (0.3, 0.32, 0.22), 0, 0.95))
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(45), 0, math.radians(30))
    bpy.context.scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (-2.6, -3.6, 2.3)
    cam.rotation_euler = (Vector((0, 0, 1.1)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    sc = bpy.context.scene
    sc.camera = cam
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.55, 0.7, 1)
    sc.world = w
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 900
    sc.render.resolution_y = 900
    sc.render.filepath = os.path.join(root_dir, "shots", "soldier_%s.png" % faction)
    bpy.ops.render.render(write_still=True)

os.makedirs(os.path.join(root_dir, "models", "units"), exist_ok=True)
for f in FACTIONS:
    for v in VARIANTS:
        build(f, v)
def anim_sheet(faction):
    """Seitenansicht mehrerer Bilder je Animation nach shots/anim/."""
    rig = build(faction, "inf")
    sc = bpy.context.scene
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(45), 0, math.radians(60))
    sc.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    sc.collection.objects.link(cam)
    cam.location = (5.2, -1.6, 1.3)
    cam.rotation_euler = (Vector((0, 0, 1.1)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    sc.camera = cam
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.62, 0.7, 1)
    sc.world = w
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x = 300
    sc.render.resolution_y = 420
    out = os.path.join(root_dir, "shots", "anim")
    os.makedirs(out, exist_ok=True)
    for act, frames in (("Walk", [1, 4, 7, 10, 13, 16, 19, 22]), ("Shoot", [1, 3]), ("Die", [7, 15]), ("Idle", [1])):
        rig.animation_data.action = bpy.data.actions[act]
        for fr in frames:
            sc.frame_set(fr)
            sc.render.filepath = os.path.join(out, "%s_%02d.png" % (act, fr))
            bpy.ops.render.render(write_still=True)

if "--sheet" in sys.argv:
    anim_sheet("west")
else:
    for f in FACTIONS:
        preview(f)
