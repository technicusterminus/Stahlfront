"""Kampfpanzer fuer Stahlfront modellieren und als .glb exportieren.

Aufruf (Hintergrund):
  blender -b -P tools/blender/make_tank.py -- <projektordner>
Ergebnis:
  models/units/tank.glb      (Spielmodell; wird automatisch geladen)
  models/source/tank.blend   (Blender-Datei zum Weiterbearbeiten)
  shots/tank_preview.png     (Vorschaubild)

Konventionen: Vorwaerts = Blender -Y (wird im Spiel zu +Z), Z oben, 1 Einheit = 1 m.
Objekt "Turret" dreht sich im Spiel, "Muzzle" markiert die Muendung,
Materialien mit "Team" im Namen werden in der Spielerfarbe eingefaerbt.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector

root_dir = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()

# ------------------------------------------------------------------ Szene leeren
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ------------------------------------------------------------------ Materialien
def material(name, color, metal=0.3, rough=0.5, emit=0.0):
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

M_TEAM = material("TeamPaint", (0.15, 0.3, 0.75), 0.45, 0.42)
M_HULL = material("HullOlive", (0.16, 0.17, 0.12), 0.35, 0.6)
M_DARK = material("DarkMetal", (0.04, 0.04, 0.045), 0.7, 0.5)
M_RUBBER = material("Rubber", (0.025, 0.025, 0.025), 0.0, 0.85)
M_STEEL = material("Steel", (0.42, 0.43, 0.45), 0.9, 0.3)
M_CANVAS = material("Canvas", (0.28, 0.25, 0.17), 0.0, 0.95)
M_GLASS = material("Optics", (0.1, 0.5, 0.9), 0.0, 0.1, 3.0)
M_LIGHT = material("Lights", (1.0, 0.85, 0.6), 0.0, 0.3, 6.0)

objects = []

def finish(ob, mat, parent=None, bevel=0.0, segs=2):
    ob.data.materials.append(mat)
    if bevel > 0:
        mod = ob.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = segs
        mod.limit_method = "ANGLE"
    if parent is not None:
        loc = ob.location.copy()
        ob.parent = parent
        ob.location = loc
    for p in ob.data.polygons:
        p.use_smooth = False
    objects.append(ob)
    return ob

def mesh_from(name, verts, faces):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    return ob

def box(name, size, loc, mat, parent=None, bevel=0.03, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    ob.location = loc
    ob.rotation_euler = rot
    return finish(ob, mat, parent, bevel)

def cyl(name, r, depth, loc, mat, parent=None, axis="Z", verts=16, bevel=0.0, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts, location=(0, 0, 0))
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, vertices=verts, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    if axis == "X":
        ob.rotation_euler = (0, math.radians(90), 0)
    elif axis == "Y":
        ob.rotation_euler = (math.radians(90), 0, 0)
    bpy.ops.object.transform_apply(rotation=True)
    ob.location = loc
    return finish(ob, mat, parent, bevel)

def prism_x(name, profile, half_w, mat, parent=None, bevel=0.04):
    """Seitenprofil (y, z) entlang X extrudieren."""
    n = len(profile)
    verts = [(-half_w, y, z) for (y, z) in profile] + [(half_w, y, z) for (y, z) in profile]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    ob = mesh_from(name, verts, faces)
    _fix_normals(ob)
    return finish(ob, mat, parent, bevel)

def loft_z(name, bottom, top, z0, z1, mat, parent=None, bevel=0.03):
    """Grundriss unten/oben (x, y) zu einem schraegen Koerper verbinden."""
    n = len(bottom)
    verts = [(x, y, z0) for (x, y) in bottom] + [(x, y, z1) for (x, y) in top]
    faces = [list(range(n))[::-1], list(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, j, n + j, n + i])
    ob = mesh_from(name, verts, faces)
    _fix_normals(ob)
    return finish(ob, mat, parent, bevel)

def superellipse(rx, y_front, y_back, n=24, p=2.6):
    """Abgerundeter Grundriss (x, y): vorn (y negativ) und hinten unterschiedlich lang, p steuert die Eckigkeit."""
    pts = []
    for i in range(n):
        a = 2.0 * math.pi * i / n
        c, s_ = math.cos(a), math.sin(a)
        x = rx * math.copysign(abs(c) ** (2.0 / p), c)
        ry = y_front if s_ < 0 else y_back
        y = ry * math.copysign(abs(s_) ** (2.0 / p), s_)
        pts.append((x, y))
    return pts

def loft_rings(name, rings, mat, parent=None, bevel=0.03, segs=2):
    """Mehrere Grundrisse (z, [(x, y)]) gleicher Punktzahl zu einem gewölbten Körper verbinden (Gussturm)."""
    n = len(rings[0][1])
    verts = []
    for z, pts in rings:
        verts += [(x, y, z) for (x, y) in pts]
    faces = [list(range(n))[::-1], list(range((len(rings) - 1) * n, len(rings) * n))]
    for r in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            faces.append([r * n + i, r * n + j, (r + 1) * n + j, (r + 1) * n + i])
    ob = mesh_from(name, verts, faces)
    _fix_normals(ob)
    return finish(ob, mat, parent, bevel, segs)

def _fix_normals(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # Sicherheitsprüfung: Normalen müssen im Mittel von der Körpermitte weg zeigen
    ctr = sum((v.co for v in bm.verts), Vector()) / max(1, len(bm.verts))
    score = sum((f.calc_center_median() - ctr).dot(f.normal) * f.calc_area() for f in bm.faces)
    if score < 0:
        for f in bm.faces:
            f.normal_flip()
    bm.to_mesh(ob.data)
    bm.free()

# ------------------------------------------------------------------ Wanne
# Seitenprofil: y nach hinten positiv, vorne = -y
hull = prism_x("Hull", [(2.25, 0.5), (2.36, 0.86), (2.3, 1.08), (2.12, 1.17), (-1.3, 1.21), (-1.62, 1.15), (-2.28, 0.86),
                        (-2.34, 0.72), (-2.05, 0.5)], 1.02, M_HULL, bevel=0.0)
_hb = hull.modifiers.new("Bevel", "BEVEL")
_hb.width = 0.11
_hb.segments = 3
_hb.limit_method = "ANGLE"
box("HullTop", (2.1, 3.5, 0.06), (0, 0.35, 1.19), M_TEAM, bevel=0.01)
box("Glacis", (2.0, 0.95, 0.05), (0, -1.88, 1.0), M_TEAM, bevel=0.01, rot=(math.radians(-25), 0, 0))
box("EngineDeck", (1.6, 1.0, 0.12), (0, 1.55, 1.22), M_DARK, bevel=0.02)
for i in range(5):
    box("Grille%d" % i, (1.5, 0.05, 0.04), (0, 1.15 + i * 0.2, 1.3), M_STEEL, bevel=0.0)
box("Exhaust", (1.4, 0.15, 0.25), (0, 2.32, 0.95), M_DARK, bevel=0.02)

# Ketten, Laufrollen, Kettenschuerzen
for sx in (-1, 1):
    x = sx * 1.22
    track = prism_x("Track%s" % ("L" if sx < 0 else "R"),
                    [(2.35, 0.75), (2.15, 0.95), (-2.15, 0.95), (-2.45, 0.7), (-2.15, 0.12), (2.0, 0.12)],
                    0.3, M_RUBBER, bevel=0.06)
    track.location.x = x
    for k in range(6):
        cyl("Wheel%s%d" % ("L" if sx < 0 else "R", k), 0.34, 0.12, (x + sx * 0.25, -1.55 + k * 0.62, 0.42), M_DARK, axis="X", verts=18, bevel=0.02)
        cyl("Hub%s%d" % ("L" if sx < 0 else "R", k), 0.12, 0.14, (x + sx * 0.3, -1.55 + k * 0.62, 0.42), M_STEEL, axis="X", verts=10)
    cyl("Sprocket%s" % sx, 0.3, 0.2, (x + sx * 0.2, -2.15, 0.7), M_STEEL, axis="X", verts=12)
    cyl("Idler%s" % sx, 0.28, 0.2, (x + sx * 0.2, 2.1, 0.68), M_DARK, axis="X", verts=12)
    box("Skirt%s" % sx, (0.07, 4.2, 0.42), (sx * 1.55, -0.05, 0.86), M_TEAM, bevel=0.03)
    box("Fender%s" % sx, (0.62, 4.7, 0.05), (x, -0.05, 1.12), M_HULL, bevel=0.01)
    for k in range(3):
        box("Box%s%d" % (sx, k), (0.35, 0.55, 0.28), (x, 0.2 + k * 0.62, 1.29), M_HULL, bevel=0.05)
    cyl("Headlight%s" % sx, 0.07, 0.08, (sx * 0.8, -2.3, 0.95), M_LIGHT, axis="Y", verts=10)

# ------------------------------------------------------------------ Turm (dreht sich)
turret = loft_rings("Turret", [
    (0.0, superellipse(1.06, 1.42, 1.34, 28, 2.4)),
    (0.34, superellipse(1.02, 1.36, 1.3, 28, 2.4)),
    (0.56, superellipse(0.9, 1.16, 1.18, 28, 2.2)),
    (0.66, superellipse(0.72, 0.9, 1.02, 28, 2.0)),
], M_TEAM, bevel=0.05, segs=3)
turret.location = (0, 0.15, 1.22)
cyl("Mantlet", 0.26, 0.62, (0, -1.42, 0.32), M_HULL, parent=turret, axis="X", verts=20, bevel=0.04)
barrel = cyl("Barrel", 0.085, 3.1, (0, -3.15, 0.32), M_STEEL, parent=turret, axis="Y", verts=14, r2=0.075)
evac = cyl("Evacuator", 0.13, 0.5, (0, -2.6, 0.32), M_DARK, parent=turret, axis="Y", verts=14)
brake = cyl("MuzzleBrake", 0.12, 0.32, (0, -4.62, 0.32), M_DARK, parent=turret, axis="Y", verts=12, bevel=0.01)
# Rücklaufendes Rohr: Evacuator und Mündungsbremse hängen am Rohr und bewegen sich mit
bpy.context.view_layer.update()   # Weltlagen aktualisieren, sonst rutschen die Teile beim Umhängen ins Rohr
for child in (evac, brake):
    mw = child.matrix_world.copy()
    child.parent = barrel
    child.matrix_world = mw
# Seelenbohrung: dunkler Lauf, der an der Mündungsbremse vorn offen endet (Rohre sind hohl)
M_BORE = material("Bore", (0.01, 0.01, 0.01), 0.2, 0.9)
bore = cyl("Bore", 0.062, 0.6, (0, -4.495, 0.32), M_BORE, parent=turret, axis="Y", verts=14)
bpy.context.view_layer.update()
mw = bore.matrix_world.copy()
bore.parent = barrel
bore.matrix_world = mw
barrel_group = [barrel, evac, brake, bore]
cyl("Cupola", 0.3, 0.22, (0.45, 0.25, 0.72), M_TEAM, parent=turret, verts=16, bevel=0.02)
cyl("Hatch", 0.24, 0.06, (0.45, 0.25, 0.86), M_HULL, parent=turret, verts=16)
box("Periscope", (0.18, 0.1, 0.1), (0.45, -0.02, 0.8), M_GLASS, parent=turret, bevel=0.0)
box("Sight", (0.3, 0.35, 0.25), (-0.55, -0.6, 0.72), M_HULL, parent=turret, bevel=0.03)
box("SightGlass", (0.24, 0.02, 0.14), (-0.55, -0.78, 0.74), M_GLASS, parent=turret, bevel=0.0)
cyl("MGMount", 0.06, 0.2, (0.45, 0.0, 0.92), M_DARK, parent=turret, verts=8)
cyl("MG", 0.03, 0.9, (0.45, -0.4, 1.0), M_DARK, parent=turret, axis="Y", verts=8)
cyl("Antenna", 0.012, 2.2, (-0.7, 1.0, 1.7), M_DARK, parent=turret, verts=6)
for sx in (-1, 1):
    for k in range(3):
        cyl("Smoke%s%d" % (sx, k), 0.06, 0.25, (sx * 0.98, -0.55 + k * 0.14, 0.45), M_DARK, parent=turret, axis="X", verts=8)
# Staukorb am Turmheck
box("BasketFloor", (1.5, 0.5, 0.04), (0, 1.55, 0.18), M_DARK, parent=turret, bevel=0.0)
for sx in (-0.73, 0.73):
    box("BasketSide%s" % sx, (0.03, 0.5, 0.35), (sx, 1.55, 0.35), M_DARK, parent=turret, bevel=0.0)
box("BasketBack", (1.5, 0.03, 0.35), (0, 1.8, 0.35), M_DARK, parent=turret, bevel=0.0)
box("Tarp", (0.9, 0.42, 0.25), (-0.25, 1.55, 0.32), M_CANVAS, parent=turret, bevel=0.06)
box("Jerrycan", (0.25, 0.15, 0.32), (0.45, 1.55, 0.36), M_HULL, parent=turret, bevel=0.02)

muzzle = bpy.data.objects.new("Muzzle", None)
scene.collection.objects.link(muzzle)
muzzle.parent = turret
muzzle.location = (0, -4.8, 0.32)
objects.append(muzzle)

# ------------------------------------------------------------------ Zusammenfuehren
os.makedirs(os.path.join(root_dir, "models", "units"), exist_ok=True)
os.makedirs(os.path.join(root_dir, "models", "source"), exist_ok=True)
os.makedirs(os.path.join(root_dir, "shots"), exist_ok=True)
view = bpy.context.view_layer

def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    view.objects.active = ob

def join_into(target, parts):
    for ob in parts + [target]:
        activate(ob)
        for m in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    target.select_set(True)
    view.objects.active = target
    if parts:
        bpy.ops.object.join()
    # Glatt schattieren, harte Kanten ab 35 Grad
    bm = bmesh.new()
    bm.from_mesh(target.data)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if not e.is_manifold or e.calc_face_angle(0.0) > math.radians(35):
            e.smooth = False
    bm.to_mesh(target.data)
    bm.free()
    activate(target)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")

meshes = [o for o in objects if o.type == "MESH"]
turret_parts = [o for o in meshes if o.parent == turret and o != turret and o not in barrel_group]
hull_parts = [o for o in meshes if o not in turret_parts and o not in (turret, hull) and o not in barrel_group]
join_into(turret, turret_parts)
join_into(hull, hull_parts)

# ------------------------------------------------------------------ Oberflaechen-Shader
# Verschleiss je Material: (Grundfarbe, Metall, Rauheit, Abrieb, Schmutz)
LOOK = {
    "TeamPaint": ((0.66, 0.67, 0.64), 0.35, 0.48, 1.0, 1.0),
    "HullOlive": ((0.2, 0.21, 0.15), 0.3, 0.6, 0.8, 1.0),
    "DarkMetal": ((0.06, 0.06, 0.065), 0.75, 0.5, 0.6, 0.8),
    "Rubber":    ((0.035, 0.034, 0.032), 0.0, 0.88, 0.0, 1.4),
    "Steel":     ((0.45, 0.46, 0.47), 0.9, 0.32, 0.3, 0.4),
    "Canvas":    ((0.3, 0.27, 0.18), 0.0, 0.95, 0.0, 0.7),
    "Optics":    ((0.1, 0.5, 0.9), 0.0, 0.1, 0.0, 0.0),
    "Lights":    ((1.0, 0.85, 0.6), 0.0, 0.3, 0.0, 0.0),
}

def surface_tree(mat, look, img_col, img_rough, img_nrm, emit_value):
    """Baut einen Cycles-Shader mit Lackvariation, Kantenabrieb, Kratzern, Schmutz und Feinstruktur."""
    col, metal, rough, wear, dirt = look
    nt = mat.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    L = nt.links.new
    out = N("ShaderNodeOutputMaterial")
    tc = N("ShaderNodeTexCoord")
    # Lackvariation (gross) und Koernung (fein)
    big = N("ShaderNodeTexNoise"); big.inputs["Scale"].default_value = 2.5; big.inputs["Detail"].default_value = 6
    fine = N("ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 90; fine.inputs["Detail"].default_value = 4
    L(tc.outputs["Object"], big.inputs["Vector"]); L(tc.outputs["Object"], fine.inputs["Vector"])
    # Kanten: Bevel-Normale gegen Flaechennormale
    bev = N("ShaderNodeBevel"); bev.inputs["Radius"].default_value = 0.03; bev.samples = 8
    geo = N("ShaderNodeNewGeometry")
    dot = N("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    L(bev.outputs["Normal"], dot.inputs[0]); L(geo.outputs["Normal"], dot.inputs[1])
    edge = N("ShaderNodeMapRange"); edge.inputs["From Min"].default_value = 0.999; edge.inputs["From Max"].default_value = 0.94
    L(dot.outputs["Value"], edge.inputs["Value"])
    brk = N("ShaderNodeTexNoise"); brk.inputs["Scale"].default_value = 18; brk.inputs["Detail"].default_value = 8
    L(tc.outputs["Object"], brk.inputs["Vector"])
    brk_r = N("ShaderNodeMapRange"); brk_r.inputs["From Min"].default_value = 0.42; brk_r.inputs["From Max"].default_value = 0.62
    L(brk.outputs["Fac"], brk_r.inputs["Value"])
    wear_m = N("ShaderNodeMath"); wear_m.operation = "MULTIPLY"
    L(edge.outputs["Result"], wear_m.inputs[0]); L(brk_r.outputs["Result"], wear_m.inputs[1])
    wear_s = N("ShaderNodeMath"); wear_s.operation = "MULTIPLY"; wear_s.use_clamp = True; wear_s.inputs[1].default_value = wear * 1.6
    L(wear_m.outputs["Value"], wear_s.inputs[0])
    # Kratzer: gestreckte Rauschbahnen
    mp = N("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (2.0, 60.0, 2.0); mp.inputs["Rotation"].default_value = (0.3, 0.2, 0.7)
    L(tc.outputs["Object"], mp.inputs["Vector"])
    scr = N("ShaderNodeTexNoise"); scr.inputs["Scale"].default_value = 3.0; scr.inputs["Detail"].default_value = 2
    L(mp.outputs["Vector"], scr.inputs["Vector"])
    scr_r = N("ShaderNodeMapRange"); scr_r.inputs["From Min"].default_value = 0.66; scr_r.inputs["From Max"].default_value = 0.72
    L(scr.outputs["Fac"], scr_r.inputs["Value"])
    scr_s = N("ShaderNodeMath"); scr_s.operation = "MULTIPLY"; scr_s.inputs[1].default_value = wear * 0.7
    L(scr_r.outputs["Result"], scr_s.inputs[0])
    # Schmutz: unten an der Wanne, in Spalten (AO) und fleckig
    sep = N("ShaderNodeSeparateXYZ"); L(tc.outputs["Object"], sep.inputs["Vector"])
    low = N("ShaderNodeMapRange"); low.inputs["From Min"].default_value = 1.0; low.inputs["From Max"].default_value = 0.15
    L(sep.outputs["Z"], low.inputs["Value"])
    ao = N("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.35; ao.samples = 8
    aoi = N("ShaderNodeMath"); aoi.operation = "SUBTRACT"; aoi.inputs[0].default_value = 1.0
    L(ao.outputs["AO"], aoi.inputs[1])
    dsum = N("ShaderNodeMath"); dsum.operation = "ADD"
    L(low.outputs["Result"], dsum.inputs[0]); L(aoi.outputs["Value"], dsum.inputs[1])
    dn = N("ShaderNodeMath"); dn.operation = "MULTIPLY"
    L(dsum.outputs["Value"], dn.inputs[0]); L(big.outputs["Fac"], dn.inputs[1])
    dirt_m = N("ShaderNodeMath"); dirt_m.operation = "MULTIPLY"; dirt_m.use_clamp = True; dirt_m.inputs[1].default_value = dirt * 1.1
    L(dn.outputs["Value"], dirt_m.inputs[0])
    # Farbe
    var = N("ShaderNodeMapRange"); var.inputs["To Min"].default_value = 0.82; var.inputs["To Max"].default_value = 1.12
    L(big.outputs["Fac"], var.inputs["Value"])
    base = N("ShaderNodeMix"); base.data_type = "RGBA"; base.blend_type = "MULTIPLY"
    base.inputs["Factor"].default_value = 1.0
    base.inputs["A"].default_value = (*col, 1)
    L(var.outputs["Result"], base.inputs["B"])
    grain = N("ShaderNodeMix"); grain.data_type = "RGBA"; grain.blend_type = "OVERLAY"; grain.inputs["Factor"].default_value = 0.12
    L(base.outputs["Result"], grain.inputs["A"]); L(fine.outputs["Color"], grain.inputs["B"])
    worn = N("ShaderNodeMix"); worn.data_type = "RGBA"
    worn.inputs["B"].default_value = (0.42, 0.41, 0.39, 1)
    L(wear_s.outputs["Value"], worn.inputs["Factor"]); L(grain.outputs["Result"], worn.inputs["A"])
    scratched = N("ShaderNodeMix"); scratched.data_type = "RGBA"
    scratched.inputs["B"].default_value = (0.5, 0.49, 0.47, 1)
    L(scr_s.outputs["Value"], scratched.inputs["Factor"]); L(worn.outputs["Result"], scratched.inputs["A"])
    dirty = N("ShaderNodeMix"); dirty.data_type = "RGBA"
    dirty.inputs["B"].default_value = (0.13, 0.1, 0.065, 1)
    L(dirt_m.outputs["Value"], dirty.inputs["Factor"]); L(scratched.outputs["Result"], dirty.inputs["A"])
    # Rauheit
    r1 = N("ShaderNodeMapRange"); r1.inputs["To Min"].default_value = rough - 0.08; r1.inputs["To Max"].default_value = rough + 0.08
    L(fine.outputs["Fac"], r1.inputs["Value"])
    r2 = N("ShaderNodeMix"); r2.inputs["B"].default_value = 0.3
    L(wear_s.outputs["Value"], r2.inputs["Factor"]); L(r1.outputs["Result"], r2.inputs["A"])
    r3 = N("ShaderNodeMix"); r3.inputs["B"].default_value = 0.95
    L(dirt_m.outputs["Value"], r3.inputs["Factor"]); L(r2.outputs["Result"], r3.inputs["A"])
    # Feinstruktur (Gussoberflaeche, Kratzer als Rillen)
    bsum = N("ShaderNodeMath"); bsum.operation = "SUBTRACT"
    L(fine.outputs["Fac"], bsum.inputs[0]); L(scr_s.outputs["Value"], bsum.inputs[1])
    bump = N("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.25; bump.inputs["Distance"].default_value = 0.003
    L(bsum.outputs["Value"], bump.inputs["Height"])
    bsdf = N("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Metallic"].default_value = metal
    L(dirty.outputs["Result"], bsdf.inputs["Base Color"])
    L(r3.outputs["Result"], bsdf.inputs["Roughness"])
    L(bump.outputs["Normal"], bsdf.inputs["Normal"])
    emi = N("ShaderNodeEmission")
    nodes = {"bsdf": bsdf, "emit": emi, "out": out, "color": dirty.outputs["Result"], "rough": r3.outputs["Result"]}
    for img in (img_col, img_rough, img_nrm):
        n = N("ShaderNodeTexImage"); n.image = img; n.name = "IMG_" + img.name
    return nodes

def new_img(name, size, non_color):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
scene.render.bake.margin = 6

def bake_object(ob, size):
    # Materialien pro Objekt eigenstaendig machen
    for slot in ob.material_slots:
        if slot.material:
            slot.material = slot.material.copy()
            slot.material.name = slot.material.name.split(".")[0] + "_" + ob.name
    imgs = {k: new_img("%s_%s" % (ob.name, k), size, k != "color") for k in ("color", "rough", "normal")}
    trees = []
    for slot in ob.material_slots:
        m = slot.material
        key = m.name.rsplit("_", 1)[0]
        trees.append((m, surface_tree(m, LOOK.get(key, LOOK["HullOlive"]), imgs["color"], imgs["rough"], imgs["normal"], 0)))
    activate(ob)

    def set_target(k):
        for m, nd in trees:
            node = m.node_tree.nodes["IMG_" + imgs[k].name]
            for n in m.node_tree.nodes:
                n.select = False
            node.select = True
            m.node_tree.nodes.active = node

    def route(kind):
        for m, nd in trees:
            nt = m.node_tree
            for l in list(nd["out"].inputs["Surface"].links):
                nt.links.remove(l)
            if kind == "bsdf":
                nt.links.new(nd["bsdf"].outputs["BSDF"], nd["out"].inputs["Surface"])
            else:
                nt.links.new(nd[kind], nd["emit"].inputs["Color"])
                nt.links.new(nd["emit"].outputs["Emission"], nd["out"].inputs["Surface"])

    route("color"); set_target("color"); bpy.ops.object.bake(type="EMIT")
    route("rough"); set_target("rough"); bpy.ops.object.bake(type="EMIT")
    route("bsdf"); set_target("normal"); bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    tex_dir = os.path.join(root_dir, "models", "source", "textures")
    os.makedirs(tex_dir, exist_ok=True)
    for k, img in imgs.items():
        img.filepath_raw = os.path.join(tex_dir, img.name + ".png")
        img.file_format = "PNG"
        img.save()
    # Endmaterial: nur Bildtexturen (glTF-tauglich)
    for m, nd in trees:
        key = m.name.rsplit("_", 1)[0]
        look = LOOK.get(key, LOOK["HullOlive"])
        nt = m.node_tree
        nt.nodes.clear()
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        b = nt.nodes.new("ShaderNodeBsdfPrincipled")
        b.inputs["Metallic"].default_value = look[1]
        tc = nt.nodes.new("ShaderNodeTexImage"); tc.image = imgs["color"]
        tr = nt.nodes.new("ShaderNodeTexImage"); tr.image = imgs["rough"]
        tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = imgs["normal"]
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(tc.outputs["Color"], b.inputs["Base Color"])
        nt.links.new(tr.outputs["Color"], b.inputs["Roughness"])
        nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], b.inputs["Normal"])
        if key in ("Lights", "Optics"):
            b.inputs["Emission Color"].default_value = (*look[0], 1)
            b.inputs["Emission Strength"].default_value = 4.0
        nt.links.new(b.outputs["BSDF"], out.inputs["Surface"])

bake_object(hull, 2048)
bake_object(turret, 1024)

bpy.ops.object.select_all(action="DESELECT")
for ob in (hull, turret, muzzle, barrel, evac, brake, bore):
    ob.select_set(True)
glb = os.path.join(root_dir, "models", "units", "tank.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)

# Vorschau: Kamera, Licht, Boden
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
ground = bpy.context.active_object
ground.data.materials.append(material("Ground", (0.22, 0.24, 0.16), 0.0, 0.95))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 4.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(35))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 50
scene.collection.objects.link(cam)
cam.location = (-7.5, -8.5, 5.2)
direction = Vector((0, -0.4, 0.9)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.55, 0.7, 1.0)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
scene.world = world
for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = eng
        break
    except Exception:
        pass
scene.render.resolution_x = 1280
scene.render.resolution_y = 720
scene.render.filepath = os.path.join(root_dir, "shots", "tank_preview.png")
bpy.ops.render.render(write_still=True)

bpy.ops.wm.save_as_mainfile(filepath=os.path.join(root_dir, "models", "source", "tank.blend"))
print("TANK_OK", glb, len(objects), "Objekte")
