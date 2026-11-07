extends Node

func _physics_process(delta: float) -> void:
    var players := get_tree().get_nodes_in_group("players")
    if not players:
        return
        
    for child in get_children():
        if child is Boid:
            child.target_direction = (players[0].position - child.position)
