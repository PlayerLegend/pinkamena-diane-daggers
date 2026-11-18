class_name Centipede
extends Node3D

@export var tail: Node3D
@export var segment_scene: PackedScene
@export var segment_count := 25
@export var segment_spacing := 1.0

var _target_positions: PackedVector3Array
var _target_rotations: PackedVector4Array
var _followers: Array[Node3D]
var _head_index: int

func _ready() -> void:
    top_level = true
    _instance_segments()
    _followers.append(tail)
    tail.top_level = true
    
    _target_positions.resize(len(_followers) + 1)
    _target_rotations.resize(len(_followers) + 1)
    for i in len(_target_rotations):
        _target_rotations[i] = Vector4(0,0,0,1)
    
    _setup_multiplayer()

func _setup_multiplayer() -> void:
    var interp_props: Array[String] = [
        ":global_transform",
        ":_lerp_fac",
        #":_last_head_pos",
    ]
    
    var sync_props: Array[String] = [
        ":global_transform",
        ":_head_index",
        ":_target_positions",
        ":_target_rotations",
    ]
    
    for follower in _followers:
        interp_props.append(str(get_path_to(follower)) + ":global_transform")

    var rollback_synchronizer := RollbackSynchronizer.new()
    rollback_synchronizer.state_properties = sync_props
    rollback_synchronizer.root = self
    
    var tick_interpolator := TickInterpolator.new()
    tick_interpolator.properties = interp_props
    tick_interpolator.root = self
    
    add_child(rollback_synchronizer)
    add_child(tick_interpolator)
    
    rollback_synchronizer.process_settings()
    
func _instance_segments() -> void:
    for i in range(segment_count):
        var _segment: Node3D = segment_scene.instantiate()
        add_child(_segment)
        _followers.append(_segment)
        _segment.top_level = true
        _segment.offset = float(i) / float(segment_count)

func _q2v(q: Quaternion):
    return Vector4(q.x,q.y,q.z,q.w)

func _v2q(v: Vector4):
    return Quaternion(v.x,v.y,v.z,v.w)

func _lerp_index(i: int, fac: float):
    var prev = (i + _head_index) % len(_target_positions)
    var next = (prev + 1) % len(_target_positions)
    _followers[i].position = _target_positions[next].lerp(_target_positions[prev], fac)
    _followers[i].quaternion = _v2q(_target_rotations[next]).slerp(_v2q(_target_rotations[prev]), fac)
    
func _rollback_tick(_delta: float, _tick, _is_fresh):
    if is_multiplayer_authority() or not _is_fresh:
        _record_points()

    # Always run, even on non-authority fresh ticks, so clients build the body from synced state
    var head_distance := (_target_positions[_head_index] - position).length()
    var fac := head_distance / segment_spacing
    for i in len(_followers):
        _lerp_index(i, fac)
        
func _record_points() -> void:
    var last := _target_positions[_head_index]
    var to_head := position - last
    var dist := to_head.length()

    while dist >= segment_spacing:
        last += (to_head / dist) * segment_spacing   # exactly one spacing along the path
        _head_index = (_head_index + len(_target_positions) - 1) % len(_target_positions)
        _target_positions[_head_index] = last
        _target_rotations[_head_index] = _q2v(quaternion)
        to_head = position - last
        dist = to_head.length()
