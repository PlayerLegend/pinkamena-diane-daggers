#include "BoidState.hpp"

using namespace godot;

#define BIND_BOID_PROP(N, ...)                                                 \
  ClassDB::bind_method(D_METHOD("set_" #N, "value"), &BoidState::set_##N);     \
  ClassDB::bind_method(D_METHOD("get_" #N), &BoidState::get_##N);              \
  ADD_PROPERTY(PropertyInfo(__VA_ARGS__), "set_" #N, "get_" #N);

void BoidState::_bind_methods() {
  BIND_BOID_PROP(type, Variant::OBJECT, "type", PROPERTY_HINT_RESOURCE_TYPE,
                 "BoidType")
  BIND_BOID_PROP(health, Variant::INT, "health")
  BIND_BOID_PROP(position, Variant::VECTOR3, "position")
  BIND_BOID_PROP(velocity, Variant::VECTOR3, "velocity")
  BIND_BOID_PROP(rotation, Variant::VECTOR4, "rotation")
}
