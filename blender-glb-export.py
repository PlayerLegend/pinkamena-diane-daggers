import bpy
import os
import sys
import argparse

parser = argparse.ArgumentParser()

parser.add_argument('filename')
parser.add_argument('-r', '--renderable',action='store_true',default=False)
parser.add_argument('-s', '--selection',action='store_true',default=False)
parser.add_argument('-v', '--visible',action='store_true',default=False)

argv = sys.argv[sys.argv.index("--") + 1:]
args = parser.parse_args(argv)
output_filepath = os.path.abspath(args.filename)

if args.renderable == False and args.visible == False and args.selection == False:
    args.renderable = True #Default behavior if no flag is set

if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

bpy.ops.export_scene.gltf(
    filepath=output_filepath,
    export_format='GLB',
    use_renderable=args.renderable,
    use_selection=args.selection,
    use_visible=args.visible,
    export_vertex_color='ACTIVE',  # Blender 3.x+/4.x: 'MATERIAL', 'ACTIVE', or 'NONE'
    export_apply=True,             # Apply modifiers
    export_yup=True,               # Convert to glTF's Y-up convention
)

Collapse (33 lines)
