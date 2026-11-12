extends Node3D

@export var guide_action_look:GUIDEAction

var _roll_velocity: float
var _mouse_scale: float = 1.0/300.0

var _gravity: Vector3 = -Vector3.UP

var _accel: Vector3

var enable_roll: bool = true

func set_gravity(gval: Vector3):
    _gravity = gval

func set_accel(aval: Vector3):
    _accel = aval

func set_mouse_scale(mscale: float):
    _mouse_scale = mscale
    
func _get_accel_angle():
    if not _accel:
        return 0
        
    return -0.4 * basis.x.dot(_accel)

func _get_roll() -> float:
    var forward = -basis.z
    var g_up = -_gravity
    var g_up_flat = (g_up - forward * forward.dot(g_up)).normalized()
    return -basis.y.signed_angle_to(g_up_flat, forward) + _get_accel_angle()
    
func _process(delta: float) -> void:
    # Look
    
    var look_axis_append = guide_action_look.value_axis_3d
    
    var look_speed = _mouse_scale * look_axis_append.length()
    
    if look_axis_append:
        quaternion *= Quaternion(-look_axis_append.normalized(), look_speed)
        
    # Roll
    
    var abs_pitch = 2.0 * acos(abs(_gravity.dot(-basis.z))) / PI
    
    var hfrac_clamp = 0.4
    var horizontal_frac = clamp(abs_pitch - hfrac_clamp, 0, 1) * (1 + hfrac_clamp)
    
    var roll = _get_roll()
    
    if enable_roll:
        _roll_velocity += 0.3 * roll * delta * horizontal_frac

    var friction = delta * _roll_velocity / (0.05 + abs(_roll_velocity))
    
    _roll_velocity -= friction
    
    rotation.z += _roll_velocity
    
func _on_set_mouse_scale(mscale: float, _area:float, _degrees: float):
    _mouse_scale = mscale
    
func _ready():
    var mouse_scale = Config.get_mouse_scale()
    Config.signal_set_mouse_scale.connect(_on_set_mouse_scale)
    if mouse_scale:
        _mouse_scale = mouse_scale
        
