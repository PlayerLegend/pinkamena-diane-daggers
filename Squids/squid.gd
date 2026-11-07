extends SlideBody3D

class_name Squid

var fly_direction: Vector3
var arena_radius: float = 11 * 4
@export var vis_model: Node3D

@export var skull_count: Array[int]
@export var skull_scene: Array[PackedScene]

func _ready():
    sync_to_physics = false
    fly_direction.x = randf_range(-1,1)
    fly_direction.z = randf_range(-1,1)
    fly_direction = fly_direction.normalized()
    
    var height = position.y
    position = -arena_radius * fly_direction
    position.y = height

func _rollback_tick(delta: float, _tick, _is_fresh):
    
    #delta *= NetworkTime.physics_factor
    
    if not is_multiplayer_authority() and _is_fresh:
        return
        
    if position.dot(fly_direction) > arena_radius * 0.9:
        fly_direction = Vector3(0,0,0)
    
    velocity = fly_direction * 0.1
    
    move_and_slide(delta)

func _process(delta: float):
    assert(vis_model)
    vis_model.rotation.y += delta / 3.14
