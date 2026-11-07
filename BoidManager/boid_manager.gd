extends MultiMeshInstance3D

class_name BoidManager
## An entire flock in one node. Boids are plain data (packed arrays), neighbors are
## found with a uniform spatial hash grid, and everything is drawn through this
## node's MultiMesh.
##
## Usage from other nodes:
##     flock.add_boid(transform, velocity)  # spawn a boid
## and, to interact with the flock, just add nodes to groups (no per-tick calls needed):
##     add_to_group("projectiles")   # nearby boids are pushed away
##     add_to_group("players")       # boids seek the nearest one
##
## Group members must be Node3D; their global_position is sampled once per physics tick.
##
## The node is forced to top_level with an identity transform, so all simulation
## happens in world space.

@export_group("Population")
@export var boid_mesh: Mesh  ## Mesh per boid, should point along -Z. Falls back to a small box.
@export var max_boids := 1000  ## Capacity. add_boid() fails once this is reached.

@export_group("Speed")
@export var max_speed := 16.0
@export var min_speed := 4.5
@export var max_force := 12.0  ## Max steering acceleration

@export_group("Flocking")
@export var separation_weight := 0.3
@export var alignment_weight := 0.1
@export var cohesion_weight := 0.2
@export var separation_radius := 1.0  ## Neighbors closer than this push away
@export var neighbor_radius := 3.0  ## Perception radius; also the hash cell size
@export var max_neighbors := 24  ## Early-out cap per boid in dense clumps

@export_group("Avoidance")
@export var projectile_group := &"projectiles"  ## Nodes in this group push boids away
@export var projectile_avoidance_weight := 1.0
@export var projectile_avoidance_distance := 3.0

@export_group("Bounds")
@export var bounds_center := Vector3.ZERO
@export var bounds_radius := 40.0
@export var bounds_weight := 1.1

@export_group("Visuals")
@export var turn_speed := 4.0  ## Smoothing for facing direction

@export_group("Targets")
@export var target_group := &"players"  ## Boids chase the nearest node in this group
@export var target_weight := 0.3

# --- Boid data (structure of arrays, preallocated to max_boids) ---
var _count := 0
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _fwd := PackedVector3Array()
var _steer := PackedVector3Array()
var _proj_push := PackedVector3Array()
var _buffer := PackedFloat32Array()

# --- Spatial hash grid (counting sort, no per-frame allocation) ---
var _dim := 1
var _cell_total := 1
var _inv_cell := 1.0
var _grid_origin := Vector3.ZERO
var _cell_start := PackedInt32Array()  # size cell_total + 1
var _cell_items := PackedInt32Array()  # boid indices grouped by cell
var _boid_cell := PackedInt32Array()

# --- Positions sampled from the groups at the start of each tick ---
var _projectile_positions := PackedVector3Array()
var _target_positions := PackedVector3Array()


func _ready() -> void:
    top_level = true
    global_transform = Transform3D.IDENTITY
    _setup_multimesh()
    _setup_grid()
    _allocate()


## Adds a boid at the transform's position, moving at the given velocity.
## Facing starts along the velocity (or the transform's -Z if velocity is zero).
## Returns the boid's index, or -1 if the flock is at capacity.
func add_boid(xform: Transform3D, velocity: Vector3) -> int:
    if _count >= max_boids:
        return -1
    var i := _count
    _count += 1
    _pos[i] = xform.origin
    _vel[i] = velocity
    _steer[i] = Vector3.ZERO
    _proj_push[i] = Vector3.ZERO
    if velocity.length_squared() > 0.0001:
        _fwd[i] = velocity.normalized()
    else:
        _fwd[i] = -xform.basis.z.normalized()
    return i


## Samples current positions of every Node3D in the projectile and target groups.
func _gather_group_positions() -> void:
    var tree := get_tree()

    _projectile_positions.clear()
    for node in tree.get_nodes_in_group(projectile_group):
        if node is Node3D and node.is_inside_tree():
            _projectile_positions.append(node.global_position)

    _target_positions.clear()
    for node in tree.get_nodes_in_group(target_group):
        if node is Node3D and node.is_inside_tree():
            _target_positions.append(node.global_position)


func _setup_multimesh() -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = false
    mm.use_custom_data = false
    if boid_mesh == null:
        var box := BoxMesh.new()
        box.size = Vector3(0.2, 0.2, 0.6)
        boid_mesh = box
    mm.mesh = boid_mesh
    mm.instance_count = max_boids
    mm.visible_instance_count = 0
    multimesh = mm

    # Instances move everywhere inside the bounds; don't let culling hide them.
    var extent := Vector3.ONE * bounds_radius * 1.5
    custom_aabb = AABB(bounds_center - extent, extent * 2.0)

    _buffer.resize(max_boids * 12)


func _setup_grid() -> void:
    var cell_size := maxf(neighbor_radius, 0.01)
    _inv_cell = 1.0 / cell_size
    _dim = int(ceil(bounds_radius * 2.0 / cell_size)) + 1
    _cell_total = _dim * _dim * _dim
    _grid_origin = bounds_center - Vector3.ONE * bounds_radius
    _cell_start.resize(_cell_total + 1)
    _cell_items.resize(max_boids)
    _boid_cell.resize(max_boids)


