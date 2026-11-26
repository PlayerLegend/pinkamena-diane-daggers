"""
Bake a mesh's vertex animation into a float EXR (X = vertex, Y = frame, frame 0 on the top row),
plus a matching normals EXR (<name>_n.exr), and export the rest mesh as a GLB of the same name
with the lookup coordinate in UV2.

Works with Geometry Nodes: the baked data and the rest mesh both come from the evaluated
(GN output) mesh, so vertex count and order always match. The vertex count and order must be
constant across all frames.

Usage:
  blender -b scene.blend --python export_vat.py -- out/walk.exr --object Body --action Walk
"""
import bpy
import os
import sys
import math
import argparse
import numpy as np

parser = argparse.ArgumentParser()

parser.add_argument('filename')
parser.add_argument('-o', '--object', default=None, help='Mesh object name (default: first mesh object)')
parser.add_argument('-a', '--action', default=None, help='Action name (default: the object\'s current action)')

argv = sys.argv[sys.argv.index("--") + 1:]
args = parser.parse_args(argv)
output_filepath = os.path.splitext(os.path.abspath(args.filename))[0] + ".exr"

if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

scene = bpy.context.scene

# Object
if args.object is not None:
    obj = scene.objects.get(args.object)
    if obj is None:
        sys.exit(f"VAT: object '{args.object}' not found")
    if obj.type != 'MESH':
        sys.exit(f"VAT: object '{args.object}' is not a mesh")
else:
    obj = next((o for o in scene.objects if o.type == 'MESH'), None)
    if obj is None:
        sys.exit("VAT: no mesh objects in the scene")

# Action: it drives the mesh through its armature if there is one, otherwise through the object itself
target = obj
for mod in obj.modifiers:
    if mod.type == 'ARMATURE' and mod.object is not None:
        target = mod.object
        break

if args.action is not None:
    action = bpy.data.actions.get(args.action)
    if action is None:
        sys.exit(f"VAT: action '{args.action}' not found")
    if target.animation_data is None:
        target.animation_data_create()
    target.animation_data.action = action
else:
    action = target.animation_data.action if target.animation_data else None
    if action is None:
        sys.exit(f"VAT: '{target.name}' has no action; pass --action")

f0 = int(math.floor(action.frame_range[0]))
f1 = int(math.ceil(action.frame_range[1]))
frames = f1 - f0 + 1

# Vertex count of the evaluated mesh (Geometry Nodes output included) at the first frame
scene.frame_set(f0)
dg = bpy.context.evaluated_depsgraph_get()
ev = obj.evaluated_get(dg)
m = ev.to_mesh()
n = len(m.vertices)
ev.to_mesh_clear()
if n == 0:
    sys.exit(f"VAT: '{obj.name}' evaluates to an empty mesh (if you use Geometry Nodes, add Realize Instances)")

pix = np.ones((frames, n, 4), dtype=np.float32)
nor = np.ones((frames, n, 4), dtype=np.float32)
for i, f in enumerate(range(f0, f1 + 1)):
    scene.frame_set(f)
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    m = ev.to_mesh()
    count = len(m.vertices)  # read before to_mesh_clear(), which invalidates m
    if count != n:
        ev.to_mesh_clear()
        sys.exit(f"VAT: '{obj.name}' has {count} vertices at frame {f}, expected {n}")
    co = np.empty(n * 3, dtype=np.float32)
    m.vertices.foreach_get("co", co)
    co = co.reshape(n, 3)
    # Blender Z-up -> Godot Y-up
    pix[i, :, 0] = co[:, 0]
    pix[i, :, 1] = co[:, 2]
    pix[i, :, 2] = -co[:, 1]
    no = np.empty(n * 3, dtype=np.float32)
    m.vertices.foreach_get("normal", no)
    no = no.reshape(n, 3)
    nor[i, :, 0] = no[:, 0]
    nor[i, :, 1] = no[:, 2]
    nor[i, :, 2] = -no[:, 1]
    ev.to_mesh_clear()


def save_exr(name, data, path):
    data = data[::-1]  # Blender image rows start at the bottom; frame 0 must be the top row
    img = bpy.data.images.new(name, width=n, height=frames, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(data.ravel())
    img.filepath_raw = path
    img.file_format = 'OPEN_EXR'
    img.save()
    bpy.data.images.remove(img)


normals_filepath = os.path.splitext(output_filepath)[0] + "_n.exr"
save_exr("vat", pix, output_filepath)
save_exr("vat_n", nor, normals_filepath)

print(f"VAT: {obj.name} / {action.name}: {n} vertices x {frames} frames -> {output_filepath}, {normals_filepath}")

# Rest mesh = evaluated (GN output) mesh at the first frame, as a temporary object
scene.frame_set(f0)
dg = bpy.context.evaluated_depsgraph_get()
rest = bpy.data.meshes.new_from_object(obj.evaluated_get(dg), preserve_all_data_layers=True, depsgraph=dg)
if len(rest.vertices) != n:
    count = len(rest.vertices)
    bpy.data.meshes.remove(rest)
    sys.exit(f"VAT: rest mesh has {count} vertices, expected {n}")

# Per-vertex lookup coordinate in a second UV map (becomes UV2 in Godot)
if len(rest.uv_layers) == 0:
    rest.uv_layers.new(name="UVMap")  # keep VAT as the second layer
vat_uv = rest.uv_layers.new(name="VAT")
loop_verts = np.empty(len(rest.loops), dtype=np.int32)
rest.loops.foreach_get("vertex_index", loop_verts)
uv = np.zeros((len(rest.loops), 2), dtype=np.float32)
uv[:, 0] = (loop_verts + 0.5) / n
uv[:, 1] = 0.5
vat_uv.data.foreach_set("uv", uv.ravel())

tmp = bpy.data.objects.new(obj.name, rest)
tmp.matrix_world = obj.matrix_world
scene.collection.objects.link(tmp)

# Export only the temporary rest object, no animation
bpy.ops.object.select_all(action='DESELECT')
tmp.select_set(True)
bpy.context.view_layer.objects.active = tmp

mesh_filepath = os.path.splitext(output_filepath)[0] + ".glb"
bpy.ops.export_scene.gltf(
    filepath=mesh_filepath,
    export_format='GLB',
    use_selection=True,
    export_apply=False,       # tmp has no modifiers; its mesh already is the evaluated result
    export_animations=False,
    export_skins=False,
    export_morph=False,
    export_texcoords=True,
    export_yup=True,          # Convert to glTF's Y-up convention
)

bpy.data.objects.remove(tmp)
bpy.data.meshes.remove(rest)
print(f"VAT: mesh -> {mesh_filepath}")
