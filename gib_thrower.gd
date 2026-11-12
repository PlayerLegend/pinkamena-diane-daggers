extends Node3D

@export var static_mesh_manager: StaticMeshManager
@export var decal_canvas: DecalCanvas
@export var gib_scenes: Array[PackedScene]

func _ready():
    BoidManager.boid_removed.connect(_on_boid_removed)

func throw_gib(pos: Vector3, vel: Vector3):
    var gib_scene = gib_scenes.pick_random()
    var gib: Gib = gib_scene.instantiate()
    add_child(gib)
    gib.static_mesh_manager = static_mesh_manager
    gib.decal_canvas = decal_canvas
    gib.velocity = vel
    gib.position = pos
    var avel := Quaternion(Vector3(randfn(-1.0, 1.0), randfn(-1.0, 1.0), randfn(-1.0, 1.0)).normalized(), PI)
    gib.rotation.x = randf_range(0,1) * PI
    gib.rotation.y = randf_range(0,1) * PI
    gib.rotation.z = randf_range(0,1) * PI
    gib.avelocity = avel

func _on_boid_removed(
    _type: BoidType,
    boid_mesh: Mesh,
    pos: Vector3,
    velocity: Vector3,
    forward: Vector3,
    health: int
):
    var randvel = Vector3(
        randf_range(-1,1),
        randf_range(0,1),
        randf_range(-1,1)
    ) * 2.0
    throw_gib(pos, velocity + Vector3.UP * 2.0 + randvel)
