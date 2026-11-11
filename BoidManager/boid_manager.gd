extends Node3D
## Many flocks in one node. Boids are plain data (packed arrays), neighbors are found
## with one shared uniform spatial hash grid, and each BoidType is drawn through its
## own MultiMeshInstance3D child (created at runtime).
##
## Setup: none. A BoidType (.tres) is registered automatically the first time it is passed
## to add_boid(). Up to 63 types; type_name must be unique.
##
## Usage from other nodes:
##     flock.add_boid(preload("res://boids/default_boid.tres"), transform, velocity)
##     flock.add_boid_by_name(&"default", transform, velocity)  # type must already be registered
## and, to interact with the flock, just add nodes to the groups named in a BoidType
## (no per-tick calls needed):
##     add_to_group("projectiles")   # nearby boids are pushed away
##     add_to_group("players")       # boids seek the nearest one
##
## Group members must be Node3D; their global_position is sampled once per physics tick.
##
## The node is forced to top_level with an identity transform, so all simulation
## happens in world space. Up to 63 types are supported.
##
## Materials: BoidType.material_overrides is an Array[Material]; index i is applied to
## mesh surface i (null or missing entries keep the mesh's own material).
##
## Flash: set_boid_flash(index, duration) stores an absolute end time (seconds on the
## _now() clock) per boid. It reaches shaders as INSTANCE_CUSTOM.x, and the current
## time is available as the global shader uniform `boid_time`. A shader compares the
## two, e.g. `step(boid_time, INSTANCE_CUSTOM.x)` is 1.0 while the flash is active.

## Afterimage scene

var afterimage_scene = preload("res://Skulls/SkullAfterimage.tscn")

## Floats per MultiMesh instance: 12 for the 3D transform + 4 for custom data.
const FLOATS_PER_INSTANCE := 12 + 4
## Name of the global shader uniform holding the current time (see _now()).
const TIME_PARAM := &"boid_time"

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
var _max_collision_radius := 0.0  # largest collision_radius of any registered type

# --- Boid data (structure of arrays). Type t owns slots [_type_base[t], _type_base[t] + max_boids) ---
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _fwd := PackedVector3Array()
var _steer := PackedVector3Array()
var _proj_push := PackedVector3Array()
var _boid_type := PackedInt32Array()
var _health := PackedInt32Array()
var _flash_end := PackedFloat32Array()  # absolute time (seconds, see _now()) when the flash ends; 0 = none

# --- Spatial hash grid (counting sort, no per-frame allocation) ---
var _dim := 1
var _cell_total := 1
var _cell_size := 0.0
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
    # Global uniform so every boid shader reads the same clock the flash times are compared against
    if not RenderingServer.global_shader_parameter_get_list().has(TIME_PARAM):
        RenderingServer.global_shader_parameter_add(
            TIME_PARAM, RenderingServer.GLOBAL_VAR_TYPE_FLOAT, _now())


func _process(_delta: float) -> void:
    RenderingServer.global_shader_parameter_set(TIME_PARAM, _now())


## Seconds since engine start. Flash times are absolute values on this clock.
func _now() -> float:
    return Time.get_ticks_msec() * 0.001


## Adds a boid of the given type at the transform's position, moving at the given velocity.
## Facing starts along the velocity (or the transform's -Z if velocity is zero).
## The type is registered automatically on first use.
## Returns the boid's slot index, or -1 if the type can't be registered or is at capacity.
func add_boid(type: BoidType, xform: Transform3D, velocity: Vector3) -> int:
    var t := _types.find(type)
    if t == -1:
        t = register_type(type)
        if t == -1:
            return -1
    return _spawn(t, xform, velocity)


## Same as add_boid() but looks the type up by its type_name. The type must already
## have been registered by an earlier add_boid() call.
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

## Boid mesh, null if invalid index
func get_boid_mesh(index: int) -> Mesh:
    var t := _type_of_slot(index)
    if t == -1:
        return null
    return _multimeshes[t].mesh

