extends Node

var walk: Vector2
var jump: bool
var look: Quaternion
var shoot: bool

var _jump_was_pressed: bool
var _jump_reset: bool

@export var guide_action_walk:GUIDEAction
@export var guide_action_jump:GUIDEAction
@export var guide_action_shoot: GUIDEAction

@export var camera: Camera3D

func _ready() -> void:
    NetworkTime.after_tick.connect(_gather_always.unbind(2))
    NetworkTime.before_tick_loop.connect(_gather)
    guide_action_jump.just_triggered.connect(_jump_start)
    guide_action_jump.completed.connect(_jump_stop)

func _jump_start() -> void:
    _jump_was_pressed = true
    
func _jump_stop() -> void:
    _jump_reset = true

func _gather() -> void:
    if is_multiplayer_authority():
        walk = guide_action_walk.value_axis_2d
        look = camera.global_transform.basis.get_rotation_quaternion()
        
        jump = _jump_was_pressed
            
        if _jump_reset:
            _jump_was_pressed = false
            _jump_reset = false
    else:
        camera.global_transform.basis = Basis(look)

func _gather_always() -> void:
    pass
