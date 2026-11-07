extends Boid

func _ready() -> void:
    add_to_group("skull1")

func _boid_collision(collision: SlideCollision3D):
    if not collision:
        return
        
    for other in collision.others:
        if other is Projectile:
    
            queue_free()
            other.queue_free()
