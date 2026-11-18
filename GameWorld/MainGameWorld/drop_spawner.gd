extends Node3D

@export var static_mesh_manager: StaticMeshManager
@export var decal_canvas: DecalCanvas
@export var gib_scenes: Array[PackedScene]
@export var boid_manager: BoidManager
@export var xtal_pickup_scene: PackedScene

@onready var death_sound: AudioStreamPlayer3D = $DeathSound

func _ready():
    boid_manager.boid_removed.connect(_on_boid_removed)

func throw_gib(pos: Vector3, vel: Vector3):
    var gib_scene = gib_scenes.pick_random()
    var gib: Gib = gib_scene.instantiate()
    add_child(gib)
    gib.static_mesh_manager = static_mesh_manager
    gib.decal_canvas = decal_canvas
    gib.velocity = vel + Vector3(randf_range(-1,1), randf_range(0,1), randf_range(-1,1))
    gib.position = pos
    var avel := Quaternion(Vector3(randfn(-1.0, 1.0), randfn(-1.0, 1.0), randfn(-1.0, 1.0)).normalized(), PI)
    gib.rotation.x = randf_range(0,1) * PI
    gib.rotation.y = randf_range(0,1) * PI
    gib.rotation.z = randf_range(0,1) * PI
    gib.avelocity = avel

func spawn_xtal(pos: Vector3):
    var xtal = xtal_pickup_scene.instantiate()
    add_child(xtal)
    xtal.position = pos

func _on_boid_removed(
    type: BoidType,
    _boid_mesh: Mesh,
    pos: Vector3,
    velocity: Vector3,
    _rot: Quaternion,
    _health: int
):
    var randvel = Vector3(
        randf_range(-1,1),
        randf_range(0,1),
        randf_range(-1,1)
    ) * 2.0
    
    for i in range(type.gibs_count):
        throw_gib(pos, velocity + Vector3.UP * 2.0 + randvel)
        
    if type.drops_xtal:
        spawn_xtal(pos)
        
    death_sound.position = pos
    death_sound.play()
    death_sound.pitch_scale = 1.0 + randf_range(-0.05, 0.05)
