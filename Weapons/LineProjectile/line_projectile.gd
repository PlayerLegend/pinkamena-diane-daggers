extends Projectile

class_name LineProjectile

var fly_start: Vector3
var fly_direction: Vector3
var fly_elapsed: float
@export var fly_speed: float = 1.0
@export var fly_finish_scene: PackedScene
@export var fly_finish_node: Node

var _is_finished: bool = false

var _phys_position_last: Vector3

enum ProjectileState {
    POSITION,
    DIRECTION,
}

func _init() -> void:
    top_level = true

func serialize() -> Dictionary:
    var result = {
        ProjectileState.POSITION: fly_start,
        ProjectileState.DIRECTION: fly_direction,
    }
    return result    
    
func deserialize(parameters: Dictionary, up: Vector3):
    var fpos: Vector3 = parameters.get(ProjectileState.POSITION)
    var fdir: Vector3 = parameters.get(ProjectileState.DIRECTION)
    set_path(fpos, fdir, up)

func set_path(start: Vector3, dir: Vector3, up: Vector3) -> void:
    
    fly_start = start
    _phys_position_last = start
    fly_direction = dir
    fly_elapsed = 0
    position = start
    #look_at(dir, up)
    basis = Basis.looking_at(dir, up)
    
func set_direction(dir: Vector3, up: Vector3) -> void:
    set_path(position, dir, up)

func _process(delta: float) -> void:
    fly_elapsed += delta
    position = fly_start + fly_direction * fly_elapsed * fly_speed

func _fly_physics_active(_delta: float) -> void:
    pass
    
func _fly_physics_inactive(_delta: float) -> void:
    pass

func _fly_physics_hit(_other: Node3D, _shape: CollisionShape3D) -> void:
    queue_free()

func _physics_process(delta: float) -> void:
    if fly_elapsed > fly_time:
        queue_free()
        return
    if _is_finished:
        _fly_physics_inactive(delta)
    else:
        var space_state = get_world_3d().direct_space_state
        var next = position + fly_direction * fly_speed * delta
        var query = PhysicsRayQueryParameters3D.create(_phys_position_last, next)
        _phys_position_last = next
        var result = space_state.intersect_ray(query)
        if result:
            _is_finished = true
            var body = result["collider"]
            var shape_index = result["shape"]
            var owner_id = body.shape_find_owner(shape_index)
            var shape = body.shape_owner_get_owner(owner_id)

            _fly_physics_hit(body, shape)
            _fly_physics_inactive(delta)
        else:
            _fly_physics_active(delta)
