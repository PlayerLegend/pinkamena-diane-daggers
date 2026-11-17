class_name Centipede
extends Node3D

@export var head: Node3D
@export var tail: Node3D
@export var segment_scene: PackedScene
@export var segment_count := 25
@export var segment_spacing := 0.5

var _target_positions: PackedVector3Array
var _target_rotations: PackedVector4Array
var _last_head_pos: Vector3
var _lerp_fac: float
var _followers: Array[Node3D]
var _head_index: int

func _ready() -> void:
    _instance_segments()
    _followers.append(tail)
    
    _target_positions.resize(len(_followers) + 1)
    _target_rotations.resize(len(_followers) + 1)
    
func _instance_segments() -> void:
    for i in range(segment_count):
        var _segment: PathFollow3D = segment_scene.instantiate()
        add_child(_segment)
        _followers.append(_segment)

func _q2v(q: Quaternion):
    return Vector4(q.x,q.y,q.z,q.w)

func _v2q(v: Vector4):
    return Quaternion(v.x,v.y,v.z,v.w)

func _lerp_index(i: int):
    var prev = (i + _head_index) % len(_target_positions)
    var next = (prev + 1) % len(_target_positions)
    _followers[i].position = _target_positions[next].lerp(_target_positions[prev], _lerp_fac)
    _followers[i].quaternion = _v2q(_target_rotations[next]).slerp(_v2q(_target_rotations[prev]), _lerp_fac)
    

func _physics_process(_delta: float):
    _lerp_fac += (head.position - _last_head_pos).length() / (segment_spacing)
    _last_head_pos = head.position
    _lerp_fac = min(1.0, _lerp_fac)    
    if (_target_positions[_head_index] - head.position).length() > segment_spacing:
        _head_index = (_head_index + len(_target_positions) - 1) % len(_target_positions)
        _target_positions[_head_index] = head.position
        _target_rotations[_head_index] = _q2v(head.quaternion)
        _lerp_fac = 0
        
    for i in range(len(_followers)):
        _lerp_index(i)
