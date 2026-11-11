class_name LetterProjectile
extends LineProjectile
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D
@export var projectile_material: Material
@export var splatter_scene: PackedScene

var mesh: Mesh:
    set(value):
        mesh_instance_3d.mesh = value
        if projectile_material:
            mesh_instance_3d.set_surface_override_material(0, projectile_material)

func _ready() -> void:
    add_to_group("projectiles")
    mesh = mesh

func _fly_physics_hit(other: Node3D, shape: CollisionShape3D) -> void:
    #print("Projectile hit ", other)
    if other is XtalTarget:
        other.take_damage(1)
    if other is Spider:
        if shape is SpiderWeakPoint:
            other.take_damage(1)
    queue_free()

func _fly_physics_active(_delta: float) -> void:
    var boid := BoidManager.raycast(position - fly_direction * fly_speed, fly_direction, fly_speed)
    if boid < 0:
        return
        
    var health := BoidManager.get_boid_health(boid)
    health -= 1
    BoidManager.set_boid_health(boid, health)
    
    
    if health <= 0:
        #var splatter = splatter_scene.instantiate()
        #get_tree().current_scene.add_child(splatter)
        #splatter.place(BoidManager.get_boid_position(boid))
        #BoidManager.spawn_afterimage(boid)
        BoidManager.remove_boid(boid)
        
    else:
        BoidManager.set_boid_flash(boid, 1.0 / 20.0)
        
    queue_free()
