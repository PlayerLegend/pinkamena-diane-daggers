#include "boidsim.hpp"

using namespace godot;

void BoidArrays::_move_boid(int from, int to) {
  if (from == to)
    return;

  _ptr.rot[to] = _ptr.rot[from];
  _ptr.vel[to] = _ptr.vel[from];
  _ptr.health[to] = _ptr.health[from];
  _ptr.steer[to] = _ptr.steer[from];

  nearby_lookup.unlink(to);
  _ptr.set_pos(to, _ptr.pos[from]);

  nearby_lookup.unlink(from);
}

BoidID BoidArrays::_new_boid_index(int type_index) {
  const int type_count = (int)type_end.size();
  if (type_index < 0 || type_index >= type_count || boid_count >= MAX_BOIDS)
    return BOID_NULL;

  int *ends = type_end.ptrw();

  boid_count++;

  for (int t = type_count - 1; t > type_index; t--) {
    const int first = ends[t - 1]; // first boid of type t
    const int past_last = ends[t]; // one past its last

    // For a non-empty section, move its first boid to the end, which frees
    // the slot at `first` for the previous type to grow into. An empty
    // section needs no move, only a shift.
    if (first != past_last)
      _move_boid(first, past_last);

    ends[t]++;
  }

  // The slot at the old end of our section is now free.
  return ends[type_index]++;
}

BoidID BoidArrays::add_boid(int type_index, Vector3 pos, Quaternion r,
                            Vector3 velocity, int health) {
  if (boid_count >= MAX_BOIDS)
    return -1;

  if (type_index >= boid_types.size() || type_index < 0)
    return -1;

  BoidID boid = _new_boid_index(type_index);

  if (boid >= MAX_BOIDS)
    return -1;

  _ptr.set_pos(boid, pos);
  _ptr.rot[boid] = Vector4(r.x, r.y, r.z, r.w);
  _ptr.vel[boid] = velocity;
  _ptr.health[boid] = health;
  return boid;
}

int BoidArrays::_type_of(BoidID boid) const {
  if (boid >= boid_count)
    return -1;

  const int *ends = type_end.ptr();
  int lo = 0;
  int hi = (int)type_end.size(); // search in [lo, hi)

  while (lo < hi) {
    const int mid = lo + (hi - lo) / 2;
    if (ends[mid] > boid)
      hi = mid;
    else
      lo = mid + 1;
  }

  return lo < (int)type_end.size() ? lo : -1;
}

void BoidArrays::remove_boid(BoidID boid) {
  const int type = _type_of(boid);
  if (type < 0)
    return;

  const int type_count = (int)type_end.size();
  int *ends = type_end.ptrw();

  _move_boid(ends[type] - 1, boid);
  ends[type]--;

  for (int u = type + 1; u < type_count; u++) {
    const int hole = ends[u - 1];
    const int last = ends[u] - 1;

    if (last > hole)
      _move_boid(last, hole);

    ends[u]--;
  }

  boid_count--;
  nearby_lookup.unlink(boid_count);
}
void BoidArrays::set_types(TypedArray<BoidType> types) {
  assert(boid_count == 0);

  boid_types = types;

  type_count = types.size();
  type_end.resize(type_count);
  type_iter.resize(type_count);
  type_end.fill(0);
  type_iter.fill(0);
}

BoidArrays::BoidArrays(NearbyLookup &l) : nearby_lookup(l), _ptr(*this) {
  array_position.resize(MAX_BOIDS);
  array_rotation.resize(MAX_BOIDS);
  array_velocity.resize(MAX_BOIDS);
  array_health.resize(MAX_BOIDS);
  array_steering_flock.resize(MAX_BOIDS);

  _ptr = Pointers(*this);
}

BoidArrays::Region::Region(BoidArrays &a, size_t index)
    : type_index(index), iter(a.type_iter[index]) {

  type = a.boid_types[index];

  begin = (index > 0) ? a.type_end[index - 1] : 0;
  end = a.type_end[index];
  count = end - begin;
}