## Returns the indices of all live boids whose collision sphere touches the query sphere
## (distance between centers <= radius + the boid's collision_radius). If `type` is null,
## boids of every type are considered. Returns an empty array if none match.
## Uses the spatial grid from the last physics tick, so boids spawned or moved
## since then may be missed (and nothing is found before the first tick).
##
## Indices are slots; remove_boid() swaps the last boid into the freed slot, so when
## removing several results, iterate the array backwards (sort it first if needed).
func get_boids_in_area(center: Vector3, radius: float, type: BoidType = null) -> PackedInt32Array:
    var results := PackedInt32Array()
    if _types.is_empty():
        return results
    var wanted := -1
    if type != null:
        wanted = _types.find(type)
        if wanted == -1:
            return results

    var reach_dist := radius + _max_collision_radius
    var max_cell := _dim - 1
    var cell_reach := int(ceil(reach_dist * _inv_cell))
    var center_cell := _cell_coords(center)

    for cz in range(maxi(center_cell.z - cell_reach, 0), mini(center_cell.z + cell_reach, max_cell) + 1):
        for cy in range(maxi(center_cell.y - cell_reach, 0), mini(center_cell.y + cell_reach, max_cell) + 1):
            for cx in range(maxi(center_cell.x - cell_reach, 0), mini(center_cell.x + cell_reach, max_cell) + 1):
                var cell := cx + _dim * (cy + _dim * cz)
                for slot in range(_cell_start[cell], _cell_start[cell + 1]):
                    var other := _cell_items[slot]
                    var t := _boid_type[other]
                    if wanted != -1 and t != wanted:
                        continue
                    # The grid can be a tick stale: skip slots removed since it was built
                    if other >= _type_base[t] + _type_counts[t]:
                        continue
                    var reach: float = radius + _types[t].collision_radius
                    if _pos[other].distance_squared_to(center) <= reach * reach:
                        results.append(other)
    return results


