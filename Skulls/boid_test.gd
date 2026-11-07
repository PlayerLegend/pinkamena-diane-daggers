extends Node3D

func _physics_process(delta: float) -> void:
    for child in get_children():
        if not child is Boid:
            continue
            
        child.target_direction = -child.global_position
