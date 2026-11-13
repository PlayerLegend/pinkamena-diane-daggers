extends Node3D

var boid_cooldown: float
@export var boid_type: BoidType
@export var boid_manager: BoidManager
@export var boid_spawn_point: Marker3D
@export var boid_target_point: Marker3D

func _random_boid_position():
    var result = Vector3(randf_range(-1,1),0,randf_range(-0.1,0.1)) * 3
    return boid_spawn_point.position + result

func _ready():
    boid_target_point.add_to_group("chase_targets")

func _physics_process(delta: float) -> void:
    if boid_cooldown <= 0:
        boid_cooldown = 0.05
        var boid_position = _random_boid_position()
        boid_manager.add_boid(boid_type, Transform3D(Basis.IDENTITY, boid_position),Vector3.ZERO)
    else:
        boid_cooldown -= delta
        
    for boid in boid_manager.get_boids_in_area(boid_target_point.position, 1.0):
        boid_manager.remove_boid(boid)
    