## Casts a ray against the boids' collision spheres and returns the index of the closest
## boid hit, or -1 if nothing was hit. `direction` does not need to be normalized.
## If `type` is null, boids of every type are considered.
##
## Uses the spatial grid from the last physics tick (see get_boids_in_area()).
## A ray starting inside a boid's sphere counts as a hit on that boid.
func raycast(start: Vector3, direction: Vector3, distance: float, type: BoidType = null) -> int:
    if _types.is_empty() or distance <= 0.0 or direction.is_zero_approx():
        return -1
    var wanted := -1
    if type != null:
        wanted = _types.find(type)
        if wanted == -1:
            return -1

    var dir := direction.normalized()
    var pad := _max_collision_radius

    # Clip the ray to the grid box (padded, since a sphere can poke out of the grid)
    var box_min := _grid_origin - Vector3.ONE * pad
    var box_max := _grid_origin + Vector3.ONE * (_dim * _cell_size + pad)
    var t_enter := 0.0
    var t_exit := distance
    for a in 3:
        if absf(dir[a]) < 0.000001:
            if start[a] < box_min[a] or start[a] > box_max[a]:
                return -1
        else:
            var t1 := (box_min[a] - start[a]) / dir[a]
            var t2 := (box_max[a] - start[a]) / dir[a]
            t_enter = maxf(t_enter, minf(t1, t2))
            t_exit = minf(t_exit, maxf(t1, t2))
    if t_enter > t_exit:
        return -1

    # DDA setup
    var entry := start + dir * t_enter
    var cell_pos := _cell_coords(entry)
    var max_cell := _dim - 1
    var cell_reach := int(ceil(pad * _inv_cell))
    var step := Vector3i.ZERO
    var t_max := Vector3(INF, INF, INF)
    var t_delta := Vector3(INF, INF, INF)
    for a in 3:
        if dir[a] > 0.000001:
            step[a] = 1
            var boundary := _grid_origin[a] + (cell_pos[a] + 1) * _cell_size
            t_max[a] = t_enter + (boundary - entry[a]) / dir[a]
            t_delta[a] = _cell_size / dir[a]
        elif dir[a] < -0.000001:
            step[a] = -1
            var boundary := _grid_origin[a] + cell_pos[a] * _cell_size
            t_max[a] = t_enter + (boundary - entry[a]) / dir[a]
            t_delta[a] = -_cell_size / dir[a]

    var best_t := INF
    var best_index := -1

    while true:
        # Test boids in this cell, plus neighbors within the largest sphere's reach: the
        # hit point lies in a cell on the ray, but the sphere's center may be in the next one.
        for cz in range(maxi(cell_pos.z - cell_reach, 0), mini(cell_pos.z + cell_reach, max_cell) + 1):
            for cy in range(maxi(cell_pos.y - cell_reach, 0), mini(cell_pos.y + cell_reach, max_cell) + 1):
                for cx in range(maxi(cell_pos.x - cell_reach, 0), mini(cell_pos.x + cell_reach, max_cell) + 1):
                    var cell := cx + _dim * (cy + _dim * cz)
                    for slot in range(_cell_start[cell], _cell_start[cell + 1]):
                        var other := _cell_items[slot]
                        var t := _boid_type[other]
                        if wanted != -1 and t != wanted:
                            continue
                        if other >= _type_base[t] + _type_counts[t]:
                            continue  # stale grid entry
                        var hit_t := _ray_sphere_distance(start, dir, _pos[other], _types[t].collision_radius, distance)
                        if hit_t >= 0.0 and hit_t < best_t:
                            best_t = hit_t
                            best_index = other

        # Anything found so far is closer than every hit in later cells
        var cell_exit := minf(t_max.x, minf(t_max.y, t_max.z))
        if best_t <= cell_exit or cell_exit > t_exit:
            break

        # Advance to the next cell along the ray
        var axis := 0
        if t_max.y < t_max[axis]:
            axis = 1
        if t_max.z < t_max[axis]:
            axis = 2
        cell_pos[axis] += step[axis]
        if cell_pos[axis] < 0 or cell_pos[axis] > max_cell:
            break
        t_max[axis] += t_delta[axis]

    return best_index


## Ray vs. sphere test. `dir` must be normalized. Returns the distance along the ray to
## the first intersection, or -1.0 if the ray misses. A ray starting inside the sphere
## returns 0.0. Hits beyond `max_distance` count as misses.
func _ray_sphere_distance(start: Vector3, dir: Vector3, center: Vector3, radius: float, max_distance: float) -> float:
    var m := start - center
    var b := m.dot(dir)
    var c := m.dot(m) - radius * radius
    if c > 0.0 and b > 0.0:
        return -1.0  # outside the sphere and pointing away
    var disc := b * b - c
    if disc < 0.0:
        return -1.0
    var hit_t := maxf(-b - sqrt(disc), 0.0)
    return hit_t if hit_t <= max_distance else -1.0


## Current world position of a boid, or Vector3.INF if the index is not a live boid.
func get_boid_position(index: int) -> Vector3:
    if _type_of_slot(index) == -1:
        return Vector3.INF
    return _pos[index]

func get_boid_transform(index: int) -> Transform3D:
    if _type_of_slot(index) == -1:
        return Transform3D(Basis.IDENTITY, Vector3.INF)
    var forward := _fwd[index]
    if forward.length_squared() < 0.0001:
        return Transform3D(Basis.IDENTITY, _pos[index])
    forward = forward.normalized()
    # Build basis with -Z facing forward, matching the render basis in _integrate()
    var z := -forward
    var up := Vector3.UP if absf(forward.y) < 0.99 else Vector3.RIGHT
    var x := up.cross(z).normalized()
    var y := z.cross(x)
    return Transform3D(Basis(x, y, z), _pos[index])


