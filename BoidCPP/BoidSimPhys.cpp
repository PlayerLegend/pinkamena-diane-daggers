#include "BoidSim.hpp"
#include <algorithm>

using namespace godot;

// Ray vs sphere. `dir` must be normalized.
// Returns true if the ray hits within [0, max_dist]; t_out is the distance
// along the ray to the hit. If the origin starts inside the sphere, t_out = 0.
inline bool ray_sphere_intersect(Vector3 origin, Vector3 dir, Vector3 center,
                                 float radius, float max_dist, float &t_out) {
  const Vector3 oc = center - origin;
  const float tca = oc.dot(dir); // distance to closest approach
  const float d2 = oc.length_squared() - tca * tca;
  const float r2 = radius * radius;

  if (d2 > r2)
    return false; // ray misses

  const float thc = Math::sqrt(r2 - d2);
  const float t_near = tca - thc;
  const float t_far = tca + thc;

  if (t_far < 0.0f)
    return false; // sphere is entirely behind the origin

  const float t = t_near < 0.0f ? 0.0f : t_near; // origin inside sphere
  if (t > max_dist)
    return false;

  t_out = t;
  return true;
}

// Returns the index of the nearest boid hit by the ray, or -1 if none.
// Requires: distance / 2 + radius_collision <= BOID_NEIGHBOR_RADIUS, since
// only the cells around the ray's midpoint are searched.
int BoidSim::raycast(Vector3 origin, Vector3 direction) {
  if (!boid_arrays) {
    static bool did_warn = false;
    if (!did_warn) {
      did_warn = true;
      godot::UtilityFunctions::push_warning("boid_arrays is not set");
    }
    return -1;
  }

  if (direction.is_zero_approx()) {
    UtilityFunctions::push_warning("Bad direction in raycast ", direction);
    return -1;
  }

  float distance = direction.length();

  direction /= distance;

  // if (distance * 0.5f >= BOID_NEIGHBOR_RADIUS)
  // UtilityFunctions::push_warning("Bad distance in raycast ", distance);

  const Vector3 mid = origin + direction * (distance * 0.5f);

  BoidArrays::Pointers p(*boid_arrays);

  int best_boid = -1;
  float best_t = distance;

  NearbyLookup &nearby_lookup = boid_arrays->get_nearby_lookup();

  NearbyLookup::Results results(nearby_lookup, mid);

  BoidID boid;

  while ((boid = results.next()) < MAX_BOIDS) {
    const int type_index = boid_arrays->type_of(boid);
    if (type_index < 0)
      continue;

    const BoidType *type =
        Object::cast_to<BoidType>(boid_arrays->boid_types[type_index]);
    if (!type)
      continue;

    if ((p.pos[boid] - origin).length() < type->radius_collision)
      return boid;

    float t;
    if (ray_sphere_intersect(origin, direction, p.pos[boid],
                             type->radius_collision, best_t, t) &&
        t <= best_t) {
      best_t = t;
      best_boid = (int)boid;
    }
  }

  return best_boid;
}

PackedInt32Array BoidSim::get_boids_in_near_radius(Vector3 position,
                                                   float radius) {
  PackedInt32Array result;
  if (!boid_arrays)
    return result;

  const float radius_squared = radius * radius;

  NearbyLookup &nearby_lookup = boid_arrays->get_nearby_lookup();
  BoidArrays::Pointers p(*boid_arrays);

  NearbyLookup::Results results(nearby_lookup, position);

  BoidID boid;
  while ((boid = results.next()) < MAX_BOIDS) {
    if (p.pos[boid].distance_squared_to(position) <= radius_squared)
      result.push_back((int)boid);
  }

  std::sort(result.ptrw(), result.ptrw() + result.size(),
            [](int a, int b) { return a > b; });

  return result;
}
