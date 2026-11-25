extends MultiplayerSpawner
@export var boid_sim: BoidSim

func _ready():
    assert(boid_sim)
    child_entered_tree.connect(_on_child_entered_tree)

func _on_child_entered_tree(node: Node) -> void:
    if node is Squid:
        node.boid_sim = boid_sim
