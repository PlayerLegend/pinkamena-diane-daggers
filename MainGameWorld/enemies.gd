extends Node

func _physics_process(_delta: float) -> void:
    var players := get_tree().get_nodes_in_group("players")
    if not players:
        return
        
    for child in get_children():
        if child is Boid:
            child.target_direction = (players[0].position - child.position)

func _on_child_entered_tree(_node: Node) -> void:
    pass
