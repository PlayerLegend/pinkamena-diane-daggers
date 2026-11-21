#include "boidsim.hpp"
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

Vector3 _steer_towards(Vector3 have_vel, Vector3 wishdir, float wishspeed) {
  // reynolds steering
  if (wishdir.is_zero_approx())
    return Vector3{};
  return wishdir.normalized() * wishspeed - have_vel;
}

Vector3 BoidSim::_get_separation(BoidID boid, Ref<BoidType> &type) {
  // use only this cell for speed

  Vector3 push_separation = Vector3{};

  Vector3 boid_pos = p_pos[boid];

  BoidID local_list = nearby_lookup.lookup_cell(boid_pos);

  int count = 0;

  while (local_list < MAX_BOIDS) {
    BoidID other = local_list;
    local_list = nearby_lookup.next(local_list);

    if (other == boid)
      continue;

    Vector3 offset = boid_pos - p_pos[other];
    float dist2 = offset.length_squared();

    if (dist2 < BOID_SEPARATION_SQUARED && dist2 > 0.01)
      push_separation += offset / dist2;

    count++;
    if (count > 12)
      break;
  }

  return _steer_towards(p_vel[boid], push_separation, type->max_speed);
}

Vector3 BoidSim::_get_alignment(int boid, Ref<BoidType> &type,
                                const FlockingSum::Sum &sum) {
  return _steer_towards(p_vel[boid], sum.get_velocity(p_vel[boid]),
                        type->max_speed);
}
Vector3 BoidSim::_get_cohesion(int boid, Ref<BoidType> &type,
                               const FlockingSum::Sum &sum) {

  return _steer_towards(p_vel[boid],
                        sum.get_position(p_pos[boid]) - p_pos[boid],
                        type->max_speed);
}

Vector3 BoidSim::_get_boid_pass_steering(BoidID boid, Ref<BoidType> &type) {
  FlockingSum::Sum sum = flocking_sum.get_sum(p_pos[boid]);
  Vector3 separation = _get_separation(boid, type);
  Vector3 alignment = _get_alignment(boid, type, sum);
  Vector3 cohesion = _get_cohesion(boid, type, sum);

  return separation * type->weight_separation +
         alignment * type->weight_alignment + cohesion * type->weight_cohesion;
}