func _allocate() -> void:
    _pos.resize(max_boids)
    _vel.resize(max_boids)
    _fwd.resize(max_boids)
    _steer.resize(max_boids)
    _proj_push.resize(max_boids)


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
    for i in _count:
        var cell := _cell_index(_cell_coords(_pos[i]))
        _boid_cell[i] = cell
        _cell_start[cell] += 1

    # Inclusive prefix sum -> each entry becomes the END of its cell
    var running := 0
    for cell in _cell_total:
        running += _cell_start[cell]
        _cell_start[cell] = running
    _cell_start[_cell_total] = _count

    # Place boids backwards; afterwards _cell_start[cell] is the START of that cell
    for i in _count:
        var cell := _boid_cell[i]
        _cell_start[cell] -= 1
        _cell_items[_cell_start[cell]] = i


## Pushes boids near each projectile away from it. Cost scales with projectiles
## times local boids rather than projectiles times all boids.
func _apply_projectiles() -> void:
    _proj_push.fill(Vector3.ZERO)
    if _projectile_positions.is_empty():
        return

    var radius := projectile_avoidance_distance
    var radius_sq := radius * radius
    var cell_reach := int(ceil(radius * _inv_cell))
    var max_cell := _dim - 1

    for proj_pos in _projectile_positions:
        var center_cell := _cell_coords(proj_pos)
        for cz in range(maxi(center_cell.z - cell_reach, 0), mini(center_cell.z + cell_reach, max_cell) + 1):
            for cy in range(maxi(center_cell.y - cell_reach, 0), mini(center_cell.y + cell_reach, max_cell) + 1):
                for cx in range(maxi(center_cell.x - cell_reach, 0), mini(center_cell.x + cell_reach, max_cell) + 1):
                    var cell := cx + _dim * (cy + _dim * cz)
                    for slot in range(_cell_start[cell], _cell_start[cell + 1]):
                        var other := _cell_items[slot]
                        var offset := _pos[other] - proj_pos
                        var dist_sq := offset.length_squared()
                        if dist_sq < radius_sq and dist_sq > 0.01:
                            _proj_push[other] += offset / dist_sq  # stronger when closer


func _physics_process(delta: float) -> void:
    if _count == 0:
        return

    _gather_group_positions()
    _build_grid()
    _apply_projectiles()
    _compute_steering()
    _integrate(delta)

    multimesh.visible_instance_count = _count
    multimesh.buffer = _buffer


## Reynolds steering: desired velocity minus current velocity.
func _steer_towards(direction: Vector3, current_vel: Vector3) -> Vector3:
    if direction.is_zero_approx():
        return Vector3.ZERO
    return direction.normalized() * max_speed - current_vel


func _compute_steering() -> void:
    var nr_sq := neighbor_radius * neighbor_radius
    var sep_sq := separation_radius * separation_radius
    var max_cell := _dim - 1
    var has_targets := not _target_positions.is_empty()

    for i in _count:
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
                        count += 1
                        velocity_sum += _vel[other]
                        position_sum += _pos[other]
                        if dist_sq > 0.0001 and dist_sq < sep_sq:
                            separation_push += offset / dist_sq  # stronger when closer
                        if count >= max_neighbors:
                            done = true
                            break
                    if done:
                        break

        # --- Combine rules ---
        var steering := _steer_towards(_proj_push[i], boid_vel) * projectile_avoidance_weight

        if count > 0:
            var alignment := _steer_towards(velocity_sum / count, boid_vel)
            var cohesion := _steer_towards(position_sum / count - boid_pos, boid_vel)
            var separation := _steer_towards(separation_push, boid_vel)
            steering += separation * separation_weight \
                + alignment * alignment_weight \
                + cohesion * cohesion_weight

        steering += _stay_in_bounds(boid_pos, boid_vel) * bounds_weight

        # --- Chase the nearest node in the target group ---
        if has_targets:
            var best_sq := INF
            var best_dir := Vector3.ZERO
            for target_pos in _target_positions:
                var to_target := target_pos - boid_pos
                var target_sq := to_target.length_squared()
                if target_sq < best_sq:
                    best_sq = target_sq
                    best_dir = to_target
            steering += _steer_towards(best_dir, boid_vel) * target_weight

        _steer[i] = steering


func _stay_in_bounds(boid_pos: Vector3, boid_vel: Vector3) -> Vector3:
    var to_center := bounds_center - boid_pos
    var dist := to_center.length()
    if dist <= bounds_radius:
        return Vector3.ZERO
    # Pull grows the farther outside the bounds the boid is
    var strength := (dist - bounds_radius) / bounds_radius
    return _steer_towards(to_center, boid_vel) * (1.0 + strength)


func _integrate(delta: float) -> void:
    var turn_t := clampf(turn_speed * delta, 0.0, 1.0)

    for i in _count:
        var boid_vel := _vel[i] + _steer[i].limit_length(max_force) * delta

        # Keep speed within [min_speed, max_speed]
        var speed := boid_vel.length()
        if speed > 0.001:
            boid_vel = boid_vel / speed * clampf(speed, min_speed, max_speed)

        var boid_pos := _pos[i] + boid_vel * delta
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
        var offset := i * 12
        _buffer[offset] = x.x
        _buffer[offset + 1] = y.x
        _buffer[offset + 2] = z.x
        _buffer[offset + 3] = boid_pos.x
        _buffer[offset + 4] = x.y
        _buffer[offset + 5] = y.y
        _buffer[offset + 6] = z.y
        _buffer[offset + 7] = boid_pos.y
        _buffer[offset + 8] = x.z
        _buffer[offset + 9] = y.z
        _buffer[offset + 10] = z.z
        _buffer[offset + 11] = boid_pos.z
