"""Besatzung für Fahrzeuge: Figuren aus make_soldier.py, per IK in Sitz- oder Standhaltung gebracht und zu starren Netzen gebacken.

Benutzung (im Fahrzeugskript, nach B.setup):
    import sf_crew as C
    lower, upper, pts = C.figure("shadow", "rider", pelvis=(0, 0.1, 1.1),
                                 feet={"L": (...), "R": (...)}, hands={"L": (...), "R": (...)},
                                 pose={"spine": (15, 0, 0)}, split_upper=False)
    P.extend(lower + upper)       # starr im Rumpf
Haltung: Grad um die Achsen der Rüstung wie in make_soldier.py (Wirbelsäule um +X = nach vorn beugen).
feet/hands: Zielpunkte für Knöchel bzw. Handgelenk (Weltlage, vorne = -Y). Knie und Ellbogen beugen sich
in die Richtung der Ruhehaltung (Knie nach vorn, Ellbogen nach außen hinten).
split_upper: Oberkörper (ab Hüfte) getrennt zurückgeben, z. B. als drehbaren Schützen (Turret).
marks: {"muzzle": ("hand.R", (x, y, z))} – Punkte in Ruhelage, die mit dem Knochen wandern; Rückgabe in Weltlage.
"""
import math
import bpy, bmesh
from mathutils import Vector, Matrix
import sf_common as S
import make_soldier as SO

UPPER = {"spine", "chest", "neck", "head", "upperarm.L", "forearm.L", "hand.L", "upperarm.R", "forearm.R", "hand.R"}


def _register_looks(mats, wear=0.2, dirt=0.35):
    """Die Figurenmaterialien beim Backen mit ihren echten Farben verwenden (sonst Einheitsgrau)."""
    for m in mats:
        if m is None or not m.use_nodes:
            continue
        b = m.node_tree.nodes.get("Principled BSDF")
        if b is None:
            continue
        base = m.name.split(".")[0]
        if base in S.LOOK:
            continue
        col = tuple(b.inputs["Base Color"].default_value[:3])
        emit = float(b.inputs["Emission Strength"].default_value) if "Emission Strength" in b.inputs else 0.0
        S.LOOK[base] = (col, float(b.inputs["Metallic"].default_value), float(b.inputs["Roughness"].default_value), wear, dirt, emit)


def _empty(name, loc):
    e = bpy.data.objects.new(name, None)
    S.scene.collection.objects.link(e)
    e.location = loc
    return e


def figure(faction, variant, pelvis, feet=None, hands=None, pose=None, yaw=0.0, split_upper=False, marks=None, foot_pitch=None, detail=0.3):
    M, uniform = SO.soldier_materials(faction, variant)
    # keine Teamfarbe auf der Kleidung: das Fahrzeug trägt die Kennung, die Besatzung ihre Fraktionsuniform
    M["team"].name = "CrewUniform"
    M["mark"].name = "CrewMarking"
    body = SO.build_body(uniform, M["boot"])
    rig = SO.build_rig()
    SO.skin_to(rig, body)
    SO.gear(faction, variant, rig, M)
    _register_looks(list(M.values()) + [uniform])
    mk = {}
    for name, (bone, p) in (marks or {}).items():
        e = _empty("mk_" + name, p)
        SO.attach(e, rig, bone)
        mk[name] = e
    # Becken der Ruhelage (0, 0, 0.95) auf den Sitzpunkt
    rot = Matrix.Rotation(yaw, 3, "Z")
    rig.rotation_euler = (0, 0, yaw)
    rig.location = Vector(pelvis) - rot @ Vector((0, 0, 0.95))
    bpy.context.view_layer.update()

    SO.activate(rig)
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    for bname, deg in (pose or {}).items():
        rig.pose.bones[bname].rotation_quaternion = SO._q(rig, bname, deg)
    temps = []

    def ik(bone, goal):
        t = _empty("ik_" + bone, goal)
        temps.append(t)
        c = rig.pose.bones[bone].constraints.new("IK")
        c.target = t
        c.chain_count = 2
        c.use_tail = True
        c.iterations = 800

    for side, goal in (feet or {}).items():
        ik("shin." + side, goal)
    for side, goal in (hands or {}).items():
        ik("forearm." + side, goal)
    bpy.context.view_layer.update()
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.visual_transform_apply()
    for pb in rig.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    # Füße waagerecht auf die Rasten (Winkel in Grad, um +X = Spitze nach unten)
    if foot_pitch is not None:
        bpy.context.view_layer.update()
        for side in ("L", "R"):
            pb = rig.pose.bones["foot." + side]
            pb.rotation_quaternion = SO._q(rig, "foot." + side, (foot_pitch, 0, 0))
    bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.view_layer.update()

    # Haltung in die Netze backen
    SO.activate(body)
    for m in list(body.modifiers):
        if m.type == "ARMATURE":
            bpy.ops.object.modifier_apply(modifier=m.name)
    upper_body = None
    if split_upper:
        names = {g.index: g.name for g in body.vertex_groups}
        bm = bmesh.new()
        bm.from_mesh(body.data)
        dl = bm.verts.layers.deform.active
        up = set()
        for v in bm.verts:
            d = v[dl] if dl is not None else {}
            if d:
                gi = max(d.items(), key=lambda kv: kv[1])[0]
                if names.get(gi) in UPPER:
                    up.add(v.index)
        for f in bm.faces:
            f.select = sum(1 for v in f.verts if v.index in up) * 2 > len(f.verts)
        for e in bm.edges:
            e.select = all(f.select for f in e.link_faces) if e.link_faces else False
        for v in bm.verts:
            v.select = any(f.select for f in v.link_faces)
        bm.to_mesh(body.data)
        bm.free()
        before = set(bpy.data.objects)
        SO.activate(body)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_mode(type="FACE")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        new = [o for o in bpy.data.objects if o not in before]
        upper_body = new[0] if new else None
    pts = {name: e.matrix_world.translation.copy() for name, e in mk.items()}
    lower, upper = [body], ([upper_body] if upper_body is not None else [])
    for ob in list(rig.children):
        mw = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_world = mw
        if ob.name.startswith("mk_") or ob in (body, upper_body):
            continue
        bone = ob.name[len("Equipment_"):] if ob.name.startswith("Equipment_") else ""
        (upper if (split_upper and bone.split(".")[0] in {b.split(".")[0] for b in UPPER}) else lower).append(ob)
    for ob in [body] + ([upper_body] if upper_body else []):
        mw = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_world = mw
        for m in list(ob.modifiers):
            ob.modifiers.remove(m)
        ob.vertex_groups.clear()
    for e in list(mk.values()) + temps:
        bpy.data.objects.remove(e, do_unlink=True)
    bpy.data.objects.remove(rig, do_unlink=True)
    # Besatzung aus der RTS-Kamera nur wenige Pixel groß: Netze ausdünnen (wird beim Verschmelzen angewendet)
    if detail < 1.0:
        for ob in lower + upper:
            if ob.type == "MESH" and len(ob.data.polygons) > 40:
                d = ob.modifiers.new("Decimate", "DECIMATE")
                d.ratio = detail
    if not split_upper:
        lower = lower + upper
        upper = []
    return lower, upper, pts
