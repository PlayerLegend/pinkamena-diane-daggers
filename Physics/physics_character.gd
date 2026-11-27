extends AnimatableBody3D
class_name PhysicsCharacter

var _vel_last: Vector3
@export var acceleration: Vector3
@export var velocity: Vector3
@export var ground_normal: Vector3 = Vector3.UP
@export var ground_angle_degrees: float = 10.0:
    set(value):
        ground_angle_degrees = value
        _ground_fac = cos(deg_to_rad(value))

var _ground_fac: float = cos(deg_to_rad(ground_angle_degrees))

func get_walk_basis(look_basis: Basis):
    return Basis.looking_at(-look_basis.z.slide(ground_normal), ground_normal)
    
func get_pitch_roll(look: Basis) -> Vector2:
    var n := ground_normal
    var pitch := asin(clampf((-look.z).dot(n), -1.0, 1.0))
    var right_n := look.x.dot(n)
    var up_n := look.y.dot(n)
    if absf(right_n) + absf(up_n) < 0.0001:
        return Vector2(pitch, 0.0)   # looking straight up/down: roll undefined
    return Vector2(pitch, atan2(right_n, up_n))
    
func check_onground() -> bool:
    var collision := move_and_collide(-ground_normal * 0.05, true)
    if not collision:
        return false
    
    var normal = collision.get_normal()
    
    if normal.dot(ground_normal) > _ground_fac:
        return true
    
    return false

func slide_to_position(target: Vector3) -> PhysicsCollision:
    var start_pos := global_position
    var motion := target - global_position
    var collisions: Array[KinematicCollision3D] = []

    for i in range(8):
        var collision := move_and_collide(motion)
        if not collision:
            break

        var normal := collision.get_normal()
        motion = collision.get_remainder()

        if normal.dot(ground_normal) > _ground_fac:
            motion = motion.slide(ground_normal)
            velocity = velocity.slide(ground_normal)
        else:
            motion = motion.slide(normal)
            velocity = velocity.slide(normal)

        collisions.append(collision)
        if motion.length_squared() < 0.001:
            break

    if collisions.is_empty():
        return null

    var result := PhysicsCollision.new()
    var normal_sum := Vector3.ZERO
    var best_ground_normal := ground_normal
    var best_ground_fac := _ground_fac

    for collision in collisions:
        var normal := collision.get_normal()
        result.normals.append(normal)
        normal_sum += normal

        var collider := collision.get_collider()
        if collider is Node3D:
            result.others.append(collider)

        var fac := normal.dot(ground_normal)
        if fac > best_ground_fac:
            best_ground_fac = fac
            best_ground_normal = normal

    result.normal_total = normal_sum / collisions.size()
    result.ground_normal = best_ground_normal
    result.motion = global_position - start_pos
    return result

func move_and_slide(delta: float) -> PhysicsCollision:
    var result = slide_to_position(position + velocity * delta)
    acceleration = (velocity - _vel_last) / delta
    _vel_last = velocity
    return result
