#pragma once

#include "BoidArrays.hpp"
#include "BoidDefs.hpp"
#include "BoidMMI.hpp"
#include "BoidType.hpp"
#include "FlockingSum.hpp"

#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/typed_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

namespace godot {
class BoidSim : public Node {
  GDCLASS(BoidSim, Node)

  static constexpr float BOID_SEPARATION = 1.0;
  static constexpr float BOID_SEPARATION_SQUARED =
      BOID_SEPARATION * BOID_SEPARATION;

private:
  FlockingSum flocking_sum;
  uint32_t tick = 0;

public:
  int add_boid(int type_index, Vector3 pos, Quaternion r, Vector3 velocity,
               int health);

  void remove(int boid);

  int raycast(Vector3 origin, Vector3 direction);

private:
  void _apply_types();

protected:
  static void _bind_methods();

public:
  BoidArrays *boid_arrays = nullptr;
  void set_boid_arrays(BoidArrays *p);
  BoidArrays *get_boid_arrays() const { return boid_arrays; }

  BoidMMI *boid_mmi = nullptr;
  void set_boid_mmi(BoidMMI *p);
  BoidMMI *get_boid_mmi() const { return boid_mmi; }

  TypedArray<BoidType> types;
  void set_types(TypedArray<BoidType> t);
  TypedArray<BoidType> get_types() const { return types; }

private:
  Vector3 _get_separation(BoidArrays::Pointers &p, BoidID boid,
                          const BoidType *type);
  Vector3 _get_alignment(BoidArrays::Pointers &p, BoidID boid,
                         const BoidType *type, const FlockingSum::Sum &sum);
  Vector3 _get_cohesion(BoidArrays::Pointers &p, BoidID boid,
                        const BoidType *type, const FlockingSum::Sum &sum);

  Vector3 _get_boid_pass_steering(BoidArrays::Pointers &p, BoidID boid,
                                  const BoidType *type);
  Vector3 _get_chase_steering(BoidArrays::Pointers &p, BoidID boid,
                              const BoidType *type,
                              const std::vector<Vector3> &targets);

  void _compute_steering(BoidArrays::Pointers &p);

  void _compute_transforms(BoidArrays::Pointers &p, double delta);
  void _tick(double delta);

  std::vector<Vector3> _get_chase_target_positions();

public:
  BoidSim();
  ~BoidSim();

  void _physics_process(double delta) override;
};
} // namespace godot
