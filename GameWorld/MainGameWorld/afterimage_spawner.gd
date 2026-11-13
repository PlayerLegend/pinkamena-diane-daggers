class_name AfterimageSpawner
extends Node3D

var afterimage_scene = preload("res://Skulls/SkullAfterimage.tscn")
@export var boid_manager: BoidManager

func _on_boid_removed(
    _type: BoidType,
    boid_mesh: Mesh,
    pos: Vector3,
    _velocity: Vector3,
    forward: Vector3,
    health: int
    ):
        if health > 0:
            return
        var afterimage: SkullAfterimage = afterimage_scene.instantiate()
        add_child(afterimage)
        afterimage.global_transform = Transform3D(Basis.looking_at(forward, Vector3.UP), pos)
        afterimage.set_mesh_1(boid_mesh)
        #var splatter = splatter_scene.instantiate()
        #get_tree().current_scene.add_child(splatter)
        #splatter.place(BoidManager.get_boid_position(boid))
    

func _ready():
    boid_manager.boid_removed.connect(_on_boid_removed)
