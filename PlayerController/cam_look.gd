extends Node3D

@export var guide_action_look:GUIDEAction

@export var physics_character: PhysicsCharacter

var _roll_velocity: float
var _mouse_scale: float = 1.0/300.0

#var enable_roll: bool = true

func set_mouse_scale(mscale: float):
    _mouse_scale = mscale
    
func _get_accel_angle():
    if not physics_character.acceleration:
        return 0
        
    return -0.01 * basis.x.dot(physics_character.acceleration)

func _get_roll() -> float:
    var forward = -basis.z
    var g_up_flat = (physics_character.ground_normal - forward * forward.dot(physics_character.ground_normal)).normalized()
    return -basis.y.signed_angle_to(g_up_flat, forward) + _get_accel_angle()
    
func _process(delta: float) -> void:
    
    # Look
    
    var look_axis_append = guide_action_look.value_axis_3d
    
    
    if look_axis_append:
        var look_speed = _mouse_scale * look_axis_append.length()
        quaternion *= Quaternion(-look_axis_append.normalized(), look_speed)
        
    # Roll
    
    var abs_pitch = 2.0 * acos(abs(-physics_character.ground_normal.dot(-basis.z))) / PI
    
    var hfrac_clamp = 0.4
    var horizontal_frac = clamp(abs_pitch - hfrac_clamp, 0, 1) * (1 + hfrac_clamp)
    
    var roll = _get_roll()
    
    #if enable_roll:
    _roll_velocity += 10 * roll * delta * horizontal_frac
        
    # damped harmonic oscillator
    var stiffness = 1.0
    #var damping = 2 * sqrt(stiffness) # critically damped
    #damping *= 2
    var damping = PI
    var accel = -stiffness * rotation.z - damping * _roll_velocity
    #var vfac = min(abs(rotation.z), abs(_roll_velocity))
    #var friction = delta * _roll_velocity * vfac / (0.01 + vfac)
    
    _roll_velocity += accel * delta
    
    rotation.z += _roll_velocity * delta
    print("Roll ",rad_to_deg( rotation.z))
    
func _on_set_mouse_scale(mscale: float, _area:float, _degrees: float):
    _mouse_scale = mscale
    
func _ready():
    var mouse_scale = Config.get_mouse_scale()
    Config.signal_set_mouse_scale.connect(_on_set_mouse_scale)
    if mouse_scale:
        _mouse_scale = mouse_scale
        
