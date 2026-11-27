class_name PlayerLook
extends Node3D

@export var weapon: Node3D

@export var guide_action_look:GUIDEAction
@export var physics_character: PhysicsCharacter

var _roll_oscillator: DampedOscillatorFloat
var _jump_oscillator: DampedOscillatorFloat
var _mouse_scale: float = 1.0/300.0
var _accel_lerp: Vector3


func _get_roll() -> float:
    var forward := -global_basis.z
    var ground := physics_character.ground_normal
    var target := ground - forward * ground.dot(forward)   # strip pitch
    if target.length_squared() < 0.0001:
        return 0.0                        # looking straight up/down
    target = target.normalized()
    return atan2(global_basis.y.cross(target).dot(forward), global_basis.y.dot(target))
    
func _get_mouselook() -> Quaternion:
    var look_axis = -guide_action_look.value_axis_3d
    if look_axis.is_zero_approx():
        return Quaternion.IDENTITY
    var look_length = look_axis.length()
    print("Look axis ", look_axis)
    return Quaternion(look_axis / look_length, _mouse_scale * look_length)
    
func _get_accel_knock(delta: float) -> Quaternion:
    _jump_oscillator.velocity += delta * physics_character.acceleration.dot(physics_character.ground_normal)
    _jump_oscillator.delta = delta
    return Quaternion(Vector3.RIGHT, -0.25 * _jump_oscillator.position)

func _get_roll_fix(delta: float, pitch_roll: Vector2):
    var pitch := pitch_roll.x
    var limit = deg_to_rad(50)
    
    delta *= max(0, 1.0 - abs(pitch) / limit)
    
    _roll_oscillator.position = pitch_roll.y
    _roll_oscillator.delta = delta
    
    return Quaternion(Vector3.BACK, _roll_oscillator.velocity * delta)
    
func _process(delta: float) -> void:
    var pitch_roll := physics_character.get_pitch_roll(basis)
    _accel_lerp = _accel_lerp.lerp(physics_character.acceleration, delta * 10.0)
    
    weapon.quaternion *= _get_mouselook()
    weapon.quaternion *= _get_roll_fix(delta, pitch_roll)
    quaternion = weapon.quaternion * _get_accel_knock(delta)
    
func _on_set_mouse_scale(mscale: float, _area:float, _degrees: float):
    _mouse_scale = mscale
    
func _ready():
    _roll_oscillator = DampedOscillatorFloat.new(70)
    _jump_oscillator = DampedOscillatorFloat.new(70)
    var mouse_scale = Config.get_mouse_scale()
    Config.signal_set_mouse_scale.connect(_on_set_mouse_scale)
    if mouse_scale:
        _mouse_scale = mouse_scale
        
