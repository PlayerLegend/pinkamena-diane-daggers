extends PhysicsCharacter

class_name PlayerController

@export var walk_gravity = 20
@export var walk_friction: float = 2.0
@export var walk_speed: float = 8 #64 #16
@export var walk_acceleration: float = 6.0
@export var walk_stopspeed: float = 8
@export var walk_jump_speed: float = 8
@export var walk_air_control: float = 0.3
@export var guide_action_look:GUIDEAction
@export var body_light: PlayerLight
@export var camera_offset: float = 0.5
@export var weapons_controller: PlayerControllerWeapons
@onready var xtal_pickup_sound: AudioStreamPlayer3D = $XtalPickupSound
@onready var hoof_translation: Node3D = $HoofTranslation
@onready var hoof_rotation: Node3D = $HoofTranslation/HoofRotation
@onready var hoof_skel: Skeleton3D = $HoofTranslation/HoofRotation/HoofVisual/HoofArmature/Skeleton3D
@onready var projectile_source: Marker3D = $HoofTranslation/HoofRotation/HoofVisual/ProjectileSource

var _teleport_to: Variant = null

@export var projectile_parent: Node:
    set(value):
        weapons_controller.projectile_parent = value
    get:
        return weapons_controller.projectile_parent
        
signal attack_power_changed(player: PlayerController)

var attack_power: int:
    set(value):
        if value != weapons_controller.attack_power:
            attack_power_changed.emit(self)
            body_light.energy_scale = 10.0
            if value > weapons_controller.attack_power:
                xtal_pickup_sound.play()
        weapons_controller.attack_power = value
    get:
        return weapons_controller.attack_power

var _light_fade_target: float

@export var enable_light: bool:
    set(value):
        if value:
            _light_fade_target = 1.0
        else:
            _light_fade_target = 0
        enable_light = value
        print("Set enable light to ", _light_fade_target)
        
@onready var input = $Input
@export var camera: Node3D
@onready var rollback_synchronizer = $RollbackSynchronizer
#@onready var projectile_source = $CamLook/Camera3D/Attack
@onready var camera_controller = $CamLook

var up_direction := Vector3(0,1,0)
var explosion_knock: Vector3 # needs to be applied during _rollback_tick

var look_direction: Vector3

func _helper_jump():
    var have_speed = velocity.dot(up_direction)
    
    var add_speed = clamp(walk_jump_speed - have_speed, 0, walk_jump_speed)
    
    velocity += add_speed * up_direction

func _helper_fall(delta: float):
    velocity += -walk_gravity * delta * up_direction

func _helper_get_wishdir():
    
    var look_basis = Basis(input.look)
    
    var is_inverted = look_basis.y.dot(up_direction) < 0
    
    var walk = input.walk
    
    if is_inverted:
        walk.y *= -1
    
    var wishdir = walk.x * look_basis.x + walk.y * look_basis.z
    
    wishdir = wishdir - up_direction * up_direction.dot(wishdir)
    
    
    return wishdir.normalized()

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
        wishspeed *= walk_air_control

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

func _helper_phys_update_camera(velocity_start: Vector3, _is_on_floor: bool):
    
    var accel = velocity - velocity_start
    #camera_controller.set_accel(accel)
    #camera_controller.set_gravity(-up_direction)
    
func _helper_phys_apply_explosion_knock():
    if not explosion_knock:
        return
    velocity += explosion_knock
    explosion_knock = Vector3(0,0,0)    

func _process(delta: float):
    var shot_fac = -weapons_controller.attack_charge * 0.6
    hoof_rotation.transform = camera_controller.transform
    hoof_translation.position = hoof_rotation.basis.z * shot_fac
    var bone_idx = hoof_skel.find_bone("Hoof.003")
    var bone_global = hoof_skel.global_transform * hoof_skel.get_bone_global_pose(bone_idx)
    #projectile_source.global_transform = bone_global
    #weapons_controller.global_transform = bone_global
    
    var light_decay = delta
    if body_light.energy_scale > 1.0:
        light_decay *= 10
    body_light.energy_scale = lerp(body_light.energy_scale, _light_fade_target, light_decay)
    var local_direction = quaternion.inverse() * up_direction
    camera_controller.position = camera_controller.position.slerp(local_direction * camera_offset, delta)

func _helper_phys_rollback_else(delta: float):
    
    _helper_phys_apply_explosion_knock()
    
    var velocity_start = velocity

    var wishdir: Vector3 = _helper_get_wishdir()

    var collision := move_and_slide(delta)
    
    var is_on_floor := collision != null
    
    _helper_apply_acceleration(wishdir, delta, is_on_floor)
    
    _helper_phys_update_camera(velocity_start, is_on_floor)
    
    _helper_phys_apply_explosion_knock()
    
    _helper_phys_floor(delta, wishdir, is_on_floor)
    
    look_direction = -camera.global_basis.z

func _rollback_tick(delta: float, _tick, _is_fresh):
    
    #delta *= NetworkTime.physics_factor
    
    #if not is_multiplayer_authority():
        #set_multiplayer_authority(1, true)
        
    if not is_multiplayer_authority() and _is_fresh:
        return
        
    if _teleport_to != null:
        assert(_teleport_to is Transform3D)
        global_transform = _teleport_to
        _teleport_to = null
        velocity = Vector3.ZERO
    
    _helper_phys_rollback_else(delta)
    
func teleport(target: Transform3D):
    _teleport_to = target
    global_transform = target
    velocity = Vector3.ZERO
    
func _helper_find_spawn() -> Node3D:
    return get_tree().get_nodes_in_group("player_spawns").pick_random()

func respawn() -> void:
    var target_spawn = _helper_find_spawn()
    transform = target_spawn.transform

func set_mouse_scale(mouse_scale: float):
    if not input.is_multiplayer_authority():
        return
    
    camera_controller.set_mouse_scale(mouse_scale)    

func get_camera_global_transform():
    return camera.global_transform

func set_chase_group():
    if visible:
        add_to_group("chase_targets")
    else:
        remove_from_group("chase_targets")
        
func _on_visibility_changed():
    set_chase_group()

func _ready():
    await get_tree().process_frame
    body_light.energy_scale = 0
    set_chase_group()
    visibility_changed.connect(_on_visibility_changed)
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