## Health of a boid, or 0 if the index is not a live boid.
func get_boid_health(index: int) -> int:
    if _type_of_slot(index) == -1:
        return 0
    return _health[index]


## Sets a boid's health. Does NOT remove the boid at 0 or below; call remove_boid()
## yourself (e.g. when the new value is <= 0). Returns false if the index is not live.
func set_boid_health(index: int, value: int) -> bool:
    if _type_of_slot(index) == -1:
        return false
    _health[index] = value
    return true


## Makes a boid flash for `duration` seconds from now. The absolute end time is stored
## per boid and passed to shaders as INSTANCE_CUSTOM.x (compare against the global
## uniform `boid_time`). Calling it again restarts the flash. The value reaches the GPU
## on the next physics tick. Returns false if the index is not a live boid.
func set_boid_flash(index: int, duration: float) -> bool:
    if _type_of_slot(index) == -1:
        return false
    _flash_end[index] = _now() + maxf(duration, 0.0)
    return true

func spawn_afterimage(index: int) -> SkullAfterimage:
    var t := _type_of_slot(index)
    if t == -1:
        return null

    var afterimage: SkullAfterimage = afterimage_scene.instantiate()
    get_tree().current_scene.add_child(afterimage)

    afterimage.global_transform = get_boid_transform(index)

    afterimage.set_mesh_1(_multimeshes[t].mesh)

    return afterimage

## Removes a live boid. Returns false if the index is not a live boid.
##
## NOTE: indices are slots, and removal swaps the LAST live boid of the same type into
## the freed slot. So after removing index i, the boid that used to have the highest
## index of that type now has index i. If you hold indices over time (or loop over
## them), iterate backwards or re-query after removing.
func remove_boid(index: int) -> bool:
    var t := _type_of_slot(index)
    if t == -1:
        return false

    var base := _type_base[t]
    var last := base + _type_counts[t] - 1
    var buf: PackedFloat32Array = _buffers[t]

    if index != last:
        _pos[index] = _pos[last]
        _vel[index] = _vel[last]
        _fwd[index] = _fwd[last]
        _steer[index] = _steer[last]
        _proj_push[index] = _proj_push[last]
        _health[index] = _health[last]
        _flash_end[index] = _flash_end[last]
        _boid_type[index] = _boid_type[last]
        # Move the render data too (transform + custom data) so there's no one-frame glitch
        var dst := (index - base) * FLOATS_PER_INSTANCE
        var src := (last - base) * FLOATS_PER_INSTANCE
        for k in FLOATS_PER_INSTANCE:
            buf[dst + k] = buf[src + k]

    _type_counts[t] -= 1
    _buffers[t] = buf
    var mm := _multimeshes[t]
    mm.visible_instance_count = _type_counts[t]
    mm.buffer = buf
    return true


## Returns the type index owning this slot if it holds a live boid, otherwise -1.
func _type_of_slot(index: int) -> int:
    if index < 0 or index >= _capacity:
        return -1
    for t in _types.size():
        var base := _type_base[t]
        if index < base + _type_counts[t]:
            return t if index >= base else -1
    return -1


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
    _health[i] = bt.max_health
    _flash_end[i] = 0.0
    if velocity.length_squared() > 0.0001:
        _fwd[i] = velocity.normalized()
    else:
        _fwd[i] = -xform.basis.z.normalized()
    return i


