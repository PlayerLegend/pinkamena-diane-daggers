class_name Centipede
extends Node3D

@export var head: Node3D
@export var tail: Node3D
@export var segment: PackedScene
@export var count := 25
@export var spacing := 0.5
@export var speed := 4.0

var _target_positions: PackedVector3Array
var _target_rotations: PackedVector4Array
var _followers: Array[Node3D]
var _last_head_pos: Vector3
var _lerp_fac: float

func _ready() -> void:
    _instance_segments()
    _followers.append(tail)
    
    _target_positions.resize(len(_followers) + 1)
    _target_rotations.resize(len(_followers) + 1)
    
func _instance_segments() -> void:
    for i in range(count):
        var _segment: PathFollow3D = segment.instantiate()
        add_child(_segment)
        _followers.append(_segment)

func _q2v(q: Quaternion):
    return Vector4(q.x,q.y,q.z,q.w)

func _v2q(v: Vector4):
    return Quaternion(v.x,v.y,v.z,v.w)

func _physics_process(delta: float):
    _lerp_fac += (head.position - _last_head_pos).length() / (spacing)
    _last_head_pos = head.position
    _lerp_fac = min(1.0, _lerp_fac)    
    if (_target_positions[0] - head.position).length() > spacing:
        _target_positions.insert(0, head.position)
        _target_rotations.insert(0, _q2v(head.quaternion))
        _target_positions.resize(len(_followers) + 2)
        _target_rotations.resize(len(_followers) + 2)
        _lerp_fac = 0
        
    for i in range(len(_followers)):
        #print("Len positions ", len(_target_positions), " vs ", len(_followers) + 2)
        print("Fac ", _lerp_fac)
        _followers[i].position = _target_positions[i+1].lerp(_target_positions[i], _lerp_fac)
        _followers[i].quaternion = _v2q(_target_rotations[i+1]).slerp(_v2q(_target_rotations[i]), _lerp_fac)
