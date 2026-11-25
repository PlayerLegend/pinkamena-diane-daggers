extends Node3D

var boid_cooldown: float
@export var boid_type: BoidType
@export var boid_sim: BoidSim
@export var boid_spawn_point: Marker3D
@export var boid_target_point: Marker3D

func _random_boid_position():
    var result = Vector3(randf_range(-1,1),0,randf_range(-0.1,0.1)) * 3
    return boid_spawn_point.position + result

func _ready():
    boid_target_point.add_to_group("chase_targets")
    visibility_changed.connect(_on_visibility_changed)

func _physics_process(delta: float) -> void:
    if not visible:
        return
    if boid_cooldown <= 0:
        boid_cooldown = 0.05
        var boid_position = _random_boid_position()
        boid_sim.add_boid(boid_sim.get_type_index(boid_type), boid_position, Quaternion.IDENTITY,Vector3.ZERO, boid_type.health)
    else:
        boid_cooldown -= delta
        
    for boid in boid_sim.get_boids_in_area(boid_target_point.position, 1.0):
        boid_sim.remove_boid(boid)
    
func _on_visibility_changed() -> void:
    boid_manager.clear()
    if visible:
        boid_target_point.add_to_group("chase_targets")
    else:
        boid_target_point.remove_from_group("chase_targets")
