#pragma once
#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/resource.hpp>

namespace godot {
class BoidType : public Resource {
  GDCLASS(BoidType, Resource)

public:
  Ref<Mesh> mesh;
  Ref<Material> material_override;
  int health = 1;
  float max_speed = 16;
  float min_speed = 4.5;
  float max_force = 12;

  float weight_separation = 0.8;
  float weight_alignment = 0.1;
  float weight_cohesion = 0.2;
  float weight_bounds = 1.1;
  float weight_floor = 1.5;
  float weight_obstacles = 1.0;
  float weight_chase = 1.0;

  float radius_collision = 0.5;

  float floor_height = 0;

  float height_target = 0.5;

  float turn_rate = 0.5;

  int gib_count = 0;
  bool drops_xtal = false;

  static void _bind_methods();

#define BOID_PROP(T, N)                                                        \
  void set_##N(T v) { N = v; }                                                 \
  T get_##N() const { return N; }

  BOID_PROP(Ref<Mesh>, mesh)
  BOID_PROP(Ref<Material>, material_override)
  BOID_PROP(int, health)
  BOID_PROP(float, max_speed)
  BOID_PROP(float, min_speed)
  BOID_PROP(float, max_force)
  BOID_PROP(float, weight_separation)
  BOID_PROP(float, weight_alignment)
  BOID_PROP(float, weight_cohesion)
  BOID_PROP(float, weight_bounds)
  BOID_PROP(float, weight_floor)
  BOID_PROP(float, weight_obstacles)
  BOID_PROP(float, weight_chase)
  BOID_PROP(float, radius_collision)
  BOID_PROP(float, floor_height)
  BOID_PROP(float, height_target)
  BOID_PROP(float, turn_rate)
  BOID_PROP(int, gib_count)
  BOID_PROP(bool, drops_xtal)

#undef BOID_PROP
};
} // namespace godot
