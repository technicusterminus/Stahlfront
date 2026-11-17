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

def build_body(mat_uniform, mat_skin, mat_boot):
    names = list(J.keys())
    me = bpy.data.meshes.new("Body")
    me.from_pydata([J[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in EDGES], [])
    ob = bpy.data.objects.new("Body", me)
    bpy.context.scene.collection.objects.link(ob)
    activate(ob)
    sk = ob.modifiers.new("Skin", "SKIN")
    sk.use_smooth_shade = True
    for i, n in enumerate(names):
        r = J[n][1]
        sv = me.skin_vertices[0].data[i]
        # Brust und Becken etwas breiter als tief
        if n in ("chest", "spine"):
            sv.radius = (r * 1.25, r * 0.85)
        elif n == "pelvis":
            sv.radius = (r * 1.15, r * 0.9)
        else:
            sv.radius = (r, r)
    me.skin_vertices[0].data[names.index("pelvis")].use_root = True
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

def gear(faction, variant, rig, M):
    objs = []
    # Kopfbedeckung
    if variant == "worker":
        h = prim("sphere", "Helmet", (0, 0.0, 1.76), (0.27, 0.29, 0.17), M["hard"])
        objs.append((h, "head"))
        objs.append((prim("cube", "Brim", (0, -0.12, 1.72), (0.22, 0.1, 0.02), M["hard"]), "head"))
    elif faction == "west":
        h = prim("sphere", "Helmet", (0, 0.01, 1.76), (0.27, 0.29, 0.2), M["team"])
        objs.append((h, "head"))
        objs.append((prim("cube", "Visor", (0, -0.12, 1.71), (0.17, 0.03, 0.05), M["visor"], bevel=0.01), "head"))
        objs.append((prim("cube", "NV", (0, -0.1, 1.84), (0.06, 0.06, 0.05), M["gear"], bevel=0.01), "head"))
    elif faction == "red":
        objs.append((prim("cyl", "Cap", (0, 0.01, 1.78), (0.25, 0.25, 0.12), M["team"], v=16), "head"))
        objs.append((prim("cube", "Peak", (0, -0.13, 1.74), (0.18, 0.09, 0.02), M["gear"]), "head"))
        objs.append((prim("sphere", "Star", (0, -0.13, 1.8), (0.04, 0.02, 0.04), M["gold"]), "head"))
        objs.append((prim("cyl", "Collar", (0, 0.0, 1.5), (0.22, 0.2, 0.08), M["team"], v=14), "chest"))
    else:
        objs.append((prim("sphere", "Turban", (0, 0.01, 1.77), (0.27, 0.27, 0.18), M["cloth"]), "head"))
        objs.append((prim("cube", "Scarf", (0, -0.1, 1.62), (0.2, 0.07, 0.09), M["scarf"], bevel=0.02), "head"))
        objs.append((prim("cube", "Bandolier", (0, -0.13, 1.3), (0.06, 0.04, 0.42), M["gear"], rot=(0, 0.6, 0)), "chest"))
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
    for ob, bone in objs:
        attach(ob, rig, bone)
    return [o for o, b in objs]

# ------------------------------------------------------------------ Animationen
def key_pose(rig, frame, pose):
    for bname, rot in pose.items():
        pb = rig.pose.bones[bname]
        pb.rotation_mode = "XYZ"
        if bname == "root" and isinstance(rot, tuple) and len(rot) == 2:
            pb.location = Vector(rot[1])
            pb.keyframe_insert("location", frame=frame)
            rot = rot[0]
        pb.rotation_euler = Euler([math.radians(a) for a in rot])
        pb.keyframe_insert("rotation_euler", frame=frame)

ALL_BONES = [b[0] for b in BONES]

def new_action(rig, name):
    rig.animation_data_create()
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    rig.animation_data.action = act
    return act

def rest(extra=None):
    p = {b: (0, 0, 0) for b in ALL_BONES}
    p["root"] = ((0, 0, 0), (0, 0, 0))
    if extra:
        p.update(extra)
    return p

def make_anims(rig, variant):
    # Grundhaltung der Arme: Waffe vor dem Körper
    hold = {} if variant == "worker" else {"upperarm.R": (-25, 0, 10), "forearm.R": (-30, 0, 0), "upperarm.L": (-20, 0, -5)}
    acts = []
    # Idle: leichtes Atmen, Kopf schaut sich um
    a = new_action(rig, "Idle")
    for f, k in [(1, 0), (24, 1), (48, 0)]:
        key_pose(rig, f, rest({**hold, "chest": (2 * k, 0, 0), "head": (0, 0, 12 * math.sin(k * 2)), "root": ((0, 0, 0), (0, 0, -0.01 * k))}))
    acts.append(a)
    # Walk: Beine, Gegenschwung, Becken-Wippen (1 s)
    a = new_action(rig, "Walk")
    for i, f in enumerate([1, 7, 13, 19, 25]):
        s = [1, 0, -1, 0, 1][i]
        up = [0, 1, 0, 1, 0][i]
        pose = rest({**hold,
                     "thigh.L": (32 * s, 0, 0), "shin.L": (-40 * max(0, -s) - 15 * up, 0, 0),
                     "thigh.R": (-32 * s, 0, 0), "shin.R": (-40 * max(0, s) - 15 * up, 0, 0),
                     "foot.L": (10 * s, 0, 0), "foot.R": (-10 * s, 0, 0),
                     "spine": (5, 0, 4 * s), "root": ((0, 0, 0), (0, 0, 0.03 * up))})
        if variant == "worker":
            pose["upperarm.L"] = (-25 * s, 0, 0)
            pose["upperarm.R"] = (25 * s, 0, 0)
        key_pose(rig, f, pose)
    acts.append(a)
    # Shoot: Anschlag, Rückstoß
    a = new_action(rig, "Shoot")
    aim = {"upperarm.R": (-75, 0, 15), "forearm.R": (-20, 0, 0), "upperarm.L": (-70, 0, -25), "forearm.L": (-15, 0, 0), "head": (5, 0, 0), "spine": (6, 0, 0)}
    if variant == "inf_at":
        aim = {"upperarm.R": (-60, 0, 20), "forearm.R": (-60, 0, 0), "upperarm.L": (-55, 0, -10), "head": (-5, 0, -8)}
    key_pose(rig, 1, rest(aim))
    key_pose(rig, 3, rest({**aim, "chest": (-6, 0, 0), "upperarm.R": (aim["upperarm.R"][0] + 8, 0, aim["upperarm.R"][2])}))
    key_pose(rig, 10, rest(aim))
    acts.append(a)
    # Die: nach hinten fallen
    a = new_action(rig, "Die")
    key_pose(rig, 1, rest(hold))
    key_pose(rig, 8, rest({"root": ((-30, 0, 5), (0, 0.05, -0.15)), "spine": (-15, 0, 0), "head": (-20, 0, 0), "upperarm.R": (-90, 0, 40), "upperarm.L": (-80, 0, -50), "thigh.L": (25, 0, 0), "shin.L": (-50, 0, 0)}))
    key_pose(rig, 18, rest({"root": ((-88, 0, 8), (0, 0.45, -0.78)), "spine": (-5, 0, 0), "head": (15, 0, 25), "upperarm.R": (-150, 0, 50), "upperarm.L": (-140, 0, -60), "thigh.L": (35, 0, 0), "shin.L": (-60, 0, 0), "thigh.R": (10, 0, 0)}))
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
    }
    uniform = M["team"] if variant != "worker" else material("Overall", (0.25, 0.3, 0.4), 0.0, 0.85)
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
for f in FACTIONS:
    preview(f)
