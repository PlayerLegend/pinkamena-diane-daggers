class_name BoidManager
extends Node3D
## Many flocks in one node. Boids are plain data (packed arrays), neighbors are found
## with one shared uniform spatial hash grid, and each BoidType is drawn through its
## own MultiMeshInstance3D child (created at runtime).
##
## Setup: assign BoidType resources (.tres) to `boid_types`.
##
## Usage from other nodes:
##     flock.add_boid(preload("res://boids/default_boid.tres"), transform, velocity)
##     flock.add_boid_by_name(&"default", transform, velocity)
## and, to interact with the flock, just add nodes to the groups named in a BoidType
## (no per-tick calls needed):
##     add_to_group("projectiles")   # nearby boids are pushed away
##     add_to_group("players")       # boids seek the nearest one
##
## Group members must be Node3D; their global_position is sampled once per physics tick.
##
## The node is forced to top_level with an identity transform, so all simulation
## happens in world space. Up to 63 types are supported.

@export var boid_types: Array[BoidType] = []  ## One entry per kind of boid. Names must be unique.

@export_group("Bounds")
@export var bounds_center := Vector3.ZERO
@export var bounds_radius := 40.0

# --- Per-type data (indexed by type index) ---
var _types: Array[BoidType] = []
var _type_base := PackedInt32Array()    # first boid slot of each type
var _type_counts := PackedInt32Array()  # live boids of each type
var _multimeshes: Array[MultiMesh] = []
var _buffers: Array = []                # PackedFloat32Array per type
var _name_to_index := {}
var _capacity := 0

# --- Boid data (structure of arrays). Type t owns slots [_type_base[t], _type_base[t] + max_boids) ---
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _fwd := PackedVector3Array()
var _steer := PackedVector3Array()
var _proj_push := PackedVector3Array()
var _boid_type := PackedInt32Array()

# --- Spatial hash grid (counting sort, no per-frame allocation) ---
var _dim := 1
var _cell_total := 1
var _inv_cell := 1.0
var _grid_origin := Vector3.ZERO
var _cell_start := PackedInt32Array()  # size cell_total + 1
var _cell_items := PackedInt32Array()  # boid indices grouped by cell
var _boid_cell := PackedInt32Array()

# --- Positions sampled from the groups at the start of each tick ---
var _group_positions := {}  # StringName -> PackedVector3Array (reused between ticks)
var _gathered := {}         # groups already sampled this tick
var _proj_lists: Array = []    # PackedVector3Array per type
var _target_lists: Array = []  # PackedVector3Array per type


func _ready() -> void:
    top_level = true
    global_transform = Transform3D.IDENTITY
    _setup_types()
    _setup_grid()
    _allocate()


## Adds a boid of the given type at the transform's position, moving at the given velocity.
## Facing starts along the velocity (or the transform's -Z if velocity is zero).
## Returns the boid's slot index, or -1 if the type is unknown or at capacity.
func add_boid(type: BoidType, xform: Transform3D, velocity: Vector3) -> int:
    var t := _types.find(type)
    if t == -1:
        push_warning("BoidManager: BoidType is not in boid_types.")
        return -1
    return _spawn(t, xform, velocity)


## Same as add_boid() but looks the type up by its type_name.
func add_boid_by_name(type_name: StringName, xform: Transform3D, velocity: Vector3) -> int:
    if not _name_to_index.has(type_name):
        push_warning("BoidManager: no BoidType named '%s'." % type_name)
        return -1
    return _spawn(_name_to_index[type_name], xform, velocity)


## Number of live boids of one type, or of all types if `type` is null.
func get_boid_count(type: BoidType = null) -> int:
    if type == null:
        var total := 0
        for c in _type_counts:
            total += c
        return total
    var t := _types.find(type)
    return _type_counts[t] if t != -1 else 0


func _spawn(t: int, xform: Transform3D, velocity: Vector3) -> int:
    var bt := _types[t]
    if _type_counts[t] >= bt.max_boids:
        return -1
    var i := _type_base[t] + _type_counts[t]
    _type_counts[t] += 1
    _boid_type[i] = t
    _pos[i] = xform.origin
    if bt.use_floor:
        _pos[i].y = maxf(_pos[i].y, bt.floor_height)
    _vel[i] = velocity
    _steer[i] = Vector3.ZERO
    _proj_push[i] = Vector3.ZERO
    if velocity.length_squared() > 0.0001:
        _fwd[i] = velocity.normalized()
    else:
        _fwd[i] = -xform.basis.z.normalized()
    return i


