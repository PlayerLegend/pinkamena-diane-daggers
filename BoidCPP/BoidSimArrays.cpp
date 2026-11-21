#include "boidsim.hpp"

using namespace godot;

void BoidSim::_move_boid(int from, int to) {
  if (from == to)
    return;

  p_rot[to] = p_rot[from];
  p_vel[to] = p_vel[from];
  p_health[to] = p_health[from];
  p_steer_flock[to] = p_steer_flock[from];

  nearby_lookup.unlink(to);
  set_position(to, p_pos[from]);

  nearby_lookup.unlink(from);
}

BoidSim::BoidID BoidSim::_new_boid_index(int type_index) {
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

void BoidSim::set_position(int boid, Vector3 pos) {
  if (boid >= boid_count || boid < 0)
    return;
  nearby_lookup.insert(boid, pos);
  p_pos[boid] = pos;
}

int BoidSim::add_boid(int type_index, Vector3 pos, Quaternion r,
                      Vector3 velocity, int health) {
  if (boid_count >= MAX_BOIDS)
    return -1;

  if (type_index >= boid_types.size() || type_index < 0)
    return -1;

  BoidID boid = _new_boid_index(type_index);

  if (boid >= MAX_BOIDS)
    return -1;

  set_position(boid, pos);
  p_rot[boid] = Vector4(r.x, r.y, r.z, r.w);
  p_vel[boid] = velocity;
  p_health[boid] = health;
  return boid;
}

int BoidSim::_type_of(BoidID boid) const {
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

void BoidSim::remove(int boid) {
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
