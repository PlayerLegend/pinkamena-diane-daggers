import bpy
import os
import sys

argv = sys.argv[sys.argv.index("--") + 1:]
output_filepath = os.path.abspath(argv[0])

if bpy.context.object is not None and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

# Select only visible objects
bpy.ops.object.select_all(action='DESELECT')
view_layer = bpy.context.view_layer
for obj in view_layer.objects:
    if obj.visible_get(view_layer=view_layer) and not obj.hide_render:
        obj.select_set(True)

bpy.ops.wm.obj_export(
    filepath=output_filepath,
    export_selected_objects=True,
    export_colors=True,
    path_mode='STRIP',
)
