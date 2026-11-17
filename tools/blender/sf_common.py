"""Gemeinsame Bausteine für Stahlfront-Modelle in Blender.

Grundkörper mit Fasen, Booleans, Arrays, Zusammenführen mit UV-Abwicklung und
prozedurale Verschleiß-Texturen, die in Bildtexturen gebacken werden (glTF-tauglich).
Konvention: vorne = -Y, Z oben, 1 Einheit = 1 m.
"""
import bpy, bmesh, math, os
from mathutils import Vector

scene = None
objects = []

def reset():
    global scene, objects
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    objects = []

def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

# ------------------------------------------------------------------ Materialien

LOOK = {}   # name -> (farbe, metall, rauheit, abrieb, schmutz, emission)

def material(name, color, metal=0.3, rough=0.5, wear=0.5, dirt=0.5, emit=0.0):
    if name in bpy.data.materials:
        return bpy.data.materials[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    LOOK[name] = (color, metal, rough, wear, dirt, emit)
    return m

# ------------------------------------------------------------------ Grundkörper

def _finish(ob, mat, bevel=0.0, segs=2, smooth=False):
    if mat is not None:
        ob.data.materials.append(mat)
    if bevel > 0:
        m = ob.modifiers.new("Bevel", "BEVEL")
        m.width = bevel
        m.segments = segs
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(40)
    for p in ob.data.polygons:
        p.use_smooth = smooth
    objects.append(ob)
    return ob

def box(name, size, loc, mat, bevel=0.02, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    ob.location = loc
    ob.rotation_euler = rot
    return _finish(ob, mat, bevel)

def cyl(name, r, depth, loc, mat, verts=24, bevel=0.0, r2=None, rot=(0, 0, 0), smooth=True):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts, location=(0, 0, 0))
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, vertices=verts, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    ob.location = loc
    ob.rotation_euler = rot
    return _finish(ob, mat, bevel, smooth=smooth)

def sphere(name, r, loc, mat, scale=(1, 1, 1), segs=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=segs, ring_count=rings, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    ob.location = loc
    return _finish(ob, mat, 0.0, smooth=True)

def prism_xz(name, profile, depth, loc, mat, bevel=0.02, rot=(0, 0, 0)):
    """Profil (x, z) entlang Y extrudieren."""
    n = len(profile)
    verts = [(x, -depth / 2, z) for x, z in profile] + [(x, depth / 2, z) for x, z in profile]
    faces = [list(range(n)), list(range(n, 2 * n))[::-1]]
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, n + i, n + j, j])
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob.location = loc
    ob.rotation_euler = rot
    return _finish(ob, mat, bevel)

def ngon_prism(name, sides, r, h, loc, mat, bevel=0.03, rot_z=None):
    """Gerades n-Eck-Prisma mit flachen Seiten (Achteck-Turm usw.)."""
    rz = math.pi / sides if rot_z is None else rot_z
    ob = cyl(name, r, h, loc, mat, verts=sides, bevel=bevel, smooth=False)
    ob.rotation_euler = (0, 0, rz)
    return ob

def cut(target, cutter, keep=False):
    """Boolesche Differenz; Schneidkörper wird entfernt."""
    m = target.modifiers.new("Cut", "BOOLEAN")
    m.operation = "DIFFERENCE"
    m.object = cutter
    m.solver = "EXACT"
    activate(target)
    bpy.ops.object.modifier_apply(modifier="Cut")
    if not keep:
        if cutter in objects:
            objects.remove(cutter)
        bpy.data.objects.remove(cutter, do_unlink=True)

def array(ob, count, offset):
    m = ob.modifiers.new("Arr", "ARRAY")
    m.count = count
    m.use_relative_offset = False
    m.use_constant_offset = True
    m.constant_offset_displace = offset
    return ob

def parent(child, par):
    mw = child.matrix_world.copy()
    child.parent = par
    child.matrix_world = mw

def empty(name, loc, par=None):
    e = bpy.data.objects.new(name, None)
    scene.collection.objects.link(e)
    e.location = loc
    if par is not None:
        parent(e, par)
    objects.append(e)
    return e

# ------------------------------------------------------------------ Zusammenführen, UV

def join_into(target, parts, smooth_angle=35):
    for ob in parts + [target]:
        activate(ob)
        for m in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
        if ob in objects:
            objects.remove(ob)
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    if parts:
        bpy.ops.object.join()
    bm = bmesh.new()
    bm.from_mesh(target.data)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        if not e.is_manifold or e.calc_face_angle(0.0) > math.radians(smooth_angle):
            e.smooth = False
    bm.to_mesh(target.data)
    bm.free()
    activate(target)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")

