extends Node3D

@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

var cooldown: float

func _process(delta: float) -> void:
    if cooldown < 0:
        mesh_instance_3d.set_instance_shader_parameter("start_time", Time.get_ticks_msec() / 1000.0)
        cooldown = 0.5
    else:
        cooldown -= delta
