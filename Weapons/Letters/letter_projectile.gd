class_name LetterProjectile
extends LineProjectile
@onready var mesh_instance_3d: MeshInstance3D = $MeshInstance3D

var mesh: Mesh:
    set(value):
        mesh_instance_3d.mesh = value
        
func _ready() -> void:
    add_to_group("projectiles")

func _fly_physics_hit(other: Node3D) -> void:
    print("Projectile hit ", other)
    if other is XtalTarget:
        other.take_damage(1)
    queue_free()
