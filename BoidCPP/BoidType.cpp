#include "boidsim.hpp"

using namespace godot;

#define BIND_BOID_PROP(N, ...)                                                 \
  ClassDB::bind_method(D_METHOD("set_" #N, "value"), &BoidType::set_##N);      \
  ClassDB::bind_method(D_METHOD("get_" #N), &BoidType::get_##N);               \
  ADD_PROPERTY(PropertyInfo(__VA_ARGS__), "set_" #N, "get_" #N);

void BoidType::_bind_methods() {
  BIND_BOID_PROP(mesh, Variant::OBJECT, "mesh", PROPERTY_HINT_RESOURCE_TYPE,
                 "Mesh")
  BIND_BOID_PROP(material_override, Variant::OBJECT, "material_override",
                 PROPERTY_HINT_RESOURCE_TYPE, "Material")
  BIND_BOID_PROP(health, Variant::INT, "health")
  BIND_BOID_PROP(max_speed, Variant::FLOAT, "max_speed")
  BIND_BOID_PROP(min_speed, Variant::FLOAT, "min_speed")
  BIND_BOID_PROP(max_force, Variant::FLOAT, "max_force")
  BIND_BOID_PROP(weight_separation, Variant::FLOAT, "weight_separation")
  BIND_BOID_PROP(weight_alignment, Variant::FLOAT, "weight_alignment")
  BIND_BOID_PROP(weight_cohesion, Variant::FLOAT, "weight_cohesion")
  BIND_BOID_PROP(weight_bounds, Variant::FLOAT, "weight_bounds")
  BIND_BOID_PROP(weight_floor, Variant::FLOAT, "weight_floor")
  BIND_BOID_PROP(weight_obstacles, Variant::FLOAT, "weight_obstacles")
  BIND_BOID_PROP(weight_chase, Variant::FLOAT, "weight_chase")
  BIND_BOID_PROP(radius_collision, Variant::FLOAT, "radius_collision")
  BIND_BOID_PROP(floor_height, Variant::FLOAT, "floor_height")
  BIND_BOID_PROP(height_target, Variant::FLOAT, "height_target")
  BIND_BOID_PROP(height_target, Variant::FLOAT, "turn_rate")
}
