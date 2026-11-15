class_name Spider
extends SlideBody3D

@export var health: int = 25
@export var arena_radius: float = 11 * 3
@export var weak_point: StaticBody3D
@export var visual_mesh: SpiderMesh
@export var animation_tree: AnimationTree
var dead_time: float
@export var hit_sound: AudioStreamPlayer3D

var gem_count: int

func take_damage(amount: int):
    visual_mesh.flash()
    hit_sound.play()
    health -= amount
    if health <= 0:
        var playback: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
        playback.travel("die")

func _ready():
    sync_to_physics = false
    var fly_direction: Vector3
    fly_direction.x = randf_range(-1,1)
    fly_direction.z = randf_range(-1,1)
    fly_direction = fly_direction.normalized()
    
    var height = position.y
    position = -(arena_radius + 10.0) * fly_direction
    position.y = height
    add_to_group("spiders")
    
func _helper_find_player() -> PlayerController:
    var dist = INF
    var result = null
    for player in get_tree().get_nodes_in_group("chase_targets"):
        assert(player is PlayerController)
        var player_dist = (player.global_position - global_position).length_squared()
        if player_dist < dist:
            result = player
            dist = player_dist
    return result

func _helper_get_avoid_dir(player: PlayerController) -> Vector3:
    if not player:
        return Vector3(0,0,0)
    var dot = player.look_direction.dot(global_basis.x)
    if abs(dot) > 0.2:
        return Vector3(0,0,0)
    
    var dir = position.normalized().cross(Vector3.UP)
    if dot < 0:
        dir = -dir
    return dir
    

func _rollback_tick(delta: float, _tick, _is_fresh):
    
    #delta *= NetworkTime.physics_factor
    
    if not is_multiplayer_authority() and _is_fresh:
        return
    
    if health <= 0:
        dead_time += delta
        if dead_time > 5.0:
            queue_free()
        return
    
    var goal_position = position.normalized() * arena_radius
    goal_position.y = position.y
    
    var player := _helper_find_player()
    
    var maxspeed = 1.5
    if player:
        var avoid_dir := _helper_get_avoid_dir(player)
        goal_position += avoid_dir * maxspeed
        var target_basis := global_transform.looking_at(player.position, Vector3.UP).basis
        global_transform.basis = global_transform.basis.slerp(target_basis, delta)
    velocity = goal_position - position
    var speed = velocity.length()
    if speed > maxspeed:
        velocity *= maxspeed / speed
    move_and_slide(delta)
