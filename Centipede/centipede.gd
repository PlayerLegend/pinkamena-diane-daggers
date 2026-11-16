class_name Centipede
extends Node3D

@export var head: Node3D
@export var segment_scene: PackedScene
@export var segment_count := 25
@export var segment_spacing := 0.5
@export var follow_speed := 4.0

var _path: Array[Transform3D] = []
var _head_dist := 0.0
var _segments: Array[Node3D] = []

var target_transform := Transform3D.IDENTITY:
    set(value):
        target_transform = value
        _extend_path(Transform3D(value.basis.orthonormalized(), value.origin))


func _ready() -> void:
    assert(head)
    for i in segment_count:
        var s := segment_scene.instantiate() as Node3D
        s.top_level = true
        add_child(s)
        _segments.append(s)
    if _path.is_empty():
        target_transform = head.global_transform


func _process(delta: float) -> void:
    _head_dist = maxf(_head_dist - follow_speed * delta, 0.0)
    var half := segment_spacing * 0.5

    var h := _sample(_head_dist)
    var h_dir := _sample(_head_dist - half).origin - _sample(_head_dist + half).origin
    var h_basis := h.basis
    if h_dir.length_squared() > 0.000001:
        h_dir = h_dir.normalized()
        var up := h.basis.y
        if absf(h_dir.dot(up)) > 0.999:
            up = h.basis.x
        h_basis = Basis.looking_at(h_dir, up)
    head.global_transform = Transform3D(h_basis, h.origin)

    for i in _segments.size():
        var d := _head_dist + (i + 1) * segment_spacing
        var here := _sample(d)
        var dir := _sample(d - half).origin - _sample(d + half).origin
        var s := _segments[i]
        var new_basis := s.global_basis.orthonormalized()
        if dir.length_squared() > 0.000001:
            dir = dir.normalized()
            var up := here.basis.y
            if absf(dir.dot(up)) > 0.999:
                up = here.basis.x
            new_basis = Basis.looking_at(dir, up)
        s.global_transform = Transform3D(new_basis, here.origin)


func _extend_path(t: Transform3D) -> void:
    var step := segment_spacing * 0.25
    if _path.is_empty():
        for i in segment_count * 4 + 4:
            _path.append(Transform3D(t.basis, t.origin + t.basis.z * step * i))
        _head_dist = 0.0
        return
    if t.origin.distance_to(_path[1].origin) >= step:
        _head_dist += t.origin.distance_to(_path[0].origin)
        _path.push_front(t)
    else:
        _head_dist += t.origin.distance_to(_path[1].origin) - _path[0].origin.distance_to(_path[1].origin)
        _path[0] = t
    _head_dist = maxf(_head_dist, 0.0)
    _trim(step)


func _trim(step: float) -> void:
    var needed := _head_dist + (segment_count + 1) * segment_spacing + step
    var travelled := 0.0
    for i in _path.size() - 1:
        travelled += _path[i].origin.distance_to(_path[i + 1].origin)
        if travelled > needed:
            _path.resize(i + 2)
            return


func _sample(dist: float) -> Transform3D:
    dist = maxf(dist, 0.0)
    var prev := _path[0]
    for i in range(1, _path.size()):
        var p := _path[i]
        var l := prev.origin.distance_to(p.origin)
        if dist <= l:
            return prev.interpolate_with(p, dist / l) if l > 0.0 else p
        dist -= l
        prev = p
    return prev
