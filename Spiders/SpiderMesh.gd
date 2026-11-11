class_name SpiderMesh
extends MeshInstance3D

func _now() -> float:
    return Time.get_ticks_msec() * 0.001

func flash():
    set_instance_shader_parameter("flash_end", _now() + 1.0 / 20.0)
