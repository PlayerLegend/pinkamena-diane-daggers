class_name Centipede
extends Path3D

@export var head: PathFollow3D
@export var tail: PathFollow3D
@export var segment: PackedScene
@export var count := 25
@export var spacing := 0.5
@export var speed := 4.0

func _ready() -> void:
    curve.clear_points()
    curve.add_point(Vector3.ZERO)
    curve.add_point(Vector3.RIGHT * count * spacing)
    _instance_segments()
    
func _instance_segments() -> void:
    var _segment_offset: float = spacing
    tail.progress = 0
    for i in range(count):
        var _segment: PathFollow3D = segment.instantiate()
        _segment.progress = _segment_offset
        add_child(_segment)
        _segment_offset += spacing
    head.progress = _segment_offset + spacing

func _get_point_progress(idx: int) -> float:
    return curve.get_closest_offset(curve.get_point_position(idx))

func _add_point(point_transform: Transform3D):
    var new_pos := point_transform.origin
    var new_in := point_transform.basis.z * speed
    var new_out := -new_in
    var new_tilt := point_transform.basis.get_euler().z
    curve.add_point(new_pos, new_in, new_out)
    if not is_zero_approx(new_tilt):
        curve.set_point_tilt(curve.point_count - 1, new_tilt)
    

func _trim_target_end() -> void:
    
    var head_xform := head.transform
    
    while curve.point_count > 1:
        var i = curve.point_count - 1
        if _get_point_progress(i - 1) < head.progress:
            break
            
        curve.remove_point(i)
    
    _add_point(head_xform) 

func _trim_target_begin() -> void:
    if curve.point_count < 3:
        return
        
    if _get_point_progress(2) >= tail.progress:
        return
    
    curve.remove_point(0)
    #var remove_progress = _get_point_progress(1)
    #for child in get_children():
        #if child is PathFollow3D:
            #child.progress -= remove_progress
    

var target: Transform3D:
    set(value):
        _trim_target_end()
        _add_point(value)
        target = value

func _physics_process(delta: float):
    #_trim_target_begin()
    for child in get_children():
        if child is PathFollow3D:
            child.progress += delta * speed
