class_name StaticMeshManager
extends Node3D
## Collapses MeshInstance3D nodes into MultiMeshInstance3D batches.
##
## Call make_static(mesh_instance) and the mesh, global transform, materials,
## shadow mode and render layers are mirrored as an instance in a MultiMesh.
## Meshes that share the same mesh/material/settings share one MultiMeshInstance3D.

class Batch:
    var mmi: MultiMeshInstance3D
    var transforms: Array[Transform3D] = []

var _batches: Dictionary = {}   # String key -> Batch
var _dirty: Dictionary = {}     # Batch -> true
var _flush_queued := false


func make_static(mi: MeshInstance3D) -> void:
    if mi == null or mi.mesh == null:
        push_warning("StaticMeshManager.make_static: MeshInstance3D has no mesh.")
        return

    var key := _make_key(mi)
    var batch: Batch = _batches.get(key)
    if batch == null:
        batch = _create_batch(mi)
        _batches[key] = batch

    # Express the source's world transform relative to this node, since the
    # MultiMeshInstance3D children live under it.
    var world_xform: Transform3D = mi.global_transform if mi.is_inside_tree() else mi.transform
    var local_xform: Transform3D = global_transform.affine_inverse() * world_xform
    batch.transforms.append(local_xform)

    _dirty[batch] = true
    _queue_flush()


## Remove every batched instance.
func clear_all() -> void:
    for batch: Batch in _batches.values():
        batch.mmi.queue_free()
    _batches.clear()
    _dirty.clear()


func _create_batch(mi: MeshInstance3D) -> Batch:
    var batch := Batch.new()

    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = _resolve_mesh(mi)

    var mmi := MultiMeshInstance3D.new()
    mmi.name = "Batch_%d" % _batches.size()
    mmi.multimesh = mm
    mmi.material_override = mi.material_override
    mmi.cast_shadow = mi.cast_shadow
    mmi.layers = mi.layers
    mmi.gi_mode = mi.gi_mode
    add_child(mmi)

    batch.mmi = mmi
    return batch


## If the node has per-surface override materials, bake them into a copy of the
## mesh (MultiMeshInstance3D only supports a single material_override).
func _resolve_mesh(mi: MeshInstance3D) -> Mesh:
    var has_surface_override := false
    for i in mi.get_surface_override_material_count():
        if mi.get_surface_override_material(i) != null:
            has_surface_override = true
            break
    if not has_surface_override:
        return mi.mesh

    var baked := ArrayMesh.new()
    for s in mi.mesh.get_surface_count():
        baked.add_surface_from_arrays(
            mi.mesh.surface_get_primitive_type(s),
            mi.mesh.surface_get_arrays(s)
        )
        baked.surface_set_material(s, mi.get_active_material(s))
    return baked


func _make_key(mi: MeshInstance3D) -> String:
    var parts := PackedStringArray()
    parts.append(str(mi.mesh.get_instance_id()))
    parts.append(str(mi.material_override.get_instance_id()) if mi.material_override else "-")
    for i in mi.get_surface_override_material_count():
        var m := mi.get_surface_override_material(i)
        parts.append(str(m.get_instance_id()) if m else "-")
    parts.append(str(mi.cast_shadow))
    parts.append(str(mi.layers))
    parts.append(str(mi.gi_mode))
    return "|".join(parts)


func _queue_flush() -> void:
    if _flush_queued:
        return
    _flush_queued = true
    _flush.call_deferred()


func _flush() -> void:
    _flush_queued = false
    for batch: Batch in _dirty.keys():
        var mm := batch.mmi.multimesh
        # Changing instance_count resets the buffer, so rewrite all transforms.
        mm.instance_count = batch.transforms.size()
        for i in batch.transforms.size():
            mm.set_instance_transform(i, batch.transforms[i])
    _dirty.clear()
