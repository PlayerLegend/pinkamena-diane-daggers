@tool
class_name BoidType
extends Resource
## Settings for one kind of boid. Save instances as .tres files and assign them to
## BoidManager.boid_types. Each type gets its own MultiMesh, capacity and behaviour.
##
## Alignment and cohesion only happen between boids of the SAME type; separation applies to boids of every type.

## Unique name for this type. Used by add_boid_by_name().
@export var type_name := &"boid"

@export_group("Population")
## Mesh per boid, should point along -Z. Falls back to a small box.
@export var mesh: Mesh:
    set(value):
        if mesh != null and mesh.changed.is_connected(_sync_materials):
            mesh.changed.disconnect(_sync_materials)
        mesh = value
        if mesh != null:
            mesh.changed.connect(_sync_materials)
        _sync_materials()
## One slot per mesh surface (resized automatically when the mesh changes).
## Null entries keep the mesh's own material.
@export var material_overrides: Array[Material] = []
@export var max_boids := 1000  ## Capacity of this type. add_boid() fails once reached.

@export_group("Health")
@export var max_health := 1  ## Health a boid starts with when spawned

@export_group("Collision")
## Radius of the boid's collision sphere. Used by raycast() and get_boids_in_area().
@export var collision_radius := 0.25

@export_group("Speed")
@export var max_speed := 16.0
@export var min_speed := 4.5
@export var max_force := 12.0  ## Max steering acceleration

@export_group("Flocking")
@export var separation_weight := 0.8
@export var alignment_weight := 0.1
@export var cohesion_weight := 0.2
@export var separation_radius := 1.0  ## Same-type neighbors closer than this push away
@export var neighbor_radius := 3.0  ## Perception radius (the manager's grid cell size is the largest of these)
@export var max_neighbors := 24  ## Early-out cap per boid in dense clumps

@export_group("Avoidance")
@export var projectile_group := &"projectiles"  ## Nodes in this group push boids away
@export var projectile_avoidance_weight := 1.0
@export var projectile_avoidance_distance := 3.0

@export_group("Bounds")
@export var bounds_weight := 1.1  ## Bounds shape itself lives on the BoidManager

@export_group("Floor")
@export var use_floor := true  ## Enable the floor
@export var floor_height := 0.0  ## World-space Y that boids can never go below
@export var floor_margin := 0.5  ## Boids start steering upward within this distance above the floor
@export var floor_weight := 1.5  ## Strength of the upward steering near the floor

@export_group("Visuals")
@export var turn_speed := 4.0  ## Smoothing for facing direction

@export_group("Targets")
@export var target_group := &"players"  ## Boids chase the nearest node in this group
@export var target_weight := 0.3


func _sync_materials() -> void:
    if mesh == null:
        return
    var n := mesh.get_surface_count()
    if material_overrides.size() != n:
        material_overrides.resize(n)  # keeps existing entries, pads with null, trims extras
        notify_property_list_changed()
