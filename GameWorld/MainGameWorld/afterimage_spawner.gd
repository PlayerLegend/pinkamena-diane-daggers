class_name AfterimageSpawner
extends Node3D

var afterimage_scene = preload("res://Skulls/SkullAfterimage.tscn")
@export var boid_sim: BoidSim

func _on_boid_removed(
    state: BoidState
    ):
        if state.health > 0:
            return
        var afterimage: SkullAfterimage = afterimage_scene.instantiate()
        add_child(afterimage)
        afterimage.global_transform = Transform3D(state.rotation, state.position)
        afterimage.set_mesh_1(state.mesh)
        #var splatter = splatter_scene.instantiate()
        #get_tree().current_scene.add_child(splatter)
        #splatter.place(BoidManager.get_boid_position(boid))
    

func _ready():
    assert(boid_sim)
    boid_sim.boid_removed.connect(_on_boid_removed)