func _setup_types() -> void:
    for bt in boid_types:
        if bt == null:
            continue
        if _name_to_index.has(bt.type_name):
            push_warning("BoidManager: duplicate type_name '%s' ignored." % bt.type_name)
            continue
        if _types.size() >= 63:
            push_warning("BoidManager: more than 63 types, extra types ignored.")
            break
        _name_to_index[bt.type_name] = _types.size()
        _types.append(bt)

    # Instance bounds: boids move everywhere inside the bounds; don't let culling hide them.
    var extent := Vector3.ONE * bounds_radius * 1.5
    var aabb := AABB(bounds_center - extent, extent * 2.0)

    var base := 0
    for t in _types.size():
        var bt := _types[t]
        _type_base.append(base)
        _type_counts.append(0)
        base += bt.max_boids

        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.use_colors = false
        mm.use_custom_data = false
        if bt.mesh != null:
            mm.mesh = bt.mesh
        else:
            var box := BoxMesh.new()
            box.size = Vector3(0.2, 0.2, 0.6)
            mm.mesh = box
        mm.instance_count = bt.max_boids
        mm.visible_instance_count = 0

        var mmi := MultiMeshInstance3D.new()
        mmi.name = bt.type_name
        mmi.multimesh = mm
        mmi.material_override = bt.material_override
        mmi.custom_aabb = aabb
        add_child(mmi)
        _multimeshes.append(mm)

        var buf := PackedFloat32Array()
        buf.resize(bt.max_boids * 12)
        _buffers.append(buf)

        _proj_lists.append(PackedVector3Array())
        _target_lists.append(PackedVector3Array())
    _capacity = base


func _setup_grid() -> void:
    # Cell size must cover the largest perception radius so a 3x3x3 block is enough.
    var cell_size := 0.01
    for bt in _types:
        cell_size = maxf(cell_size, bt.neighbor_radius)
    _inv_cell = 1.0 / cell_size
    _dim = int(ceil(bounds_radius * 2.0 / cell_size)) + 1
    _cell_total = _dim * _dim * _dim
    _grid_origin = bounds_center - Vector3.ONE * bounds_radius
    _cell_start.resize(_cell_total + 1)
    _cell_items.resize(_capacity)
    _boid_cell.resize(_capacity)


func _allocate() -> void:
    _pos.resize(_capacity)
    _vel.resize(_capacity)
    _fwd.resize(_capacity)
    _steer.resize(_capacity)
    _proj_push.resize(_capacity)
    _boid_type.resize(_capacity)


## Samples current positions of every Node3D in the group (once per tick per group).
func _sample_group(group: StringName) -> PackedVector3Array:
    if group.is_empty():
        return PackedVector3Array()
    if _gathered.has(group):
        return _group_positions[group]
    var arr: PackedVector3Array = _group_positions.get(group, PackedVector3Array())
    arr.clear()
    for node in get_tree().get_nodes_in_group(group):
        if node is Node3D and node.is_inside_tree():
            arr.append(node.global_position)
    _group_positions[group] = arr
    _gathered[group] = true
    return arr


func _gather_group_positions() -> void:
    _gathered.clear()
    for t in _types.size():
        _proj_lists[t] = _sample_group(_types[t].projectile_group)
        _target_lists[t] = _sample_group(_types[t].target_group)


func _cell_coords(point: Vector3) -> Vector3i:
    var scaled := (point - _grid_origin) * _inv_cell
    var max_cell := _dim - 1
    return Vector3i(
        clampi(int(scaled.x), 0, max_cell),
        clampi(int(scaled.y), 0, max_cell),
        clampi(int(scaled.z), 0, max_cell))


func _cell_index(coords: Vector3i) -> int:
    return coords.x + _dim * (coords.y + _dim * coords.z)


func _build_grid() -> void:
    _cell_start.fill(0)
    var total := 0
    for t in _types.size():
        var base := _type_base[t]
        for i in range(base, base + _type_counts[t]):
            var cell := _cell_index(_cell_coords(_pos[i]))
            _boid_cell[i] = cell
            _cell_start[cell] += 1
        total += _type_counts[t]

    # Inclusive prefix sum -> each entry becomes the END of its cell
    var running := 0
    for cell in _cell_total:
        running += _cell_start[cell]
        _cell_start[cell] = running
    _cell_start[_cell_total] = total

    # Place boids backwards; afterwards _cell_start[cell] is the START of that cell
    for t in _types.size():
        var base := _type_base[t]
        for i in range(base, base + _type_counts[t]):
            var cell := _boid_cell[i]
            _cell_start[cell] -= 1
            _cell_items[_cell_start[cell]] = i


