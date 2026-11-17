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
var _target_distances: PackedFloat32Array

var _followers: Array[Node3D]
var _follower_target: PackedInt32Array

func _ready() -> void:
    _followers.append(tail)
    _instance_segments()
    _followers.append(head)
    
func _instance_segments() -> void:
    for i in range(count):
        var _segment: PathFollow3D = segment.instantiate()
        add_child(_segment)
        _followers.append(_segment)
        _follower_target.append(0)

var target: Transform3D:
    set(value):
        pass

func _physics_process(delta: float):
    pass
