class_name SkullAfterimage
extends MeshInstance3D

var lifetime: float = 1.0 / 20.0
@export var afterimage_material: ShaderMaterial

func _process(delta: float):
    if lifetime <= 0.0:
        queue_free()
    else:
        lifetime -= delta

func set_mesh_1(want_mesh: Mesh):
    mesh = want_mesh
    assert(afterimage_material)
    material_override = afterimage_material
        
func _helper_apply_afterimage_material() -> void:
    if afterimage_material == null or mesh == null:
        return
    for i in mesh.get_surface_count():
        var mat := mesh.surface_get_material(i)
        #if mat is BaseMaterial3D:
            #afterimage_material.set_shader_parameter(&"albedo_texture", mat.albedo_texture)
        set_surface_override_material(i, afterimage_material)