## Pushes boids near each projectile away from it. Each type uses its own projectile
## group and distance, and only that type's boids are affected.
func _apply_projectiles() -> void:
    _proj_push.fill(Vector3.ZERO)
    var max_cell := _dim - 1

    for t in _types.size():
        var proj_list: PackedVector3Array = _proj_lists[t]
        if proj_list.is_empty() or _type_counts[t] == 0:
            continue
        var radius := _types[t].projectile_avoidance_distance
        var radius_sq := radius * radius
        var cell_reach := int(ceil(radius * _inv_cell))

        for proj_pos in proj_list:
            var center_cell := _cell_coords(proj_pos)
            for cz in range(maxi(center_cell.z - cell_reach, 0), mini(center_cell.z + cell_reach, max_cell) + 1):
                for cy in range(maxi(center_cell.y - cell_reach, 0), mini(center_cell.y + cell_reach, max_cell) + 1):
                    for cx in range(maxi(center_cell.x - cell_reach, 0), mini(center_cell.x + cell_reach, max_cell) + 1):
                        var cell := cx + _dim * (cy + _dim * cz)
                        for slot in range(_cell_start[cell], _cell_start[cell + 1]):
                            var other := _cell_items[slot]
                            if _boid_type[other] != t:
                                continue
                            var offset := _pos[other] - proj_pos
                            var dist_sq := offset.length_squared()
                            if dist_sq < radius_sq and dist_sq > 0.01:
                                _proj_push[other] += offset / dist_sq  # stronger when closer


func _physics_process(delta: float) -> void:
    if _types.is_empty():
        return
    var any := false
    for c in _type_counts:
        if c > 0:
            any = true
            break
    if not any:
        return

    _gather_group_positions()
    _build_grid()
    _apply_projectiles()
    _compute_steering()
    _integrate(delta)


## Reynolds steering: desired velocity minus current velocity.
func _steer_towards(direction: Vector3, current_vel: Vector3, speed: float) -> Vector3:
    if direction.is_zero_approx():
        return Vector3.ZERO
    return direction.normalized() * speed - current_vel


func _compute_steering() -> void:
    var max_cell := _dim - 1

    for t in _types.size():
        var bt := _types[t]
        var base := _type_base[t]
        var nr_sq := bt.neighbor_radius * bt.neighbor_radius
        var sep_sq := bt.separation_radius * bt.separation_radius
        var max_speed := bt.max_speed
        var targets: PackedVector3Array = _target_lists[t]
        var has_targets := not targets.is_empty()

        for i in range(base, base + _type_counts[t]):
            var boid_pos := _pos[i]
            var boid_vel := _vel[i]

            var separation_push := Vector3.ZERO
            var velocity_sum := Vector3.ZERO
            var position_sum := Vector3.ZERO
            var count := 0

            # --- Neighbors via the 3x3x3 block of cells around this boid ---
            var home_cell := _cell_coords(boid_pos)
            var done := false
            for cz in range(maxi(home_cell.z - 1, 0), mini(home_cell.z + 1, max_cell) + 1):
                if done:
                    break
                for cy in range(maxi(home_cell.y - 1, 0), mini(home_cell.y + 1, max_cell) + 1):
                    if done:
                        break
                    for cx in range(maxi(home_cell.x - 1, 0), mini(home_cell.x + 1, max_cell) + 1):
                        var cell := cx + _dim * (cy + _dim * cz)
                        for slot in range(_cell_start[cell], _cell_start[cell + 1]):
                            var other := _cell_items[slot]
                            if other == i:
                                continue
                            var offset := boid_pos - _pos[other]
                            var dist_sq := offset.length_squared()
                            if dist_sq > nr_sq:
                                continue
                            # Separation applies to every boid, whatever its type
                            if dist_sq > 0.0001 and dist_sq < sep_sq:
                                separation_push += offset / dist_sq  # stronger when closer
                            # Alignment and cohesion only use the same type
                            if _boid_type[other] == t:
                                count += 1
                                velocity_sum += _vel[other]
                                position_sum += _pos[other]
                                if count >= bt.max_neighbors:
                                    done = true
                                    break
                        if done:
                            break

            # --- Combine rules ---
            var steering := _steer_towards(_proj_push[i], boid_vel, max_speed) * bt.projectile_avoidance_weight

            steering += _steer_towards(separation_push, boid_vel, max_speed) * bt.separation_weight

            if count > 0:
                var alignment := _steer_towards(velocity_sum / count, boid_vel, max_speed)
                var cohesion := _steer_towards(position_sum / count - boid_pos, boid_vel, max_speed)
                steering += alignment * bt.alignment_weight \
                    + cohesion * bt.cohesion_weight

            steering += _stay_in_bounds(bt, boid_pos, boid_vel) * bt.bounds_weight
            steering += _avoid_floor(bt, boid_pos, boid_vel) * bt.floor_weight

            # --- Chase the nearest node in the target group ---
            if has_targets:
                var best_sq := INF
                var best_dir := Vector3.ZERO
                for target_pos in targets:
                    var to_target := target_pos - boid_pos
                    var target_sq := to_target.length_squared()
                    if target_sq < best_sq:
                        best_sq = target_sq
                        best_dir = to_target
                steering += _steer_towards(best_dir, boid_vel, max_speed) * bt.target_weight

            _steer[i] = steering


