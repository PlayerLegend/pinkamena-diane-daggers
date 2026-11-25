extends SlideBody3D

class_name Squid

var fly_direction: Vector3
@export var arena_radius: float = 11 * 3 * 1.05

@export var rollback_synchronizer: RollbackSynchronizer

@export var xtal_scene: PackedScene
@export var spawn_count: Array[int]
@export var spawn_boid_type: Array[BoidType]
@export var spawn_rate: float = 0.05
@export var attack_rate: float = 1 #20
@export var spawn_output: Node3D
@export var boid_sim: BoidSim

@export var pain_sound: AudioStreamPlayer3D
@export var death_sound: AudioStreamPlayer3D

var spawn_cooldown: float
var attack_cooldown: float = 2
var did_spawn_index: int = 999
var did_spawn_count: int
var xtal_count: int

var dead_time: float

func _ready():
    sync_to_physics = false
    fly_direction.x = randf_range(-1,1)
    fly_direction.z = randf_range(-1,1)
    fly_direction = fly_direction.normalized()
    
    rotation.y = randf_range(0,1) * PI
    
    var height = position.y
    position = -arena_radius * fly_direction
    position.y = height
    
    
    for child in get_children():
        if child is XtalTarget:
            xtal_count += 1
            child.xtal_died.connect(_xtal_died)

func spawn_boid(boid_type: BoidType):
    
    print("Tried spawning a boid")
    
    assert(spawn_output)
    var new_xform = spawn_output.global_transform
    var offs = Vector3(randf_range(-1,1), 5, randf_range(-1,1)).normalized()
    var new_vel = 3 * offs
    var type_index = boid_sim.get_type_index(boid_type)
    var boid = boid_sim.add_boid(type_index, new_xform.origin, new_xform.basis.get_rotation_quaternion(), new_vel, boid_type.health)
    print("Spawned a boid ", boid, " type ", type_index)

func attack_idle(delta: float):
    if not boid_sim:
        push_warning("Missing Boidsim")
        return
    attack_cooldown -= delta
    spawn_cooldown -= delta
    
    if spawn_cooldown >= 0:
        return
    
    spawn_cooldown = spawn_rate
    
    while true:
        if did_spawn_index >= len(spawn_count):
            return
            
        var count = spawn_count[did_spawn_index]
        
        if did_spawn_count >= count:
            did_spawn_index += 1
            did_spawn_count = 0
            continue
        
        did_spawn_count += 1
        
        spawn_boid(spawn_boid_type[did_spawn_index])
        
        return

func attack():
    attack_cooldown = attack_rate
    did_spawn_count = 0
    did_spawn_index = 0
    
func _rollback_tick(delta: float, _tick, _is_fresh):
    if not visible:
        return
        
    #delta *= NetworkTime.physics_factor
    
    if not is_multiplayer_authority() and _is_fresh:
        return
    
    if xtal_count <= 0:
        position.y -= delta
        collision_layer = 0
        return
    
    attack_idle(delta)
    if attack_cooldown < 0:
        attack()
        
    if position.dot(fly_direction) > arena_radius * 0.9:
        fly_direction = Vector3(0,0,0)
    
    velocity = fly_direction * 0.4
    
    move_and_slide(delta)

func _process(delta: float):
    if xtal_count <= 0:
        dead_time += delta
        rotation.y += delta * dead_time * 5 + delta / 0.314
        if dead_time >= 8.0:
            queue_free()
    else:
        rotation.y += delta / 3.14

func drop_xtal(where: Transform3D):
    var new_xtal = xtal_scene.instantiate()
    get_parent().add_child(new_xtal)
    new_xtal.global_transform = where

func _xtal_died(xtal: XtalTarget):
    xtal_count -= 1
    if xtal_count == 0:
        if death_sound:
            death_sound.play()
    drop_xtal(xtal.global_transform)

func _xtal_damaged(_xtal: XtalTarget):
    if pain_sound:
        pain_sound.play()
    
            
            
    
