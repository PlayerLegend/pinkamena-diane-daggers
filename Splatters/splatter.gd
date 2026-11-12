class_name Splatter
extends Decal

@export var splatter_choices: Array[CompressedTexture2D]
@export_flags_3d_physics var floor_collision_mask: int = 1

func place(point: Vector3, scale_val: float = 1.0):
    if splatter_choices.size() > 0:
        texture_albedo = splatter_choices.pick_random()
    position = point
    #rotation.x = randf_range(0,PI)
    rotation.y = randf_range(0,PI)
    #rotation.z = randf_range(0,PI)
    
    size.x = randf_range(0.5,1.0) * scale_val * 10
    size.z = randf_range(0.5,1.0) * scale_val * 10
    _drop_to_ground()
    print("Placed splatter at ", position)


func _drop_to_ground() -> void:
    var ground_position := _get_ground_position()
    if is_nan(ground_position):
        push_warning("Splatter: no floor found below %s" % global_position)
        return

    global_position.y = ground_position
    sorting_offset = randf_range(0,1)

func _get_ground_position() -> float:
    var space_state := get_world_3d().direct_space_state
    var from := global_position
    var to := from - Vector3.UP * 1000.0

    var query := PhysicsRayQueryParameters3D.create(from, to, floor_collision_mask)

    var hit := space_state.intersect_ray(query)
    if hit.is_empty():
        print("Splatter missed ground")
        return NAN
    print("Splatter ground at ", hit["collider"])
    return hit.position.y
