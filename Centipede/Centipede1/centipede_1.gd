extends Centipede

@export var speed: float = 5.0
@export var floor = 3.0
@export var xtal_pickup: PackedScene

var health: int

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

func _rollback_tick(delta: float, _tick, _is_fresh):
    super(delta, _tick, _is_fresh)
    
    if not is_multiplayer_authority() and _is_fresh:
        return
        
    var player = _helper_find_player()
    
    if not player:
        return
    
    var to_player = player.position - position
    
    var tilt = to_player.normalized().dot(basis.x)
    
    var time = Time.get_ticks_msec() / 1000.0
    
    var target_basis = Basis.looking_at(to_player)
    target_basis = target_basis.rotated(-target_basis.z, tilt * 1.5).rotated(basis.x, sin(time * PI / 1.5))
    
    if position.y < floor:
        target_basis = target_basis.rotated(basis.x, delta * 15.0)
    
    basis = basis.slerp(target_basis, delta * 2.0)
    
    position += -basis.z * speed * delta
    print("Centipos ", position)

func _drop_xtal(where: Transform3D):
    var new_xtal = xtal_pickup.instantiate()
    get_parent().add_child(new_xtal)
    new_xtal.global_transform = where

    
func _xtal_died(xtal: XtalTarget):
    health -= 1
    _drop_xtal(xtal.global_transform)

func _ready():
    super()
    assert(xtal_pickup)
    for child in get_children():
        if child.has_signal("xtal_died"):
            child.xtal_died.connect(_xtal_died)
            health += 1
