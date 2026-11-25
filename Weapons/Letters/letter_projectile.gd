class_name LetterProjectile
extends LineProjectile
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@export var projectile_material: Material
@export var splatter_scene: PackedScene
@export var boid_sim: BoidSim

var _last_pos: Vector3

var mesh: Mesh:
    set(value):
        mesh_instance_3d.mesh = value
        if mesh_instance_3d.mesh and projectile_material:
            mesh_instance_3d.set_surface_override_material(0, projectile_material)

func _ready() -> void:
    add_to_group("avoid_targets")
    mesh = mesh
    _last_pos = position

func _fly_physics_hit(other: Node3D, shape: CollisionShape3D) -> void:
    #print("Projectile hit ", other)
    if other is XtalTarget:
        other.take_damage(1)
    if other is Spider:
        if shape is SpiderWeakPoint:
            other.take_damage(1)
    queue_free()

func _fly_physics_active(_delta: float) -> void:
    if not boid_sim:
        push_warning("Boidsim not set in projectile")
        queue_free()
        return
    
    var boid: int = boid_sim.raycast(_last_pos, position - _last_pos)
    _last_pos = position
    
    if boid < 0:
        return
    
    var health: int = boid_sim.get_health(boid)
    health -= 1
    boid_sim.set_health(boid, health)
    
    
    if health <= 0:
        print("Tried removing boid ", boid)
        boid_sim.remove(boid)
    else:
        boid_sim.set_flash(boid, 1.0 / 20.0)
        
    queue_free()
