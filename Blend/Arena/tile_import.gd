
@tool
extends EditorScenePostImport
## Replaces the object named "col" with a StaticBody3D whose collision shape
## is built from the col mesh. The visible mesh is removed.
 
 
func _post_import(scene: Node) -> Object:
    var col := scene.find_child("col", true, false) as MeshInstance3D
    if col == null or col.mesh == null:
        push_error("col_import: no MeshInstance3D named 'col' with a mesh found.")
        return scene
 
    var parent := col.get_parent()
    var index := col.get_index()
    var xform := col.transform
 
    var shape := CollisionShape3D.new()
    shape.name = "CollisionShape3D"
    shape.shape = col.mesh.create_trimesh_shape()
 
    var body := StaticBody3D.new()
    body.transform = xform
    body.collision_layer = 4
    body.add_child(shape)
 
    # Remove the original first so the new node can take the name "col".
    parent.remove_child(col)
    col.free()
 
    body.name = "col"
    parent.add_child(body)
    parent.move_child(body, index)
    body.owner = scene
    shape.owner = scene
 
    return scene