func _stay_in_bounds(bt: BoidType, boid_pos: Vector3, boid_vel: Vector3) -> Vector3:
    var to_center := bounds_center - boid_pos
    var dist := to_center.length()
    if dist <= bounds_radius:
        return Vector3.ZERO
    # Pull grows the farther outside the bounds the boid is
    var strength := (dist - bounds_radius) / bounds_radius
    return _steer_towards(to_center, boid_vel, bt.max_speed) * (1.0 + strength)


## Soft floor: steers upward once a boid is within floor_margin of the floor.
## The push ramps from 0 at the margin edge to full strength at the floor.
## (A hard clamp in _integrate() guarantees boids never actually pass through.)
func _avoid_floor(bt: BoidType, boid_pos: Vector3, boid_vel: Vector3) -> Vector3:
    if not bt.use_floor:
        return Vector3.ZERO
    var depth := (bt.floor_height + bt.floor_margin) - boid_pos.y
    if depth <= 0.0:
        return Vector3.ZERO
    var strength := minf(depth / maxf(bt.floor_margin, 0.01), 2.0)
    return _steer_towards(Vector3.UP, boid_vel, bt.max_speed) * strength


func _integrate(delta: float) -> void:
    for t in _types.size():
        var bt := _types[t]
        var count := _type_counts[t]
        var base := _type_base[t]
        var buf: PackedFloat32Array = _buffers[t]
        var turn_t := clampf(bt.turn_speed * delta, 0.0, 1.0)

        for i in range(base, base + count):
            var boid_vel := _vel[i] + _steer[i].limit_length(bt.max_force) * delta

            # Keep speed within [min_speed, max_speed]
            var speed := boid_vel.length()
            if speed > 0.001:
                boid_vel = boid_vel / speed * clampf(speed, bt.min_speed, bt.max_speed)

            var boid_pos := _pos[i] + boid_vel * delta

            # Hard floor: never go below, and cancel downward velocity on contact
            if bt.use_floor and boid_pos.y < bt.floor_height:
                boid_pos.y = bt.floor_height
                if boid_vel.y < 0.0:
                    boid_vel.y = 0.0
                    # Re-apply min speed in case cancelling the Y component slowed it too much
                    var flat_speed := boid_vel.length()
                    if flat_speed > 0.001:
                        boid_vel = boid_vel / flat_speed * maxf(flat_speed, bt.min_speed)

            _vel[i] = boid_vel
            _pos[i] = boid_pos

            # Smoothed facing direction
            var forward := _fwd[i]
            if boid_vel.length_squared() > 0.01:
                forward = forward.lerp(boid_vel.normalized(), turn_t)
                if forward.length_squared() < 0.0001:
                    forward = boid_vel.normalized()
                else:
                    forward = forward.normalized()
                _fwd[i] = forward

            # Build basis (-Z faces forward), avoiding degeneracy when moving straight up/down
            var z := -forward
            var up := Vector3.UP if absf(forward.y) < 0.99 else Vector3.RIGHT
            var x := up.cross(z).normalized()
            var y := z.cross(x)

            # MultiMesh TRANSFORM_3D layout: 3 rows of (basis column x, y, z, origin)
            var o := (i - base) * 12
            buf[o] = x.x
            buf[o + 1] = y.x
            buf[o + 2] = z.x
            buf[o + 3] = boid_pos.x
            buf[o + 4] = x.y
            buf[o + 5] = y.y
            buf[o + 6] = z.y
            buf[o + 7] = boid_pos.y
            buf[o + 8] = x.z
            buf[o + 9] = y.z
            buf[o + 10] = z.z
            buf[o + 11] = boid_pos.z

        var mm := _multimeshes[t]
        mm.visible_instance_count = count
        mm.buffer = buf
