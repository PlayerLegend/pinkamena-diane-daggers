extends BaseWeapon

class_name WeaponLetters

@export var projectile_scene: PackedScene
@export var projectile_source: Node3D

@onready var markov_chain: MarkovChain

var cooldown: float

func _process(delta: float):
    cooldown = max(0, cooldown - delta)

func _can_fire() -> bool:
    if cooldown > 0:
        return false
        
    return true

func _can_peer_use(_peer_id: int) -> bool:
    return true
    
func _after_fire(_projectile: Node):
    cooldown = 60.0 / 900.0
    
func _spawn() -> Node3D:
    var new_projectile: LineProjectile = projectile_scene.instantiate()
    new_projectile.add_to_group("LetterProjectiles")
    add_child(new_projectile)
    new_projectile.set_path(projectile_source.global_position, -global_basis.z, global_basis.y)
    new_projectile.fly_finish_node = self
    return new_projectile

func _get_data(projectile: Node) -> Dictionary:
    return projectile.serialize()

func _apply_data(projectile: Node, data: Dictionary):
    projectile.deserialize(data, global_basis.y)

func _is_reconcilable(_projectile: Node, _request_data: Dictionary, _local_data: Dictionary) -> bool:
    return true

func _reconcile(_projectile: Node, _local_data: Dictionary, _remote_data: Dictionary):
    pass

func _ready() -> void:
    markov_chain = MarkovChain.new(2)
    markov_chain.load_from_file("res://passages.txt")
