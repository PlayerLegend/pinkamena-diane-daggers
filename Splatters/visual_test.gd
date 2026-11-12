extends Node3D

var cooldown: float

func _process(delta: float):
    if cooldown <= 0:
        for child in get_children():
            if child is Splatter:
                child.place(Vector3(0,10,0))
        cooldown = 1.0
    else:
        cooldown -= delta
