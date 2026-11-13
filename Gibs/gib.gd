class_name Gib
extends MeshInstance3D

@export var velocity: Vector3
var time: float
@export var avelocity: Quaternion = Quaternion.IDENTITY

@export var static_mesh_manager: StaticMeshManager
@export var decal_canvas: DecalCanvas

func _process(delta: float) -> void:
    time += delta
    
    if time > 8.0:
        queue_free()
        return
        
    velocity += Vector3.DOWN * delta * 10.0
        
    var space_state = get_world_3d().direct_space_state
    var next = position + velocity * delta
    var query = PhysicsRayQueryParameters3D.create(position, next)
    var result = space_state.intersect_ray(query)
    if result:
        if decal_canvas:
            decal_canvas.add_splatter(position, randf_range(0.5,1.5))
            #decal_canvas = null
        var normal: Vector3 = result["normal"]
        var dot: float = velocity.dot(normal)
        if dot > -0.5:
            static_mesh_manager.make_static(self)
            queue_free()
            return
        else:
            velocity = velocity - 2.0 * dot * normal
            velocity *= 0.6
    position += velocity * delta
    var qstep := Quaternion.IDENTITY.slerp(avelocity, delta)
    quaternion = (qstep * quaternion).normalized()
