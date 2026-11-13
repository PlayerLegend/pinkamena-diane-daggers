extends Node3D

@export var boid_manager: BoidManager

func _ready():
    child_entered_tree.connect(_on_child_entered_tree)

func _on_child_entered_tree(node: Node):
    if node is LetterProjectile:
        node.boid_manager = boid_manager
