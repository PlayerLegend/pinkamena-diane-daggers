#pragma once
#include "BoidType.hpp"
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/ref_counted.hpp>

namespace godot {
class BoidState : public RefCounted {
  GDCLASS(BoidState, RefCounted)

public:
  Ref<Mesh> mesh;
  Ref<Material> material_override;
  BoidType *type;
  int health = 0;
  Vector3 position;
  Vector3 velocity;
  Quaternion rotation;
  static void _bind_methods();

#define BOID_PROP(T, N)                                                        \
  void set_##N(T v) { N = v; }                                                 \
  T get_##N() const { return N; }

  BOID_PROP(Ref<Mesh>, mesh)
  BOID_PROP(Ref<Material>, material_override)
  BOID_PROP(int, health)
  BOID_PROP(Vector3, position)
  BOID_PROP(Vector3, velocity)
  BOID_PROP(Quaternion, rotation)
#undef BOID_PROP
};
} // namespace godot
