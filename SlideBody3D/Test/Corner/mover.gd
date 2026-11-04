extends SlideBody3D

func _physics_process(delta: float) -> void:
    velocity = Vector3(1, 0, -1)
    var result = move_and_slide(delta)
    if result.did_hit:    
        print("Hit ", result.normal_total)
    else:
        print("Miss")
