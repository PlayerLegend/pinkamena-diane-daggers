extends Node3D

@export var tile_scene: PackedScene

var time: float = 0

var spawn_radius = 11
var tile_width = 4.0

func _ready():
    var limit = spawn_radius * spawn_radius
    for x in range(-spawn_radius, spawn_radius):
        for y in range(-spawn_radius, spawn_radius):
            if x * x + y * y > limit:
                continue
            var tile = tile_scene.instantiate()
            add_child(tile)
            tile.position.x = x * tile_width
            tile.position.z = y * tile_width
            tile.position.y = -tile_width / 2

func _rollback_tick(delta: float, _tick, _is_fresh):
    
    if not is_multiplayer_authority() and _is_fresh:
        return
    
    time += delta
    
func _process(_delta: float):
    var time_fac = clamp(time / 1200.0, 0, 1)
    var cdist_min = 4 * tile_width
    var cdist_max = spawn_radius * tile_width
    
    for node in get_children():
        if not node is ArenaTile:
            continue
        var cdist = Vector2(node.position.x, node.position.z).length()
        var dist_fac = min((cdist - cdist_min) / (cdist_max - cdist_min), 1)
        
        if dist_fac < 0:
            continue
        
        var fall_fac = clamp(dist_fac - (1.0 - time_fac), 0, 1)
        
        var base_pos = -tile_width / 2
        node.position.y = base_pos - fall_fac * tile_width * 200.0
    
    
