#include "boidsim.hpp"
#include <godot_cpp/core/error_macros.hpp>

using namespace godot;

void BoidArrays::_move_boid(Pointers &p, int from, int to) {
  if (from == to)
    return;

  p.rot[to] = p.rot[from];
  p.vel[to] = p.vel[from];
  p.health[to] = p.health[from];
  p.steer[to] = p.steer[from];

  nearby_lookup.unlink(to);
  p.set_pos(to, p.pos[from]);

  nearby_lookup.unlink(from);
}

BoidID BoidArrays::_new_boid_index(Pointers &p, int type_index) {
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
      _move_boid(p, first, past_last);

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

  Pointers p(*this);

  BoidID boid = _new_boid_index(p, type_index);

  if (boid >= MAX_BOIDS)
    return -1;

  p.set_pos(boid, pos);
  p.rot[boid] = Vector4(r.x, r.y, r.z, r.w);
  p.vel[boid] = velocity;
  p.health[boid] = health;
  p.steer[boid] = Vector3{};

  return boid;
}

int BoidArrays::type_of(BoidID boid) const {
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
  const int type = type_of(boid);
  if (type < 0)
    return;

  const int type_count = (int)type_end.size();
  int *ends = type_end.ptrw();

  Pointers p(*this);
  _move_boid(p, ends[type] - 1, boid);
  ends[type]--;

  for (int u = type + 1; u < type_count; u++) {
    const int hole = ends[u - 1];
    const int last = ends[u] - 1;

    if (last > hole)
      _move_boid(p, last, hole);

    ends[u]--;
  }

  boid_count--;
  nearby_lookup.unlink(boid_count);
}

void BoidArrays::set_types(TypedArray<BoidType> types) {
  if (boid_count != 0)
    UtilityFunctions::push_warning("Second use of set_types ignored");

  boid_types = types;

  type_count = types.size();
  type_end.resize(type_count);
  type_iter.resize(type_count);
  type_end.fill(0);
  type_iter.fill(0);
}

BoidArrays::BoidArrays(NearbyLookup &l) : nearby_lookup(l) {
  array_position.resize(MAX_BOIDS);
  array_rotation.resize(MAX_BOIDS);
  array_velocity.resize(MAX_BOIDS);
  array_health.resize(MAX_BOIDS);
  array_steering_flock.resize(MAX_BOIDS);
}

BoidArrays::Region::Region(BoidArrays &a, size_t index)
    : type_index(index), iter(a.type_iter[index]) {

  type = Object::cast_to<BoidType>(a.boid_types[index]);

  begin = (index > 0) ? a.type_end[index - 1] : 0;
  end = a.type_end[index];
  count = end - begin;
}

BoidArrays::Pointers::Pointers(BoidArrays &a)
    : pos_w(a.array_position.ptrw()), nearby_lookup(&a.nearby_lookup),
      pos(a.array_position.ptr()), rot(a.array_rotation.ptrw()),
      vel(a.array_velocity.ptrw()), health(a.array_health.ptrw()),
      steer(a.array_steering_flock.ptrw()) {}
