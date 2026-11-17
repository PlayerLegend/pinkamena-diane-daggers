class_name Centipede
extends Node3D

@export var head: Node3D
@export var tail: Node3D
@export var segment: PackedScene
@export var count := 25
@export var spacing := 0.5
@export var speed := 4.0

# Trail of targets, oldest first, all in global space.
var _target_positions: PackedVector3Array
var _target_rotations: PackedVector4Array   # quaternion packed as (x, y, z, w)
var _target_distances: PackedFloat32Array    # distance from the previous target to this one (0 for the first)

# Order is tail -> segments -> head. The head is always the last element.
var _followers: Array[Node3D]
var _follower_target: PackedInt32Array       # previous target index; +1 is the next target


func _ready() -> void:
    _followers.append(tail)
    _instance_segments()
    _followers.append(head)
    _seed_trail()


func _instance_segments() -> void:
    for segment_index in range(count):
        var new_segment: Node3D = segment.instantiate()
        add_child(new_segment)
        _followers.append(new_segment)


# Lay the followers out in a straight line behind the head, one target per
# follower, so every follower starts exactly on its own target.
func _seed_trail() -> void:
    var follower_count := _followers.size()
    var head_transform := head.global_transform
    var backward := head_transform.basis.z  # Godot forward is -Z, so +Z is behind

    _follower_target.resize(follower_count)
    for follower_index in range(follower_count):
        var slot_transform := head_transform
        slot_transform.origin += backward * spacing * (follower_count - 1 - follower_index)
        _append_target(slot_transform)
        _followers[follower_index].global_transform = slot_transform
        _follower_target[follower_index] = follower_index


var target: Transform3D:
    set(value):
        var head_index := _followers.size() - 1
        var next_target_index := _follower_target[head_index] + 1

        # The head's next target becomes its current transform. Anything the
        # head had queued past that point is discarded, then the new target
        # goes after it.
        _target_positions.resize(next_target_index)
        _target_rotations.resize(next_target_index)
        _target_distances.resize(next_target_index)
        _append_target(head.global_transform)
        _append_target(value)
        target = value
        print("Point count ", len(_target_positions))


func _append_target(target_transform: Transform3D) -> void:
    var target_position := target_transform.origin
    var target_rotation := target_transform.basis.orthonormalized().get_rotation_quaternion()
    var distance_from_previous := 0.0
    if not _target_positions.is_empty():
        distance_from_previous = _target_positions[_target_positions.size() - 1].distance_to(target_position)
    _target_positions.append(target_position)
    _target_rotations.append(Vector4(target_rotation.x, target_rotation.y, target_rotation.z, target_rotation.w))
    _target_distances.append(distance_from_previous)


func _physics_process(delta: float) -> void:
    for follower_index in range(_followers.size()):
        _advance_follower(follower_index, speed * delta)
    _trim_trail()


func _advance_follower(follower_index: int, travel_distance: float) -> void:
    var follower := _followers[follower_index]
    var previous_target_index := _follower_target[follower_index]
    var follower_position := follower.global_position
    var target_count := _target_positions.size()

    # Move toward the next target, carrying leftover distance across targets.
    while previous_target_index + 1 < target_count:
        var next_target_position := _target_positions[previous_target_index + 1]
        var distance_to_next := follower_position.distance_to(next_target_position)
        if distance_to_next > travel_distance:
            follower_position = follower_position.move_toward(next_target_position, travel_distance)
            break
        follower_position = next_target_position
        travel_distance -= distance_to_next
        previous_target_index += 1

    _follower_target[follower_index] = previous_target_index

    # Slerp between the previous and next target rotations by progress along the leg.
    var follower_rotation := _get_target_rotation(previous_target_index)
    if previous_target_index + 1 < target_count:
        var leg_length := _target_distances[previous_target_index + 1]
        var progress := 1.0
        if leg_length > 0.0:
            var remaining_distance := follower_position.distance_to(_target_positions[previous_target_index + 1])
            progress = clampf(1.0 - remaining_distance / leg_length, 0.0, 1.0)
        follower_rotation = follower_rotation.slerp(_get_target_rotation(previous_target_index + 1), progress)

    follower.global_position = follower_position
    follower.global_basis = Basis(follower_rotation).scaled_local(follower.scale)


func _get_target_rotation(target_index: int) -> Quaternion:
    var packed_rotation := _target_rotations[target_index]
    return Quaternion(packed_rotation.x, packed_rotation.y, packed_rotation.z, packed_rotation.w)


# The tail is the furthest-behind follower, so anything before its previous
# target is never visited again. Drop it and shift all indices to match.
func _trim_trail() -> void:
    var passed_target_count := _follower_target[0]
    if passed_target_count <= 0:
        return
    _target_positions = _target_positions.slice(passed_target_count)
    _target_rotations = _target_rotations.slice(passed_target_count)
    _target_distances = _target_distances.slice(passed_target_count)
    _target_distances[0] = 0.0
    for follower_index in range(_follower_target.size()):
        _follower_target[follower_index] -= passed_target_count
