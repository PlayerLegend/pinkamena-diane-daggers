class_name XtalPickup
extends Node3D

@export var target_height: float = 1

@export_flags_3d_physics var floor_collision_mask

var time: float
var velocity: Vector3

func get_height(up: Vector3 = Vector3.UP, max_distance: float = 1000.0, collision_mask: int = floor_collision_mask) -> float:
    var space_state := get_world_3d().direct_space_state
    var from := global_position
    var to := from - up.normalized() * max_distance

    var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)

    var hit := space_state.intersect_ray(query)
    if hit.is_empty():
        return NAN

    return (from - hit.position).dot(up.normalized())
    
func _helper_find_spider() -> Spider:
    var dist = INF
    var result = null
    for spider in get_tree().get_nodes_in_group("spiders"):
        if spider is Spider:
            if spider.health <= 0:
                continue
            var spider_dist = (spider.global_position - global_position).length_squared()
            if spider_dist < dist:
                result = spider
                dist = spider_dist
    return result

func _helper_find_player() -> PlayerController:
    var dist = INF
    var result = null
    for player in get_tree().get_nodes_in_group("players"):
        assert(player is PlayerController)
        var player_dist = (player.global_position - global_position).length_squared()
        if player_dist < dist:
            result = player
            dist = player_dist
    return result

func _helper_fly_to_spider(delta: float, spider: Spider):
    var wishdir = (spider.global_position - global_position).normalized()
    velocity = wishdir
    
func _helper_fly_to_player(delta: float, player: PlayerController):
    if not player:
        return
        
    if (player.global_position - global_position).length_squared() < 0.2:
        player.shot_power += 1
        queue_free()
        return
        
    var wishdir = (player.global_position - global_position).normalized()
    var wishvel = 15 * wishdir
    var fric = velocity.slide(wishdir)    
    var delta_v = (wishvel - velocity) * delta / 2 - fric * delta
    var height = get_height()
    if is_nan(height):
        height = player.global_position.y
        delta_v.y += (player.position.y - position.y)*delta
    else:
        delta_v.y += (target_height - height) * delta
    
    velocity += delta_v
    


func _rollback_tick(delta: float, _tick, _is_fresh):
    
    #delta *= NetworkTime.physics_factor
    
    if not is_multiplayer_authority() and _is_fresh:
        return
        
    print("xtal position ", position)
        
    time += delta

    rotation = rotation.lerp(Vector3(0,0,0), delta)
    var spider := _helper_find_spider()
    if spider:
        _helper_fly_to_spider(delta, spider)
    else:
        var player := _helper_find_player()
        _helper_fly_to_player(delta, player)
    position += velocity * delta
        
