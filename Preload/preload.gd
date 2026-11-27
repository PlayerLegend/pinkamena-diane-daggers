extends Node

@export var skulls: Array[BoidType]

var frames: int = 0

func _ready():
    for skull in skulls:
        var mesh_instance = MeshInstance3D.new()
        add_child(mesh_instance)
        mesh_instance.mesh = skull.mesh
        mesh_instance.material = skull.material_override
        mesh_instance.position = Vector3.ZERO

func _process(_delta: float):
    if frames == 60:
        queue_free()
    frames += 1