## Registers a BoidType and returns its type index, or -1 if it can't be registered.
## New types are appended, so existing types keep their slot ranges and indices.
func register_type(bt: BoidType) -> int:
    if bt == null:
        push_warning("BoidManager: cannot register a null BoidType.")
        return -1
    if _name_to_index.has(bt.type_name):
        push_warning("BoidManager: a different BoidType already uses type_name '%s'." % bt.type_name)
        return -1
    if _types.size() >= 63:
        push_warning("BoidManager: more than 63 types, cannot register '%s'." % bt.type_name)
        return -1

    var t := _types.size()
    _name_to_index[bt.type_name] = t
    _types.append(bt)
    _type_base.append(_capacity)
    _type_counts.append(0)
    _capacity += bt.max_boids
    _resize_boid_arrays()
    _update_grid(bt.neighbor_radius)
    _max_collision_radius = maxf(_max_collision_radius, bt.collision_radius)

    # Instance bounds: boids move everywhere inside the bounds; don't let culling hide them.
    var extent := Vector3.ONE * bounds_radius * 1.5
    var aabb := AABB(bounds_center - extent, extent * 2.0)

    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = false
    mm.use_custom_data = true  # INSTANCE_CUSTOM.x = flash end time

    var mesh: Mesh = bt.mesh
    if mesh == null:
        var box := BoxMesh.new()
        box.size = Vector3(0.2, 0.2, 0.6)
        mesh = box
    if not bt.material_overrides.is_empty():
        mesh = mesh.duplicate()  # don't modify the shared resource
        var surfaces := mini(mesh.get_surface_count(), bt.material_overrides.size())
        for s in surfaces:
            var mat := bt.material_overrides[s]
            if mat != null:
                mesh.surface_set_material(s, mat)
    mm.mesh = mesh
    mm.instance_count = bt.max_boids
    mm.visible_instance_count = 0

    var mmi := MultiMeshInstance3D.new()
    mmi.name = bt.type_name
    mmi.multimesh = mm
    mmi.custom_aabb = aabb
    add_child(mmi)
    _multimeshes.append(mm)

    var buf := PackedFloat32Array()
    buf.resize(bt.max_boids * FLOATS_PER_INSTANCE)
    _buffers.append(buf)

    _proj_lists.append(PackedVector3Array())
    _target_lists.append(PackedVector3Array())
    return t


## Grows every per-boid array to the current capacity (existing data is kept).
func _resize_boid_arrays() -> void:
    _pos.resize(_capacity)
    _vel.resize(_capacity)
    _fwd.resize(_capacity)
    _steer.resize(_capacity)
    _proj_push.resize(_capacity)
    _boid_type.resize(_capacity)
    _health.resize(_capacity)
    _flash_end.resize(_capacity)
    _cell_items.resize(_capacity)
    _boid_cell.resize(_capacity)


## Makes sure the grid cell size covers `neighbor_radius` (a 3x3x3 block of cells must be
## enough for the largest perception radius). Only rebuilds the grid layout if the cell
## size has to grow; the grid is emptied and refilled on the next physics tick.
func _update_grid(neighbor_radius: float) -> void:
    var cell_size := maxf(maxf(_cell_size, neighbor_radius), 0.01)
    if cell_size == _cell_size:
        return
    _cell_size = cell_size
    _inv_cell = 1.0 / cell_size
    _dim = int(ceil(bounds_radius * 2.0 / cell_size)) + 1
    _cell_total = _dim * _dim * _dim
    _grid_origin = bounds_center - Vector3.ONE * bounds_radius
    _cell_start.resize(_cell_total + 1)
    _cell_start.fill(0)  # old contents no longer match the layout; queries see an empty grid


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

            # MultiMesh TRANSFORM_3D layout: 3 rows of (basis column x, y, z, origin),
            # followed by 4 floats of custom data (use_custom_data = true)
            var o := (i - base) * FLOATS_PER_INSTANCE
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

            # Custom data (INSTANCE_CUSTOM): x = flash end time (absolute, see _now())
            buf[o + 12] = _flash_end[i]
            buf[o + 13] = 0.0
            buf[o + 14] = 0.0
            buf[o + 15] = 0.0

        _buffers[t] = buf
        var mm := _multimeshes[t]
        mm.visible_instance_count = count
        mm.buffer = buf
