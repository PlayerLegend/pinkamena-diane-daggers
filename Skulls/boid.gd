extends SlideBody3D

class_name Boid

@export_group("Speed")
@export var max_speed := 16.0
@export var min_speed := 3.5
@export var max_force := 12.0  ## Max steering acceleration

@export_group("Flocking")

@export var separation_weight := 0.3
@export var alignment_weight := 0.1
@export var cohesion_weight := 0.2
@export var separation_radius := 1.0  ## Neighbors closer than this push away
 
@export_group("Bounds")
@export var bounds_center := Vector3.ZERO
@export var bounds_radius := 40
@export var bounds_weight := 1.1
 
@export_group("Visuals")
@export var turn_speed := 4.0  ## Smoothing for facing direction
 
@export_group("Target")
## Direction the flock drifts toward. Zero vector disables it.
@export var target_direction := Vector3.ZERO:
    set(value):
        target_direction = value.normalized()
@export var target_weight := 0.3

@onready var nearby_area: Area3D = $NearbyArea
 
func _ready() -> void:
    # Random initial heading
    var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)).normalized()
    velocity = dir * randf_range(min_speed, max_speed)
    
func _physics_process(delta: float) -> void:
    var steering := _flocking_steering(nearby_area.get_overlapping_bodies())
    steering += _stay_in_bounds() * bounds_weight
    steering += _steer_towards(target_direction) * target_weight

    velocity += steering.limit_length(max_force) * delta
 
    # Keep speed within [min_speed, max_speed]
    var speed := velocity.length()
    if speed > 0.001:
        velocity = velocity / speed * clampf(speed, min_speed, max_speed)
 
    move_and_slide(delta)
    _face_velocity(delta)
 
 
## Reynolds steering: desired velocity minus current velocity.
func _steer_towards(direction: Vector3) -> Vector3:
    if direction.is_zero_approx():
        return Vector3.ZERO
    return direction.normalized() * max_speed - velocity
 
 
## Single pass over neighbors computing all three flocking rules.
func _flocking_steering(bodies: Array[Node3D]) -> Vector3:
    var separation_push := Vector3.ZERO
    var velocity_sum := Vector3.ZERO
    var position_sum := Vector3.ZERO
    var count := 0
    var sep_radius_sq := separation_radius * separation_radius
 
    for body in bodies:
        if body == self:
            continue
        var other := body as Boid
        if other == null:
            continue
 
        count += 1
        velocity_sum += other.velocity
        position_sum += other.global_position
 
        var offset := global_position - other.global_position
        var dist_sq := offset.length_squared()
        if dist_sq > 0.0001 and dist_sq < sep_radius_sq:
            separation_push += offset / dist_sq  # stronger when closer
 
    if count == 0:
        return Vector3.ZERO
 
    var alignment := _steer_towards(velocity_sum / count)
    var cohesion := _steer_towards(position_sum / count - global_position)
    var separation := _steer_towards(separation_push)
 
    return separation * separation_weight \
        + alignment * alignment_weight \
        + cohesion * cohesion_weight
 
 
func _stay_in_bounds() -> Vector3:
    var to_center := bounds_center - global_position
    var dist := to_center.length()
    if dist <= bounds_radius:
        return Vector3.ZERO
    # Pull grows the farther outside the bounds the boid is
    var strength := (dist - bounds_radius) / bounds_radius
    return _steer_towards(to_center) * (1.0 + strength)
 
 
func _face_velocity(delta: float) -> void:
    if velocity.length_squared() < 0.01:
        return
    var forward := velocity.normalized()
    # Avoid degenerate basis when moving straight up/down
    var up := Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
    var target := Basis.looking_at(forward, up)  # -Z faces velocity
    global_basis = global_basis.slerp(target, clampf(turn_speed * delta, 0.0, 1.0)).orthonormalized()
