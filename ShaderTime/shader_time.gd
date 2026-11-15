extends Node

func _process(_delta: float) -> void:
    RenderingServer.global_shader_parameter_set(
        "shader_time", 
        Time.get_ticks_msec() / 1000.0
    )
