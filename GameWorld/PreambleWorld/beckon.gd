extends Node3D
@onready var pinkie_pie: Node3D = $PinkiePie

func set_unshaded(mesh_instance: MeshInstance3D) -> void:
    var mesh := mesh_instance.mesh
    if mesh == null:
        return

    for i in mesh.get_surface_count():
        var mat := mesh_instance.get_active_material(i)
        if mat is BaseMaterial3D:
            var new_mat: BaseMaterial3D = mat.duplicate()
            new_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            mesh_instance.set_surface_override_material(i, new_mat)

func set_unshaded_recursive(node: Node) -> void:
    if node is MeshInstance3D:
        var mesh_instance := node as MeshInstance3D
        var mesh := mesh_instance.mesh

        if mesh != null:
            for i in mesh.get_surface_count():
                var mat := mesh_instance.get_active_material(i)
                if mat is BaseMaterial3D:
                    # Duplicate so shared materials on other meshes aren't affected
                    var new_mat := mat.duplicate() as BaseMaterial3D
                    new_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                    mesh_instance.set_surface_override_material(i, new_mat)

    for child in node.get_children():
        set_unshaded_recursive(child)
        
func _ready():
    set_unshaded_recursive(pinkie_pie)
    
