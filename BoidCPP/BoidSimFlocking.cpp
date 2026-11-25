#include "BoidSim.hpp"

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

Vector3 BoidSim::_get_separation(BoidArrays::Pointers &p, BoidID boid,
                                 const BoidType *type) {
  if (!boid_arrays)
    return Vector3{};

  // use only this cell for speed

  Vector3 push_separation = Vector3{};

  Vector3 boid_pos = p.pos[boid];

  NearbyLookup &nearby_lookup = boid_arrays->get_nearby_lookup();

  BoidID local_list = nearby_lookup.lookup_cell(boid_pos);

  int count = 0;

  while (local_list < MAX_BOIDS) {
    BoidID other = local_list;
    local_list = nearby_lookup.next(local_list);

    if (other == boid)
      continue;

    Vector3 offset = boid_pos - p.pos[other];
    float dist2 = offset.length_squared();

    if (dist2 < BOID_SEPARATION_SQUARED && dist2 > 0.01)
      push_separation += offset / dist2;

    count++;
    if (count > 12)
      break;
  }

  return _steer_towards(p.vel[boid], push_separation, type->max_speed);
}

Vector3 BoidSim::_get_alignment(BoidArrays::Pointers &p, BoidID boid,
                                const BoidType *type,
                                const FlockingSum::Sum &sum) {
  return _steer_towards(p.vel[boid], sum.get_velocity(), type->max_speed);
}
Vector3 BoidSim::_get_cohesion(BoidArrays::Pointers &p, BoidID boid,
                               const BoidType *type,
                               const FlockingSum::Sum &sum) {

  return _steer_towards(p.vel[boid],
                        sum.get_position(p.pos[boid]) - p.pos[boid],
                        type->max_speed);
}

std::vector<Vector3> BoidSim::_get_chase_target_positions() {
  std::vector<Vector3> result;

  TypedArray<Node> chase_targets =
      get_tree()->get_nodes_in_group("chase_targets");

  for (auto node : chase_targets) {
    Node3D *node_3d = Object::cast_to<Node3D>(node);

    if (node_3d)
      result.push_back(node_3d->get_global_position());
  }

  return result;
}

Vector3 BoidSim::_get_boid_pass_steering(BoidArrays::Pointers &p, BoidID boid,
                                         const BoidType *type) {
  FlockingSum::Sum sum = flocking_sum.get_sum(p.pos[boid]);
  Vector3 separation = _get_separation(p, boid, type);
  Vector3 alignment = _get_alignment(p, boid, type, sum);
  Vector3 cohesion = _get_cohesion(p, boid, type, sum);

  return separation * type->weight_separation +
         alignment * type->weight_alignment + cohesion * type->weight_cohesion;
}

void BoidSim::_compute_steering(BoidArrays::Pointers &p) {
  if (!boid_arrays)
    return;

  std::vector<Vector3> chase_targets = _get_chase_target_positions();

  for (size_t type_index = 0; type_index < boid_arrays->type_count;
       type_index++) {
    BoidArrays::Region region(*boid_arrays, type_index);

    if (!region.type)
      continue;

    int iterations = region.count;
    if (iterations > 100)
      iterations = 100;

    for (int i = 0; i < iterations; i++) {
      BoidID boid = region.get_boid();

      Vector3 steer_flock = _get_boid_pass_steering(p, boid, region.type);
      Vector3 steer_chase =
          _get_chase_steering(p, boid, region.type, chase_targets);

      p.steer[boid] = steer_flock + steer_chase;
    }
  }
}

static bool _get_nearest_chase_target(Vector3 &out, Vector3 self,
                                      const std::vector<Vector3> &targets) {
  bool result = false;
  float best = INFINITY;

  for (auto pos : targets) {
    float dist = self.distance_squared_to(pos);
    if (dist < best) {
      best = dist;
      out = pos;
      result = true;
    }
  }

  return result;
}

Vector3 BoidSim::_get_chase_steering(BoidArrays::Pointers &p, BoidID boid,
                                     const BoidType *type,
                                     const std::vector<Vector3> &targets) {
  Vector3 target;
  if (_get_nearest_chase_target(target, p.pos[boid], targets)) {
    return _steer_towards(p.vel[boid], target - p.pos[boid], type->max_speed) *
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

void BoidSim::_compute_transforms(BoidArrays::Pointers &p, double delta) {

  if (!boid_arrays)
    return;

  if (!boid_mmi)
    return;

  for (size_t type_index = 0; type_index < boid_arrays->type_count;
       type_index++) {
    BoidArrays::Region region(*boid_arrays, type_index);

    if (!region.type)
      continue;

    boid_mmi->start_type(type_index);

    for (int boid = region.begin; boid < region.end; boid++) {

      Vector3 new_velocity =
          p.vel[boid] +
          p.steer[boid].limit_length(region.type->max_force) * delta;

      float height = p.pos[boid].y;

      if (height < region.type->floor_height && new_velocity.y < 0)
        new_velocity.y = 0.1;

      float speed = new_velocity.length();

      Vector3 dir;
      if (speed > 0.001f)
        dir = new_velocity / speed;
      else
        dir = p.get_rot(boid).xform(Vector3(0, 0, -1));

      new_velocity = dir * Math::clamp(speed, region.type->min_speed,
                                       region.type->max_speed);

      p.vel[boid] = new_velocity;
      p.set_pos(boid, p.pos[boid] + new_velocity * delta);

      Quaternion wish_rotation = _look_rotation(new_velocity);

      const float turn_slerp_fac =
          1.0f - Math::exp(-region.type->turn_rate * (float)delta);

      p.set_rot(boid, p.get_rot(boid).slerp(wish_rotation, turn_slerp_fac));

      boid_mmi->set_transform(Transform3D(Basis(p.get_rot(boid)), p.pos[boid]));
    }

    boid_mmi->finish_type(type_index);
  }
}

void BoidSim::_tick(double delta) {

  if (!boid_arrays)
    return;

  tick++;
  if (tick % 5 == 0)
    boid_arrays->set_flocking_sums(flocking_sum);

  BoidArrays::Pointers pointers(*boid_arrays);

  _compute_steering(pointers);
  _compute_transforms(pointers, delta);
}
