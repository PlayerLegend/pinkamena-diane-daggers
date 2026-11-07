class_name LetterProjectile
extends LineProjectile
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

var mesh: Mesh:
    set(value):
        mesh_instance_3d.mesh = value
        
