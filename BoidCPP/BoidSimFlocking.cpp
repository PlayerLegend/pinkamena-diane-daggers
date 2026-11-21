#include "boidsim.hpp"
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/node3d.hpp>
#include <godot_cpp/classes/scene_tree.hpp>
#include <godot_cpp/core/class_db.hpp>

using namespace godot;

Vector3 _steer_towards(Vector3 have_vel, Vector3 wishdir, float wishspeed) {
  // reynolds steering
  if (wishdir.is_zero_approx())
    return Vector3{};
  return wishdir.normalized() * wishspeed - have_vel;
}

Vector3 BoidSim::_get_separation(BoidID boid, const Ref<BoidType> &type) {
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

Vector3 BoidSim::_get_alignment(BoidID boid, const Ref<BoidType> &type,
                                const FlockingSum::Sum &sum) {
  return _steer_towards(p_vel[boid], sum.get_velocity(p_vel[boid]),
                        type->max_speed);
}
Vector3 BoidSim::_get_cohesion(BoidID boid, const Ref<BoidType> &type,
                               const FlockingSum::Sum &sum) {

  return _steer_towards(p_vel[boid],
                        sum.get_position(p_pos[boid]) - p_pos[boid],
                        type->max_speed);
}

Vector3 BoidSim::_get_boid_pass_steering(BoidID boid,
                                         const Ref<BoidType> &type) {
  FlockingSum::Sum sum = flocking_sum.get_sum(p_pos[boid]);
  Vector3 separation = _get_separation(boid, type);
  Vector3 alignment = _get_alignment(boid, type, sum);
  Vector3 cohesion = _get_cohesion(boid, type, sum);

  return separation * type->weight_separation +
         alignment * type->weight_alignment + cohesion * type->weight_cohesion;
}

void BoidSim::_compute_steering() {
  TypedArray<Node> chase_targets =
      get_tree()->get_nodes_in_group("chase_targets");

  flocking_sum.set_sums(boid_count, array_position, array_velocity);

  for (int type_index = 0, max = type_end.size(), begin = 0; type_index < max;
       begin = type_end[type_index], type_index++) {

    const Ref<BoidType> type = boid_types[type_index];

    if (!type.is_valid())
      continue;

    int end = type_end[type_index];
    int prev = type_stopped_prev[type_index];

    int count = end - begin;

    int iter = count;

    if (iter > 100)
      iter = 100;

    if (iter > 0) {
      int boid = 0;
      for (int i = 0; i < iter; i++) {

        boid = begin + (prev + i) % count;

        Vector3 steer_flock = _get_boid_pass_steering(boid, type);
        Vector3 steer_chase = _get_chase_steering(boid, type, chase_targets);

        p_steer[boid] = steer_flock + steer_chase;
      }

      type_stopped_prev[type_index] = (prev + iter) % count;
    }
  }
}

static bool _get_nearest_chase_target(Vector3 &out, Vector3 self,
                                      const TypedArray<Node> &targets) {
  bool result = false;
  float best = INFINITY;

  for (auto node : targets) {
    Node3D *node_3d = Object::cast_to<Node3D>(node);

    Vector3 pos = node_3d->get_global_position();
    float dist = self.distance_squared_to(pos);
    if (dist < best) {
      best = dist;
      out = pos;
      result = true;
    }
  }

  return result;
}

Vector3 BoidSim::_get_chase_steering(BoidID boid, const Ref<BoidType> &type,
                                     const TypedArray<Node> &targets) {
  Vector3 target;
  if (_get_nearest_chase_target(target, p_pos[boid], targets)) {
    return _steer_towards(p_vel[boid], target - p_pos[boid], type->max_speed) *
           type->weight_chase;
  } else {
    return Vector3{};
  }
}

Quaternion _look_rotation(const Vector3 &direction,
                          const Vector3 &up = Vector3(0, 1, 0)) {
  Vector3 dir = direction.normalized();

  if (dir.is_zero_approx()) {
    return Quaternion();
  }

  Vector3 safe_up = up;
  if (Math::abs(dir.dot(up.normalized())) > 0.9999f) {
    safe_up = Vector3(1, 0, 0);
  }

  Basis b = Basis::looking_at(dir, safe_up);
  return b.get_rotation_quaternion();
}

void BoidSim::_apply_steering(double delta) {
  for (int type_index = 0, max = type_end.size(), begin = 0; type_index < max;
       begin = type_end[type_index], type_index++) {

    const Ref<BoidType> type = boid_types[type_index];

    if (!type.is_valid())
      continue;

    int end = type_end[type_index];

    for (int boid = begin; boid < end; boid++) {

      Vector3 new_velocity =
          p_vel[boid] + p_steer[boid].limit_length(type->max_force) * delta;

      float height = p_pos[boid].y;

      if (height < type->floor_height && new_velocity.y < 0)
        new_velocity.y = 0;

      float speed = new_velocity.length();

      if (speed > 0.01)
        new_velocity = (new_velocity / speed) *
                       Math::clamp(speed, type->min_speed, type->max_speed);

      p_vel[boid] = new_velocity;
      p_pos[boid] += new_velocity * delta;

      Quaternion wish_rotation = _look_rotation(new_velocity);

      _set_rot(boid, _get_rot(boid).slerp(wish_rotation, delta));
    }
  }
}

void BoidSim::_process(double delta) {
  if (Engine::get_singleton()->is_editor_hint())
    return;
  _compute_steering();
  _apply_steering(delta);
}
