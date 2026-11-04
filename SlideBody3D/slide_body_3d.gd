extends AnimatableBody3D

class_name SlideBody3D

var velocity: Vector3

func move_and_slide(delta: float) -> SlideCollision3D:
    var start_pos = global_position
    var motion: Vector3 = velocity * delta
    
    var collisions: Array[KinematicCollision3D]
    
    for i in range(4):
        var collision = move_and_collide(motion)
        
        if not collision:
            break
            
        collisions.append(collision)
        
        var normal = collision.get_normal()
        motion = motion.slide(normal)
        velocity = velocity.slide(normal)
    
    var result := SlideCollision3D.new()
    
    if not collisions.is_empty():
        result.did_hit = true
        var normal_sum := Vector3(0,0,0)
    
        for collision in collisions:
            var normal = collision.get_normal()
            result.normals.append(normal)
            normal_sum += normal
            var collider = collision.get_collider()
            if collider is Node3D:
                result.others.append(collider)
        
        result.normal_total = normal_sum / collisions.size()
    
    result.motion = global_position - start_pos
    
    return result