# ------------------------------------------------------------------ Verschleiß-Shader und Backen

def _surface(mat, look, imgs):
    col, metal, rough, wear, dirt, emit = look
    nt = mat.node_tree
    nt.nodes.clear()
    N = nt.nodes.new
    L = nt.links.new
    out = N("ShaderNodeOutputMaterial")
    tc = N("ShaderNodeTexCoord")
    big = N("ShaderNodeTexNoise"); big.inputs["Scale"].default_value = 1.8; big.inputs["Detail"].default_value = 6
    fine = N("ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 70; fine.inputs["Detail"].default_value = 4
    L(tc.outputs["Object"], big.inputs["Vector"]); L(tc.outputs["Object"], fine.inputs["Vector"])
    bev = N("ShaderNodeBevel"); bev.inputs["Radius"].default_value = 0.025; bev.samples = 8
    geo = N("ShaderNodeNewGeometry")
    dot = N("ShaderNodeVectorMath"); dot.operation = "DOT_PRODUCT"
    L(bev.outputs["Normal"], dot.inputs[0]); L(geo.outputs["Normal"], dot.inputs[1])
    edge = N("ShaderNodeMapRange"); edge.inputs["From Min"].default_value = 0.999; edge.inputs["From Max"].default_value = 0.95
    L(dot.outputs["Value"], edge.inputs["Value"])
    brk = N("ShaderNodeTexNoise"); brk.inputs["Scale"].default_value = 14; brk.inputs["Detail"].default_value = 8
    L(tc.outputs["Object"], brk.inputs["Vector"])
    brk_r = N("ShaderNodeMapRange"); brk_r.inputs["From Min"].default_value = 0.45; brk_r.inputs["From Max"].default_value = 0.62
    L(brk.outputs["Fac"], brk_r.inputs["Value"])
    wm = N("ShaderNodeMath"); wm.operation = "MULTIPLY"; L(edge.outputs["Result"], wm.inputs[0]); L(brk_r.outputs["Result"], wm.inputs[1])
    ws = N("ShaderNodeMath"); ws.operation = "MULTIPLY"; ws.use_clamp = True; ws.inputs[1].default_value = wear * 1.5
    L(wm.outputs["Value"], ws.inputs[0])
    # Schmutz: Laufspuren nach unten und AO
    mp = N("ShaderNodeMapping"); mp.inputs["Scale"].default_value = (6.0, 6.0, 0.6)
    L(tc.outputs["Object"], mp.inputs["Vector"])
    streak = N("ShaderNodeTexNoise"); streak.inputs["Scale"].default_value = 4.0; streak.inputs["Detail"].default_value = 3
    L(mp.outputs["Vector"], streak.inputs["Vector"])
    sr = N("ShaderNodeMapRange"); sr.inputs["From Min"].default_value = 0.52; sr.inputs["From Max"].default_value = 0.7
    L(streak.outputs["Fac"], sr.inputs["Value"])
    ao = N("ShaderNodeAmbientOcclusion"); ao.inputs["Distance"].default_value = 0.4; ao.samples = 8
    aoi = N("ShaderNodeMath"); aoi.operation = "SUBTRACT"; aoi.inputs[0].default_value = 1.0; L(ao.outputs["AO"], aoi.inputs[1])
    ds = N("ShaderNodeMath"); ds.operation = "ADD"; L(sr.outputs["Result"], ds.inputs[0]); L(aoi.outputs["Value"], ds.inputs[1])
    dm = N("ShaderNodeMath"); dm.operation = "MULTIPLY"; dm.use_clamp = True; dm.inputs[1].default_value = dirt * 0.8
    L(ds.outputs["Value"], dm.inputs[0])
    var = N("ShaderNodeMapRange"); var.inputs["To Min"].default_value = 0.88; var.inputs["To Max"].default_value = 1.08
    L(big.outputs["Fac"], var.inputs["Value"])
    base = N("ShaderNodeMix"); base.data_type = "RGBA"; base.blend_type = "MULTIPLY"; base.inputs["Factor"].default_value = 1.0
    base.inputs["A"].default_value = (*col, 1); L(var.outputs["Result"], base.inputs["B"])
    grain = N("ShaderNodeMix"); grain.data_type = "RGBA"; grain.blend_type = "OVERLAY"; grain.inputs["Factor"].default_value = 0.1
    L(base.outputs["Result"], grain.inputs["A"]); L(fine.outputs["Color"], grain.inputs["B"])
    worn = N("ShaderNodeMix"); worn.data_type = "RGBA"; worn.inputs["B"].default_value = (0.5, 0.5, 0.5, 1)
    L(ws.outputs["Value"], worn.inputs["Factor"]); L(grain.outputs["Result"], worn.inputs["A"])
    dirty = N("ShaderNodeMix"); dirty.data_type = "RGBA"; dirty.inputs["B"].default_value = (0.17, 0.15, 0.12, 1)
    L(dm.outputs["Value"], dirty.inputs["Factor"]); L(worn.outputs["Result"], dirty.inputs["A"])
    r1 = N("ShaderNodeMapRange"); r1.inputs["To Min"].default_value = rough - 0.07; r1.inputs["To Max"].default_value = rough + 0.07
    L(fine.outputs["Fac"], r1.inputs["Value"])
    r2 = N("ShaderNodeMix"); r2.inputs["B"].default_value = 0.92; L(dm.outputs["Value"], r2.inputs["Factor"]); L(r1.outputs["Result"], r2.inputs["A"])
    bump = N("ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.2; bump.inputs["Distance"].default_value = 0.003
    L(fine.outputs["Fac"], bump.inputs["Height"])
    bsdf = N("ShaderNodeBsdfPrincipled"); bsdf.inputs["Metallic"].default_value = metal
    L(dirty.outputs["Result"], bsdf.inputs["Base Color"]); L(r2.outputs["Result"], bsdf.inputs["Roughness"]); L(bump.outputs["Normal"], bsdf.inputs["Normal"])
    emi = N("ShaderNodeEmission")
    for img in imgs.values():
        n = N("ShaderNodeTexImage"); n.image = img; n.name = "IMG_" + img.name
    if emit > 0:
        # Leuchtflächen: Farbe direkt, kein Schmutz
        return {"bsdf": bsdf, "emit": emi, "out": out, "color": base.outputs["Result"], "rough": r1.outputs["Result"]}
    return {"bsdf": bsdf, "emit": emi, "out": out, "color": dirty.outputs["Result"], "rough": r2.outputs["Result"]}

def bake(ob, size, tex_dir, samples=12):
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.render.bake.margin = 6
    for slot in ob.material_slots:
        if slot.material:
            base = slot.material.name.split(".")[0]
            slot.material = slot.material.copy()
            slot.material.name = base + "_" + ob.name
    imgs = {}
    for k in ("color", "rough", "normal"):
        img = bpy.data.images.new("%s_%s" % (ob.name, k), size, size, alpha=False)
        if k != "color":
            img.colorspace_settings.name = "Non-Color"
        imgs[k] = img
    trees = []
    for slot in ob.material_slots:
        m = slot.material
        if m is None:
            continue
        key = m.name.rsplit("_", 1)[0]
        trees.append((m, key, _surface(m, LOOK.get(key, ((0.5, 0.5, 0.5), 0.2, 0.6, 0.5, 0.5, 0.0)), imgs)))
    activate(ob)

    def target(k):
        for m, key, nd in trees:
            node = m.node_tree.nodes["IMG_" + imgs[k].name]
            for n in m.node_tree.nodes:
                n.select = False
            node.select = True
            m.node_tree.nodes.active = node

    def route(kind):
        for m, key, nd in trees:
            nt = m.node_tree
            for l in list(nd["out"].inputs["Surface"].links):
                nt.links.remove(l)
            if kind == "bsdf":
                nt.links.new(nd["bsdf"].outputs["BSDF"], nd["out"].inputs["Surface"])
            else:
                nt.links.new(nd[kind], nd["emit"].inputs["Color"])
                nt.links.new(nd["emit"].outputs["Emission"], nd["out"].inputs["Surface"])

    route("color"); target("color"); bpy.ops.object.bake(type="EMIT")
    route("rough"); target("rough"); bpy.ops.object.bake(type="EMIT")
    route("bsdf"); target("normal"); bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    os.makedirs(tex_dir, exist_ok=True)
    for k, img in imgs.items():
        img.filepath_raw = os.path.join(tex_dir, img.name + ".png")
        img.file_format = "PNG"
        img.save()
    for m, key, nd in trees:
        look = LOOK.get(key, ((0.5, 0.5, 0.5), 0.2, 0.6, 0.5, 0.5, 0.0))
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
        if look[5] > 0:
            b.inputs["Emission Color"].default_value = (*look[0], 1)
            b.inputs["Emission Strength"].default_value = look[5]
        nt.links.new(b.outputs["BSDF"], out.inputs["Surface"])

def export(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)

def preview(path, target=(0, 0, 2), cam_loc=(-14, -16, 11), lens=45, ground=(0.3, 0.32, 0.25)):
    bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
    g = bpy.context.active_object
    g.data.materials.append(material("PreviewGround", ground, 0, 0.95))
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = lens
    scene.collection.objects.link(cam)
    cam.location = cam_loc
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.6, 0.72, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scene.world = w
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 1000
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
