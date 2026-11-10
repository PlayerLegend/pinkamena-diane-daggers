@tool
extends EditorScenePostImport

## Import script for scenes containing a MeshInstance3D named "col".
##
## - Builds a StaticBody3D named "col" from the "col" mesh's trimesh collision,
##   removing the visible mesh.
## - Assigns `shader_material` to every MeshInstance3D surface, copying the
##   original albedo texture into the shader's `albedo_texture` uniform.

var shader_material: ShaderMaterial = preload("res://Materials/mat_skull.tres")

func _post_import(scene: Node) -> Object:
    _replace_col_with_static_body(scene)
    _apply_shader_materials(scene)
    return scene


# --- Collision replacement -------------------------------------------------

func _replace_col_with_static_body(scene: Node) -> void:
    var col := scene.find_child("col", true, false) as MeshInstance3D
    if col == null or col.mesh == null:
        push_error("col_import: no MeshInstance3D named 'col' with a mesh found.")
        return

    var parent := col.get_parent()
    var index := col.get_index()
    var xform := col.transform

    var body := _build_static_body(xform, col.mesh)

    # Remove the original first so the new node can take the name "col".
    parent.remove_child(col)
    col.free()

    body.name = "col"
    parent.add_child(body)
    parent.move_child(body, index)
    body.owner = scene
    for child in body.get_children():
        child.owner = scene


func _build_static_body(xform: Transform3D, mesh: Mesh) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.transform = xform
    body.collision_layer = 4

    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    shape.shape = mesh.create_trimesh_shape()
    body.add_child(shape)

    return body


# --- Shader material assignment -------------------------------------------

func _apply_shader_materials(scene: Node) -> void:
    if shader_material == null:
        return
    var mesh_instances := scene.find_children("*", "MeshInstance3D", true, false)
    for mi in mesh_instances:
        _apply_shader_to_mesh_instance(mi)


func _apply_shader_to_mesh_instance(mi: MeshInstance3D) -> void:
    if mi.mesh == null:
        return

    for i in mi.mesh.get_surface_count():
        var original_mat := mi.mesh.surface_get_material(i)
        if original_mat == null:
            continue

        var new_mat := _make_shader_material(original_mat)
        if new_mat == null:
            continue

        mi.mesh.surface_set_material(i, new_mat)


func _make_shader_material(original_mat: Material) -> ShaderMaterial:
    # Duplicate so surfaces/instances don't share a single resource.
    var new_mat := shader_material.duplicate() as ShaderMaterial
    var albedo_tex := _extract_albedo_texture(original_mat)
    if albedo_tex != null:
        new_mat.set_shader_parameter("albedo_texture", albedo_tex)
    return new_mat


func _extract_albedo_texture(mat: Material) -> Texture2D:
    if mat is BaseMaterial3D:
        return (mat as BaseMaterial3D).albedo_texture
    return null
