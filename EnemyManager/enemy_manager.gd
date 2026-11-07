class_name EnemyManager
extends Node3D
## Renders all enemies in the "Enemies" group through a single MultiMeshInstance3D.
## Enemies only need to be Node3Ds in the group; hide or remove their own visuals
## so they aren't drawn twice.

const INITIAL_CAPACITY := 64
@export var enemy_group_name := "boids"

## Half-size of the culling box (centered on the origin) so instances far from the
## origin aren't culled by a stale AABB.
const CULL_EXTENT := 1000.0

## The mesh drawn for every enemy.
@export var mesh: Mesh:
    set(value):
        mesh = value
        if multimesh_instance != null:
            multimesh_instance.multimesh.mesh = mesh

## Optional material applied to the whole MultiMeshInstance3D.
@export var material_override: Material:
    set(value):
        material_override = value
        if multimesh_instance != null:
            multimesh_instance.material_override = material_override

var multimesh_instance: MultiMeshInstance3D

func _ready() -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D  # must be set before instance_count
    mm.mesh = mesh
    mm.instance_count = INITIAL_CAPACITY
    mm.visible_instance_count = 0

    multimesh_instance = MultiMeshInstance3D.new()
    multimesh_instance.name = "EnemyInstances"
    multimesh_instance.multimesh = mm
    multimesh_instance.material_override = material_override
    multimesh_instance.custom_aabb = AABB(Vector3.ONE * -CULL_EXTENT, Vector3.ONE * CULL_EXTENT * 2.0)
    # Transforms below are global, so don't let this node's own transform apply on top.
    multimesh_instance.top_level = true
    add_child(multimesh_instance)


func _process(_delta: float) -> void:
    if multimesh_instance == null or mesh == null:
        return

    var mm := multimesh_instance.multimesh

    # Collect valid enemy transforms.
    var xforms: Array[Transform3D] = []
    for node in get_tree().get_nodes_in_group(enemy_group_name):
        var enemy := node as Node3D
        if enemy == null or enemy.is_queued_for_deletion() or not enemy.is_visible_in_tree():
            continue
        xforms.append(enemy.global_transform)

    var count := xforms.size()

    if count > mm.instance_count:
        mm.instance_count = nearest_po2(count)  # grow by doubling; resets visible count

    mm.visible_instance_count = count
    for i in count:
        mm.set_instance_transform(i, xforms[i])
