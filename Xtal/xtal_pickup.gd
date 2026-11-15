class_name XtalPickup
extends SlideBody3D

@export var target_height: float = 1
@onready var hum_sound: AudioStreamPlayer3D = $HumSound

var time: float

func _ready():
    sync_to_physics = false
    hum_sound.play()

func get_height() -> float:
    var query := PhysicsRayQueryParameters3D.create(
        global_position,
        global_position + Vector3.DOWN * 1000.0
    )
    query.exclude = [get_rid()]

    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return NAN

    return global_position.y - hit.position.y
    
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
    for player in get_tree().get_nodes_in_group("chase_targets"):
        if player is PlayerController:
            if not player.visible:
                continue
            var player_dist = (player.global_position - global_position).length_squared()
            if player_dist < dist:
                result = player
                dist = player_dist
    return result

func _helper_fly_to_spider(_delta: float, spider: Spider):
    var wishdir = (spider.global_position - global_position).normalized()
    velocity = wishdir
    
func _helper_fly_to_player(delta: float, player: PlayerController):
    if not player:
        return
        
    if (player.global_position - global_position).length_squared() < 0.5:
        player.attack_power += 1
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
    
    if not is_multiplayer_authority() and _is_fresh:
        return
        
    time += delta

    rotation = rotation.lerp(Vector3(0,0,0), delta)
    var spider := _helper_find_spider()
    if spider:
        _helper_fly_to_spider(delta, spider)
    else:
        var player := _helper_find_player()
        _helper_fly_to_player(delta, player)
    print("Velocity ", velocity)
    move_and_slide(delta)
        
