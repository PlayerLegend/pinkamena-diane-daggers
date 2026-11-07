extends SlideBody3D

class_name PlayerController

@export var walk_gravity = 15
@export var walk_friction: float = 2.0
@export var walk_speed: float = 8 #64 #16
@export var walk_acceleration: float = 6.0
@export var walk_stopspeed: float = 8
@export var walk_jump_speed: float = 8
@export var guide_action_look:GUIDEAction
@export var body_light: OmniLight3D
@export var camera_offset: float = 0.5

@onready var input = $Input
@onready var camera = $CamLook/Camera3D
@onready var rollback_synchronizer = $RollbackSynchronizer
@onready var projectile_source = $CamLook/Camera3D/Attack
@onready var camera_controller = $CamLook

var up_direction := Vector3(0,1,0)
var explosion_knock: Vector3 # needs to be applied during _rollback_tick

func give_weapon(scene: PackedScene):
    camera.add_child(scene.instantiate())

func _helper_jump():
    var have_speed = velocity.dot(up_direction)
    
    var add_speed = clamp(walk_jump_speed - have_speed, 0, walk_jump_speed)
    
    velocity += add_speed * up_direction

func _helper_fall(delta: float):
    velocity += -walk_gravity * delta * up_direction

func _helper_get_walk_basis():
    var look_basis = Basis(input.look)
    var forward: Vector3 = -look_basis.z
    var forward_flat = forward - forward * up_direction.dot(forward)
    var up = up_direction
    
    print("test ", up_direction.dot(look_basis.y) < 0)
    
    if up_direction.dot(look_basis.y) < 0:
        up = -up
    return Basis.looking_at(forward_flat, up)

func _helper_get_wishdir():
    
    var look_basis = Basis(input.look)
    
    var is_inverted = look_basis.y.dot(up_direction) < 0
    
    var walk = input.walk
    
    if is_inverted:
        walk.y *= -1
    
    var wishdir = walk.x * look_basis.x + walk.y * look_basis.z
    
    wishdir = wishdir - up_direction * up_direction.dot(wishdir)
    
    
    return wishdir.normalized()

func take_explosion_damage(explosion_position: Vector3, explosion_power: float):
    var my_position = camera.global_position
    var direction = (my_position - explosion_position).normalized()
    explosion_knock += direction * 200.0 * explosion_power

func _helper_apply_friction(wishdir: Vector3, delta: float) -> void:
    var have_speed: float = wishdir.dot(velocity)
    
    if have_speed < 0:
        have_speed = 0

    var friction_vel = velocity - have_speed * wishdir
    
    friction_vel = friction_vel.slide(up_direction)
    
    var friction_mag = friction_vel.length()
    var friction_dir = friction_vel.normalized()
    var friction_take = delta * walk_friction * friction_mag
    
    if friction_mag < walk_stopspeed:
        friction_take *= 4
        
    if friction_take > friction_mag:
        friction_take = friction_mag
    
    var take: Vector3 = -friction_take * friction_dir

    velocity += take

func _helper_apply_acceleration(wishdir: Vector3, delta: float, is_on_floor: bool) -> void:
    var have_speed = wishdir.dot(velocity)

    var wishspeed = walk_speed
    
    if not is_on_floor:
        wishspeed *= 0.5

    var add_speed_cap = wishspeed - have_speed
    
    if add_speed_cap <= 0:
        return
        
    var add_speed = min(add_speed_cap, walk_acceleration * delta * wishspeed)
        
    velocity += wishdir * add_speed

func _helper_phys_floor(delta: float, wishdir: Vector3, is_on_floor: bool):
    #_helper_fall(delta)
    #if is_on_floor and not input.jump:
        #_helper_apply_friction(wishdir, delta)
    if input.jump:
        if is_on_floor:
            _helper_jump()
        else:
            _helper_fall(delta)
    else:
        if is_on_floor:
            _helper_apply_friction(wishdir, delta)
        else:
            _helper_fall(delta)

func _helper_phys_update_camera(velocity_start: Vector3, is_on_floor: bool):
    
    var accel = velocity - velocity_start
    camera_controller.set_accel(accel)
    camera_controller.set_gravity(-up_direction)
    
    #camera.enable_roll = is_on_floor

func _helper_phys_apply_explosion_knock():
    if not explosion_knock:
        return
    velocity += explosion_knock
    explosion_knock = Vector3(0,0,0)    

func _process(delta: float):
    var local_direction = quaternion.inverse() * up_direction
    camera_controller.position = camera_controller.position.slerp(local_direction * camera_offset, delta)

func _helper_phys_rollback_else(delta: float):
    
    _helper_phys_apply_explosion_knock()
    
    var velocity_start = velocity

    var wishdir: Vector3 = _helper_get_wishdir()

    var collision := move_and_slide(delta)
    
    var is_on_floor := collision.did_hit
    
    _helper_apply_acceleration(wishdir, delta, is_on_floor)
    
    _helper_phys_update_camera(velocity_start, is_on_floor)
    
    _helper_phys_apply_explosion_knock()
    
    _helper_phys_floor(delta, wishdir, is_on_floor)
    
    if collision.did_hit:
        is_on_floor = true
    else:
        is_on_floor = false

func _rollback_tick(delta: float, _tick, _is_fresh):
    
    #delta *= NetworkTime.physics_factor
    
    if not is_multiplayer_authority() and _is_fresh:
        return
    
    _helper_phys_rollback_else(delta)
    
func _helper_find_spawn() -> Node3D:
    return get_tree().get_nodes_in_group("player_spawns").pick_random()

func respawn() -> void:
    var target_spawn = _helper_find_spawn()
    transform = target_spawn.transform

func set_mouse_scale(mouse_scale: float):
    if not input.is_multiplayer_authority():
        return
    
    camera_controller.set_mouse_scale(mouse_scale)    

func _ready():
    await get_tree().process_frame
    add_to_group("players")
    set_multiplayer_authority(1)
    input.set_multiplayer_authority(name.to_int())
    camera.set_multiplayer_authority(name.to_int())
    camera_controller.set_multiplayer_authority(name.to_int())
    rollback_synchronizer.process_settings()
    respawn()
    if input.is_multiplayer_authority():
        camera.current = true
    else:
        body_light.hide()
