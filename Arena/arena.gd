extends Node3D

@export var tile_mesh: Mesh
@export var tile_material: Material
@export var spawn_radius = 11
@export var tile_width = 3.0
@export_flags_3d_physics var tile_collision_layer: int = 1
@export_flags_3d_physics var tile_collision_mask: int = 1
@export_flags_3d_render var tile_render_layer: int = 1

var time: float = 0
var tiles: Array[AnimatableBody3D] = []
var multimesh_instance: MultiMeshInstance3D
var multimesh: MultiMesh

func _ready():
    multimesh_instance = MultiMeshInstance3D.new()
    multimesh_instance.material_override = tile_material
    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = tile_mesh
    
    var limit = spawn_radius * spawn_radius
    var count = 0
    for x in range(-spawn_radius, spawn_radius):
        for y in range(-spawn_radius, spawn_radius):
            if x * x + y * y > limit:
                continue
            count += 1
    
    multimesh.instance_count = count
    multimesh.visible_instance_count = count
    
    for x in range(-spawn_radius, spawn_radius):
        for y in range(-spawn_radius, spawn_radius):
            if x * x + y * y > limit:
                continue
            
            var tile = AnimatableBody3D.new()
            tile.sync_to_physics = false
            tile.collision_layer = tile_collision_layer
            tile.collision_mask = tile_collision_mask
            
            var shape = BoxShape3D.new()
            shape.size = Vector3(tile_width, tile_width, tile_width)
            var collision = CollisionShape3D.new()
            collision.shape = shape
            tile.add_child(collision)
            
            add_child(tile)
            tile.position.x = x * tile_width
            tile.position.z = y * tile_width
            tile.position.y = -tile_width / 2
            
            tiles.append(tile)
    
    multimesh_instance.multimesh = multimesh
    multimesh_instance.layers = tile_render_layer
    add_child(multimesh_instance)

func _rollback_tick(delta: float, _tick, _is_fresh):
    if not is_multiplayer_authority() and _is_fresh:
        return
    
    time += delta

func _process(_delta: float):
    var time_fac = clamp(time / 1200.0, 0, 1)
    var cdist_min = 4 * tile_width
    var cdist_max = spawn_radius * tile_width
    
    for i in tiles.size():
        var node = tiles[i]
        var cdist = Vector2(node.position.x, node.position.z).length()
        var dist_fac = min((cdist - cdist_min) / (cdist_max - cdist_min), 1)
        
        if dist_fac < 0:
            # Still need to update the multimesh for this tile at its default position
            var default_transform = Transform3D(Basis().scaled(Vector3.ONE * tile_width), node.position)
            multimesh.set_instance_transform(i, default_transform)
            continue
        
        var fall_fac = clamp(dist_fac - (1.0 - time_fac), 0, 1)
        
        var base_pos = -tile_width / 2
        node.position.y = base_pos - fall_fac * tile_width * 200.0
        
        # Sync mesh to the physics body's position, scaled by tile_width
        var xform = Transform3D(Basis().scaled(Vector3.ONE * tile_width), node.position)
        multimesh.set_instance_transform(i, xform)
