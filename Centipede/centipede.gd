class_name Centipede
extends Node3D

@export var head: Node3D
@export var segment_scene: PackedScene
@export var segment_count := 25
@export var segment_spacing := 0.25
@export var follow_speed := 4.0

var _path: Array[Transform3D] = []
var _head_distance := 0.0
var _segments: Array[Node3D] = []

var target_transform := Transform3D.IDENTITY:
    set(value):
        target_transform = value
        _extend_path(Transform3D(value.basis.orthonormalized(), value.origin))


func _ready() -> void:
    assert(head)
    for i in segment_count:
        var segment: CentipedeSegment = segment_scene.instantiate()
        segment.setup_wave(4, segment_count, segment_spacing, follow_speed)
        segment.top_level = true
        add_child(segment)
        
        _segments.append(segment)
    if _path.is_empty():
        target_transform = head.global_transform


func _process(delta: float) -> void:
    _head_distance = maxf(_head_distance - follow_speed * delta, 0.0)
    var half_spacing := segment_spacing * 0.5

    var head_sample := _sample(_head_distance)
    var head_direction := _sample(_head_distance - half_spacing).origin - _sample(_head_distance + half_spacing).origin
    var head_basis := head_sample.basis
    if head_direction.length_squared() > 0.000001:
        head_direction = head_direction.normalized()
        var up := head_sample.basis.y
        if absf(head_direction.dot(up)) > 0.999:
            up = head_sample.basis.x
        head_basis = Basis.looking_at(head_direction, up)
    head.global_transform = Transform3D(head_basis, head_sample.origin)

    for i in _segments.size():
        var distance := _head_distance + (i + 1) * segment_spacing
        var here := _sample(distance)
        var direction := _sample(distance - half_spacing).origin - _sample(distance + half_spacing).origin
        var segment := _segments[i]
        var new_basis := segment.global_basis.orthonormalized()
        if direction.length_squared() > 0.000001:
            direction = direction.normalized()
            var up := here.basis.y
            if absf(direction.dot(up)) > 0.999:
                up = here.basis.x
            new_basis = Basis.looking_at(direction, up)
        segment.global_transform = Transform3D(new_basis, here.origin)


func _extend_path(new_transform: Transform3D) -> void:
    var step := segment_spacing * 0.25
    if _path.is_empty():
        for i in segment_count * 4 + 4:
            _path.append(Transform3D(new_transform.basis, new_transform.origin + new_transform.basis.z * step * i))
        _head_distance = 0.0
        return
    if new_transform.origin.distance_to(_path[1].origin) >= step:
        _head_distance += new_transform.origin.distance_to(_path[0].origin)
        _path.push_front(new_transform)
    else:
        _head_distance += new_transform.origin.distance_to(_path[1].origin) - _path[0].origin.distance_to(_path[1].origin)
        _path[0] = new_transform
    _head_distance = maxf(_head_distance, 0.0)
    _trim(step)


func _trim(step: float) -> void:
    var needed_length := _head_distance + (segment_count + 1) * segment_spacing + step
    var travelled := 0.0
    for i in _path.size() - 1:
        travelled += _path[i].origin.distance_to(_path[i + 1].origin)
        if travelled > needed_length:
            _path.resize(i + 2)
            return


func _sample(distance: float) -> Transform3D:
    distance = maxf(distance, 0.0)
    var previous := _path[0]
    for i in range(1, _path.size()):
        var current := _path[i]
        var segment_length := previous.origin.distance_to(current.origin)
        if distance <= segment_length:
            return previous.interpolate_with(current, distance / segment_length) if segment_length > 0.0 else current
        distance -= segment_length
        previous = current
    return previous
