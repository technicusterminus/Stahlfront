"""Exportiert aus west_falke.blend das kompakte Laufzeitmodell für Godot.

blender -b models/source/west_falke.blend -P tools/blender/export_falke_game.py -- models/units/west_tank.glb
"""
import sys
from collections import defaultdict

import bpy
from mathutils import Matrix


out = sys.argv[sys.argv.index('--') + 1]
scene = bpy.context.scene
scene.frame_set(1)
view = bpy.context.view_layer
depsgraph = bpy.context.evaluated_depsgraph_get()

def holder(name, parent=None, source=None):
    ob = bpy.data.objects.new(name, None)
    scene.collection.objects.link(ob)
    ob.parent = parent
    if source is not None:
        ob.matrix_world = source.matrix_world.copy()
    view.update()
    return ob


def combine(name, sources, parent, origin=None):
    groups = defaultdict(lambda: [[], []])
    frame = parent.matrix_world if origin is None else Matrix.Translation(origin)
    inverse = frame.inverted()
    for ob in sources:
        mesh = ob.evaluated_get(depsgraph).to_mesh()
        tf = inverse @ ob.matrix_world
        for poly in mesh.polygons:
            material = ob.data.materials[poly.material_index]
            verts, faces = groups[material]
            start = len(verts)
            verts.extend(tuple(tf @ mesh.vertices[index].co) for index in poly.vertices)
            faces.append(tuple(range(start, len(verts))))
        ob.evaluated_get(depsgraph).to_mesh_clear()
    vertices, polygons, material_ids = [], [], []
    mesh = bpy.data.meshes.new(name)
    for index, (material, (verts, faces)) in enumerate(groups.items()):
        base = len(vertices)
        vertices.extend(verts)
        polygons.extend(tuple(base + i for i in face) for face in faces)
        material_ids.extend([index] * len(faces))
        mesh.materials.append(material)
    mesh.from_pydata(vertices, [], polygons)
    mesh.update()
    for poly, index in zip(mesh.polygons, material_ids):
        poly.material_index = index
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    ob.parent = parent
    return ob


tank = bpy.data.objects['Falke redesign']
old_chassis = bpy.data.objects['Suspended chassis']
old_hull = bpy.data.objects['Hull geometry']
old_turret = bpy.data.objects['Turret']
old_barrel = bpy.data.objects['Barrel']
old_muzzle = bpy.data.objects['Muzzle']
for ob, name in ((old_turret, 'source Turret'), (old_barrel, 'source Barrel'), (old_muzzle, 'source Muzzle')):
    ob.name = name

for ob in list(old_turret.children):
    if ob.type == 'FONT':
        bpy.ops.object.select_all(action='DESELECT')
        ob.select_set(True)
        view.objects.active = ob
        bpy.ops.object.convert(target='MESH')

root = holder('Falke')
chassis = holder('Chassis', root, old_chassis)
turret = holder('Turret', chassis, old_turret)
barrel = holder('Barrel', turret, old_barrel)
muzzle = holder('Muzzle', barrel, old_muzzle)
assets = [root, chassis, turret, barrel, muzzle]
assets.append(combine('FalkeHull', [o for o in old_hull.children if o.type == 'MESH'], chassis))
assets.append(combine('FalkeTurret', [o for o in old_turret.children if o.type == 'MESH'], turret))
assets.append(combine('FalkeBarrel', [o for o in old_barrel.children if o.type == 'MESH'], barrel))

track = next(o for o in tank.children if o.name.startswith('Track link'))
track.rotation_euler.x = 0
view.update()
assets.append(combine('TrackPrototype', list(track.children), root, track.matrix_world.translation))
for prefix, template in [('Road wheel', 'RoadWheelPrototype'), ('Track guide wheel', 'GuideWheelPrototype')]:
    wheel = next(o for o in tank.children if o.name.startswith(prefix) and o.location.x > 0)
    assets.append(combine(template, list(wheel.children), root, wheel.matrix_world.translation))

palette = {
    'Westbund / satin blue identification': ('TeamMarking', (0.065, 0.18, 0.33)),
    'Westbund / graphite ceramic paint': ('FalkeArmorDark', (0.061, 0.086, 0.087)),
    'Westbund / upper slate paint': ('FalkeArmorLight', (0.091, 0.123, 0.136)),
    'Blackened machined alloy': ('FalkeAlloy', (0.034, 0.045, 0.047)),
    'Exposed steel': ('FalkeSteel', (0.169, 0.182, 0.187)),
    'Rubber and track pads': ('FalkeRubber', (0.028, 0.029, 0.028)),
    'Canvas stowage': ('FalkeCanvas', (0.166, 0.151, 0.097)),
}
for original, (name, color) in palette.items():
    mat = bpy.data.materials.get(original)
    mat.name = name
    shader = mat.node_tree.nodes.get('Principled BSDF')
    for socket in ('Base Color', 'Roughness', 'Normal'):
        for link in list(shader.inputs[socket].links):
            mat.node_tree.links.remove(link)
    shader.inputs['Base Color'].default_value = (*color, 1)

bpy.ops.object.select_all(action='DESELECT')
for ob in assets:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=out, export_format='GLB', use_selection=True, export_animations=False)
